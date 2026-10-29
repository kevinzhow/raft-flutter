import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart'
    show RaftPreviewRoute, raftText, showRaftAlertDialog;
import 'package:raft_updater/raft_updater.dart';

/// Requests the runner's ordinary close action, preserving its close preference.
///
/// macOS keeps running after closing its window; Windows decides whether to
/// hide or exit. Unsupported platforms and older runners have no action.
Future<void> closeAppWindow({
  TargetPlatform? platform,
  MethodChannel? channel,
}) async {
  final name = switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.macOS => 'app.raft/window',
    TargetPlatform.windows => 'app.raft/windows-tray',
    _ => null,
  };
  if (name == null) return;
  try {
    await (channel ?? MethodChannel(name)).invokeMethod<void>('closeWindow');
  } on MissingPluginException {
    // A preview or older runner has no native close entry.
  }
}

/// Routes desktop window commands through the root navigator before the runner.
///
/// Local preview shortcuts take precedence over the window fallback. Native
/// macOS menu actions use the same policy: popups and marked previews close
/// first, protected dialogs veto closing, and ordinary pages stay mounted.
/// Native Paste uses the focused editor's action, including its attachment
/// handler, instead of the engine's hidden AppKit accessibility text field.
class AppWindowCommands extends StatefulWidget {
  const AppWindowCommands({
    super.key,
    required this.navigatorKey,
    this.openSection,
    this.updater,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final ValueChanged<String>? openSection;

  /// The same updater used by Settings; defaults to the app-wide instance.
  final AppUpdater? updater;
  final Widget child;

  @override
  State<AppWindowCommands> createState() => _AppWindowCommandsState();
}

class _AppWindowCommandsState extends State<AppWindowCommands> {
  static const _channel = MethodChannel('app.raft/window');
  // A replacement can mount before its predecessor is disposed.
  static Object? _handlerOwner;
  late final _mac = !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
  bool _closing = false;
  bool _checkingUpdates = false;

  @override
  void initState() {
    super.initState();
    if (_mac) {
      _handlerOwner = this;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'pasteRequested') return _paste();
        if (call.method == 'checkForUpdatesRequested') {
          return _checkForUpdates();
        }
        if (call.method == 'closeRequested') {
          await _close();
        } else if (call.method == 'openPreferences') {
          _preferences();
        } else {
          throw MissingPluginException();
        }
        return true;
      });
      FocusManager.instance.addListener(_focusChanged);
      unawaited(_publishState(true));
    }
  }

  @override
  void didUpdateWidget(AppWindowCommands oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mac &&
        (oldWidget.openSection == null) != (widget.openSection == null)) {
      unawaited(_publishState(true));
    }
  }

  static const _pasteIntent = PasteTextIntent(SelectionChangedCause.keyboard);

  BuildContext? get _pasteContext {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null || !context.mounted) return null;
    final editor = context.findAncestorWidgetOfExactType<EditableText>();
    if (editor != null &&
        (editor.readOnly ||
            !editor.selectionEnabled ||
            !editor.controller.selection.isValid)) {
      return null;
    }
    final action = Actions.maybeFind<PasteTextIntent>(context);
    return action?.isEnabled(_pasteIntent) == true ? context : null;
  }

  void _focusChanged() => unawaited(_publishState(true));

  bool _paste() {
    final target = _pasteContext;
    if (target == null) return false;
    Actions.invoke(target, _pasteIntent);
    return true;
  }

  Future<bool> _checkForUpdates() async {
    if (_checkingUpdates) return false;
    _checkingUpdates = true;
    await _publishState(true);
    try {
      do {
        final outcome = await (widget.updater ?? AppUpdater.instance)
            .checkAndInstall();
        if (outcome != AppUpdateOutcome.failed) return true;
        final context = widget.navigatorKey.currentState?.overlay?.context;
        if (!mounted || context == null || !context.mounted) return false;
        final retry = await showRaftAlertDialog(
          context: context,
          title: raftText(context, "Couldn't check for updates"),
          description: raftText(
            context,
            'Check your connection and try again.',
          ),
          confirmLabel: raftText(context, 'Try Again'),
          cancelLabel: raftText(context, 'Cancel'),
        );
        if (!retry) return false;
      } while (mounted);
      return false;
    } finally {
      _checkingUpdates = false;
      if (mounted) await _publishState(true);
    }
  }

  Future<void> _publishState(bool ready) async {
    if (!identical(_handlerOwner, this)) return;
    try {
      await _channel.invokeMethod<void>('setWindowCommandsState', {
        'ready': ready,
        'updates': ready && !_checkingUpdates,
        'paste': ready && _pasteContext != null,
        'preferences': ready && widget.openSection != null,
      });
    } on MissingPluginException {
      // Older runners still receive the ordinary keyboard fallback.
    }
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    try {
      final navigator = widget.navigatorKey.currentState;
      Route<dynamic>? top;
      // Inspect the top route without removing it. Ordinary pages stay mounted
      // while the runner closes the window, ready for the next reopen.
      navigator?.popUntil((route) {
        top = route;
        return true;
      });
      if (top is PopupRoute || top is RaftPreviewRoute) {
        // maybePop also respects PopScope and its veto callback.
        if (await navigator!.maybePop()) return;
      }
      if (mounted) await closeAppWindow();
    } finally {
      _closing = false;
    }
  }

  void _preferences() {
    if (widget.openSection == null) return;
    var blocked = false;
    widget.navigatorKey.currentState?.popUntil((route) {
      blocked = route.popDisposition == RoutePopDisposition.doNotPop;
      return route.isFirst || blocked;
    });
    if (!blocked) widget.openSection?.call('settings');
  }

  @override
  void dispose() {
    if (_mac) FocusManager.instance.removeListener(_focusChanged);
    if (_mac && identical(_handlerOwner, this)) {
      unawaited(_publishState(false));
      _channel.setMethodCallHandler(null);
      _handlerOwner = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final windows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    if (!_mac && !windows) return widget.child;
    return CallbackShortcuts(
      bindings: {
        SingleActivator(
          LogicalKeyboardKey.keyW,
          meta: _mac,
          control: windows,
          includeRepeats: false,
        ): () =>
            unawaited(_close()),
      },
      child: widget.child,
    );
  }
}

