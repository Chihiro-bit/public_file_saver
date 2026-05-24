# public_file_saver

一个跨平台的 Flutter 插件，用于将文件保存到公开可见的位置（下载、文档目录）。支持 **Android**、**iOS**、**macOS**、**Web**、**Windows**、**Linux** 和 **鸿蒙系统 (OHOS)**。

[![pub package](https://img.shields.io/pub/v/public_file_saver.svg)](https://pub.dev/packages/public_file_saver)

[English Documentation](README.md)

## 功能特性

- ✅ 保存二进制数据（Uint8List）到公开目录
- ✅ 通过系统文件选择器对话框保存
- ✅ 保存本地文件
- ✅ 从 URL 下载并保存文件
- ✅ 自动清理非法文件名字符
- ✅ 自动推断 MIME 类型
- ✅ 所有平台统一的返回格式
- ✅ iOS 端支持 Swift Package Manager

## 平台支持

| 功能 | Android | iOS | macOS | Web | Windows | Linux | OHOS |
|------|---------|-----|-------|-----|---------|-------|------|
| `saveBytes()` | ✅ | ✅ | ✅ | ✅¹ | ✅ | ✅ | ✅ |
| `saveBytesWithDialog()` | ✅ | ✅ | ✅ | ✅¹ | ✅ | ✅ | ✅ |
| `saveFile()` | ✅ | ✅ | ✅ | ❌² | ✅ | ✅ | ✅ |
| `saveFromUrl()` | ✅ | ✅ | ✅ | ✅¹ | ✅ | ✅ | ✅ |
| `subDir` 参数 | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ |
| `fileSuffixChoices` 参数 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |

¹ Web 端两种模式都会触发浏览器的下载流程，保存位置由浏览器决定（通常是用户配置的下载目录，或者在用户启用"每次询问保存位置"时弹出系统对话框）。返回的 `PublicSavedFile` 只包含 `fileName`。

² Web 端调用 `saveFile(File)` 会抛出 `UnsupportedError`，因为浏览器没有 `dart:io` 的 `File`。请自行读取字节后调用 `saveBytes()`。

## 安装

在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  public_file_saver: ^1.1.0
```

然后运行：

```bash
flutter pub get
```

## 平台特定配置

### Android

无需额外配置。插件自动处理权限：

- **Android 10+ (API 29+)**：使用 MediaStore API，无需权限
- **Android 9 及以下**：使用公共下载目录

### iOS

如果希望用户通过"文件"应用访问保存的文件，请在 `Info.plist` 中添加以下配置：

```xml
<key>UIFileSharingEnabled</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
```

### macOS

如果你的应用启用了沙盒（Mac App Store 构建的默认状态），需要在 entitlements 中开启"用户选择的文件读写"权限，对话框模式才能写入沙盒以外的位置：

```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

未启用沙盒时无需额外配置。直接保存（无对话框）模式写入 `~/Downloads`；在沙盒环境下，系统会自动重定向到该应用容器内的 Downloads 目录。

### Web

无需额外配置。`saveBytes()` 与 `saveBytesWithDialog()` 都会触发浏览器的标准下载流程，保存位置由浏览器决定。

### Windows

无需额外配置。直接保存模式使用 `FOLDERID_Downloads`（用户标准的下载目录）；对话框模式使用原生 `IFileSaveDialog`。

### Linux

插件依赖 GTK 3，所有 Flutter Linux 应用默认就链接了 GTK，无需额外配置。直接保存模式使用 XDG 的下载目录（`g_get_user_special_dir(G_USER_DIRECTORY_DOWNLOAD)`），未配置 XDG 时回退到 `$HOME`；对话框模式使用 `GtkFileChooserNative`。

### 鸿蒙系统 (OHOS)

插件使用 `DocumentViewPicker`，无需额外权限。

## 使用方法

### 导入

```dart
import 'package:public_file_saver/public_file_saver.dart';
```

### 创建实例

```dart
final fileSaver = PublicFileSaver();
```

### API 参考

---

#### `saveBytes()`

直接将二进制数据保存到公开位置，不显示对话框。

```dart
Future<PublicSavedFile?> saveBytes({
  required Uint8List bytes,
  required String fileName,
  String mimeType = 'application/octet-stream',
  String? subDir,  // 仅 Android 支持
})
```

**参数说明：**

| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `bytes` | `Uint8List` | 是 | 要保存的二进制数据 |
| `fileName` | `String` | 是 | 期望的文件名（会自动清理非法字符） |
| `mimeType` | `String` | 否 | 文件的 MIME 类型（默认：`application/octet-stream`） |
| `subDir` | `String?` | 否 | 下载目录内的子目录（仅 Android 支持） |

**各平台行为：**

| 平台 | 保存位置 | 返回值 |
|------|----------|--------|
| Android 10+ | MediaStore 下载目录 | `uri`: content:// URI |
| Android 9- | 公共下载目录 | `path`: 完整文件路径 |
| iOS | 应用文档目录（可在"文件"应用中查看） | `path`: 完整文件路径 |
| macOS | `~/Downloads`（沙盒时会被重定向） | `uri` (file://) 和 `path` |
| Web | 浏览器下载（由浏览器决定位置） | 仅 `fileName` |
| Windows | `FOLDERID_Downloads` | `path`: 完整文件路径 |
| Linux | XDG `$HOME/Downloads` | `uri` (file://) 和 `path` |
| OHOS | 通过 DocumentViewPicker 用户选择 | `uri` 和 `path` |

**示例：**

```dart
final bytes = Uint8List.fromList(utf8.encode('你好，世界！'));

final result = await fileSaver.saveBytes(
  bytes: bytes,
  fileName: 'hello.txt',
  mimeType: 'text/plain',
  subDir: 'MyApp', // 在 Android 上创建 Downloads/MyApp/hello.txt
);

if (result != null && result.isSuccess) {
  print('已保存: ${result.fileName}');
  print('URI: ${result.uri}');
  print('路径: ${result.path}');
}
```

---

#### `saveBytesWithDialog()`

通过系统文件选择器对话框保存二进制数据，允许用户选择保存位置。

```dart
Future<PublicSavedFile?> saveBytesWithDialog({
  required Uint8List bytes,
  required String fileName,
  String mimeType = 'application/octet-stream',
  List<String>? fileSuffixChoices,  // 仅 OHOS 支持
})
```

**参数说明：**

| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `bytes` | `Uint8List` | 是 | 要保存的二进制数据 |
| `fileName` | `String` | 是 | 建议的文件名 |
| `mimeType` | `String` | 否 | 文件的 MIME 类型 |
| `fileSuffixChoices` | `List<String>?` | 否 | 文件扩展名选项（仅 OHOS 支持） |

**各平台行为：**

| 平台 | 对话框类型 | 返回值 |
|------|------------|--------|
| Android | Storage Access Framework (ACTION_CREATE_DOCUMENT) | `uri`: content:// URI |
| iOS | UIDocumentPickerViewController | `uri`: file:// URL, `path`: 文件路径 |
| macOS | NSSavePanel | `uri` (file://) 和 `path` |
| Web | 浏览器下载（无真正对话框，详见上文说明） | 仅 `fileName` |
| Windows | IFileSaveDialog (COM) | `path`: 完整文件路径 |
| Linux | GtkFileChooserNative | `uri` (file://) 和 `path` |
| OHOS | DocumentViewPicker.save | `uri` 和 `path` |

**示例：**

```dart
final jsonData = {'name': '测试', 'value': 123};
final bytes = Uint8List.fromList(
  utf8.encode(jsonEncode(jsonData))
);

final result = await fileSaver.saveBytesWithDialog(
  bytes: bytes,
  fileName: 'data.json',
  mimeType: 'application/json',
);

if (result != null && result.isSuccess) {
  print('用户保存文件到: ${result.path ?? result.uri}');
} else {
  print('用户取消或保存失败');
}
```

---

#### `saveFile()`

将本地 `File` 对象保存到公开位置。

```dart
Future<PublicSavedFile?> saveFile({
  required File file,
  String? fileName,
  String? mimeType,
  String? subDir,
  bool useDialog = false,
})
```

**参数说明：**

| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `file` | `File` | 是 | 要保存的文件 |
| `fileName` | `String?` | 否 | 自定义文件名（不提供则使用原文件名） |
| `mimeType` | `String?` | 否 | MIME 类型（不提供则从扩展名推断） |
| `subDir` | `String?` | 否 | 子目录（非对话框模式，仅 Android 支持） |
| `useDialog` | `bool` | 否 | 如果为 true，显示文件选择器对话框 |

**示例：**

```dart
import 'dart:io';

final file = File('/path/to/document.pdf');

// 不显示对话框保存
final result = await fileSaver.saveFile(
  file: file,
  subDir: 'Documents',
);

// 显示对话框保存
final result = await fileSaver.saveFile(
  file: file,
  fileName: 'renamed_document.pdf',
  useDialog: true,
);
```

---

#### `saveFromUrl()`

从 URL 下载文件并保存到公开位置。

```dart
Future<PublicSavedFile?> saveFromUrl({
  required String url,
  String? fileName,
  String? mimeType,
  String? subDir,
  bool useDialog = false,
})
```

**参数说明：**

| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `url` | `String` | 是 | 要下载的 HTTP(S) URL |
| `fileName` | `String?` | 否 | 自定义文件名（不提供则从 URL/响应头推断） |
| `mimeType` | `String?` | 否 | MIME 类型（不提供则从 Content-Type 响应头推断） |
| `subDir` | `String?` | 否 | 子目录（非对话框模式，仅 Android 支持） |
| `useDialog` | `bool` | 否 | 如果为 true，下载后显示文件选择器对话框 |

**示例：**

```dart
// 直接下载并保存
final result = await fileSaver.saveFromUrl(
  url: 'https://example.com/document.pdf',
  subDir: 'Downloads',
);

// 下载后显示保存对话框
final result = await fileSaver.saveFromUrl(
  url: 'https://example.com/image.png',
  fileName: 'my_image.png',
  useDialog: true,
);

if (result != null && result.isSuccess) {
  print('下载并保存成功: ${result.fileName}');
}
```

---

### 返回类型：`PublicSavedFile`

所有保存方法返回 `PublicSavedFile?`：

```dart
class PublicSavedFile {
  final String fileName;  // 保存的文件名
  final String? uri;      // 保存文件的 URI（取决于平台）
  final String? path;     // 文件系统路径（取决于平台）
  
  bool get isSuccess => uri != null || path != null;
}
```

**各平台返回值：**

| 平台 | `uri` | `path` |
|------|-------|--------|
| Android 10+ | content:// URI | null |
| Android 9- | null | 完整文件路径 |
| Android (对话框) | content:// URI | null |
| iOS (直接保存) | null | 完整文件路径 |
| iOS (对话框) | file:// URL | 完整文件路径 |
| macOS | file:// URL | 完整文件路径 |
| Web | null | null（由浏览器控制） |
| Windows | null | 完整文件路径 |
| Linux | file:// URL | 完整文件路径 |
| OHOS | 文件 URI | 转换后的路径 |

Web 端即使保存成功，`PublicSavedFile.isSuccess` 也会返回 `false`，因为出于隐私原因浏览器不会向 JS 暴露实际保存位置。若只关心 `saveBytes` 是否成功触发，把非 null 的返回值当作成功即可。

### 工具方法

#### `sanitizeFileName()`

清理文件名中的非法字符。

```dart
final safeName = PublicFileSaver.sanitizeFileName('file:name?.txt');
// 结果: 'file_name_.txt'
```

**被替换的字符：** `\ / : * ? " < > |`

## 完整示例

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
  String _status = '准备就绪';

  Future<void> _saveTextFile() async {
    final bytes = Uint8List.fromList(
      utf8.encode('来自 Flutter 的问候！\n时间戳: ${DateTime.now()}'),
    );

    final result = await _fileSaver.saveBytes(
      bytes: bytes,
      fileName: 'flutter_demo.txt',
      mimeType: 'text/plain',
    );

    setState(() {
      if (result != null && result.isSuccess) {
        _status = '已保存: ${result.fileName}\n'
                  'URI: ${result.uri}\n'
                  '路径: ${result.path}';
      } else {
        _status = '保存失败或已取消';
      }
    });
  }

  Future<void> _saveWithDialog() async {
    final data = {'message': '你好', 'timestamp': DateTime.now().toIso8601String()};
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));

    final result = await _fileSaver.saveBytesWithDialog(
      bytes: bytes,
      fileName: 'data.json',
      mimeType: 'application/json',
    );

    setState(() {
      _status = result?.isSuccess == true 
        ? '保存到: ${result!.path ?? result.uri}'
        : '已取消';
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
          ? '已下载: ${result!.fileName}'
          : '失败';
      });
    } catch (e) {
      setState(() {
        _status = '错误: $e';
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
          child: Text('保存文本文件'),
        ),
        ElevatedButton(
          onPressed: _saveWithDialog,
          child: Text('通过对话框保存'),
        ),
        ElevatedButton(
          onPressed: _downloadAndSave,
          child: Text('下载并保存'),
        ),
      ],
    );
  }
}
```

## 错误处理

所有方法在以下情况返回 `null`：
- 用户取消保存对话框
- 保存操作失败
- 缺少必需参数

对于 `saveFromUrl()`，网络错误会抛出异常：

```dart
try {
  final result = await fileSaver.saveFromUrl(url: 'https://example.com/file.pdf');
} catch (e) {
  print('下载失败: $e');
}
```

## 许可证

MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 贡献

欢迎贡献！请在提交 PR 前阅读贡献指南。

