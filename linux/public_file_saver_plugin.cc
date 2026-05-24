#include "include/public_file_saver/public_file_saver_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/stat.h>

#include <cerrno>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

#define PUBLIC_FILE_SAVER_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), public_file_saver_plugin_get_type(), \
                              PublicFileSaverPlugin))

struct _PublicFileSaverPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(PublicFileSaverPlugin, public_file_saver_plugin, G_TYPE_OBJECT)

namespace {

// Returns a newly-allocated string with each occurrence of the path separator
// removed from the end, or g_strdup of the input if it has none.
gchar* StripTrailingSlash(const gchar* path) {
  gsize len = strlen(path);
  while (len > 1 && path[len - 1] == G_DIR_SEPARATOR) --len;
  return g_strndup(path, len);
}

// Builds {fileName,uri,path} as an FlValue map (transfer-full).
FlValue* BuildResultMap(const gchar* path) {
  g_autoptr(GFile) file = g_file_new_for_path(path);
  g_autofree gchar* uri = g_file_get_uri(file);
  g_autofree gchar* basename = g_path_get_basename(path);

  FlValue* map = fl_value_new_map();
  fl_value_set_string_take(map, "fileName", fl_value_new_string(basename));
  fl_value_set_string_take(map, "uri", fl_value_new_string(uri));
  fl_value_set_string_take(map, "path", fl_value_new_string(path));
  return map;
}

// Produces a non-colliding path inside `dir` by appending (1), (2), ... before
// the extension when the target already exists.
gchar* UniquePath(const gchar* dir, const gchar* file_name) {
  g_autofree gchar* candidate = g_build_filename(dir, file_name, nullptr);
  if (!g_file_test(candidate, G_FILE_TEST_EXISTS)) {
    return g_strdup(candidate);
  }

  const gchar* dot = strrchr(file_name, '.');
  std::string stem;
  std::string ext;
  if (dot == nullptr || dot == file_name) {
    stem = file_name;
  } else {
    stem.assign(file_name, dot - file_name);
    ext.assign(dot);
  }

  int counter = 1;
  while (true) {
    std::string next = stem + "(" + std::to_string(counter) + ")" + ext;
    g_autofree gchar* next_path = g_build_filename(dir, next.c_str(), nullptr);
    if (!g_file_test(next_path, G_FILE_TEST_EXISTS)) {
      return g_strdup(next_path);
    }
    ++counter;
  }
}

bool WriteBytes(const gchar* path, const uint8_t* data, gsize size,
                GError** error) {
  return g_file_set_contents(path, reinterpret_cast<const gchar*>(data),
                             static_cast<gssize>(size), error) == TRUE;
}

void HandleSaveBytes(FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
        fl_method_error_response_new("INVALID_ARGUMENTS",
                                     "Arguments must be a map", nullptr));
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }

  FlValue* bytes_val = fl_value_lookup_string(args, "bytes");
  FlValue* name_val = fl_value_lookup_string(args, "fileName");
  FlValue* sub_dir_val = fl_value_lookup_string(args, "subDir");

  if (bytes_val == nullptr ||
      fl_value_get_type(bytes_val) != FL_VALUE_TYPE_UINT8_LIST ||
      name_val == nullptr ||
      fl_value_get_type(name_val) != FL_VALUE_TYPE_STRING) {
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
        fl_method_error_response_new("INVALID_ARGUMENTS",
                                     "bytes and fileName are required",
                                     nullptr));
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }

  const gchar* file_name = fl_value_get_string(name_val);
  const gchar* sub_dir =
      (sub_dir_val != nullptr &&
       fl_value_get_type(sub_dir_val) == FL_VALUE_TYPE_STRING)
          ? fl_value_get_string(sub_dir_val)
          : nullptr;

  const gchar* downloads =
      g_get_user_special_dir(G_USER_DIRECTORY_DOWNLOAD);
  if (downloads == nullptr) {
    downloads = g_get_home_dir();
  }
  if (downloads == nullptr) {
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
        fl_method_error_response_new("NO_DOWNLOADS",
                                     "Could not resolve Downloads directory",
                                     nullptr));
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }

  g_autofree gchar* target_dir =
      (sub_dir != nullptr && *sub_dir != '\0')
          ? g_build_filename(downloads, sub_dir, nullptr)
          : StripTrailingSlash(downloads);

  if (g_mkdir_with_parents(target_dir, 0755) != 0) {
    g_autofree gchar* msg =
        g_strdup_printf("mkdir failed: %s", g_strerror(errno));
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
        fl_method_error_response_new("MKDIR_FAILED", msg, nullptr));
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }

  g_autofree gchar* dest = UniquePath(target_dir, file_name);

  g_autoptr(GError) error = nullptr;
  const uint8_t* data = fl_value_get_uint8_list(bytes_val);
  gsize size = fl_value_get_length(bytes_val);
  if (!WriteBytes(dest, data, size, &error)) {
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
        fl_method_error_response_new(
            "SAVE_FAILED", error != nullptr ? error->message : "Write failed",
            nullptr));
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }

  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_success_response_new(BuildResultMap(dest)));
  fl_method_call_respond(method_call, response, nullptr);
}

