/// Batch saving for [PublicFileSaver].
///
/// A standalone entry point: importing it adds [PublicFileSaverBatch] and its
/// input/result types without changing anything about the single-file API in
/// `package:public_file_saver/public_file_saver.dart`.
///
/// Batch saving is dialog-free by design — see [PublicFileSaverBatch] for why.
library;

export 'src/batch/batch_inputs.dart';
export 'src/batch/batch_save_result.dart';
export 'src/batch/public_file_saver_batch.dart';
export 'src/public_saved_file.dart';
