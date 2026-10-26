#include "windows_notifications.h"
#include <shobjidl.h>
#include <shlobj.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.UI.Notifications.h>
#include <winrt/Windows.Data.Xml.Dom.h>
#include <algorithm>

namespace {
using flutter::EncodableValue;
using flutter::EncodableMap;
constexpr ULONG_PTR kNotificationActivation = 0x52414654;
bool activation_ready = false;
std::string app_id;
std::string notification_icon;
std::vector<std::string> pending_activations;
winrt::Windows::UI::Notifications::ToastNotifier notifier{nullptr};

std::wstring ExecutablePath() {
  std::vector<wchar_t> path(32768);
  const auto length = GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
  if (!length || length >= path.size()) throw winrt::hresult_error(E_FAIL);
  return std::wstring(path.data(), length);
}

bool IsNotificationUri(const std::string& value) {
  return value.size() <= 16384 &&
      (value.rfind("raft-notification://open?", 0) == 0 ||
       value.rfind("raft-notification://open/?", 0) == 0 ||
       value.rfind("raft-notification-lab://open?", 0) == 0 ||
       value.rfind("raft-notification-lab://open/?", 0) == 0);
}

std::wstring XmlEscape(const std::string& value) {
  std::wstring escaped;
  for (auto ch : std::wstring(winrt::to_hstring(value))) {
    switch (ch) {
      case L'&': escaped += L"&amp;"; break;
      case L'<': escaped += L"&lt;"; break;
      case L'>': escaped += L"&gt;"; break;
      case L'\"': escaped += L"&quot;"; break;
      case L'\'': escaped += L"&apos;"; break;
      default: escaped += ch;
    }
  }
  return escaped;
}

void WriteProtocolValue(const std::wstring& path, const wchar_t* name,
                        const std::wstring& value) {
  HKEY key = nullptr;
  winrt::check_win32(RegCreateKeyExW(HKEY_CURRENT_USER, path.c_str(), 0,
      nullptr, 0, KEY_SET_VALUE, nullptr, &key, nullptr));
  const auto status = RegSetValueExW(key, name, 0, REG_SZ,
      reinterpret_cast<const BYTE*>(value.c_str()),
      static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
  RegCloseKey(key);
  winrt::check_win32(status);
}
}  // namespace

void InitializeWindowsNotifications(const std::string& id, const std::string& icon) {
  if (notifier) return;
  const auto scheme = id == "app.raft.raft_flutter.notificationlab"
      ? L"raft-notification-lab" : L"raft-notification";
  const auto path = std::wstring(L"Software\\Classes\\") + scheme;
  WriteProtocolValue(path, nullptr, L"URL:Raft notification");
  WriteProtocolValue(path, L"URL Protocol", L"");
  WriteProtocolValue(path + L"\\Application", L"ApplicationName",
      id == "app.raft.raft_flutter.notificationlab" ? L"Raft notification lab" : L"Raft");
  WriteProtocolValue(path + L"\\Application", L"ApplicationIcon", std::wstring(winrt::to_hstring(icon)));
  WriteProtocolValue(path + L"\\DefaultIcon", nullptr, std::wstring(winrt::to_hstring(icon)));
  WriteProtocolValue(path + L"\\shell\\open\\command", nullptr,
      L"\"" + ExecutablePath() + L"\" \"%1\"");
  SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nullptr, nullptr);
  notifier = winrt::Windows::UI::Notifications::ToastNotificationManager::CreateToastNotifier(
      winrt::to_hstring(id));
  app_id = id;
  const auto directory = ExecutablePath().substr(0, ExecutablePath().find_last_of(L"\\/"));
  notification_icon = winrt::to_string(
      winrt::Windows::Foundation::Uri(directory + L"\\notification_icon.png").AbsoluteUri());
}

void ShutdownWindowsNotifications() {
  notifier = nullptr;
}

