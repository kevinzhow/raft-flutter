#include "shared_egl_display.h"

#include <epoxy/egl.h>
#ifdef GDK_WINDOWING_WAYLAND
#include <gdk/gdkwayland.h>
#endif
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "shared_egl_termination.h"
#include "desktop_quit_cleanup.h"
#include "desktop_view_retirement.h"
#ifdef RAFT_MULTIWINDOW_QA
#include <atomic>
#include <cstdio>
#endif

namespace {
SharedEglTermination lifetime;
DesktopQuitCleanup owned_windows([](GObject* object) {
  gtk_widget_destroy(GTK_WIDGET(object));
});
#ifdef RAFT_MULTIWINDOW_QA
EGLDisplay observed_display = EGL_NO_DISPLAY;
PFNEGLDESTROYCONTEXTPROC previous_destroy = nullptr;
PFNEGLDESTROYCONTEXTPROC actual_destroy = nullptr;
std::atomic<size_t> destroyed_contexts{0};
EGLBoolean observe_context_destroy(EGLDisplay display, EGLContext context) {
  const EGLBoolean result = actual_destroy(display, context);
  if (display == observed_display) {
    const size_t count = result == EGL_TRUE
        ? destroyed_contexts.fetch_add(1, std::memory_order_relaxed) + 1
        : destroyed_contexts.load(std::memory_order_relaxed);
    std::fprintf(stderr, "RAFT_EGL_LIFETIME event=context_destroy display=%p context=%p success=%d count=%zu\n",
                 display, context, result == EGL_TRUE, count);
  }
  return result;
}
#endif

// GDK keeps its own thread-local current-context bookkeeping. Restore that AND
// the actual EGL binding, which may belong to Flutter rather than to GDK.
class CurrentContext {
 public:
  CurrentContext()
      : gdk_(gdk_gl_context_get_current()), display_(eglGetCurrentDisplay()),
        context_(eglGetCurrentContext()), draw_(eglGetCurrentSurface(EGL_DRAW)),
        read_(eglGetCurrentSurface(EGL_READ)), api_(eglQueryAPI()) {
    if (gdk_) g_object_ref(gdk_);
  }
  ~CurrentContext() { Restore(); }
  bool Restore() {
    if (restored_) return success_;
    restored_ = true;
    if (gdk_) {
      gdk_gl_context_make_current(gdk_);
      g_object_unref(gdk_);
    } else {
      gdk_gl_context_clear_current();
    }
    success_ = eglBindAPI(api_) == EGL_TRUE;
    if (display_ != EGL_NO_DISPLAY) {
      success_ = eglMakeCurrent(display_, draw_, read_, context_) == EGL_TRUE && success_;
    } else {
      const EGLDisplay current = eglGetCurrentDisplay();
      if (current != EGL_NO_DISPLAY) {
        success_ = eglMakeCurrent(current, EGL_NO_SURFACE, EGL_NO_SURFACE,
                                 EGL_NO_CONTEXT) == EGL_TRUE && success_;
      }
    }
    success_ = success_ && eglGetCurrentDisplay() == display_ &&
               eglGetCurrentContext() == context_ &&
               eglGetCurrentSurface(EGL_DRAW) == draw_ &&
               eglGetCurrentSurface(EGL_READ) == read_ &&
               eglQueryAPI() == api_ && gdk_gl_context_get_current() == gdk_;
#ifdef RAFT_MULTIWINDOW_QA
    std::fprintf(stderr, "RAFT_EGL_LIFETIME event=context_restore success=%d oldDisplay=%p currentDisplay=%p oldContext=%p currentContext=%p oldDraw=%p currentDraw=%p oldRead=%p currentRead=%p oldAPI=%u currentAPI=%u oldGdk=%p currentGdk=%p\n",
                 success_, display_, eglGetCurrentDisplay(), context_, eglGetCurrentContext(),
                 draw_, eglGetCurrentSurface(EGL_DRAW), read_, eglGetCurrentSurface(EGL_READ),
                 api_, eglQueryAPI(), static_cast<void*>(gdk_),
                 static_cast<void*>(gdk_gl_context_get_current()));
#endif
    return success_;
  }
 private:
  GdkGLContext* gdk_;
  EGLDisplay display_;
  EGLContext context_;
  EGLSurface draw_;
  EGLSurface read_;
  EGLenum api_;
  bool restored_ = false;
  bool success_ = false;
};

EGLDisplay engine_display(GdkDisplay* display) {
#ifdef GDK_WINDOWING_WAYLAND
  if (GDK_IS_WAYLAND_DISPLAY(display)) {
    return eglGetPlatformDisplayEXT(EGL_PLATFORM_WAYLAND_EXT,
                                   gdk_wayland_display_get_wl_display(display),
                                   nullptr);
  }
#endif
#ifdef GDK_WINDOWING_X11
  if (GDK_IS_X11_DISPLAY(display)) {
    return eglGetPlatformDisplayEXT(EGL_PLATFORM_X11_EXT,
                                   gdk_x11_display_get_xdisplay(display), nullptr);
  }
#endif
  return EGL_NO_DISPLAY;
}
}  // namespace

