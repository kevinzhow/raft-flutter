#ifndef RAFT_DESKTOP_QA_IDENTITY_H_
#define RAFT_DESKTOP_QA_IDENTITY_H_
#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
// QA-only readback. No business actions, session data, titles or IPC payloads.
void raft_qa_observe_window(FlView* view, GtkWindow* window, bool child);
bool raft_qa_register_window_id(GtkWindow* window, const char* window_id);
#endif
