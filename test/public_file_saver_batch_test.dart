import 'dart:io' as io;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:public_file_saver/public_file_saver.dart';
import 'package:public_file_saver/public_file_saver_platform_interface.dart';
// Resolve `File` the same way the package does, so the analyzer compares the
// same type the batch API declares.
import 'package:public_file_saver/src/io_compat_web.dart'
    if (dart.library.io) 'package:public_file_saver/src/io_compat.dart';

/// Records every save it is asked to perform and can be told to fail, return
/// null, or block on specific file names.
class _FakePlatform extends PublicFileSaverPlatform
    with MockPlatformInterfaceMixin {
  final List<String> savedNames = <String>[];
  final List<String?> savedSubDirs = <String?>[];
  final List<String> savedMimeTypes = <String>[];
  final List<int> savedLengths = <int>[];

  /// File names that should throw instead of saving.
  Set<String> failOn = <String>{};

  /// File names that should resolve to `null` (platform reported no result).
  Set<String> nullOn = <String>{};

  /// True if a second save started before the previous one completed.
  bool sawOverlap = false;
  bool _inFlight = false;

  @override
  Future<PublicSavedFile?> saveBytes({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/octet-stream',
    String? subDir,
  }) async {
    if (_inFlight) sawOverlap = true;
    _inFlight = true;

    // Yield so an interleaved caller would be observed as an overlap.
    await Future<void>.delayed(Duration.zero);

    try {
      savedNames.add(fileName);
      savedSubDirs.add(subDir);
      savedMimeTypes.add(mimeType);
      savedLengths.add(bytes.length);

      if (failOn.contains(fileName)) {
        throw Exception('boom: $fileName');
      }
      if (nullOn.contains(fileName)) {
        return null;
      }
      return PublicSavedFile(
        fileName: fileName,
        path: '/downloads/$fileName',
      );
    } finally {
      _inFlight = false;
    }
  }
}

Uint8List _bytes(int length) =>
    Uint8List.fromList(List<int>.filled(length, 42));

