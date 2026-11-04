#ifndef RAFT_IMAGE_CLIPBOARD_H_
#define RAFT_IMAGE_CLIPBOARD_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <cstring>

// GTK owns the original PNG until the selection is replaced. Closing the Dart
// preview must not release it: another process requests the bytes later.
inline void raft_image_clipboard_install(FlView* view) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "app.raft/image-clipboard", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel,
      [](FlMethodChannel*, FlMethodCall* call, gpointer display) {
        if (g_strcmp0(fl_method_call_get_name(call), "copyPng") != 0) {
          fl_method_call_respond_not_implemented(call, nullptr);
          return;
        }
        FlValue* arg = fl_method_call_get_args(call);
        const guint8 signature[] = {137, 80, 78, 71, 13, 10, 26, 10};
        if (arg == nullptr || fl_value_get_type(arg) != FL_VALUE_TYPE_UINT8_LIST ||
            fl_value_get_length(arg) < 33 ||
            fl_value_get_length(arg) > 32 * 1024 * 1024 ||
            memcmp(fl_value_get_uint8_list(arg), signature, sizeof(signature)) != 0) {
          fl_method_call_respond_error(call, "invalid_png", "Invalid PNG image.", nullptr, nullptr);
          return;
        }
        const guint8* data = fl_value_get_uint8_list(arg);
        const gsize size = fl_value_get_length(arg);
        // Reject huge dimensions before decoding; the message export budget is
        // 16M pixels. All preparation precedes selection ownership changes.
        guint32 width = 0, height = 0;
        memcpy(&width, data + 16, 4);
        memcpy(&height, data + 20, 4);
        width = GUINT32_FROM_BE(width);
        height = GUINT32_FROM_BE(height);
        if (width == 0 || height == 0 ||
            static_cast<guint64>(width) * height > 16000000) {
          fl_method_call_respond_error(call, "invalid_png", "Invalid PNG image size.", nullptr, nullptr);
          return;
        }
        g_autoptr(GError) error = nullptr;
        g_autoptr(GdkPixbufLoader) loader = gdk_pixbuf_loader_new_with_type("png", &error);
        const bool written = loader != nullptr && gdk_pixbuf_loader_write(loader, data, size, &error);
        // A write error still requires closing the loader before releasing it.
        const bool closed = loader != nullptr && gdk_pixbuf_loader_close(loader, nullptr);
        if (!written || !closed || gdk_pixbuf_loader_get_pixbuf(loader) == nullptr) {
          fl_method_call_respond_error(call, "invalid_png", "The PNG could not be decoded.", nullptr, nullptr);
          return;
        }
        GtkClipboard* clipboard = gtk_clipboard_get_for_display(GDK_DISPLAY(display), GDK_SELECTION_CLIPBOARD);
        GBytes* bytes = g_bytes_new(data, size);
        GtkTargetEntry target = {const_cast<gchar*>("image/png"), 0, 0};
        const gboolean accepted = gtk_clipboard_set_with_data(
            clipboard, &target, 1,
            [](GtkClipboard*, GtkSelectionData* selection, guint, gpointer stored) {
              gsize length = 0;
              const auto* png = static_cast<const guchar*>(g_bytes_get_data(static_cast<GBytes*>(stored), &length));
              gtk_selection_data_set(selection, gdk_atom_intern_static_string("image/png"), 8,
                                     png, static_cast<gint>(length));
            },
            [](GtkClipboard*, gpointer stored) { g_bytes_unref(static_cast<GBytes*>(stored)); },
            bytes);
        if (!accepted) {
          g_bytes_unref(bytes);
          fl_method_call_respond_error(call, "clipboard_unavailable", "The clipboard did not accept the PNG.", nullptr, nullptr);
          return;
        }
        // Let desktop clipboard managers preserve the PNG on process exit.
        // Do not block the Copy action waiting for an optional manager.
        gtk_clipboard_set_can_store(clipboard, &target, 1);
        g_autoptr(FlValue) success = fl_value_new_bool(TRUE);
        fl_method_call_respond_success(call, success, nullptr);
      }, g_object_ref(gtk_widget_get_display(GTK_WIDGET(view))), g_object_unref);
}

#endif  // RAFT_IMAGE_CLIPBOARD_H_
