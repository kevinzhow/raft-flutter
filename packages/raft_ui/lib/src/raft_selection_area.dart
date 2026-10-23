import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter/services.dart';

import 'design_primitives.dart';
import 'selected_text_quote.dart';
import 'text_selection_toolbar.dart';

/// [SelectionArea] whose touch selection ends with the next touch elsewhere.
///
/// Flutter keeps a touch selection (highlight, handles) until the same text is
/// tapped again: only Web unfocuses a [SelectableRegion] on an outside tap. The
/// message timeline hides the platform toolbar, so a phone user has no Copy /
/// Clear button either, and the selection stays on screen like a stuck desktop
/// hover. A touch or stylus press outside every selectable region clears it.
/// The shared [SelectableRegion] tap group keeps taps on the selection handles
/// and on other selectable regions "inside". Mouse and trackpad keep Flutter's
/// desktop behaviour (the selection stays until replaced).
class RaftSelectionArea extends StatefulWidget {
  const RaftSelectionArea({
    super.key,
    required this.child,
    this.contextMenuBuilder = _platformToolbar,
    this.shortcut,
  });
  final Widget child;
  final SelectableRegionContextMenuBuilder? contextMenuBuilder;

  /// Web `MessageSelectionShortcut`: a mouse selection here shows Quote / Copy
  /// beside it.
  final RaftSelectionShortcut? shortcut;

  static Widget _platformToolbar(
    BuildContext context,
    SelectableRegionState state,
  ) => RaftTextSelectionToolbar.selectableRegion(context, state);

  /// The platform Copy / Select all toolbar for a touch selection, nothing
  /// for a mouse or trackpad. For areas whose desktop right-click belongs to
  /// the host (a message row's action menu) but whose phone selection still
  /// needs its Copy / Select all toolbar: the host hides the platform
  /// toolbar everywhere, so without this a long-press selection on a phone
  /// has no way to copy.
  static Widget touchToolbarOnly(
    BuildContext context,
    SelectableRegionState state,
  ) {
    // The density scope falls back to the platform (phones are touch).
    return RaftDensityScope.of(context) == RaftDensity.touch
        ? _platformToolbar(context, state)
        : const SizedBox.shrink();
  }

  @override
  State<RaftSelectionArea> createState() => _RaftSelectionAreaState();
}

class _RaftSelectionAreaState extends State<RaftSelectionArea> {
  /// Context inside the area: its [SelectableRegionState] is the nearest
  /// ancestor state (no per-row GlobalKey).
  BuildContext? inside;

  Timer? shortcutTimer;
  String selected = '';
  bool pointerDown = false;
  OverlayEntry? shortcutEntry;

  SelectableRegionState? get region => inside?.mounted == true
      ? inside!.findAncestorStateOfType<SelectableRegionState>()
      : null;

  void outsidePress(PointerDownEvent event) {
    hideShortcut();
    if (event.kind == PointerDeviceKind.mouse ||
        event.kind == PointerDeviceKind.trackpad) {
      return;
    }
    region?.clearSelection();
  }

  void selectionChanged(SelectedContent? content) {
    selected = content?.plainText ?? '';
    if (!pointerDown) scheduleShortcut();
  }

  void scheduleShortcut() {
    final shortcut = widget.shortcut;
    if (shortcut == null) return;
    shortcutTimer?.cancel();
    hideShortcut();
    if (!raftHasQuotableSelection(selected)) return;
    shortcutTimer = Timer(raftSelectionShortcutDelay, showShortcut);
  }

  /// The pair beside the selection: the platform toolbar's own layout, placed
  /// from the selection's anchors, as an overlay of its own (the region only
  /// shows its toolbar for a right click or a long press, which belong to the
  /// message menu).
  void showShortcut() {
    final shortcut = widget.shortcut, state = region, context = inside;
    if (shortcut == null ||
        state == null ||
        context == null ||
        !context.mounted ||
        RaftDensityScope.of(context) == RaftDensity.touch) {
      return;
    }
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    shortcut.text = selected;
    final anchors = state.contextMenuAnchors;
    shortcutEntry = OverlayEntry(
      builder: (overlayContext) => TapRegion(
        groupId: SelectableRegion,
        child: RaftSelectionShortcutBar(
          anchors: anchors,
          onQuote: () {
            if (raftHasQuotableSelection(shortcut.text)) {
              shortcut.onQuote(shortcut.text);
            }
            state.clearSelection();
            hideShortcut();
          },
          onCopy: () {
            Clipboard.setData(ClipboardData(text: shortcut.text));
            state.clearSelection();
            hideShortcut();
          },
        ),
      ),
    );
    overlay.insert(shortcutEntry!);
    HardwareKeyboard.instance.addHandler(escapeShortcut);
  }

  /// Web: Escape closes the pair (it never consumes the key).
  bool escapeShortcut(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      hideShortcut();
    }
    return false;
  }

  void hideShortcut() {
    HardwareKeyboard.instance.removeHandler(escapeShortcut);
    shortcutEntry?.remove();
    shortcutEntry?.dispose();
    shortcutEntry = null;
  }

  @override
  void dispose() {
    shortcutTimer?.cancel();
    hideShortcut();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TapRegion(
    groupId: SelectableRegion,
    onTapOutside: outsidePress,
    // ignore: raft_lints/avoid_bare_selection_area -- this is the wrapper
    child: Listener(
      onPointerDown: (_) {
        pointerDown = true;
        hideShortcut();
      },
      onPointerUp: (_) {
        pointerDown = false;
        scheduleShortcut();
      },
      onPointerCancel: (_) => pointerDown = false,
      // ignore: raft_lints/avoid_bare_selection_area -- this is the wrapper
      child: SelectionArea(
        contextMenuBuilder: widget.contextMenuBuilder,
        onSelectionChanged: widget.shortcut == null ? null : selectionChanged,
        child: Builder(
          builder: (context) {
            inside = context;
            return widget.child;
          },
        ),
      ),
    ),
  );
}
