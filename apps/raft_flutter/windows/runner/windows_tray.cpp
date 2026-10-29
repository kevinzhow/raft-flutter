#include "windows_tray.h"

#include <flutter/standard_method_codec.h>
#include <flutter/method_result_functions.h>
#include <shellapi.h>
#include <windowsx.h>
#include <raft_updater/window_lifetime.h>

#include <algorithm>
#include <stdexcept>
#include <vector>

#include "resource.h"

namespace {
using flutter::EncodableMap;
using flutter::EncodableValue;
constexpr UINT kTrayCallback = WM_APP + 0x56;
constexpr UINT kOpen = 1, kHide = 2, kQuit = 3, kIcon = 1;
// Application system-menu commands must be below 0xF000; the low four bits
// are reserved by WM_SYSCOMMAND.
constexpr UINT kCheckUpdates = 0x1850, kUpdateSeparator = 0x1851;
constexpr wchar_t kProductPrefs[] = L"Software\\Raft\\Desktop";
constexpr wchar_t kLabPrefs[] = L"Software\\Raft\\WindowsTrayLab";
constexpr wchar_t kTrayOwner[] = L"Raft.TrayOwner";
constexpr wchar_t kPresentMessage[] = L"Raft.PresentTrayOwner";

bool Bool(const EncodableMap& args, const char* key, bool fallback = false) {
  const auto found = args.find(EncodableValue(key));
  if (found == args.end()) return fallback;
  const auto value = std::get_if<bool>(&found->second);
  return value ? *value : fallback;
}

std::wstring Text(const EncodableMap& args, const char* key,
                  const std::wstring& fallback) {
  const auto found = args.find(EncodableValue(key));
  if (found == args.end()) return fallback;
  const auto value = std::get_if<std::string>(&found->second);
  if (!value || value->empty() || value->size() > 256) return fallback;
  const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
      value->data(), static_cast<int>(value->size()), nullptr, 0);
  if (!length) return fallback;
  std::wstring result(static_cast<size_t>(length), L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value->data(),
      static_cast<int>(value->size()), result.data(), length);
  return result;
}

NOTIFYICONDATAW Data(HWND window) {
  NOTIFYICONDATAW data{};
  data.cbSize = sizeof(data);
  data.hWnd = window;
  data.uID = kIcon;
  return data;
}
}  // namespace

bool ForwardWindowsTrayLaunch() {
  wchar_t own_executable[32768]{};
  if (!GetModuleFileNameW(nullptr, own_executable, 32768)) return false;
  struct Context { const wchar_t* executable; HWND window = nullptr; DWORD process = 0; };
  Context context{own_executable};
  EnumWindows([](HWND window, LPARAM data) -> BOOL {
    if (!GetPropW(window, kTrayOwner)) return TRUE;
    auto& context = *reinterpret_cast<Context*>(data);
    DWORD process = 0;
    GetWindowThreadProcessId(window, &process);
    if (process == GetCurrentProcessId()) return TRUE;
    HANDLE handle = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process);
    if (!handle) return TRUE;
    wchar_t executable[32768]{}; DWORD length = 32768;
    const BOOL read = QueryFullProcessImageNameW(handle, 0, executable, &length);
    CloseHandle(handle);
    if (!read || CompareStringOrdinal(executable, -1, context.executable, -1, TRUE) != CSTR_EQUAL) return TRUE;
    context.window = window; context.process = process;
    return FALSE;
  }, reinterpret_cast<LPARAM>(&context));
  if (!context.window) return false;
  AllowSetForegroundWindow(context.process);
  DWORD_PTR result = 0;
  return SendMessageTimeoutW(context.window, RegisterWindowMessageW(kPresentMessage),
      0, 0, SMTO_ABORTIFHUNG | SMTO_BLOCK, 2000, &result) != 0;
}

