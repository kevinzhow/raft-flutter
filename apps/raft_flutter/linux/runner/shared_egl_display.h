#ifndef RAFT_SHARED_EGL_DISPLAY_H_
#define RAFT_SHARED_EGL_DISPLAY_H_

#include <flutter_linux/flutter_linux.h>

// Main-thread Linux host boundary. Does not retain engines or windows.
void raft_shared_egl_watch_engine(FlEngine* engine);
void raft_desktop_track_window(FlView* view, GtkWindow* window);
bool raft_desktop_finish_quit();
bool raft_shared_egl_prepare_open(GtkWindow* realized_window);
// Call only after g_application_run AND application/window disposal.
bool raft_shared_egl_release();

#endif
