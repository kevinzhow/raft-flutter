import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

/// How long a `/settings/<tab>#<id>` link waits for a section that renders
/// after its data loads (Web useScrollToSettingsSection `WAIT_MS`).
const settingsAnchorWait = Duration(seconds: 5);

/// The jumps of one Settings surface. A page's sections mount and unmount as
/// their data loads, so each [RaftSettingsAnchor] registers here and a
/// pending jump finishes the moment its section is on screen, or is dropped
/// after [settingsAnchorWait] (no timer left on the page).
///
/// Web `features/settings/shared/useScrollToSettingsSection.ts`: scroll the
/// section to the top once per jump, mark it located
/// (design/foundations/states.md#located), and move focus to it when the
/// keyboard started the jump.
class SettingsAnchorRegistry {
  final _anchors = <String, _RaftSettingsAnchorState>{};
  _Jump? _pending;
  Timer? _timer;
  bool _disposed = false;

  /// Starts a jump to [id]; a new jump replaces one still waiting. Opening the
  /// same id again is a new jump, which locates it again.
  void jump(String id, {bool fromKeyboard = false}) {
    if (_disposed || id.isEmpty) return;
    _timer?.cancel();
    final jump = _pending = _Jump(id, fromKeyboard);
    _timer = Timer(settingsAnchorWait, () {
      if (identical(_pending, jump)) _pending = null;
    });
    _resolveAfterFrame(jump);
  }

  void _resolveAfterFrame(_Jump jump) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !identical(_pending, jump)) return;
      final anchor = _anchors[jump.id];
      if (anchor == null || !anchor.mounted) return;
      _pending = null;
      _timer?.cancel();
      anchor.reveal(focus: jump.fromKeyboard);
    });
  }

  void _register(String id, _RaftSettingsAnchorState state) {
    assert(
      _anchors[id] == null || identical(_anchors[id], state),
      'Settings anchor "$id" is on two rows of one page',
    );
    _anchors[id] = state;
    final jump = _pending;
    if (jump != null && jump.id == id) _resolveAfterFrame(jump);
  }

  void _unregister(String id, _RaftSettingsAnchorState state) {
    if (identical(_anchors[id], state)) _anchors.remove(id);
  }

  /// Whether a jump is still waiting for its section (tests).
  bool get waiting => _pending != null;

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _pending = null;
    _anchors.clear();
  }
}

class _Jump {
  const _Jump(this.id, this.fromKeyboard);
  final String id;
  final bool fromKeyboard;
}

/// Provides the [SettingsAnchorRegistry] to the sections of one Settings
/// surface.
class SettingsAnchorScope extends InheritedWidget {
  const SettingsAnchorScope({
    super.key,
    required this.registry,
    required super.child,
  });
  final SettingsAnchorRegistry registry;

  static SettingsAnchorRegistry? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<SettingsAnchorScope>()
      ?.registry;

  @override
  bool updateShouldNotify(SettingsAnchorScope old) =>
      !identical(registry, old.registry);
}

/// The target of `/settings/<tab>#<id>` and of a Settings search result: the
/// row (or section) of the setting with this index id. Exactly one per page
/// and id (Web `settingsSearchAnchors.test.ts`: `id="<id>"` on the row).
///
/// Outside a Settings surface it is transparent.
class RaftSettingsAnchor extends StatefulWidget {
  const RaftSettingsAnchor({super.key, required this.id, required this.child});

  /// The settings search index id (`two-step`, `delete-account`, ...).
  final String id;
  final Widget child;

  @override
  State<RaftSettingsAnchor> createState() => _RaftSettingsAnchorState();
}

class _RaftSettingsAnchorState extends State<RaftSettingsAnchor>
    with SingleTickerProviderStateMixin {
  final FocusNode _focus = FocusNode(
    debugLabel: 'settings-anchor',
    skipTraversal: true,
  );
  late final AnimationController _located = AnimationController(
    vsync: this,
    duration: raftLocatedDuration,
  );
  SettingsAnchorRegistry? _registry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = SettingsAnchorScope.maybeOf(context);
    if (!identical(next, _registry)) {
      _registry?._unregister(widget.id, this);
      _registry = next?.._register(widget.id, this);
    }
  }

  @override
  void didUpdateWidget(RaftSettingsAnchor old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      _registry?._unregister(old.id, this);
      _registry?._register(widget.id, this);
    }
  }

  @override
  void dispose() {
    _registry?._unregister(widget.id, this);
    _located.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Scrolls the section to the top of its scroll view, washes it
  /// `info-soft` (held to 1.2 s, gone by 2 s) and, after a keyboard jump,
  /// takes focus (Web `focusJumpTarget`).
  void reveal({required bool focus}) {
    if (!mounted) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0,
      duration: Duration.zero,
    );
    _located.forward(from: 0);
    if (focus) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final wash = t.colors['info-soft']!;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Focus(
      focusNode: _focus,
      includeSemantics: false,
      child: AnimatedBuilder(
        animation: _located,
        child: widget.child,
        builder: (context, child) {
          final v = _located.value;
          // Held to 1.2 s, then faded out by 2 s.
          final fade = v == 0 || v == 1
              ? 0.0
              : reduce
              ? (v < .6 ? 1.0 : 0.0)
              : (1 - (v - .6) / .4).clamp(0.0, 1.0);
          return DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(t.fieldRadius),
              color: wash.withValues(alpha: wash.a * fade),
            ),
            child: child,
          );
        },
      ),
    );
  }
}
