#ifndef RUNNER_WINDOWS_NOTIFICATIONS_H_
#define RUNNER_WINDOWS_NOTIFICATIONS_H_

#include <windows.h>
#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>
#include <memory>
#include <string>
#include <vector>

// Protocol clicks return to the existing process when its executable matches.
void NormalizeWindowsNotificationArguments(std::vector<std::string>& arguments);
bool ForwardWindowsNotificationActivation(const std::vector<std::string>& arguments);
bool HandleWindowsNotificationActivation(
    UINT message, LPARAM lparam,
    flutter::MethodChannel<flutter::EncodableValue>* channel, HWND window);
void InitializeWindowsNotifications(const std::string& app_id, const std::string& icon);
void ShowWindowsNotification(const flutter::EncodableValue* arguments);
void ClearWindowsNotifications();
flutter::EncodableList TakeWindowsNotificationActivations();
void ShutdownWindowsNotifications();

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
CreateWindowsNotificationsChannel(flutter::BinaryMessenger* messenger,
                                  HWND window);

#endif
