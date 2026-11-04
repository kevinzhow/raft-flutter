#include "desktop_view_retirement.h"

#include <memory>
#include <mutex>
#include <vector>
#ifdef RAFT_MULTIWINDOW_QA
#include <atomic>
#include <cstdio>
#endif

namespace {
struct Retirement {
  Retirement() : context(g_main_context_ref(g_main_context_default())) {}
  ~Retirement() { g_main_context_unref(context); }
  GMainContext* context;
  bool (*enabled)() = nullptr;
  std::mutex mutex;
  std::vector<GObject*> children;
  bool view_destroyed = false;
  bool engine_retired = false;
  bool release_queued = false;
#ifdef RAFT_MULTIWINDOW_QA
  guintptr engine_id = 0;
#endif
};
using RetirementRef = std::shared_ptr<Retirement>;
#ifdef RAFT_MULTIWINDOW_QA
std::atomic<size_t> observed_children_live{0};
struct ChildObservation { guintptr engine; guintptr object; };
#endif

void collect_children(GtkWidget* widget, std::vector<GObject*>& retained) {
  if (!GTK_IS_CONTAINER(widget)) return;
  GList* children = gtk_container_get_children(GTK_CONTAINER(widget));
  for (GList* item = children; item; item = item->next) {
    auto* child = GTK_WIDGET(item->data);
    retained.push_back(G_OBJECT(g_object_ref(child)));
    collect_children(child, retained);
  }
  g_list_free(children);
}

void queue_release(const RetirementRef& state) {
  {
    std::lock_guard<std::mutex> lock(state->mutex);
    if (!state->view_destroyed || !state->engine_retired || state->release_queued) return;
    state->release_queued = true;
  }
  // A single finite cleanup source, never a retry/poll loop. Always defer to
  // the GTK context, including when the engine's weak notify ran on GTK: its
  // destructor and the current destroy signal must return before finalizing
  // the disposed descendants. Global quit's bounded drain also services it.
  GSource* source = g_idle_source_new();
  g_source_set_callback(source, [](gpointer data) -> gboolean {
    const auto& state = *static_cast<RetirementRef*>(data);
    std::vector<GObject*> children;
    {
      std::lock_guard<std::mutex> lock(state->mutex);
      children.swap(state->children);
    }
    for (auto item = children.rbegin(); item != children.rend(); ++item) {
      g_object_unref(*item);
    }
#ifdef RAFT_MULTIWINDOW_QA
    std::fprintf(stderr, "RAFT_EGL_LIFETIME event=view_children_released engine=0x%zx children=%zu live=%zu\n",
                 state->engine_id, children.size(),
                 observed_children_live.load(std::memory_order_relaxed));
#endif
    return G_SOURCE_REMOVE;
  }, new RetirementRef(state), [](gpointer data) {
    delete static_cast<RetirementRef*>(data);
  });
  g_source_attach(source, state->context);
  g_source_unref(source);
}
}  // namespace

void raft_desktop_retire_view_children_after_engine(FlView* view, bool (*enabled)()) {
  if (g_object_get_data(G_OBJECT(view), "raft-view-retirement")) return;
  FlEngine* engine = fl_view_get_engine(view);
  if (!engine) return;
  g_object_set_data(G_OBJECT(view), "raft-view-retirement", GINT_TO_POINTER(1));
  auto state = std::make_shared<Retirement>();
  state->enabled = enabled;
#ifdef RAFT_MULTIWINDOW_QA
  state->engine_id = reinterpret_cast<guintptr>(engine);
#endif
  // This notification owns the small retirement state, never the engine.
  // GTK's normal child dispose clears FlViewRenderer's engine reference even
  // while our extra widget reference delays finalize. No ownership cycle.
  g_object_weak_ref(G_OBJECT(engine), [](gpointer data, GObject*) {
    auto state = *static_cast<RetirementRef*>(data);
    delete static_cast<RetirementRef*>(data);
    {
      std::lock_guard<std::mutex> lock(state->mutex);
      state->engine_retired = true;
    }
    queue_release(state);
  }, new RetirementRef(state));
  g_signal_connect_data(view, "destroy", G_CALLBACK(+[](GtkWidget* widget, gpointer data) {
    const auto& state = *static_cast<RetirementRef*>(data);
    if (!state->enabled()) return;
    {
      std::lock_guard<std::mutex> lock(state->mutex);
      if (state->view_destroyed) return;
    }
    std::vector<GObject*> children;
    collect_children(widget, children);
#ifdef RAFT_MULTIWINDOW_QA
    observed_children_live.fetch_add(children.size(), std::memory_order_relaxed);
    for (auto* child : children) {
      // GtkWidget weak notifications can run during dispose despite an extra
      // strong reference. This private qdata destructor runs at finalization,
      // after the class's finalize has released the compositor/resources.
      g_object_set_qdata_full(child, g_quark_from_static_string("raft-view-finalization-qa"),
          new ChildObservation{state->engine_id, reinterpret_cast<guintptr>(child)},
          [](gpointer data) {
            auto* observation = static_cast<ChildObservation*>(data);
            const auto live = observed_children_live.fetch_sub(1, std::memory_order_relaxed) - 1;
            std::fprintf(stderr, "RAFT_EGL_LIFETIME event=view_child_finalized engine=0x%zx object=0x%zx live=%zu\n",
                         observation->engine, observation->object, live);
            delete observation;
          });
    }
    std::fprintf(stderr, "RAFT_EGL_LIFETIME event=view_children_retained engine=0x%zx children=%zu live=%zu\n",
                 state->engine_id, children.size(),
                 observed_children_live.load(std::memory_order_relaxed));
#endif
    {
      std::lock_guard<std::mutex> lock(state->mutex);
      state->children.swap(children);
      state->view_destroyed = true;
    }
    queue_release(state);
  }), new RetirementRef(state), [](gpointer data, GClosure*) {
    delete static_cast<RetirementRef*>(data);
  }, static_cast<GConnectFlags>(0));
}
