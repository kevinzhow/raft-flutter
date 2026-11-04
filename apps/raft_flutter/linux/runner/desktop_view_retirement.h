#ifndef RUNNER_DESKTOP_VIEW_RETIREMENT_H_
#define RUNNER_DESKTOP_VIEW_RETIREMENT_H_

#include <flutter_linux/flutter_linux.h>

// Keep only this view's existing descendants alive across GTK destruction.
// The predicate preserves the original single-window lifecycle.
// Their dispose still runs normally; their finalization follows the engine's
// real shutdown, so an in-flight raster callback cannot use a freed renderer.
void raft_desktop_retire_view_children_after_engine(FlView* view,
                                                    bool (*enabled)());

#endif  // RUNNER_DESKTOP_VIEW_RETIREMENT_H_
