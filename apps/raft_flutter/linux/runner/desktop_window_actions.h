#ifndef RAFT_DESKTOP_WINDOW_ACTIONS_H_
#define RAFT_DESKTOP_WINDOW_ACTIONS_H_

#include <gtk/gtk.h>

// Capture the initiating GTK event before Flutter consumes it. The method
// channel arrives later on the GTK thread, when gtk_get_current_event is null.
class DesktopWindowActions {
 public:
  explicit DesktopWindowActions(GtkWindow* window) : window_(window) {
    press_ = gtk_gesture_multi_press_new(GTK_WIDGET(window));
    gtk_event_controller_set_propagation_phase(GTK_EVENT_CONTROLLER(press_),
                                               GTK_PHASE_CAPTURE);
    g_signal_connect(press_, "pressed", G_CALLBACK(RecordPress), this);
  }
  ~DesktopWindowActions() {
    g_clear_object(&press_);
    g_clear_pointer(&press_event_, gdk_event_free);
  }

  void StartDragging() {
    if (button_ != GDK_BUTTON_PRIMARY || press_event_ == nullptr) return;
    // The WM consumes the physical release that ends an interactive move.
    // Flutter 3.47 keeps that button pressed forever unless its view receives
    // an Up first. End only this background gesture before handing it to the
    // WM; the physical button is still down, so native moving works normally.
    g_autoptr(GdkEvent) release = gdk_event_copy(press_event_);
    release->type = GDK_BUTTON_RELEASE;
    release->button.send_event = TRUE;
    release->button.state |= GDK_BUTTON1_MASK;
    gtk_main_do_event(release);
    gtk_window_begin_move_drag(window_, button_, root_x_, root_y_, time_);
  }

  void DoubleClick() {
    GdkWindow* native = gtk_widget_get_window(GTK_WIDGET(window_));
    if (native != nullptr &&
        (gdk_window_get_state(native) & GDK_WINDOW_STATE_FULLSCREEN)) return;
    g_autofree gchar* action = nullptr;
    g_object_get(gtk_widget_get_settings(GTK_WIDGET(window_)),
                 "gtk-titlebar-double-click", &action, nullptr);
    if (g_strcmp0(action, "toggle-maximize") == 0) {
      if (gtk_window_is_maximized(window_)) gtk_window_unmaximize(window_);
      else gtk_window_maximize(window_);
    } else if (g_strcmp0(action, "minimize") == 0) {
      gtk_window_iconify(window_);
    } else if (g_strcmp0(action, "lower") == 0 && native != nullptr) {
      gdk_window_lower(native);
    }
  }

 private:
  static void RecordPress(GtkGestureMultiPress*, gint, gdouble, gdouble,
                          gpointer data) {
    auto* self = static_cast<DesktopWindowActions*>(data);
    g_autoptr(GdkEvent) event = gtk_get_current_event();
    if (event == nullptr) return;
    guint button = 0;
    gdouble x = 0, y = 0;
    if (!gdk_event_get_button(event, &button) ||
        !gdk_event_get_root_coords(event, &x, &y)) return;
    g_clear_pointer(&self->press_event_, gdk_event_free);
    self->press_event_ = gdk_event_copy(event);
    self->button_ = button;
    self->root_x_ = static_cast<gint>(x);
    self->root_y_ = static_cast<gint>(y);
    self->time_ = gdk_event_get_time(event);
  }
  GtkWindow* window_;
  GtkGesture* press_ = nullptr;
  GdkEvent* press_event_ = nullptr;
  guint button_ = 0;
  gint root_x_ = 0, root_y_ = 0;
  guint32 time_ = GDK_CURRENT_TIME;
};
#endif  // RAFT_DESKTOP_WINDOW_ACTIONS_H_
