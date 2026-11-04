// Compile the pinned plugin's real control handler with display-free API fakes.
#include <glib.h>
#include <map>
#include <string>
#include <cstdio>
struct FlValue;
static void fl_value_unref(FlValue* value);
struct FlValue {
  int refs = 1;
  std::string text;
  std::map<std::string, FlValue*> values;
  ~FlValue() { for (auto& entry : values) fl_value_unref(entry.second); }
};
static FlValue* fl_value_ref(FlValue* v) { if (v) ++v->refs; return v; }
static void fl_value_unref(FlValue* v) { if (v && --v->refs == 0) delete v; }
G_DEFINE_AUTOPTR_CLEANUP_FUNC(FlValue, fl_value_unref)
static FlValue* fl_value_new_map() { return new FlValue; }
static FlValue* fl_value_new_string(const char* text) { auto* v = new FlValue; v->text = text; return v; }
static void fl_value_set_string_take(FlValue* v, const char* key, FlValue* item) { v->values[key] = item; }
static FlValue* fl_value_lookup_string(FlValue* v, const char* key) { auto i=v->values.find(key); return i==v->values.end() ? nullptr : i->second; }
static const char* fl_value_get_string(FlValue* v) { return v->text.c_str(); }
struct FlMethodResponse {
  int type;
  std::string code;
  FlValue* result;
  ~FlMethodResponse() { fl_value_unref(result); }
};
static void free_response(FlMethodResponse* r) { delete r; }
G_DEFINE_AUTOPTR_CLEANUP_FUNC(FlMethodResponse, free_response)
#define FL_METHOD_RESPONSE(x) (x)
static FlMethodResponse* fl_method_success_response_new(FlValue* value) { return new FlMethodResponse{0,"",fl_value_ref(value)}; }
static FlMethodResponse* fl_method_error_response_new(const char* code, const char*, void*) { return new FlMethodResponse{1,code,nullptr}; }
static FlMethodResponse* fl_method_not_implemented_response_new() { return new FlMethodResponse{2,"",nullptr}; }
struct FlMethodCall { const char* method; FlValue args; int response=-1; std::string code; };
static const char* fl_method_call_get_name(FlMethodCall* call) { return call->method; }
static FlValue* fl_method_call_get_args(FlMethodCall* call) { return &call->args; }
static void fl_method_call_respond(FlMethodCall* c, FlMethodResponse* r, void*) { c->response=r->type;c->code=r->code; }
[[maybe_unused]] static void fl_method_call_respond_error(FlMethodCall* c, const char* code, const char*, void*, void*) { c->response=1;c->code=code; }
class FlutterWindow {
 public:
  unsigned controls=0;
  std::string GetWindowId() { return "primary"; }
  std::string GetWindowArgument() { return ""; }
  void HandleWindowMethod(const char*, FlValue*, FlMethodCall* call) { ++controls;call->response=0; }
};
class MultiWindowManager {
 public:
  unsigned creates=0, queries=0;
  FlutterWindow window;
  static MultiWindowManager* Instance() { static MultiWindowManager m;return &m; }
  std::string Create(FlValue*) { ++creates;return "child"; }
  FlutterWindow* GetWindow(const std::string& id) { return id=="primary" ? &window : nullptr; }
  FlValue* GetAllWindows() { ++queries;return fl_value_new_string("known-windows"); }
};
struct DesktopMultiWindowPlugin { FlutterWindow* window; };
