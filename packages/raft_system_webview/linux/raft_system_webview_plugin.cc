#include "include/raft_system_webview/raft_system_webview_plugin.h"
#include "native_host.h"
#include "native_view.h"
#include <map>
#include <memory>

struct PluginState {
  explicit PluginState(FlPluginRegistrar* registrar)
    : host(fl_plugin_registrar_get_view(registrar)), messenger(fl_plugin_registrar_get_messenger(registrar)) {}
  ~PluginState() {
    for (auto& pair : views) { pair.second->SetRetire(nullptr); pair.second->Close(); }
  }
  NativeHost host;
  FlBinaryMessenger* messenger;
  int64_t next = 1;
  std::map<int64_t, std::shared_ptr<NativeView>> views;
};

static void Method(FlMethodChannel*, FlMethodCall* call, gpointer data) {
  auto* state = static_cast<PluginState*>(data);
  g_autoptr(FlMethodResponse) response = nullptr;
  if (g_str_equal(fl_method_call_get_name(call), "create")) {
    auto view = std::make_shared<NativeView>(state->next, &state->host, state->messenger);
    if (view->ready()) {
      int64_t id = state->next++;
      view->Bind(); state->views[id] = view;
      view->SetRetire([state, id]() { state->views.erase(id); });
      g_autoptr(FlValue) result = fl_value_new_map();
      fl_value_set_string_take(result, "id", fl_value_new_int(id));
      fl_value_set_string_take(result, "protocol", fl_value_new_int(1));
      fl_value_set_string_take(result, "ephemeral", fl_value_new_bool(true));
      fl_value_set_string_take(result, "sandboxed", fl_value_new_bool(true));
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
    } else response = FL_METHOD_RESPONSE(fl_method_error_response_new("isolation_unavailable", "A sandboxed system renderer is unavailable.", nullptr));
  } else response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  fl_method_call_respond(call, response, nullptr);
}
void raft_system_webview_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  auto* state = new PluginState(registrar);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(state->messenger, "app.raft/system_webview", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, Method, state,
    [](gpointer value) { delete static_cast<PluginState*>(value); });
}
