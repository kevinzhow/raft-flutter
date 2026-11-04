#include "my_application.h"
#include "shared_egl_display.h"

int main(int argc, char** argv) {
  g_autoptr(MyApplication) app = my_application_new();
  const int result = g_application_run(G_APPLICATION(app), argc, argv);
  // GtkApplication disposal must finish before terminating the display still
  // used by GTK and by the individual Flutter engines during window teardown.
  g_clear_object(&app);
  if (!raft_shared_egl_release()) {
    g_warning("Shared EGL display teardown was incomplete");
    return result == 0 ? 1 : result;
  }
  return result;
}
