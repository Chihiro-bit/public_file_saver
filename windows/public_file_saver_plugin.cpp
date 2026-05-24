#include "public_file_saver_plugin.h"

// Windows headers.
#include <windows.h>
#include <shlobj.h>
#include <shobjidl.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <filesystem>
#include <fstream>
#include <memory>
#include <string>
#include <vector>

namespace public_file_saver {

namespace {

// UTF-8 -> wide string.
std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  int size_needed = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(),
                                        static_cast<int>(utf8.size()),
                                        nullptr, 0);
  std::wstring wide(size_needed, 0);
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(),
                      static_cast<int>(utf8.size()),
                      wide.data(), size_needed);
  return wide;
}

// Wide string -> UTF-8.
std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) return std::string();
  int size_needed = WideCharToMultiByte(CP_UTF8, 0, wide.c_str(),
                                        static_cast<int>(wide.size()),
                                        nullptr, 0, nullptr, nullptr);
  std::string utf8(size_needed, 0);
  WideCharToMultiByte(CP_UTF8, 0, wide.c_str(),
                      static_cast<int>(wide.size()),
                      utf8.data(), size_needed, nullptr, nullptr);
  return utf8;
}

// Returns FOLDERID_Downloads as a wide-character path. Empty on failure.
std::wstring GetDownloadsFolder() {
  PWSTR path = nullptr;
  HRESULT hr = SHGetKnownFolderPath(FOLDERID_Downloads, 0, nullptr, &path);
  if (FAILED(hr)) {
    if (path) CoTaskMemFree(path);
    return std::wstring();
  }
  std::wstring result(path);
  CoTaskMemFree(path);
  return result;
}

// Produces a non-colliding file path inside `dir` by appending (1), (2), ...
// before the extension when the target already exists.
std::filesystem::path GetUniquePath(const std::filesystem::path& dir,
                                    const std::wstring& file_name) {
  std::filesystem::path candidate = dir / file_name;
  if (!std::filesystem::exists(candidate)) return candidate;

  std::filesystem::path stem = candidate.stem();
  std::wstring ext = candidate.extension().wstring();
  int counter = 1;
  while (true) {
    std::wstring next = stem.wstring() + L"(" + std::to_wstring(counter) + L")" + ext;
    std::filesystem::path next_path = dir / next;
    if (!std::filesystem::exists(next_path)) return next_path;
    ++counter;
  }
}

bool WriteBytes(const std::filesystem::path& path,
                const std::vector<uint8_t>& bytes) {
  std::ofstream out(path, std::ios::binary | std::ios::trunc);
  if (!out) return false;
  if (!bytes.empty()) {
    out.write(reinterpret_cast<const char*>(bytes.data()),
              static_cast<std::streamsize>(bytes.size()));
  }
  return out.good();
}

flutter::EncodableMap BuildResult(const std::filesystem::path& path) {
  flutter::EncodableMap map;
  map[flutter::EncodableValue("fileName")] =
      flutter::EncodableValue(WideToUtf8(path.filename().wstring()));
  map[flutter::EncodableValue("uri")] = flutter::EncodableValue();
  map[flutter::EncodableValue("path")] =
      flutter::EncodableValue(WideToUtf8(path.wstring()));
  return map;
}

// Splits "name.ext" into ("name", L".ext"); returns ("name", L"") if no dot.
std::pair<std::wstring, std::wstring> SplitName(const std::wstring& file_name) {
  size_t dot = file_name.find_last_of(L'.');
  if (dot == std::wstring::npos || dot == 0) {
    return {file_name, L""};
  }
  return {file_name.substr(0, dot), file_name.substr(dot)};
}

