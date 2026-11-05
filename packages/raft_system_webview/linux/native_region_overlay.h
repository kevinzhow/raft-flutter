#ifndef RAFT_SYSTEM_WEBVIEW_NATIVE_REGION_OVERLAY_H_
#define RAFT_SYSTEM_WEBVIEW_NATIVE_REGION_OVERLAY_H_
#include <flutter_linux/flutter_linux.h>
#include <functional>
#include <memory>
#include <vector>
#include <array>
#include <string>

class NativeRegionOverlay {
 public:
  explicit NativeRegionOverlay(GtkWidget* web, std::function<void(FlValue*)> input);
  ~NativeRegionOverlay();
  GtkWidget* widget() const { return root_; }
  bool Update(FlValue* value);
  void Clear();
  void Visibility(bool visible);
 private:
  struct Marker { double rect[4], stroke, radius; guint32 fill, border;
    bool dashed; std::vector<std::array<double, 4>> segments; };
  static gboolean Draw(GtkWidget*, cairo_t*, gpointer);
  static gboolean Button(GtkWidget*, GdkEventButton*, gpointer);
  static gboolean Motion(GtkWidget*, GdkEventMotion*, gpointer);
  static gboolean Scroll(GtkWidget*, GdkEventScroll*, gpointer);
  static gboolean GrabBroken(GtkWidget*, GdkEventGrabBroken*, gpointer);
  void Input(const char* phase, double x, double y, double dx=0, double dy=0);
  void Paint(cairo_t* canvas);
  GtkWidget *root_ = nullptr, *capture_ = nullptr, *drawing_ = nullptr;
  GdkPixbuf* hint_ = nullptr;
  std::string hint_sha_;
  std::function<void(FlValue*)> input_;
  int64_t generation_ = 0, sequence_ = 0, input_sequence_ = 0;
  double viewport_[2]{0,0}, hint_size_[2]{0,0}, hint_offset_[2]{0,0};
  bool enabled_ = false, pressed_ = false, visible_ = false;
  std::vector<Marker> markers_;
};
#endif