/// Brings the app's window to the front. A desktop sign-in finishes in the
/// browser, which stays in front until the app takes the focus back.
///
/// Best effort: a desktop shell may refuse to raise a window the person's last
/// input did not start (Wayland compositors, Windows' foreground lock); it then
/// flashes the taskbar entry or the dock icon instead.
Future<void> presentAppWindow({
  TargetPlatform? platform,
  MethodChannel? channel,
}) async {
  switch (platform ?? defaultTargetPlatform) {
    case TargetPlatform.windows:
      // The notification channel's `present` (ShowWindow + SetForegroundWindow).
      await (channel ?? const MethodChannel('app.raft/windows-notifications'))
          .invokeMethod<void>('present');
    case TargetPlatform.linux || TargetPlatform.macOS:
      await (channel ?? const MethodChannel('app.raft/window'))
          .invokeMethod<void>('present');
    case TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia:
      break;
  }
}

/// Reads desktop activation without raising the window.
///
/// Flutter may not deliver a lifecycle event at background startup. Missing
/// runners, failed reads, and a one-second timeout return `false`.
Future<bool> isAppWindowActive({
  TargetPlatform? platform,
  MethodChannel? channel,
}) async {
  final name = switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.windows => 'app.raft/windows-notifications',
    TargetPlatform.linux || TargetPlatform.macOS => 'app.raft/window',
    _ => null,
  };
  if (name == null) return false;
  try {
    return await (channel ?? MethodChannel(name))
            .invokeMethod<Object?>('isActive')
            .timeout(const Duration(seconds: 1)) ==
        true;
  } catch (_) {
    return false;
  }
}
