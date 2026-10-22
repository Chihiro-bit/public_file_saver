import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

import '../../public_file_saver.dart' show PublicFileSaver;
import '../../public_file_saver_platform_interface.dart';
import '../http_naming.dart';
import '../public_saved_file.dart';
import 'batch_inputs.dart';
import 'batch_save_result.dart';

/// Reports progress during a batch save.
///
/// [completed] counts every item that has been attempted, successful or not.
typedef BatchProgressCallback = void Function(int completed, int total);

/// Saves multiple files to a public location in one call, without any system
/// dialog.
///
/// This is a standalone entry point. It does not change, wrap, or extend
/// [PublicFileSaver] — single-file saving keeps its existing API and behavior.
///
/// ### Why there is no dialog variant
///
/// Every batch method here saves directly to the public Downloads / Documents
/// location, the same destination as [PublicFileSaver.saveBytes]. There is
/// deliberately no batched equivalent of `saveBytesWithDialog`: on Android,
/// macOS, Windows, and Linux the native save dialog handles exactly one file,
/// so a batch would have to show one dialog per file. Use
/// [PublicFileSaver.saveBytesWithDialog] when you want the user to pick a
/// location for a single file.
///
/// ### Ordering and memory
///
/// Items are saved strictly one at a time, in list order. This is required for
/// correctness, not just politeness: the native "find a non-colliding name"
/// helpers check for an existing file and then write it, so concurrent saves of
/// same-named files could resolve to the same target and overwrite each other.
///
/// Sequential processing also bounds memory. [saveFiles] and [saveFromUrls]
/// read or download one item at a time, so a batch of large files never holds
/// more than a single file's bytes in memory.
///
/// ### Failure handling
///
/// A batch never throws because one item failed. Each item lands in
/// [BatchSaveResult.succeeded] or [BatchSaveResult.failed], so a failure in the
/// middle of a batch never discards the files already written.
///
/// ```dart
/// final batch = PublicFileSaverBatch();
/// final result = await batch.saveBytes(
///   files: [
///     FileToSave(bytes: invoiceBytes, fileName: 'invoice.pdf'),
///     FileToSave(bytes: chartBytes, fileName: 'chart.png'),
///   ],
///   subDir: 'MyApp',
///   onProgress: (done, total) => debugPrint('saved $done of $total'),
/// );
///
/// for (final failure in result.failed) {
///   debugPrint('${failure.fileName} failed: ${failure.error}');
/// }
/// ```
class PublicFileSaverBatch {
  /// An optional HTTP client used by [saveFromUrls].
  ///
  /// When omitted, each [saveFromUrls] call creates and closes its own client.
  /// Pass one to reuse connections across batches, or to inject a mock in
  /// tests; a caller-supplied client is never closed by this class.
  final http.Client? httpClient;

  const PublicFileSaverBatch({this.httpClient});

  /// Saves a list of in-memory files to the public Downloads / Documents
  /// location.
  ///
  /// [files] - The files to save, written in list order.
  /// [subDir] - Optional subdirectory (ignored on Web and OHOS).
  /// [continueOnError] - When true (the default), a failed item is recorded and
  ///   the batch moves on. When false, the batch stops at the first failure and
  ///   the untried items are reported via [BatchSaveResult.skippedCount].
  /// [onProgress] - Called after each attempted item.
  ///
  /// Note that [files] holds every item's bytes for the lifetime of the call,
  /// because the caller built them. Prefer [saveFiles] or [saveFromUrls] when
  /// the data is large and can be loaded lazily.
  Future<BatchSaveResult> saveBytes({
    required List<FileToSave> files,
    String? subDir,
    bool continueOnError = true,
    BatchProgressCallback? onProgress,
  }) {
    return _runSequentially(
      count: files.length,
      labelOf: (index) => files[index].fileName,
      resolve: (index) async {
        final file = files[index];
        return _Payload(file.bytes, file.fileName, file.mimeType);
      },
      subDir: subDir,
      continueOnError: continueOnError,
      onProgress: onProgress,
    );
  }

