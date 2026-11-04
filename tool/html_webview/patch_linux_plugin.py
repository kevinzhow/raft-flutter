"""Apply reviewed, hash-pinned fixes to a build-local Linux plugin copy."""
import argparse
import hashlib
from pathlib import Path

PINS = {
    "in_app_webview/in_app_webview_settings.cc": "4288f88084645211d79693855a70c294bbfefed2c15c5adf7ad57695ac0cece4",
    "in_app_webview/in_app_webview_settings.h": "fe7e5658168f2cc9ae5f2cf114359c40e2bff5a5c9f4237687742d6fa67567ac",
    "in_app_webview/in_app_webview.cc": "50cafee5572793f13ec2783f57e38495ec383b6c4fdd9f9cb59c1e7a21ed8473",
    "types/navigation_action.h": "1069c8e3dba9dde5870e911a03ca3a73f891fa153ee0684463aaf507137de3b5",
    "types/navigation_action.cc": "b70b4272b6c4d42b6dd7207c7806653a7955e9e6d96a5c31a35c981139428459",
}


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise ValueError("The pinned Linux plugin patch site changed")
    return source.replace(old, new, 1)


def patch(name, source):
    if name.endswith("in_app_webview_settings.cc"):
        source = replace_once(source, "WPE_SETTING_DISABLE_ANIMATIONS", "WPE_SETTING_REDUCED_MOTION")
        source = replace_once(source, '  allowFileAccessFromFileURLs =',
                              '  allowFileAccess = get_fl_map_value(map, "allowFileAccess", allowFileAccess);\n  allowFileAccessFromFileURLs =')
        return replace_once(source, '      {"allowFileAccessFromFileURLs",',
                            '      {"allowFileAccess", make_fl_value(allowFileAccess)},\n      {"allowFileAccessFromFileURLs",')
    if name.endswith("in_app_webview_settings.h"):
        return replace_once(source, "  bool allowFileAccessFromFileURLs =",
                            "  bool allowFileAccess = true;  // Explicit false also denies native file selection.\n  bool allowFileAccessFromFileURLs =")
    if name == "types/navigation_action.h":
        source = replace_once(source, "  const std::optional<bool> isRedirect;",
                              "  const std::optional<bool> isRedirect;\n  const std::optional<bool> hasGesture;")
        return replace_once(source, "const std::optional<NavigationActionType>& navigationType);",
                            "const std::optional<NavigationActionType>& navigationType,\n                   const std::optional<bool>& hasGesture = std::nullopt);")
    if name == "types/navigation_action.cc":
        source = replace_once(source, "const std::optional<NavigationActionType>& navigationType)",
                              "const std::optional<NavigationActionType>& navigationType,\n                                   const std::optional<bool>& hasGesture)")
        source = replace_once(source, "      isRedirect(isRedirect),",
                              "      isRedirect(isRedirect),\n      hasGesture(hasGesture),")
        return replace_once(source, '      {"isRedirect", make_fl_value(isRedirect)},',
                            '      {"isRedirect", make_fl_value(isRedirect)},\n      {"hasGesture", make_fl_value(hasGesture)},')
    if name == "in_app_webview/in_app_webview.cc":
        source = replace_once(source,
                              "      // Update button state AFTER the event (but include in modifiers)\n      break;",
                              "      // Match WPEWaylandSeat: UP reports the remaining pressed buttons.\n      button_state_ &= ~button_modifier_bit;\n      break;")
        source = replace_once(source,
                              "  // Clear button state AFTER sending the UP event\n  if (event_type == WPE_EVENT_POINTER_UP) {\n    button_state_ &= ~button_modifier_bit;\n  }\n",
                              "")
        source = replace_once(source, "      // Create URLRequest\n      auto urlRequest =",
                              "      // Preserve the real method; non-HTTP requests can have none.\n      const gchar* method = webkit_uri_request_get_http_method(request);\n      auto urlRequest =")
        source = replace_once(source, '          std::optional<std::string>("GET"),',
                              '          method ? std::optional<std::string>(method) : std::nullopt,')
        source = replace_once(source, "          std::nullopt,  // isRedirect - not easily available in WebKit\n          navActionType);",
                              "          webkit_navigation_action_is_redirect(nav_action) != FALSE,\n          navActionType,\n          webkit_navigation_action_is_user_gesture(nav_action) != FALSE);")
        source = replace_once(source,
                              "      // CRITICAL: Set error handler to prevent navigation from being blocked on channel errors\n      // Allow navigation on error to prevent page from being stuck",
                              "      // A failed host policy decision cannot grant navigation.")
        source = replace_once(source,
                              "        // Allow navigation on error to prevent page from being stuck\n        self->OnShouldOverrideUrlLoadingDecision(decision_id, true);",
                              "        self->OnShouldOverrideUrlLoadingDecision(decision_id, false);")
        return replace_once(source,
                            "  // Get file chooser properties\n  gboolean select_multiple =",
                            "  // Honor the host's explicit file-access denial before any callback or\n  // native dialog. The pinned Dart Linux chooser mode decoder can throw;\n  // that must never turn the preview's denial into a GTK chooser.\n  if (self->settings_ && !self->settings_->allowFileAccess) {\n    webkit_file_chooser_request_cancel(request);\n    return TRUE;\n  }\n\n  // Get file chooser properties\n  gboolean select_multiple =")
    raise ValueError("Unexpected Linux plugin source")


def prepare(original, output):
    original, output = original.resolve(), output.resolve()
    if original == output or original in output.parents or output in original.parents:
        raise ValueError("The Linux plugin backport requires a separate build copy")
    pending = {}
    for name, pin in PINS.items():
        source = (original / name).read_bytes()
        if hashlib.sha256(source).hexdigest() != pin:
            raise ValueError(f"Review changed Linux plugin source: {name}")
        target = output / name
        if (target.is_symlink() or target.stat().st_nlink != 1
                or target.resolve().parent != (output / name).parent):
            raise ValueError("A build-local patch target escapes its copy")
        if target.read_bytes() != source:
            raise ValueError("Copy the original plugin before applying its backport")
        pending[target] = patch(name, source.decode()).encode()
    # Validate all inputs and patch sites before writing any output.
    for target, value in pending.items():
        target.write_bytes(value)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("original", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    prepare(args.original, args.output)
