#ifndef FLUTTER_PLUGIN_PUBLIC_FILE_SAVER_PLUGIN_H_
#define FLUTTER_PLUGIN_PUBLIC_FILE_SAVER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace public_file_saver {

class PublicFileSaverPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit PublicFileSaverPlugin(flutter::PluginRegistrarWindows* registrar);
  virtual ~PublicFileSaverPlugin();

  PublicFileSaverPlugin(const PublicFileSaverPlugin&) = delete;
  PublicFileSaverPlugin& operator=(const PublicFileSaverPlugin&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::PluginRegistrarWindows* registrar_;
};

}  // namespace public_file_saver

#endif  // FLUTTER_PLUGIN_PUBLIC_FILE_SAVER_PLUGIN_H_
