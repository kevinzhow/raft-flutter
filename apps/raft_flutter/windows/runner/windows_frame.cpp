#include "windows_frame.h"

#include <dwmapi.h>
#include <windowsx.h>

#include <cmath>
#include <utility>

namespace {
constexpr UINT_PTR kChildSubclass = 1;
POINT ScreenPoint(LPARAM lp) { return {GET_X_LPARAM(lp), GET_Y_LPARAM(lp)}; }
bool Valid(const WindowsFrame::Rect& rect) {
  return std::isfinite(rect.x) && std::isfinite(rect.y) &&
      std::isfinite(rect.width) && std::isfinite(rect.height) &&
      rect.x >= 0 && rect.y >= 0 && rect.width >= 0 && rect.height >= 0 &&
      rect.x <= 100000 && rect.y <= 100000 &&
      rect.width <= 100000 && rect.height <= 100000;
}
}  // namespace

WindowsFrame::WindowsFrame(HWND window, HWND child, std::function<void()> changed)
    : window_(window), child_(child), changed_(std::move(changed)) {
  state_.active = GetForegroundWindow() == window_;
  state_.maximized = IsZoomed(window_) != FALSE;
}

WindowsFrame::~WindowsFrame() {
  if (subclassed_ && IsWindow(child_))
    RemoveWindowSubclass(child_, ChildProc, kChildSubclass);
}

