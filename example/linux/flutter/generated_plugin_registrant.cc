//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <public_file_saver/public_file_saver_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) public_file_saver_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "PublicFileSaverPlugin");
  public_file_saver_plugin_register_with_registrar(public_file_saver_registrar);
}
