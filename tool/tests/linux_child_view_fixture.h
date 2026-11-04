#ifndef RAFT_CHILD_VIEW_FIXTURE_H_
#define RAFT_CHILD_VIEW_FIXTURE_H_
#include <gio/gio.h>
#include <string>

struct FakeWidget { GObject parent; FakeWidget* child; FakeWidget* owner; GObject* engine; bool is_view; bool disposed; };
struct FakeWidgetClass { GObjectClass parent; void (*destroy)(FakeWidget*); };
using GtkWidget = FakeWidget;
using GtkWindow = FakeWidget;
using FlView = FakeWidget;
using FlPluginRegistry = FakeWidget;
#define GTK_WIDGET(x) (reinterpret_cast<GtkWidget*>(x))
#define GTK_WINDOW(x) (reinterpret_cast<GtkWindow*>(x))
#define GTK_BIN(x) GTK_WIDGET(x)
#define GTK_CONTAINER(x) GTK_WIDGET(x)
#define FL_VIEW(x) GTK_WIDGET(x)
#define FL_IS_VIEW(x) (GTK_WIDGET(x)->is_view)
class DesktopCaptionBar { public: explicit DesktopCaptionBar(GtkWindow*) {} };
struct TitleBar { GtkWindow* window; DesktopCaptionBar* caption; };
void fl_register_plugins(FlPluginRegistry*);
GtkWidget* gtk_widget_get_toplevel(GtkWidget*);
void gtk_window_set_title(GtkWindow*, const char*);
void register_window_channels(FlView*, GtkWindow*, TitleBar*, bool);
void raft_desktop_destroy_child_view_after_close(FlView*, GtkWindow*);
void gtk_widget_destroy(GtkWidget*);
GtkWidget* gtk_bin_get_child(GtkWidget*);
void gtk_container_remove(GtkWidget*, GtkWidget*);
GObject* fl_view_get_engine(FlView*);
void register_child_window(FlPluginRegistry*);
class MultiWindowManager {
 public:
  static MultiWindowManager* Instance();
  void ObserveWindowClose(const std::string&, GtkWindow*);
  void RemoveWindow(const std::string&);
  unsigned removed = 0;
};
#endif
