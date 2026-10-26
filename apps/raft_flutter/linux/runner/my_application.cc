#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif
#ifdef GDK_WINDOWING_WAYLAND
#include <gdk/gdkwayland.h>
#endif

#include "flutter/generated_plugin_registrant.h"
#include "vsync_driver.h"
#include "desktop_caption_bar.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

// Channel state is owned by its handler. The window outlives its Flutter view.
struct TitleBar {
  GtkWindow* window;
  DesktopCaptionBar* caption;
  FlMethodChannel* channel;
  gulong window_state_handler;
  gulong active_handler;
};

static FlValue* title_bar_state(TitleBar* bar) {
  FlValue* state = fl_value_new_map();
  fl_value_set_string_take(state, "height", fl_value_new_float(bar->caption->custom() ? 48 : 0));
  fl_value_set_string_take(state, "fullscreen", fl_value_new_bool(bar->caption->fullscreen()));
  fl_value_set_string_take(state, "customControls", fl_value_new_bool(bar->caption->custom()));
  fl_value_set_string_take(state, "maximized", fl_value_new_bool(bar->caption->maximized()));
  fl_value_set_string_take(state, "active", fl_value_new_bool(bar->caption->active()));
  fl_value_set_string_take(state, "buttonLayout", fl_value_new_string(bar->caption->layout().c_str()));
  return state;
}

static void title_bar_report(TitleBar* bar) {
  g_autoptr(FlValue) state = title_bar_state(bar);
  fl_method_channel_invoke_method(bar->channel, "state", state, nullptr, nullptr, nullptr);
}

