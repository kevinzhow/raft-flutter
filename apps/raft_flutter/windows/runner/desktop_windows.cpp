#include "desktop_windows.h"
#include "windows_frame.h"
#include "flutter/generated_plugin_registrant.h"
#include <desktop_multi_window/desktop_multi_window_plugin.h>
#include <flutter/method_channel.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <flutter/plugin_registrar_windows.h>
#include <dwmapi.h>
#include <commctrl.h>
#include <memory>
#include <filesystem>

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

namespace {
using Channel = flutter::MethodChannel<flutter::EncodableValue>;
using Value = flutter::EncodableValue;
constexpr UINT_PTR kServerWindowSubclass = 299;

class ChildHost : public flutter::Plugin {
 public:
  explicit ChildHost(flutter::FlutterViewController* controller)
      : controller_(controller), window_(GetAncestor(controller->view()->GetNativeWindow(), GA_ROOT)) {
  titlebar_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          controller_->engine()->messenger(), "app.raft/titlebar",
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
  frame_ = std::make_unique<WindowsFrame>(GetHandle(),
      controller_->view()->GetNativeWindow(), [this] {
        if (titlebar_channel_ && frame_) titlebar_channel_->InvokeMethod(
            "state", std::make_unique<flutter::EncodableValue>(FrameState(frame_->state())));
      });
  wchar_t titlebar_mode[16]{};
  GetEnvironmentVariableW(L"RAFT_DESKTOP_TITLE_BAR", titlebar_mode, 16);


    InstallDesktopWindowHost(controller_, window_);
    const bool subclassed = SetWindowSubclass(window_, Proc, kServerWindowSubclass,
        reinterpret_cast<DWORD_PTR>(this)) != FALSE;
    frame_->Enable(subclassed && wcscmp(titlebar_mode, L"native") != 0);
    memory_channel_ = std::make_unique<Channel>(controller_->engine()->messenger(),
        "app.raft/device-memory", &flutter::StandardMethodCodec::GetInstance());
    memory_channel_->SetMethodCallHandler([](const flutter::MethodCall<Value>& call,
        std::unique_ptr<flutter::MethodResult<Value>> result) {
      if (call.method_name() == "snapshot") {
        MEMORYSTATUSEX memory = {}; memory.dwLength = sizeof(memory);
        if (!GlobalMemoryStatusEx(&memory)) {
          result->Error("memory_unavailable", "Device memory could not be read."); return;
        }
        result->Success(flutter::EncodableMap{{Value("totalBytes"),
            Value(static_cast<int64_t>(memory.ullTotalPhys))}});
      } else if (call.method_name() == "availableStorageBytes") {
        const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
        const auto entry = args ? args->find(Value("path")) : flutter::EncodableMap::const_iterator{};
        const auto* path = args && entry != args->end() ? std::get_if<std::string>(&entry->second) : nullptr;
        ULARGE_INTEGER available = {};
        if (!path || path->empty() || !GetDiskFreeSpaceExW(std::filesystem::u8path(*path).c_str(),
            &available, nullptr, nullptr)) {
          result->Error("storage_unavailable", "Available storage could not be read."); return;
        }
        result->Success(Value(static_cast<int64_t>(available.QuadPart)));
      } else { result->NotImplemented(); }
    });
  }
  ~ChildHost() override {
    if (IsWindow(window_)) RemoveWindowSubclass(window_, Proc, kServerWindowSubclass);
  }
 private:
  HWND GetHandle() const { return window_; }
  static LRESULT CALLBACK Proc(HWND window, UINT message, WPARAM wp, LPARAM lp,
      UINT_PTR, DWORD_PTR data) {
    auto* self = reinterpret_cast<ChildHost*>(data);
    if (message == WM_NCDESTROY) {
      RemoveWindowSubclass(window, Proc, kServerWindowSubclass);
      return DefSubclassProc(window, message, wp, lp);
    }
    if (self->frame_) {
      const auto result = self->frame_->HandleMessage(message, wp, lp);
      if (result) return *result;
    }
    return DefSubclassProc(window, message, wp, lp);
  }
  flutter::FlutterViewController* controller_;
  HWND window_;
  std::unique_ptr<Channel> titlebar_channel_;
  std::unique_ptr<Channel> memory_channel_;
  std::unique_ptr<WindowsFrame> frame_;
};

// The messenger owns each handler until engine destruction. No captured
// primary HWND is reused for a child engine.
void ChildCreated(void* value) {
  auto* controller = reinterpret_cast<flutter::FlutterViewController*>(value);
  RegisterPlugins(controller->engine());
  auto* registrar = flutter::PluginRegistrarManager::GetInstance()
      ->GetRegistrar<flutter::PluginRegistrarWindows>(
          controller->engine()->GetRegistrarForPlugin("RaftDesktopWindowHost"));
  registrar->AddPlugin(std::make_unique<ChildHost>(controller));
}
}  // namespace

