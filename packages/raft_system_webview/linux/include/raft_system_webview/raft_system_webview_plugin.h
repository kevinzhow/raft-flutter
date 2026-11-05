#ifndef RAFT_SYSTEM_WEBVIEW_PLUGIN_H_
#define RAFT_SYSTEM_WEBVIEW_PLUGIN_H_
#include <flutter_linux/flutter_linux.h>
G_BEGIN_DECLS
#ifdef FLUTTER_PLUGIN_IMPL
#define RAFT_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define RAFT_PLUGIN_EXPORT
#endif
RAFT_PLUGIN_EXPORT void raft_system_webview_plugin_register_with_registrar(FlPluginRegistrar* registrar);
G_END_DECLS
#endif