// Shows IFileSaveDialog. On success, sets `out_path` and returns S_OK.
// Returns S_FALSE if the user cancelled. Any other HRESULT is a real error.
HRESULT ShowSaveDialog(const std::wstring& suggested_name,
                       HWND owner,
                       std::wstring* out_path) {
  IFileSaveDialog* dialog = nullptr;
  HRESULT hr = CoCreateInstance(CLSID_FileSaveDialog, nullptr,
                                CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&dialog));
  if (FAILED(hr)) return hr;

  // Default the dialog to the suggested file name (and its extension).
  auto [stem, ext] = SplitName(suggested_name);
  if (!suggested_name.empty()) {
    dialog->SetFileName(suggested_name.c_str());
  }
  std::wstring ext_no_dot;
  std::wstring pattern;
  if (!ext.empty() && ext.size() > 1) {
    ext_no_dot = ext.substr(1);
    pattern = L"*." + ext_no_dot;
    COMDLG_FILTERSPEC filter[] = {
        {L"Selected type", pattern.c_str()},
        {L"All files", L"*.*"},
    };
    dialog->SetFileTypes(2, filter);
    dialog->SetDefaultExtension(ext_no_dot.c_str());
  }

  hr = dialog->Show(owner);
  if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
    dialog->Release();
    return S_FALSE;
  }
  if (FAILED(hr)) {
    dialog->Release();
    return hr;
  }

  IShellItem* item = nullptr;
  hr = dialog->GetResult(&item);
  if (FAILED(hr) || !item) {
    if (item) item->Release();
    dialog->Release();
    return FAILED(hr) ? hr : E_FAIL;
  }

  PWSTR raw = nullptr;
  hr = item->GetDisplayName(SIGDN_FILESYSPATH, &raw);
  if (SUCCEEDED(hr) && raw) {
    *out_path = raw;
    CoTaskMemFree(raw);
  }
  item->Release();
  dialog->Release();
  return hr;
}

}  // namespace

// static
void PublicFileSaverPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "public_file_saver",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<PublicFileSaverPlugin>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

PublicFileSaverPlugin::PublicFileSaverPlugin(
    flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {}

PublicFileSaverPlugin::~PublicFileSaverPlugin() = default;

void PublicFileSaverPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();
  const auto* args =
      std::get_if<flutter::EncodableMap>(method_call.arguments());
  if (!args) {
    result->Error("INVALID_ARGUMENTS", "Arguments must be a map");
    return;
  }

  auto get_bytes = [&](std::vector<uint8_t>* out) -> bool {
    auto it = args->find(flutter::EncodableValue("bytes"));
    if (it == args->end()) return false;
    const auto* vec = std::get_if<std::vector<uint8_t>>(&it->second);
    if (!vec) return false;
    *out = *vec;
    return true;
  };

  auto get_string = [&](const char* key, std::string* out) -> bool {
    auto it = args->find(flutter::EncodableValue(key));
    if (it == args->end()) return false;
    const auto* s = std::get_if<std::string>(&it->second);
    if (!s) return false;
    *out = *s;
    return true;
  };

  std::vector<uint8_t> bytes;
  std::string file_name_utf8;
  if (!get_bytes(&bytes) || !get_string("fileName", &file_name_utf8)) {
    result->Error("INVALID_ARGUMENTS", "bytes and fileName are required");
    return;
  }
  std::wstring file_name = Utf8ToWide(file_name_utf8);

  if (method == "saveBytes") {
    std::wstring downloads = GetDownloadsFolder();
    if (downloads.empty()) {
      result->Error("NO_DOWNLOADS",
                    "Could not locate the user's Downloads folder");
      return;
    }
    std::filesystem::path target_dir = downloads;

    std::string sub_dir_utf8;
    if (get_string("subDir", &sub_dir_utf8) && !sub_dir_utf8.empty()) {
      target_dir /= Utf8ToWide(sub_dir_utf8);
      std::error_code ec;
      std::filesystem::create_directories(target_dir, ec);
      if (ec) {
        result->Error("MKDIR_FAILED", ec.message());
        return;
      }
    }

    std::filesystem::path file_path = GetUniquePath(target_dir, file_name);
    if (!WriteBytes(file_path, bytes)) {
      result->Error("SAVE_FAILED", "Failed to write file");
      return;
    }
    result->Success(flutter::EncodableValue(BuildResult(file_path)));
    return;
  }

  if (method == "saveBytesWithDialog") {
    HWND owner = registrar_->GetView() ? registrar_->GetView()->GetNativeWindow()
                                       : nullptr;

    HRESULT co_init = CoInitializeEx(
        nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
    bool initialized_com = SUCCEEDED(co_init);

    std::wstring chosen;
    HRESULT hr = ShowSaveDialog(file_name, owner, &chosen);

    if (initialized_com) CoUninitialize();

    if (hr == S_FALSE || chosen.empty()) {
      result->Success();  // User cancelled.
      return;
    }
    if (FAILED(hr)) {
      result->Error("DIALOG_FAILED",
                    "Save dialog failed with HRESULT " +
                        std::to_string(static_cast<unsigned long>(hr)));
      return;
    }

    std::filesystem::path file_path = chosen;
    if (!WriteBytes(file_path, bytes)) {
      result->Error("SAVE_FAILED", "Failed to write file");
      return;
    }
    result->Success(flutter::EncodableValue(BuildResult(file_path)));
    return;
  }

  result->NotImplemented();
}

}  // namespace public_file_saver