void ShowWindowsNotification(const EncodableValue* arguments) {
  if (!notifier) throw winrt::hresult_error(E_UNEXPECTED);
  const auto values = arguments ? std::get_if<EncodableMap>(arguments) : nullptr;
  if (!values) throw winrt::hresult_error(E_INVALIDARG);
  const auto title = std::get<std::string>(values->at(EncodableValue("title")));
  const auto body = std::get<std::string>(values->at(EncodableValue("body")));
  const auto uri = std::get<std::string>(values->at(EncodableValue("uri")));
  const auto id = std::get<int32_t>(values->at(EncodableValue("id")));
  if (!IsNotificationUri(uri)) throw winrt::hresult_error(E_INVALIDARG);
  winrt::Windows::Data::Xml::Dom::XmlDocument xml;
  xml.LoadXml(
      L"<toast activationType='protocol' launch='" + XmlEscape(uri) +
      L"'><visual><binding template='ToastGeneric'><image placement='appLogoOverride' src='" +
      XmlEscape(notification_icon) + L"'/><text>" + XmlEscape(title) +
      L"</text><text>" + XmlEscape(body) + L"</text></binding></visual></toast>");
  winrt::Windows::UI::Notifications::ToastNotification notification(xml);
  notification.Tag(winrt::to_hstring(std::to_string(id)));
  notification.Group(L"Raft");
  notifier.Show(notification);
}

void ClearWindowsNotifications() {
  if (!app_id.empty()) winrt::Windows::UI::Notifications::ToastNotificationManager::History().Clear(
      winrt::to_hstring(app_id));
}

flutter::EncodableList TakeWindowsNotificationActivations() {
  activation_ready = true;
  flutter::EncodableList result;
  for (const auto& uri : pending_activations) result.emplace_back(uri);
  pending_activations.clear();
  return result;
}

bool ForwardWindowsNotificationActivation(const std::vector<std::string>& arguments) {
  const auto found = std::find_if(arguments.begin(), arguments.end(), IsNotificationUri);
  if (found == arguments.end()) return false;
  struct Context { std::wstring executable; HWND target = nullptr; DWORD process = 0; };
  Context context{ExecutablePath()};
  EnumWindows([](HWND window, LPARAM data) -> BOOL {
    auto& context = *reinterpret_cast<Context*>(data);
    wchar_t class_name[64]{}; GetClassNameW(window, class_name, 64);
    if (wcscmp(class_name, L"FLUTTER_RUNNER_WIN32_WINDOW") != 0) return TRUE;
    DWORD process = 0; GetWindowThreadProcessId(window, &process);
    if (process == GetCurrentProcessId()) return TRUE;
    HANDLE handle = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process);
    if (!handle) return TRUE;
    wchar_t executable[32768]{}; DWORD length = 32768;
    const auto read = QueryFullProcessImageNameW(handle, 0, executable, &length);
    CloseHandle(handle);
    if (!read || CompareStringOrdinal(executable, -1,
        context.executable.c_str(), -1, TRUE) != CSTR_EQUAL) return TRUE;
    context.target = window; context.process = process; return FALSE;
  }, reinterpret_cast<LPARAM>(&context));
  if (!context.target) return false;
  AllowSetForegroundWindow(context.process);
  COPYDATASTRUCT data{kNotificationActivation,
      static_cast<DWORD>(found->size() + 1), const_cast<char*>(found->c_str())};
  DWORD_PTR result = 0;
  SendMessageTimeoutW(context.target, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&data),
      SMTO_ABORTIFHUNG | SMTO_BLOCK, 2000, &result);
  return true;
}

void NormalizeWindowsNotificationArguments(std::vector<std::string>& arguments) {
  const std::string prefix = "----ms-protocol:";
  for (auto& argument : arguments) {
    if (argument.rfind(prefix, 0) == 0 && IsNotificationUri(argument.substr(prefix.size()))) {
      argument.erase(0, prefix.size());
    }
  }
}

bool HandleWindowsNotificationActivation(UINT message, LPARAM lparam,
    flutter::MethodChannel<EncodableValue>* channel, HWND window) {
  if (message != WM_COPYDATA || !lparam) return false;
  const auto& data = *reinterpret_cast<const COPYDATASTRUCT*>(lparam);
  if (data.dwData != kNotificationActivation || !data.lpData ||
      data.cbData < 2 || data.cbData > 16385) return false;
  const auto bytes = static_cast<const char*>(data.lpData);
  if (bytes[data.cbData - 1] != '\0') return false;
  const std::string uri(bytes, data.cbData - 1);
  if (!IsNotificationUri(uri)) return false;
  ShowWindow(window, IsIconic(window) ? SW_RESTORE : SW_SHOW);
  SetForegroundWindow(window);
  if (activation_ready && channel) {
    channel->InvokeMethod("activated", std::make_unique<EncodableValue>(uri));
  } else if (pending_activations.size() < 8) {
    pending_activations.push_back(uri);
  }
  return true;
}
