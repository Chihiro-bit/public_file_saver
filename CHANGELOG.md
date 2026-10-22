## 1.3.0 (Unreleased)

### Added
- **Batch saving** via a new, standalone `PublicFileSaverBatch` class:
  - `saveBytes()` — save a list of in-memory files.
  - `saveFiles()` — save a list of local files, read one at a time.
  - `saveFromUrls()` — download and save a list of URLs, one at a time.
- New types: `FileToSave`, `LocalFileToSave`, `UrlToSave`, `BatchSaveResult`, `BatchSaveFailure`, `BatchSaveException`.
- Batch calls report per-item outcomes through `BatchSaveResult`, so one failed item never discards the files already written. `continueOnError: false` stops at the first failure instead.
- Optional `onProgress` callback, called after every attempted item.
- Batch saving is available on all supported platforms and needs no platform-specific code.

### Fixed
- **Android:** supports AGP 9 built-in Kotlin ([#1](https://github.com/Chihiro-bit/public_file_saver/issues/1)). The plugin no longer applies the Kotlin Gradle Plugin when built-in Kotlin is enabled, which removes the Flutter warning "Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP)". Older toolchains (AGP < 9, or AGP 9 with `android.builtInKotlin=false`) still get KGP applied as before, so the minimum Flutter version is unchanged.

### Notes
- Batch saving is **dialog-free by design**. There is no batched equivalent of `saveBytesWithDialog()`: on Android, macOS, Windows, and Linux the native save dialog handles exactly one file, so a batch would have to show one dialog per file. Batch methods always save to the public Downloads / Documents location.
- Items are saved strictly one at a time. Concurrent saves could race in the native "find a non-colliding name" logic and overwrite each other, and sequential processing also keeps at most one file's bytes in memory.
- Merged the published 1.2.0 implementation and platform fixes into this development branch, retaining `saveFromUrl(timeout:)` and `sanitizeSubDir`. This version remains unreleased pending platform build validation.
- `saveFiles()` is not supported on Web (reading a `File` throws there); use `saveBytes()` instead.

### Development compatibility
- Use flutter_lints 4.x in the package and example to support the local Dart 3.4.3 toolchain.
- Lower the example Dart SDK constraint to >=3.4.3 <4.0.0 and retain the imports required by the restored integration test.

## 1.2.0

### Added
- **macOS** support: direct save to `~/Downloads` and `NSSavePanel` for dialog mode.
- **Web** support: browser downloads plus native Save As picker where the File System Access API is available.
- **Windows** support: `FOLDERID_Downloads` for direct save; `IFileSaveDialog` (COM) for dialog mode.
- **Linux** support: XDG Downloads directory for direct save; `GtkFileChooserNative` for dialog mode.
- iOS plugin now ships a Swift Package Manager `Package.swift` alongside the existing podspec. Both CocoaPods and SPM consumers are supported.

### Changed
- Restructured `ios/` from `ios/Classes/` to `ios/public_file_saver/Sources/public_file_saver/` to support Swift Package Manager.
- `lib/public_file_saver.dart` now uses conditional imports for `dart:io` so the package compiles on Web. Calling `saveFile(File)` on Web throws `UnsupportedError` — use `saveBytes()` directly instead.
- Updated `homepage` / `repository` / `issue_tracker` URLs in `pubspec.yaml` (removed `.git` suffix so pana can reach them).
- `saveFromUrl()` gained an optional `timeout` parameter; the request throws `TimeoutException` when exceeded.
- `subDir` is now sanitized (relative segments only; `..` and absolute paths are rejected) to prevent directory traversal on all platforms.

### Fixed
- Removed unused `dart:typed_data` import from `public_file_saver_method_channel.dart`.
- Android: declared `WRITE_EXTERNAL_STORAGE` (maxSdkVersion 28) so direct saves work on Android 9 and below.
- Android: file writes now run on a background thread instead of the main thread (avoids ANRs for large files).
- Android: MediaStore update re-puts DISPLAY_NAME/MIME_TYPE/RELATIVE_PATH alongside IS_PENDING, fixing files staying hidden on some OEM ROMs.
- Android: failed MediaStore writes now remove their pending row instead of leaving a permanently hidden entry.
- Android/iOS/macOS: file writes are now atomic, avoiding partially-written files if the process is killed mid-write.
- iOS/macOS: direct saves now run on a background queue instead of the main thread.
- iOS/macOS: background saves now deliver Flutter method-channel results on the main queue.
- OHOS: direct saves no longer silently overwrite an existing file with the same name (unique `(1)`, `(2)` suffixes are appended, matching Android/iOS).
- Web: `PublicSavedFile.isSuccess` now also accepts a non-empty `fileName`, since browsers never expose `uri`/`path`.
- Web: object URLs are revoked after a delay instead of synchronously, which could abort downloads in Safari.
- Web: `saveBytesWithDialog()` and dialog-mode URL downloads now use the native Save As picker when the File System Access API is available, with a standard-download fallback for unsupported browsers.
- `saveFromUrl()`: fixed Content-Disposition parsing — RFC 5987 `filename*=UTF-8''…` names are decoded correctly and literal `%` in file names no longer throws.
- File-name sanitization now enforces its limit in UTF-8 bytes and handles Windows reserved device names.
- Windows: link against `shell32` and `ole32` instead of the unused `shlwapi`.
- Fixed SPM product name (`public_file_saver`) in iOS and macOS `Package.swift`.

## 1.0.0
- Initial release.
