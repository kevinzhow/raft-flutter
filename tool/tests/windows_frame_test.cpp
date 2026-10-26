// Hidden windows and actual Win32 message dispatch. This is not pointer/UI QA.
#include <windows.h>
#include <windowsx.h>

#if __has_include("windows_frame.h")
#include "windows_frame.h"
#define RAFT_FRAME_AVAILABLE 1
#endif

#include <iostream>
#include <limits>
#include <memory>
#include <stdexcept>

namespace {
void Check(bool value, const char* message) {
  if (!value) throw std::runtime_error(message);
}

struct Window {
  HWND hwnd = nullptr, child = nullptr;
  int closes = 0, changes = 0, moves = 0, downs = 0, leaves = 0;
#ifdef RAFT_FRAME_AVAILABLE
  std::unique_ptr<WindowsFrame> frame;
#endif
  static LRESULT CALLBACK Proc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    auto* self = reinterpret_cast<Window*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (msg == WM_NCCREATE) {
      self = static_cast<Window*>(reinterpret_cast<CREATESTRUCTW*>(lp)->lpCreateParams);
      SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
    }
    if (self && msg == WM_CLOSE) { ++self->closes; return 0; }
#ifdef RAFT_FRAME_AVAILABLE
    if (self && self->frame) {
      const auto result = self->frame->HandleMessage(msg, wp, lp);
      if (result) return *result;
    }
#endif
    return DefWindowProcW(hwnd, msg, wp, lp);
  }
  static LRESULT CALLBACK ChildProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    auto* self = reinterpret_cast<Window*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (msg == WM_NCCREATE) {
      self = static_cast<Window*>(reinterpret_cast<CREATESTRUCTW*>(lp)->lpCreateParams);
      SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
    }
    if (self && msg == WM_MOUSEMOVE) ++self->moves;
    if (self && msg == WM_MOUSELEAVE) ++self->leaves;
    if (self && msg == WM_LBUTTONDOWN) ++self->downs;
    return DefWindowProcW(hwnd, msg, wp, lp);
  }
  explicit Window(bool custom = true) {
    static bool registered = [] {
      WNDCLASSW wc{};
      wc.lpfnWndProc = Proc; wc.hInstance = GetModuleHandleW(nullptr);
      wc.lpszClassName = L"RaftIsolatedFrameTest";
      Check(RegisterClassW(&wc) != 0, "register frame fixture");
      wc.lpfnWndProc = ChildProc; wc.lpszClassName = L"RaftIsolatedFrameChild";
      return RegisterClassW(&wc) != 0;
    }();
    Check(registered, "register child fixture");
    hwnd = CreateWindowW(L"RaftIsolatedFrameTest", L"Isolated frame regression",
        WS_OVERLAPPEDWINDOW, 100, 100, 800, 600, nullptr, nullptr,
        GetModuleHandleW(nullptr), this);
    Check(hwnd != nullptr, "create frame fixture");
    child = CreateWindowW(L"RaftIsolatedFrameChild", L"", WS_CHILD,
        0, 0, 800, 600, hwnd, nullptr, GetModuleHandleW(nullptr), this);
    Check(child != nullptr, "create Flutter child stand-in");
#ifdef RAFT_FRAME_AVAILABLE
    frame = std::make_unique<WindowsFrame>(hwnd, child, [this] { ++changes; });
    Check(frame->Enable(custom), "install child frame routing");
#else
    (void)custom;
#endif
  }
  ~Window() {
#ifdef RAFT_FRAME_AVAILABLE
    frame.reset();
#endif
    DestroyWindow(hwnd);
  }
  LPARAM Point(int x, int y) const {
    POINT point{x, y}; ClientToScreen(hwnd, &point);
    return MAKELPARAM(point.x, point.y);
  }
  void Pump() {
    MSG msg;
    while (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) DispatchMessageW(&msg);
  }
};

void NoExtraCaption() {
  Window w;
  RECT outer{}, client{}; POINT origin{};
  GetWindowRect(w.hwnd, &outer); GetClientRect(w.hwnd, &client);
  ClientToScreen(w.hwnd, &origin);
  std::cout << "outer=" << outer.right-outer.left << 'x' << outer.bottom-outer.top
            << " client=" << client.right << 'x' << client.bottom
            << " topInset=" << origin.y-outer.top << '\n';
  Check(origin.y == outer.top && origin.x == outer.left &&
        client.bottom == outer.bottom-outer.top,
        "shared 48px titlebar must not have an extra native caption above it");
}

