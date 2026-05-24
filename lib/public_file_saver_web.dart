// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'public_file_saver_platform_interface.dart';
import 'src/public_saved_file.dart';

/// Web implementation of [PublicFileSaverPlatform].
///
/// Both [saveBytes] and [saveBytesWithDialog] trigger a standard browser
/// download. The browser decides where the file goes (typically the user's
/// configured Downloads folder, or it prompts the user if "Ask where to save
/// each file" is enabled).
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
  }) async {
    _triggerDownload(bytes, fileName, mimeType);
    return PublicSavedFile(fileName: fileName);
  }

  void _triggerDownload(Uint8List bytes, String fileName, String mimeType) {
    final blob = html.Blob(<dynamic>[bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    try {
      final anchor = html.AnchorElement(href: url)
        ..download = fileName
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
    } finally {
      html.Url.revokeObjectUrl(url);
    }
  }
}
