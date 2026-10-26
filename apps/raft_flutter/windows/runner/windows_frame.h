#ifndef RUNNER_WINDOWS_FRAME_H_
#define RUNNER_WINDOWS_FRAME_H_

#include <windows.h>
#include <commctrl.h>

#include <array>
#include <functional>
#include <optional>

// Native frame ownership only. Caption drawing and ordinary input stay in Dart.
class WindowsFrame {
 public:
  struct State {
    bool custom_controls = false;
    bool maximized = false;
    bool fullscreen = false;
    bool active = false;
  };
  struct Rect { double x = 0, y = 0, width = 0, height = 0; };
  using CaptionRects = std::array<Rect, 3>;  // minimize, maximize, close.

  WindowsFrame(HWND window, HWND child, std::function<void()> changed);
  ~WindowsFrame();
  WindowsFrame(const WindowsFrame&) = delete;
  WindowsFrame& operator=(const WindowsFrame&) = delete;
  bool Enable(bool custom);
  bool SetCaptionRects(const CaptionRects& rects);
  const State& state() const { return state_; }
  std::optional<LRESULT> HandleMessage(UINT message, WPARAM wp, LPARAM lp);
  void Minimize();
  void ToggleMaximize();
  void Close();
  void StartDragging();

 private:
  static LRESULT CALLBACK ChildProc(HWND, UINT, WPARAM, LPARAM, UINT_PTR, DWORD_PTR);
  LRESULT HitTest(POINT screen) const;
  bool IsFullscreen() const;
  void NotifyIfChanged(const State& before);
  void ForwardPointer(UINT message, WPARAM wp, LPARAM screen);
  HWND window_, child_;
  std::function<void()> changed_;
  State state_;
  CaptionRects rects_{};
  double caption_layout_width_ = -1;
  bool subclassed_ = false;
  bool tracking_max_ = false;
};

#endif  // RUNNER_WINDOWS_FRAME_H_