  /// Saves a list of local files to the public Downloads / Documents location.
  ///
  /// Each file is read immediately before it is saved, so only one file's bytes
  /// are in memory at a time.
  ///
  /// [files] - The local files to copy, saved in list order.
  /// [subDir] - Optional subdirectory (ignored on Web and OHOS).
  /// [continueOnError] - See [saveBytes].
  /// [onProgress] - Called after each attempted item.
  ///
  /// Not supported on Web: reading a `File` throws there, so every item is
  /// reported as a failure. Use [saveBytes] on Web instead.
  Future<BatchSaveResult> saveFiles({
    required List<LocalFileToSave> files,
    String? subDir,
    bool continueOnError = true,
    BatchProgressCallback? onProgress,
  }) {
    return _runSequentially(
      count: files.length,
      labelOf: (index) =>
          files[index].fileName ?? files[index].file.uri.pathSegments.last,
      resolve: (index) async {
        final item = files[index];
        final bytes = await item.file.readAsBytes();
        final name = item.fileName ?? item.file.uri.pathSegments.last;
        final mime =
            item.mimeType ?? lookupMimeType(name) ?? 'application/octet-stream';
        return _Payload(bytes, name, mime);
      },
      subDir: subDir,
      continueOnError: continueOnError,
      onProgress: onProgress,
    );
  }

  /// Downloads a list of URLs and saves them to the public Downloads /
  /// Documents location.
  ///
  /// Each URL is downloaded immediately before it is saved, so only one
  /// response body is in memory at a time. Downloads are not run in parallel:
  /// that would mean holding every response in memory at once.
  ///
  /// [urls] - The files to download, saved in list order.
  /// [subDir] - Optional subdirectory (ignored on Web and OHOS).
  /// [continueOnError] - See [saveBytes]. A network error counts as a failed
  ///   item, not a thrown exception.
  /// [onProgress] - Called after each attempted item.
  Future<BatchSaveResult> saveFromUrls({
    required List<UrlToSave> urls,
    String? subDir,
    bool continueOnError = true,
    BatchProgressCallback? onProgress,
  }) async {
    final client = httpClient ?? http.Client();
    final ownsClient = httpClient == null;

    try {
      return await _runSequentially(
        count: urls.length,
        labelOf: (index) => urls[index].fileName ?? urls[index].url,
        resolve: (index) async {
          final item = urls[index];
          final response = await client.get(Uri.parse(item.url));
          if (response.statusCode != 200) {
            throw BatchSaveException(
              'Failed to download ${item.url}: HTTP ${response.statusCode}',
            );
          }
          final name =
              item.fileName ?? inferFileNameFromResponse(response, item.url);
          final mime =
              item.mimeType ?? inferMimeTypeFromResponse(response, name);
          return _Payload(response.bodyBytes, name, mime);
        },
        subDir: subDir,
        continueOnError: continueOnError,
        onProgress: onProgress,
      );
    } finally {
      if (ownsClient) client.close();
    }
  }

  /// Runs one batch, one item at a time, collecting per-item outcomes.
  Future<BatchSaveResult> _runSequentially({
    required int count,
    required String Function(int index) labelOf,
    required Future<_Payload> Function(int index) resolve,
    required String? subDir,
    required bool continueOnError,
    required BatchProgressCallback? onProgress,
  }) async {
    final succeeded = <PublicSavedFile>[];
    final failed = <BatchSaveFailure>[];

    for (var index = 0; index < count; index++) {
      try {
        // Scoped to this iteration so the bytes become collectable before the
        // next item is read or downloaded.
        final payload = await resolve(index);
        final saved = await PublicFileSaverPlatform.instance.saveBytes(
          bytes: payload.bytes,
          fileName: PublicFileSaver.sanitizeFileName(payload.fileName),
          mimeType: payload.mimeType,
          subDir: PublicFileSaver.sanitizeSubDir(subDir),
        );

        if (saved == null) {
          failed.add(BatchSaveFailure(
            index: index,
            fileName: payload.fileName,
            error: BatchSaveException(
              'The platform returned no result for "${payload.fileName}".',
            ),
          ));
        } else {
          succeeded.add(saved);
        }
      } catch (error, stackTrace) {
        failed.add(BatchSaveFailure(
          index: index,
          fileName: labelOf(index),
          error: error,
          stackTrace: stackTrace,
        ));
      }

      onProgress?.call(succeeded.length + failed.length, count);

      if (failed.isNotEmpty && !continueOnError) break;
    }

    return BatchSaveResult(
      succeeded: succeeded,
      failed: failed,
      totalRequested: count,
    );
  }
}

/// The resolved bytes and metadata for a single batch item.
class _Payload {
  final Uint8List bytes;
  final String fileName;
  final String mimeType;

  const _Payload(this.bytes, this.fileName, this.mimeType);
}
