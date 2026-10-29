#ifndef RUNNER_WINDOWS_EXIT_H_
#define RUNNER_WINDOWS_EXIT_H_

#include <windows.h>

#include <cstdint>
#include <functional>
#include <memory>
#include <optional>
#include <string>

// Explicit quit must not depend on Flutter counting the last native window:
// WinSparkle may still have its own dialog open. The window owns this waiter.
class WindowsExit {
 public:
  using Reply = std::function<void(int64_t, const std::string&)>;
  using Prepare = std::function<void(int64_t, const char*, Reply)>;
  using Log = std::function<void(const std::string&)>;

  WindowsExit(HWND window, UINT quit_message, Prepare prepare, Log log = {},
              UINT explicit_budget_ms = 2100, UINT session_budget_ms = 1000);
  ~WindowsExit();
  std::optional<LRESULT> HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);
  bool quitting() const;
  bool ready_to_close() const;

 private:
  struct State;
  static void Begin(const std::shared_ptr<State>& state, const Prepare& prepare,
                    bool session);
  static void Finish(const std::shared_ptr<State>& state, const std::string& outcome);
  static void WaitForSession(const std::shared_ptr<State>& state);
  std::shared_ptr<State> state_;
  Prepare prepare_;
  UINT quit_message_;
};

#endif  // RUNNER_WINDOWS_EXIT_H_
