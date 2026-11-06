#ifndef RAFT_SYSTEM_WEBVIEW_HOST_BOOTSTRAP_H_
#define RAFT_SYSTEM_WEBVIEW_HOST_BOOTSTRAP_H_
#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

// GTK-only host structure, shared by the core runner and optional backend.
// It never loads WebKit. Reparenting a realized FlView destroys its GL surface,
// so the hook must exist before the view is parented, including child engines.
// GTK overlay adaptation: webview_all_linux ab32ceb7f0bb0585432986908875c0a5fe0df9a6.
// Copyright 2021-2026 Abandoft. See ../LICENSE.upstream and upstream.json.
namespace raft_webview_host {
inline gboolean ParentSet(GSignalInvocationHint*, guint count,
                          const GValue* args, gpointer) {
  if (count == 0) return TRUE;
  auto* object = G_OBJECT(g_value_get_object(&args[0]));
  if (!object || !FL_IS_VIEW(object) ||
      g_object_get_data(object, "raft-system-webview-overlay")) return TRUE;
  auto* view = GTK_WIDGET(object);
  if (GTK_IS_OVERLAY(gtk_widget_get_parent(view)) ||
      gtk_widget_get_realized(view)) return TRUE;
  GList* children = gtk_container_get_children(GTK_CONTAINER(view));
  if (!children || children->next) { g_list_free(children); return TRUE; }
  auto* content = GTK_WIDGET(children->data);
  g_object_ref(content);
  gtk_container_remove(GTK_CONTAINER(view), content);
  GtkWidget* overlay = gtk_overlay_new();
  gtk_widget_set_hexpand(overlay, TRUE);
  gtk_widget_set_vexpand(overlay, TRUE);
  gtk_container_add(GTK_CONTAINER(overlay), content);
  gtk_container_add(GTK_CONTAINER(view), overlay);
  gtk_widget_show(overlay);
  g_object_set_data_full(object, "raft-system-webview-overlay",
                         g_object_ref(overlay), g_object_unref);
  g_object_set_data_full(object, "raft-system-webview-content",
                         g_object_ref(content), g_object_unref);
  g_object_unref(content);
  g_list_free(children);
  return TRUE;
}
}  // namespace raft_webview_host

inline void RaftInstallWebviewHostBootstrap() {
  const GQuark marker = g_quark_from_static_string("raft-system-webview-host-hook");
  if (g_type_get_qdata(GTK_TYPE_WIDGET, marker)) return;
  gpointer klass = g_type_class_ref(GTK_TYPE_WIDGET);
  const guint signal = g_signal_lookup("parent-set", GTK_TYPE_WIDGET);
  if (signal) {
    const gulong hook = g_signal_add_emission_hook(
        signal, 0, raft_webview_host::ParentSet, nullptr, nullptr);
    if (hook) g_type_set_qdata(GTK_TYPE_WIDGET, marker,
                              GSIZE_TO_POINTER(static_cast<gsize>(hook)));
  }
  g_type_class_unref(klass);
}
#endif
