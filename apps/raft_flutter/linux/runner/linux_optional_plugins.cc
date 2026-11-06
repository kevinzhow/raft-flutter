#include "linux_optional_plugins.h"
#include "optional_backend.h"

#include <array>
#include <map>
#include <string>

namespace {
constexpr std::array<const char*, 3> kFeatures = {"webkit", "mpv", "poppler"};

raft::OptionalBackendLoader& Loader() {
  static auto* loader = new raft::OptionalBackendLoader(
      raft::OptionalBackendLoader::ExecutableLibraryDirectory());
  return *loader;
}

struct State {
  explicit State(FlPluginRegistry* registry) : engines(Loader()) {
    g_weak_ref_init(&engine, G_OBJECT(registry));
  }
  ~State() { g_weak_ref_clear(&engine); }
  GWeakRef engine;
  raft::EngineBackends engines;
  std::map<std::string, raft::BackendResult> known;
};

FlValue* Distro() {
  FlValue* value = fl_value_new_map();
  g_autofree gchar* contents = nullptr;
  std::map<std::string, std::string> fields;
  if (g_file_get_contents("/etc/os-release", &contents, nullptr, nullptr)) {
    g_auto(GStrv) lines = g_strsplit(contents, "\n", -1);
    for (gchar** line = lines; *line; ++line) {
      const std::string text(*line);
      const auto equal = text.find('=');
      if (equal == std::string::npos) continue;
      std::string content = text.substr(equal + 1);
      if (content.size() >= 2 && ((content.front() == '"' && content.back() == '"') ||
                                (content.front() == '\'' && content.back() == '\'')))
        content = content.substr(1, content.size() - 2);
      fields[text.substr(0, equal)] = content;
    }
  }
  for (const auto& pair : {std::make_pair("id", "ID"),
                           std::make_pair("idLike", "ID_LIKE"),
                           std::make_pair("versionId", "VERSION_ID")})
    fl_value_set_string_take(value, pair.first, fl_value_new_string(fields[pair.second].c_str()));
  return value;
}

FlValue* Result(State* state) {
  FlValue* result = fl_value_new_map();
  fl_value_set_string_take(result, "protocol", fl_value_new_int(1));
  fl_value_set_string_take(result, "distro", Distro());
  FlValue* features = fl_value_new_map();
  for (const char* name : kFeatures) {
    FlValue* row = fl_value_new_map();
    const auto found = state->known.find(name);
    const bool checked = found != state->known.end();
    const bool available = checked && found->second.available;
    fl_value_set_string_take(row, "status", fl_value_new_string(
        !checked ? "unchecked" : available ? "available" : "missing"));
    fl_value_set_string_take(row, "available", fl_value_new_bool(available));
    fl_value_set_string_take(row, "registered", fl_value_new_bool(state->engines.Registered(name)));
    fl_value_set_string_take(row, "requiresRestart", fl_value_new_bool(false));
    fl_value_set_string_take(row, "reason", fl_value_new_string(checked ? found->second.reason.c_str() : "unchecked"));
    if (checked && !found->second.detail.empty())
      fl_value_set_string_take(row, "detail", fl_value_new_string(found->second.detail.c_str()));
    fl_value_set_string_take(features, name, row);
  }
  fl_value_set_string_take(result, "features", features);
  return result;
}

raft::BackendResult Poppler() {
  g_autofree gchar* info = g_find_program_in_path("pdfinfo");
  g_autofree gchar* render = g_find_program_in_path("pdftoppm");
  return {info && render, info && render ? "available" : "dependency_unavailable",
          info && render ? "" : "pdfinfo and pdftoppm are required", nullptr};
}

void Method(FlMethodChannel*, FlMethodCall* call, gpointer data) {
  auto* state = static_cast<State*>(data);
  const std::string method(fl_method_call_get_name(call));
  if (method != "inspect" && method != "ensure") {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  }
  FlValue* args = fl_method_call_get_args(call);
  const bool invalid_args = args && fl_value_get_type(args) != FL_VALUE_TYPE_NULL &&
      fl_value_get_type(args) != FL_VALUE_TYPE_MAP;
  FlValue* feature = args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP
      ? fl_value_lookup_string(args, "feature") : nullptr;
  const bool has_feature = feature && fl_value_get_type(feature) == FL_VALUE_TYPE_STRING;
  const std::string name = has_feature ? fl_value_get_string(feature) : "";
  if (invalid_args || (feature && name.empty()) ||
      (!name.empty() && name != "webkit" && name != "mpv" && name != "poppler") ||
      (feature && !has_feature) || (method == "ensure" && name.empty())) {
    fl_method_call_respond_error(call, "invalid_arguments", "A known feature is required", nullptr, nullptr);
    return;
  }
  if (!name.empty()) {
    if (name == "poppler") state->known[name] = Poppler();
    else if (method == "inspect") state->known[name] = Loader().Probe(name);
    else {
      g_autoptr(GObject) engine = G_OBJECT(g_weak_ref_get(&state->engine));
      if (!engine) {
        fl_method_call_respond_error(call, "engine_closed", "The Flutter engine has closed", nullptr, nullptr);
        return;
      }
      const char* plugin = name == "webkit" ? "RaftSystemWebviewPlugin" : "MediaKitVideoPlugin";
      g_autoptr(FlPluginRegistrar) registrar =
          fl_plugin_registry_get_registrar_for_plugin(FL_PLUGIN_REGISTRY(engine), plugin);
      if (!registrar) {
        fl_method_call_respond_error(call, "engine_closed", "Plugin registrar unavailable", nullptr, nullptr);
        return;
      }
      state->known[name] = state->engines.Ensure(name, registrar);
    }
  }
  g_autoptr(FlValue) value = Result(state);
  fl_method_call_respond_success(call, value, nullptr);
}
}  // namespace

void raft_register_optional_linux_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "RaftLinuxDependencies");
  auto* state = new State(registry);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "app.raft/linux_dependencies", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, Method, state,
      [](gpointer data) { delete static_cast<State*>(data); });
}