extern "C" __attribute__((visibility("default")))
bool raft_desktop_window_creation_allowed() {
  return owned_windows.accepting();
}

void raft_desktop_track_window(FlView* view, GtkWindow* window) {
  owned_windows.Register(G_OBJECT(window), G_OBJECT(view),
                         G_OBJECT(fl_view_get_engine(view)));
  raft_desktop_retire_view_children_after_engine(view, [] {
    return owned_windows.registered() >= 2;
  });
}

bool raft_desktop_finish_quit() {
  // Global quit only. Ordinary child Close never enters this function. Keep
  // the old single-window exit path untouched when the feature was not used.
  owned_windows.StopAccepting();
  if (owned_windows.registered() < 2 && !lifetime.Ready()) return true;
  const auto result = owned_windows.FinishAfterApplicationRun(
      g_main_context_default(), 2 * G_USEC_PER_SEC,
      [] { return lifetime.ReadyToRelease(); },
      [](const char* stage, unsigned iterations,
          const DesktopQuitCleanup::Counts& live) {
#ifdef RAFT_MULTIWINDOW_QA
        const unsigned phase = g_strcmp0(stage, "run_returned") == 0 ? 1 :
            g_strcmp0(stage, "owned_destroyed") == 0 ? 2 :
            g_strcmp0(stage, "drained") == 0 ? 3 : 4;
        std::fprintf(stderr, "RAFT_EGL_LIFETIME event=quit_stage stage=%u iterations=%u windows=%zu views=%zu engines=%zu deferred=%zu seen=%zu\n",
                     phase, iterations, live.windows, live.views, live.engines,
                     lifetime.deferred(), lifetime.engines_seen());
        for (const auto& object : owned_windows.Objects()) {
          std::fprintf(stderr, "RAFT_EGL_LIFETIME event=quit_object stage=%u ordinal=%zu window=0x%zx view=0x%zx engine=0x%zx windowLive=%d viewLive=%d engineLive=%d\n",
                       phase, object.ordinal, object.window, object.view, object.engine,
                       object.window_live, object.view_live, object.engine_live);
        }
#else
        (void)stage; (void)iterations; (void)live;
#endif
      });
  if (!result.complete) g_warning("Owned desktop quit completion did not finish");
  return result.complete;
}

void raft_shared_egl_watch_engine(FlEngine* engine) {
  if (g_object_get_data(G_OBJECT(engine), "raft-egl-observed")) return;
  g_object_set_data(G_OBJECT(engine), "raft-egl-observed", GINT_TO_POINTER(1));
  lifetime.EngineAdded();
#ifdef RAFT_MULTIWINDOW_QA
  std::fprintf(stderr, "RAFT_EGL_LIFETIME event=engine_added engine=%p live=%zu\n",
               static_cast<void*>(engine), lifetime.live_engines());
#endif
  g_object_weak_ref(G_OBJECT(engine), [](gpointer, GObject* object) {
    lifetime.EngineRemoved();
#ifdef RAFT_MULTIWINDOW_QA
    std::fprintf(stderr, "RAFT_EGL_LIFETIME event=engine_finalized engine=%p live=%zu\n",
                 static_cast<void*>(object), lifetime.live_engines());
#else
    (void)object;
#endif
  }, nullptr);
}

