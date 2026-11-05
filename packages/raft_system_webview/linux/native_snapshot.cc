#include "native_snapshot.h"
#include <cairo.h>
#include <cstdint>

namespace {
constexpr size_t kMaximumBytes = 8 * 1024 * 1024;
constexpr uint64_t kMaximumPixels = 16 * 1024 * 1024;
void Refuse(FlMethodCall* call, const char* code) {
  g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_error_response_new(code, "The preview snapshot is unavailable.", nullptr));
  fl_method_call_respond(call, response, nullptr);
}
cairo_status_t WritePng(void* context, const unsigned char* data, unsigned int length) {
  auto* bytes = static_cast<GByteArray*>(context);
  if (length > kMaximumBytes || bytes->len > kMaximumBytes - length) return CAIRO_STATUS_WRITE_ERROR;
  g_byte_array_append(bytes, data, length); return CAIRO_STATUS_SUCCESS;
}
}
void NativeSnapshot::Capture(FlMethodCall* call, int64_t sequence) {
  const int64_t scale = gtk_widget_get_scale_factor(GTK_WIDGET(view_));
  const int64_t width = gtk_widget_get_allocated_width(GTK_WIDGET(view_)) * scale;
  const int64_t height = gtk_widget_get_allocated_height(GTK_WIDGET(view_)) * scale;
  if (closed_ || pending_ || !current_ || !current_(sequence) || width <= 0 || height <= 0 ||
      width > 8192 || height > 8192 || static_cast<uint64_t>(width * height) > kMaximumPixels) {
    Refuse(call, "snapshot_unavailable"); return;
  }
  pending_ = true;
  struct Pending { std::weak_ptr<NativeSnapshot> owner; FlMethodCall* call; int64_t sequence; };
  auto* pending = new Pending{weak_from_this(), FL_METHOD_CALL(g_object_ref(call)), sequence};
  webkit_web_view_get_snapshot(view_, WEBKIT_SNAPSHOT_REGION_VISIBLE, WEBKIT_SNAPSHOT_OPTIONS_NONE, cancel_,
    [](GObject* object, GAsyncResult* result, gpointer data) {
      std::unique_ptr<Pending> request(static_cast<Pending*>(data));
      g_autoptr(GError) error = nullptr;
      cairo_surface_t* surface = webkit_web_view_get_snapshot_finish(WEBKIT_WEB_VIEW(object), result, &error);
      auto owner = request->owner.lock();
      if (owner) owner->pending_ = false;
      if (!owner || owner->closed_ || !owner->current_ || !owner->current_(request->sequence) || error ||
          !surface || cairo_surface_status(surface) != CAIRO_STATUS_SUCCESS || cairo_surface_get_type(surface) != CAIRO_SURFACE_TYPE_IMAGE) {
        Refuse(request->call, "snapshot_stale");
      } else {
        const int width = cairo_image_surface_get_width(surface), height = cairo_image_surface_get_height(surface);
        g_autoptr(GByteArray) bytes = g_byte_array_new();
        if (width <= 0 || height <= 0 || width > 8192 || height > 8192 ||
            static_cast<uint64_t>(width) * height > kMaximumPixels ||
            cairo_surface_write_to_png_stream(surface, WritePng, bytes) != CAIRO_STATUS_SUCCESS) {
          Refuse(request->call, "snapshot_too_large");
        } else {
          g_autoptr(FlValue) output = fl_value_new_map();
          fl_value_set_string_take(output, "png", fl_value_new_uint8_list(bytes->data, bytes->len));
          fl_value_set_string_take(output, "width", fl_value_new_int(width));
          fl_value_set_string_take(output, "height", fl_value_new_int(height));
          fl_value_set_string_take(output, "sequence", fl_value_new_int(request->sequence));
          g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(output));
          fl_method_call_respond(request->call, response, nullptr);
        }
      }
      if (surface) cairo_surface_destroy(surface);
      g_object_unref(request->call);
    }, pending);
}
