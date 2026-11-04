// Real GObject/GTask/GMainContext ownership model; no GTK/display/account.
#include "desktop_quit_cleanup.h"
#include <cassert>
#include <cstdio>
#include <cstring>

struct OwnedNode { GObject parent; GObject* child; bool task_on_dispose; };
struct OwnedNodeClass { GObjectClass parent; };
G_DEFINE_TYPE(OwnedNode, owned_node, G_TYPE_OBJECT)
static void owned_node_dispose(GObject* object) {
  auto* node = reinterpret_cast<OwnedNode*>(object);
  g_object_set_data(object, "fixture-disposed", GINT_TO_POINTER(1));
  if (node->child && node->task_on_dispose) {
    node->task_on_dispose = false;
    GTask* task = g_task_new(node->child, nullptr, nullptr, nullptr);
    g_task_return_new_error(task, g_quark_from_static_string("quit-fixture"), 1,
                             "queued ownership completion");
    g_object_unref(task);
  }
  g_clear_object(&node->child);
  G_OBJECT_CLASS(owned_node_parent_class)->dispose(object);
}
static void owned_node_class_init(OwnedNodeClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = owned_node_dispose;
}
static void owned_node_init(OwnedNode*) {}
static GObject* node(GObject* child, bool task) {
  auto* result = reinterpret_cast<OwnedNode*>(g_object_new(owned_node_get_type(), nullptr));
  result->child = child ? G_OBJECT(g_object_ref(child)) : nullptr;
  result->task_on_dispose = task;
  return G_OBJECT(result);
}

static DesktopQuitCleanup cleanup(g_object_run_dispose);
static GMainContext* context;
static GObject* top;
static GObject* held;
static GObject* unowned;
static bool app_alive = true;
static bool queued_create_rejected = false;
static bool ran = false;
static unsigned terminates = 0;

GApplication* my_application_new() {
  context = g_main_context_new();
  g_main_context_push_thread_default(context);
  GObject* engine = G_OBJECT(g_object_new(G_TYPE_OBJECT, nullptr));
  GObject* view = node(engine, true);
  top = node(view, false);  // GTK-like user reference survives application detach.
  unowned = node(nullptr, false);  // Not one of this application's windows.
  cleanup.Register(top, view, engine);
  cleanup.Register(top, view, engine);
  assert(cleanup.registered() == 1);  // Registration never adds another owner.
  if (g_strcmp0(g_getenv("RAFT_QUIT_SCENARIO"), "held") == 0) {
    held = G_OBJECT(g_object_ref(engine));
  }
  g_object_unref(view); g_object_unref(engine);
  auto* app = g_application_new("org.raft.QuitPolicy", G_APPLICATION_NON_UNIQUE);
  g_object_weak_ref(G_OBJECT(app), [](gpointer, GObject*) { app_alive = false; }, nullptr);
  return app;
}
int raft_test_application_run(GApplication*, int, char**) {
  assert(cleanup.accepting());
  // The application has returned from an accepted global quit. An already
  // queued create checks admission when dispatched, not when enqueued.
  GSource* source = g_idle_source_new();
  g_source_set_callback(source, [](gpointer) -> gboolean {
    queued_create_rejected = !cleanup.accepting();
    return G_SOURCE_REMOVE;
  }, nullptr, nullptr);
  g_source_attach(source, context); g_source_unref(source);
  ran = true;
  return 0;
}
bool raft_desktop_finish_quit() {
  assert(ran && app_alive);
  const auto result = cleanup.FinishAfterApplicationRun(
      context, held ? 2000 : 100000,
      [] { return queued_create_rejected; },
      [](const char*, unsigned, const DesktopQuitCleanup::Counts&) {
        assert(app_alive);  // Callback owner must outlive the entire cleanup.
      });
  assert(!cleanup.accepting());
  assert(!g_object_get_data(unowned, "fixture-disposed"));
  if (held) {
    assert(!result.complete && result.timed_out && result.live.engines == 1);
    std::puts("PASS bounded held-engine failure retains actual live ownership");
  } else {
    assert(result.complete && result.iterations > 0 && queued_create_rejected);
    assert(result.live.windows == 0 && result.live.views == 0 && result.live.engines == 0);
    std::puts("PASS detached owned window disposed; GTask drained; late create rejected");
  }
  return result.complete;
}
bool raft_shared_egl_release() {
  assert(!app_alive);
  const auto live = cleanup.Live();
  const bool done = !live.windows && !live.views && !live.engines;
  if (done) ++terminates;
  std::printf("READBACK windows=%zu views=%zu engines=%zu terminate=%u\n",
              live.windows, live.views, live.engines, terminates);
  // Test cleanup happens after the oracle, never used to manufacture success.
  g_clear_object(&held); g_clear_object(&top); g_clear_object(&unowned);
  while (g_main_context_pending(context)) g_main_context_iteration(context, FALSE);
  g_main_context_pop_thread_default(context); g_main_context_unref(context);
  return done;
}
