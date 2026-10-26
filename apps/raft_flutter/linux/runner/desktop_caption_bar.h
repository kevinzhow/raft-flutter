#ifndef RAFT_DESKTOP_CAPTION_BAR_H_
#define RAFT_DESKTOP_CAPTION_BAR_H_

#include <gtk/gtk.h>
#include <string>

#include "desktop_window_actions.h"

// GTK keeps its client-side resize border and shadow, but delegates the 48px
// caption row and controls to Flutter. No desktop-environment name branching.
class DesktopCaptionBar {
 public:
  explicit DesktopCaptionBar(GtkWindow* window) : window_(window), actions_(window) {
    custom_ = g_strcmp0(g_getenv("RAFT_LINUX_HEADER_BAR"), "0") != 0;
    const gchar* layout = g_getenv("RAFT_LINUX_CAPTION_LAYOUT");
    layout_ = layout != nullptr ? layout : ":minimize,maximize,close";
    if (!custom_) return;
    GtkWidget* title = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_style_context_add_class(gtk_widget_get_style_context(title), "raft-caption-spacer");
    g_autoptr(GtkCssProvider) css = gtk_css_provider_new();
    gtk_css_provider_load_from_data(css,
        ".raft-caption-spacer { min-height: 0; min-width: 0; padding: 0;"
        " margin: 0; border: 0; box-shadow: none; background: transparent; }", -1, nullptr);
    gtk_style_context_add_provider(gtk_widget_get_style_context(title),
        GTK_STYLE_PROVIDER(css), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    gtk_widget_show(title);
    gtk_window_set_titlebar(window_, title);
  }

  bool custom() const { return custom_; }
  const std::string& layout() const { return layout_; }
  bool fullscreen() const { return HasState(GDK_WINDOW_STATE_FULLSCREEN); }
  bool maximized() const { return HasState(GDK_WINDOW_STATE_MAXIMIZED); }
  bool active() const { return gtk_window_is_active(window_); }
  void StartDragging() { actions_.StartDragging(); }
  void DoubleClick() { actions_.DoubleClick(); }
  void Minimize() { gtk_window_iconify(window_); }
  void ToggleMaximize() {
    if (fullscreen() || !gtk_window_get_resizable(window_)) return;
    if (maximized()) gtk_window_unmaximize(window_);
    else gtk_window_maximize(window_);
  }
  void Close() { gtk_window_close(window_); }

 private:
  bool HasState(GdkWindowState flag) const {
    GdkWindow* native = gtk_widget_get_window(GTK_WIDGET(window_));
    return native != nullptr && (gdk_window_get_state(native) & flag);
  }
  GtkWindow* window_;
  DesktopWindowActions actions_;
  bool custom_ = true;
  std::string layout_;
};
#endif  // RAFT_DESKTOP_CAPTION_BAR_H_
