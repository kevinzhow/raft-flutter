import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Tells the macOS text input plugin to take key input again after the window
/// was resized.
///
/// The macOS engine routes keystrokes to the input method only while its text
/// input view is the key responder, which `TextInput.show` establishes. A
/// resized window can leave that behind: the connection is intact (same client,
/// no `clearClient`), but typing produces no editing state until the next
/// `show`, which a click on the field sends. So after the window metrics
/// changed, the focused editor asks for the keyboard once more. `show` on a live
/// connection changes no text, selection or composing range.
///
/// macOS only. It acts on whatever field has the primary focus, so any screen can use it;
/// [retain]/[release] count the screens that want it, and it listens only while
/// there is at least one.
class RaftTextInputRefresh with WidgetsBindingObserver {
  RaftTextInputRefresh._();
  static final instance = RaftTextInputRefresh._();

  int _users = 0;
  Size? _size;

  static void retain() {
    if (instance._users++ > 0) return;
    instance._size = instance._viewSize;
    WidgetsBinding.instance.addObserver(instance);
  }

  static void release() {
    if (--instance._users > 0) return;
    WidgetsBinding.instance.removeObserver(instance);
  }

  Size? get _viewSize =>
      WidgetsBinding.instance.platformDispatcher.implicitView?.physicalSize;

  @override
  void didChangeMetrics() {
    if (defaultTargetPlatform != TargetPlatform.macOS) return;
    final size = _viewSize;
    if (size == _size) return;
    _size = size;
    // After the frame: the new layout is in place and the plugin has the new
    // editable geometry.
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
  }

  @visibleForTesting
  void refresh() {
    final field = FocusManager.instance.primaryFocus?.context
        ?.findAncestorStateOfType<EditableTextState>();
    if (field == null || !field.mounted) return;
    field.requestKeyboard();
  }
}
