#include "windows_frame.h"

#include <dwmapi.h>
#include <windowsx.h>

#include <cmath>
#include <utility>

namespace {
constexpr UINT_PTR kChildSubclass = 1;
constexpr int kCaptionRowHeight = 48;
POINT ScreenPoint(LPARAM lp) { return {GET_X_LPARAM(lp), GET_Y_LPARAM(lp)}; }
bool Valid(const WindowsFrame::Rect& rect) {
  return std::isfinite(rect.x) && std::isfinite(rect.y) &&
      std::isfinite(rect.width) && std::isfinite(rect.height) &&
      rect.x >= 0 && rect.y >= 0 && rect.width >= 0 && rect.height >= 0 &&
      rect.x <= 100000 && rect.y <= 100000 &&
      rect.width <= 100000 && rect.height <= 100000;
}
}  // namespace

WindowsFrame::WindowsFrame(HWND window, HWND child, std::function<void()> changed,
    std::function<BOOL(TRACKMOUSEEVENT*)> track_mouse)
    : window_(window), child_(child), changed_(std::move(changed)),
      track_mouse_(std::move(track_mouse)) {
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
  state_.maximize_hovered = false;
  rects_ = {};
  // Keep WS_OVERLAPPEDWINDOW: Windows still owns resizing, snap and system menu.
  UpdateFrameMargins(GetDpiForWindow(window_));
  SetWindowPos(window_, nullptr, 0, 0, 0, 0,
      SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
  NotifyIfChanged(before);
  return true;
}

void WindowsFrame::UpdateFrameMargins(UINT dpi) {
  if (!dpi) dpi = GetDpiForWindow(window_);
  // A one-pixel extension clips Windows' internal maximize rectangle to one
  // pixel, so Snap Layouts remain unavailable even when HTMAXBUTTON is correct.
  // Register the complete shared caption row; Dart still paints its controls.
  const int margin = state_.custom_controls && !state_.fullscreen
      ? MulDiv(kCaptionRowHeight, dpi, 96) : 0;
  if (margin == frame_margin_) return;
  MARGINS margins{0, 0, margin, 0};
  if (SUCCEEDED(DwmExtendFrameIntoClientArea(window_, &margins)))
    frame_margin_ = margin;
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
      state_.fullscreen != before.fullscreen ||
      state_.maximize_hovered != before.maximize_hovered)) changed_();
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
  if (!state_.custom_controls && message != WM_SIZE &&
      message != WM_WINDOWPOSCHANGED && message != WM_ACTIVATE) return std::nullopt;
  switch (message) {
    case WM_NCCALCSIZE: {
      // Remove the system caption in both restored and maximized windows.
      RECT* client = wp ? &reinterpret_cast<NCCALCSIZE_PARAMS*>(lp)->rgrc[0]
                        : reinterpret_cast<RECT*>(lp);
      // During NCCALCSIZE GetWindowRect can still report the previous bounds.
      // A borderless fullscreen transition from maximized must not be clamped
      // to the taskbar work area using that stale geometry.
      if (IsZoomed(window_) && (GetWindowLongPtrW(window_, GWL_STYLE) & WS_CAPTION)) {
        MONITORINFO monitor{sizeof(MONITORINFO)};
        if (GetMonitorInfoW(MonitorFromWindow(window_, MONITOR_DEFAULTTONEAREST), &monitor))
          *client = monitor.rcWork;
      }
      return 0;
    }
    case WM_NCHITTEST: return HitTest(ScreenPoint(lp));
    case WM_NCMOUSEMOVE: {
      const auto result = DefWindowProcW(window_, message, wp, lp);
      const auto before = state_;
      state_.maximize_hovered = wp == HTMAXBUTTON;
      if (wp == HTMAXBUTTON) {
        if (!tracking_max_) {
          TRACKMOUSEEVENT tracking{sizeof(TRACKMOUSEEVENT),
              TME_NONCLIENT | TME_HOVER | TME_LEAVE, window_, HOVER_DEFAULT};
          tracking_max_ = track_mouse_(&tracking) != FALSE;
        }
        // Forwarding WM_MOUSEMOVE to Flutter starts client TME_LEAVE tracking
        // on its child HWND, competing with this nonclient track. Report only
        // paint state; let DefWindowProc own the native snap-hover lifecycle.
      } else {
        tracking_max_ = false;
      }
      NotifyIfChanged(before);
      return result;
    }
    case WM_NCMOUSEHOVER:
      // Windows consumes the hover request after delivering it. Preserve the
      // system's Snap Layout handling and re-arm only on a later mouse move.
      tracking_max_ = false;
      return DefWindowProcW(window_, message, wp, lp);
    case WM_NCMOUSELEAVE: {
      const auto before = state_;
      tracking_max_ = false;
      state_.maximize_hovered = false;
      NotifyIfChanged(before);
      return DefWindowProcW(window_, message, wp, lp);
    }
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
      UpdateFrameMargins(GetDpiForWindow(window_));
      state_.maximize_hovered = false;
      NotifyIfChanged(before);
      break;
    }
    case WM_WINDOWPOSCHANGED: {
      const auto before = state_;
      state_.fullscreen = IsFullscreen();
      UpdateFrameMargins(GetDpiForWindow(window_));
      if (state_.fullscreen) state_.maximize_hovered = false;
      NotifyIfChanged(before);
      break;
    }
    case WM_DPICHANGED:
      UpdateFrameMargins(LOWORD(wp));
      // The window owner still applies the suggested physical bounds.
      break;
    case WM_ACTIVATE: {
      const auto before = state_;
      state_.active = LOWORD(wp) != WA_INACTIVE;
      if (!state_.active) state_.maximize_hovered = false;
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
