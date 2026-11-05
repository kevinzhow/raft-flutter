#ifndef RAFT_SYSTEM_WEBVIEW_TRUSTED_NAVIGATION_H_
#define RAFT_SYSTEM_WEBVIEW_TRUSTED_NAVIGATION_H_
#include <webkit2/webkit2.h>
#include <functional>
#include <string>

// Native-only association of an actual main-frame DOM click with the matching
// engine navigation. A page receives no callable application bridge.
class TrustedNavigation {
 public:
  using Handoff = std::function<void(const std::string&, const char* authority)>;
  TrustedNavigation(WebKitWebView* view, std::string nonce, std::string document, Handoff handoff);
  ~TrustedNavigation();
  bool Message(WebKitUserMessage* message);
  void Decide(WebKitPolicyDecision* decision, WebKitNavigationAction* action);
 private:
  void Cancel();
  void Complete();
  static gboolean Timeout(gpointer data);
  WebKitWebView* view_;
  std::string nonce_, document_, proof_, requested_;
  Handoff handoff_;
  gint64 proof_at_ = 0;
  guint64 trusted_sequence_ = 0;
  guint timer_ = 0;
  WebKitPolicyDecision* pending_ = nullptr;
};
#endif
