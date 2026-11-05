#include <webkit2/webkit-web-extension.h>
#include <jsc/jsc.h>
#include <gmodule.h>
#include <cstring>
#include <string>

namespace {
std::string nonce;
guint64 trusted_sequence = 0;
struct Binding {
  GWeakRef page, frame;
  Binding(WebKitWebPage* p, WebKitFrame* f) { g_weak_ref_init(&page, p); g_weak_ref_init(&frame, f); }
  ~Binding() { g_weak_ref_clear(&page); g_weak_ref_clear(&frame); }
};
void TrustedClick(JSCValue* event, const char* href, const char* target, gpointer data) {
  auto* binding = static_cast<Binding*>(data);
  auto* page = WEBKIT_WEB_PAGE(g_weak_ref_get(&binding->page));
  auto* frame = WEBKIT_FRAME(g_weak_ref_get(&binding->frame));
  if (!page || !frame) { if (page) g_object_unref(page); if (frame) g_object_unref(frame); return; }
  g_autoptr(JSCValue) trusted = jsc_value_object_get_property(event, "isTrusted");
  g_autoptr(JSCValue) type = jsc_value_object_get_property(event, "type");
  g_autofree char* event_type = jsc_value_to_string(type);
  const char* source = webkit_frame_get_uri(frame);
  const bool accepted_target = target && (!*target || !g_ascii_strcasecmp(target,"_self") || !g_ascii_strcasecmp(target,"_blank"));
  if (webkit_frame_is_main_frame(frame) && source && href && strlen(href) <= 8192 && accepted_target &&
      jsc_value_is_boolean(trusted) && jsc_value_to_boolean(trusted) && !g_strcmp0(event_type, "click")) {
    auto* message = webkit_user_message_new("raft-attachment-trusted-link-v2",
      g_variant_new("(sttssst)", nonce.c_str(), webkit_web_page_get_id(page),
        webkit_frame_get_id(frame), source, href, target, ++trusted_sequence));
    webkit_web_page_send_message_to_view(page, message, nullptr, nullptr, nullptr);
  }
  g_object_unref(frame); g_object_unref(page);
}
void WindowCleared(WebKitScriptWorld* world, WebKitWebPage* page, WebKitFrame* frame, gpointer) {
  if (!webkit_frame_is_main_frame(frame)) return;
  g_autoptr(JSCContext) context = webkit_frame_get_js_context_for_script_world(frame, world);
  auto* binding = new Binding(page, frame);
  g_autoptr(JSCValue) callback = jsc_value_new_function(context, "raftTrustedClick",
    G_CALLBACK(TrustedClick), binding, [](gpointer value) { delete static_cast<Binding*>(value); },
    G_TYPE_NONE, 3, JSC_TYPE_VALUE, G_TYPE_STRING, G_TYPE_STRING);
  // This global exists only in our private ScriptWorld. Page JavaScript and
  // host geometry evaluations execute in the default world and cannot call it.
  jsc_context_set_value(context, "__raftTrustedClick", callback);
  constexpr const char* listener = R"JS((function(){
    const report = globalThis.__raftTrustedClick;
    delete globalThis.__raftTrustedClick;
    document.addEventListener('click', function(event) {
      if (!event.isTrusted || event.button !== 0 || event.defaultPrevented) return;
      const element = event.target instanceof Element ? event.target : event.target?.parentElement;
      const link = element?.closest('a[href]');
      if (!link || link.hasAttribute('download')) return;
      const uri = link.href;
      const target = link.getAttribute('target') ??
        document.querySelector('base[target]')?.getAttribute('target') ?? '';
      const targetKind = target.toLowerCase();
      if (targetKind !== '' && targetKind !== '_self' && targetKind !== '_blank') {
        event.preventDefault(); return;
      }
      if (targetKind === '_blank') {
        // Keep the sandbox's popup prohibition. Hand off only this genuine
        // main-frame link click; script window.open never enters this branch.
        event.preventDefault(); report(event, uri, target); return;
      }
      // Wait until all page listeners have had a chance to prevent default.
      // Policy decisions are bounded while this isolated-world proof arrives.
      queueMicrotask(() => { if (!event.defaultPrevented) report(event, uri, target); });
    }, true);
  })())JS";
  g_autoptr(JSCValue) installed = jsc_context_evaluate(context, listener, -1);
}
}
extern "C" G_MODULE_EXPORT void webkit_web_extension_initialize_with_user_data(
  WebKitWebExtension*, const GVariant* user_data) {
  auto* value = const_cast<GVariant*>(user_data);
  if (!value || !g_variant_is_of_type(value, G_VARIANT_TYPE_STRING)) return;
  nonce = g_variant_get_string(value, nullptr);
  if (nonce.size() != 36) { nonce.clear(); return; }
  WebKitScriptWorld* world = webkit_script_world_new();
  g_signal_connect(world, "window-object-cleared", G_CALLBACK(WindowCleared), nullptr);
  // The world lives for this ephemeral WebProcess. No main-world scripts or
  // UserContentManager script-message handlers are installed.
}
