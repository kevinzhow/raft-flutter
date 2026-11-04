#include "my_application.h"
#include "shared_egl_display.h"

int main(int argc, char** argv) {
  g_autoptr(MyApplication) app = my_application_new();
  const int result = g_application_run(G_APPLICATION(app), argc, argv);
  // Flutter may have detached rather than destroyed GtkApplication windows.
  // Retire only our weakly registered windows and their queued completions
  // while the application/callback owner is still alive.
  const bool quit_complete = raft_desktop_finish_quit();
  g_clear_object(&app);
  const bool display_released = raft_shared_egl_release();
  if (!quit_complete || !display_released) {
    g_warning("Shared EGL display teardown was incomplete");
    return result == 0 ? 1 : result;
  }
  return result;
}
