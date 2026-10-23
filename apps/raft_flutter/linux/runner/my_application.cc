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

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

// The header bar the title strip colours, and the CSS it is coloured with.
// Null when the window manager draws the title bar (the app cannot colour
// that); see docs/desktop-title-bar.md.
struct TitleBar {
  GtkWindow* window;
  GtkWidget* header_bar;
  GtkCssProvider* css;
};

static void title_bar_free(gpointer data) {
  TitleBar* bar = static_cast<TitleBar*>(data);
  g_clear_object(&bar->css);
  g_free(bar);
}

static void format_rgb(char* out, size_t size, int64_t argb) {
  g_snprintf(out, size, "#%06x", static_cast<unsigned>(argb & 0xFFFFFF));
}

// Paint the header bar in the nav rail's colours: no title, the rail's colour
// in every window state, and the rail's divider as its bottom rule.
static void title_bar_set_style(TitleBar* bar, int64_t background,
                                int64_t foreground, int64_t rule,
                                double rule_width) {
  if (bar->header_bar == nullptr) return;
  char bg[16], fg[16], line[16];
  format_rgb(bg, sizeof(bg), background);
  format_rgb(fg, sizeof(fg), foreground);
  format_rgb(line, sizeof(line), rule);
  g_autofree gchar* css = g_strdup_printf(
      "headerbar.raft-titlebar, headerbar.raft-titlebar:backdrop {"
      " background: %s; background-image: none; box-shadow: none;"
      " border-bottom: %dpx solid %s; }"
      "headerbar.raft-titlebar button, headerbar.raft-titlebar button:backdrop,"
      " headerbar.raft-titlebar button image,"
      " headerbar.raft-titlebar button:backdrop image {"
      " color: %s; opacity: 1; text-shadow: none; -gtk-icon-shadow: none; }",
      bg, static_cast<int>(rule_width + 0.5), line, fg);
  gtk_css_provider_load_from_data(bar->css, css, -1, nullptr);
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

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  // RAFT_LINUX_HEADER_BAR=1 forces the header bar (a window manager that
  // draws no title bar of its own, such as a bare Xvfb, would otherwise get
  // none); RAFT_LINUX_HEADER_BAR=0 forces the window manager's.
  const gchar* forced_header_bar = g_getenv("RAFT_LINUX_HEADER_BAR");
  if (g_strcmp0(forced_header_bar, "1") == 0) use_header_bar = TRUE;
  if (g_strcmp0(forced_header_bar, "0") == 0) use_header_bar = FALSE;
  TitleBar* title_bar = g_new0(TitleBar, 1);
  title_bar->window = window;
  // The window's name stays for the task switcher; the bar shows no title.
  gtk_window_set_title(window, "Raft");
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    // An empty custom title keeps the bar free of text; only the window
    // controls GTK draws remain.
    GtkWidget* no_title = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_widget_show(no_title);
    gtk_header_bar_set_custom_title(header_bar, no_title);
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
    title_bar->header_bar = GTK_WIDGET(header_bar);
    title_bar->css = gtk_css_provider_new();
    GtkStyleContext* style = gtk_widget_get_style_context(title_bar->header_bar);
    gtk_style_context_add_class(style, "raft-titlebar");
    // Screen-wide, because a provider on the bar's own context would not reach
    // the window buttons inside it; every rule is scoped to
    // headerbar.raft-titlebar.
    gtk_style_context_add_provider_for_screen(
        gtk_widget_get_screen(title_bar->header_bar),
        GTK_STYLE_PROVIDER(title_bar->css),
        GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  }

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

  // The app tells the runner the rail's colours (and again on every theme
  // change); GTK owns the bar's height, dragging, double-click and
  // fullscreen / maximised / tiled states, so there is no strip to report.
  g_autoptr(FlMethodChannel) title_bar_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "app.raft/titlebar", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      title_bar_channel,
      [](FlMethodChannel*, FlMethodCall* call, gpointer data) {
        TitleBar* bar = static_cast<TitleBar*>(data);
        const gchar* method = fl_method_call_get_name(call);
        if (g_strcmp0(method, "status") == 0) {
          g_autoptr(FlValue) state = fl_value_new_map();
          fl_value_set_string_take(state, "height", fl_value_new_float(0));
          fl_value_set_string_take(state, "fullscreen", fl_value_new_bool(FALSE));
          fl_method_call_respond_success(call, state, nullptr);
        } else if (g_strcmp0(method, "setStyle") == 0) {
          FlValue* args = fl_method_call_get_args(call);
          auto integer = [args](const char* key) -> int64_t {
            FlValue* value = fl_value_lookup_string(args, key);
            return value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_INT
                       ? fl_value_get_int(value)
                       : 0;
          };
          FlValue* width = fl_value_lookup_string(args, "ruleWidth");
          title_bar_set_style(
              bar, integer("background"), integer("foreground"), integer("rule"),
              width != nullptr && fl_value_get_type(width) == FL_VALUE_TYPE_FLOAT
                  ? fl_value_get_float(width)
                  : 1);
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
