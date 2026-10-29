// WinSparkle bridge for Raft (method channel `app.raft/updater`).
//
// WinSparkle downloads an installer (.exe/.msi), verifies its EdDSA signature
// against the public key supplied by Dart, asks the app to shut down through
// the callback below and then runs the installer. See docs/auto-update.md.
#include "include/raft_updater/raft_updater_plugin.h"
#include "include/raft_updater/window_lifetime.h"

#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <winsparkle.h>

#include <atomic>
#include <memory>
#include <string>

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;

std::atomic<HWND> g_main_window{nullptr};
bool g_initialised = false;

std::wstring Widen(const std::string& text) {
  if (text.empty()) return L"";
  int size = MultiByteToWideChar(CP_UTF8, 0, text.c_str(),
                                 static_cast<int>(text.size()), nullptr, 0);
  std::wstring wide(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()),
                      &wide[0], size);
  return wide;
}

std::string StringArgument(const EncodableMap& arguments, const char* name) {
  auto found = arguments.find(EncodableValue(name));
  if (found == arguments.end()) return "";
  const auto* value = std::get_if<std::string>(&found->second);
  return value ? *value : "";
}

EncodableValue Result(bool available, const std::string& reason = "") {
  EncodableMap map;
  map[EncodableValue("available")] = EncodableValue(available);
  if (!reason.empty()) map[EncodableValue("reason")] = EncodableValue(reason);
  return EncodableValue(map);
}

// WinSparkle calls these on its own worker thread.
int __cdecl CanShutdown() { return 1; }

void __cdecl ShutdownRequested() {
  // Explicit exit, distinct from a user's close-to-tray preference.
  HWND window = g_main_window.load();
  if (window != nullptr) {
    RequestRaftQuit(GetAncestor(window, GA_ROOT));
  }
}

class RaftUpdaterPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
    auto channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
        registrar->messenger(), "app.raft/updater",
        &flutter::StandardMethodCodec::GetInstance());
    auto plugin = std::make_unique<RaftUpdaterPlugin>(registrar);
    channel->SetMethodCallHandler([plugin = plugin.get()](const auto& call, auto result) {
      plugin->Handle(call, std::move(result));
    });
    registrar->AddPlugin(std::move(plugin));
  }

  explicit RaftUpdaterPlugin(flutter::PluginRegistrarWindows* registrar)
      : registrar_(registrar) {}

  ~RaftUpdaterPlugin() override {
    if (g_initialised) {
      win_sparkle_cleanup();
      g_initialised = false;
    }
  }

 private:
  void Handle(const flutter::MethodCall<EncodableValue>& call,
              std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
    if (call.method_name() == "configure") {
      const auto* arguments = std::get_if<EncodableMap>(call.arguments());
      result->Success(Configure(arguments ? *arguments : EncodableMap()));
    } else if (call.method_name() == "checkForUpdates") {
      if (!g_initialised) {
        result->Success(EncodableValue(false));
        return;
      }
      win_sparkle_check_update_with_ui();  // WinSparkle shows the UI
      result->Success(EncodableValue(true));
    } else {
      result->NotImplemented();
    }
  }

  EncodableValue Configure(const EncodableMap& arguments) {
    if (g_initialised) return Result(true);
    const std::string feed = StringArgument(arguments, "feedUrl");
    const std::string key = StringArgument(arguments, "publicKey");
    const std::string build = StringArgument(arguments, "buildNumber");
    const std::string version = StringArgument(arguments, "version");
    // https only; loopback http is for local rehearsals.
    if (feed.rfind("https://", 0) != 0 && feed.rfind("http://localhost", 0) != 0 &&
        feed.rfind("http://127.0.0.1", 0) != 0) {
      return Result(false, "The update feed must be an https URL.");
    }
    if (build.empty()) return Result(false, "The build number is unknown.");
    // Only an EdDSA-signed update can be installed.
    if (win_sparkle_set_eddsa_public_key(key.c_str()) != 1) {
      return Result(false, "The EdDSA public key is missing or invalid.");
    }
    if (auto* view = registrar_->GetView()) {
      g_main_window.store(view->GetNativeWindow());
    }
    win_sparkle_set_appcast_url(feed.c_str());
    win_sparkle_set_registry_path("Software\\app.raft\\Raft\\WinSparkle");
    const std::wstring wide_version = Widen(version.empty() ? build : version);
    win_sparkle_set_app_details(L"app.raft", L"Raft", wide_version.c_str());
    // sparkle:version in the appcast is the build number.
    win_sparkle_set_app_build_version(Widen(build).c_str());
    // The app decides when to check (update-available dot); no scheduled
    // checks and no first-run "check automatically?" prompt.
    win_sparkle_set_automatic_check_for_updates(0);
    win_sparkle_set_can_shutdown_callback(CanShutdown);
    win_sparkle_set_shutdown_request_callback(ShutdownRequested);
    win_sparkle_init();
    g_initialised = true;
    return Result(true);
  }

  flutter::PluginRegistrarWindows* registrar_;
};

}  // namespace

void RaftUpdaterPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  RaftUpdaterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
