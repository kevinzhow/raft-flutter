#ifndef RAFT_DESKTOP_VIEW_CLOSE_H_
#define RAFT_DESKTOP_VIEW_CLOSE_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

// The plugin unparents its child view during window destruction. Retire that
// owned view even when a pending raster/key operation still references it.
void raft_desktop_destroy_child_view_after_close(FlView* view, GtkWindow* window);

#endif
