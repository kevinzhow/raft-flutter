#ifndef RAFT_DESKTOP_QUIT_CLEANUP_H_
#define RAFT_DESKTOP_QUIT_CLEANUP_H_

#include <gio/gio.h>
#include <functional>
#include <memory>
#include <vector>

// Only native objects registered by this application's window-created path.
// No GtkApplication/window-list ownership assumption, no strong object cache.
class DesktopQuitCleanup {
 public:
  using Destroy = void (*)(GObject*);
  struct Counts { size_t windows = 0, views = 0, engines = 0; };
  struct ObjectState {
    size_t ordinal;
    guintptr window, view, engine;
    bool window_live, view_live, engine_live;
  };
  struct Result { bool complete; bool timed_out; unsigned iterations; Counts live; };
  using Observe = std::function<void(const char*, unsigned, const Counts&)>;

  explicit DesktopQuitCleanup(Destroy destroy) : destroy_(destroy) {}
  void Register(GObject* window, GObject* view, GObject* engine);
  bool accepting() const { return !quitting_; }
  size_t registered() const { return entries_.size(); }
  Counts Live() const;
  std::vector<ObjectState> Objects() const;
  // Called only after g_application_run returns. Does not change a draft veto
  // or ordinary child Close. Individual SDK/driver destructors are not preempted.
  Result FinishAfterApplicationRun(
      GMainContext* context, gint64 budget_us,
      const std::function<bool()>& graphics_done, const Observe& observe = {});
  void StopAccepting() { quitting_ = true; }

 private:
  struct Entry {
    Entry(GObject* window, GObject* view, GObject* engine);
    ~Entry();
    GWeakRef window, view, engine;
    guintptr window_id, view_id, engine_id;
  };
  void DestroyOwned();
  bool quitting_ = false;
  bool late_registration_ = false;
  Destroy destroy_;
  std::vector<std::unique_ptr<Entry>> entries_;
};

#endif
