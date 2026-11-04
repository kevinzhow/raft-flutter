#ifndef RUNNER_DESKTOP_WINDOWS_H_
#define RUNNER_DESKTOP_WINDOWS_H_
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <functional>
void InstallDesktopWindowHost(flutter::FlutterViewController* controller, HWND window, std::function<bool()> hidesOnClose = {});
void RegisterDesktopChildWindows();
#endif
