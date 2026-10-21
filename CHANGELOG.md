## 1.2.0

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
- `PublicFileSaver` and its `saveBytes()` / `saveBytesWithDialog()` / `saveFile()` / `saveFromUrl()` signatures are unchanged. This release is fully backward compatible.
- `saveFiles()` is not supported on Web (reading a `File` throws there); use `saveBytes()` instead.

## 1.1.0

### Added
- **macOS** support: direct save to `~/Downloads` and `NSSavePanel` for dialog mode.
- **Web** support: browser-triggered download via Blob + anchor element.
- **Windows** support: `FOLDERID_Downloads` for direct save; `IFileSaveDialog` (COM) for dialog mode.
- **Linux** support: XDG Downloads directory for direct save; `GtkFileChooserNative` for dialog mode.
- iOS plugin now ships a Swift Package Manager `Package.swift` alongside the existing podspec. Both CocoaPods and SPM consumers are supported.

### Changed
- Restructured `ios/` from `ios/Classes/` to `ios/public_file_saver/Sources/public_file_saver/` to support Swift Package Manager.
- `lib/public_file_saver.dart` now uses conditional imports for `dart:io` so the package compiles on Web. Calling `saveFile(File)` on Web throws `UnsupportedError` — use `saveBytes()` directly instead.
- Updated `homepage` / `repository` / `issue_tracker` URLs in `pubspec.yaml` (removed `.git` suffix so pana can reach them).

### Fixed
- Removed unused `dart:typed_data` import from `public_file_saver_method_channel.dart`.

## 1.0.0
- Initial release.
