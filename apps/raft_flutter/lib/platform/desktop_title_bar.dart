import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'window_title.dart';
import 'desktop_caption_controls.dart';

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
  const DesktopTitleBarState({
    this.height = 0,
    this.fullscreen = false,
    this.leadingInset = 0,
    this.integrated = false,
    this.customControls = false,
    this.maximized = false,
    this.active = true,
    this.buttonLayout = ':minimize,maximize,close',
  });

  /// The title bar's height in logical pixels; zero when the window has none.
  final double height;

  /// Whether the window is fullscreen. macOS hides its title bar then.
  final bool fullscreen;

  /// Space reserved for the native traffic lights in an integrated row.
  final double leadingInset;

  /// The native host owns the shared frame even during a zero-height layout.
  final bool integrated;
  /// Capability flag: older runners retain their system decoration.
  final bool customControls, maximized, active;
  final String buttonLayout;

  @override
  bool operator ==(Object other) =>
      other is DesktopTitleBarState &&
      other.height == height &&
      other.fullscreen == fullscreen &&
      other.leadingInset == leadingInset &&
      other.integrated == integrated &&
      other.customControls == customControls &&
      other.maximized == maximized &&
      other.active == active &&
      other.buttonLayout == buttonLayout;

  @override
  int get hashCode => Object.hash(
    height,
    fullscreen,
    leadingInset,
    integrated,
    customControls,
    maximized,
    active,
    buttonLayout,
  );
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
  static const macosDefaultHeight = 48.0;

  /// Reference desktop traffic lights end at x=76; content starts at x=80.
  static const macosControlsInset = 80.0;

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
      leadingInset: mode == DesktopTitleBarMode.strip ? macosControlsInset : 0,
      integrated: mode == DesktopTitleBarMode.strip,
    ),
  );
  Future<void>? _starting;
  DesktopTitleBarStyle? _sent;

  /// Listen for the runner's reports and read the first one. Safe to call
  /// again; an older bundle without the channel keeps the defaults.
  Future<void> start() => _starting ??= _start();

  Future<void> _start() async {
    if (mode == DesktopTitleBarMode.none) return;
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
    final inset = value['leadingInset'];
    final integrated = value['integrated'] == true;
    final keepControls =
        mode == DesktopTitleBarMode.strip && integrated && fullscreen != true;
    final measuredInset = inset is num && inset.isFinite && inset >= 0
        ? inset.toDouble()
        : 0.0;
    state.value = DesktopTitleBarState(
      height:
          mode == DesktopTitleBarMode.strip &&
              height is num &&
              height.isFinite &&
              height >= 0
          ? height.toDouble()
          : 0,
      fullscreen: fullscreen == true,
      integrated: integrated,
      leadingInset: keepControls && measuredInset == 0
          ? (state.value.leadingInset > 0
                ? state.value.leadingInset
                : macosControlsInset)
          : measuredInset,
      customControls: value['customControls'] == true,
      maximized: value['maximized'] == true,
      active: value['active'] != false,
      buttonLayout: value['buttonLayout'] is String
          ? value['buttonLayout'] as String
          : ':minimize,maximize,close',
    );
  }

  (bool, double)? _integrated;

  /// Let the shared global row occupy the native titlebar's content area.
  /// Window controls remain native; the row reserves [state]'s leading inset.
  Future<void> setIntegrated(bool enabled, {double height = 48}) async {
    await start();
    if (mode == DesktopTitleBarMode.none || _integrated == (enabled, height)) {
      return;
    }
    _integrated = (enabled, height);
    try {
      _receive(
        await _channel.invokeMethod<Object?>('setIntegrated', {
          'enabled': enabled,
          'height': height,
        }),
      );
    } on MissingPluginException {
      // Older runners keep their original native window controls.
    }
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

  Future<void> captionAction(String action) => _fire(action);
  Map<String, Object>? _captionRects;
  Future<void> setCaptionButtonRects(Map<String, Object> rects) async {
    final old = _captionRects;
    if (old != null &&
        old.length == rects.length &&
        rects.entries.every(
          (entry) => mapEquals(old[entry.key] as Map?, entry.value as Map),
        )) {
      return;
    }
    _captionRects = rects;
    try {
      await _channel.invokeMethod<void>('setCaptionButtonRects', rects);
    } on MissingPluginException {
      // Older runners keep native hit testing.
    }
  }

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
    this.integrated = false,
    this.integratedHeight = 48,
    required this.child,
  });

  final DesktopTitleBarController? controller;

  /// The open workspace: the window is titled after its conversation (Web
  /// `useBrowserDocumentTitle`), and plainly "Raft" without one.
  final WorkspaceController? workspace;

  /// True while the shared global toolbar occupies the top of the window.
  /// It replaces the macOS empty strip, including in fullscreen.
  final bool integrated;
  final double integratedHeight;
  final Widget child;

  @override
  State<DesktopTitleBar> createState() => _DesktopTitleBarState();
}

class _DesktopTitleBarState extends State<DesktopTitleBar> {
  // Native chrome changes the wrappers above the router. Keep its state and
  // accepted workspace page when entering integrated mode or fullscreen.
  final _contentKey = GlobalKey();