WindowsTray::WindowsTray(flutter::BinaryMessenger* messenger, HWND window)
    : window_(window), taskbar_created_(RegisterWindowMessageW(L"TaskbarCreated")),
      present_message_(RegisterWindowMessageW(kPresentMessage)) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "app.raft/windows-tray",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    const auto args = call.arguments()
        ? std::get_if<EncodableMap>(call.arguments()) : nullptr;
    if (call.method_name() == "configure" && args) {
      try {
        Configure(*args);
        result->Success(EncodableValue(State()));
      } catch (...) {
        result->Error("tray-configuration-failed", "The tray could not be configured.");
      }
    } else if (call.method_name() == "state") {
      result->Success(EncodableValue(State()));
    } else if (call.method_name() == "setCloseToTray" && args) {
      if (!SaveClosePreference(Bool(*args, "enabled"))) {
        result->Error("tray-preference-failed", "The window preference could not be saved.");
      } else {
        result->Success(EncodableValue(State()));
      }
    } else if (call.method_name() == "setUnread" && args) {
      const auto found = args->find(EncodableValue("count"));
      int64_t count = -1;
      if (found != args->end()) {
        if (const auto v = std::get_if<int32_t>(&found->second)) count = *v;
        if (const auto v = std::get_if<int64_t>(&found->second)) count = *v;
      }
      if (count < 0 || count > 1000000000) {
        result->Error("invalid-unread", "An unread count is required.");
        return;
      }
      if (count != unread_) { unread_ = count; if (available_) UpdateIcon(); }
      result->Success();
    } else if (call.method_name() == "closeWindow") {
      result->Success();
      PostMessageW(window_, WM_CLOSE, 0, 0);
    } else if (call.method_name() == "quit") {
      result->Success();
      RequestRaftQuit(window_);
    } else if (call.method_name() == "dispose") {
      *alive_ = false;
      commands_ready_ = false;
      update_pending_ = false;
      RemoveUpdateMenu();
      RemoveIcon();
      // A retired optional bridge must never leave a live process unreachable.
      if (!quitting_ && !IsWindowVisible(window_)) Present();
      result->Success();
    } else {
      result->NotImplemented();
    }
  });
}

WindowsTray::~WindowsTray() {
  *alive_ = false;
  channel_->SetMethodCallHandler(nullptr);
  RemoveUpdateMenu();
  RemoveIcon();
}

void WindowsTray::PrepareExit(int64_t request_id, const char* reason,
                              WindowsExit::Reply reply) {
  auto result = std::make_unique<flutter::MethodResultFunctions<EncodableValue>>(
      [reply](const EncodableValue* value) {
        const auto map = value ? std::get_if<EncodableMap>(value) : nullptr;
        if (!map) return;
        const auto id = map->find(EncodableValue("requestId"));
        const auto outcome = map->find(EncodableValue("outcome"));
        if (id == map->end() || outcome == map->end()) return;
        const auto text = std::get_if<std::string>(&outcome->second);
        if (!text) return;
        if (const auto number32 = std::get_if<int32_t>(&id->second)) reply(*number32, *text);
        else if (const auto number64 = std::get_if<int64_t>(&id->second)) reply(*number64, *text);
      },
      [reply, request_id](const std::string&, const std::string&, const EncodableValue*) {
        reply(request_id, "channelError");
      },
      [reply, request_id]() { reply(request_id, "unavailable"); });
  channel_->InvokeMethod("prepareExit", std::make_unique<EncodableValue>(EncodableMap{
      {EncodableValue("requestId"), EncodableValue(request_id)},
      {EncodableValue("reason"), EncodableValue(reason)}}), std::move(result));
}

void WindowsTray::Configure(const EncodableMap& args) {
  const bool lab = Bool(args, "lab");
  if (initialized_ && lab != lab_) throw std::runtime_error("Tray identity changed");
  if (!initialized_) {
    lab_ = lab;
    DWORD value = 1, bytes = sizeof(value);
    if (RegGetValueW(HKEY_CURRENT_USER, lab_ ? kLabPrefs : kProductPrefs,
        L"CloseToTray", RRF_RT_REG_DWORD, nullptr, &value, &bytes) == ERROR_SUCCESS) {
      close_to_tray_ = value != 0;
    }
    initialized_ = true;
  }
  title_ = lab_ ? L"Raft tray lab" : L"Raft";
  open_label_ = Text(args, "open", open_label_);
  hide_label_ = Text(args, "hide", hide_label_);
  quit_label_ = Text(args, "quit", quit_label_);
  unread_label_ = Text(args, "unread", unread_label_);
  update_label_ = Text(args, "checkUpdates", update_label_);
  update_failed_label_ = Text(args, "updateFailed", update_failed_label_);
  if (!commands_ready_) alive_ = std::make_shared<bool>(true);
  commands_ready_ = true;
  UpdateSystemMenu();
  if (available_) UpdateIcon(); else AddIcon();
}

