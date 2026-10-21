import '../public_saved_file.dart';

/// Thrown internally when a batch item cannot be saved for a reason the
/// platform reported without an exception (for example a `null` result).
class BatchSaveException implements Exception {
  final String message;

  const BatchSaveException(this.message);

  @override
  String toString() => 'BatchSaveException: $message';
}

/// Describes one item in a batch that could not be saved.
class BatchSaveFailure {
  /// Index of the item in the list originally passed to the batch call.
  final int index;

  /// Best-known name of the item that failed. For URL items whose name could
  /// not be inferred yet, this falls back to the URL.
  final String fileName;

  /// The error that caused the failure.
  final Object error;

  /// Stack trace captured with [error], when one was available.
  final StackTrace? stackTrace;

  const BatchSaveFailure({
    required this.index,
    required this.fileName,
    required this.error,
    this.stackTrace,
  });

  @override
  String toString() =>
      'BatchSaveFailure(index: $index, fileName: $fileName, error: $error)';
}

/// The outcome of a batch save.
///
/// A batch never throws for a single bad item: every item is reported either in
/// [succeeded] or in [failed], so a partial failure never discards the files
/// that were written successfully.
class BatchSaveResult {
  /// Files that were written, in the order they were saved.
  final List<PublicSavedFile> succeeded;

  /// Items that could not be written, in the order they were attempted.
  final List<BatchSaveFailure> failed;

  /// How many items the caller asked to save.
  final int totalRequested;

  BatchSaveResult({
    required List<PublicSavedFile> succeeded,
    required List<BatchSaveFailure> failed,
    required this.totalRequested,
  })  : succeeded = List.unmodifiable(succeeded),
        failed = List.unmodifiable(failed);

  /// True when every requested item was saved.
  bool get isCompleteSuccess =>
      failed.isEmpty && succeeded.length == totalRequested;

  /// True when at least one item failed.
  bool get hasFailures => failed.isNotEmpty;

  /// How many items were actually attempted.
  int get processedCount => succeeded.length + failed.length;

  /// How many items were never attempted.
  ///
  /// Non-zero only when the batch ran with `continueOnError: false` and stopped
  /// early at the first failure.
  int get skippedCount => totalRequested - processedCount;

  @override
  String toString() => 'BatchSaveResult(succeeded: ${succeeded.length}, '
      'failed: ${failed.length}, skipped: $skippedCount, '
      'total: $totalRequested)';
}
