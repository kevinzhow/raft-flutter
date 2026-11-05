#ifndef RAFT_SYSTEM_WEBVIEW_NATIVE_VIEW_H_
#define RAFT_SYSTEM_WEBVIEW_NATIVE_VIEW_H_
#include <webkit2/webkit2.h>
#include <flutter_linux/flutter_linux.h>
#include <memory>
#include <functional>
#include <string>
#include "native_host.h"
#include "trusted_navigation.h"
#include "native_snapshot.h"

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
  static gboolean Policy(WebKitWebView*, WebKitPolicyDecision*, WebKitPolicyDecisionType, gpointer);
  static void Loaded(WebKitWebView*, WebKitLoadEvent, gpointer);
  static gboolean Failed(WebKitWebView*, WebKitLoadEvent, gchar*, GError*, gpointer);
  static void Progress(GObject*, GParamSpec*, gpointer);
  static gboolean Message(WebKitWebView*, WebKitUserMessage*, gpointer);
  static void AfterInput(GtkWidget*, GdkEvent*, gpointer);
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
  int pending_evaluations_ = 0;
  std::function<void()> retire_;
  bool closed_ = false, initial_ = false, loaded_ = false, failed_ = false, response_ = false;
};
#endif