bool WindowsTray::SaveClosePreference(bool value) {
  if (!initialized_) return false;
  HKEY key = nullptr;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, lab_ ? kLabPrefs : kProductPrefs,
      0, nullptr, 0, KEY_SET_VALUE, nullptr, &key, nullptr) != ERROR_SUCCESS) return false;
  DWORD stored = value ? 1 : 0;
  const auto result = RegSetValueExW(key, L"CloseToTray", 0, REG_DWORD,
      reinterpret_cast<const BYTE*>(&stored), sizeof(stored));
  RegCloseKey(key);
  if (result == ERROR_SUCCESS) close_to_tray_ = value;
  return result == ERROR_SUCCESS;
}

HICON WindowsTray::MakeIcon() const {
  const int size = GetSystemMetricsForDpi(SM_CXSMICON, GetDpiForWindow(window_));
  HICON base = static_cast<HICON>(LoadImageW(GetModuleHandle(nullptr),
      MAKEINTRESOURCEW(IDI_APP_ICON), IMAGE_ICON, size, size, LR_DEFAULTCOLOR));
  if (!base || unread_ == 0) return base;
  BITMAPINFO info{};
  info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  info.bmiHeader.biWidth = size;
  info.bmiHeader.biHeight = -size;
  info.bmiHeader.biPlanes = 1;
  info.bmiHeader.biBitCount = 32;
  info.bmiHeader.biCompression = BI_RGB;
  void* pixels = nullptr;
  HDC dc = CreateCompatibleDC(nullptr);
  HBITMAP bitmap = CreateDIBSection(dc, &info, DIB_RGB_COLORS, &pixels, nullptr, 0);
  if (!dc || !bitmap || !pixels) {
    if (bitmap) DeleteObject(bitmap);
    if (dc) DeleteDC(dc);
    return base;
  }
  auto old = SelectObject(dc, bitmap);
  ZeroMemory(pixels, static_cast<size_t>(size) * size * 4);
  DrawIconEx(dc, 0, 0, base, size, size, 0, nullptr, DI_NORMAL);
  const int diameter = std::max(6, size / 2);
  HBRUSH brush = CreateSolidBrush(RGB(218, 48, 56));
  auto old_brush = SelectObject(dc, brush);
  auto old_pen = SelectObject(dc, GetStockObject(NULL_PEN));
  Ellipse(dc, size - diameter, size - diameter, size, size);
  auto bytes = static_cast<BYTE*>(pixels);
  for (int i = 0; i < size * size; ++i) {
    auto pixel = bytes + i * 4;
    if (!pixel[3] && (pixel[0] || pixel[1] || pixel[2])) pixel[3] = 255;
  }
  // A monochrome bitmap has WORD-aligned rows. Explicitly clear the mask;
  // nullptr leaves its pixels uninitialized and can hide parts of the icon.
  const size_t mask_stride = ((static_cast<size_t>(size) + 15) / 16) * 2;
  const std::vector<BYTE> mask_bits(mask_stride * size, 0);
  HBITMAP mask = CreateBitmap(size, size, 1, 1, mask_bits.data());
  ICONINFO icon_info{};
  icon_info.fIcon = TRUE;
  icon_info.hbmColor = bitmap;
  icon_info.hbmMask = mask;
  HICON result = mask ? CreateIconIndirect(&icon_info) : nullptr;
  SelectObject(dc, old_pen);
  SelectObject(dc, old_brush);
  SelectObject(dc, old);
  DeleteObject(brush);
  if (mask) DeleteObject(mask);
  DeleteObject(bitmap);
  DeleteDC(dc);
  if (result) { DestroyIcon(base); return result; }
  return base;
}

