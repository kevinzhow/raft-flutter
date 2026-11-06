#include "optional_backend.h"

#include <dlfcn.h>
#include <limits.h>
#include <unistd.h>
#include <utility>

namespace raft {
OptionalBackendLoader::OptionalBackendLoader(std::string directory)
    : library_directory_(std::move(directory)) {}

std::string OptionalBackendLoader::ExecutableLibraryDirectory() {
  char executable[PATH_MAX];
  const ssize_t length = readlink("/proc/self/exe", executable, sizeof(executable));
  if (length <= 0 || length == static_cast<ssize_t>(sizeof(executable))) return {};
  std::string path(executable, static_cast<size_t>(length));
  return path.substr(0, path.find_last_of('/')) + "/lib";
}

BackendResult OptionalBackendLoader::Probe(const std::string& feature) {
  std::lock_guard<std::mutex> lock(mutex_);
  const auto previous = loaded_.find(feature);
  if (previous != loaded_.end()) return previous->second;
  const char* library = nullptr;
  const char* symbol = nullptr;
  if (feature == "webkit") {
    library = "libraft_system_webview_plugin.so";
    symbol = "raft_system_webview_plugin_register_with_registrar";
  } else if (feature == "mpv") {
    library = "libmedia_kit_video_plugin.so";
    symbol = "media_kit_video_plugin_register_with_registrar";
  } else {
    return {false, "unknown_feature", "", nullptr};
  }
  if (library_directory_.empty())
    return {false, "backend_unavailable", "Application library directory unavailable", nullptr};
  void* handle = dlopen((library_directory_ + "/" + library).c_str(), RTLD_NOW | RTLD_LOCAL);
  if (!handle) {
    const char* error = dlerror();
    // No failed probe is cached: installing a missing dependency can be retried.
    return {false, "dependency_unavailable", error ? error : "Native dependency unavailable", nullptr};
  }
  dlerror();
  auto registration = reinterpret_cast<Registration>(dlsym(handle, symbol));
  const char* error = dlerror();
  if (error || !registration) {
    const std::string detail = error ? error : "Plugin registration unavailable";
    dlclose(handle);  // Registration was never called; no engine owns this module.
    return {false, "backend_invalid", detail, nullptr};
  }
  BackendResult ready{true, "available", "", registration};
  loaded_.emplace(feature, ready);
  // No dlclose: unloading registered GTypes is unsafe across engine lifetimes.
  return ready;
}

BackendResult EngineBackends::Ensure(const std::string& feature,
                                    _FlPluginRegistrar* registrar) {
  BackendResult result = loader_.Probe(feature);
  if (result.available && !Registered(feature)) {
    result.registration(registrar);
    registered_.insert(feature);
  }
  return result;
}

bool EngineBackends::Registered(const std::string& feature) const {
  return registered_.count(feature) != 0;
}
}  // namespace raft
