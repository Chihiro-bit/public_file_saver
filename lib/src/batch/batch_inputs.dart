import 'dart:typed_data';

import '../io_compat_web.dart' if (dart.library.io) '../io_compat.dart';

/// A single in-memory file to hand to [PublicFileSaverBatch.saveBytes].
class FileToSave {
  /// The binary data to write.
  final Uint8List bytes;

  /// The desired file name (sanitized before saving).
  final String fileName;

  /// The MIME type of the file.
  final String mimeType;

  const FileToSave({
    required this.bytes,
    required this.fileName,
    this.mimeType = 'application/octet-stream',
  });

  @override
  String toString() =>
      'FileToSave(fileName: $fileName, mimeType: $mimeType, ${bytes.length} bytes)';
}

/// A single local file to hand to [PublicFileSaverBatch.saveFiles].
///
/// The file is read one at a time during the batch, so a batch of large files
/// never holds more than one file's bytes in memory.
class LocalFileToSave {
  /// The file to read and copy to a public location.
  final File file;

  /// Optional custom file name. Defaults to the source file's base name.
  final String? fileName;

  /// Optional MIME type. Inferred from the file extension when omitted.
  final String? mimeType;

  const LocalFileToSave(this.file, {this.fileName, this.mimeType});

  @override
  String toString() =>
      'LocalFileToSave(path: ${file.path}, fileName: $fileName, mimeType: $mimeType)';
}

/// A single remote file to hand to [PublicFileSaverBatch.saveFromUrls].
///
/// Downloads happen one at a time during the batch, so a batch of large
/// downloads never holds more than one response body in memory.
class UrlToSave {
  /// The HTTP(S) URL to download from.
  final String url;

  /// Optional custom file name. Inferred from `Content-Disposition` or the URL
  /// path when omitted.
  final String? fileName;

  /// Optional MIME type. Inferred from the `Content-Type` header or the file
  /// extension when omitted.
  final String? mimeType;

  const UrlToSave(this.url, {this.fileName, this.mimeType});

  @override
  String toString() =>
      'UrlToSave(url: $url, fileName: $fileName, mimeType: $mimeType)';
}
