#include "desktop_qa_identity.h"
#include <gdk/gdkwayland.h>
#include <wayland-client-core.h>
#include <atomic>
#include <cstdint>
#include <cstring>
#include <memory>
#include <mutex>
#include <cstdio>
#include <string>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

namespace {
constexpr char kStateKey[] = "raft-qa-native-window";
constexpr char kRecord[] = "/evidence/engine-identities.jsonl";
std::atomic<unsigned> next_generation{1};
struct State {
  std::mutex mutex;
  uintptr_t engine, window;
  unsigned generation;
  bool child, active = false, visible = false, wayland = false;
  uint32_t surface = 0;
  int width = 0, height = 0;
  std::string window_id;
};
using Ref = std::shared_ptr<State>;

bool write_record(const Ref& state, const char* event) {
  // Fixed private QA destination only. An inherited path never grants write
  // authority and no caller-provided path, token, route or payload is logged.
  const char* destination = g_getenv("RAFT_QA_ENGINE_RECORD");
  if (!destination || std::strcmp(destination, kRecord) != 0) return false;
  int fd = open(kRecord, O_WRONLY | O_APPEND | O_CREAT | O_CLOEXEC | O_NOFOLLOW, 0600);
  if (fd < 0) return false;
  struct stat info{};
  if (fstat(fd, &info) || !S_ISREG(info.st_mode) || info.st_uid != geteuid() || (info.st_mode & 0077)) {
    close(fd); return false;
  }
  std::lock_guard<std::mutex> lock(state->mutex);
  char line[768];
  int length = snprintf(line, sizeof(line),
      "{\"event\":\"%s\",\"pid\":%ld,\"atMicros\":%lld,\"engine\":\"%zx\","
      "\"gtkWindow\":\"%zx\",\"generation\":%u,\"role\":\"%s\",\"windowId\":\"%s\","
      "\"backend\":\"%s\",\"surfaceId\":%u,\"active\":%s,\"visible\":%s,\"width\":%d,\"height\":%d}\n",
      event, static_cast<long>(getpid()), static_cast<long long>(g_get_monotonic_time()),
      state->engine, state->window, state->generation, state->child ? "child" : "primary",
      state->window_id.c_str(), state->wayland ? "wayland" : "unconfirmed", state->surface,
      state->active ? "true" : "false", state->visible ? "true" : "false", state->width, state->height);
  bool accepted = length > 0 && length < static_cast<int>(sizeof(line)) &&
      write(fd, line, static_cast<size_t>(length)) == length;
  close(fd); return accepted;
}
void snapshot(GtkWindow* window, const Ref& state) {
  std::lock_guard<std::mutex> lock(state->mutex);
  state->active = gtk_window_is_active(window);
  state->visible = gtk_widget_get_visible(GTK_WIDGET(window));
  gtk_window_get_size(window, &state->width, &state->height);
  GdkWindow* native = gtk_widget_get_window(GTK_WIDGET(window));
  if (native && GDK_IS_WAYLAND_WINDOW(native)) {
    state->wayland = true;
    wl_surface* surface = gdk_wayland_window_get_wl_surface(native);
    if (surface) state->surface = wl_proxy_get_id(reinterpret_cast<wl_proxy*>(surface));
  }
}
Ref state_for(GtkWindow* window) {
  auto* stored = static_cast<Ref*>(g_object_get_data(G_OBJECT(window), kStateKey));
  return stored ? *stored : Ref{};
}
}  // namespace

void raft_qa_observe_window(FlView* view, GtkWindow* window, bool child) {
  auto state = std::make_shared<State>();
  state->engine = reinterpret_cast<uintptr_t>(fl_view_get_engine(view));
  state->window = reinterpret_cast<uintptr_t>(window);
  state->child = child; state->generation = next_generation.fetch_add(1);
  g_object_set_data_full(G_OBJECT(window), kStateKey, new Ref(state), [](gpointer value) { delete static_cast<Ref*>(value); });
  g_signal_connect(window, "map-event", G_CALLBACK(+[](GtkWidget* widget, GdkEvent*, gpointer) -> gboolean {
    auto state = state_for(GTK_WINDOW(widget));
    snapshot(GTK_WINDOW(widget), state); write_record(state, "mapped"); return FALSE;
  }), nullptr);
  g_signal_connect(window, "notify::is-active", G_CALLBACK(+[](GObject* object, GParamSpec*, gpointer) {
    auto state = state_for(GTK_WINDOW(object)); snapshot(GTK_WINDOW(object), state); write_record(state, "activation");
  }), nullptr);
  g_signal_connect(window, "configure-event", G_CALLBACK(+[](GtkWidget* widget, GdkEvent*, gpointer) -> gboolean {
    auto state = state_for(GTK_WINDOW(widget)); snapshot(GTK_WINDOW(widget), state);
    write_record(state, "configure"); return FALSE;
  }), nullptr);
  g_signal_connect(window, "destroy", G_CALLBACK(+[](GtkWidget* widget, gpointer) {
    auto state = state_for(GTK_WINDOW(widget));
    { std::lock_guard<std::mutex> lock(state->mutex); state->visible = false; state->active = false; }
    write_record(state, "window_destroyed");
  }), nullptr);
  g_object_weak_ref(G_OBJECT(fl_view_get_engine(view)), +[](gpointer data, GObject*) {
    auto* stored = static_cast<Ref*>(data);
    write_record(*stored, "engine_finalized"); delete stored;
  }, new Ref(state));
  snapshot(window, state); write_record(state, "registered");
}

bool raft_qa_register_window_id(GtkWindow* window, const char* window_id) {
  if (!window_id || std::strlen(window_id) != 36) return false;
  for (const char* cursor = window_id; *cursor; cursor++) {
    if (!g_ascii_isxdigit(*cursor) && *cursor != '-') return false;
  }
  auto state = state_for(window);
  if (!state) return false;
  { std::lock_guard<std::mutex> lock(state->mutex); state->window_id = window_id; }
  snapshot(window, state); return write_record(state, "window_identity");
}
