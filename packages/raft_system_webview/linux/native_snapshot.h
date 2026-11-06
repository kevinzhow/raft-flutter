#ifndef RAFT_SYSTEM_WEBVIEW_NATIVE_SNAPSHOT_H_
#define RAFT_SYSTEM_WEBVIEW_NATIVE_SNAPSHOT_H_
#include <flutter_linux/flutter_linux.h>
#include <webkit2/webkit2.h>
#include <functional>
#include <memory>

class NativeSnapshot : public std::enable_shared_from_this<NativeSnapshot> {
 public:
  NativeSnapshot(WebKitWebView* view, GCancellable* cancel,
    std::function<bool(int64_t)> current) : view_(view), cancel_(cancel), current_(std::move(current)) {}
  void SetViewport(int width, int height) { width_ = width; height_ = height; }
  bool ViewportAllocated() const;
  void Capture(FlMethodCall* call, int64_t sequence);
  void Close() { closed_ = true; current_ = nullptr; }
 private:
  WebKitWebView* view_;
  GCancellable* cancel_;
  std::function<bool(int64_t)> current_;
  int width_ = 0, height_ = 0;
  bool pending_ = false, closed_ = false;
};
#endif
