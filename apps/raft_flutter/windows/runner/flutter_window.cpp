#include <filesystem>
#include "flutter_window.h"

#include <dwmapi.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <optional>
#include <raft_updater/window_lifetime.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

// DWMWA_CAPTION_COLOR / DWMWA_TEXT_COLOR / DWMWA_USE_IMMERSIVE_DARK_MODE.
// The first two exist from Windows 11 (build 22000); older systems reject
// them and keep their own caption, which is harmless. Spelled as numbers so an
// older SDK still builds.
constexpr DWORD kCaptionColor = 35;
constexpr DWORD kCaptionTextColor = 36;
constexpr DWORD kImmersiveDarkMode = 20;

int64_t IntArgument(const flutter::EncodableMap& arguments, const char* key) {
  auto found = arguments.find(flutter::EncodableValue(key));
  if (found == arguments.end()) return 0;
  if (const auto* value = std::get_if<int32_t>(&found->second)) return *value;
  if (const auto* value = std::get_if<int64_t>(&found->second)) return *value;
  return 0;
}

// Dart sends 0xAARRGGBB; COLORREF is 0x00BBGGRR.
COLORREF ToColorRef(int64_t argb) {
  return RGB((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);
}

flutter::EncodableValue FrameState(const WindowsFrame::State& state) {
  return flutter::EncodableMap{
      {flutter::EncodableValue("height"), flutter::EncodableValue(0.0)},
      {flutter::EncodableValue("leadingInset"), flutter::EncodableValue(0.0)},
      {flutter::EncodableValue("customControls"), flutter::EncodableValue(state.custom_controls)},
      {flutter::EncodableValue("maximized"), flutter::EncodableValue(state.maximized)},
      {flutter::EncodableValue("fullscreen"), flutter::EncodableValue(state.fullscreen)},
      {flutter::EncodableValue("active"), flutter::EncodableValue(state.active)},
      {flutter::EncodableValue("maximizeHovered"), flutter::EncodableValue(state.maximize_hovered)},
      {flutter::EncodableValue("buttonLayout"), flutter::EncodableValue(":minimize,maximize,close")}};
}

double DoubleArgument(const flutter::EncodableMap& arguments, const char* key) {
  const auto found = arguments.find(flutter::EncodableValue(key));
  if (found == arguments.end()) return 0;
  if (const auto* value = std::get_if<double>(&found->second)) return *value;
  return static_cast<double>(IntArgument(arguments, key));
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  memory_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "app.raft/device-memory",
          &flutter::StandardMethodCodec::GetInstance());
  memory_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "availableStorageBytes") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          const auto entry = args ? args->find(flutter::EncodableValue("path"))
                                  : flutter::EncodableMap::const_iterator{};
          const auto* path = args && entry != args->end()
              ? std::get_if<std::string>(&entry->second) : nullptr;
          ULARGE_INTEGER available = {};
          if (!path || path->empty() || !GetDiskFreeSpaceExW(
                  std::filesystem::u8path(*path).c_str(), &available, nullptr, nullptr)) {
            result->Error("storage_unavailable", "Available storage could not be read.");
          } else {
            result->Success(flutter::EncodableValue(static_cast<int64_t>(available.QuadPart)));
          }
          return;
        }
        if (call.method_name() != "snapshot") {
          result->NotImplemented();
          return;
        }
        MEMORYSTATUSEX memory = {};
        memory.dwLength = sizeof(memory);
        if (!GlobalMemoryStatusEx(&memory)) {
          result->Error("memory_unavailable", "Device memory could not be read.");
          return;
        }
        flutter::EncodableMap values;
        values[flutter::EncodableValue("totalBytes")] =
            flutter::EncodableValue(static_cast<int64_t>(memory.ullTotalPhys));
        result->Success(flutter::EncodableValue(values));
      });
  notifications_channel_ = CreateWindowsNotificationsChannel(
      flutter_controller_->engine()->messenger(), GetHandle());
  tray_ = std::make_unique<WindowsTray>(
      flutter_controller_->engine()->messenger(), GetHandle());
  exit_ = std::make_unique<WindowsExit>(GetHandle(),
      RegisterWindowMessageW(kRaftExplicitQuitMessage),
      [this](int64_t id, const char* reason, WindowsExit::Reply reply) {
        tray_->PrepareExit(id, reason, std::move(reply));
      });
  // Dart owns the shared 48px bar and buttons; Windows retains resize/snap and
  // system-menu behavior. Native caption mode remains an explicit fallback.
  titlebar_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "app.raft/titlebar",
          &flutter::StandardMethodCodec::GetInstance());
  HWND window_handle = GetHandle();
  titlebar_channel_->SetMethodCallHandler(
      [this, window_handle](
          const flutter::MethodCall<flutter::EncodableValue>& call,
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
              result) {
        if (call.method_name() == "status") {
          result->Success(FrameState(frame_ ? frame_->state() : WindowsFrame::State{}));
        } else if (call.method_name() == "setIntegrated") {
          // This selects workspace vs. standalone Dart header, not native mode.
          result->Success(FrameState(frame_ ? frame_->state() : WindowsFrame::State{}));
        } else if (call.method_name() == "setCaptionButtonRects") {
          WindowsFrame::CaptionRects rects{};
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          const char* names[] = {"minimize", "maximize", "close"};
          if (arguments) {
            for (size_t i = 0; i < rects.size(); ++i) {
              const auto entry = arguments->find(flutter::EncodableValue(names[i]));
              if (entry == arguments->end()) continue;
              const auto* rect = std::get_if<flutter::EncodableMap>(&entry->second);
              if (rect) rects[i] = {DoubleArgument(*rect, "x"), DoubleArgument(*rect, "y"),
                                   DoubleArgument(*rect, "width"), DoubleArgument(*rect, "height")};
            }
          }
          if (frame_ && !frame_->SetCaptionRects(rects)) {
            result->Error("invalid_caption_rects", "Caption positions must be finite nonnegative logical coordinates.");
          } else { result->Success(); }
        } else if (call.method_name() == "minimize" && frame_) {
          frame_->Minimize(); result->Success();
        } else if ((call.method_name() == "toggleMaximize" || call.method_name() == "doubleClick") && frame_) {
          frame_->ToggleMaximize(); result->Success();
        } else if (call.method_name() == "close" && frame_) {
          frame_->Close(); result->Success();
        } else if (call.method_name() == "startDragging" && frame_) {
          // Finish the channel reply before entering the OS's modal move loop.
          result->Success(); frame_->StartDragging();
        } else if (call.method_name() == "setStyle") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments != nullptr) {
            COLORREF background =
                ToColorRef(IntArgument(*arguments, "background"));
            DwmSetWindowAttribute(window_handle, kCaptionColor, &background,
                                  sizeof(background));
            DwmSetWindowAttribute(window_handle, kCaptionTextColor,
                                  &background, sizeof(background));
            auto dark = arguments->find(flutter::EncodableValue("dark"));
            if (dark != arguments->end()) {
              if (const auto* value = std::get_if<bool>(&dark->second)) {
                BOOL immersive = *value ? TRUE : FALSE;
                DwmSetWindowAttribute(window_handle, kImmersiveDarkMode,
                                      &immersive, sizeof(immersive));
              }
            }
          }
          result->Success();
        } else if (call.method_name() == "setTitle") {
          // The window's name for the taskbar and Alt+Tab (the caption text
          // is drawn in the caption colour, so the bar stays empty).
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments != nullptr) {
            auto title = arguments->find(flutter::EncodableValue("title"));
            if (title != arguments->end()) {
              if (const auto* text = std::get_if<std::string>(&title->second)) {
                const int length = MultiByteToWideChar(
                    CP_UTF8, 0, text->data(), static_cast<int>(text->size()),
                    nullptr, 0);
                std::wstring wide(length > 0 ? length : 0, L'\0');
                if (length > 0) {
                  MultiByteToWideChar(CP_UTF8, 0, text->data(),
                                      static_cast<int>(text->size()),
                                      wide.data(), length);
                  SetWindowTextW(window_handle, wide.c_str());
                }
              }
            }
          }
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  frame_ = std::make_unique<WindowsFrame>(GetHandle(),
      flutter_controller_->view()->GetNativeWindow(), [this] {
        if (titlebar_channel_ && frame_) titlebar_channel_->InvokeMethod(
            "state", std::make_unique<flutter::EncodableValue>(FrameState(frame_->state())));
      });
  wchar_t titlebar_mode[16]{};
  GetEnvironmentVariableW(L"RAFT_DESKTOP_TITLE_BAR", titlebar_mode, 16);
  frame_->Enable(wcscmp(titlebar_mode, L"native") != 0);

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  // Unhook the child HWND before Flutter destroys it.
  frame_ = nullptr;
  exit_ = nullptr;
  tray_ = nullptr;
  notifications_channel_ = nullptr;
  titlebar_channel_ = nullptr;
  memory_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (exit_) {
    const auto result = exit_->HandleMessage(message, wparam, lparam);
    if (exit_ && exit_->quitting() && tray_) tray_->MarkQuitting();
    if (result) return *result;
    if (message == WM_CLOSE && exit_ && exit_->ready_to_close()) {
      return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
    }
  }
  if (tray_) {
    const auto result = tray_->HandleMessage(message, wparam, lparam);
    if (result) return *result;
  }
  if (HandleWindowsNotificationActivation(message, lparam,
      notifications_channel_.get(), hwnd)) return TRUE;
  if (frame_) {
    const auto result = frame_->HandleMessage(message, wparam, lparam);
    if (result) return *result;
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
