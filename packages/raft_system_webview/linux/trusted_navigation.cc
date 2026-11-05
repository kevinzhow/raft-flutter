#include "trusted_navigation.h"
#include <cstring>

namespace {
constexpr gint64 kProofMicroseconds = 750000;
constexpr guint kDecisionMilliseconds = 500;
bool Http(const char* value) {
  if (!value || strlen(value) > 8192) return false;
  g_autoptr(GUri) uri = g_uri_parse(value, G_URI_FLAGS_NONE, nullptr);
  const char* scheme = uri ? g_uri_get_scheme(uri) : nullptr;
  return scheme && g_uri_get_host(uri) && !g_uri_get_userinfo(uri) &&
    (!g_strcmp0(scheme, "http") || !g_strcmp0(scheme, "https"));
}
std::string WithoutFragment(const std::string& value) {
  return value.substr(0, value.find('#'));
}
}
TrustedNavigation::TrustedNavigation(WebKitWebView* view, std::string nonce,
  std::string document, Handoff handoff) : view_(view), nonce_(std::move(nonce)),
  document_(std::move(document)), handoff_(std::move(handoff)) {}
TrustedNavigation::~TrustedNavigation() { Cancel(); }
void TrustedNavigation::Cancel() {
  if (timer_) { g_source_remove(timer_); timer_ = 0; }
  if (pending_) {
    webkit_policy_decision_ignore(pending_);
    g_clear_object(&pending_);
  }
  proof_.clear(); requested_.clear(); proof_at_ = 0;
}
gboolean TrustedNavigation::Timeout(gpointer data) {
  auto* self = static_cast<TrustedNavigation*>(data);
  self->timer_ = 0; self->Cancel(); return G_SOURCE_REMOVE;
}
void TrustedNavigation::Complete() {
  if (!pending_ || proof_.empty()) return;
  const bool matched = requested_ == proof_ && proof_at_ > 0 &&
    g_get_monotonic_time() - proof_at_ >= 0 &&
    g_get_monotonic_time() - proof_at_ <= kProofMicroseconds;
  auto requested = requested_;
  WebKitPolicyDecision* decision = pending_; pending_ = nullptr;
  if (matched && WithoutFragment(requested) == WithoutFragment(document_))
    webkit_policy_decision_use(decision);
  else webkit_policy_decision_ignore(decision);
  g_object_unref(decision);
  Cancel();
  // Cancel before handing out the callback: it cannot be replayed by a page
  // script or by reentrant application code after a real click.
  if (matched && WithoutFragment(requested) != WithoutFragment(document_)) handoff_(requested, "matched-native-self-link");
}
bool TrustedNavigation::Message(WebKitUserMessage* message) {
  if (g_strcmp0(webkit_user_message_get_name(message), "raft-attachment-trusted-link-v2")) return false;
  GVariant* value = webkit_user_message_get_parameters(message);
  if (!value || !g_variant_is_of_type(value, G_VARIANT_TYPE("(sttssst)"))) { Cancel(); return true; }
  const char *nonce, *frame_uri, *target, *target_frame; guint64 page, frame, sequence;
  g_variant_get(value, "(&stt&s&s&st)", &nonce, &page, &frame, &frame_uri, &target, &target_frame, &sequence);
  (void)frame;
  if (nonce_ != nonce || page != webkit_web_view_get_page_id(view_) ||
      WithoutFragment(frame_uri) != WithoutFragment(document_) ||
      WithoutFragment(webkit_web_view_get_uri(view_) ? webkit_web_view_get_uri(view_) : "") != WithoutFragment(document_) ||
      !Http(target) || sequence <= trusted_sequence_ ||
      (g_strcmp0(target_frame, "") && g_ascii_strcasecmp(target_frame, "_self") &&
       g_ascii_strcasecmp(target_frame, "_blank"))) { Cancel(); return true; }
  trusted_sequence_ = sequence;
  if (!g_ascii_strcasecmp(target_frame, "_blank")) {
    // sandbox allow-scripts deliberately excludes allow-popups, so WebKit may
    // never produce NEW_WINDOW_ACTION. The private-world native main-frame
    // trusted click is the authority; it already prevented default. No popup
    // or invented navigation action is created to hand the URL to its owner.
    Cancel(); handoff_(target, "trusted-main-frame-blank-click"); return true;
  }
  if (!proof_.empty() && g_get_monotonic_time() - proof_at_ > kProofMicroseconds) {
    proof_.clear(); proof_at_ = 0;
  }
  // A second proof never replaces an outstanding navigation's authority.
  if (!proof_.empty()) { Cancel(); return true; }
  proof_ = target; proof_at_ = g_get_monotonic_time();
  Complete();
  return true;
}
void TrustedNavigation::Decide(WebKitPolicyDecision* decision, WebKitNavigationAction* action) {
  WebKitURIRequest* request = webkit_navigation_action_get_request(action);
  const char* uri = webkit_uri_request_get_uri(request);
  if (!Http(uri) || g_strcmp0(webkit_uri_request_get_http_method(request), "GET") ||
      !webkit_navigation_action_is_user_gesture(action) || webkit_navigation_action_is_redirect(action) ||
      webkit_navigation_action_get_navigation_type(action) != WEBKIT_NAVIGATION_TYPE_LINK_CLICKED || pending_) {
    webkit_policy_decision_ignore(decision); Cancel(); return;
  }
  pending_ = WEBKIT_POLICY_DECISION(g_object_ref(decision)); requested_ = uri;
  if (!proof_.empty()) Complete();
  else timer_ = g_timeout_add(kDecisionMilliseconds, Timeout, this);
}
