// Exercise the production native waiter with real per-window Win32 messages.
#include "windows_exit.h"

#include <iostream>
#include <stdexcept>
#include <vector>

namespace {
constexpr UINT kReply = WM_APP + 21;
void Check(bool value, const char* message) {
  if (!value) throw std::runtime_error(message);
}

struct Window {
  HWND hwnd = nullptr;
  UINT quit = RegisterWindowMessageW(L"Raft.QuitApplication");
  std::unique_ptr<WindowsExit> exit;
  WindowsExit::Reply reply;
  int64_t id = 0;
  int prepares = 0, closes = 0;
  bool synchronous = false, post_reply = false;
  std::string reason;
  std::vector<std::string> logs;

  static LRESULT CALLBACK Proc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    auto* self = reinterpret_cast<Window*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (msg == WM_NCCREATE) {
      self = static_cast<Window*>(reinterpret_cast<CREATESTRUCTW*>(lp)->lpCreateParams);
      SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
    }
    if (self && self->exit) {
      auto result = self->exit->HandleMessage(msg, wp, lp);
      if (result) return *result;
    }
    if (self && msg == kReply) {
      self->reply(self->id, "completed");
      return 0;
    }
    if (self && msg == WM_CLOSE) {
      ++self->closes;
      DestroyWindow(hwnd);
      return 0;
    }
    if (self && msg == WM_DESTROY) self->exit.reset();
    return DefWindowProcW(hwnd, msg, wp, lp);
  }

  Window(UINT explicit_ms = 2100, UINT session_ms = 1000) {
    static bool registered = [] {
      WNDCLASSW wc{};
      wc.lpfnWndProc = Proc;
      wc.hInstance = GetModuleHandleW(nullptr);
      wc.lpszClassName = L"RaftCacheExitNativeTest";
      return RegisterClassW(&wc) != 0;
    }();
    Check(registered, "register test window");
    hwnd = CreateWindowW(L"RaftCacheExitNativeTest", L"Isolated exit test", 0,
        0, 0, 10, 10, nullptr, nullptr, GetModuleHandleW(nullptr), this);
    Check(hwnd != nullptr, "create test window");
    exit = std::make_unique<WindowsExit>(hwnd, quit,
        [this](int64_t number, const char* why, WindowsExit::Reply done) {
          ++prepares; id = number; reason = why; reply = std::move(done);
          if (synchronous) reply(id, "completed");
          if (post_reply) PostMessageW(hwnd, kReply, 0, 0);
        }, [this](const std::string& line) { logs.push_back(line); }, explicit_ms, session_ms);
  }
  ~Window() {
    exit.reset();
    if (IsWindow(hwnd)) DestroyWindow(hwnd);
  }
  void Send(UINT msg, WPARAM wp = 0) { SendMessageW(hwnd, msg, wp, 0); }
  void Pump(UINT max_ms = 150) {
    const auto until = GetTickCount64() + max_ms;
    do {
      MSG msg;
      while (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) {
        TranslateMessage(&msg); DispatchMessageW(&msg);
      }
      if (closes) return;
      MsgWaitForMultipleObjectsEx(0, nullptr, 5, QS_ALLINPUT, MWMO_INPUTAVAILABLE);
    } while (GetTickCount64() < until);
  }
  bool Logged(const char* outcome) const {
    return logs.size() == 1 && logs.front().find(std::string("outcome=") + outcome) != std::string::npos;
  }
};

