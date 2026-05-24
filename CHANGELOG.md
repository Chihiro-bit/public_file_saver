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
