#include "extension_paths.h"
#include <glib.h>
#include <dlfcn.h>

std::string RaftWebviewExtensionDirectory() {
  Dl_info info{};
  if (!dladdr(reinterpret_cast<void*>(&RaftWebviewExtensionDirectory), &info) || !info.dli_fname) return {};
  g_autofree char* library = g_canonicalize_filename(info.dli_fname, nullptr);
  g_autofree char* parent = g_path_get_dirname(library);
  g_autofree char* directory = g_build_filename(parent, "raft-webview", nullptr);
  g_autofree char* extension = g_build_filename(directory, "libraft_system_webview_extension.so", nullptr);
  return g_file_test(extension, G_FILE_TEST_IS_REGULAR) ? std::string(directory) : std::string();
}
