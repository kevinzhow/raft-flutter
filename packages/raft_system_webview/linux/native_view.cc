#include "native_view.h"
#include <libsoup/soup.h>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <map>
#include <set>
#include <sstream>

namespace {
FlValue* Field(FlValue* map, const char* key) {
  return map && fl_value_get_type(map) == FL_VALUE_TYPE_MAP ? fl_value_lookup_string(map, key) : nullptr;
}
const char* String(FlValue* map, const char* key) {
  FlValue* value = Field(map, key);
  return value && fl_value_get_type(value) == FL_VALUE_TYPE_STRING ? fl_value_get_string(value) : nullptr;
}
void Reply(FlMethodCall* call, FlValue* value = nullptr) {
  g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(value));
  fl_method_call_respond(call, response, nullptr);
}
void Error(FlMethodCall* call, const char* code) {
  g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_error_response_new(code, "The system preview request was refused.", nullptr));
  fl_method_call_respond(call, response, nullptr);
}
bool Rect(FlValue* args, const char* key, GdkRectangle* output) {
  FlValue* list = Field(args, key);
  if (!list || fl_value_get_type(list) != FL_VALUE_TYPE_LIST || fl_value_get_length(list) != 4) return false;
  double values[4];
  for (int i = 0; i < 4; i++) {
    FlValue* v = fl_value_get_list_value(list, i);
    FlValueType type = fl_value_get_type(v);
    if (type != FL_VALUE_TYPE_FLOAT && type != FL_VALUE_TYPE_INT) return false;
    values[i] = type == FL_VALUE_TYPE_FLOAT ? fl_value_get_float(v) : fl_value_get_int(v);
    if (!std::isfinite(values[i]) || std::abs(values[i]) > 1000000) return false;
  }
  if (values[2] < 0 || values[3] < 0 || values[2] > 32768 || values[3] > 32768) return false;
  output->x = static_cast<int>(std::ceil(values[0]));
  output->y = static_cast<int>(std::ceil(values[1]));
  output->width = std::max(0, static_cast<int>(std::floor(values[0] + values[2])) - output->x);
  output->height = std::max(0, static_cast<int>(std::floor(values[1] + values[3])) - output->y);
  return true;
}
gboolean DenyPermission(WebKitWebView*, WebKitPermissionRequest* request, gpointer) {
  webkit_permission_request_deny(request); return TRUE;
}
gboolean DenyFile(WebKitWebView*, WebKitFileChooserRequest* request, gpointer) {
  webkit_file_chooser_request_cancel(request); return TRUE;
}
gboolean DenyAuthentication(WebKitWebView*, WebKitAuthenticationRequest* request, gpointer) {
  webkit_authentication_request_cancel(request); return TRUE;
}
gboolean DenyDialog(WebKitWebView*, WebKitScriptDialog* dialog, gpointer) {
  webkit_script_dialog_close(dialog); return TRUE;
}
WebKitWebView* DenyWindow(WebKitWebView*, WebKitNavigationAction*, gpointer) { return nullptr; }
void DenyDownload(WebKitWebContext*, WebKitDownload* download, gpointer) { webkit_download_cancel(download); }
gboolean DenyContext(WebKitWebView*, WebKitContextMenu*, GdkEvent*, WebKitHitTestResult*, gpointer) { return TRUE; }
gboolean DenyTls(WebKitWebView*, gchar*, GTlsCertificate*, GTlsCertificateFlags, gpointer) { return TRUE; }
bool Sandboxed(WebKitURIResponse* response) {
  SoupMessageHeaders* headers = webkit_uri_response_get_http_headers(response);
  const char* csp = headers ? soup_message_headers_get_one(headers, "Content-Security-Policy") : nullptr;
  if (!csp || strlen(csp) > 16384 || webkit_uri_response_get_status_code(response) != 200) return false;
  std::map<std::string, std::string> directives;
  std::istringstream stream(csp); std::string directive;
  while (std::getline(stream, directive, ';')) {
    std::istringstream words(directive); std::string key, word, value;
    if (!(words >> key)) continue;
    for (char& c : key) c = g_ascii_tolower(c);
    while (words >> word) {
      for (char& c : word) c = g_ascii_tolower(c);
      if (!value.empty()) value += " ";
      value += word;
    }
    if (!directives.emplace(key, value).second) return false;
  }
  if (directives["sandbox"] != "allow-scripts") return false;
  for (const char* key : {"default-src", "connect-src", "object-src", "base-uri", "form-action", "worker-src"})
    if (directives[key] != "'none'") return false;
  return true;
}
}

