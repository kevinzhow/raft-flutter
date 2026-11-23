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
    g_clear_object(&browser_context);
  }
  NativeHost host;
  FlBinaryMessenger* messenger;
  int64_t next = 1;
  std::map<int64_t, std::shared_ptr<NativeView>> views;
  WebKitWebContext* browser_context = nullptr;
  size_t browser_count = 0;
};

static void Method(FlMethodChannel*, FlMethodCall* call, gpointer data) {
  auto* state = static_cast<PluginState*>(data);
  g_autoptr(FlMethodResponse) response = nullptr;
  const char* method = fl_method_call_get_name(call);
  const bool browsing = g_str_equal(method, "createBrowser");
  if (browsing || g_str_equal(method, "create")) {
    std::set<std::string> blocked_hosts;
    if (browsing) {
      FlValue* args = fl_method_call_get_args(call);
      FlValue* hosts = args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP
          ? fl_value_lookup_string(args, "blockedHosts") : nullptr;
      if (!hosts || fl_value_get_type(hosts) != FL_VALUE_TYPE_LIST ||
          state->browser_count >= 12) {
        response = FL_METHOD_RESPONSE(fl_method_error_response_new(
            "invalid_browser", "The browser view could not be created.", nullptr));
        fl_method_call_respond(call, response, nullptr);
        return;
      }
      for (size_t index = 0; index < fl_value_get_length(hosts); ++index) {
        FlValue* host = fl_value_get_list_value(hosts, index);
        if (fl_value_get_type(host) == FL_VALUE_TYPE_STRING) {
          g_autofree char* lowercase = g_ascii_strdown(fl_value_get_string(host), -1);
          blocked_hosts.emplace(lowercase);
        }
      }
      if (!state->browser_context) {
        state->browser_context = webkit_web_context_new_ephemeral();
        webkit_web_context_set_sandbox_enabled(state->browser_context, TRUE);
      }
    }
    auto view = std::make_shared<NativeView>(
        state->next, &state->host, state->messenger,
        browsing ? state->browser_context : nullptr, std::move(blocked_hosts));
    if (view->ready()) {
      int64_t id = state->next++;
      view->Bind(); state->views[id] = view;
      if (browsing) ++state->browser_count;
      view->SetRetire([state, id, browsing]() {
        state->views.erase(id);
        if (browsing && --state->browser_count == 0) g_clear_object(&state->browser_context);
      });
      g_autoptr(FlValue) result = fl_value_new_map();
      fl_value_set_string_take(result, "id", fl_value_new_int(id));
      fl_value_set_string_take(result, "protocol", fl_value_new_int(1));
      fl_value_set_string_take(result, "snapshot", fl_value_new_bool(true));
      if (browsing) fl_value_set_string_take(result, "browser", fl_value_new_bool(true));
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
