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
    this.onCreateTask,
    this.moves = const [],
    this.onCollapsedChanged,
    this.onExpand,
    this.expanded = false,
    this.collapsed = false,
    this.stackEnd = false,
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

  /// The Tasks header’s own action, also reachable from its overflow menu.
  final VoidCallback? onCreateTask;
  final List<RaftMenuEntry> moves;

  /// Set where the card shares its column and may fold.
  final ValueChanged<bool>? onCollapsedChanged;
  final VoidCallback? onExpand;
  final bool expanded;
  final bool collapsed, stackEnd;
  final ChannelSideHeadWrapper? headWrapper;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final covering = mode == ChannelSideMode.overlay;
    final id = 'channel-side-card-${section.name}';
    final foldable = onCollapsedChanged != null;
    final moreActions = raftText(context, 'More actions');
    final collapseLabel = raftFormat(
      context,
      collapsed ? 'Expand {title}' : 'Collapse {title}',
      {'title': title},
    );
    final newTask = raftText(context, 'New task');
    final head = LayoutBuilder(
      builder: (context, box) {
        final leadingInset = foldable && !phone ? RaftSpace.x3 : null;
        // Web headFit reserves room for the title and surface controls before
        // adding the card's own action. A clipped column uses the small icons
        // so its essential actions stay operable at the 160px column floor.
        final leadingWidth = foldable ? 40.0 : 0.0;
        final controls = (onExpand == null ? 0 : 1) + (covering ? 0 : 1);
        final actions = controls + (moves.isEmpty ? 0 : 1) + 1;
        final showCreate = !collapsed && onCreateTask != null;
        final createInline =
            showCreate &&
            (covering ||
                box.maxWidth >=
                    (foldable ? 13 : 20) +
                        13 +
                        leadingWidth +
                        56 +
                        actions * RaftMetrics.buttonMd +
                        (actions - 1) * RaftSpace.x1);
        final menu = [
          if (showCreate && !createInline)
            RaftMenuEntry(
              label: newTask,
              glyph: RaftGlyph.plus,
              onPressed: onCreateTask,
            ),
          ...moves,
        ];
        final compactActions =
            !covering && box.maxWidth < channelSideCompactHeaderWidth;
        final desktopBar = t.desktop && !covering && !compactActions;
        final actionSize = compactActions
            ? RaftButtonSize.iconXs
            : RaftButtonSize.iconSm;
        final bar = RaftPanelHeaderBar(
          key: Key('$id-header'),
          title: title,
          leftPadding: leadingInset,
          desktopBar: desktopBar,
          background: t.colors['layer-canvas'],
          bottomRule: true,
          bottomBorder: stackEnd
              ? const Border()
              : RaftSidePanelFrame.headerRule(t),
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
                    ghostSize: covering ? null : actionSize,
                    desktopBar: desktopBar,
                    onPressed: () => onCollapsedChanged!(!collapsed),
                    minHitExtent: RaftMetrics.touchTarget,
                  ),
                )
              : null,
          actions: [
            if (createInline)
              RaftPanelAction(
                key: const Key('channel-tasks-panel-new'),
                glyph: RaftGlyph.plus,
                tooltip: newTask,
                ghostSize: covering ? null : actionSize,
                desktopBar: desktopBar,
                minHitExtent: RaftMetrics.touchTarget,
                onPressed: onCreateTask,
              ),
            if (menu.isNotEmpty)
              RaftDropdownMenu(
                key: Key('$id-overflow'),
                label: moreActions,
                kind: RaftMenuKind.dropdownMenu,
                align: RaftDropdownAlign.end,
                sideOffset: RaftSpace.x1,
                entries: menu,
                triggerBuilder: (context, focus, onPressed) => RaftPanelAction(
                  tooltip: moreActions,
                  glyph: RaftGlyph.ellipsisVertical,
                  ghostSize: actionSize,
                  desktopBar: desktopBar,
                  focusNode: focus,
                  onPressed: onPressed,
                ),
              ),
            if (onExpand != null)
              raftConversationHeaderToggle(
                key: Key('$id-expand'),
                glyph: expanded ? RaftGlyph.minimize2 : RaftGlyph.maximize2,
                label: raftText(context, expanded ? 'Restore' : 'Expand'),
                pressed: expanded,
                desktopBar: desktopBar,
                size: actionSize,
                onPressed: onExpand,
              ),
            if (!covering)
              RaftPanelAction(
                key: Key('$id-close'),
                glyph: RaftGlyph.x,
                tooltip: closeLabel,
                ghostSize: actionSize,
                desktopBar: desktopBar,
                onPressed: onClose,
                minHitExtent: RaftMetrics.touchTarget,
              ),
          ],
        );
        return headWrapper?.call(context, section, bar) ?? bar;
      },
    );
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
