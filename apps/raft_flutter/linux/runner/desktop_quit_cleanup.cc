#include "desktop_quit_cleanup.h"

DesktopQuitCleanup::Entry::Entry(GObject* w, GObject* v, GObject* e)
    : window_id(reinterpret_cast<guintptr>(w)), view_id(reinterpret_cast<guintptr>(v)),
      engine_id(reinterpret_cast<guintptr>(e)) {
  g_weak_ref_init(&window, w);
  g_weak_ref_init(&view, v);
  g_weak_ref_init(&engine, e);
}
DesktopQuitCleanup::Entry::~Entry() {
  g_weak_ref_clear(&window);
  g_weak_ref_clear(&view);
  g_weak_ref_clear(&engine);
}

void DesktopQuitCleanup::Register(GObject* window, GObject* view, GObject* engine) {
  g_return_if_fail(G_IS_OBJECT(window) && G_IS_OBJECT(view) && G_IS_OBJECT(engine));
  for (const auto& entry : entries_) {
    g_autoptr(GObject) existing = G_OBJECT(g_weak_ref_get(&entry->engine));
    if (existing == engine) return;
  }
  if (quitting_) late_registration_ = true;  // Never hide a violated admission.
  entries_.emplace_back(new Entry(window, view, engine));
}

std::vector<DesktopQuitCleanup::ObjectState> DesktopQuitCleanup::Objects() const {
  std::vector<ObjectState> result;
  for (const auto& entry : entries_) {
    g_autoptr(GObject) window = G_OBJECT(g_weak_ref_get(&entry->window));
    g_autoptr(GObject) view = G_OBJECT(g_weak_ref_get(&entry->view));
    g_autoptr(GObject) engine = G_OBJECT(g_weak_ref_get(&entry->engine));
    result.push_back({result.size() + 1, entry->window_id, entry->view_id,
                      entry->engine_id, window != nullptr, view != nullptr,
                      engine != nullptr});
  }
  return result;
}

DesktopQuitCleanup::Counts DesktopQuitCleanup::Live() const {
  Counts result;
  for (const auto& entry : entries_) {
    g_autoptr(GObject) window = G_OBJECT(g_weak_ref_get(&entry->window));
    g_autoptr(GObject) view = G_OBJECT(g_weak_ref_get(&entry->view));
    g_autoptr(GObject) engine = G_OBJECT(g_weak_ref_get(&entry->engine));
    result.windows += window != nullptr;
    result.views += view != nullptr;
    result.engines += engine != nullptr;
  }
  return result;
}

void DesktopQuitCleanup::DestroyOwned() {
  // A window destroy handler can emit platform notifications. Keep a temporary
  // reference only while destroying this one window/view; the registry is weak.
  // The plugin can unparent rather than dispose FlView, so explicitly dispose a
  // surviving registered view. GWeakRef returns null once already disposed.
  for (size_t index = 0; index < entries_.size(); ++index) {
    auto* entry = entries_[index].get();
    g_autoptr(GObject) view = G_OBJECT(g_weak_ref_get(&entry->view));
    g_autoptr(GObject) window = G_OBJECT(g_weak_ref_get(&entry->window));
    if (window) destroy_(window);
    g_autoptr(GObject) surviving = G_OBJECT(g_weak_ref_get(&entry->view));
    if (surviving) destroy_(surviving);
  }
}

DesktopQuitCleanup::Result DesktopQuitCleanup::FinishAfterApplicationRun(
    GMainContext* context, gint64 budget_us,
    const std::function<bool()>& graphics_done, const Observe& observe) {
  quitting_ = true;
  const gint64 deadline = g_get_monotonic_time() + MAX(gint64{0}, budget_us);
  auto report = [&](const char* stage, unsigned iteration) {
    if (observe) observe(stage, iteration, Live());
  };
  report("run_returned", 0);
  DestroyOwned();
  report("owned_destroyed", 0);
  unsigned iterations = 0;
  while (true) {
    const auto live = Live();
    // A single SDK destructor/callback cannot be preempted safely. If it
    // returned after the budget, record failure rather than a late success.
    if (g_get_monotonic_time() >= deadline || iterations >= 256) {
      report("deadline", iterations);
      return {false, true, iterations, live};
    }
    if (!live.windows && !live.views && !live.engines && graphics_done()) {
      report("drained", iterations);
      return {!late_registration_, false, iterations, live};
    }
    // Both a wall deadline and iteration cap prevent perpetually ready sources
    // from extending quit. No blocking main-loop iteration is used.
    if (g_main_context_pending(context)) {
      g_main_context_iteration(context, FALSE);
      ++iterations;
    } else {
      g_usleep(1000);
    }
    // Defensive only: a late registration still makes the result fail, but
    // any newly registered owned native object must be retired rather than
    // becoming a hidden, untracked window.
    DestroyOwned();
  }
}
