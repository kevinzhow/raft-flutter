#include "vsync_driver.h"

#include <gtk/gtk.h>

#include <algorithm>
#include <atomic>
#include <cstddef>
#include <cstdint>
#include <cstring>

#include "flutter_embedder.h"

// The embedder API table lives inside the FlEngine instance (fl_engine.cc:
// `FlutterEngineProcTable embedder_api`) and fl_engine_start() calls
// `embedder_api.Initialize(...)` through it. FlEngine is private, so the table
// is located by its struct_size and checked slot by slot; Initialize is then
// wrapped to add the vsync callback the GTK embedder omits.

namespace {

constexpr gint64 kDefaultIntervalUs = 16667;
constexpr gint64 kMinIntervalUs = 4000;
constexpr gint64 kMaxIntervalUs = 40000;
// A frame-clock tick that has not arrived this long after the next frame
// boundary is replaced by the timer (a hidden, occluded or unpainted window
// gets no ticks); the slack is a fraction of the interval.
constexpr gint64 kTickSlackDivisor = 8;
// After this many deliveries in a row that needed the timer, ticks are only
// probed once per kProbeEvery deliveries.
constexpr guint kTickGiveUpAfter = 30;
constexpr guint kProbeEvery = 60;
// Ticks without a waiting request before the tick callback is dropped.
constexpr guint kIdleTicksBeforeStop = 4;
// A request up to this far (percent of the interval) after a tick that found no
// waiting request is served at once instead of at the next tick: the frame
// would be presented at the same refresh either way.
constexpr gint64 kLatePercent = 100;

struct State {
  GtkWidget* view = nullptr;
  FlutterEngineProcTable* table = nullptr;
  FlutterEngineInitializeFnPtr initialize = nullptr;
  std::atomic<FlutterEngine> engine{nullptr};
  GMutex lock;
  GArray* batons = nullptr;  // intptr_t, guarded by lock
  bool scheduled = false;    // guarded by lock
  guint tick_id = 0;         // main thread only
  guint watchdog_id = 0;     // main thread only
  gint64 grid_origin_us = 0;  // main thread only: a past frame boundary
  guint timer_streak = 0;     // main thread only: consecutive timer deliveries
  gint64 last_delivery_us = 0;  // main thread only
  guint ticks_delivered = 0;   // main thread only, per stats period
  guint ticks_early = 0;
  guint late_delivered = 0;
  guint long_gaps = 0;
  guint requests = 0;            // guarded by lock, per stats period
  gint64 lateness_us[512];       // main thread, per stats period
  guint lateness_count = 0;
  guint idle_ticks = 0;         // main thread only
  gint64 last_tick_us = 0;      // main thread only
  bool boundary_used = true;    // main thread only: the last tick's refresh already released a frame
  gint64 interval_us = 0;       // main thread only (read by the engine thread for stats, racy but harmless)
  guint timer_delivered = 0;
  bool stats = false;
  bool timer_only = false;  // RAFT_LINUX_VSYNC=timer: never use frame-clock ticks
  gint64 stats_start_us = 0;
  guint stats_frames = 0;
  gint64 requested_us = 0;     // guarded by lock
  gint64 delivered_us = 0;
  gint64 wait_total_us = 0;    // request -> release
  gint64 gap_total_us = 0;     // release -> next request
};

State state;

gint64 monitor_interval_us(GtkWidget* view) {
  GdkWindow* window = gtk_widget_get_window(view);
  if (window == nullptr) return kDefaultIntervalUs;
  GdkMonitor* monitor =
      gdk_display_get_monitor_at_window(gdk_window_get_display(window), window);
  int millihertz = monitor != nullptr ? gdk_monitor_get_refresh_rate(monitor) : 0;
  if (millihertz <= 0) return kDefaultIntervalUs;
  return CLAMP(1000000000LL / millihertz, kMinIntervalUs, kMaxIntervalUs);
}

gint64 interval_us(GtkWidget* view, GdkFrameClock* clock) {
  gint64 interval = monitor_interval_us(view);
  // The monitor's mode is authoritative; the frame clock's own estimate is
  // only a default (16.667 ms) until it has measured presentations.
  if (interval == kDefaultIntervalUs && clock != nullptr) {
    gint64 presentation = 0, measured = 0;
    gdk_frame_clock_get_refresh_info(clock, gdk_frame_clock_get_frame_time(clock),
                                     &measured, &presentation);
    if (measured > 0) interval = CLAMP(measured, kMinIntervalUs, kMaxIntervalUs);
  }
  return interval;
}

// GDK 3 on Wayland/X11 paces its frame clock with the previous frame's
// GdkFrameTimings::refresh_interval and falls back to 16.667 ms when that is
// zero. A GL-rendered window commits through eglSwapBuffers, never requests a
// wl_surface frame callback and so never gets a measured interval: the clock
// (and with it every repaint) is capped at 60 Hz on any monitor. Fill the
// interval in from the monitor's mode on each cycle. GdkFrameTimings is
// private, so its layout is verified against the public getters first.
constexpr size_t kTimingsCounterOffset = 8;
constexpr size_t kTimingsFrameTimeOffset = 24;
constexpr size_t kTimingsPresentationOffset = 48;
constexpr size_t kTimingsRefreshIntervalOffset = 56;
constexpr size_t kTimingsPredictedOffset = 64;
int timings_layout = 0;  // 0 unchecked, 1 verified, -1 unknown

template <typename T>
T* timings_field(GdkFrameTimings* timings, size_t offset) {
  return reinterpret_cast<T*>(reinterpret_cast<uint8_t*>(timings) + offset);
}

bool verify_timings_layout(GdkFrameTimings* t) {
  return *timings_field<gint64>(t, kTimingsCounterOffset) == gdk_frame_timings_get_frame_counter(t) &&
         *timings_field<gint64>(t, kTimingsFrameTimeOffset) == gdk_frame_timings_get_frame_time(t) &&
         *timings_field<gint64>(t, kTimingsPresentationOffset) == gdk_frame_timings_get_presentation_time(t) &&
         *timings_field<gint64>(t, kTimingsRefreshIntervalOffset) == gdk_frame_timings_get_refresh_interval(t) &&
         *timings_field<gint64>(t, kTimingsPredictedOffset) ==
             gdk_frame_timings_get_predicted_presentation_time(t) &&
         gdk_frame_timings_get_frame_time(t) != 0;
}

void on_before_paint(GdkFrameClock* clock, gpointer) {
  if (timings_layout < 0 || state.view == nullptr) return;
  GdkFrameTimings* timings = gdk_frame_clock_get_current_timings(clock);
  if (timings == nullptr) return;
  if (timings_layout == 0) {
    timings_layout = verify_timings_layout(timings) ? 1 : -1;
    if (timings_layout < 0) {
      g_message("raft.vsync: frame timings layout not recognised; repaint stays on GDK's pacing");
      return;
    }
  }
  gint64* interval = timings_field<gint64>(timings, kTimingsRefreshIntervalOffset);
  if (*interval == 0) *interval = monitor_interval_us(state.view);
}

void on_view_realize(GtkWidget* view, gpointer) {
  GdkFrameClock* clock = gtk_widget_get_frame_clock(view);
  if (clock != nullptr) g_signal_connect(clock, "before-paint", G_CALLBACK(on_before_paint), nullptr);
}

enum class Source { kTick, kTimer, kLate };

void remove_tick() {
  if (state.tick_id != 0) {
    if (state.view != nullptr) gtk_widget_remove_tick_callback(state.view, state.tick_id);
    state.tick_id = 0;
  }
}

void remove_watchdog() {
  if (state.watchdog_id != 0) {
    g_source_remove(state.watchdog_id);
    state.watchdog_id = 0;
  }
}

void clear_sources() {
  remove_tick();
  remove_watchdog();
}

// Hand every waiting baton back to the engine. Main thread only (the thread
// that ran the engine: FlutterEngineOnVsync must be called there).
// [boundary_us] is the frame boundary this delivery belongs to (the tick, or
// the timer's grid point); a late delivery is started after it but still
// targets the following one.
void deliver(GdkFrameClock* clock, Source source, gint64 boundary_us) {
  remove_watchdog();
  gint64 now_us = g_get_monotonic_time();
  state.last_delivery_us = boundary_us;
  switch (source) {
    case Source::kTick:
      state.boundary_used = true;
      state.grid_origin_us = boundary_us;
      state.timer_streak = 0;
      state.ticks_delivered++;
      break;
    case Source::kLate:
      state.boundary_used = true;
      state.timer_streak = 0;
      state.late_delivered++;
      break;
    case Source::kTimer:
      state.boundary_used = true;
      state.grid_origin_us = boundary_us;
      state.timer_streak++;
      state.timer_delivered++;
      break;
  }
  g_mutex_lock(&state.lock);
  g_autoptr(GArray) taken = state.batons;
  state.batons = g_array_new(FALSE, FALSE, sizeof(intptr_t));
  state.scheduled = false;
  if (state.stats) {
    state.delivered_us = now_us;
    state.wait_total_us += state.delivered_us - state.requested_us;
  }
  g_mutex_unlock(&state.lock);

  FlutterEngine engine = state.engine.load();
  if (engine == nullptr) return;
  uint64_t start = state.table->GetCurrentTime();
  gint64 interval = state.view != nullptr ? interval_us(state.view, clock) : kDefaultIntervalUs;
  state.interval_us = interval;
  // The frame is shown at the first boundary after it starts.
  if (state.stats && state.lateness_count < 512) {
    state.lateness_us[state.lateness_count++] = now_us - boundary_us;
  }
  gint64 to_next = interval - (now_us - boundary_us) % interval;
  uint64_t target = start + static_cast<uint64_t>(to_next) * 1000;
  for (guint i = 0; i < taken->len; i++) {
    state.table->OnVsync(engine, g_array_index(taken, intptr_t, i), start, target);
  }
  if (state.stats) {
    state.stats_frames++;
    gint64 now = g_get_monotonic_time();
    if (state.stats_start_us == 0) state.stats_start_us = now;
    if (now - state.stats_start_us >= G_USEC_PER_SEC) {
      GdkDisplay* display = gdk_display_get_default();
      g_mutex_lock(&state.lock);
      guint requests = state.requests;
      state.requests = 0;
      g_mutex_unlock(&state.lock);
      std::sort(state.lateness_us, state.lateness_us + state.lateness_count);
      double late_median = state.lateness_count ? state.lateness_us[state.lateness_count / 2] / 1000.0 : 0;
      double late_max = state.lateness_count ? state.lateness_us[state.lateness_count - 1] / 1000.0 : 0;
      state.lateness_count = 0;
      g_printerr("raft.vsync: [%s %s] requested %u, delivered %u in %.0f ms (%u by tick, %u late after a tick, %u by timer; %u early ticks ignored; %u engine gaps over one interval), lateness vs vblank median %.2f max %.2f ms, interval %.2f ms, wait for tick %.2f ms, engine gap %.2f ms\n",
                 display != nullptr ? G_OBJECT_TYPE_NAME(display) : "none",
                 display != nullptr ? gdk_display_get_name(display) : "none", requests, state.stats_frames,
                 (now - state.stats_start_us) / 1000.0, state.ticks_delivered, state.late_delivered,
                 state.timer_delivered, state.ticks_early, state.long_gaps, late_median, late_max,
                 interval / 1000.0, state.wait_total_us / 1000.0 / state.stats_frames,
                 state.gap_total_us / 1000.0 / state.stats_frames);
      state.ticks_delivered = state.timer_delivered = state.late_delivered = state.ticks_early = 0;
      state.long_gaps = 0;
      state.wait_total_us = state.gap_total_us = 0;
      state.stats_start_us = now;
      state.stats_frames = 0;
    }
  }
}

bool engine_waiting() {
  g_mutex_lock(&state.lock);
  bool waiting = state.scheduled;
  g_mutex_unlock(&state.lock);
  return waiting;
}

// Frame-clock tick. The callback stays registered while frames are being
// requested, so the clock keeps ticking on every refresh instead of being
// restarted (and re-synchronised) for each frame; a few ticks with no request
// end it, which lets an idle window fall back to zero frames.
gboolean on_tick(GtkWidget*, GdkFrameClock* clock, gpointer) {
  gint64 now = g_get_monotonic_time();
  // A frame clock that is not paced by the display (it can tick back to back)
  // must not release frames faster than the refresh rate: a tick earlier than
  // three quarters of an interval after the previous frame boundary is ignored.
  if (state.last_delivery_us != 0 && now - state.last_delivery_us < interval_us(state.view, clock) * 3 / 4) {
    state.ticks_early++;
    return G_SOURCE_CONTINUE;
  }
  state.last_tick_us = now;
  if (engine_waiting()) {
    state.idle_ticks = 0;
    deliver(clock, Source::kTick, now);
    return G_SOURCE_CONTINUE;
  }
  // The grid follows the compositor even while the engine is quiet.
  state.boundary_used = false;
  state.grid_origin_us = now;
  if (++state.idle_ticks >= kIdleTicksBeforeStop) {
    state.tick_id = 0;  // returning REMOVE drops it
    return G_SOURCE_REMOVE;
  }
  return G_SOURCE_CONTINUE;
}

// The frame boundary the timer targets, in monotonic microseconds.
gint64 pending_boundary_us = 0;

// No frame-clock tick by the next frame boundary (window hidden, occluded,
// minimised or not yet mapped, as during the first frame that shows it, or a
// session whose compositor sends no frame callbacks): deliver from a timer on
// the same grid, never slower than the engine's own fixed timer.
gboolean on_watchdog(gpointer) {
  state.watchdog_id = 0;
  if (!engine_waiting()) return G_SOURCE_REMOVE;
  deliver(state.view != nullptr ? gtk_widget_get_frame_clock(state.view) : nullptr, Source::kTimer,
          pending_boundary_us);
  if (state.timer_streak >= kTickGiveUpAfter && state.timer_streak % kProbeEvery != 0) remove_tick();
  return G_SOURCE_REMOVE;
}

gboolean schedule_on_main(gpointer) {
  if (state.view == nullptr || !engine_waiting()) return G_SOURCE_REMOVE;
  GdkFrameClock* clock = gtk_widget_get_frame_clock(state.view);
  gint64 interval = interval_us(state.view, clock);
  state.interval_us = interval;
  gint64 now = g_get_monotonic_time();
  bool use_ticks = !state.timer_only && clock != nullptr && gtk_widget_get_mapped(state.view) &&
                   (state.timer_streak < kTickGiveUpAfter || state.timer_streak % kProbeEvery == 0);
  if (use_ticks && state.tick_id == 0) {
    state.idle_ticks = 0;
    state.tick_id = gtk_widget_add_tick_callback(state.view, on_tick, nullptr, nullptr);
  }
  // The request came just after a refresh whose tick found nothing to
  // release (the engine asks for the next frame a few ms after the last one
  // was released, and a frame that finishes slightly late asks after the next
  // boundary): start the frame now, within the same refresh, rather than
  // idling a whole period. Frames are cheap (a few ms), so the remainder of
  // the period is enough to finish before the next boundary.
  // Each refresh releases at most one frame: only a refresh whose tick found
  // nothing waiting can be served late, so the rate never exceeds the display's.
  if (use_ticks && state.tick_id != 0 && !state.boundary_used && state.last_tick_us != 0 &&
      now >= state.last_tick_us) {
    gint64 since = now - state.last_tick_us;
    if (since < interval * kLatePercent / 100) {
      deliver(clock, Source::kLate, state.last_tick_us);
      return G_SOURCE_REMOVE;
    }
  }
  // Next boundary of the grid anchored on the last tick (or the timer's own
  // previous boundary); a first or long-idle request lands on the next
  // boundary of that grid.
  gint64 boundary = now + interval;
  if (state.grid_origin_us != 0 && now >= state.grid_origin_us) {
    boundary = now + interval - (now - state.grid_origin_us) % interval;
  }
  pending_boundary_us = boundary;
  // The slack only protects a working tick; once ticks have stopped arriving the
  // timer is the pacing source and fires on the boundary itself.
  gint64 wait_us = boundary - now + (use_ticks ? interval / kTickSlackDivisor : 0);
  if (wait_us < 1000) wait_us = 1000;
  remove_watchdog();
  state.watchdog_id = g_timeout_add(static_cast<guint>((wait_us + 500) / 1000), on_watchdog, nullptr);
  return G_SOURCE_REMOVE;
}

// Engine-managed thread.
void on_engine_vsync(void*, intptr_t baton) {
  g_mutex_lock(&state.lock);
  state.requests++;
  if (state.stats) {
    gint64 now = g_get_monotonic_time();
    if (state.delivered_us != 0 && !state.scheduled) {
      state.gap_total_us += now - state.delivered_us;
      if (state.interval_us != 0 && now - state.delivered_us > state.interval_us) state.long_gaps++;
    }
    state.requested_us = now;
  }
  g_array_append_val(state.batons, baton);
  bool first = !state.scheduled;
  state.scheduled = true;
  g_mutex_unlock(&state.lock);
  if (first) g_main_context_invoke_full(nullptr, G_PRIORITY_HIGH, schedule_on_main, nullptr, nullptr);
}

FlutterEngineResult initialize_with_vsync(size_t version, const FlutterRendererConfig* config,
                                          const FlutterProjectArgs* args, void* user_data,
                                          FlutterEngine* engine_out) {
  FlutterProjectArgs patched;
  const FlutterProjectArgs* use = args;
  if (args != nullptr && args->struct_size == sizeof(FlutterProjectArgs) &&
      args->vsync_callback == nullptr) {
    std::memcpy(&patched, args, sizeof(patched));
    patched.vsync_callback = on_engine_vsync;
    use = &patched;
  }
  FlutterEngineResult result = state.initialize(version, config, use, user_data, engine_out);
  if (result == kSuccess && use == &patched && engine_out != nullptr) {
    state.engine.store(*engine_out);
  }
  return result;
}

void on_view_destroy(GtkWidget*, gpointer) {
  clear_sources();
  state.view = nullptr;
}

FlutterEngineProcTable* find_table(GObject* engine) {
  GTypeQuery query;
  g_type_query(G_OBJECT_TYPE(engine), &query);
  auto* bytes = reinterpret_cast<uint8_t*>(engine);
  FlutterEngineProcTable* found = nullptr;
  for (size_t offset = sizeof(GObject); offset + sizeof(FlutterEngineProcTable) <= query.instance_size;
       offset += sizeof(void*)) {
    auto* candidate = reinterpret_cast<FlutterEngineProcTable*>(bytes + offset);
    if (candidate->struct_size != sizeof(FlutterEngineProcTable)) continue;
    auto** slots = reinterpret_cast<void**>(candidate);
    bool complete = true;
    for (size_t i = 1; i < sizeof(FlutterEngineProcTable) / sizeof(void*); i++) {
      if (slots[i] == nullptr) complete = false;
    }
    if (!complete) continue;
    if (found != nullptr) return nullptr;  // ambiguous
    found = candidate;
  }
  return found;
}

}  // namespace

void raft_vsync_install(FlView* view) {
  if (g_strcmp0(g_getenv("RAFT_LINUX_VSYNC"), "0") == 0) return;
  if (state.table != nullptr) return;
  FlEngine* engine = fl_view_get_engine(view);
  FlutterEngineProcTable* table = engine != nullptr ? find_table(G_OBJECT(engine)) : nullptr;
  if (table == nullptr) {
    g_message("raft.vsync: engine layout not recognised; keeping the engine's own 60 Hz timer");
    return;
  }
  g_mutex_init(&state.lock);
  state.batons = g_array_new(FALSE, FALSE, sizeof(intptr_t));
  state.view = GTK_WIDGET(view);
  state.table = table;
  state.initialize = table->Initialize;
  state.stats = g_strcmp0(g_getenv("RAFT_LINUX_VSYNC_STATS"), "1") == 0;
  state.timer_only = g_strcmp0(g_getenv("RAFT_LINUX_VSYNC"), "timer") == 0;
  table->Initialize = initialize_with_vsync;
  g_signal_connect(view, "destroy", G_CALLBACK(on_view_destroy), nullptr);
  g_signal_connect_after(view, "realize", G_CALLBACK(on_view_realize), nullptr);
}