bool WindowsFrame::Enable(bool custom) {
  if (custom && !subclassed_) {
    if (!SetWindowSubclass(child_, ChildProc, kChildSubclass,
                           reinterpret_cast<DWORD_PTR>(this))) return false;
    subclassed_ = true;
  }
  const auto before = state_;
  state_.custom_controls = custom;
  rects_ = {};
  // Keep WS_OVERLAPPEDWINDOW: Windows still owns resizing, snap and system menu.
  MARGINS margins{0, 0, custom ? 1 : 0, 0};
  DwmExtendFrameIntoClientArea(window_, &margins);
  SetWindowPos(window_, nullptr, 0, 0, 0, 0,
      SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
  NotifyIfChanged(before);
  return true;
}

bool WindowsFrame::SetCaptionRects(const CaptionRects& rects) {
  for (const auto& rect : rects) {
    if (!Valid(rect)) { rects_ = {}; return false; }
  }
  rects_ = rects;
  RECT client{}; GetClientRect(window_, &client);
  caption_layout_width_ = client.right / (GetDpiForWindow(window_) / 96.0);
  return true;
}

bool WindowsFrame::IsFullscreen() const {
  if ((GetWindowLongPtrW(window_, GWL_STYLE) & WS_CAPTION) != 0) return false;
  MONITORINFO monitor{sizeof(MONITORINFO)};
  RECT bounds{};
  return GetWindowRect(window_, &bounds) &&
      GetMonitorInfoW(MonitorFromWindow(window_, MONITOR_DEFAULTTONEAREST), &monitor) &&
      EqualRect(&bounds, &monitor.rcMonitor);
}

void WindowsFrame::NotifyIfChanged(const State& before) {
  if (changed_ && (state_.custom_controls != before.custom_controls ||
      state_.active != before.active || state_.maximized != before.maximized ||
      state_.fullscreen != before.fullscreen)) changed_();
}

LRESULT WindowsFrame::HitTest(POINT point) const {
  if (!state_.custom_controls || state_.fullscreen) return HTCLIENT;
  RECT bounds{}; GetWindowRect(window_, &bounds);
  // LPARAM coordinates are signed: secondary monitors may be left of primary.
  if (point.x < bounds.left || point.x >= bounds.right ||
      point.y < bounds.top || point.y >= bounds.bottom) return HTNOWHERE;
  if (!state_.maximized && (GetWindowLongPtrW(window_, GWL_STYLE) & WS_THICKFRAME)) {
    const UINT dpi = GetDpiForWindow(window_);
    const int border_x = GetSystemMetricsForDpi(SM_CXSIZEFRAME, dpi) +
                         GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
    const int border_y = GetSystemMetricsForDpi(SM_CYSIZEFRAME, dpi) +
                         GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
    const bool left = point.x < bounds.left + border_x;
    const bool right = point.x >= bounds.right - border_x;
    const bool top = point.y < bounds.top + border_y;
    const bool bottom = point.y >= bounds.bottom - border_y;
    if (top && left) return HTTOPLEFT;
    if (top && right) return HTTOPRIGHT;
    if (bottom && left) return HTBOTTOMLEFT;
    if (bottom && right) return HTBOTTOMRIGHT;
    if (left) return HTLEFT;
    if (right) return HTRIGHT;
    if (top) return HTTOP;
    if (bottom) return HTBOTTOM;
  }
  ScreenToClient(window_, &point);
  const double scale = GetDpiForWindow(window_) / 96.0;
  RECT client{}; GetClientRect(window_, &client);
  // Do not use targets from an older, wider layout. Height-only changes and
  // scaling with the same logical width keep valid targets: Dart deduplicates
  // unchanged rectangles, so clearing them on every WM_SIZE loses snap forever.
  if (std::abs(client.right / scale - caption_layout_width_) > 0.01) return HTCLIENT;
  const auto& rect = rects_[1];
  if (point.x >= rect.x * scale && point.x < (rect.x + rect.width) * scale &&
      point.y >= rect.y * scale && point.y < (rect.y + rect.height) * scale &&
      (GetWindowLongPtrW(window_, GWL_STYLE) & WS_MAXIMIZEBOX)) return HTMAXBUTTON;
  return HTCLIENT;
}

void WindowsFrame::ForwardPointer(UINT message, WPARAM wp, LPARAM screen) {
  if (!IsWindow(child_)) return;
  POINT point = ScreenPoint(screen);
  ScreenToClient(child_, &point);
  SendMessageW(child_, message, wp, MAKELPARAM(point.x, point.y));
}

std::optional<LRESULT> WindowsFrame::HandleMessage(UINT message, WPARAM wp, LPARAM lp) {
  if (!state_.custom_controls) return std::nullopt;
  switch (message) {
    case WM_NCCALCSIZE: {
      // Remove the system caption in both restored and maximized windows.
      RECT* client = wp ? &reinterpret_cast<NCCALCSIZE_PARAMS*>(lp)->rgrc[0]
                        : reinterpret_cast<RECT*>(lp);
      if (IsZoomed(window_) && !IsFullscreen()) {
        MONITORINFO monitor{sizeof(MONITORINFO)};
        if (GetMonitorInfoW(MonitorFromWindow(window_, MONITOR_DEFAULTTONEAREST), &monitor))
          *client = monitor.rcWork;
      }
      return 0;
    }
    case WM_NCHITTEST: return HitTest(ScreenPoint(lp));
    case WM_NCMOUSEMOVE:
      if (wp == HTMAXBUTTON) {
        if (!tracking_max_) {
          TRACKMOUSEEVENT tracking{sizeof(TRACKMOUSEEVENT), TME_NONCLIENT | TME_LEAVE, window_, 0};
          TrackMouseEvent(&tracking); tracking_max_ = true;
        }
        ForwardPointer(WM_MOUSEMOVE, 0, lp);
        // DefWindowProc still sees HTMAXBUTTON and can present Win11 snap layouts.
      }
      break;
    case WM_NCMOUSELEAVE:
      if (tracking_max_) {
        tracking_max_ = false;
        SendMessageW(child_, WM_MOUSELEAVE, 0, 0);
      }
      break;
    case WM_NCLBUTTONDOWN:
    case WM_NCLBUTTONDBLCLK:
      if (wp == HTMAXBUTTON) {
        // Flutter owns activation (also keyboard/semantics). Its pointer capture
        // delivers the matching client mouse-up, avoiding a second OS toggle.
        ForwardPointer(WM_LBUTTONDOWN, MK_LBUTTON, lp);
        return 0;
      }
      break;
    case WM_SIZE: {
      const auto before = state_;
      state_.maximized = wp == SIZE_MAXIMIZED;
      state_.fullscreen = IsFullscreen();
      NotifyIfChanged(before);
      break;
    }
    case WM_WINDOWPOSCHANGED: {
      const auto before = state_;
      state_.fullscreen = IsFullscreen();
      NotifyIfChanged(before);
      break;
    }
    case WM_ACTIVATE: {
      const auto before = state_;
      state_.active = LOWORD(wp) != WA_INACTIVE;
      NotifyIfChanged(before);
      break;
    }
  }
  return std::nullopt;
}

LRESULT CALLBACK WindowsFrame::ChildProc(HWND hwnd, UINT message, WPARAM wp,
    LPARAM lp, UINT_PTR id, DWORD_PTR data) {
  auto* self = reinterpret_cast<WindowsFrame*>(data);
  if (message == WM_NCHITTEST && self->state_.custom_controls) {
    const auto hit = self->HitTest(ScreenPoint(lp));
    if (hit != HTCLIENT && hit != HTNOWHERE) return HTTRANSPARENT;
  }
  if (message == WM_NCDESTROY) {
    RemoveWindowSubclass(hwnd, ChildProc, id);
    self->subclassed_ = false;
  }
  return DefSubclassProc(hwnd, message, wp, lp);
}

void WindowsFrame::Minimize() { PostMessageW(window_, WM_SYSCOMMAND, SC_MINIMIZE, 0); }
void WindowsFrame::ToggleMaximize() {
  if (state_.fullscreen) return;
  PostMessageW(window_, WM_SYSCOMMAND, IsZoomed(window_) ? SC_RESTORE : SC_MAXIMIZE, 0);
}
void WindowsFrame::Close() { PostMessageW(window_, WM_CLOSE, 0, 0); }
void WindowsFrame::StartDragging() {
  if (state_.fullscreen) return;
  POINT point{}; GetCursorPos(&point);
  ReleaseCapture();
  SendMessageW(window_, WM_NCLBUTTONDOWN, HTCAPTION, MAKELPARAM(point.x, point.y));
}
