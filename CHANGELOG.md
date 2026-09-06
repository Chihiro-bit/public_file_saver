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
