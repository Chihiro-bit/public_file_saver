import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'public_file_saver_method_channel.dart';
import 'src/public_saved_file.dart';

/// Data resolved after a save dialog has been requested.
///
/// This lets Web open its native picker during the original user gesture,
/// before asynchronous work such as an HTTP download completes.
class PublicFileSaveData {
  final Uint8List bytes;
  final String fileName;
  final String mimeType;
  final List<String>? fileSuffixChoices;

  const PublicFileSaveData({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    this.fileSuffixChoices,
  });
}

abstract class PublicFileSaverPlatform extends PlatformInterface {
  /// Constructs a PublicFileSaverPlatform.
  PublicFileSaverPlatform() : super(token: _token);

  static final Object _token = Object();

  static PublicFileSaverPlatform _instance = MethodChannelPublicFileSaver();

  /// The default instance of [PublicFileSaverPlatform] to use.
  ///
  /// Defaults to [MethodChannelPublicFileSaver].
  static PublicFileSaverPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PublicFileSaverPlatform] when
  /// they register themselves.
  static set instance(PublicFileSaverPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Save bytes to a public visible location without showing a dialog.
  Future<PublicSavedFile?> saveBytes({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/octet-stream',
    String? subDir,
  }) {
    throw UnimplementedError('saveBytes() has not been implemented.');
  }

  /// Save bytes to a user-selected location via system file picker dialog.
  Future<PublicSavedFile?> saveBytesWithDialog({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/octet-stream',
    List<String>? fileSuffixChoices,
  }) {
    throw UnimplementedError('saveBytesWithDialog() has not been implemented.');
  }

  /// Opens a save dialog while [data] is still being prepared.
  ///
  /// Native implementations use the default behavior and wait for [data]
  /// before opening their picker. Web overrides this so `showSaveFilePicker`
  /// is invoked while the browser still has transient user activation.
  Future<PublicSavedFile?> saveBytesWithDialogDeferred({
    required Future<PublicFileSaveData> data,
    required String suggestedFileName,
  }) async {
    final resolved = await data;
    return saveBytesWithDialog(
      bytes: resolved.bytes,
      fileName: resolved.fileName,
      mimeType: resolved.mimeType,
      fileSuffixChoices: resolved.fileSuffixChoices,
    );
  }
}
