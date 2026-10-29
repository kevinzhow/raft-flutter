#ifndef RAFT_UPDATER_WINDOW_LIFETIME_H_
#define RAFT_UPDATER_WINDOW_LIFETIME_H_

#include <windows.h>

// Shared by the runner and WinSparkle: installing an update must terminate the
// process even when an ordinary WM_CLOSE means "keep running in the tray".
inline constexpr wchar_t kRaftExplicitQuitMessage[] = L"Raft.QuitApplication";
inline void RequestRaftQuit(HWND window) {
  PostMessageW(window, RegisterWindowMessageW(kRaftExplicitQuitMessage), 0, 0);
}

#endif  // RAFT_UPDATER_WINDOW_LIFETIME_H_
