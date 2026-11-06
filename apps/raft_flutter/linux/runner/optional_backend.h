#ifndef RAFT_OPTIONAL_BACKEND_H_
#define RAFT_OPTIONAL_BACKEND_H_

#include <map>
#include <mutex>
#include <set>
#include <string>

struct _FlPluginRegistrar;

namespace raft {
using Registration = void (*)(_FlPluginRegistrar*);

struct BackendResult {
  bool available = false;
  std::string reason;
  std::string detail;
  Registration registration = nullptr;
};

// Successful handles deliberately live until process exit. Flutter engines can
// retire independently, while GTypes and queued native callbacks outlive a call.
class OptionalBackendLoader {
 public:
  explicit OptionalBackendLoader(std::string library_directory);
  BackendResult Probe(const std::string& feature);
  static std::string ExecutableLibraryDirectory();

 private:
  std::string library_directory_;
  std::mutex mutex_;
  std::map<std::string, BackendResult> loaded_;
};

class EngineBackends {
 public:
  explicit EngineBackends(OptionalBackendLoader& loader) : loader_(loader) {}
  BackendResult Ensure(const std::string& feature, _FlPluginRegistrar* registrar);
  bool Registered(const std::string& feature) const;

 private:
  OptionalBackendLoader& loader_;
  std::set<std::string> registered_;
};
}  // namespace raft
#endif
