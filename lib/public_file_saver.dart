import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

import 'public_file_saver_platform_interface.dart';
import 'src/public_saved_file.dart';

export 'src/public_saved_file.dart';

/// A cross-platform Flutter plugin to save files to publicly visible locations.
///
/// Supports Android, iOS, and HarmonyOS (OHOS) with consistent API and return format.
class PublicFileSaver {
  /// Illegal characters for file names that will be replaced.
  static const _illegalFileNameChars = r'\/:*?"<>|';

  /// Sanitize file name by replacing illegal characters with underscore.
  static String sanitizeFileName(String fileName) {
    String result = fileName;
    for (final char in _illegalFileNameChars.split('')) {
      result = result.replaceAll(char, '_');
    }
    // Also replace control characters and trim whitespace
    result = result.replaceAll(RegExp(r'[\x00-\x1f]'), '_').trim();
    // Ensure file name is not empty
    if (result.isEmpty) {
      result = 'file';
    }
    return result;
  }

  /// Save bytes to a public visible location (no dialog).
  ///
  /// - **Android 10+**: Uses MediaStore.Downloads, returns content:// URI.
  /// - **Android 9-**: Writes to public Downloads directory, returns file path.
  /// - **iOS**: Writes to app Documents directory (visible in Files app), returns path.
  /// - **OHOS**: Uses DocumentViewPicker in DOWNLOAD mode, returns URI and path.
  ///
  /// [bytes] - The binary data to save.
  /// [fileName] - The desired file name (will be sanitized).
  /// [mimeType] - The MIME type of the file.
  /// [subDir] - Optional subdirectory within Downloads (Android only).
  ///
  /// Returns [PublicSavedFile] on success, or `null` if cancelled/failed.
  Future<PublicSavedFile?> saveBytes({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/octet-stream',
    String? subDir,
  }) {
    final sanitizedName = sanitizeFileName(fileName);
    return PublicFileSaverPlatform.instance.saveBytes(
      bytes: bytes,
      fileName: sanitizedName,
      mimeType: mimeType,
      subDir: subDir,
    );
  }

  /// Save bytes with a system file picker dialog.
  ///
  /// Shows a native file picker dialog allowing the user to choose the save location.
  ///
  /// - **Android**: Uses Storage Access Framework (ACTION_CREATE_DOCUMENT).
  /// - **iOS**: Uses UIDocumentPickerViewController for export.
  /// - **OHOS**: Uses DocumentViewPicker.save with DocumentSaveOptions.
  ///
  /// [bytes] - The binary data to save.
  /// [fileName] - The suggested file name.
  /// [mimeType] - The MIME type of the file.
  /// [fileSuffixChoices] - Optional file extension choices (OHOS only).
  ///
  /// Returns [PublicSavedFile] on success, or `null` if cancelled.
  Future<PublicSavedFile?> saveBytesWithDialog({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/octet-stream',
    List<String>? fileSuffixChoices,
  }) {
    final sanitizedName = sanitizeFileName(fileName);
    return PublicFileSaverPlatform.instance.saveBytesWithDialog(
      bytes: bytes,
      fileName: sanitizedName,
      mimeType: mimeType,
      fileSuffixChoices: fileSuffixChoices,
    );
  }

  /// Save a local file to a public visible location.
  ///
  /// Reads the file content and delegates to [saveBytes] or [saveBytesWithDialog].
  ///
  /// [file] - The file to save.
  /// [fileName] - Optional custom file name (uses file.path basename if not provided).
  /// [mimeType] - Optional MIME type (inferred from extension if not provided).
  /// [subDir] - Optional subdirectory (non-dialog mode only).
  /// [useDialog] - If true, shows file picker dialog.
  ///
  /// Returns [PublicSavedFile] on success, or `null` if cancelled/failed.
  Future<PublicSavedFile?> saveFile({
    required File file,
    String? fileName,
    String? mimeType,
    String? subDir,
    bool useDialog = false,
  }) async {
    final bytes = await file.readAsBytes();
    final name = fileName ?? file.uri.pathSegments.last;
    final mime = mimeType ?? lookupMimeType(name) ?? 'application/octet-stream';

    if (useDialog) {
      return saveBytesWithDialog(
        bytes: bytes,
        fileName: name,
        mimeType: mime,
      );
    } else {
      return saveBytes(
        bytes: bytes,
        fileName: name,
        mimeType: mime,
        subDir: subDir,
      );
    }
  }

  /// Download and save a file from a URL to a public visible location.
  ///
  /// Downloads the file content via HTTP GET, attempts to infer file name
  /// from Content-Disposition header or URL path, and delegates to
  /// [saveBytes] or [saveBytesWithDialog].
  ///
  /// [url] - The HTTP(S) URL to download from.
  /// [fileName] - Optional custom file name (inferred from URL/headers if not provided).
  /// [mimeType] - Optional MIME type (inferred from Content-Type header if not provided).
  /// [subDir] - Optional subdirectory (non-dialog mode only).
  /// [useDialog] - If true, shows file picker dialog.
  ///
  /// Returns [PublicSavedFile] on success, or `null` if cancelled/failed.
  /// Throws exception on network error.
  Future<PublicSavedFile?> saveFromUrl({
    required String url,
    String? fileName,
    String? mimeType,
    String? subDir,
    bool useDialog = false,
  }) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to download file: HTTP ${response.statusCode}');
    }

    final bytes = response.bodyBytes;

    // Infer file name from Content-Disposition or URL
    String name = fileName ?? _inferFileNameFromResponse(response, url);

    // Infer MIME type from Content-Type header or file extension
    String mime = mimeType ?? _inferMimeType(response, name);

    if (useDialog) {
      return saveBytesWithDialog(
        bytes: bytes,
        fileName: name,
        mimeType: mime,
      );
    } else {
      return saveBytes(
        bytes: bytes,
        fileName: name,
        mimeType: mime,
        subDir: subDir,
      );
    }
  }

  /// Infer file name from HTTP response or URL.
  String _inferFileNameFromResponse(http.Response response, String url) {
    // Try Content-Disposition header first
    final contentDisposition = response.headers['content-disposition'];
    if (contentDisposition != null) {
      // Parse filename from Content-Disposition: attachment; filename="example.pdf"
      final regex = RegExp(r"filename[*]?=[" "\"'" r"]?([^" "\"';" r"\s]+)[" "\"'" r"]?", caseSensitive: false);
      final match = regex.firstMatch(contentDisposition);
      if (match != null && match.group(1) != null) {
        final name = Uri.decodeComponent(match.group(1)!);
        if (name.isNotEmpty) return name;
      }
    }

    // Fallback to URL path segment
    final uri = Uri.parse(url);
    if (uri.pathSegments.isNotEmpty) {
      final lastSegment = uri.pathSegments.last;
      if (lastSegment.isNotEmpty && lastSegment.contains('.')) {
        return lastSegment;
      }
    }

    // Default name with timestamp
    return 'download_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Infer MIME type from response header or file name.
  String _inferMimeType(http.Response response, String fileName) {
    // Try Content-Type header (remove charset if present)
    final contentType = response.headers['content-type'];
    if (contentType != null && contentType.isNotEmpty) {
      final mime = contentType.split(';').first.trim();
      if (mime.isNotEmpty && mime != 'application/octet-stream') {
        return mime;
      }
    }

    // Fallback to lookup by file extension
    return lookupMimeType(fileName) ?? 'application/octet-stream';
  }
}
