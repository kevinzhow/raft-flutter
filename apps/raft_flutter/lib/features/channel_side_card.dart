// The shell of a section beside the conversation: Tasks (Web v1.24
// `ChannelSideCard.tsx`). The column head every panel has (56px, a seam under
// it), then the body; the area (ChannelSideArea) says where the card stands and
// the card draws what that needs:
//   - covering the conversation on a phone: no X, the header's Back closes it;
//   - covering it on a narrow desktop panel: its own Back (there is no header
//     Back there), no X;
//   - stacked with another section: a chevron folds it to its head, the body
//     stays mounted;
//   - otherwise: X.
// Escape does not close it (Web passes no `closeOnEscape` for these two).
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'channel_side_layout.dart';

/// Where a card sits; the area decides, the card reads it.
enum ChannelSideMode { beside, float, overlay }

/// What the drag agent wraps around a card's head (the handle that moves the
/// section among the columns). Receives the section and the finished head.
typedef ChannelSideHeadWrapper = Widget Function(
  BuildContext context,
  ChannelSideSection section,
  Widget head,
);

class ChannelSideCardView extends StatelessWidget {
  const ChannelSideCardView({
    super.key,
    required this.section,
    required this.title,
    required this.closeLabel,
    required this.onClose,
    required this.mode,
    required this.phone,
    required this.child,
    this.actions = const [],
    this.onCollapsedChanged,
    this.collapsed = false,
    this.headWrapper,
  });

  final ChannelSideSection section;
  final String title;

  /// "Close Tasks": the X's tooltip, and a covering card's Back label.
  final String closeLabel;
  final VoidCallback onClose;
  final ChannelSideMode mode;

  /// A phone: the channel header's Back closes the covering card, so the card
  /// draws no Back and no X of its own.
  final bool phone;

  /// Its own buttons, before the X (Tasks: "+ New task").
  final List<Widget> actions;

  /// Set where the card shares its column and may fold.
  final ValueChanged<bool>? onCollapsedChanged;
  final bool collapsed;
  final ChannelSideHeadWrapper? headWrapper;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final covering = mode == ChannelSideMode.overlay;
    final id = 'channel-side-card-${section.name}';
    final foldable = onCollapsedChanged != null;
    final collapseLabel = raftFormat(
      context,
      collapsed ? 'Expand {title}' : 'Collapse {title}',
      {'title': title},
    );
    Widget head = RaftPanelHeaderBar(
      key: Key('$id-header'),
      title: title,
      background: t.colors['layer-canvas'],
      bottomRule: true,
      onBack: covering && !phone ? onClose : null,
      backKey: Key('$id-back'),
      backTooltip: closeLabel,
      leading: foldable
          ? Semantics(
              expanded: !collapsed,
              child: RaftPanelAction(
                key: Key('$id-collapse'),
                glyph: collapsed
                    ? RaftGlyph.chevronRight
                    : RaftGlyph.chevronDown,
                tooltip: collapseLabel,
                onPressed: () => onCollapsedChanged!(!collapsed),
                minHitExtent: RaftMetrics.touchTarget,
              ),
            )
          : null,
      actions: [
        if (!collapsed) ...actions,
        if (!covering)
          RaftPanelAction(
            key: Key('$id-close'),
            glyph: RaftGlyph.x,
            tooltip: closeLabel,
            onPressed: onClose,
            minHitExtent: RaftMetrics.touchTarget,
          ),
      ],
    );
    head = headWrapper?.call(context, section, head) ?? head;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: title,
      child: ColoredBox(
        key: Key(id),
        color: t.colors['layer-canvas']!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            head,
            // Folded, the body stays mounted (its scroll, its folded lanes)
            // and only hides.
            Expanded(
              child: Offstage(offstage: collapsed, child: child),
            ),
          ],
        ),
      ),
    );
  }
}