  DesktopTitleBarController get _controller =>
      widget.controller ?? DesktopTitleBarController.platform;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.start());
    _syncLayout();
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
    _syncLayout();
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

  void _syncLayout() => unawaited(
    _controller.setIntegrated(
      _controller.mode == DesktopTitleBarMode.strip || widget.integrated,
      height: widget.integratedHeight,
    ),
  );

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
    final nativeCaption = controller.mode == DesktopTitleBarMode.nativeWithRule;
    return ValueListenableBuilder<DesktopTitleBarState>(
      valueListenable: controller.state,
      child: KeyedSubtree(key: _contentKey, child: widget.child),
      builder: (context, state, child) {
        final macFrame =
            controller.mode == DesktopTitleBarMode.strip &&
            (state.integrated || state.height > 0 || state.fullscreen);
        final custom = state.customControls;
        final windows = controller.mode == DesktopTitleBarMode.nativeWithRule;
        final layout = DesktopCaptionLayout.parse(state.buttonLayout);
        final showButtons = custom && !state.fullscreen;
        final leading = showButtons
            ? layout.inset(layout.leading, windows: windows)
            : 0.0;
        final trailing = showButtons
            ? layout.inset(layout.trailing, windows: windows)
            : 0.0;
        final draggable =
            widget.integrated &&
            (custom ||
                (controller.mode == DesktopTitleBarMode.strip ||
                    controller.mode == DesktopTitleBarMode.native));
        final content = DesktopTitleBarScope(
          leadingInset: custom
              ? leading
              : widget.integrated && !state.fullscreen
              ? state.leadingInset
              : 0,
          trailingInset: trailing,
          onDragStart: draggable
              ? () => unawaited(controller.startDragging())
              : null,
          onDoubleTap: draggable
              ? () => unawaited(controller.doubleClick())
              : null,
          child: RaftWindowChromeScope(
            // ds-allow: native window-control bounds, independent of theme spacing.
            overlayInsets: EdgeInsets.only(
              top: (macFrame || custom) && widget.integrated && !state.fullscreen
                  ? widget.integratedHeight
                  : 0,
            ),
            child: RaftAuthHeaderScope(
              external: (macFrame || custom) && !widget.integrated,
              child: child!,
            ),
          ),
        );
        if (controller.mode == DesktopTitleBarMode.strip && !macFrame) {
          return content;
        }
        if (custom) {
          final body = widget.integrated
              ? content
              : RaftDesktopTitleBar(
                  height: widget.integratedHeight,
                  title: Padding(
                    // ds-allow: native caption content inset measured from Desktop 1.21.33.
                    padding: EdgeInsets.only(left: leading + 32),
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: RaftBrandMark(RaftBrandMarkKind.logo, height: 20),
                    ),
                  ),
                  onDragStart: () => unawaited(controller.startDragging()),
                  onDoubleTap: () => unawaited(controller.doubleClick()),
                  child: content,
                );
          return Stack(
            fit: StackFit.expand,
            children: [
              body,
              Positioned.fill(
                // The title bar sits above the Router, so its tooltips need
                // their own full-window overlay. Only caption targets hit-test;
                // empty space continues through to the toolbar and body.
                child: Overlay.wrap(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: widget.integratedHeight,
                      child: DesktopCaptionControls(
                        layout: layout,
                        windows: windows,
                        visible: showButtons,
                        maximized: state.maximized,
                        active: state.active,
                        onAction: (action) =>
                            unawaited(controller.captionAction(action)),
                        onRects: (rects) =>
                            unawaited(controller.setCaptionButtonRects(rects)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        if (controller.mode == DesktopTitleBarMode.native ||
            (widget.integrated && !nativeCaption)) {
          return content;
        }
        return RaftDesktopTitleBar(
          // A strip only as tall as its border paints just the rule. DWM keeps
          // the actual caption height and all native window interactions.
          height: nativeCaption
              ? RaftTitleBarRecipe(RaftTokens.of(context)).ruleWidth
              : widget.integratedHeight,
          // Non-workspace Mac pages retain the same branded row in fullscreen.
          fullscreen: nativeCaption && state.fullscreen,
          title: nativeCaption
              ? null
              : Padding(
                  // ds-allow: measured native traffic-light geometry, not theme spacing.
                  padding: const EdgeInsets.only(
                    left: DesktopTitleBarController.macosControlsInset + 2,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: const RaftBrandMark(
                      RaftBrandMarkKind.logo,
                      height: 20,
                    ),
                  ),
                ),
          onDragStart: nativeCaption
              ? null
              : () => unawaited(controller.startDragging()),
          onDoubleTap: nativeCaption
              ? null
              : () => unawaited(controller.doubleClick()),
          child: content,
        );
      },
    );
  }
}

/// Native window geometry and actions for the shared global toolbar. Only its
/// empty areas use these callbacks; buttons keep their own gesture handling.
class DesktopTitleBarScope extends InheritedWidget {
  const DesktopTitleBarScope({
    super.key,
    required this.leadingInset,
    this.trailingInset = 0,
    this.onDragStart,
    this.onDoubleTap,
    required super.child,
  });

  final double leadingInset, trailingInset;
  final VoidCallback? onDragStart;
  final VoidCallback? onDoubleTap;

  static DesktopTitleBarScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesktopTitleBarScope>();

  @override
  bool updateShouldNotify(DesktopTitleBarScope oldWidget) =>
      leadingInset != oldWidget.leadingInset ||
      trailingInset != oldWidget.trailingInset ||
      onDragStart != oldWidget.onDragStart ||
      onDoubleTap != oldWidget.onDoubleTap;
}
