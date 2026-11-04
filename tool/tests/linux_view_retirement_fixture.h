#include <gio/gio.h>
#include <vector>
#include <mutex>
#include <memory>
struct FakeWidget { GObject parent; FakeWidget* owner; GPtrArray* children; GObject* engine; bool disposed; bool renderer; GMutex frame_mutex; };
struct FakeWidgetClass { GObjectClass parent; void (*destroy)(FakeWidget*); };
GType fake_widget_get_type();
using GtkWidget = FakeWidget;
using GtkWindow = FakeWidget;
using FlView = FakeWidget;
using FlEngine = GObject;
#define GTK_WIDGET(o) (reinterpret_cast<FakeWidget*>(o))
#define GTK_CONTAINER(o) GTK_WIDGET(o)
#define GTK_IS_CONTAINER(o) (GTK_WIDGET(o)->children != nullptr)
GList* gtk_container_get_children(FakeWidget* widget);
GObject* fl_view_get_engine(FakeWidget* view);
void gtk_widget_destroy(FakeWidget* widget);
void raft_desktop_retire_view_children_after_engine(FlView* view);
void raft_desktop_track_window(FlView* view, GtkWindow* window);
struct Owned { void Register(GObject*,GObject*,GObject*) {} };
extern Owned owned_windows;
