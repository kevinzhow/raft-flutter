// Real GObject destruction and real locked GMutex, not a native GTK/engine test.
#include "linux_view_retirement_fixture.h"
#include <condition_variable>
#include <cstdio>
#include <cstring>
#include <thread>
Owned owned_windows;
G_DEFINE_TYPE(FakeWidget, fake_widget, G_TYPE_OBJECT)
static guint destroy_signal;
static bool renderer_finalized = false;
static bool engine_retired = false;
static GThread* ui_thread = nullptr;
static bool renderer_finalized_on_ui = false;
static void destroy_children(FakeWidget* widget) {
  while (widget->children && widget->children->len) {
    auto* child = GTK_WIDGET(g_ptr_array_index(widget->children,0));
    gtk_widget_destroy(child);
    child->owner = nullptr;
    g_ptr_array_remove_index(widget->children,0);
    g_object_unref(child);
  }
}
static void dispose(GObject* object) {
  auto* widget = GTK_WIDGET(object);
  if (!widget->disposed) {
    widget->disposed = true;
    g_clear_object(&widget->engine);  // Actual renderer dispose breaks ownership.
    g_signal_emit(widget,destroy_signal,0);
  }
  G_OBJECT_CLASS(fake_widget_parent_class)->dispose(object);
}
static void finalize(GObject* object) {
  auto* widget = GTK_WIDGET(object);
  if (widget->renderer) {
    // Actual old failure: clear while the in-flight raster owns frame_mutex.
    g_mutex_clear(&widget->frame_mutex);
    renderer_finalized = true;
    renderer_finalized_on_ui = g_thread_self() == ui_thread;
  }
  g_clear_pointer(&widget->children,g_ptr_array_unref);
  G_OBJECT_CLASS(fake_widget_parent_class)->finalize(object);
}
static void fake_widget_class_init(FakeWidgetClass* klass) {
  G_OBJECT_CLASS(klass)->dispose=dispose;G_OBJECT_CLASS(klass)->finalize=finalize;
  klass->destroy=destroy_children;
  destroy_signal=g_signal_new("destroy",G_TYPE_FROM_CLASS(klass),G_SIGNAL_RUN_CLEANUP,
      G_STRUCT_OFFSET(FakeWidgetClass,destroy),nullptr,nullptr,nullptr,G_TYPE_NONE,0);
}
static void fake_widget_init(FakeWidget*) {}
static GtkWidget* widget(bool container=false) {
  auto* w=GTK_WIDGET(g_object_new(fake_widget_get_type(),nullptr));
  if(container)w->children=g_ptr_array_new();
  return w;
}
static void add(GtkWidget* parent,GtkWidget* child) { child->owner=parent;g_ptr_array_add(parent->children,child); }
void gtk_widget_destroy(GtkWidget* w) { g_object_run_dispose(G_OBJECT(w)); }
GObject* fl_view_get_engine(FakeWidget* view) { return view->engine; }
GList* gtk_container_get_children(FakeWidget* w) {
  GList* result=nullptr;
  if(w->children)for(guint i=0;i<w->children->len;++i)result=g_list_append(result,g_ptr_array_index(w->children,i));
  return result;
}
int main(int argc,char** argv) {
  if(argc!=2)return 2;
  ui_thread = g_thread_self();
  auto* view=widget(true);auto* event_box=widget(true);auto* renderer=widget();
  add(view,event_box);add(event_box,renderer);renderer->renderer=true;g_mutex_init(&renderer->frame_mutex);
  auto* engine=G_OBJECT(g_object_new(G_TYPE_OBJECT,nullptr));
  view->engine=G_OBJECT(g_object_ref(engine));renderer->engine=G_OBJECT(g_object_ref(engine));
  g_object_weak_ref(engine,[](gpointer,GObject*){engine_retired=true;std::fputs("FIXTURE_ENGINE_WEAK_RETIRED\n",stderr);},nullptr);
  auto* other=widget(true);auto* other_renderer=widget();add(other,other_renderer);
  other_renderer->engine=G_OBJECT(g_object_new(G_TYPE_OBJECT,nullptr));
  raft_desktop_track_window(view,view);raft_desktop_track_window(view,view); // Registration deduplicates.
  if (std::strcmp(argv[1],"single-window")==0) {
    gtk_widget_destroy(view);
    const bool immediate=renderer_finalized && !engine_retired;
    g_object_unref(engine);
    const bool no_cleanup=g_main_context_pending(nullptr)==FALSE;
    std::printf("READBACK singleWindowImmediate=%d engineRetired=%d noCleanupPending=%d\n",immediate,engine_retired,no_cleanup);
    gtk_widget_destroy(other);g_object_unref(other);g_object_unref(view);
    return immediate&&engine_retired&&no_cleanup?0:1;
  }
  raft_desktop_track_window(other,other); // Second real owned engine enables the narrow lifecycle.
  std::mutex mutex;std::condition_variable condition;bool locked=false,release=false;
  std::thread raster([&]{g_mutex_lock(&renderer->frame_mutex);{std::lock_guard<std::mutex> lock(mutex);locked=true;}condition.notify_one();
    {std::unique_lock<std::mutex> lock(mutex);condition.wait(lock,[&]{return release;});}g_mutex_unlock(&renderer->frame_mutex);});
  {std::unique_lock<std::mutex> lock(mutex);condition.wait(lock,[&]{return locked;});}
  gtk_widget_destroy(view); // Actual production registration now protects descendants.
  const bool before = !renderer_finalized && !engine_retired && !other_renderer->disposed;
  // The renderer's normal dispose MUST already have dropped its engine. An
  // extra durable renderer->engine ref would keep weak retirement unreachable.
  {std::lock_guard<std::mutex> lock(mutex);release=true;}condition.notify_one();raster.join();
  if(std::strcmp(argv[1],"worker-retirement")==0){std::thread stop([&]{g_object_unref(engine);});stop.join();}
  else g_object_unref(engine);
  const bool notified=engine_retired && !renderer_finalized;
  const gint64 deadline=g_get_monotonic_time()+G_USEC_PER_SEC;
  while(!renderer_finalized&&g_get_monotonic_time()<deadline)g_main_context_iteration(nullptr,FALSE);
  const bool success=before && notified && renderer_finalized && renderer_finalized_on_ui && !other_renderer->disposed;
  std::printf("READBACK beforeEngineRetired=%d engineWeakRetired=%d rendererFinalized=%d unrelatedDisposed=%d finalizedOnUi=%d\n",before,engine_retired,renderer_finalized,other_renderer->disposed,renderer_finalized_on_ui);
  gtk_widget_destroy(other);g_object_unref(other);g_object_unref(view);
  return success?0:1;
}