NativeView::NativeView(int64_t id, NativeHost* host, FlBinaryMessenger* messenger) : id_(id), host_(host) {
  if (!host->available() || g_getenv("WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS")) return;
  context_ = webkit_web_context_new_ephemeral();
  webkit_web_context_set_sandbox_enabled(context_, TRUE);
  if (!webkit_web_context_get_sandbox_enabled(context_)) return;
  // A new manager contains no application script-message handlers or scripts.
  g_autoptr(WebKitUserContentManager) manager = webkit_user_content_manager_new();
  web_ = WEBKIT_WEB_VIEW(g_object_new(WEBKIT_TYPE_WEB_VIEW, "web-context", context_, "user-content-manager", manager, nullptr));
  g_object_ref_sink(web_);
  WebKitSettings* settings = webkit_web_view_get_settings(web_);
  g_object_set(settings, "enable-javascript", TRUE,
    "enable-developer-extras", FALSE, "enable-html5-database", FALSE,
    "enable-html5-local-storage", FALSE, "enable-page-cache", FALSE,
    "allow-file-access-from-file-urls", FALSE,
    "allow-universal-access-from-file-urls", FALSE,
    "javascript-can-open-windows-automatically", FALSE,
    "media-playback-requires-user-gesture", TRUE, nullptr);
  webkit_cookie_manager_set_accept_policy(webkit_web_context_get_cookie_manager(context_), WEBKIT_COOKIE_POLICY_ACCEPT_NEVER);
  clip_ = gtk_layout_new(nullptr, nullptr);
  g_object_ref_sink(clip_);
  gtk_layout_put(GTK_LAYOUT(clip_), GTK_WIDGET(web_), 0, 0);
  gtk_widget_show(GTK_WIDGET(web_));
  if (!host_->Attach(id_, clip_)) { gtk_widget_destroy(clip_); g_clear_object(&clip_); return; }
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  std::string name = "app.raft/system_webview/" + std::to_string(id);
  channel_ = fl_method_channel_new(messenger, name.c_str(), FL_METHOD_CODEC(codec));
  cancellable_ = g_cancellable_new();
  g_signal_connect(web_, "decide-policy", G_CALLBACK(Policy), this);
  g_signal_connect(web_, "load-changed", G_CALLBACK(Loaded), this);
  g_signal_connect(web_, "load-failed", G_CALLBACK(Failed), this);
  g_signal_connect(web_, "notify::estimated-load-progress", G_CALLBACK(Progress), this);
  g_signal_connect(web_, "permission-request", G_CALLBACK(DenyPermission), this);
  g_signal_connect(web_, "run-file-chooser", G_CALLBACK(DenyFile), this);
  g_signal_connect(web_, "authenticate", G_CALLBACK(DenyAuthentication), this);
  g_signal_connect(web_, "script-dialog", G_CALLBACK(DenyDialog), this);
  g_signal_connect(web_, "create", G_CALLBACK(DenyWindow), this);
  g_signal_connect(web_, "context-menu", G_CALLBACK(DenyContext), this);
  g_signal_connect(web_, "load-failed-with-tls-errors", G_CALLBACK(DenyTls), this);
  g_signal_connect(context_, "download-started", G_CALLBACK(DenyDownload), this);
}
NativeView::~NativeView() { Close(); }
void NativeView::Bind() {
  auto* weak = new std::weak_ptr<NativeView>(shared_from_this());
  fl_method_channel_set_method_call_handler(channel_, Method, weak,
    [](gpointer data) { delete static_cast<std::weak_ptr<NativeView>*>(data); });
}
void NativeView::Close() {
  if (closed_) return;
  closed_ = true;
  if (cancellable_) g_cancellable_cancel(cancellable_);
  if (web_) {
    g_signal_handlers_disconnect_by_data(web_, this);
    webkit_web_view_stop_loading(web_);
  }
  if (context_) g_signal_handlers_disconnect_by_data(context_, this);
  if (clip_) { host_->Detach(id_, clip_); gtk_widget_destroy(clip_); }
  g_clear_object(&clip_);
  g_clear_object(&web_);
  g_clear_object(&context_);
  if (channel_) fl_method_channel_set_method_call_handler(channel_, nullptr, nullptr, nullptr);
  g_clear_object(&channel_);
  g_clear_object(&cancellable_);
  if (retire_) { auto retire = std::move(retire_); retire(); }
}
void NativeView::Method(FlMethodChannel*, FlMethodCall* call, gpointer data) {
  auto view = static_cast<std::weak_ptr<NativeView>*>(data)->lock();
  if (!view || view->closed_) { Error(call, "closed"); return; }
  view->Handle(call);
}
void NativeView::Handle(FlMethodCall* call) {
  const char* method = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);
  if (g_str_equal(method, "dispose")) { Reply(call); Close(); return; }
  if (g_str_equal(method, "load")) {
    const char* url = String(args, "url");
    g_autoptr(GUri) parsed = url ? g_uri_parse(url, G_URI_FLAGS_NONE, nullptr) : nullptr;
    const char* scheme = parsed ? g_uri_get_scheme(parsed) : nullptr;
    if (!url_.empty() || !scheme || (g_strcmp0(scheme, "https") && g_strcmp0(scheme, "http")) ||
        !g_uri_get_host(parsed) || g_uri_get_userinfo(parsed) || g_uri_get_fragment(parsed)) {
      Error(call, "invalid_url"); return;
    }
    url_ = url; initial_ = true;
    webkit_web_view_load_uri(web_, url);
    Reply(call); return;
  }
  if (g_str_equal(method, "layout")) {
    FlValue* serial = Field(args, "sequence");
    FlValue* visible = Field(args, "visible");
    GdkRectangle frame, clip;
    if (!serial || fl_value_get_type(serial) != FL_VALUE_TYPE_INT ||
        fl_value_get_int(serial) <= sequence_ || !visible || fl_value_get_type(visible) != FL_VALUE_TYPE_BOOL ||
        !Rect(args, "frame", &frame) || !Rect(args, "clip", &clip)) {
      host_->Layout(id_, clip_, {0, 0, 0, 0}, false);
      Error(call, "invalid_layout"); return;
    }
    sequence_ = fl_value_get_int(serial);
    GdkRectangle intersection;
    bool show = loaded_ && fl_value_get_bool(visible) &&
      gdk_rectangle_intersect(&frame, &clip, &intersection);
    if (show) {
      gtk_widget_set_size_request(GTK_WIDGET(web_), frame.width, frame.height);
      gtk_layout_move(GTK_LAYOUT(clip_), GTK_WIDGET(web_), frame.x - intersection.x, frame.y - intersection.y);
      gtk_layout_set_size(GTK_LAYOUT(clip_), intersection.width, intersection.height);
    }
    host_->Layout(id_, clip_, show ? intersection : GdkRectangle{0, 0, 0, 0}, show);
    Reply(call); return;
  }
  if (g_str_equal(method, "currentUri")) {
    g_autoptr(FlValue) uri = fl_value_new_string(webkit_web_view_get_uri(web_) ? webkit_web_view_get_uri(web_) : "");
    Reply(call, uri); return;
  }
  if (g_str_equal(method, "evaluate")) {
    const char* source = String(args, "source");
    if (!loaded_ || !source || strlen(source) > 65536) { Error(call, "invalid_evaluation"); return; }
    struct Pending { std::weak_ptr<NativeView> view; FlMethodCall* call; };
    auto* pending = new Pending{weak_from_this(), FL_METHOD_CALL(g_object_ref(call))};
    webkit_web_view_evaluate_javascript(web_, source, -1, nullptr, nullptr, cancellable_,
      [](GObject* object, GAsyncResult* result, gpointer data) {
        std::unique_ptr<Pending> pending(static_cast<Pending*>(data));
        g_autoptr(GError) error = nullptr;
        g_autoptr(JSCValue) value = webkit_web_view_evaluate_javascript_finish(WEBKIT_WEB_VIEW(object), result, &error);
        auto owner = pending->view.lock();
        if (!owner || owner->closed_ || error) Error(pending->call, "evaluation_failed");
        else {
          g_autofree char* text = jsc_value_is_string(value) ? jsc_value_to_string(value) : jsc_value_to_json(value, 0);
          if (!text || strlen(text) > 16384) Error(pending->call, "invalid_result");
          else { g_autoptr(FlValue) output = fl_value_new_string(text); Reply(pending->call, output); }
        }
        g_object_unref(pending->call);
      }, pending);
    return;
  }
  Error(call, "unsupported_method");
}
void NativeView::Event(const char* type, FlValue* fields) {
  if (closed_ || !channel_) return;
  g_autoptr(FlValue) event = fields ? fl_value_ref(fields) : fl_value_new_map();
  fl_value_set_string_take(event, "type", fl_value_new_string(type));
  fl_method_channel_invoke_method(channel_, "event", event, nullptr, nullptr, nullptr);
}
gboolean NativeView::Policy(WebKitWebView*, WebKitPolicyDecision* decision, WebKitPolicyDecisionType type, gpointer data) {
  auto* self = static_cast<NativeView*>(data);
  if (type == WEBKIT_POLICY_DECISION_TYPE_NAVIGATION_ACTION) {
    WebKitNavigationAction* action = webkit_navigation_policy_decision_get_navigation_action(WEBKIT_NAVIGATION_POLICY_DECISION(decision));
    WebKitURIRequest* request = webkit_navigation_action_get_request(action);
    const char* uri = webkit_uri_request_get_uri(request);
    const char* method = webkit_uri_request_get_http_method(request);
    // The first exact URI is an app-owned load before any document executes.
    // GTK 2.52 does not expose target frame info. Do not invent isMainFrame:
    // every later navigation, including script/redirect/new-window, is denied.
    bool initial = self->initial_ && !self->closed_ && g_strcmp0(uri, self->url_.c_str()) == 0 &&
      g_strcmp0(method, "GET") == 0 && !webkit_navigation_action_is_redirect(action);
    self->initial_ = false;
    if (initial) webkit_policy_decision_use(decision);
    else webkit_policy_decision_ignore(decision);
    return TRUE;
  }
  if (type == WEBKIT_POLICY_DECISION_TYPE_RESPONSE) {
    auto* response = WEBKIT_RESPONSE_POLICY_DECISION(decision);
    WebKitURIRequest* request = webkit_response_policy_decision_get_request(response);
    if (webkit_response_policy_decision_is_main_frame_main_resource(response) &&
        g_strcmp0(webkit_uri_request_get_uri(request), self->url_.c_str()) == 0 &&
        webkit_response_policy_decision_is_mime_type_supported(response) &&
        Sandboxed(webkit_response_policy_decision_get_response(response))) {
      self->response_ = true;
      webkit_policy_decision_use(decision);
    } else {
      self->failed_ = true;
      webkit_policy_decision_ignore(decision);
      self->Event("failed");
    }
    return TRUE;
  }
  webkit_policy_decision_ignore(decision); return TRUE;
}
void NativeView::Loaded(WebKitWebView*, WebKitLoadEvent event, gpointer data) {
  auto* self = static_cast<NativeView*>(data);
  if (event == WEBKIT_LOAD_FINISHED && !self->loaded_ && !self->failed_ && self->response_ &&
      g_strcmp0(webkit_web_view_get_uri(self->web_), self->url_.c_str()) == 0) {
    self->loaded_ = true; self->Event("loaded");
  }
}
gboolean NativeView::Failed(WebKitWebView*, WebKitLoadEvent, gchar* uri, GError* error, gpointer data) {
  auto* self = static_cast<NativeView*>(data);
  if (!self->loaded_ && g_strcmp0(uri, self->url_.c_str()) == 0 &&
      !(error->domain == WEBKIT_NETWORK_ERROR && error->code == WEBKIT_NETWORK_ERROR_CANCELLED)) {
    self->failed_ = true; self->Event("failed");
  }
  return TRUE;
}
void NativeView::Progress(GObject*, GParamSpec*, gpointer data) {
  auto* self = static_cast<NativeView*>(data);
  g_autoptr(FlValue) fields = fl_value_new_map();
  fl_value_set_string_take(fields, "percent", fl_value_new_int(std::lround(webkit_web_view_get_estimated_load_progress(self->web_) * 100)));
  self->Event("progress", fields);
}