bool WindowsTray::AddIcon() {
  if (!initialized_ || quitting_) return false;
  HICON next = MakeIcon();
  if (!next) return false;
  auto data = Data(window_);
  data.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP | NIF_SHOWTIP;
  data.uCallbackMessage = kTrayCallback;
  data.hIcon = next;
  std::wstring tip = title_;
  if (unread_ > 0) tip += L" - " + std::to_wstring(unread_) + L" " + unread_label_;
  wcsncpy_s(data.szTip, tip.c_str(), _TRUNCATE);
  if (!Shell_NotifyIconW(NIM_ADD, &data)) { DestroyIcon(next); return false; }
  if (icon_) DestroyIcon(icon_);
  icon_ = next;
  available_ = true;
  data.uVersion = NOTIFYICON_VERSION_4;
  if (!Shell_NotifyIconW(NIM_SETVERSION, &data)) { RemoveIcon(); return false; }
  SetPropW(window_, kTrayOwner, reinterpret_cast<HANDLE>(static_cast<INT_PTR>(1)));
  return true;
}

bool WindowsTray::UpdateIcon() {
  HICON next = MakeIcon();
  if (!next) return false;
  auto data = Data(window_);
  data.uFlags = NIF_ICON | NIF_TIP | NIF_SHOWTIP;
  data.hIcon = next;
  std::wstring tip = title_;
  if (unread_ > 0) tip += L" - " + std::to_wstring(unread_) + L" " + unread_label_;
  wcsncpy_s(data.szTip, tip.c_str(), _TRUNCATE);
  if (!Shell_NotifyIconW(NIM_MODIFY, &data)) {
    DestroyIcon(next); available_ = false;
    if (!AddIcon() && !IsWindowVisible(window_)) Present();
    return available_;
  }
  if (icon_) DestroyIcon(icon_);
  icon_ = next;
  return true;
}

void WindowsTray::RemoveIcon() {
  RemovePropW(window_, kTrayOwner);
  if (available_) { auto data = Data(window_); Shell_NotifyIconW(NIM_DELETE, &data); }
  available_ = false;
  if (icon_) { DestroyIcon(icon_); icon_ = nullptr; }
}

void WindowsTray::Present() {
  ShowWindow(window_, IsIconic(window_) ? SW_RESTORE : SW_SHOW);
  SetForegroundWindow(window_);
}

void WindowsTray::Hide() {
  if (!available_) return;
  ShowWindow(window_, SW_HIDE);
  channel_->InvokeMethod("hidden", std::make_unique<EncodableValue>(true));
}

void WindowsTray::ShowMenu(POINT point) {
  HMENU menu = CreatePopupMenu();
  if (!menu) return;
  AppendMenuW(menu, MF_STRING, kOpen, open_label_.c_str());
  SetMenuDefaultItem(menu, kOpen, FALSE);
  if (IsWindowVisible(window_)) AppendMenuW(menu, MF_STRING, kHide, hide_label_.c_str());
  AppendMenuW(menu, MF_STRING | (update_pending_ ? MF_GRAYED : MF_ENABLED),
      kCheckUpdates, update_label_.c_str());
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, kQuit, quit_label_.c_str());
  SetForegroundWindow(window_);
  const UINT selected = TrackPopupMenu(menu,
      TPM_RETURNCMD | TPM_RIGHTBUTTON, point.x, point.y, 0, window_, nullptr);
  DestroyMenu(menu);
  PostMessageW(window_, WM_NULL, 0, 0);
  if (selected == kOpen) Present();
  else if (selected == kHide) Hide();
  else if (selected == kCheckUpdates) CheckForUpdates();
  else if (selected == kQuit) RequestRaftQuit(window_);
  else { auto data = Data(window_); Shell_NotifyIconW(NIM_SETFOCUS, &data); }
}

