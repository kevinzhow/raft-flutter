// GTK overlay/input routing adapted from webview_all_linux ab32ceb7f0bb0585432986908875c0a5fe0df9a6.
// Copyright 2021-2026 Abandoft. See ../LICENSE.upstream and upstream.json.
#include "native_host.h"
#include "host_bootstrap.h"
#include <algorithm>

namespace {
constexpr const char* kOverlay = "raft-system-webview-overlay";
constexpr const char* kContent = "raft-system-webview-content";
constexpr const char* kClip = "raft-system-webview-clip";

// Kept for ordinary developer runners that eagerly link this plugin. The
// optional Linux runner installs the same idempotent hook before any FlView.
__attribute__((constructor)) void InstallOverlayHook() {
  RaftInstallWebviewHostBootstrap();
}
GtkWidget* InputWidget(GtkWidget* widget) {
  if (!widget || GTK_IS_EVENT_BOX(widget)) return widget;
  if (!GTK_IS_CONTAINER(widget)) return nullptr;
  GList* children = gtk_container_get_children(GTK_CONTAINER(widget));
  GtkWidget* result = nullptr;
  for (GList* item = children; item && !result; item = item->next)
    result = InputWidget(GTK_WIDGET(item->data));
  g_list_free(children);
  return result;
}
}

NativeHost::NativeHost(FlView* view) : view_(GTK_WIDGET(view)) {
  overlay_ = GTK_OVERLAY(g_object_get_data(G_OBJECT(view), kOverlay));
  GtkWidget* content = GTK_WIDGET(g_object_get_data(G_OBJECT(view), kContent));
  if (!overlay_) {
    GtkWidget* parent = gtk_widget_get_parent(view_);
    if (GTK_IS_OVERLAY(parent)) overlay_ = GTK_OVERLAY(parent);
  }
  if (!overlay_) { view_ = nullptr; return; }
  input_ = InputWidget(content ? content : view_);
  // Without the specific Flutter input widget, do not shape another window.
  if (!input_) { overlay_ = nullptr; view_ = nullptr; return; }
  g_object_add_weak_pointer(G_OBJECT(view_), reinterpret_cast<gpointer*>(&view_));
  g_object_add_weak_pointer(G_OBJECT(overlay_), reinterpret_cast<gpointer*>(&overlay_));
  g_object_add_weak_pointer(G_OBJECT(input_), reinterpret_cast<gpointer*>(&input_));
  g_signal_connect(overlay_, "get-child-position", G_CALLBACK(Position), this);
  g_signal_connect(input_, "size-allocate", G_CALLBACK(Allocated), this);
  // Observe the actual Flutter-side input before its specific handler can
  // consume it. Native widgets are siblings of this input subtree, so their
  // own real clicks retain GTK's normal WebKit focus handling.
  input_event_signal_ = g_signal_lookup("event", GTK_TYPE_WIDGET);
  if (input_event_signal_) input_event_hook_ = g_signal_add_emission_hook(
    input_event_signal_, 0, FlutterInput, this, nullptr);
}
NativeHost::~NativeHost() {
  if (input_event_hook_) g_signal_remove_emission_hook(input_event_signal_, input_event_hook_);
  rectangles_.clear();
  UpdateInput();
  if (overlay_) {
    g_signal_handlers_disconnect_by_data(overlay_, this);
    g_object_remove_weak_pointer(G_OBJECT(overlay_), reinterpret_cast<gpointer*>(&overlay_));
  }
  if (input_) {
    g_signal_handlers_disconnect_by_data(input_, this);
    g_object_remove_weak_pointer(G_OBJECT(input_), reinterpret_cast<gpointer*>(&input_));
  }
  if (view_) g_object_remove_weak_pointer(G_OBJECT(view_), reinterpret_cast<gpointer*>(&view_));
}
gboolean NativeHost::Position(GtkOverlay*, GtkWidget* child, GdkRectangle* output, gpointer) {
  auto* clip = static_cast<GdkRectangle*>(g_object_get_data(G_OBJECT(child), kClip));
  if (!clip) return FALSE;
  *output = *clip;
  return TRUE;
}
void NativeHost::Allocated(GtkWidget*, GdkRectangle*, gpointer data) {
  static_cast<NativeHost*>(data)->UpdateInput();
}
bool NativeHost::Attach(int64_t, GtkWidget* widget) {
  if (!overlay_ || !input_) return false;
  gtk_widget_set_halign(widget, GTK_ALIGN_START);
  gtk_widget_set_valign(widget, GTK_ALIGN_START);
  gtk_widget_set_no_show_all(widget, TRUE);
  gtk_overlay_add_overlay(overlay_, widget);
  return true;
}
void NativeHost::Layout(int64_t id, GtkWidget* widget, const GdkRectangle& clip, bool visible) {
  if (!overlay_) return;
  if (visible) {
    auto* copy = g_new(GdkRectangle, 1); *copy = clip;
    g_object_set_data_full(G_OBJECT(widget), kClip, copy, g_free);
    gtk_widget_set_size_request(widget, clip.width, clip.height);
    gtk_widget_show(widget);
    rectangles_[id] = clip;
  } else {
    gtk_widget_hide(widget);
    rectangles_.erase(id);
  }
  gtk_widget_queue_resize(GTK_WIDGET(overlay_));
  UpdateInput();
}
void NativeHost::Detach(int64_t id, GtkWidget* widget) {
  rectangles_.erase(id);
  if (widget) gtk_widget_hide(widget);
  UpdateInput();
}
void NativeHost::UpdateInput() {
  if (!input_ || !gtk_widget_get_realized(input_) || !gtk_widget_get_has_window(input_)) return;
  GdkRectangle bounds = {0, 0, gtk_widget_get_allocated_width(input_), gtk_widget_get_allocated_height(input_)};
  cairo_region_t* region = cairo_region_create_rectangle(&bounds);
  for (const auto& pair : rectangles_) {
    GdkRectangle clipped;
    if (gdk_rectangle_intersect(&bounds, &pair.second, &clipped))
      cairo_region_subtract_rectangle(region, &clipped);
  }
  gtk_widget_input_shape_combine_region(input_, rectangles_.empty() ? nullptr : region);
  cairo_region_destroy(region);
}