void ExplicitReply() {
  Window w;
  w.Send(w.quit);
  Check(w.prepares == 1 && w.reason == "explicitQuit" && !w.closes, "quit must wait for Dart");
  w.Send(WM_CLOSE);
  Check(!w.closes, "WM_CLOSE while waiting must not destroy engine");
  w.reply(w.id, "completed");
  Check(!w.closes, "reply must not destroy engine on callback stack");
  w.Pump();
  Check(w.closes == 1 && w.Logged("completed"), "completed close then destroy");
}
void RepeatedAndLateReply() {
  Window w;
  w.Send(w.quit); w.Send(w.quit); w.Send(w.quit);
  Check(w.prepares == 1, "repeated quit starts one close");
  auto reply = w.reply;
  reply(w.id, "completed"); w.Pump();
  reply(w.id, "failed");
  Check(w.closes == 1 && w.Logged("completed"), "late reply is ignored after owner destruction");
}
void BadReplies() {
  Window w;
  w.Send(w.quit);
  w.reply(w.id + 1, "completed"); w.reply(w.id, "nonsense");
  Check(!w.exit->ready_to_close() && w.logs.empty(), "invalid reply cannot authorize close");
  w.reply(w.id, "absent"); w.Pump();
  Check(w.Logged("absent") && w.closes == 1, "valid reply still finishes");
}
void Outcomes() {
  for (const auto outcome : {"failed", "timedOut", "channelError", "unavailable"}) {
    Window w;
    w.Send(w.quit); w.reply(w.id, outcome); w.Pump();
    Check(w.closes == 1 && w.Logged(outcome), "failure/unavailable must still exit");
  }
}
void SynchronousReply() {
  Window w;
  w.synchronous = true;
  w.Send(w.quit);
  Check(!w.closes, "sync reply must defer native destruction");
  w.Pump();
  Check(w.closes == 1, "sync reply queues close");
}
void NativeTimeout() {
  Window w(30, 30);
  w.Send(w.quit);
  w.Pump(500);
  Check(w.closes == 1 && w.Logged("nativeTimedOut"), "independent native timer must exit");
  w.reply(w.id, "completed");
  Check(w.Logged("nativeTimedOut"), "late successful close must not replace timeout");
}
void BusyQueueCannotExtendDeadline() {
  Window w(25, 25);
  w.Send(w.quit);
  Sleep(45);  // Leave WM_TIMER unprocessed, as in a busy platform queue.
  w.Send(WM_NULL);
  Check(w.exit->ready_to_close() && w.Logged("nativeTimedOut"),
        "deadline must not depend on low-priority timer dispatch");
  w.Pump();
  Check(w.closes == 1, "busy queue still queues close");
}
void CancelledSession() {
  Window w;
  const auto start = GetTickCount64();
  Check(SendMessageW(w.hwnd, WM_QUERYENDSESSION, 0, ENDSESSION_LOGOFF) == TRUE,
        "query immediately accepts session end");
  Check(GetTickCount64() - start < 250 && w.prepares == 0, "query must not close cache");
  w.Send(WM_ENDSESSION, FALSE);
  Check(w.prepares == 0 && !w.exit->quitting(), "cancelled session leaves cache usable");
  w.Send(w.quit); w.reply(w.id, "completed"); w.Pump();
  Check(w.closes == 1, "explicit quit still works after cancellation");
}
void SessionPumpsPlatformReply() {
  Window w;
  w.post_reply = true;
  w.Send(WM_QUERYENDSESSION);
  w.Send(WM_ENDSESSION, TRUE);
  Check(w.prepares == 1 && w.reason == "sessionEnd" && w.Logged("completed"),
        "confirmed session must pump platform reply before return");
  Check(w.closes == 0, "session handler must unwind before destruction");
  w.Pump(); Check(w.closes == 1, "session completion queues ordinary destruction");
}
void SessionNativeTimeout() {
  Window w(2100, 35);
  w.Send(WM_QUERYENDSESSION);
  const auto start = GetTickCount64();
  w.Send(WM_ENDSESSION, TRUE);
  const auto elapsed = GetTickCount64() - start;
  Check(elapsed >= 25 && elapsed < 500 && w.Logged("nativeTimedOut"), "session wait is bounded");
  Check(w.closes == 0, "timeout must also defer destruction until unwind");
  w.Pump(); Check(w.closes == 1, "session timeout still exits");
}
void SessionShortensExplicit() {
  Window w(2100, 30);
  w.Send(w.quit); w.Send(WM_QUERYENDSESSION);
  const auto start = GetTickCount64();
  w.Send(WM_ENDSESSION, TRUE);
  Check(GetTickCount64() - start < 500 && w.prepares == 1 && w.Logged("nativeTimedOut"),
        "session transition shares close and shortens deadline");
  w.Pump();
}
void CancelDoesNotUndoExplicit() {
  Window w;
  w.Send(w.quit); w.Send(WM_QUERYENDSESSION); w.Send(WM_ENDSESSION, FALSE);
  Check(w.prepares == 1 && w.exit->quitting(), "cancel cannot undo an explicit user quit");
  w.reply(w.id, "completed"); w.Pump(); Check(w.closes == 1, "explicit quit survives session cancel");
}
void DestroyWhileWaiting() {
  Window w(30, 30);
  w.Send(w.quit);
  const auto callback = w.reply;
  DestroyWindow(w.hwnd);
  callback(w.id, "completed"); w.Pump(75);
  Check(w.logs.empty() && w.closes == 0, "retired window ignores callback and cancelled timer");
}
}  // namespace

int main() {
  try {
    ExplicitReply(); RepeatedAndLateReply(); BadReplies(); Outcomes();
    SynchronousReply(); NativeTimeout(); BusyQueueCannotExtendDeadline(); CancelledSession();
    SessionPumpsPlatformReply(); SessionNativeTimeout(); SessionShortensExplicit();
    CancelDoesNotUndoExplicit(); DestroyWhileWaiting();
    std::cout << "PASS: 13 native exit scenarios (including 4 outcome replies)\n";
    return 0;
  } catch (const std::exception& e) {
    std::cerr << "FAIL: " << e.what() << '\n'; return 1;
  }
}
