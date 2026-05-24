import 'dart:typed_data';

/// Web stub for `dart:io`'s [File]. Constructing this type is allowed (so
/// signatures referencing [File] compile on the web), but any operation that
/// touches the underlying file system throws [UnsupportedError]. Web callers
/// should use [PublicFileSaver.saveBytes] / [PublicFileSaver.saveBytesWithDialog]
/// directly.
class File {
  final String path;

  File(this.path);

  Uri get uri => Uri.file(path);

  Future<Uint8List> readAsBytes() => Future.error(UnsupportedError(
        'PublicFileSaver.saveFile(File) is not supported on Web. '
        'Use saveBytes(...) instead.',
      ));
}