bool raft_shared_egl_prepare_open(GtkWindow* window) {
  if (!owned_windows.accepting()) return false;
  // A changed/retired hook must not silently become eligible again.
  static bool installed = false;
  if (installed && !lifetime.Ready()) return false;
  GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
  if (!gdk_window) return false;
  g_autoptr(GdkGLContext) probe = nullptr;
  CurrentContext previous;
  g_autoptr(GError) error = nullptr;
  probe = gdk_window_create_gl_context(gdk_window, &error);
  if (!probe || !gdk_gl_context_realize(probe, &error)) return false;
  gdk_gl_context_make_current(probe);
  const EGLDisplay actual_gtk_display = eglGetCurrentDisplay();
  // Compare a realized GTK context's actual handle with the exact lookup used
  // by pinned Flutter3.47's FlOpenGLManager, not just the native display name.
  const EGLDisplay actual_engine_display = engine_display(gdk_display_get_default());
#ifdef RAFT_MULTIWINDOW_QA
  std::fprintf(stderr, "RAFT_EGL_LIFETIME event=display_compare gtk=%p engineLookup=%p match=%d\n",
               actual_gtk_display, actual_engine_display,
               actual_gtk_display != EGL_NO_DISPLAY && actual_gtk_display == actual_engine_display);
#endif
  if (actual_gtk_display == EGL_NO_DISPLAY ||
      actual_gtk_display != actual_engine_display) return false;
  // Some implementations already count initialization references. Leave their
  // native semantics intact rather than coalescing balanced Terminate calls.
  EGLAttrib tracks_references = EGL_FALSE;
  if (epoxy_has_egl_extension(EGL_NO_DISPLAY, "EGL_KHR_display_reference") &&
      eglQueryDisplayAttribKHR(actual_gtk_display, EGL_TRACK_REFERENCES_KHR,
                               &tracks_references) == EGL_TRUE &&
      tracks_references == EGL_TRUE) {
    return previous.Restore();
  }
  const auto terminate = reinterpret_cast<SharedEglTermination::Terminate>(
      eglGetProcAddress("eglTerminate"));
  if (!terminate) return false;
  if (!previous.Restore()) return false;
  g_clear_object(&probe);
  if (installed) return lifetime.Matches(actual_gtk_display);
  installed = lifetime.Install(actual_gtk_display, &epoxy_eglTerminate, terminate);
#ifdef RAFT_MULTIWINDOW_QA
  if (installed && !actual_destroy) {
    actual_destroy = reinterpret_cast<PFNEGLDESTROYCONTEXTPROC>(eglGetProcAddress("eglDestroyContext"));
    if (actual_destroy) {
      observed_display = actual_gtk_display;
      previous_destroy = epoxy_eglDestroyContext;
      epoxy_eglDestroyContext = observe_context_destroy;
    }
  }
  std::fprintf(stderr, "RAFT_EGL_LIFETIME event=installed success=%d contextObserver=%d live=%zu\n",
               installed, actual_destroy != nullptr, lifetime.live_engines());
#endif
  return installed;
}

bool raft_shared_egl_release() {
#ifdef RAFT_MULTIWINDOW_QA
  if (epoxy_eglDestroyContext == observe_context_destroy) {
    epoxy_eglDestroyContext = previous_destroy;
  }
#endif
  const bool success = lifetime.Release();
#ifdef RAFT_MULTIWINDOW_QA
  std::fprintf(stderr, "RAFT_EGL_LIFETIME event=released success=%d live=%zu deferred=%zu terminateCount=%zu contextDestroyCount=%zu ready=%d\n",
               success, lifetime.live_engines(), lifetime.deferred(), lifetime.terminated(),
               destroyed_contexts.load(std::memory_order_relaxed), lifetime.Ready());
#endif
  return success;
}
