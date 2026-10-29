#include "windows_exit.h"

#include <algorithm>
#include <cstdio>
#include <utility>

struct WindowsExit::State {
  HWND window;
  Log log;
  UINT explicit_budget_ms, session_budget_ms;
  UINT_PTR timer = 0;
  ULONGLONG deadline = 0;
  int64_t request_id = 0;
  bool preparing = false, ready = false, destroyed = false;
  bool query_pending = false, session_waiting = false, session_confirmed = false;
  const char* reason = "explicitQuit";
};

WindowsExit::WindowsExit(HWND window, UINT quit_message, Prepare prepare,
                         Log log, UINT explicit_budget_ms, UINT session_budget_ms)
    : state_(std::make_shared<State>()), prepare_(std::move(prepare)),
      quit_message_(quit_message) {
  state_->window = window;
  state_->explicit_budget_ms = explicit_budget_ms;
  state_->session_budget_ms = session_budget_ms;
  state_->log = log ? std::move(log) : [](const std::string& line) {
    std::fprintf(stdout, "%s\n", line.c_str());
    std::fflush(stdout);
    OutputDebugStringA((line + "\n").c_str());
  };
}

WindowsExit::~WindowsExit() {
  state_->destroyed = true;
  if (state_->timer) KillTimer(state_->window, state_->timer);
  state_->timer = 0;
  state_->window = nullptr;
}

void WindowsExit::Finish(const std::shared_ptr<State>& state,
                         const std::string& outcome) {
  if (state->destroyed || !state->preparing || state->ready) return;
  state->ready = true;
  if (state->timer) KillTimer(state->window, state->timer);
  state->timer = 0;
  state->log("raft.windows_exit reason=" + std::string(state->reason) +
      " requestId=" + std::to_string(state->request_id) +
      (state->session_confirmed ? " confirmedSession=true" : "") + " outcome=" + outcome);
  // Never tear down the engine inside a platform-channel reply or the nested
  // ENDSESSION pump. Let this handler unwind before the ordinary WM_DESTROY.
  if (!state->session_waiting) PostMessageW(state->window, WM_CLOSE, 0, 0);
}

void WindowsExit::Begin(const std::shared_ptr<State>& state,
                        const Prepare& prepare, bool session) {
  if (state->destroyed || state->ready) return;
  const auto deadline = GetTickCount64() +
      (session ? state->session_budget_ms : state->explicit_budget_ms);
  if (state->preparing) {
    // A confirmed session end may shorten an in-flight explicit quit. Neither
    // repeats nor the transition start a second close or extend the deadline.
    if (session) state->deadline = std::min(state->deadline, deadline);
    return;
  }
  state->preparing = true;
  state->reason = session ? "sessionEnd" : "explicitQuit";
  state->deadline = deadline;
  ++state->request_id;
  state->timer = SetTimer(state->window, reinterpret_cast<UINT_PTR>(state.get()),
      session ? state->session_budget_ms : state->explicit_budget_ms, nullptr);
  if (!state->timer) {
    Finish(state, "timerFailed");
    return;
  }
  const auto id = state->request_id;
  const std::weak_ptr<State> weak = state;
  try {
    prepare(id, state->reason, [weak, id](int64_t reply_id, const std::string& outcome) {
      const auto current = weak.lock();
      if (!current || current->destroyed || current->ready || reply_id != id) return;
      if (outcome == "absent" || outcome == "completed" || outcome == "timedOut" ||
          outcome == "failed" || outcome == "channelError" || outcome == "unavailable") {
        Finish(current, outcome);
      }
      // A malformed/mismatched reply does not authorize destruction; the
      // independent native deadline still guarantees the waiter will finish.
    });
  } catch (...) {
    Finish(state, "channelError");
  }
}

void WindowsExit::WaitForSession(const std::shared_ptr<State>& state) {
  while (!state->ready && !state->destroyed) {
    const auto now = GetTickCount64();
    if (now >= state->deadline) {
      Finish(state, "nativeTimedOut");
      break;
    }
    const auto remaining = static_cast<DWORD>(state->deadline - now);
    // A plain wait would block Dart's platform thread and prevent its reply.
    MsgWaitForMultipleObjectsEx(0, nullptr, remaining, QS_ALLINPUT,
                                MWMO_INPUTAVAILABLE);
    MSG message;
    while (!state->ready && !state->destroyed &&
           PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) {
      if (message.message == WM_QUIT) {
        PostQuitMessage(static_cast<int>(message.wParam));
        Finish(state, "messageLoopQuit");
        return;
      }
      TranslateMessage(&message);
      DispatchMessageW(&message);
      if (GetTickCount64() >= state->deadline) break;
    }
  }
}

std::optional<LRESULT> WindowsExit::HandleMessage(UINT message, WPARAM wparam,
                                                 LPARAM /*lparam*/) {
  // Keep state alive even if a reentrant WM_DESTROY retires this owner.
  const auto state = state_;
  // WM_TIMER has low priority. A busy platform queue must not extend quit.
  if (state->preparing && !state->ready && GetTickCount64() >= state->deadline) {
    Finish(state, "nativeTimedOut");
  }
  if (quit_message_ && message == quit_message_) {
    const auto prepare = prepare_;
    Begin(state, prepare, false);
    return 0;
  }
  if (message == WM_QUERYENDSESSION) {
    state->query_pending = true;
    return TRUE;
  }
  if (message == WM_ENDSESSION) {
    state->query_pending = false;
    if (!wparam || state->session_waiting || state->destroyed) return 0;
    state->session_confirmed = true;
    state->session_waiting = true;
    const auto prepare = prepare_;
    Begin(state, prepare, true);
    WaitForSession(state);
    state->session_waiting = false;
    if (!state->destroyed && state->ready) PostMessageW(state->window, WM_CLOSE, 0, 0);
    return 0;
  }
  if (message == WM_TIMER && state->timer && wparam == state->timer) {
    if (GetTickCount64() >= state->deadline) Finish(state, "nativeTimedOut");
    return 0;
  }
  if (message == WM_CLOSE && state->preparing && !ready_to_close()) return 0;
  return std::nullopt;
}

bool WindowsExit::quitting() const { return state_->preparing; }

bool WindowsExit::ready_to_close() const {
  return state_->ready && !state_->session_waiting && !state_->destroyed;
}
