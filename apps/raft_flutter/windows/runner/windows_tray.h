#ifndef RUNNER_WINDOWS_TRAY_H_
#define RUNNER_WINDOWS_TRAY_H_

#include <windows.h>
#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>

#include <memory>
#include <optional>
#include <string>

#include "windows_exit.h"

// A shortcut launch restores the existing tray owner, including a hidden one.
bool ForwardWindowsTrayLaunch();

// Owns only this window's shell presence. Message/notification policy stays in Dart.
class WindowsTray {
 public:
  WindowsTray(flutter::BinaryMessenger* messenger, HWND window);
  ~WindowsTray();
  std::optional<LRESULT> HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);
  void PrepareExit(int64_t request_id, const char* reason, WindowsExit::Reply reply);
  void MarkQuitting() { quitting_ = true; }

 private:
  bool AddIcon();
  bool UpdateIcon();
  void RemoveIcon();
  void Present();
  void Hide();
  void ShowMenu(POINT point);
  void UpdateSystemMenu();
  void RemoveUpdateMenu();
  void CheckForUpdates();
  HICON MakeIcon() const;
  flutter::EncodableMap State() const;
  bool SaveClosePreference(bool value);
  void Configure(const flutter::EncodableMap& args);

  HWND window_;
  UINT taskbar_created_;
  UINT present_message_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HICON icon_ = nullptr;
  bool initialized_ = false, available_ = false, close_to_tray_ = true;
  bool quitting_ = false, lab_ = false;
  bool commands_ready_ = false, update_pending_ = false;
  std::shared_ptr<bool> alive_ = std::make_shared<bool>(true);
  int64_t unread_ = 0;
  std::wstring open_label_ = L"Open Raft", hide_label_ = L"Hide window";
  std::wstring quit_label_ = L"Quit Raft", unread_label_ = L"unread";
  std::wstring title_ = L"Raft";
  std::wstring update_label_ = L"Check for updates\u2026";
  std::wstring update_failed_label_ =
      L"Can't check for a new version right now. Try again later.";
};

#endif  // RUNNER_WINDOWS_TRAY_H_