gboolean NativeHost::FlutterInput(GSignalInvocationHint*, guint count, const GValue* args, gpointer data) {
  auto* self = static_cast<NativeHost*>(data);
  if (count < 2 || !self->view_ || !self->input_) return TRUE;
  auto* widget = GTK_WIDGET(g_value_get_object(&args[0]));
  if (widget != self->input_ && !gtk_widget_is_ancestor(widget, self->input_)) return TRUE;
  auto* event = static_cast<GdkEvent*>(g_value_get_boxed(&args[1]));
  if (event && (event->type == GDK_BUTTON_PRESS || event->type == GDK_TOUCH_BEGIN) &&
      gtk_widget_get_can_focus(self->view_)) gtk_widget_grab_focus(self->view_);
  // TRUE retains this observation hook; it cannot consume the GTK event.
  return TRUE;
}
FlValue* NativeHost::FocusState() const {
  auto* result = fl_value_new_map();
  fl_value_set_string_take(result, "flutterCanFocus", fl_value_new_bool(view_ && gtk_widget_get_can_focus(view_)));
  fl_value_set_string_take(result, "flutterHasFocus", fl_value_new_bool(view_ && gtk_widget_has_focus(view_)));
  GtkWidget* top = view_ ? gtk_widget_get_toplevel(view_) : nullptr;
  if (top && GTK_IS_WINDOW(top)) {
    auto* focus = gtk_window_get_focus(GTK_WINDOW(top));
    fl_value_set_string_take(result, "toplevelActive", fl_value_new_bool(gtk_window_is_active(GTK_WINDOW(top))));
    fl_value_set_string_take(result, "toplevelHasFocus", fl_value_new_bool(gtk_window_has_toplevel_focus(GTK_WINDOW(top))));
    fl_value_set_string_take(result, "focusWidgetType", fl_value_new_string(focus ? G_OBJECT_TYPE_NAME(focus) : "none"));
  }
  return result;
}
