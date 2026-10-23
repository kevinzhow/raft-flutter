import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'window_title.dart';

/// Who paints the desktop title bar.
enum DesktopTitleBarMode {
  /// Not a desktop window with a title bar the app can colour.
  none,

  /// macOS: the content view runs under a transparent title bar, so the app
  /// draws the strip itself in the space the native bar leaves and reports.
  strip,

  /// Linux: GTK draws both the bar and its rule in the supplied colours.
  native,

  /// Windows: DWM draws the caption; Flutter supplies its missing bottom rule
  /// at the top of the client area, using the same strip recipe as macOS.
  nativeWithRule,
}

/// What the native window reports about its title bar.
@immutable
class DesktopTitleBarState {
  const DesktopTitleBarState({this.height = 0, this.fullscreen = false});

  /// The title bar's height in logical pixels; zero when the window has none.
  final double height;

  /// Whether the window is fullscreen. macOS hides its title bar then.
  final bool fullscreen;

  @override
  bool operator ==(Object other) =>
      other is DesktopTitleBarState &&
      other.height == height &&
      other.fullscreen == fullscreen;

  @override
  int get hashCode => Object.hash(height, fullscreen);
}

/// The colours the title bar wears, from the rail recipe of the current theme.
@immutable
class DesktopTitleBarStyle {
  const DesktopTitleBarStyle({
    required this.background,
    required this.foreground,
    required this.rule,
    required this.ruleWidth,
  });

  factory DesktopTitleBarStyle.of(RaftTokens tokens) {
    final recipe = RaftTitleBarRecipe(tokens);
    return DesktopTitleBarStyle(
      background: recipe.background,
      foreground: recipe.foreground,
      rule: recipe.rule,
      ruleWidth: recipe.ruleWidth,
    );
  }

  final Color background, foreground, rule;
  final double ruleWidth;

  Map<String, Object> toArguments() => {
    'background': background.toARGB32(),
    'foreground': foreground.toARGB32(),
    // The system paints the rule opaque: resolve a translucent divider (the
    // dark Elegant one) over the strip, the way the Flutter strip shows it.
    'rule': Color.alphaBlend(rule, background).toARGB32(),
    'ruleWidth': ruleWidth,
    'dark': background.computeLuminance() < .5,
  };

  @override
  bool operator ==(Object other) =>
      other is DesktopTitleBarStyle &&
      other.background == background &&
      other.foreground == foreground &&
      other.rule == rule &&
      other.ruleWidth == ruleWidth;

  @override
  int get hashCode => Object.hash(background, foreground, rule, ruleWidth);
}

/// The Dart side of the runner's `app.raft/titlebar` channel.
///
/// Dart to native: `status` (reads the state), `setStyle` (colours), and on
/// macOS `startDragging` / `doubleClick`. Native to Dart: `state`, whenever the
/// title bar's height or the window's fullscreen state changes.
class DesktopTitleBarController {
  DesktopTitleBarController({
    MethodChannel? channel,
    TargetPlatform? platform,
    bool? web,
  }) : _channel = channel ?? const MethodChannel(channelName),
       mode = _modeFor(platform ?? defaultTargetPlatform, web ?? kIsWeb);

  static const channelName = 'app.raft/titlebar';

  /// macOS's standard title bar, until the window says otherwise. The first
  /// frame is drawn before the runner's answer arrives.
  static const macosDefaultHeight = 28.0;

  static final DesktopTitleBarController platform = DesktopTitleBarController();

  static DesktopTitleBarMode _modeFor(TargetPlatform platform, bool web) {
    if (web) return DesktopTitleBarMode.none;
    return switch (platform) {
      TargetPlatform.macOS => DesktopTitleBarMode.strip,
      TargetPlatform.linux => DesktopTitleBarMode.native,
      TargetPlatform.windows => DesktopTitleBarMode.nativeWithRule,
      _ => DesktopTitleBarMode.none,
    };
  }

  final MethodChannel _channel;
  final DesktopTitleBarMode mode;
  // ignore: raft_lints/avoid_unreleased_resource -- Process-wide singleton, never torn down.
  late final ValueNotifier<DesktopTitleBarState> state = ValueNotifier(
    DesktopTitleBarState(
      height: mode == DesktopTitleBarMode.strip ? macosDefaultHeight : 0,
    ),
  );
  bool _started = false;
  DesktopTitleBarStyle? _sent;