FileToSave _item(String name, {int length = 4}) =>
    FileToSave(bytes: _bytes(length), fileName: name);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePlatform platform;
  final original = PublicFileSaverPlatform.instance;

  setUp(() {
    platform = _FakePlatform();
    PublicFileSaverPlatform.instance = platform;
  });

  tearDown(() {
    PublicFileSaverPlatform.instance = original;
  });

  group('saveBytes', () {
    test('rejects unsafe batch subdirectories before platform writes',
        () async {
      for (final subDir in ['../outside', '/absolute', r'C:\outside']) {
        final result = await const PublicFileSaverBatch().saveBytes(
          files: [_item('safe.txt')],
          subDir: subDir,
        );
        expect(result.failed.single.error, isA<ArgumentError>());
        expect(platform.savedNames, isEmpty);
      }
    });

    test('sanitizes batch subdirectory segments', () async {
      await const PublicFileSaverBatch().saveBytes(
        files: [_item('safe.txt')],
        subDir: r'my\dir:one',
      );
      expect(platform.savedSubDirs.single, 'my/dir_one');
    });

    test('saves every item, in list order', () async {
      final result = await const PublicFileSaverBatch().saveBytes(
        files: [_item('a.pdf'), _item('b.png'), _item('c.txt')],
      );

      expect(platform.savedNames, ['a.pdf', 'b.png', 'c.txt']);
      expect(
          result.succeeded.map((f) => f.fileName), ['a.pdf', 'b.png', 'c.txt']);
      expect(result.failed, isEmpty);
      expect(result.isCompleteSuccess, isTrue);
      expect(result.hasFailures, isFalse);
      expect(result.totalRequested, 3);
      expect(result.skippedCount, 0);
    });

    test('never overlaps saves', () async {
      await const PublicFileSaverBatch().saveBytes(
        files: List.generate(5, (i) => _item('f$i.bin')),
      );

      expect(platform.sawOverlap, isFalse);
    });

    test('sanitizes file names before saving', () async {
      await const PublicFileSaverBatch().saveBytes(
        files: [_item('in/valid:name?.pdf')],
      );

      expect(platform.savedNames.single, 'in_valid_name_.pdf');
    });

    test('forwards subDir and mimeType', () async {
      await const PublicFileSaverBatch().saveBytes(
        files: [
          FileToSave(
            bytes: _bytes(8),
            fileName: 'chart.png',
            mimeType: 'image/png',
          ),
        ],
        subDir: 'MyApp',
      );

      expect(platform.savedSubDirs.single, 'MyApp');
      expect(platform.savedMimeTypes.single, 'image/png');
      expect(platform.savedLengths.single, 8);
    });

    test('an empty batch succeeds without touching the platform', () async {
      final result =
          await const PublicFileSaverBatch().saveBytes(files: const []);

      expect(platform.savedNames, isEmpty);
      expect(result.isCompleteSuccess, isTrue);
      expect(result.totalRequested, 0);
    });

    test('reports progress after every attempted item', () async {
      final progress = <String>[];

      await const PublicFileSaverBatch().saveBytes(
        files: [_item('a.pdf'), _item('b.png')],
        onProgress: (done, total) => progress.add('$done/$total'),
      );

      expect(progress, ['1/2', '2/2']);
    });
  });

  group('failure handling', () {
    test('records the failure and keeps going by default', () async {
      platform.failOn = {'b.png'};

      final result = await const PublicFileSaverBatch().saveBytes(
        files: [_item('a.pdf'), _item('b.png'), _item('c.txt')],
      );

      expect(result.succeeded.map((f) => f.fileName), ['a.pdf', 'c.txt']);
      expect(result.failed, hasLength(1));
      expect(result.failed.single.index, 1);
      expect(result.failed.single.fileName, 'b.png');
      expect(result.failed.single.error, isA<Exception>());
      expect(result.failed.single.stackTrace, isNotNull);
      expect(result.hasFailures, isTrue);
      expect(result.isCompleteSuccess, isFalse);
      expect(result.skippedCount, 0);
    });

    test('a null platform result counts as a failure', () async {
      platform.nullOn = {'b.png'};

      final result = await const PublicFileSaverBatch().saveBytes(
        files: [_item('a.pdf'), _item('b.png')],
      );

      expect(result.succeeded, hasLength(1));
      expect(result.failed.single.error, isA<BatchSaveException>());
    });

    test('continueOnError: false stops at the first failure', () async {
      platform.failOn = {'b.png'};

      final result = await const PublicFileSaverBatch().saveBytes(
        files: [_item('a.pdf'), _item('b.png'), _item('c.txt')],
        continueOnError: false,
      );

      expect(platform.savedNames, ['a.pdf', 'b.png']);
      expect(result.succeeded.map((f) => f.fileName), ['a.pdf']);
      expect(result.failed, hasLength(1));
      expect(result.processedCount, 2);
      expect(result.skippedCount, 1);
      expect(result.totalRequested, 3);
    });

    test('result lists are unmodifiable', () async {
      final result =
          await const PublicFileSaverBatch().saveBytes(files: [_item('a.pdf')]);

      expect(
        () => result.succeeded.add(const PublicSavedFile(fileName: 'x')),
        throwsUnsupportedError,
      );
    });
  });

  group('saveFiles', () {
    late io.Directory tempDir;

    /// Writes a real file on disk and returns it as the package's `File` type.
    File writeTempFile(String name, int length) {
      final path = '${tempDir.path}/$name';
      io.File(path).writeAsBytesSync(_bytes(length));
      return File(path);
    }

    setUp(() async {
      tempDir = await io.Directory.systemTemp.createTemp('pfs_batch_test');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('reads each file and infers name and mime type', () async {
      final png = writeTempFile('photo.png', 10);
      final txt = writeTempFile('notes.txt', 3);

      final result = await const PublicFileSaverBatch().saveFiles(
        files: [LocalFileToSave(png), LocalFileToSave(txt)],
      );

      expect(platform.savedNames, ['photo.png', 'notes.txt']);
      expect(platform.savedMimeTypes, ['image/png', 'text/plain']);
      expect(platform.savedLengths, [10, 3]);
      expect(result.isCompleteSuccess, isTrue);
    });

    test('honors a custom file name and mime type', () async {
      final source = writeTempFile('raw.bin', 5);

      await const PublicFileSaverBatch().saveFiles(
        files: [
          LocalFileToSave(source,
              fileName: 'renamed.pdf', mimeType: 'application/pdf'),
        ],
      );

      expect(platform.savedNames.single, 'renamed.pdf');
      expect(platform.savedMimeTypes.single, 'application/pdf');
    });

    test('a missing file fails only that item', () async {
      final good = writeTempFile('good.txt', 2);

      final result = await const PublicFileSaverBatch().saveFiles(
        files: [
          LocalFileToSave(File('${tempDir.path}/missing.txt')),
          LocalFileToSave(good),
        ],
      );

      expect(result.failed.single.index, 0);
      expect(result.failed.single.fileName, 'missing.txt');
      expect(result.succeeded.single.fileName, 'good.txt');
    });
  });

  group('saveFromUrls', () {
    test('reuses published HTTP filename fixes in batch downloads', () async {
      final headers = [
        "attachment; filename*=UTF-8''%E6%B5%8B%E8%AF%95.pdf",
        'attachment; filename="50%off.pdf"',
        'attachment; filename="annual report.pdf"',
      ];
      var index = 0;
      final client = MockClient((request) async => http.Response.bytes(
            _bytes(1),
            200,
            headers: {'content-disposition': headers[index++]},
          ));
      final result =
          await PublicFileSaverBatch(httpClient: client).saveFromUrls(
        urls: List.generate(3, (i) => UrlToSave('https://example.com/$i')),
      );
      expect(result.failed, isEmpty);
      expect(
          platform.savedNames, ['测试.pdf', '50%off.pdf', 'annual report.pdf']);
    });

    test('downloads each URL and infers name and mime type', () async {
      final client = MockClient((request) async {
        return http.Response.bytes(
          _bytes(6),
          200,
          headers: {'content-type': 'application/pdf'},
        );
      });

      final result = await PublicFileSaverBatch(httpClient: client)
          .saveFromUrls(urls: const [
        UrlToSave('https://example.com/files/report.pdf'),
        UrlToSave('https://example.com/files/summary.pdf'),
      ]);

      expect(platform.savedNames, ['report.pdf', 'summary.pdf']);
      expect(platform.savedMimeTypes, ['application/pdf', 'application/pdf']);
      expect(result.isCompleteSuccess, isTrue);
    });

    test('prefers the Content-Disposition file name', () async {
      final client = MockClient((request) async {
        return http.Response.bytes(
          _bytes(1),
          200,
          headers: {
            'content-type': 'application/pdf',
            'content-disposition': 'attachment; filename="invoice-42.pdf"',
          },
        );
      });

      await PublicFileSaverBatch(httpClient: client).saveFromUrls(
        urls: const [UrlToSave('https://example.com/download?id=42')],
      );

      expect(platform.savedNames.single, 'invoice-42.pdf');
    });

    test('a non-200 response fails only that item', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('missing.pdf')) {
          return http.Response('nope', 404);
        }
        return http.Response.bytes(_bytes(2), 200);
      });

      final result = await PublicFileSaverBatch(httpClient: client)
          .saveFromUrls(urls: const [
        UrlToSave('https://example.com/missing.pdf'),
        UrlToSave('https://example.com/ok.pdf'),
      ]);

      expect(result.failed.single.index, 0);
      expect(result.failed.single.error, isA<BatchSaveException>());
      expect(result.succeeded.single.fileName, 'ok.pdf');
    });

    test('downloads do not run in parallel', () async {
      var inFlight = 0;
      var sawParallel = false;

      final client = MockClient((request) async {
        inFlight++;
        if (inFlight > 1) sawParallel = true;
        await Future<void>.delayed(Duration.zero);
        inFlight--;
        return http.Response.bytes(_bytes(1), 200);
      });

      await PublicFileSaverBatch(httpClient: client).saveFromUrls(
        urls: List.generate(
          4,
          (i) => UrlToSave('https://example.com/f$i.bin'),
        ),
      );

      expect(sawParallel, isFalse);
      expect(platform.sawOverlap, isFalse);
    });
  });
}
