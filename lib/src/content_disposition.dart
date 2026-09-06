/// Parses a file name from a Content-Disposition header value.
///
/// Handles both RFC 5987 (`filename*=UTF-8''<percent-encoded>`) and the
/// plain `filename="..."` / `filename=...` forms. Percent-decoding is
/// best-effort: if the value contains invalid encoding (e.g. a literal
/// `%`), the raw value is returned instead of throwing.
String? parseContentDispositionFileName(String header) {
  // RFC 5987 extended form: filename*=UTF-8''na%C3%AFve%20file.pdf
  // (some servers quote the whole parameter, so strip outer quotes first)
  final extended = RegExp(r"filename\*\s*=\s*([^;]+)", caseSensitive: false);
  final extendedMatch = extended.firstMatch(header);
  if (extendedMatch != null) {
    final raw = _stripQuotes(extendedMatch.group(1)!.trim());
    final firstQuote = raw.indexOf("'");
    final secondQuote = firstQuote < 0 ? -1 : raw.indexOf("'", firstQuote + 1);
    if (firstQuote > 0 && secondQuote > firstQuote) {
      final charset = raw.substring(0, firstQuote).toLowerCase();
      // RFC 5987 values are percent-encoded, so raw quotes in the value
      // are only ever left over from malformed quoting - drop them.
      if (charset == 'utf-8') {
        final value = raw.substring(secondQuote + 1).replaceAll('"', '');
        final decoded = _tryDecodePercent(value);
        if (decoded.isNotEmpty) return decoded;
      }
    }
  }

  // Plain form: filename="example.pdf" | filename='x.pdf' | filename=x.pdf
  final plain = RegExp(
    r'''filename\s*=\s*(?:"([^"]*)"|'([^']*)'|([^;]*))''',
    caseSensitive: false,
  );
  final plainMatch = plain.firstMatch(header);
  if (plainMatch != null) {
    final raw = (plainMatch.group(1) ??
            plainMatch.group(2) ??
            plainMatch.group(3) ??
            '')
        .trim();
    final decoded = _tryDecodePercent(raw);
    if (decoded.isNotEmpty) return decoded;
  }

  return null;
}

/// Percent-decode [value], falling back to the raw value on malformed input.
String _tryDecodePercent(String value) {
  if (value.isEmpty || !value.contains('%')) return value;
  try {
    return Uri.decodeComponent(value);
  } on FormatException {
    // Not valid percent-encoding (e.g. "50%off.pdf") - use as-is.
    return value;
  } on ArgumentError {
    // decodeComponent throws ArgumentError on some SDKs for the same input.
    return value;
  }
}

String _stripQuotes(String value) {
  var result = value;
  if (result.length >= 2) {
    final first = result[0];
    final last = result[result.length - 1];
    if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
      result = result.substring(1, result.length - 1);
    }
  }
  return result;
}
