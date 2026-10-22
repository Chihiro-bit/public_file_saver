import 'dart:async';
import 'dart:io' as io;
import 'package:public_file_saver/src/io_compat_web.dart'
    if (dart.library.io) 'package:public_file_saver/src/io_compat.dart';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:public_file_saver/public_file_saver.dart';
import 'package:public_file_saver/public_file_saver_platform_interface.dart';

class RecordingPlatform extends PublicFileSaverPlatform
    with MockPlatformInterfaceMixin {
  String? name;
  String? mime;
  String? directory;
  List<String>? suffixes;
  Uint8List? content;
  bool dialog = false;
  bool deferred = false;
  bool cancel = false;

  @override
  Future<PublicSavedFile?> saveBytes({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/octet-stream',
    String? subDir,
  }) async {
    name = fileName;
    mime = mimeType;
    directory = subDir;
    content = bytes;
    return cancel
        ? null
        : PublicSavedFile(fileName: fileName, path: '/$fileName');
  }

  @override
  Future<PublicSavedFile?> saveBytesWithDialog({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/octet-stream',
    List<String>? fileSuffixChoices,
  }) {
    dialog = true;
    suffixes = fileSuffixChoices;
    return saveBytes(bytes: bytes, fileName: fileName, mimeType: mimeType);
  }

  @override
  Future<PublicSavedFile?> saveBytesWithDialogDeferred({
    required Future<PublicFileSaveData> data,
    required String suggestedFileName,
  }) {
    deferred = true;
    return super.saveBytesWithDialogDeferred(
        data: data, suggestedFileName: suggestedFileName);
  }
}

void main() {
  final saver = PublicFileSaver();
  final original = PublicFileSaverPlatform.instance;
  late RecordingPlatform platform;
  final bytes = Uint8List.fromList([1, 2, 3]);

  setUp(() {
    platform = RecordingPlatform();
    PublicFileSaverPlatform.instance = platform;
  });
  tearDown(() => PublicFileSaverPlatform.instance = original);

  test('requires exactly one source and validates before side effects', () {
    expect(() => saver.save(), throwsArgumentError);
    expect(() => saver.save(bytes: bytes, url: 'https://example.com/a'),
        throwsArgumentError);
    expect(() => saver.save(bytes: bytes), throwsArgumentError);
    expect(() => saver.save(bytes: bytes, fileName: ' '), throwsArgumentError);
    expect(() => saver.save(url: 'file:///tmp/a'), throwsArgumentError);
    expect(() => saver.save(url: 'https://example.com/a', subDir: '../out'),
        throwsArgumentError);
    expect(
        () => saver.save(url: 'https://example.com/a', timeout: Duration.zero),
        throwsArgumentError);
    expect(() => saver.save(bytes: bytes, fileName: 'a', headers: {}),
        throwsArgumentError);
    expect(
        () => saver.save(
            bytes: bytes, fileName: 'a', useDialog: true, subDir: 'x'),
        throwsArgumentError);
    expect(
        () => saver
            .save(bytes: bytes, fileName: 'a', fileSuffixChoices: ['.txt']),
        throwsArgumentError);
    expect(platform.content, isNull);
  });

  test('bytes infer MIME and sanitize name and directory', () async {
    await saver.save(bytes: bytes, fileName: 'a:b.txt', subDir: r'my\dir');
    expect(platform.name, 'a_b.txt');
    expect(platform.mime, 'text/plain');
    expect(platform.directory, 'my/dir');
    expect(platform.content, bytes);
  });

  test('dialog forwards suffixes and cancellation', () async {
    platform.cancel = true;
    expect(
        await saver.save(
            bytes: bytes,
            fileName: 'a.txt',
            useDialog: true,
            fileSuffixChoices: ['.txt']),
        isNull);
    expect(platform.dialog, isTrue);
    expect(platform.suffixes, ['.txt']);
  });

  test('local file infers name and supports override and dialog', () async {
    final dir = await io.Directory.systemTemp.createTemp('unified-save-');
    try {
      final path = '${dir.path}/a.txt';
      await io.File(path).writeAsBytes(bytes);
      final file = File(path);
      await saver.save(file: file);
      expect(platform.name, 'a.txt');
      expect(platform.mime, 'text/plain');
      await saver.save(
          file: file,
          fileName: 'b.bin',
          mimeType: 'custom/type',
          useDialog: true,
          fileSuffixChoices: ['.bin']);
      expect(platform.name, 'b.bin');
      expect(platform.mime, 'custom/type');
      expect(platform.suffixes, ['.bin']);
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('URL forwards auth headers and parses response filename', () async {
    await http.runWithClient(() async {
      await saver.save(
          url: 'https://example.com/download',
          headers: {'Authorization': 'Bearer test'});
    },
        () => MockClient((request) async {
              expect(request.headers['Authorization'], 'Bearer test');
              return http.Response.bytes(bytes, 200, headers: {
                'content-disposition':
                    "attachment; filename*=UTF-8''%E6%B5%8B%E8%AF%95.txt",
                'content-type': 'text/plain; charset=utf-8',
              });
            }));
    expect(platform.name, '测试.txt');
    expect(platform.mime, 'text/plain');
  });

  test('URL opens deferred dialog before download completes', () async {
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
      final result = saver.save(
          url: 'https://example.com/a.txt',
          useDialog: true,
          fileSuffixChoices: ['.txt']);
      expect(platform.deferred, isTrue);
      response.complete(http.Response.bytes(bytes, 200));
      await result;
      expect(platform.suffixes, ['.txt']);
    }, () => MockClient((_) => response.future));
  });

  test('URL timeout and HTTP failures do not write files', () async {
    await http.runWithClient(() async {
      await expectLater(
          saver.save(url: 'https://example.com/a'), throwsException);
    }, () => MockClient((_) async => http.Response('missing', 404)));
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      await expectLater(
          saver.save(
              url: 'https://example.com/a',
              timeout: const Duration(milliseconds: 5)),
          throwsA(isA<TimeoutException>()));
    }, () => MockClient((_) => pending.future));
    pending.complete(http.Response('late', 200));
    expect(platform.content, isNull);
  });

  test('legacy API keeps its original MIME default', () async {
    // ignore: deprecated_member_use_from_same_package
    await saver.saveBytes(bytes: bytes, fileName: 'a.txt');
    expect(platform.mime, 'application/octet-stream');
    // ignore: deprecated_member_use_from_same_package
    await saver.saveBytesWithDialog(bytes: bytes, fileName: 'a.txt');
    expect(platform.dialog, isTrue);
  });
}
