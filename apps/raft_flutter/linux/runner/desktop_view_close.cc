#include "desktop_view_close.h"
#ifdef RAFT_MULTIWINDOW_QA
#include <cstdio>
#endif

void raft_desktop_destroy_child_view_after_close(FlView* view, GtkWindow* window) {
  auto* weak = new GWeakRef;
  g_weak_ref_init(weak, G_OBJECT(view));
  // Run after the plugin has removed its window/channel registry entry. A
  // removed view can still have a raster/key reference, so unparenting alone
  // does not guarantee GtkWidget::destroy and its engine-reference release.
  g_signal_connect_data(window, "destroy", G_CALLBACK(+[](GtkWidget* widget, gpointer data) {
    g_autoptr(GObject) owned = G_OBJECT(g_weak_ref_get(static_cast<GWeakRef*>(data)));
#ifdef RAFT_MULTIWINDOW_QA
    std::fprintf(stderr, "RAFT_EGL_LIFETIME event=orphan_view_close window=%p view=%p alive=%d\n",
                 static_cast<void*>(widget), static_cast<void*>(owned), owned != nullptr);
#else
    (void)widget;
#endif
    if (!owned) return;
#ifdef RAFT_MULTIWINDOW_QA
    std::fprintf(stderr, "RAFT_EGL_LIFETIME event=orphan_view_dispose view=%p engine=%p\n",
                 static_cast<void*>(owned),
                 static_cast<void*>(fl_view_get_engine(FL_VIEW(owned))));
#endif
    // Use the normal GTK lifecycle. Do not force FlEngine disposal, steal a
    // reference, or cancel unrelated objects/main-context sources.
    gtk_widget_destroy(GTK_WIDGET(owned));
  }), weak, [](gpointer data, GClosure*) {
    auto* ref = static_cast<GWeakRef*>(data);
    g_weak_ref_clear(ref);
    delete ref;
  }, G_CONNECT_AFTER);
}
