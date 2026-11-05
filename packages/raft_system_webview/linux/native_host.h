#ifndef RAFT_SYSTEM_WEBVIEW_NATIVE_HOST_H_
#define RAFT_SYSTEM_WEBVIEW_NATIVE_HOST_H_
#include <flutter_linux/flutter_linux.h>
#include <array>
#include <map>

// The host owns no Flutter business state. It only clips native GTK widgets
// and removes their rectangles from Flutter's own input window, never from the
// application/toplevel window (which would send input to other applications).
class NativeHost {
 public:
  explicit NativeHost(FlView* view);
  ~NativeHost();
  bool available() const { return overlay_ != nullptr; }
  bool HasInputRect(int64_t id) const { return rectangles_.count(id) != 0; }
  bool InputReady() const { return input_ && gtk_widget_get_realized(input_) && gtk_widget_get_has_window(input_); }
  bool Attach(int64_t id, GtkWidget* widget);
  void Layout(int64_t id, GtkWidget* widget, const GdkRectangle& clip, bool visible);
  void Detach(int64_t id, GtkWidget* widget);
 private:
  void UpdateInput();
  static gboolean Position(GtkOverlay*, GtkWidget*, GdkRectangle*, gpointer);
  static void Allocated(GtkWidget*, GdkRectangle*, gpointer);
  GtkWidget* view_ = nullptr;
  GtkOverlay* overlay_ = nullptr;
  GtkWidget* input_ = nullptr;
  std::map<int64_t, GdkRectangle> rectangles_;
};
#endif