static void title_bar_free(gpointer data) {
  auto* bar = static_cast<TitleBar*>(data);
  g_signal_handler_disconnect(bar->window, bar->window_state_handler);
  g_signal_handler_disconnect(bar->window, bar->active_handler);
  delete bar->caption;
  g_free(bar);
}

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GList* windows = gtk_application_get_windows(GTK_APPLICATION(application));
  if (windows != nullptr) {
    gtk_window_present(GTK_WINDOW(windows->data));
    return;
  }
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  TitleBar* title_bar = g_new0(TitleBar, 1);
  title_bar->window = window;
  title_bar->caption = new DesktopCaptionBar(window);
  gtk_window_set_title(window, "Raft");

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);
  // The Dart UI isolate runs on its own thread (RAFT_LINUX_UI_THREAD=platform
  // restores the engine default, which runs it on the GTK main thread). With
  // the default every frame's build waits behind the GTK paint of the previous
  // frame on the same thread, which takes several ms at 2x scale and turned a
  // 3 ms frame into a missed 120 Hz refresh; see docs/idle-cpu.md.
  const gchar* ui_thread = g_getenv("RAFT_LINUX_UI_THREAD");
  fl_dart_project_set_ui_thread_policy(
      project, g_strcmp0(ui_thread, "platform") == 0
                   ? FL_UI_THREAD_POLICY_RUN_ON_PLATFORM_THREAD
                   : FL_UI_THREAD_POLICY_RUN_ON_SEPARATE_THREAD);
  // RAFT_LINUX_IMPELLER=0 renders with Skia and =1 with Impeller; unset keeps
  // the engine's default (Impeller in Flutter 3.47). For A/B measurements.
  const gchar* impeller = g_getenv("RAFT_LINUX_IMPELLER");
  if (g_strcmp0(impeller, "0") == 0) fl_dart_project_set_enable_impeller(project, FALSE);
  if (g_strcmp0(impeller, "1") == 0) fl_dart_project_set_enable_impeller(project, TRUE);

  FlView* view = fl_view_new(project);
  // Before the view is realized (that starts the engine); see vsync_driver.h.
  raft_vsync_install(view);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) window_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "app.raft/window", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(window_channel,
      [](FlMethodChannel*, FlMethodCall* call, gpointer data) {
        if (g_strcmp0(fl_method_call_get_name(call), "isActive") == 0) {
          g_autoptr(FlValue) active =
              fl_value_new_bool(gtk_window_is_active(GTK_WINDOW(data)));
          fl_method_call_respond_success(call, active, nullptr);
        } else if (g_strcmp0(fl_method_call_get_name(call), "present") == 0) {
          GtkWindow* target = GTK_WINDOW(data);
          // A notification click carries the desktop's activation token
          // (org.freedesktop.Notifications ActivationToken). Wayland
          // compositors and KWin only raise and focus a window that presents
          // itself with it; without one this is a plain present.
          FlValue* args = fl_method_call_get_args(call);
          FlValue* token = args != nullptr &&
                                   fl_value_get_type(args) == FL_VALUE_TYPE_MAP
                               ? fl_value_lookup_string(args, "token")
                               : nullptr;
          if (token != nullptr &&
              fl_value_get_type(token) == FL_VALUE_TYPE_STRING &&
              fl_value_get_string(token)[0] != '\0') {
            const gchar* startup_id = fl_value_get_string(token);
            GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(target));
#ifdef GDK_WINDOWING_WAYLAND
            if (GDK_IS_WAYLAND_DISPLAY(display)) {
              gdk_wayland_display_set_startup_notification_id(display,
                                                              startup_id);
            }
#endif
            gtk_window_set_startup_id(target, startup_id);
          }
          gtk_window_present(target);
          fl_method_call_respond_success(call, nullptr, nullptr);
        } else {
          fl_method_call_respond_not_implemented(call, nullptr);
        }
      }, g_object_ref(window), g_object_unref);

  g_autoptr(FlMethodChannel) title_bar_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "app.raft/titlebar", FL_METHOD_CODEC(codec));
  title_bar->channel = title_bar_channel;
  title_bar->window_state_handler = g_signal_connect(window, "window-state-event",
      G_CALLBACK(+[](GtkWidget*, GdkEventWindowState*, gpointer data) -> gboolean {
        title_bar_report(static_cast<TitleBar*>(data));
        return FALSE;
      }), title_bar);
  title_bar->active_handler = g_signal_connect(window, "notify::is-active",
      G_CALLBACK(+[](GObject*, GParamSpec*, gpointer data) {
        title_bar_report(static_cast<TitleBar*>(data));
      }), title_bar);
  fl_method_channel_set_method_call_handler(
      title_bar_channel,
      [](FlMethodChannel*, FlMethodCall* call, gpointer data) {
        TitleBar* bar = static_cast<TitleBar*>(data);
        const gchar* method = fl_method_call_get_name(call);
        if (g_strcmp0(method, "status") == 0 ||
            g_strcmp0(method, "setIntegrated") == 0) {
          g_autoptr(FlValue) state = title_bar_state(bar);
          fl_method_call_respond_success(call, state, nullptr);
        } else if (g_strcmp0(method, "startDragging") == 0) {
          bar->caption->StartDragging();
          fl_method_call_respond_success(call, nullptr, nullptr);
        } else if (g_strcmp0(method, "doubleClick") == 0) {
          bar->caption->DoubleClick();
          fl_method_call_respond_success(call, nullptr, nullptr);
        } else if (g_strcmp0(method, "minimize") == 0) {
          bar->caption->Minimize();
          fl_method_call_respond_success(call, nullptr, nullptr);
        } else if (g_strcmp0(method, "toggleMaximize") == 0) {
          bar->caption->ToggleMaximize();
          fl_method_call_respond_success(call, nullptr, nullptr);
        } else if (g_strcmp0(method, "close") == 0) {
          fl_method_call_respond_success(call, nullptr, nullptr);
          bar->caption->Close();
        } else if (g_strcmp0(method, "setStyle") == 0 ||
                   g_strcmp0(method, "setCaptionButtonRects") == 0) {
          // Flutter paints the whole row; GTK needs no colour or hit rectangles.
          fl_method_call_respond_success(call, nullptr, nullptr);
        } else if (g_strcmp0(method, "setTitle") == 0) {
          // The window's name for the task switcher and window lists (the
          // Web document title); the header bar keeps its empty title.
          FlValue* args = fl_method_call_get_args(call);
          FlValue* title = args != nullptr &&
                                   fl_value_get_type(args) == FL_VALUE_TYPE_MAP
                               ? fl_value_lookup_string(args, "title")
                               : nullptr;
          if (title != nullptr &&
              fl_value_get_type(title) == FL_VALUE_TYPE_STRING) {
            gtk_window_set_title(bar->window, fl_value_get_string(title));
          }
          fl_method_call_respond_success(call, nullptr, nullptr);
        } else {
          fl_method_call_respond_not_implemented(call, nullptr);
        }
      },
      title_bar, title_bar_free);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  // GLib forwards later launches to the owning instance; app_links observes
  // its command-line signal. The initial URI reaches Dart as entrypoint args.
  return G_APPLICATION_CLASS(my_application_parent_class)->local_command_line(
      application, arguments, exit_status);
}

static gint my_application_command_line(GApplication* application,
                                         GApplicationCommandLine*) {
  g_application_activate(application);
  return 0;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->command_line = my_application_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_HANDLES_COMMAND_LINE, nullptr));
}
