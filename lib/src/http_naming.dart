import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

/// Infers a file name for a downloaded response, preferring the
/// `Content-Disposition` header, then the URL's last path segment, and finally
/// a timestamped fallback.
String inferFileNameFromResponse(http.Response response, String url) {
  final contentDisposition = response.headers['content-disposition'];
  if (contentDisposition != null) {
    final regex = RegExp(
      r"filename[*]?=[" "\"'" r"]?([^" "\"';" r"\s]+)[" "\"'" r"]?",
      caseSensitive: false,
    );
    final match = regex.firstMatch(contentDisposition);
    if (match != null && match.group(1) != null) {
      final name = Uri.decodeComponent(match.group(1)!);
      if (name.isNotEmpty) return name;
    }
  }

  final uri = Uri.parse(url);
  if (uri.pathSegments.isNotEmpty) {
    final lastSegment = uri.pathSegments.last;
    if (lastSegment.isNotEmpty && lastSegment.contains('.')) {
      return lastSegment;
    }
  }

  return 'download_${DateTime.now().millisecondsSinceEpoch}';
}

/// Infers a MIME type for a downloaded response, preferring the `Content-Type`
/// header and falling back to a lookup on the file extension.
String inferMimeTypeFromResponse(http.Response response, String fileName) {
  final contentType = response.headers['content-type'];
  if (contentType != null && contentType.isNotEmpty) {
    final mime = contentType.split(';').first.trim();
    if (mime.isNotEmpty && mime != 'application/octet-stream') {
      return mime;
    }
  }

  return lookupMimeType(fileName) ?? 'application/octet-stream';
}
