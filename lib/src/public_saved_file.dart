/// Represents the result of a file save operation.
///
/// Contains the saved file's name, URI, and/or path depending on the platform
/// and save mode used.
class PublicSavedFile {
  /// The name of the saved file.
  final String fileName;

  /// The URI of the saved file.
  /// - Android 10+: content:// URI from MediaStore
  /// - Android dialog mode: content:// URI from SAF
  /// - OHOS: file URI
  /// - iOS: Usually null for direct save, file:// URL for dialog mode
  final String? uri;

  /// The file system path of the saved file.
  /// - Android 9-: Full path in Downloads directory
  /// - iOS: Full path in Documents directory
  /// - OHOS: Converted path from URI if available
  final String? path;

  const PublicSavedFile({
    required this.fileName,
    this.uri,
    this.path,
  });

  /// Returns true if the save operation was successful.
  bool get isSuccess => uri != null || path != null;

  /// Creates a PublicSavedFile from a platform result map.
  factory PublicSavedFile.fromMap(Map<dynamic, dynamic> map) {
    return PublicSavedFile(
      fileName: map['fileName'] as String? ?? '',
      uri: map['uri'] as String?,
      path: map['path'] as String?,
    );
  }

  /// Converts this object to a map.
  Map<String, dynamic> toMap() {
    return {
      'fileName': fileName,
      'uri': uri,
      'path': path,
    };
  }

  @override
  String toString() {
    return 'PublicSavedFile(fileName: $fileName, uri: $uri, path: $path)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PublicSavedFile &&
        other.fileName == fileName &&
        other.uri == uri &&
        other.path == path;
  }

  @override
  int get hashCode => Object.hash(fileName, uri, path);
}