#ifdef RAFT_FRAME_AVAILABLE
void Rects(Window& w) {
  // Coordinates sent by Dart are logical, while Win32 hit tests are physical.
  const double scale = GetDpiForWindow(w.hwnd) / 96.0;
  Check(w.frame->SetCaptionRects({{{550/scale, 0, 46, 48},
      {620/scale, 0, 46, 48}, {690/scale, 0, 46, 48}}}), "valid caption rects");
}
void HitTests() {
  Window w; Rects(w);
  auto hit = [&](int x, int y) { return SendMessageW(w.hwnd, WM_NCHITTEST, 0, w.Point(x,y)); };
  Check(hit(640,25) == HTMAXBUTTON, "maximize must expose Win11 snap hit target");
  Check(hit(570,25) == HTCLIENT && hit(710,25) == HTCLIENT,
        "minimize/close remain Flutter pointer targets");
  Check(hit(300,25) == HTCLIENT && hit(300,200) == HTCLIENT,
        "normal header/content do not become native drag regions");
  Check(hit(1,1) == HTTOPLEFT && hit(799,1) == HTTOPRIGHT &&
        hit(1,599) == HTBOTTOMLEFT && hit(799,599) == HTBOTTOMRIGHT,
        "all resize corners survive client extension");
  Check(hit(1,250) == HTLEFT && hit(799,250) == HTRIGHT &&
        hit(250,1) == HTTOP && hit(250,599) == HTBOTTOM,
        "all resize edges survive client extension");
  Check(SendMessageW(w.child, WM_NCHITTEST, 0, w.Point(640,25)) == HTTRANSPARENT,
        "Flutter child must let OS reach maximize nonclient hit target");
  Check(SendMessageW(w.child, WM_NCHITTEST, 0, w.Point(300,200)) == HTCLIENT,
        "Flutter content retains ordinary hit testing");
}
void InvalidAndStaleRects() {
  Window w; Rects(w);
  const auto nan = std::numeric_limits<double>::quiet_NaN();
  Check(!w.frame->SetCaptionRects({{{}, {nan,0,46,48}, {}}}), "reject nonfinite channel input");
  Check(SendMessageW(w.hwnd, WM_NCHITTEST, 0, w.Point(640,25)) == HTCLIENT,
        "invalid input must remove stale maximize hit target");
  Rects(w);
  SetWindowPos(w.hwnd, nullptr, 0,0,800,700, SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE);
  Check(SendMessageW(w.hwnd, WM_NCHITTEST, 0, w.Point(640,25)) == HTMAXBUTTON,
        "height-only resize must retain deduplicated caption positions");
  SetWindowPos(w.hwnd, nullptr, 0,0,790,700, SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE);
  Check(SendMessageW(w.hwnd, WM_NCHITTEST, 0, w.Point(640,25)) == HTCLIENT,
        "width change disables old caption targets until new Flutter layout arrives");
}
void MaximumClientArea() {
  Window w;
  MONITORINFO monitor{sizeof(MONITORINFO)};
  GetMonitorInfoW(MonitorFromWindow(w.hwnd, MONITOR_DEFAULTTONEAREST), &monitor);
  SetWindowLongPtrW(w.hwnd, GWL_STYLE, GetWindowLongPtrW(w.hwnd, GWL_STYLE) | WS_MAXIMIZE);
  SendMessageW(w.hwnd, WM_SIZE, SIZE_MAXIMIZED, 0);
  NCCALCSIZE_PARAMS params{}; params.rgrc[0] = monitor.rcMonitor;
  SendMessageW(w.hwnd, WM_NCCALCSIZE, TRUE, reinterpret_cast<LPARAM>(&params));
  Check(EqualRect(&params.rgrc[0], &monitor.rcWork),
        "maximized content must stay inside work area instead of taskbar/overscan");
}
void StateAndFullscreen() {
  Window w;
  const auto original = GetWindowLongPtrW(w.hwnd, GWL_STYLE);
  SendMessageW(w.hwnd, WM_ACTIVATE, WA_ACTIVE, 0);
  const int changes = w.changes;
  SendMessageW(w.hwnd, WM_ACTIVATE, WA_ACTIVE, 0);
  Check(w.changes == changes, "unchanged native state must not notify/redraw Dart");
  SendMessageW(w.hwnd, WM_ACTIVATE, WA_INACTIVE, 0);
  Check(!w.frame->state().active && w.changes == changes+1,
        "activation updates once");
  MONITORINFO monitor{sizeof(MONITORINFO)};
  GetMonitorInfoW(MonitorFromWindow(w.hwnd, MONITOR_DEFAULTTONEAREST), &monitor);
  SetWindowLongPtrW(w.hwnd, GWL_STYLE, (original & ~WS_OVERLAPPEDWINDOW) | WS_MAXIMIZE);
  SetWindowPos(w.hwnd, nullptr, monitor.rcMonitor.left, monitor.rcMonitor.top,
      monitor.rcMonitor.right-monitor.rcMonitor.left,
      monitor.rcMonitor.bottom-monitor.rcMonitor.top, SWP_NOZORDER|SWP_NOACTIVATE|SWP_FRAMECHANGED);
  Check(w.frame->state().fullscreen, "real monitor-sized borderless window is fullscreen");
  RECT full_client{}; GetClientRect(w.hwnd, &full_client);
  Check(full_client.right == monitor.rcMonitor.right-monitor.rcMonitor.left &&
        full_client.bottom == monitor.rcMonitor.bottom-monitor.rcMonitor.top,
        "fullscreen from maximized must fill monitor, not previous work area");
  Rects(w);
  Check(SendMessageW(w.hwnd, WM_NCHITTEST, 0, w.Point(640,25)) == HTCLIENT,
        "fullscreen cannot leave hidden maximize/resize hit targets");
  SetWindowLongPtrW(w.hwnd, GWL_STYLE, original);
  SetWindowPos(w.hwnd, nullptr, 100,100,800,600, SWP_NOZORDER|SWP_NOACTIVATE|SWP_FRAMECHANGED);
  Check(!w.frame->state().fullscreen, "restoring window clears fullscreen state");
}
void ForwardMaxPointer() {
  Window w; Rects(w);
  SendMessageW(w.hwnd, WM_NCMOUSEMOVE, HTMAXBUTTON, w.Point(640,25));
  Check(w.moves == 1, "native maximize hover must reach shared Flutter hover drawing");
  SendMessageW(w.hwnd, WM_NCLBUTTONDOWN, HTMAXBUTTON, w.Point(640,25));
  Check(w.downs == 1, "maximize press must use the same shared button action as keyboard");
  ReleaseCapture();
  SendMessageW(w.hwnd, WM_NCMOUSELEAVE, 0, 0);
  Check(w.leaves == 1, "leaving native maximize clears Flutter hover");
}
void CloseOwnership() {
  Window w;
  w.frame->Close(); Check(w.closes == 0, "caption close must defer to ordinary message owner");
  w.Pump(); Check(w.closes == 1 && IsWindow(w.hwnd), "caption close must not destroy/bypass tray and exit owner");
}
void FallbackAndLifetime() {
  Window w(false);
  POINT point{}; RECT outer{}; ClientToScreen(w.hwnd, &point); GetWindowRect(w.hwnd, &outer);
  Check(!w.frame->state().custom_controls && point.y > outer.top, "native fallback preserves system caption");
  w.frame.reset();
  Check(SendMessageW(w.child, WM_NCHITTEST, 0, w.Point(20,20)) == HTCLIENT,
        "destroying frame unhooks child before engine destruction");
}
#endif
}  // namespace

int main() {
  try {
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    NoExtraCaption();
#ifdef RAFT_FRAME_AVAILABLE
    HitTests(); InvalidAndStaleRects(); MaximumClientArea(); StateAndFullscreen();
    ForwardMaxPointer(); CloseOwnership(); FallbackAndLifetime();
    std::cout << "PASS: 8 native frame scenarios (hidden windows; not visual/pointer acceptance)\n";
#endif
    return 0;
  } catch (const std::exception& e) { std::cerr << "FAIL: " << e.what() << '\n'; return 1; }
}
