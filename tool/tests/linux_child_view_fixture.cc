// Real GObject signals/refcounts; GTK operations model the pinned public
// destruction/unparent semantics. This does not start GTK or a Flutter engine.
#include "linux_child_view_fixture.h"
#include <cstdio>
#include <cstring>

G_DEFINE_TYPE(FakeWidget, fake_widget, G_TYPE_OBJECT)
static guint destroy_signal;
static void fake_widget_dispose(GObject* object) {
  auto* widget = GTK_WIDGET(object);
  if (!widget->disposed) {
    widget->disposed = true;
    if (widget->owner) gtk_container_remove(widget->owner, widget);
    g_signal_emit(widget, destroy_signal, 0);
    g_clear_object(&widget->engine);
  }
  G_OBJECT_CLASS(fake_widget_parent_class)->dispose(object);
}
static void destroy_children(FakeWidget* widget) {
  if (widget->child) gtk_widget_destroy(widget->child);
}
static void fake_widget_class_init(FakeWidgetClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = fake_widget_dispose;
  klass->destroy = destroy_children;
  destroy_signal = g_signal_new("destroy", G_TYPE_FROM_CLASS(klass),
      G_SIGNAL_RUN_CLEANUP, G_STRUCT_OFFSET(FakeWidgetClass, destroy),
      nullptr, nullptr, nullptr, G_TYPE_NONE, 0);
}
static void fake_widget_init(FakeWidget*) {}
void gtk_widget_destroy(GtkWidget* widget) { g_object_run_dispose(G_OBJECT(widget)); }
GtkWidget* gtk_bin_get_child(GtkWidget* widget) { return widget->child; }
void gtk_container_remove(GtkWidget* parent, GtkWidget* child) {
  if (parent->child != child) return;
  parent->child = nullptr; child->owner = nullptr; g_object_unref(child);
}
GObject* fl_view_get_engine(FlView* view) { return view->engine; }
void fl_register_plugins(FlPluginRegistry*) {}
GtkWidget* gtk_widget_get_toplevel(GtkWidget* view) { return view->owner; }
void gtk_window_set_title(GtkWindow*, const char*) {}
void register_window_channels(FlView*, GtkWindow* window, TitleBar* title, bool) {
  g_object_set_data_full(G_OBJECT(window), "fixture-title", title, [](gpointer p) {
    auto* title = static_cast<TitleBar*>(p); delete title->caption; g_free(title);
  });
}
MultiWindowManager* MultiWindowManager::Instance() { static MultiWindowManager result; return &result; }
void MultiWindowManager::RemoveWindow(const std::string&) { ++removed; }

struct Case {
  GtkWidget *window, *view, *raster;
  bool* engine_gone;
};
static Case create_case(bool* gone, bool retain) {
  auto* window = GTK_WIDGET(g_object_new(fake_widget_get_type(), nullptr));
  auto* view = GTK_WIDGET(g_object_new(fake_widget_get_type(), nullptr));
  view->is_view = true;
  view->engine = G_OBJECT(g_object_new(G_TYPE_OBJECT, nullptr));
  g_object_weak_ref(view->engine, [](gpointer data, GObject*) { *static_cast<bool*>(data) = true; }, gone);
  window->child = view; view->owner = window;
  GtkWidget* raster = retain ? GTK_WIDGET(g_object_ref(view)) : nullptr;
  return {window, view, raster, gone};
}
int main(int argc, char** argv) {
  if (argc != 2) return 2;
  const bool retain = std::strcmp(argv[1], "already-released") != 0;
  bool own_gone = false, other_gone = false;
  auto own = create_case(&own_gone, retain);
  auto other = create_case(&other_gone, true);
  register_child_window(own.view);  // Real old/new production entry.
  MultiWindowManager::Instance()->ObserveWindowClose("child", own.window);
  if (own_gone || other_gone) return 3;
  gtk_widget_destroy(own.window);  // Real pinned plugin destroy callback runs.
  const bool success = own_gone && !other_gone && !other.view->disposed &&
      MultiWindowManager::Instance()->removed == 1;
  std::printf("READBACK ownedEngineGone=%d unrelatedEngineGone=%d retainedRasterView=%d pluginRemoved=%u\n",
      own_gone, other_gone, retain, MultiWindowManager::Instance()->removed);
  // Oracle precedes cleanup; never use the cleanup to manufacture success.
  if (own.raster) { gtk_widget_destroy(own.raster); g_object_unref(own.raster); }
  gtk_widget_destroy(other.window);
  gtk_widget_destroy(other.raster); g_object_unref(other.raster);
  g_object_unref(own.window); g_object_unref(other.window);
  return success ? 0 : 1;
}
