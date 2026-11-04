"""Build-local plugin integrity and actual native file-chooser admission."""
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "linux_html_patch", ROOT / "tool/html_webview/patch_linux_plugin.py")
PATCH = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PATCH)
PLUGIN = Path(os.environ.get("PUB_CACHE", Path.home() / ".pub-cache")) / (
    "hosted/pub.dev/flutter_inappwebview_linux-0.1.0-beta.1/linux")


def chooser_source(path):
    source = path.read_text()
    start = source.index("gboolean InAppWebView::OnRunFileChooser(")
    end = source.index("// === Option Menu", start)
    return source[start:end]


# External WebKit/GTK calls are test doubles. The complete actual plugin
# callback body is compiled unchanged; no parallel implementation of its gate.
CHOOSER_FIXTURE = r'''
#include <cassert>
#include <functional>
#include <memory>
#include <optional>
#include <string>
#include <vector>
using gboolean = int; using gpointer = void*; using gchar = char;
constexpr int TRUE=1, FALSE=0;
struct WebKitWebView {}; struct WebKitFileChooserRequest {}; struct GtkWindow {};
struct Settings { bool allowFileAccess=true; };
struct ShowFileChooserResponse {
 bool handledByClient=false;
 std::optional<std::vector<std::string>> filePaths;
};
struct Delegate { template<class... T> void onShowFileChooser(T... args) {} };
struct InAppWebView {
 std::shared_ptr<Settings> settings_=std::make_shared<Settings>();
 Delegate* channel_delegate_=nullptr; GtkWindow* gtk_window_=nullptr;
 static gboolean OnRunFileChooser(WebKitWebView*,WebKitFileChooserRequest*,gpointer);
};
int cancelled=0, shown=0;
gboolean webkit_file_chooser_request_get_select_multiple(WebKitFileChooserRequest*) { return FALSE; }
const gchar* const* webkit_file_chooser_request_get_mime_types(WebKitFileChooserRequest*) { return nullptr; }
void webkit_file_chooser_request_cancel(WebKitFileChooserRequest*) { ++cancelled; }
void webkit_file_chooser_request_select_files(WebKitFileChooserRequest*,const char**) { assert(false); }
void g_object_ref(WebKitFileChooserRequest*) {}
void g_object_unref(WebKitFileChooserRequest*) {}
void ShowNativeFileChooser(InAppWebView*,WebKitFileChooserRequest*,bool,
 const std::vector<std::string>&,GtkWindow*) { ++shown; }
'''
CHOOSER_MAIN = r'''
int main() {
 InAppWebView view; WebKitFileChooserRequest request;
 view.settings_->allowFileAccess=false;
 assert(view.OnRunFileChooser(nullptr,&request,&view)==TRUE);
 assert(cancelled==1 && shown==0);
 view.settings_->allowFileAccess=true;
 assert(view.OnRunFileChooser(nullptr,&request,&view)==TRUE);
 assert(cancelled==1 && shown==1);
}
'''


@unittest.skipUnless(PLUGIN.is_dir(), "Pinned public Linux plugin is not installed")
class LinuxHtmlPluginTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="raft-linux-html-")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.original = self.directory / "original"
        self.output = self.directory / "build-copy"
        shutil.copytree(PLUGIN, self.original)
        shutil.copytree(PLUGIN, self.output)

    def test_changed_input_fails_before_any_write(self):
        before = {n: (self.output / n).read_bytes() for n in PATCH.PINS}
        name = next(reversed(PATCH.PINS))
        (self.original / name).write_bytes(b"changed upstream source\n")
        with self.assertRaisesRegex(ValueError, "Review changed"):
            PATCH.prepare(self.original, self.output)
        self.assertEqual(before, {n: (self.output / n).read_bytes() for n in PATCH.PINS})

    def test_original_and_symlink_targets_are_never_written(self):
        with self.assertRaisesRegex(ValueError, "separate build copy"):
            PATCH.prepare(self.original, self.original)
        name = next(iter(PATCH.PINS))
        target = self.output / name
        target.unlink()
        target.symlink_to(self.original / name)
        before = (self.original / name).read_bytes()
        with self.assertRaisesRegex(ValueError, "escapes"):
            PATCH.prepare(self.original, self.output)
        self.assertEqual(before, (self.original / name).read_bytes())
        target.unlink()
        os.link(self.original / name, target)
        with self.assertRaisesRegex(ValueError, "escapes"):
            PATCH.prepare(self.original, self.output)
        self.assertEqual(before, (self.original / name).read_bytes())

    @unittest.skipUnless(shutil.which("c++"), "C++ compiler is unavailable")
    def test_actual_chooser_denies_before_native_or_channel_fallback(self):
        original = {n: (self.original / n).read_bytes() for n in PATCH.PINS}
        PATCH.prepare(self.original, self.output)
        self.assertEqual(original, {n: (self.original / n).read_bytes() for n in PATCH.PINS})
        for label, directory, expected in (("original", self.original, False),
                                            ("patched", self.output, True)):
            source = self.directory / (label + ".cc")
            binary = self.directory / (label + ".bin")
            source.write_text(CHOOSER_FIXTURE + chooser_source(
                directory / "in_app_webview/in_app_webview.cc") + CHOOSER_MAIN)
            compiled = subprocess.run(
                ["c++", "-std=c++17", str(source), "-o", str(binary)],
                capture_output=True, timeout=30)
            self.assertEqual(compiled.returncode, 0, compiled.stderr.decode())
            # Disable cores for the intentional original-source assertion.
            import resource
            def no_core():
                resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
            result = subprocess.run([str(binary)], capture_output=True,
                                    timeout=5, preexec_fn=no_core)
            self.assertEqual(result.returncode == 0, expected, result.stderr.decode())


if __name__ == "__main__":
    unittest.main()
