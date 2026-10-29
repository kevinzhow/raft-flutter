#ifndef RAFT_VSYNC_DRIVER_H_
#define RAFT_VSYNC_DRIVER_H_

#include <flutter_linux/flutter_linux.h>

// Flutter's GTK embedder (3.47) never installs a vsync callback, so the
// engine paces frames with a fixed 1/60 s timer whatever the monitor's rate.
// Call this after fl_view_new() and before the view is realized (that starts
// the engine): it installs a vsync callback that releases each frame on the
// GTK frame clock, which follows the compositor (120 Hz on a 120 Hz output).
// Frames are only requested while the engine asks for one, so an idle window
// stays at 0 fps. RAFT_LINUX_VSYNC=0 keeps the engine's own timer;
// RAFT_LINUX_VSYNC_STATS=1 prints delivered frames per second to stderr.
// Anything unexpected (a different engine layout) leaves the engine untouched.
void raft_vsync_install(FlView* view);

#endif  // RAFT_VSYNC_DRIVER_H_