void HandleSaveBytesWithDialog(FlMethodCall* method_call,
                               FlPluginRegistrar* registrar) {
  FlValue* args = fl_method_call_get_args(method_call);
  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
        fl_method_error_response_new("INVALID_ARGUMENTS",
                                     "Arguments must be a map", nullptr));
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }

  FlValue* bytes_val = fl_value_lookup_string(args, "bytes");
  FlValue* name_val = fl_value_lookup_string(args, "fileName");
  if (bytes_val == nullptr ||
      fl_value_get_type(bytes_val) != FL_VALUE_TYPE_UINT8_LIST ||
      name_val == nullptr ||
      fl_value_get_type(name_val) != FL_VALUE_TYPE_STRING) {
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
        fl_method_error_response_new("INVALID_ARGUMENTS",
                                     "bytes and fileName are required",
                                     nullptr));
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }

  const gchar* suggested = fl_value_get_string(name_val);

  FlView* view = fl_plugin_registrar_get_view(registrar);
  GtkWindow* parent_window = nullptr;
  if (view != nullptr) {
    GtkWidget* toplevel = gtk_widget_get_toplevel(GTK_WIDGET(view));
    if (toplevel != nullptr && gtk_widget_is_toplevel(toplevel)) {
      parent_window = GTK_WINDOW(toplevel);
    }
  }

  GtkFileChooserNative* dialog = gtk_file_chooser_native_new(
      "Save file", parent_window, GTK_FILE_CHOOSER_ACTION_SAVE, "_Save",
      "_Cancel");
  GtkFileChooser* chooser = GTK_FILE_CHOOSER(dialog);
  gtk_file_chooser_set_do_overwrite_confirmation(chooser, TRUE);
  gtk_file_chooser_set_current_name(chooser, suggested);
  const gchar* downloads =
      g_get_user_special_dir(G_USER_DIRECTORY_DOWNLOAD);
  if (downloads != nullptr) {
    gtk_file_chooser_set_current_folder(chooser, downloads);
  }

  gint response_id =
      gtk_native_dialog_run(GTK_NATIVE_DIALOG(dialog));

  if (response_id != GTK_RESPONSE_ACCEPT) {
    g_object_unref(dialog);
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }

  g_autofree gchar* dest = gtk_file_chooser_get_filename(chooser);
  g_object_unref(dialog);

  if (dest == nullptr) {
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }

  g_autoptr(GError) error = nullptr;
  const uint8_t* data = fl_value_get_uint8_list(bytes_val);
  gsize size = fl_value_get_length(bytes_val);
  if (!WriteBytes(dest, data, size, &error)) {
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
        fl_method_error_response_new(
            "SAVE_FAILED", error != nullptr ? error->message : "Write failed",
            nullptr));
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }

  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_success_response_new(BuildResultMap(dest)));
  fl_method_call_respond(method_call, response, nullptr);
}

void MethodCallCb(FlMethodChannel* /*channel*/, FlMethodCall* method_call,
                  gpointer user_data) {
  FlPluginRegistrar* registrar = FL_PLUGIN_REGISTRAR(user_data);
  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "saveBytes") == 0) {
    HandleSaveBytes(method_call);
  } else if (strcmp(method, "saveBytesWithDialog") == 0) {
    HandleSaveBytesWithDialog(method_call, registrar);
  } else {
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    fl_method_call_respond(method_call, response, nullptr);
  }
}

}  // namespace

static void public_file_saver_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(public_file_saver_plugin_parent_class)->dispose(object);
}

static void public_file_saver_plugin_class_init(
    PublicFileSaverPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = public_file_saver_plugin_dispose;
}

static void public_file_saver_plugin_init(PublicFileSaverPlugin* /*self*/) {}

void public_file_saver_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  PublicFileSaverPlugin* plugin = PUBLIC_FILE_SAVER_PLUGIN(
      g_object_new(public_file_saver_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "public_file_saver", FL_METHOD_CODEC(codec));
  // The channel keeps a strong reference to `registrar` (g_object_ref) via the
  // user_data hook; releasing it when the channel is destroyed.
  fl_method_channel_set_method_call_handler(
      channel, MethodCallCb, g_object_ref(registrar), g_object_unref);

  g_object_unref(plugin);
}