void WindowsTray::UpdateSystemMenu() {
  if (!commands_ready_) return;
  HMENU menu = GetSystemMenu(window_, FALSE);
  if (!menu) return;
  const UINT flags = MF_BYCOMMAND | MF_STRING |
      (update_pending_ ? MF_GRAYED : MF_ENABLED);
  if (GetMenuState(menu, kCheckUpdates, MF_BYCOMMAND) == static_cast<UINT>(-1)) {
    InsertMenuW(menu, SC_CLOSE, MF_BYCOMMAND | MF_SEPARATOR,
        kUpdateSeparator, nullptr);
    InsertMenuW(menu, kUpdateSeparator, flags, kCheckUpdates, update_label_.c_str());
  } else {
    ModifyMenuW(menu, kCheckUpdates, flags, kCheckUpdates, update_label_.c_str());
  }
  DrawMenuBar(window_);
}

void WindowsTray::RemoveUpdateMenu() {
  if (HMENU menu = GetSystemMenu(window_, FALSE)) {
    DeleteMenu(menu, kCheckUpdates, MF_BYCOMMAND);
    DeleteMenu(menu, kUpdateSeparator, MF_BYCOMMAND);
    DrawMenuBar(window_);
  }
}

void WindowsTray::CheckForUpdates() {
  if (!commands_ready_ || update_pending_ || quitting_) return;
  update_pending_ = true;
  UpdateSystemMenu();
  Present();
  const auto alive = alive_;
  const auto finish = [this, alive](bool started) {
    // A method reply can arrive after this window's bridge has been retired.
    if (!*alive || !commands_ready_) return;
    update_pending_ = false;
    UpdateSystemMenu();
    if (started || quitting_) return;
    const int choice = MessageBoxW(window_, update_failed_label_.c_str(),
        update_label_.c_str(), MB_RETRYCANCEL | MB_ICONERROR);
    if (*alive && commands_ready_ && !quitting_ && choice == IDRETRY) {
      PostMessageW(window_, WM_SYSCOMMAND, kCheckUpdates, 0);
    }
  };
  auto result = std::make_unique<flutter::MethodResultFunctions<EncodableValue>>(
      [finish](const EncodableValue* value) {
        const auto outcome = value ? std::get_if<std::string>(value) : nullptr;
        finish(outcome && (*outcome == "started" || *outcome == "openedReleasePage"));
      },
      [finish](const std::string&, const std::string&, const EncodableValue*) { finish(false); },
      [finish]() { finish(false); });
  channel_->InvokeMethod("checkForUpdates", nullptr, std::move(result));
}

EncodableMap WindowsTray::State() const {
  return {{EncodableValue("available"), EncodableValue(available_)},
      {EncodableValue("closeToTray"), EncodableValue(close_to_tray_)},
      {EncodableValue("visible"), EncodableValue(IsWindowVisible(window_) != FALSE)},
      {EncodableValue("unread"), EncodableValue(unread_)}};
}

std::optional<LRESULT> WindowsTray::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == WM_SYSCOMMAND && (wparam & 0xFFF0) == kCheckUpdates) {
    CheckForUpdates(); return 0;
  }
  if (present_message_ && message == present_message_ && initialized_ && !quitting_) {
    Present(); return 0;
  }
  if (taskbar_created_ && message == taskbar_created_) {
    available_ = false;
    if (!AddIcon() && !IsWindowVisible(window_) && !quitting_) Present();
    return 0;
  }
  if (message == WM_CLOSE && close_to_tray_ && available_ && !quitting_) {
    Hide(); return 0;
  }
  if (message == WM_DPICHANGED && available_) UpdateIcon();
  if (message != kTrayCallback) return std::nullopt;
  const UINT event = LOWORD(lparam);
  if (event == NIN_SELECT || event == NIN_KEYSELECT) Present();
  else if (event == WM_CONTEXTMENU) {
    POINT point{GET_X_LPARAM(wparam), GET_Y_LPARAM(wparam)};
    if (point.x == -1 && point.y == -1) GetCursorPos(&point);
    ShowMenu(point);
  }
  return 0;
}
