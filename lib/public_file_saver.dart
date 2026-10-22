import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

import 'public_file_saver_platform_interface.dart';
import 'src/content_disposition.dart';
import 'src/io_compat_web.dart' if (dart.library.io) 'src/io_compat.dart';
import 'src/public_saved_file.dart';

export 'src/public_saved_file.dart';

/// Reliably saves bytes, local files, and URL downloads to user-visible
/// locations across supported platforms.
///
/// Supports Android, iOS, macOS, Web, Windows, Linux, and HarmonyOS (OHOS)
/// with consistent API and return format.
class PublicFileSaver {
  /// Saves exactly one source: [bytes], [file], or an HTTP(S) [url].
  ///
  /// [fileName] is required for bytes and inferred for files and URLs.
  /// MIME type is inferred when omitted. [useDialog] requests the platform's
  /// save picker; browser support and platform restrictions still apply.
  /// [subDir] applies only to direct saves; [fileSuffixChoices] applies only
  /// to dialogs (currently OHOS). Local files are not supported on Web.
  ///
  /// [headers] and [timeout] apply only to URL downloads. Downloads and local
  /// files are buffered in memory, so this is not a streaming download API.
  /// A timeout limits waiting for the response; it does not guarantee that the
  /// underlying HTTP request is aborted.
  ///
  /// Returns the platform result, or null on cancellation. Invalid options
  /// throw [ArgumentError] before any file read, request, or platform call.
  Future<PublicSavedFile?> save({
    Uint8List? bytes,
    File? file,
    String? url,
    String? fileName,
    String? mimeType,
    String? subDir,
    bool useDialog = false,
    List<String>? fileSuffixChoices,
    Map<String, String>? headers,
    Duration? timeout,
  }) {
    final sources = [bytes != null, file != null, url != null]
        .where((present) => present)
        .length;
    if (sources != 1) {
      throw ArgumentError('Provide exactly one of bytes, file, or url.');
    }
    if (fileName != null && fileName.trim().isEmpty) {
      throw ArgumentError.value(fileName, 'fileName', 'Must not be blank');
    }
    if (bytes != null && fileName == null) {
      throw ArgumentError('fileName is required when saving bytes.');
    }
    if (useDialog && subDir != null) {
      throw ArgumentError('subDir cannot be combined with useDialog.');
    }
    if (!useDialog && fileSuffixChoices != null) {
      throw ArgumentError('fileSuffixChoices requires useDialog.');
    }
    if (url == null && (headers != null || timeout != null)) {
      throw ArgumentError('headers and timeout require a URL source.');
    }
    if (timeout != null && timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'Must be positive');
    }
    final directory = useDialog ? null : sanitizeSubDir(subDir);
    if (url != null) {
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty) {
        throw ArgumentError.value(url, 'url', 'Expected an HTTP(S) URL');
      }
      return _saveFromUrl(
        url: url,
        fileName: fileName,
        mimeType: mimeType,
        subDir: directory,
        useDialog: useDialog,
        timeout: timeout,
        headers: headers,
        fileSuffixChoices: fileSuffixChoices,
      );
    }
    if (file != null) {
      return _saveFile(
        file: file,
        fileName: fileName,
        mimeType: mimeType,
        subDir: directory,
        useDialog: useDialog,
        fileSuffixChoices: fileSuffixChoices,
      );
    }
    final mime =
        mimeType ?? lookupMimeType(fileName!) ?? 'application/octet-stream';
    return useDialog
        ? _saveBytesWithDialog(
            bytes: bytes!,
            fileName: fileName!,
            mimeType: mime,
            fileSuffixChoices: fileSuffixChoices)
        : _saveBytes(
            bytes: bytes!,
            fileName: fileName!,
            mimeType: mime,
            subDir: directory);
  }

  /// Legacy byte-saving entry point. Use [save] instead.
  @Deprecated('Use save(bytes: bytes, fileName: fileName) instead.')
  Future<PublicSavedFile?> saveBytes({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/octet-stream',
    String? subDir,
  }) =>
      _saveBytes(
          bytes: bytes, fileName: fileName, mimeType: mimeType, subDir: subDir);

  /// Legacy dialog entry point. Use [save] with useDialog instead.
  @Deprecated(
      'Use save(bytes: bytes, fileName: fileName, useDialog: true) instead.')
  Future<PublicSavedFile?> saveBytesWithDialog({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/octet-stream',
    List<String>? fileSuffixChoices,
  }) =>
      _saveBytesWithDialog(
          bytes: bytes,
          fileName: fileName,
          mimeType: mimeType,
          fileSuffixChoices: fileSuffixChoices);

  /// Legacy local-file entry point. Use [save] instead.
  @Deprecated('Use save(file: file) instead.')
  Future<PublicSavedFile?> saveFile({
    required File file,
    String? fileName,
    String? mimeType,
    String? subDir,
    bool useDialog = false,
  }) =>
      _saveFile(
          file: file,
          fileName: fileName,
          mimeType: mimeType,
          subDir: subDir,
          useDialog: useDialog);

  /// Legacy URL entry point. Use [save] instead.
  @Deprecated('Use save(url: url) instead.')
  Future<PublicSavedFile?> saveFromUrl({
    required String url,
    String? fileName,
    String? mimeType,
    String? subDir,
    bool useDialog = false,
    Duration? timeout,
  }) =>
      _saveFromUrl(
          url: url,
          fileName: fileName,
          mimeType: mimeType,
          subDir: subDir,
          useDialog: useDialog,
          timeout: timeout);

  /// Illegal characters for file names that will be replaced.
  static const _illegalFileNameChars = r'\/:*?"<>|';

  /// Conservative UTF-8 byte limit that leaves room below the 255-byte
  /// component limit used by common file systems.
  static const _maxFileNameBytes = 240;

  /// Sanitize file name by replacing illegal characters with underscore.
  static String sanitizeFileName(String fileName) {
    String result = fileName;
    for (final char in _illegalFileNameChars.split('')) {
      result = result.replaceAll(char, '_');
    }
    // Also replace control characters and trim whitespace
    result = result.replaceAll(RegExp(r'[\x00-\x1f]'), '_').trim();
    // Replace trailing dots/spaces (problematic on Windows and some file systems)
    result = result.replaceFirst(RegExp(r'[. ]+$'), '_');
    // Ensure file name is not empty
    if (result.isEmpty) {
      result = 'file';
    }

    // Windows reserves these device names even when an extension is present.
    if (RegExp(
      r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
      caseSensitive: false,
    ).hasMatch(result)) {
      result = '_$result';
    }

    // File-system component limits are byte-based. Truncate by complete
    // Unicode scalar values so multi-byte names remain valid UTF-8.
    if (utf8.encode(result).length > _maxFileNameBytes) {
      final truncated = StringBuffer();
      var byteCount = 0;
      for (final rune in result.runes) {
        final character = String.fromCharCode(rune);
        final characterBytes = utf8.encode(character).length;
        if (byteCount + characterBytes > _maxFileNameBytes) break;
        truncated.write(character);
        byteCount += characterBytes;
      }
      result = truncated.toString();
    }
    return result;
  }

  /// Sanitize a subdirectory path and guard against directory traversal.
  ///
  /// Rejects absolute paths and `..` segments (throwing [ArgumentError]),
  /// sanitizes each remaining segment, and returns `null` for an empty
  /// result. Returned segments are joined with `/`, which every supported
  /// platform accepts.
  static String? sanitizeSubDir(String? subDir) {
    if (subDir == null) return null;
    final trimmed = subDir.trim();
    if (trimmed.isEmpty) return null;

    // Reject absolute paths (Unix, Windows drive letters, UNC).
    if (trimmed.startsWith('/') ||
        trimmed.startsWith(r'\') ||
        RegExp(r'^[A-Za-z]:').hasMatch(trimmed)) {
      throw ArgumentError.value(
          subDir, 'subDir', 'Subdirectory must be a relative path');
    }

    final segments = trimmed
        .split(RegExp(r'[/\\]+'))
        .where((segment) => segment.isNotEmpty && segment != '.')
        .toList();
    if (segments.any((segment) => segment == '..')) {
      throw ArgumentError.value(
          subDir, 'subDir', 'Subdirectory must not contain ".."');
    }
    if (segments.isEmpty) return null;

    final sanitized = segments.map(sanitizeFileName).join('/');
    return sanitized.isEmpty ? null : sanitized;
  }

  /// Save bytes to a public visible location (no dialog).
  ///
  /// - **Android 10+**: Uses MediaStore.Downloads, returns content:// URI.
  /// - **Android 9-**: Writes to public Downloads directory, returns file path.
  /// - **iOS**: Writes to app Documents directory (visible in Files app), returns path.
  /// - **macOS**: Writes to ~/Downloads (sandbox-redirected in sandboxed apps).
  /// - **Web**: Triggers a browser download, returns the file name only.
  /// - **Windows**: Writes to the user's Downloads folder, returns path.
  /// - **Linux**: Writes to the XDG Downloads directory, returns URI and path.
  /// - **OHOS**: Uses DocumentViewPicker in DOWNLOAD mode, returns URI and path.
  ///
  /// [bytes] - The binary data to save.
  /// [fileName] - The desired file name (will be sanitized).
  /// [mimeType] - The MIME type of the file.
  /// [subDir] - Optional subdirectory within the public directory
  /// (Android, iOS, macOS, Windows, Linux).
  ///
  /// Returns [PublicSavedFile] on success, or `null` if cancelled/failed.
  Future<PublicSavedFile?> _saveBytes({
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
      subDir: sanitizeSubDir(subDir),
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
  Future<PublicSavedFile?> _saveBytesWithDialog({
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
  /// Reads the file content and delegates to [save].
  ///
  /// [file] - The file to save.
  /// [fileName] - Optional custom file name (uses file.path basename if not provided).
  /// [mimeType] - Optional MIME type (inferred from extension if not provided).
  /// [subDir] - Optional subdirectory (non-dialog mode only, not supported on Web/OHOS).
  /// [useDialog] - If true, shows file picker dialog.
  ///
  /// Returns [PublicSavedFile] on success, or `null` if cancelled/failed.
  Future<PublicSavedFile?> _saveFile({
    required File file,
    String? fileName,
    String? mimeType,
    String? subDir,
    bool useDialog = false,
    List<String>? fileSuffixChoices,
  }) async {
    final bytes = await file.readAsBytes();
    final name = fileName ?? file.uri.pathSegments.last;
    final mime = mimeType ?? lookupMimeType(name) ?? 'application/octet-stream';

    if (useDialog) {
      return _saveBytesWithDialog(
        bytes: bytes,
        fileName: name,
        mimeType: mime,
        fileSuffixChoices: fileSuffixChoices,
      );
    } else {
      return _saveBytes(
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
  /// [save].
  ///
  /// [url] - The HTTP(S) URL to download from.
  /// [fileName] - Optional custom file name (inferred from URL/headers if not provided).
  /// [mimeType] - Optional MIME type (inferred from Content-Type header if not provided).
  /// [subDir] - Optional subdirectory (non-dialog mode only, not supported on Web/OHOS).
  /// [useDialog] - If true, shows file picker dialog.
  /// [timeout] - Optional timeout for the HTTP request. When the request
  /// exceeds this duration a [TimeoutException] is thrown.
  ///
  /// Returns [PublicSavedFile] on success, or `null` if cancelled/failed.
  /// Throws exception on network error.
  Future<PublicSavedFile?> _saveFromUrl({
    required String url,
    String? fileName,
    String? mimeType,
    String? subDir,
    bool useDialog = false,
    Duration? timeout,
    Map<String, String>? headers,
    List<String>? fileSuffixChoices,
  }) async {
    final request = http.get(Uri.parse(url), headers: headers);
    final responseFuture = timeout == null ? request : request.timeout(timeout);

    if (useDialog) {
      // Web must open showSaveFilePicker during the original click gesture;
      // waiting for the HTTP response first would consume that activation.
      final suggestedName = sanitizeFileName(
        fileName ?? _inferFileNameFromUrl(url),
      );
      final data = responseFuture.then((response) {
        _ensureSuccessfulResponse(response);
        final name = fileName ?? _inferFileNameFromResponse(response, url);
        return PublicFileSaveData(
          bytes: response.bodyBytes,
          fileName: sanitizeFileName(name),
          mimeType: mimeType ?? _inferMimeType(response, name),
          fileSuffixChoices: fileSuffixChoices,
        );
      });
      return PublicFileSaverPlatform.instance.saveBytesWithDialogDeferred(
        data: data,
        suggestedFileName: suggestedName,
      );
    }

    final response = await responseFuture;
    _ensureSuccessfulResponse(response);
    final name = fileName ?? _inferFileNameFromResponse(response, url);
    final mime = mimeType ?? _inferMimeType(response, name);
    return _saveBytes(
      bytes: response.bodyBytes,
      fileName: name,
      mimeType: mime,
      subDir: subDir,
    );
  }

  void _ensureSuccessfulResponse(http.Response response) {
    if (response.statusCode != 200) {
      throw Exception('Failed to download file: HTTP ${response.statusCode}');
    }
  }

  /// Infer file name from HTTP response or URL.
  String _inferFileNameFromResponse(http.Response response, String url) {
    // Try Content-Disposition header first
    final contentDisposition = response.headers['content-disposition'];
    if (contentDisposition != null) {
      final name = parseContentDispositionFileName(contentDisposition);
      if (name != null && name.isNotEmpty) return name;
    }

    // Fallback to URL path segment
    return _inferFileNameFromUrl(url);
  }

  String _inferFileNameFromUrl(String url) {
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
