#include "include/desktop_drop/desktop_drop_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <stdlib.h>
#include <string.h>
#include <sys/utsname.h>

#define DESKTOP_DROP_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), desktop_drop_plugin_get_type(), \
                              DesktopDropPlugin))

struct _DesktopDropPlugin {
  GObject parent_instance;
};

static gboolean isKDE = FALSE;
static gboolean ignoreNext = FALSE;

G_DEFINE_TYPE(DesktopDropPlugin, desktop_drop_plugin, g_object_get_type())

// RAFT PATCH: GTK asks the drag source for exactly one target when
// GTK_DEST_DEFAULT_DROP is set, and picks it in the *source's* offer order.
// A source that lists application/vnd.portal.filetransfer first (KDE/Dolphin,
// Flatpak sources) therefore never delivers text/uri-list, and when the portal
// key is dead (RetrieveFiles: AccessDenied "Invalid transfer") nothing is left
// to fall back on. We take over the drop instead and read every useful target
// of the same drag, one after another, before finishing it.
static const char *kUriTarget = "text/uri-list";
static const char *kPortalTarget = "application/vnd.portal.filetransfer";
static const char *kTextTarget = "STRING";

struct DropState {
  GdkDragContext *context = nullptr;
  guint time = 0;
  gdouble x = 0, y = 0;
  int stage = 0;  // index of the target being fetched, see kStages
  gchar *uris = nullptr;
  gchar *portal = nullptr;
  gchar *text = nullptr;
};
static DropState drop_state;

static const char *const kStages[] = {kUriTarget, kPortalTarget, kTextTarget};

static gboolean source_offers(GdkDragContext *context, const char *name) {
  for (GList *l = gdk_drag_context_list_targets(context); l != nullptr;
       l = l->next) {
    g_autofree gchar *atom_name = gdk_atom_name(GDK_POINTER_TO_ATOM(l->data));
    if (atom_name != nullptr && strcmp(atom_name, name) == 0) return TRUE;
  }
  return FALSE;
}

static void drop_reset() {
  if (drop_state.context != nullptr) g_object_unref(drop_state.context);
  g_free(drop_state.uris);
  g_free(drop_state.portal);
  g_free(drop_state.text);
  drop_state = DropState();
}

static gchar *take_payload(GtkSelectionData *sdata) {
  gint length = gtk_selection_data_get_length(sdata);
  if (length <= 0) return nullptr;
  // Selection data is not guaranteed to be NUL-terminated.
  return g_strndup(
      reinterpret_cast<const gchar *>(gtk_selection_data_get_data(sdata)),
      length);
}

// Requests the next target the source offers, or finishes the drop.
static void drop_advance(GtkWidget *widget, FlMethodChannel *channel) {
  while (drop_state.stage < 3) {
    const char *name = kStages[drop_state.stage];
    // Plain text only matters when no file target produced anything.
    bool skip = drop_state.stage == 2 &&
                (drop_state.uris != nullptr || drop_state.portal != nullptr);
    if (!skip && source_offers(drop_state.context, name)) {
      gtk_drag_get_data(widget, drop_state.context,
                        gdk_atom_intern(name, FALSE), drop_state.time);
      return;
    }
    drop_state.stage++;
  }

  double point[] = {drop_state.x, drop_state.y};
  g_autoptr(FlValue) args = fl_value_new_list();
  const char *method_name;
  if (drop_state.uris != nullptr || drop_state.portal != nullptr) {
    // [uri-list text, portal key, point]: Dart picks the source (RAFT PATCH).
    method_name = "performOperation_linux_sources";
    fl_value_append(args, fl_value_new_string(drop_state.uris ? drop_state.uris : ""));
    fl_value_append(args, fl_value_new_string(drop_state.portal ? drop_state.portal : ""));
  } else {
    method_name = "performOperation_linux";
    fl_value_append(args, fl_value_new_string(drop_state.text ? drop_state.text : ""));
  }
  fl_value_append(args, fl_value_new_float_list(point, 2));
  gboolean success = drop_state.uris != nullptr || drop_state.portal != nullptr ||
                     drop_state.text != nullptr;
  gtk_drag_finish(drop_state.context, success, FALSE, drop_state.time);
  fl_method_channel_invoke_method(channel, method_name, args,
                                  nullptr, nullptr, nullptr);
  drop_reset();
}

gboolean on_drag_drop(GtkWidget *widget, GdkDragContext *drag_context,
                      gint x, gint y, guint time, gpointer user_data) {
  bool offered = false;
  for (const char *name : kStages) {
    offered = offered || source_offers(drag_context, name);
  }
  if (!offered) return FALSE;  // Nothing we understand: let GTK reject it.
  drop_reset();
  drop_state.context = GDK_DRAG_CONTEXT(g_object_ref(drag_context));
  drop_state.time = time;
  drop_state.x = x;
  drop_state.y = y;
  drop_advance(widget, static_cast<FlMethodChannel *>(user_data));
  return TRUE;
}

