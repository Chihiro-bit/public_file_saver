// ignore_for_file: deprecated_member_use, invalid_runtime_check_with_js_interop_types

import 'dart:async';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'public_file_saver_platform_interface.dart';
import 'src/public_saved_file.dart';

/// Web implementation of [PublicFileSaverPlatform].
///
/// [saveBytesWithDialog] uses `showSaveFilePicker` when the browser supports
/// the File System Access API. Other browsers fall back to a standard browser
/// download, whose destination is controlled by browser settings.
///
/// The returned [PublicSavedFile] only contains [PublicSavedFile.fileName]
/// because the actual save location is not exposed to JavaScript for privacy
/// reasons.
class PublicFileSaverWeb extends PublicFileSaverPlatform {
  static void registerWith(Registrar registrar) {
    PublicFileSaverPlatform.instance = PublicFileSaverWeb();
  }

  @override
  Future<PublicSavedFile?> saveBytes({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/octet-stream',
    String? subDir,
  }) async {
    _triggerDownload(bytes, fileName, mimeType);
    return PublicSavedFile(fileName: fileName);
  }

  @override
  Future<PublicSavedFile?> saveBytesWithDialog({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/octet-stream',
    List<String>? fileSuffixChoices,
  }) {
    return _saveWithDialog(
      data: Future<PublicFileSaveData>.value(
        PublicFileSaveData(
          bytes: bytes,
          fileName: fileName,
          mimeType: mimeType,
        ),
      ),
      suggestedFileName: fileName,
    );
  }

  @override
  Future<PublicSavedFile?> saveBytesWithDialogDeferred({
    required Future<PublicFileSaveData> data,
    required String suggestedFileName,
  }) {
    return _saveWithDialog(
      data: data,
      suggestedFileName: suggestedFileName,
    );
  }

  Future<PublicSavedFile?> _saveWithDialog({
    required Future<PublicFileSaveData> data,
    required String suggestedFileName,
  }) {
    if (!globalContext.has('showSaveFilePicker')) {
      return _downloadWhenReady(data);
    }

    // This call must happen synchronously in the original click handler.
    // Awaiting file preparation first would consume the browser's transient
    // user activation and cause showSaveFilePicker to throw SecurityError.
    try {
      final options = <String, Object?>{
        'suggestedName': suggestedFileName,
      }.jsify();
      final pickerPromise = globalContext.callMethodVarArgs<JSAny?>(
        'showSaveFilePicker'.toJS,
        <JSAny?>[options],
      );
      return _writeToPickedFile(pickerPromise as JSPromise<JSObject>, data);
    } catch (error, stackTrace) {
      return Future<PublicSavedFile?>.error(error, stackTrace);
    }
  }

  Future<PublicSavedFile?> _writeToPickedFile(
    JSPromise<JSObject> pickerPromise,
    Future<PublicFileSaveData> data,
  ) async {
    try {
      final handle = await pickerPromise.toDart;
      final resolved = await data;
      final writablePromise = handle.callMethodVarArgs<JSAny?>(
        'createWritable'.toJS,
        const <JSAny?>[],
      );
      final writable = await (writablePromise as JSPromise<JSObject>).toDart;
      final blob = html.Blob(<dynamic>[resolved.bytes], resolved.mimeType);
      final writePromise = writable.callMethodVarArgs<JSAny?>(
        'write'.toJS,
        <JSAny?>[blob as JSAny],
      );
      await (writePromise as JSPromise<JSAny?>).toDart;
      final closePromise = writable.callMethodVarArgs<JSAny?>(
        'close'.toJS,
        const <JSAny?>[],
      );
      await (closePromise as JSPromise<JSAny?>).toDart;

      final pickedName = handle.getProperty<JSString>('name'.toJS).toDart;
      return PublicSavedFile(
        fileName: pickedName.isNotEmpty ? pickedName : resolved.fileName,
      );
    } catch (error, stackTrace) {
      if (_isAbortError(error)) return null;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<PublicSavedFile?> _downloadWhenReady(
    Future<PublicFileSaveData> data,
  ) async {
    final resolved = await data;
    _triggerDownload(resolved.bytes, resolved.fileName, resolved.mimeType);
    return PublicSavedFile(fileName: resolved.fileName);
  }

  bool _isAbortError(Object error) {
    try {
      if (error is JSObject) {
        return error.getProperty<JSString>('name'.toJS).toDart == 'AbortError';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void _triggerDownload(Uint8List bytes, String fileName, String mimeType) {
    final blob = html.Blob(<dynamic>[bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    // Deliberately delay revocation: revoking synchronously right after
    // click() can abort the download in some browsers (notably Safari).
    unawaited(Future<void>.delayed(const Duration(seconds: 30), () {
      html.Url.revokeObjectUrl(url);
    }));
  }
}
