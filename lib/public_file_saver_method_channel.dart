import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'public_file_saver_platform_interface.dart';
import 'src/public_saved_file.dart';

/// An implementation of [PublicFileSaverPlatform] that uses method channels.
class MethodChannelPublicFileSaver extends PublicFileSaverPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('public_file_saver');

  @override
  Future<PublicSavedFile?> saveBytes({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/octet-stream',
    String? subDir,
  }) async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'saveBytes',
      {
        'bytes': bytes,
        'fileName': fileName,
        'mimeType': mimeType,
        'subDir': subDir,
      },
    );
    if (result == null) return null;
    return PublicSavedFile.fromMap(result);
  }

  @override
  Future<PublicSavedFile?> saveBytesWithDialog({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/octet-stream',
    List<String>? fileSuffixChoices,
  }) async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'saveBytesWithDialog',
      {
        'bytes': bytes,
        'fileName': fileName,
        'mimeType': mimeType,
        'fileSuffixChoices': fileSuffixChoices,
      },
    );
    if (result == null) return null;
    return PublicSavedFile.fromMap(result);
  }
}
