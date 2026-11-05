#ifndef RAFT_SYSTEM_WEBVIEW_NATIVE_VIEW_H_
#define RAFT_SYSTEM_WEBVIEW_NATIVE_VIEW_H_
#include <webkit2/webkit2.h>
#include <flutter_linux/flutter_linux.h>
#include <memory>
#include <functional>
#include <string>
#include <deque>
#include "native_host.h"
#include "trusted_navigation.h"
#include "native_snapshot.h"
#include "native_region_overlay.h"

class NativeView : public std::enable_shared_from_this<NativeView> {
 public:
  NativeView(int64_t id, NativeHost* host, FlBinaryMessenger* messenger);
  ~NativeView();
  bool ready() const { return web_ != nullptr && clip_ != nullptr; }
  void Bind();
  void Close();
  void SetRetire(std::function<void()> retire) { retire_ = std::move(retire); }
 private:
  static void Method(FlMethodChannel*, FlMethodCall*, gpointer);
  void Handle(FlMethodCall* call);
  void Event(const char* type, FlValue* fields = nullptr);
  void Fail();
  void SetPaintOccluded(bool occluded);
  static gboolean Policy(WebKitWebView*, WebKitPolicyDecision*, WebKitPolicyDecisionType, gpointer);
  static void Loaded(WebKitWebView*, WebKitLoadEvent, gpointer);
  static gboolean Failed(WebKitWebView*, WebKitLoadEvent, gchar*, GError*, gpointer);
  static void Progress(GObject*, GParamSpec*, gpointer);
  static void FocusChanged(GObject*, GParamSpec*, gpointer);
  static gboolean Message(WebKitWebView*, WebKitUserMessage*, gpointer);
  static void AfterInput(GtkWidget*, GdkEvent*, gpointer);
  static gboolean ObserveInput(GtkWidget*, GdkEvent*, gpointer);
  static gboolean TlsFailed(WebKitWebView*, gchar*, GTlsCertificate*, GTlsCertificateFlags, gpointer);
  static void Terminated(WebKitWebView*, WebKitWebProcessTerminationReason, gpointer);
  int64_t id_, sequence_ = 0;
  NativeHost* host_;
  WebKitWebContext* context_ = nullptr;
  WebKitWebView* web_ = nullptr;
  GtkWidget* clip_ = nullptr;
  FlMethodChannel* channel_ = nullptr;
  GCancellable* cancellable_ = nullptr;
  std::string url_, nonce_;
  std::unique_ptr<TrustedNavigation> navigation_;
  std::shared_ptr<NativeSnapshot> snapshot_;
  std::unique_ptr<NativeRegionOverlay> region_;
  struct InputSample {
    std::string type, widget_type;
    guint32 time; int64_t sequence, layout;
    double x, y, root_x, root_y;
    int origin_x, origin_y, device_x, device_y;
    bool web_window;
  };
  std::deque<InputSample> input_samples_;
  int64_t input_sample_sequence_ = 0;
  bool paint_occluded_ = false;
  int pending_evaluations_ = 0;
  GdkRectangle last_frame_{0,0,0,0}, last_clip_{0,0,0,0};
  std::function<void()> retire_;
  bool closed_ = false, initial_ = false, loaded_ = false, failed_ = false, response_ = false;
};
#endif