  /// Listen for the runner's reports and read the first one. Safe to call
  /// again; an older bundle without the channel keeps the defaults.
  Future<void> start() async {
    if (_started || mode == DesktopTitleBarMode.none) return;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'state') _receive(call.arguments);
    });
    try {
      _receive(await _channel.invokeMethod<Object?>('status'));
    } on MissingPluginException {
      if (mode == DesktopTitleBarMode.strip) {
        state.value = const DesktopTitleBarState();
      }
    }
  }

  void _receive(Object? value) {
    if (value is! Map) return;
    final height = value['height'];
    final fullscreen = value['fullscreen'];
    state.value = DesktopTitleBarState(
      height: mode == DesktopTitleBarMode.strip && height is num
          ? height.toDouble()
          : 0,
      fullscreen: fullscreen == true,
    );
  }

  /// Tell the runner the colours; repeated identical styles are dropped.
  Future<void> setStyle(DesktopTitleBarStyle style) async {
    if (mode == DesktopTitleBarMode.none || style == _sent) return;
    _sent = style;
    try {
      await _channel.invokeMethod<void>('setStyle', style.toArguments());
    } on MissingPluginException {
      // An older bundle: the window keeps its own title bar.
    }
  }

  String? _title;

  /// Names the OS window (task switcher, window list, screen readers). The
  /// strip itself stays text-free; repeated identical titles are dropped.
  Future<void> setTitle(String title) async {
    if (mode == DesktopTitleBarMode.none || title == _title) return;
    _title = title;
    try {
      await _channel.invokeMethod<void>('setTitle', {'title': title});
    } on MissingPluginException {
      // An older bundle: the window keeps the title it was created with.
    }
  }

  Future<void> startDragging() => _fire('startDragging');

  Future<void> doubleClick() => _fire('doubleClick');

  Future<void> _fire(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // An older bundle: the traffic lights still move the window.
    }
  }
}

/// Gives macOS its title strip, Linux its native bar colours, and Windows its
/// native caption colours plus a Flutter rule above [child]. Sits below the
/// theme so it follows every theme change.
class DesktopTitleBar extends StatefulWidget {
  const DesktopTitleBar({
    super.key,
    this.controller,
    this.workspace,
    required this.child,
  });

  final DesktopTitleBarController? controller;

  /// The open workspace: the window is titled after its conversation (Web
  /// `useBrowserDocumentTitle`), and plainly "Raft" without one.
  final WorkspaceController? workspace;
  final Widget child;

  @override
  State<DesktopTitleBar> createState() => _DesktopTitleBarState();
}

class _DesktopTitleBarState extends State<DesktopTitleBar> {
  DesktopTitleBarController get _controller =>
      widget.controller ?? DesktopTitleBarController.platform;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.start());
    widget.workspace?.addListener(_syncTitle);
    _syncTitle();
  }

  @override
  void didUpdateWidget(DesktopTitleBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.workspace, widget.workspace)) {
      oldWidget.workspace?.removeListener(_syncTitle);
      widget.workspace?.addListener(_syncTitle);
    }
    _syncTitle();
  }

  @override
  void dispose() {
    widget.workspace?.removeListener(_syncTitle);
    super.dispose();
  }

  void _syncTitle() {
    if (_controller.mode == DesktopTitleBarMode.none) return;
    unawaited(_controller.setTitle(workspaceWindowTitle(widget.workspace)));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Runs again whenever the theme changes, so a live switch is sent at once.
    unawaited(
      _controller.setStyle(DesktopTitleBarStyle.of(RaftTokens.of(context))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller.mode == DesktopTitleBarMode.none) return widget.child;
    if (controller.mode == DesktopTitleBarMode.native) return widget.child;
    final nativeCaption = controller.mode == DesktopTitleBarMode.nativeWithRule;
    return ValueListenableBuilder<DesktopTitleBarState>(
      valueListenable: controller.state,
      child: widget.child,
      builder: (context, state, child) => RaftDesktopTitleBar(
        // A strip only as tall as its border paints just the rule. DWM keeps
        // the actual caption height and all native window interactions.
        height: nativeCaption
            ? RaftTitleBarRecipe(RaftTokens.of(context)).ruleWidth
            : state.height,
        fullscreen: state.fullscreen,
        onDragStart: nativeCaption
            ? null
            : () => unawaited(controller.startDragging()),
        onDoubleTap: nativeCaption
            ? null
            : () => unawaited(controller.doubleClick()),
        child: child!,
      ),
    );
  }
}
