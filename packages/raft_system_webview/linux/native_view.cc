#include "native_view.h"
#include "extension_paths.h"
#include <dlfcn.h>
#include <libsoup/soup.h>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <map>
#include <optional>
#include <set>
#include <sstream>

struct _WebKitFrameInfo;

namespace {
std::optional<bool> BrowserSubframe(WebKitNavigationAction* action) {
  using TargetFrame = _WebKitFrameInfo* (*)(WebKitNavigationAction*);
  using IsMain = gboolean (*)(_WebKitFrameInfo*);
  static const auto target_frame = reinterpret_cast<TargetFrame>(
      dlsym(RTLD_DEFAULT, "webkit_navigation_action_get_target_frame_info"));
  static const auto is_main = reinterpret_cast<IsMain>(
      dlsym(RTLD_DEFAULT, "webkit_frame_info_is_main_frame"));
  if (!target_frame || !is_main) return std::nullopt;
  auto* target = target_frame(action);
  return target && !is_main(target);
}

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
gboolean DenyContext(WebKitWebView*, WebKitContextMenu*, GdkEvent*, WebKitHitTestResult*, gpointer) { return TRUE; }
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

NativeView::NativeView(int64_t id, NativeHost* host, FlBinaryMessenger* messenger,
                       WebKitWebContext* browser_context, std::set<std::string> blocked_hosts)
    : id_(id), host_(host), browsing_(browser_context != nullptr),
      blocked_hosts_(std::move(blocked_hosts)) {
  if (!host->available() || g_getenv("WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS")) return;
  if (browsing_) {
    context_ = WEBKIT_WEB_CONTEXT(g_object_ref(browser_context));
  } else {
    const auto extension_directory = RaftWebviewExtensionDirectory();
    if (extension_directory.empty()) return;
    g_autofree char* nonce = g_uuid_string_random();
    nonce_ = nonce;
    context_ = webkit_web_context_new_ephemeral();
    webkit_web_context_set_web_extensions_directory(context_, extension_directory.c_str());
    webkit_web_context_set_web_extensions_initialization_user_data(context_, g_variant_new_string(nonce_.c_str()));
    webkit_web_context_add_path_to_sandbox(context_, extension_directory.c_str(), TRUE);
    webkit_web_context_set_sandbox_enabled(context_, TRUE);
  }
  if (!webkit_web_context_get_sandbox_enabled(context_)) return;
  // A new manager contains no application script-message handlers or scripts.
  g_autoptr(WebKitUserContentManager) manager = webkit_user_content_manager_new();
  web_ = WEBKIT_WEB_VIEW(g_object_new(WEBKIT_TYPE_WEB_VIEW, "web-context", context_, "user-content-manager", manager, nullptr));
  g_object_ref_sink(web_);
  WebKitSettings* settings = webkit_web_view_get_settings(web_);
  g_object_set(settings, "enable-javascript", TRUE,
    "enable-developer-extras", FALSE, "enable-html5-database", FALSE,
    "enable-html5-local-storage", browsing_, "enable-page-cache", browsing_,
    "allow-file-access-from-file-urls", FALSE,
    "allow-universal-access-from-file-urls", FALSE,
    "javascript-can-open-windows-automatically", FALSE,
    "media-playback-requires-user-gesture", TRUE, nullptr);
  if (!browsing_) {
    webkit_cookie_manager_set_accept_policy(webkit_web_context_get_cookie_manager(context_), WEBKIT_COOKIE_POLICY_ACCEPT_NEVER);
  }
  clip_ = gtk_layout_new(nullptr, nullptr);
  g_object_ref_sink(clip_);
  region_ = std::make_unique<NativeRegionOverlay>(GTK_WIDGET(web_), [this](FlValue* fields) {
    if (!closed_ && loaded_ && !failed_) Event("regionInput", fields);
  });
  gtk_layout_put(GTK_LAYOUT(clip_), region_->widget(), 0, 0);
  gtk_widget_show(region_->widget());
  gtk_widget_show(GTK_WIDGET(web_));
  if (!host_->Attach(id_, clip_)) { gtk_widget_destroy(clip_); g_clear_object(&clip_); return; }
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  std::string name = "app.raft/system_webview/" + std::to_string(id);
  channel_ = fl_method_channel_new(messenger, name.c_str(), FL_METHOD_CODEC(codec));
  cancellable_ = g_cancellable_new();
  snapshot_ = std::make_shared<NativeSnapshot>(web_, cancellable_, [this](int64_t sequence) {
    return !closed_ && loaded_ && !failed_ && sequence_ == sequence;
  });
  g_signal_connect(web_, "decide-policy", G_CALLBACK(Policy), this);
  g_signal_connect(web_, "user-message-received", G_CALLBACK(Message), this);
  g_signal_connect(web_, "event-after", G_CALLBACK(AfterInput), this);
  g_signal_connect(web_, "event", G_CALLBACK(ObserveInput), this);
  g_signal_connect(web_, "notify::has-focus", G_CALLBACK(FocusChanged), this);
  g_signal_connect_after(web_, "size-allocate", G_CALLBACK(Allocated), this);
  g_signal_connect(web_, "load-changed", G_CALLBACK(Loaded), this);
  g_signal_connect(web_, "load-failed", G_CALLBACK(Failed), this);
  g_signal_connect(web_, "notify::estimated-load-progress", G_CALLBACK(Progress), this);
  g_signal_connect(web_, "permission-request", G_CALLBACK(DenyPermission), this);
  g_signal_connect(web_, "run-file-chooser", G_CALLBACK(DenyFile), this);
  g_signal_connect(web_, "authenticate", G_CALLBACK(DenyAuthentication), this);
  g_signal_connect(web_, "script-dialog", G_CALLBACK(DenyDialog), this);
  g_signal_connect(web_, "create", G_CALLBACK(CreateWindow), this);
  g_signal_connect(web_, "context-menu", G_CALLBACK(DenyContext), this);
  g_signal_connect(web_, "load-failed-with-tls-errors", G_CALLBACK(TlsFailed), this);
  g_signal_connect(web_, "web-process-terminated", G_CALLBACK(Terminated), this);
  g_signal_connect(context_, "download-started", G_CALLBACK(BrowserDownload), this);
  if (browsing_) {
    g_signal_connect(web_, "key-press-event", G_CALLBACK(BrowserKeys), this);
    for (const char* signal : {"notify::uri", "notify::title", "notify::is-loading"}) {
      g_signal_connect(web_, signal, G_CALLBACK(+[](GObject*, GParamSpec*, gpointer data) {
        static_cast<NativeView*>(data)->BrowserState();
      }), this);
    }
  }
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
  SetPaintOccluded(false);
  if (cancellable_) g_cancellable_cancel(cancellable_);
  navigation_.reset();
  if (snapshot_) snapshot_->Close();
  snapshot_.reset();
  if (web_) {
    g_signal_handlers_disconnect_by_data(web_, this);
    webkit_web_view_stop_loading(web_);
  }
  if (context_) g_signal_handlers_disconnect_by_data(context_, this);
  region_.reset();
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
  if (browsing_) {
    if (g_str_equal(method, "load")) {
      const char* address = String(args, "url");
      if (!BrowserAddress(address)) { Error(call, "invalid_url"); return; }
      webkit_web_view_load_uri(web_, address);
      Reply(call); return;
    }
    if (g_str_equal(method, "back")) {
      webkit_web_view_go_back(web_);
      Reply(call); return;
    }
    if (g_str_equal(method, "forward")) {
      webkit_web_view_go_forward(web_);
      Reply(call); return;
    }
    if (g_str_equal(method, "reload")) {
      if (failed_ && BrowserAddress(browser_retry_.c_str())) {
        const std::string retry = browser_retry_;
        webkit_web_view_load_uri(web_, retry.c_str());
      } else {
        webkit_web_view_reload(web_);
      }
      Reply(call); return;
    }
    if (g_str_equal(method, "evaluate") || g_str_equal(method, "regionOverlay")) {
      Error(call, "unsupported_method"); return;
    }
  }
  if (g_str_equal(method, "load")) {
    const char* url = String(args, "url");
    g_autoptr(GUri) parsed = url ? g_uri_parse(url, G_URI_FLAGS_NONE, nullptr) : nullptr;
    const char* scheme = parsed ? g_uri_get_scheme(parsed) : nullptr;
    if (!url_.empty() || !scheme || (g_strcmp0(scheme, "https") && g_strcmp0(scheme, "http")) ||
        !g_uri_get_host(parsed) || g_uri_get_userinfo(parsed) || g_uri_get_fragment(parsed)) {
      Error(call, "invalid_url"); return;
    }
    url_ = url; initial_ = true;
    navigation_ = std::make_unique<TrustedNavigation>(web_, nonce_, url_, [this](const std::string& link, const char* authority) {
      if (closed_ || !loaded_ || failed_) return;
      g_autoptr(FlValue) fields = fl_value_new_map();
      fl_value_set_string_take(fields, "url", fl_value_new_string(link.c_str()));
      fl_value_set_string_take(fields, "authority", fl_value_new_string(authority));
      Event("navigation", fields);
    });
    webkit_web_view_load_uri(web_, url);
    Reply(call); return;
  }
  if (g_str_equal(method, "layout")) {
    FlValue* serial = Field(args, "sequence");
    FlValue* visible = Field(args, "visible");
    FlValue* paint_occluded = Field(args, "paintOccluded");
    GdkRectangle frame, clip;
    if (!serial || fl_value_get_type(serial) != FL_VALUE_TYPE_INT ||
        fl_value_get_int(serial) <= sequence_ || !visible || fl_value_get_type(visible) != FL_VALUE_TYPE_BOOL ||
        (paint_occluded && fl_value_get_type(paint_occluded) != FL_VALUE_TYPE_BOOL) ||
        !Rect(args, "frame", &frame) || !Rect(args, "clip", &clip)) {
      if (region_) region_->Visibility(false);
      SetPaintOccluded(false);
      last_clip_ = {0,0,0,0};
      host_->Layout(id_, clip_, {0, 0, 0, 0}, false);
      Error(call, "invalid_layout"); return;
    }
    sequence_ = fl_value_get_int(serial);
    GdkRectangle intersection;
    bool show = (browsing_ || loaded_) && fl_value_get_bool(visible) &&
      gdk_rectangle_intersect(&frame, &clip, &intersection);
    if (frame.width > 0 && frame.height > 0) snapshot_->SetViewport(frame.width, frame.height);
    if (show) {
      gtk_widget_set_size_request(region_->widget(), frame.width, frame.height);
      gtk_layout_move(GTK_LAYOUT(clip_), region_->widget(), frame.x - intersection.x, frame.y - intersection.y);
      gtk_layout_set_size(GTK_LAYOUT(clip_), intersection.width, intersection.height);
    }
    SetPaintOccluded(show && paint_occluded && fl_value_get_bool(paint_occluded));
    last_frame_ = frame;
    last_clip_ = show ? intersection : GdkRectangle{0,0,0,0};
    if (region_) region_->Visibility(show);
    host_->Layout(id_, clip_, show ? intersection : GdkRectangle{0, 0, 0, 0}, show);
    Reply(call); return;
  }
  if (g_str_equal(method, "regionOverlay")) {
    if (!region_ || !region_->Update(args)) {
      if (region_) region_->Clear();
      Error(call, "invalid_overlay");
    } else Reply(call);
    return;
  }
  if (g_str_equal(method, "snapshot")) {
    if (snapshot_) snapshot_->Capture(call, sequence_);
    else Error(call, "snapshot_unavailable");
    return;
  }
  if (g_str_equal(method, "inspect")) {
    g_autoptr(FlValue) state = fl_value_new_map();
    fl_value_set_string_take(state, "id", fl_value_new_int(id_));
    fl_value_set_string_take(state, "loaded", fl_value_new_bool(loaded_));
    g_autoptr(FlValue) inputs = fl_value_new_list();
    for (const auto& sample : input_samples_) {
      FlValue* row = fl_value_new_map();
      fl_value_set_string_take(row,"type",fl_value_new_string(sample.type.c_str()));
      fl_value_set_string_take(row,"time",fl_value_new_int(sample.time));
      fl_value_set_string_take(row,"sequence",fl_value_new_int(sample.sequence));
      fl_value_set_string_take(row,"layoutSequence",fl_value_new_int(sample.layout));
      fl_value_set_string_take(row,"x",fl_value_new_float(sample.x));
      fl_value_set_string_take(row,"y",fl_value_new_float(sample.y));
      fl_value_set_string_take(row,"rootX",fl_value_new_float(sample.root_x));
      fl_value_set_string_take(row,"rootY",fl_value_new_float(sample.root_y));
      fl_value_set_string_take(row,"windowOriginX",fl_value_new_int(sample.origin_x));
      fl_value_set_string_take(row,"windowOriginY",fl_value_new_int(sample.origin_y));
      fl_value_set_string_take(row,"deviceNowX",fl_value_new_int(sample.device_x));
      fl_value_set_string_take(row,"deviceNowY",fl_value_new_int(sample.device_y));
      fl_value_set_string_take(row,"isWebViewWindow",fl_value_new_bool(sample.web_window));
      fl_value_set_string_take(row,"eventWidgetType",fl_value_new_string(sample.widget_type.c_str()));
      fl_value_append_take(inputs,row);
    }
    fl_value_set_string_take(state,"recentInput",g_steal_pointer(&inputs));
    fl_value_set_string_take(state, "layoutSequence", fl_value_new_int(sequence_));
    auto rect=[](const GdkRectangle& r) {
      FlValue* values=fl_value_new_list();
      for(int value:{r.x,r.y,r.width,r.height})fl_value_append_take(values,fl_value_new_int(value));
      return values;
    };
    fl_value_set_string_take(state, "frame", rect(last_frame_));
    fl_value_set_string_take(state, "clip", rect(last_clip_));
    fl_value_set_string_take(state, "inputRectActive", fl_value_new_bool(host_->HasInputRect(id_)));
    fl_value_set_string_take(state, "flutterInputReady", fl_value_new_bool(host_->InputReady()));
    fl_value_set_string_take(state, "nativeAllocation", rect({0,0,gtk_widget_get_allocated_width(GTK_WIDGET(web_)),gtk_widget_get_allocated_height(GTK_WIDGET(web_))}));
    fl_value_set_string_take(state, "visible", fl_value_new_bool(gtk_widget_get_visible(clip_)));
    fl_value_set_string_take(state, "paintOccluded", fl_value_new_bool(paint_occluded_));
    fl_value_set_string_take(state, "opacity", fl_value_new_float(gtk_widget_get_opacity(clip_)));
    fl_value_set_string_take(state, "mapped", fl_value_new_bool(gtk_widget_get_mapped(clip_)));
    fl_value_set_string_take(state, "focused", fl_value_new_bool(gtk_widget_has_focus(GTK_WIDGET(web_))));
    fl_value_set_string_take(state, "gtkFocus", host_->FocusState());
    fl_value_set_string_take(state, "ephemeral", fl_value_new_bool(webkit_web_context_is_ephemeral(context_)));
    fl_value_set_string_take(state, "sandboxed", fl_value_new_bool(webkit_web_context_get_sandbox_enabled(context_)));
    WebKitWebsiteDataManager* manager = webkit_web_context_get_website_data_manager(context_);
    fl_value_set_string_take(state, "persistentDataDirectory", fl_value_new_bool(webkit_website_data_manager_get_base_data_directory(manager) != nullptr));
    fl_value_set_string_take(state, "persistentCacheDirectory", fl_value_new_bool(webkit_website_data_manager_get_base_cache_directory(manager) != nullptr));
    Reply(call, state); return;
  }
  if (g_str_equal(method, "currentUri")) {
    g_autoptr(FlValue) uri = fl_value_new_string(webkit_web_view_get_uri(web_) ? webkit_web_view_get_uri(web_) : "");
    Reply(call, uri); return;
  }
  if (g_str_equal(method, "evaluate")) {
    const char* source = String(args, "source");
    if (!loaded_ || pending_evaluations_ >= 2 || !source || strlen(source) > 65536) { Error(call, "invalid_evaluation"); return; }
    struct Pending { std::weak_ptr<NativeView> view; FlMethodCall* call; };
    auto* pending = new Pending{weak_from_this(), FL_METHOD_CALL(g_object_ref(call))};
    pending_evaluations_++;
    webkit_web_view_evaluate_javascript(web_, source, -1, nullptr, nullptr, cancellable_,
      [](GObject* object, GAsyncResult* result, gpointer data) {
        std::unique_ptr<Pending> pending(static_cast<Pending*>(data));
        g_autoptr(GError) error = nullptr;
        g_autoptr(JSCValue) value = webkit_web_view_evaluate_javascript_finish(WEBKIT_WEB_VIEW(object), result, &error);
        auto owner = pending->view.lock();
        if (owner) owner->pending_evaluations_--;
        if (!owner || owner->closed_ || error || !value) Error(pending->call, "evaluation_failed");
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
bool NativeView::BrowserAddress(const char* url) const {
  g_autoptr(GUri) parsed = url ? g_uri_parse(url, G_URI_FLAGS_NONE, nullptr) : nullptr;
  if (!parsed || g_uri_get_userinfo(parsed)) return false;
  const char* protocol = g_uri_get_scheme(parsed);
  const char* host = g_uri_get_host(parsed);
  if (!host || !*host || (g_strcmp0(protocol, "http") && g_strcmp0(protocol, "https"))) return false;
  g_autofree char* lowercase = g_ascii_strdown(host, -1);
  std::string name(lowercase);
  while (!name.empty() && name.back() == '.') name.pop_back();
  return !name.empty() && blocked_hosts_.count(name) == 0;
}
void NativeView::BrowserState() {
  if (closed_) return;
  g_autoptr(FlValue) fields = fl_value_new_map();
  const char* address = webkit_web_view_get_uri(web_);
  const char* title = webkit_web_view_get_title(web_);
  if (BrowserAddress(address)) fl_value_set_string_take(fields, "url", fl_value_new_string(address));
  fl_value_set_string_take(fields, "title", fl_value_new_string(title ? title : ""));
  fl_value_set_string_take(fields, "back", fl_value_new_bool(webkit_web_view_can_go_back(web_)));
  fl_value_set_string_take(fields, "forward", fl_value_new_bool(webkit_web_view_can_go_forward(web_)));
  fl_value_set_string_take(fields, "loading", fl_value_new_bool(webkit_web_view_is_loading(web_)));
  Event("browserState", fields);
}
gboolean NativeView::BrowserKeys(GtkWidget*, GdkEventKey* event, gpointer data) {
  auto* self = static_cast<NativeView*>(data);
  const auto modifiers = event->state & gtk_accelerator_get_default_mod_mask();
  if (event->keyval == GDK_KEY_Escape && modifiers == 0) {
    self->Event("closePanel");
    return TRUE;
  }
  constexpr guint kPhysicalW = 25;
  if (event->hardware_keycode != kPhysicalW || modifiers != GDK_CONTROL_MASK) return FALSE;
  self->Event("closeTab");
  return TRUE;
}
void NativeView::OpenBrowserExternal(const char* address) {
  if (!BrowserAddress(address)) return;
  g_autoptr(FlValue) fields = fl_value_new_map();
  fl_value_set_string_take(fields, "url", fl_value_new_string(address));
  Event("openExternal", fields);
}
WebKitWebView* NativeView::CreateWindow(WebKitWebView*, WebKitNavigationAction* action, gpointer data) {
  auto* self = static_cast<NativeView*>(data);
  if (self->browsing_ && webkit_navigation_action_is_user_gesture(action)) {
    self->OpenBrowserExternal(webkit_uri_request_get_uri(webkit_navigation_action_get_request(action)));
  }
  return nullptr;
}
void NativeView::BrowserDownload(WebKitWebContext*, WebKitDownload* download, gpointer data) {
  auto* self = static_cast<NativeView*>(data);
  if (self->browsing_) {
    auto* owner = webkit_download_get_web_view(download);
    if (owner && owner != self->web_) return;
    if (owner) {
      self->OpenBrowserExternal(webkit_uri_request_get_uri(webkit_download_get_request(download)));
    }
  }
  webkit_download_cancel(download);
}
gboolean NativeView::Policy(WebKitWebView*, WebKitPolicyDecision* decision, WebKitPolicyDecisionType type, gpointer data) {
  auto* self = static_cast<NativeView*>(data);
  if (self->browsing_) {
    if (type == WEBKIT_POLICY_DECISION_TYPE_RESPONSE) {
      auto* response = WEBKIT_RESPONSE_POLICY_DECISION(decision);
      if (!webkit_response_policy_decision_is_main_frame_main_resource(response)) return FALSE;
      const char* address = webkit_uri_request_get_uri(webkit_response_policy_decision_get_request(response));
      if (self->BrowserAddress(address)) {
        auto* headers = webkit_uri_response_get_http_headers(webkit_response_policy_decision_get_response(response));
        g_autofree char* disposition = nullptr;
        if (headers) soup_message_headers_get_content_disposition(headers, &disposition, nullptr);
        if (webkit_response_policy_decision_is_mime_type_supported(response) &&
            (!disposition || g_ascii_strcasecmp(disposition, "attachment") != 0)) return FALSE;
        self->OpenBrowserExternal(address);
      }
      webkit_policy_decision_ignore(decision);
      return TRUE;
    }
    auto* action = webkit_navigation_policy_decision_get_navigation_action(WEBKIT_NAVIGATION_POLICY_DECISION(decision));
    const char* address = webkit_uri_request_get_uri(webkit_navigation_action_get_request(action));
    if (type == WEBKIT_POLICY_DECISION_TYPE_NAVIGATION_ACTION) {
      const auto subframe = BrowserSubframe(action);
      const bool local_document = address &&
          (g_str_equal(address, "about:blank") || g_str_equal(address, "about:srcdoc") ||
           g_str_has_prefix(address, "blob:") || g_str_has_prefix(address, "data:"));
      if (self->BrowserAddress(address) || subframe.value_or(local_document)) {
        webkit_policy_decision_use(decision);
        return TRUE;
      }
    } else if (webkit_navigation_action_is_user_gesture(action)) {
      self->OpenBrowserExternal(address);
    }
    webkit_policy_decision_ignore(decision);
    return TRUE;
  }
  if (type == WEBKIT_POLICY_DECISION_TYPE_NAVIGATION_ACTION) {
    WebKitNavigationAction* action = webkit_navigation_policy_decision_get_navigation_action(WEBKIT_NAVIGATION_POLICY_DECISION(decision));
    WebKitURIRequest* request = webkit_navigation_action_get_request(action);
    const char* uri = webkit_uri_request_get_uri(request);
    const char* method = webkit_uri_request_get_http_method(request);
    // The first exact URI is an app-owned load before any document executes.
    // GTK 2.52 has no target-frame accessor. Later links require the separate
    // native main-frame/private-world click proof; never invent isMainFrame.
    bool initial = self->initial_ && !self->closed_ && g_strcmp0(uri, self->url_.c_str()) == 0 &&
      g_strcmp0(method, "GET") == 0 && !webkit_navigation_action_is_redirect(action);
    self->initial_ = false;
    if (initial) webkit_policy_decision_use(decision);
    else if (self->loaded_ && !self->failed_ && self->navigation_) self->navigation_->Decide(decision, action);
    else {
      // GTK does not expose the target frame for navigation decisions. A
      // denied child load can arrive before the main load finishes; refusing
      // that decision must not revoke the independently validated main page.
      g_debug("Raft system preview: refused navigation during main load (kind=%d, redirect=%d, response=%d)",
        webkit_navigation_action_get_navigation_type(action),
        webkit_navigation_action_is_redirect(action), self->response_);
      webkit_policy_decision_ignore(decision);
    }
    return TRUE;
  }
  if (type == WEBKIT_POLICY_DECISION_TYPE_RESPONSE) {
    auto* response = WEBKIT_RESPONSE_POLICY_DECISION(decision);
    // Only the main resource is the isolation contract. Child resources are
    // refused independently and never become an alternate accepted document.
    if (!webkit_response_policy_decision_is_main_frame_main_resource(response)) {
      g_debug("Raft system preview: refused non-main response");
      webkit_policy_decision_ignore(decision); return TRUE;
    }
    WebKitURIRequest* request = webkit_response_policy_decision_get_request(response);
    if (
        g_strcmp0(webkit_uri_request_get_uri(request), self->url_.c_str()) == 0 &&
        webkit_response_policy_decision_is_mime_type_supported(response) &&
        Sandboxed(webkit_response_policy_decision_get_response(response))) {
      self->response_ = true;
      webkit_policy_decision_use(decision);
    } else {
      webkit_policy_decision_ignore(decision);
      self->Fail();
    }
    return TRUE;
  }
  webkit_policy_decision_ignore(decision); return TRUE;
}
void NativeView::Loaded(WebKitWebView* view, WebKitLoadEvent event, gpointer data) {
  auto* self = static_cast<NativeView*>(data);
  if (self->browsing_) {
    if ((event == WEBKIT_LOAD_STARTED || event == WEBKIT_LOAD_REDIRECTED) &&
        !self->BrowserAddress(webkit_web_view_get_uri(view))) {
      webkit_web_view_stop_loading(view);
      return;
    }
    if (event == WEBKIT_LOAD_STARTED) {
      self->loaded_ = false;
      self->failed_ = false;
      self->browser_retry_.clear();
      self->Event("navigationStarted");
    }
    if (event == WEBKIT_LOAD_FINISHED && !self->failed_) {
      self->loaded_ = true;
      self->Event("loaded");
    }
    self->BrowserState();
    return;
  }
  if (event != WEBKIT_LOAD_FINISHED || self->loaded_ || self->failed_ || self->closed_) return;
  // An ignored redirect or cancelled initial main load must terminate as a
  // failure. Child-policy rejection alone cannot manufacture this response.
  if (!self->response_ || g_strcmp0(webkit_web_view_get_uri(self->web_), self->url_.c_str())) {
    self->Fail(); return;
  }
  self->loaded_ = true; self->Event("loaded");
}
gboolean NativeView::Failed(WebKitWebView*, WebKitLoadEvent, gchar* uri, GError* error, gpointer data) {
  auto* self = static_cast<NativeView*>(data);
  if (self->browsing_) {
    if (!(error->domain == WEBKIT_NETWORK_ERROR && error->code == WEBKIT_NETWORK_ERROR_CANCELLED) &&
        !(error->domain == WEBKIT_POLICY_ERROR && error->code == WEBKIT_POLICY_ERROR_FRAME_LOAD_INTERRUPTED_BY_POLICY_CHANGE)) {
      self->Fail(uri);
    }
    return TRUE;
  }
  if (!self->loaded_ && g_strcmp0(uri, self->url_.c_str()) == 0 &&
      !(error->domain == WEBKIT_NETWORK_ERROR && error->code == WEBKIT_NETWORK_ERROR_CANCELLED)) {
    self->Fail();
  }
  return TRUE;
}
void NativeView::Progress(GObject*, GParamSpec*, gpointer data) {
  auto* self = static_cast<NativeView*>(data);
  if (self->closed_ || self->failed_ || self->loaded_) return;
  g_autoptr(FlValue) fields = fl_value_new_map();
  fl_value_set_string_take(fields, "percent", fl_value_new_int(std::lround(webkit_web_view_get_estimated_load_progress(self->web_) * 100)));
  self->Event("progress", fields);
}

gboolean NativeView::Message(WebKitWebView*, WebKitUserMessage* message, gpointer data) {
  auto* self = static_cast<NativeView*>(data);
  return self->navigation_ && !self->closed_ && self->loaded_ && !self->failed_ && self->navigation_->Message(message);
}

void NativeView::AfterInput(GtkWidget*, GdkEvent* event, gpointer data) {
  auto* self = static_cast<NativeView*>(data);
  if (!self->loaded_ || self->closed_ || self->failed_ || !event) return;
  switch (event->type) {
    case GDK_BUTTON_RELEASE: case GDK_SCROLL: case GDK_KEY_RELEASE:
    case GDK_TOUCH_END: case GDK_TOUCH_CANCEL:
      self->Event("snapshotDirty"); break;
    default: break;
  }
}

void NativeView::Fail(const char* browser_address) {
  if (closed_ || failed_) return;
  failed_ = true; loaded_ = false;
  if (browsing_) {
    g_autoptr(FlValue) fields = fl_value_new_map();
    if (BrowserAddress(browser_address)) browser_retry_ = browser_address;
    if (!browser_retry_.empty()) {
      fl_value_set_string_take(fields, "url", fl_value_new_string(browser_retry_.c_str()));
    }
    Event("failed", fields);
    return;
  }
  SetPaintOccluded(false);
  if (web_) webkit_web_view_stop_loading(web_);
  if (cancellable_) g_cancellable_cancel(cancellable_);
  navigation_.reset();
  if (region_) { region_->Clear(); region_->Visibility(false); }
  last_clip_ = {0,0,0,0};
  if (clip_) host_->Layout(id_, clip_, last_clip_, false);
  Event("failed");
}
gboolean NativeView::TlsFailed(WebKitWebView*, gchar* address, GTlsCertificate*, GTlsCertificateFlags, gpointer data) {
  static_cast<NativeView*>(data)->Fail(address); return TRUE;
}
void NativeView::Terminated(WebKitWebView*, WebKitWebProcessTerminationReason, gpointer data) {
  static_cast<NativeView*>(data)->Fail();
}

gboolean NativeView::ObserveInput(GtkWidget*, GdkEvent* event, gpointer data) {
  auto* self = static_cast<NativeView*>(data);
  if (self->closed_ || !event) return FALSE;
  const char* type;
  switch (event->type) {
    case GDK_MOTION_NOTIFY:type="motion";break;
    case GDK_BUTTON_PRESS:type="down";break;
    case GDK_BUTTON_RELEASE:type="up";break;
    case GDK_ENTER_NOTIFY:type="enter";break;
    case GDK_LEAVE_NOTIFY:type="leave";break;
    default:return FALSE;
  }
  InputSample sample{};sample.type=type;sample.time=gdk_event_get_time(event);
  sample.sequence=++self->input_sample_sequence_;sample.layout=self->sequence_;
  if (!gdk_event_get_coords(event,&sample.x,&sample.y) ||
      !gdk_event_get_root_coords(event,&sample.root_x,&sample.root_y)) return FALSE;
  auto* window=gdk_event_get_window(event);
  if(window){gdk_window_get_origin(window,&sample.origin_x,&sample.origin_y);
    gpointer widget=nullptr;gdk_window_get_user_data(window,&widget);
    if(widget&&GTK_IS_WIDGET(widget))sample.widget_type=G_OBJECT_TYPE_NAME(widget);
  }
  sample.web_window=window==gtk_widget_get_window(GTK_WIDGET(self->web_));
  if(auto* device=gdk_event_get_device(event))gdk_device_get_position(device,nullptr,&sample.device_x,&sample.device_y);
  self->input_samples_.push_back(std::move(sample));
  while(self->input_samples_.size()>16)self->input_samples_.pop_front();
  // Observation does not retarget, delay, consume, queue or synthesize input.
  return FALSE;
}

void NativeView::FocusChanged(GObject*, GParamSpec*, gpointer data) {
  auto* self = static_cast<NativeView*>(data);
  if (self->closed_) return;
  g_autoptr(FlValue) fields = fl_value_new_map();
  fl_value_set_string_take(fields, "focused", fl_value_new_bool(gtk_widget_has_focus(GTK_WIDGET(self->web_))));
  self->Event("focus", fields);
}

void NativeView::Allocated(GtkWidget*, GtkAllocation*, gpointer data) {
  auto* self = static_cast<NativeView*>(data);
  if (!self->closed_ && self->loaded_ && !self->failed_ && self->snapshot_ &&
      self->snapshot_->ViewportAllocated()) self->Event("snapshotDirty");
}

void NativeView::SetPaintOccluded(bool occluded) {
  paint_occluded_ = occluded;
  // Opacity affects painting only. A passive Flutter overlay must not unmap
  // the genuine WebKit widget or remove the user's native input rectangle.
  if (clip_) gtk_widget_set_opacity(clip_, occluded ? 0.0 : 1.0);
}