void on_drag_data_received(GtkWidget *widget, GdkDragContext *drag_context,
                           gint x, gint y, GtkSelectionData *sdata, guint info,
                           guint time, gpointer user_data) {
  // Only data we asked for from on_drag_drop is of interest.
  if (drop_state.context != drag_context || drop_state.stage >= 3) return;
  gchar *payload = take_payload(sdata);
  switch (drop_state.stage) {
    case 0: g_free(drop_state.uris); drop_state.uris = payload; break;
    case 1: g_free(drop_state.portal); drop_state.portal = payload; break;
    default: g_free(drop_state.text); drop_state.text = payload; break;
  }
  drop_state.stage++;
  drop_advance(widget, static_cast<FlMethodChannel *>(user_data));
}

gboolean on_drag_motion(GtkWidget *widget, GdkDragContext *drag_context,
                        gint x, gint y, guint time, gpointer user_data) {
  if (ignoreNext) {
    ignoreNext = FALSE;
    return FALSE;
  }

  auto *channel = static_cast<FlMethodChannel *>(user_data);
  double point[] = {double(x), double(y)};
  g_autoptr(FlValue) args = fl_value_new_float_list(point, 2);
  fl_method_channel_invoke_method(channel, "updated", args,
                                  nullptr, nullptr, nullptr);
  // FALSE: GTK_DEST_DEFAULT_MOTION answers the drag status.
  return FALSE;
}

void on_drag_leave(GtkWidget *widget, GdkDragContext *drag_context, guint time, gpointer user_data) {
  auto *channel = static_cast<FlMethodChannel *>(user_data);
  fl_method_channel_invoke_method(channel, "exited", nullptr,
                                  nullptr, nullptr, nullptr);
}

// Called when a method call is received from Flutter.
static void desktop_drop_plugin_handle_method_call(
    DesktopDropPlugin *self,
    FlMethodCall *method_call) {
  fl_method_call_respond_not_implemented(method_call, nullptr);
}

static void desktop_drop_plugin_dispose(GObject *object) {
  G_OBJECT_CLASS(desktop_drop_plugin_parent_class)->dispose(object);
}

static void desktop_drop_plugin_class_init(DesktopDropPluginClass *klass) {
  G_OBJECT_CLASS(klass)->dispose = desktop_drop_plugin_dispose;
}

static void desktop_drop_plugin_init(DesktopDropPlugin *self) {
  const char * desktopEnv = getenv("XDG_CURRENT_DESKTOP");
  if (desktopEnv) {
    const char * lowercaseDesktopEnv = g_ascii_strdown(desktopEnv, -1);

    if (strcmp(lowercaseDesktopEnv, "kde") == 0 || strcmp(lowercaseDesktopEnv, "plasma") == 0) {
        isKDE = TRUE;
    }
  }
}

static gboolean on_focus_in_event(GtkWidget *widget, GdkEventFocus *event, gpointer user_data) {
  if (isKDE) {
    ignoreNext = TRUE;
  }
  return FALSE;
}

static void method_call_cb(FlMethodChannel *channel, FlMethodCall *method_call,
                           gpointer user_data) {
  DesktopDropPlugin *plugin = DESKTOP_DROP_PLUGIN(user_data);
  desktop_drop_plugin_handle_method_call(plugin, method_call);
}

void desktop_drop_plugin_register_with_registrar(FlPluginRegistrar *registrar) {
  DesktopDropPlugin *plugin = DESKTOP_DROP_PLUGIN(
      g_object_new(desktop_drop_plugin_get_type(), nullptr));

  auto *fl_view = fl_plugin_registrar_get_view(registrar);
  // Register portal file transfer target FIRST (highest priority)
  // then STRING, then URI targets
  static GtkTargetEntry entries[] = {
      {strdup("application/vnd.portal.filetransfer"), GTK_TARGET_OTHER_APP, 0},
      {strdup("STRING"), GTK_TARGET_OTHER_APP, 0}
  };
  // No GTK_DEST_DEFAULT_DROP: on_drag_drop reads the targets itself.
  gtk_drag_dest_set(GTK_WIDGET(fl_view),
                    GtkDestDefaults(GTK_DEST_DEFAULT_MOTION | GTK_DEST_DEFAULT_HIGHLIGHT),
                    entries, 2, GDK_ACTION_COPY);
  gtk_drag_dest_add_uri_targets(GTK_WIDGET(fl_view));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel *channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "desktop_drop",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_signal_connect(fl_view, "drag-motion",
                   G_CALLBACK(on_drag_motion), channel);
  g_signal_connect(fl_view, "drag-drop",
                   G_CALLBACK(on_drag_drop), channel);
  g_signal_connect(GTK_WIDGET(fl_view), "drag-data-received",
                   G_CALLBACK(on_drag_data_received), channel);
  g_signal_connect(GTK_WIDGET(fl_view), "drag-leave",
                   G_CALLBACK(on_drag_leave), channel);
  g_signal_connect(fl_view, "focus-in-event",
                   G_CALLBACK(on_focus_in_event), nullptr);

  g_object_unref(plugin);
}