namespace {
class DesktopCloseGuard : public flutter::Plugin {
 public:
  DesktopCloseGuard(flutter::FlutterViewController* controller, HWND window, std::function<bool()> hidesOnClose)
      : window_(window), hides_on_close_(std::move(hidesOnClose)), channel_(controller->engine()->messenger(),
          "app.raft/desktop-window", &flutter::StandardMethodCodec::GetInstance()) {
    SetWindowSubclass(window_, Proc, 300, reinterpret_cast<DWORD_PTR>(this));
    channel_.SetMethodCallHandler([this](const flutter::MethodCall<Value>& call,
        std::unique_ptr<flutter::MethodResult<Value>> result) {
      if (call.method_name() == "directoryIdentity") {
        const auto* path = call.arguments() ? std::get_if<std::string>(call.arguments()) : nullptr;
        const auto wide = path ? std::filesystem::u8path(*path) : std::filesystem::path();
        HANDLE handle = path ? CreateFileW(wide.c_str(), FILE_READ_ATTRIBUTES,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr, OPEN_EXISTING,
            FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, nullptr) : INVALID_HANDLE_VALUE;
        BY_HANDLE_FILE_INFORMATION info{};
        if (handle == INVALID_HANDLE_VALUE || !GetFileInformationByHandle(handle, &info) ||
            !(info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) ||
            (info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT)) {
          if (handle != INVALID_HANDLE_VALUE) CloseHandle(handle);
          result->Success();
        } else {
          CloseHandle(handle);
          result->Success(Value(std::to_string(info.dwVolumeSerialNumber) + ":" +
              std::to_string(info.nFileIndexHigh) + ":" + std::to_string(info.nFileIndexLow)));
        }
      } else if (call.method_name() == "isActive") {
        result->Success(Value(GetForegroundWindow() == window_));
      } else if (call.method_name() == "focus") {
        if (IsIconic(window_)) ShowWindow(window_, SW_RESTORE);
        ShowWindow(window_, SW_SHOW); SetForegroundWindow(window_); result->Success();
      } else if (call.method_name() == "close" || call.method_name() == "forceClose") {
        allowed_ = call.method_name() == "forceClose";
        result->Success(); PostMessageW(window_, WM_CLOSE, 0, 0);
      } else { result->NotImplemented(); }
    });
  }
  ~DesktopCloseGuard() override {
    *alive_ = false;
    if (IsWindow(window_)) RemoveWindowSubclass(window_, Proc, 300);
  }
 private:
  static LRESULT CALLBACK Proc(HWND window, UINT message, WPARAM wp, LPARAM lp,
      UINT_PTR, DWORD_PTR data) {
    auto* self = reinterpret_cast<DesktopCloseGuard*>(data);
    if (message == WM_NCDESTROY) {
      RemoveWindowSubclass(window, Proc, 300);
      return DefSubclassProc(window, message, wp, lp);
    }
    if (message != WM_CLOSE || (self->hides_on_close_ && self->hides_on_close_())) return DefSubclassProc(window, message, wp, lp);
    if (self->allowed_) {
      self->allowed_ = false;
      return DefSubclassProc(window, message, wp, lp);
    }
    if (!self->pending_) {
      self->pending_ = true;
      auto alive = self->alive_;
      self->channel_.InvokeMethod("prepareClose", nullptr,
          std::make_unique<flutter::MethodResultFunctions<Value>>(
            [self, alive](const Value* value) {
              if (!*alive) return;
              self->pending_ = false;
              const bool* accepted = value ? std::get_if<bool>(value) : nullptr;
              if (accepted && *accepted) {
                self->allowed_ = true; PostMessageW(self->window_, WM_CLOSE, 0, 0);
              }
            },
            [self, alive](const std::string&, const std::string&, const Value*) {
              if (*alive) self->pending_ = false;
            }, [self, alive]() { if (*alive) self->pending_ = false; }));
    }
    return 0;
  }
  HWND window_;
  std::function<bool()> hides_on_close_;
  Channel channel_;
  bool pending_ = false, allowed_ = false;
  std::shared_ptr<bool> alive_ = std::make_shared<bool>(true);
};
}  // namespace

void InstallDesktopWindowHost(flutter::FlutterViewController* controller, HWND window, std::function<bool()> hidesOnClose) {
  auto* registrar = flutter::PluginRegistrarManager::GetInstance()
      ->GetRegistrar<flutter::PluginRegistrarWindows>(
          controller->engine()->GetRegistrarForPlugin("RaftDesktopCloseGuard"));
  registrar->AddPlugin(std::make_unique<DesktopCloseGuard>(controller, window, std::move(hidesOnClose)));
}

void RegisterDesktopChildWindows() {
  DesktopMultiWindowSetWindowCreatedCallback(ChildCreated);
}
