# public_file_saver

A cross-platform Flutter plugin to save files to publicly visible locations (Downloads, Documents). Supports **Android**, **iOS**, **macOS**, **Web**, **Windows**, **Linux**, and **HarmonyOS (OHOS)**.

[![pub package](https://img.shields.io/pub/v/public_file_saver.svg)](https://pub.dev/packages/public_file_saver)

[中文文档](README_ZH.md)

## Features

- ✅ Save binary data (Uint8List) to public directories
- ✅ Save with system file picker dialog
- ✅ Save local files
- ✅ Download and save files from URL
- ✅ Automatic file name sanitization
- ✅ MIME type inference
- ✅ Consistent return format across all platforms
- ✅ Swift Package Manager support on iOS

## Platform Support

| Feature | Android | iOS | macOS | Web | Windows | Linux | OHOS |
|---------|---------|-----|-------|-----|---------|-------|------|
| `saveBytes()` | ✅ | ✅ | ✅ | ✅¹ | ✅ | ✅ | ✅ |
| `saveBytesWithDialog()` | ✅ | ✅ | ✅ | ✅¹ | ✅ | ✅ | ✅ |
| `saveFile()` | ✅ | ✅ | ✅ | ❌² | ✅ | ✅ | ✅ |
| `saveFromUrl()` | ✅ | ✅ | ✅ | ✅¹ | ✅ | ✅ | ✅ |
| `subDir` parameter | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ |
| `fileSuffixChoices` parameter | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |

¹ On Web, both modes trigger a normal browser download; the browser chooses the destination (typically the configured Downloads folder, or it prompts if the user has "ask where to save" enabled). The returned `PublicSavedFile` only carries `fileName`.

² On Web, calling `saveFile(File)` throws `UnsupportedError` — `dart:io`'s `File` is not available in the browser. Read the bytes yourself and call `saveBytes()` instead.

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  public_file_saver: ^1.1.0
```

Then run:

```bash
flutter pub get
```

## Platform-Specific Setup

### Android

No additional setup required. The plugin handles permissions automatically:

- **Android 10+ (API 29+)**: Uses MediaStore API, no permission needed
- **Android 9 and below**: Uses public Downloads directory

### iOS

Add the following keys to your `Info.plist` if you want users to access saved files via the Files app:

```xml
<key>UIFileSharingEnabled</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
```

### macOS

If your app is sandboxed (the default for Mac App Store builds), enable user-selected file access in your entitlements to allow the save dialog to write outside the app sandbox:

```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

Without the sandbox, no extra entitlements are needed. Direct (no-dialog) `saveBytes` writes to `~/Downloads`; in a sandboxed build, the system redirects this to the per-app container's Downloads folder.

### Web

No setup required. Both `saveBytes()` and `saveBytesWithDialog()` trigger a standard browser download — the browser decides the destination based on its own settings.

### Windows

No setup required. Direct mode uses `FOLDERID_Downloads` (the user's standard Downloads folder); dialog mode uses the native `IFileSaveDialog`.

### Linux

The plugin uses GTK 3, which is already linked by every Flutter Linux app, so no extra dependencies are required. Direct mode resolves the XDG Downloads directory (`g_get_user_special_dir(G_USER_DIRECTORY_DOWNLOAD)`), falling back to `$HOME` if XDG is not configured; dialog mode uses `GtkFileChooserNative`.

### HarmonyOS (OHOS)

The plugin uses `DocumentViewPicker` which requires no additional permissions.

## Usage

### Import

```dart
import 'package:public_file_saver/public_file_saver.dart';
```

### Create Instance

```dart
final fileSaver = PublicFileSaver();
```

### API Reference

---

#### `saveBytes()`

Save binary data directly to a public location without showing a dialog.

```dart
Future<PublicSavedFile?> saveBytes({
  required Uint8List bytes,
  required String fileName,
  String mimeType = 'application/octet-stream',
  String? subDir,  // Android only
})
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `bytes` | `Uint8List` | Yes | The binary data to save |
| `fileName` | `String` | Yes | Desired file name (will be sanitized) |
| `mimeType` | `String` | No | MIME type of the file (default: `application/octet-stream`) |
| `subDir` | `String?` | No | Subdirectory within Downloads (Android only) |

**Platform Behavior:**

| Platform | Save Location | Returns |
|----------|---------------|---------|
| Android 10+ | MediaStore Downloads | `uri`: content:// URI |
| Android 9- | Public Downloads directory | `path`: full file path |
| iOS | App Documents directory (visible in Files app) | `path`: full file path |
| macOS | `~/Downloads` (or sandbox-redirected) | `uri` (file://) and `path` |
| Web | Browser download (browser-chosen) | `fileName` only |
| Windows | `FOLDERID_Downloads` | `path`: full file path |
| Linux | XDG `$HOME/Downloads` | `uri` (file://) and `path` |
| OHOS | User-selected via DocumentViewPicker | `uri` and `path` |

**Example:**

```dart
final bytes = Uint8List.fromList(utf8.encode('Hello, World!'));

final result = await fileSaver.saveBytes(
  bytes: bytes,
  fileName: 'hello.txt',
  mimeType: 'text/plain',
  subDir: 'MyApp', // Creates Downloads/MyApp/hello.txt on Android
);

if (result != null && result.isSuccess) {
  print('Saved: ${result.fileName}');
  print('URI: ${result.uri}');
  print('Path: ${result.path}');
}
```

---

#### `saveBytesWithDialog()`

Save binary data with a system file picker dialog, allowing users to choose the save location.

```dart
Future<PublicSavedFile?> saveBytesWithDialog({
  required Uint8List bytes,
  required String fileName,
  String mimeType = 'application/octet-stream',
  List<String>? fileSuffixChoices,  // OHOS only
})
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `bytes` | `Uint8List` | Yes | The binary data to save |
| `fileName` | `String` | Yes | Suggested file name |
| `mimeType` | `String` | No | MIME type of the file |
| `fileSuffixChoices` | `List<String>?` | No | File extension choices (OHOS only) |

**Platform Behavior:**

| Platform | Dialog Type | Returns |
|----------|-------------|---------|
| Android | Storage Access Framework (ACTION_CREATE_DOCUMENT) | `uri`: content:// URI |
| iOS | UIDocumentPickerViewController | `uri`: file:// URL, `path`: file path |
| macOS | NSSavePanel | `uri` (file://) and `path` |
| Web | Browser download (no real dialog — see notes above) | `fileName` only |
| Windows | IFileSaveDialog (COM) | `path`: full file path |
| Linux | GtkFileChooserNative | `uri` (file://) and `path` |
| OHOS | DocumentViewPicker.save | `uri` and `path` |

**Example:**

```dart
final jsonData = {'name': 'Test', 'value': 123};
final bytes = Uint8List.fromList(
  utf8.encode(jsonEncode(jsonData))
);

final result = await fileSaver.saveBytesWithDialog(
  bytes: bytes,
  fileName: 'data.json',
  mimeType: 'application/json',
);

if (result != null && result.isSuccess) {
  print('User saved file to: ${result.path ?? result.uri}');
} else {
  print('User cancelled or save failed');
}
```

---

#### `saveFile()`

Save a local `File` object to a public location.

```dart
Future<PublicSavedFile?> saveFile({
  required File file,
  String? fileName,
  String? mimeType,
  String? subDir,
  bool useDialog = false,
})
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file` | `File` | Yes | The file to save |
| `fileName` | `String?` | No | Custom file name (uses original name if not provided) |
| `mimeType` | `String?` | No | MIME type (inferred from extension if not provided) |
| `subDir` | `String?` | No | Subdirectory (non-dialog mode, Android only) |
| `useDialog` | `bool` | No | If true, shows file picker dialog |

**Example:**

```dart
import 'dart:io';

final file = File('/path/to/document.pdf');

// Save without dialog
final result = await fileSaver.saveFile(
  file: file,
  subDir: 'Documents',
);

// Save with dialog
final result = await fileSaver.saveFile(
  file: file,
  fileName: 'renamed_document.pdf',
  useDialog: true,
);
```

---

#### `saveFromUrl()`

Download a file from a URL and save it to a public location.

```dart
Future<PublicSavedFile?> saveFromUrl({
  required String url,
  String? fileName,
  String? mimeType,
  String? subDir,
  bool useDialog = false,
})
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `url` | `String` | Yes | HTTP(S) URL to download from |
| `fileName` | `String?` | No | Custom file name (inferred from URL/headers if not provided) |
| `mimeType` | `String?` | No | MIME type (inferred from Content-Type header if not provided) |
| `subDir` | `String?` | No | Subdirectory (non-dialog mode, Android only) |
| `useDialog` | `bool` | No | If true, shows file picker dialog after download |

**Example:**

```dart
// Download and save directly
final result = await fileSaver.saveFromUrl(
  url: 'https://example.com/document.pdf',
  subDir: 'Downloads',
);

// Download and show save dialog
final result = await fileSaver.saveFromUrl(
  url: 'https://example.com/image.png',
  fileName: 'my_image.png',
  useDialog: true,
);

if (result != null && result.isSuccess) {
  print('Downloaded and saved: ${result.fileName}');
}
```

---

### Return Type: `PublicSavedFile`

All save methods return `PublicSavedFile?`:

```dart
class PublicSavedFile {
  final String fileName;  // Name of the saved file
  final String? uri;      // URI of the saved file (platform-dependent)
  final String? path;     // File system path (platform-dependent)
  
  bool get isSuccess => uri != null || path != null;
}
```

**Return values by platform:**

| Platform | `uri` | `path` |
|----------|-------|--------|
| Android 10+ | content:// URI | null |
| Android 9- | null | Full file path |
| Android (dialog) | content:// URI | null |
| iOS (direct) | null | Full file path |
| iOS (dialog) | file:// URL | Full file path |
| macOS | file:// URL | Full file path |
| Web | null | null (browser-controlled) |
| Windows | null | Full file path |
| Linux | file:// URL | Full file path |
| OHOS | File URI | Converted path |

On Web, `PublicSavedFile.isSuccess` returns `false` even on success because the actual save location is not exposed to JavaScript for privacy reasons. If you only care about whether `saveBytes` was invoked without throwing, treat a non-null return value as success.

### Utility Methods

#### `sanitizeFileName()`

Sanitize file names by replacing illegal characters.

```dart
final safeName = PublicFileSaver.sanitizeFileName('file:name?.txt');
// Result: 'file_name_.txt'
```

**Replaced characters:** `\ / : * ? " < > |`

## Complete Example

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:public_file_saver/public_file_saver.dart';

class SaveFileExample extends StatefulWidget {
  @override
  _SaveFileExampleState createState() => _SaveFileExampleState();
}

class _SaveFileExampleState extends State<SaveFileExample> {
  final _fileSaver = PublicFileSaver();
  String _status = 'Ready';

  Future<void> _saveTextFile() async {
    final bytes = Uint8List.fromList(
      utf8.encode('Hello from Flutter!\nTimestamp: ${DateTime.now()}'),
    );

    final result = await _fileSaver.saveBytes(
      bytes: bytes,
      fileName: 'flutter_demo.txt',
      mimeType: 'text/plain',
    );

    setState(() {
      if (result != null && result.isSuccess) {
        _status = 'Saved: ${result.fileName}\n'
                  'URI: ${result.uri}\n'
                  'Path: ${result.path}';
      } else {
        _status = 'Save failed or cancelled';
      }
    });
  }

  Future<void> _saveWithDialog() async {
    final data = {'message': 'Hello', 'timestamp': DateTime.now().toIso8601String()};
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));

    final result = await _fileSaver.saveBytesWithDialog(
      bytes: bytes,
      fileName: 'data.json',
      mimeType: 'application/json',
    );

    setState(() {
      _status = result?.isSuccess == true 
        ? 'Saved to: ${result!.path ?? result.uri}'
        : 'Cancelled';
    });
  }

  Future<void> _downloadAndSave() async {
    try {
      final result = await _fileSaver.saveFromUrl(
        url: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        useDialog: true,
      );

      setState(() {
        _status = result?.isSuccess == true 
          ? 'Downloaded: ${result!.fileName}'
          : 'Failed';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_status),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: _saveTextFile,
          child: Text('Save Text File'),
        ),
        ElevatedButton(
          onPressed: _saveWithDialog,
          child: Text('Save with Dialog'),
        ),
        ElevatedButton(
          onPressed: _downloadAndSave,
          child: Text('Download & Save'),
        ),
      ],
    );
  }
}
```

## Error Handling

All methods return `null` when:
- User cancels the save dialog
- Save operation fails
- Required parameters are missing

For `saveFromUrl()`, network errors will throw exceptions:

```dart
try {
  final result = await fileSaver.saveFromUrl(url: 'https://example.com/file.pdf');
} catch (e) {
  print('Download failed: $e');
}
```

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please read the contributing guidelines before submitting a PR.

