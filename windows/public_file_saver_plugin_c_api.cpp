#include "include/public_file_saver/public_file_saver_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "public_file_saver_plugin.h"

void PublicFileSaverPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  public_file_saver::PublicFileSaverPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
