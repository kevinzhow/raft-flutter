import 'raft/list_row_action.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'hover_region.dart';
import 'design_primitives.dart';
import 'icons.dart';
import 'theme.dart';

/// Web ThreadsInbox `InboxRow` in its `list` layout (`activity_conversation_list_v0`):
/// one avatar row per conversation, `flex gap-3 px-4 py-3`, a hairline between
/// consecutive rows that starts where the text starts, a pressed wash on hover
/// and a soft info wash for the row open beside the list. The row's own action
/// (Done) is an ink-outline button that takes the side column's place while it
/// shows (pointer and keyboard only: on touch the long-press menu carries it).
class RaftConversationListRow extends StatefulWidget {
  const RaftConversationListRow({
    super.key,
    required this.leading,
    required this.title,
    required this.body,
    required this.onOpen,
    this.titleTrailing = const [],
    this.timestamp,
    this.bodyTrailing = const [],
    this.strong = false,
    this.selected = false,
    this.popupOpen = false,
    this.separator = false,
    this.action,
    this.onContextMenu,
    this.onActivate,
    this.onPointerActivate,
    this.doubleClickInterval = kDoubleTapTimeout,
    this.semanticLabel,
  });

  /// The 36px leading visual ([RaftConversationAvatarTile] or a peer's face).
  final Widget leading;

  /// First line: [title] (one line, ellipsis), then [titleTrailing] (the task
  /// badge) and [timestamp].
  final Widget title;
  final List<Widget> titleTrailing;
  final Widget? timestamp;

  /// Second line: [body] (one line, ellipsis), then [bodyTrailing] (draft
  /// mark, @ mark, unread count or muted bell).
  final Widget body;
  final List<Widget> bodyTrailing;

  /// Unread and not muted: the title and preview read as strong.
  final bool strong;
  final bool selected, popupOpen;

  /// A hairline above the row, from where the text starts. False for the
  /// first row and for the first row under a section heading.
  final bool separator;
  final Widget? action;
  final VoidCallback onOpen;
  final ValueChanged<Offset>? onContextMenu;
  final ValueChanged<int>? onActivate, onPointerActivate;
  final Duration doubleClickInterval;
  final String? semanticLabel;

  /// Whether the row's action is showing (the side column steps aside).
  static bool actionVisibleOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_ListRowActionScope>()
          ?.visible ??
      false;

  static TextStyle titleStyle(RaftTokens t, bool strong) =>
      RaftTypography.body(
        t,
        size: 16,
        line: 20,
        color: strong ? t.strong : t.muted,
      ).copyWith(
        fontFamily: t.headingFont,
        fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
      );

  static TextStyle bodyStyle(RaftTokens t, bool strong) => RaftTypography.body(
    t,
    size: 13,
    line: 18,
    color: strong ? t.strong : t.muted,
  ).copyWith(fontFamily: t.headingFont);

  static TextStyle timestampStyle(RaftTokens t) => RaftTypography.mono(
    t,
    size: 12,
    line: 20,
    color: t.colors['foreground-placeholder'],
  );

  @override
  State<RaftConversationListRow> createState() =>
      _RaftConversationListRowState();
}

class _RaftConversationListRowState extends State<RaftConversationListRow> {
  bool hovered = false, focused = false;
  final focusNode = FocusNode(debugLabel: 'conversation-list-row');
  Offset? lastPointer;
  Duration? pendingTapTime, lastTapTime;
  Offset? pendingTapPosition, lastTapPosition;
  int clickCount = 0;

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  void openContextMenu(Offset at) {
    focusNode.requestFocus();
    widget.onContextMenu?.call(at);
  }

  void deliverActivation() {
    final callback = pendingTapPosition != null
        ? widget.onPointerActivate ?? widget.onActivate
        : widget.onActivate;
    if (callback == null) {
      widget.onOpen();
      return;
    }
    final time = pendingTapTime, position = pendingTapPosition;
    final interval = time != null && lastTapTime != null
        ? time - lastTapTime!
        : null;
    final repeat =
        interval != null &&
        interval >= Duration.zero &&
        interval <= widget.doubleClickInterval &&
        position != null &&
        lastTapPosition != null &&
        (position - lastTapPosition!).distance <= kDoubleTapSlop;
    clickCount = repeat ? clickCount + 1 : 1;
    lastTapTime = time;
    lastTapPosition = position;
    pendingTapTime = null;
    pendingTapPosition = null;
    callback(clickCount);
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final touch = RaftDensityScope.of(context) == RaftDensity.touch;
    // `[@media(hover:none)]:hidden`: touch has no row action.
    final showAction =
        widget.action != null &&
        !touch &&
        (hovered || focused || widget.popupOpen);
    final fill = widget.selected
        ? t.colors['info-soft']!
        : hovered || widget.popupOpen
        ? t.colors['fill-muted']!
        : Colors.transparent;
    final fade = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 150);
    return _ListRowActionScope(
      visible: showAction,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (value) => setState(() => focused = value),
        child: RaftHoverRegion(
          onEnter: (_) => setState(() => hovered = true),
          onExit: (_) => setState(() => hovered = false),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) => lastPointer = e.position,
            child: Material(
              color: fill,
              child: RaftListRowAction(
                selected: widget.selected,
                semanticLabel: widget.semanticLabel,
                onTapDown:
                    widget.onActivate == null &&
                        widget.onPointerActivate == null
                    ? null
                    : (details) {
                        pendingTapTime = SchedulerBinding
                            .instance
                            .currentSystemFrameTimeStamp;
                        pendingTapPosition = details.globalPosition;
                      },
                onTapCancel: () {
                  pendingTapTime = null;
                  pendingTapPosition = null;
                },
                onPressed: deliverActivation,
                focusNode: focusNode,
                onLongPress: widget.onContextMenu == null
                    ? null
                    : () => openContextMenu(lastPointer ?? Offset.zero),
                onSecondaryTapDown: widget.onContextMenu == null
                    ? null
                    : (details) => openContextMenu(details.globalPosition),
                child: Stack(
                  children: [
                    if (widget.separator)
                      Positioned(
                        left: 64,
                        right: 0,
                        top: 0,
                        height: 1,
                        child: ColoredBox(color: t.colors['line-hairline']!),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          widget.leading,
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: DefaultTextStyle.merge(
                                        style:
                                            RaftConversationListRow.titleStyle(
                                              t,
                                              widget.strong,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        child: widget.title,
                                      ),
                                    ),
                                    for (final badge
                                        in widget.titleTrailing) ...[
                                      const SizedBox(width: 8),
                                      badge,
                                    ],
                                    if (widget.timestamp != null) ...[
                                      const SizedBox(width: 8),
                                      AnimatedOpacity(
                                        opacity: showAction ? 0 : 1,
                                        duration: fade,
                                        child: DefaultTextStyle.merge(
                                          style:
                                              RaftConversationListRow.timestampStyle(
                                                t,
                                              ),
                                          child: widget.timestamp!,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DefaultTextStyle.merge(
                                        style:
                                            RaftConversationListRow.bodyStyle(
                                              t,
                                              widget.strong,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        child: widget.body,
                                      ),
                                    ),
                                    for (final mark in widget.bodyTrailing) ...[
                                      const SizedBox(width: 8),
                                      AnimatedOpacity(
                                        opacity: showAction ? 0 : 1,
                                        duration: fade,
                                        child: mark,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.action != null)
                      Positioned(
                        right: 12,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: ExcludeSemantics(
                            excluding: !showAction,
                            child: IgnorePointer(
                              ignoring: !showAction,
                              child: AnimatedOpacity(
                                opacity: showAction ? 1 : 0,
                                duration: fade,
                                child: widget.action,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                decorate: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListRowActionScope extends InheritedWidget {
  const _ListRowActionScope({required this.visible, required super.child});
  final bool visible;
  @override
  bool updateShouldNotify(_ListRowActionScope oldWidget) =>
      visible != oldWidget.visible;
}

enum RaftConversationAvatarKind { channel, dm, thread }

/// List-layout leading visual: a `#` tile for a channel (a place, not a face),
/// the peer's own face for a DM ([face]), and a `#` tile with a small thread
/// mark for a thread.
class RaftConversationAvatarTile extends StatelessWidget {
  const RaftConversationAvatarTile({super.key, required this.kind, this.face});
  final RaftConversationAvatarKind kind;

  /// The peer's avatar for a DM.
  final Widget? face;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (kind == RaftConversationAvatarKind.dm && face != null) {
      return SizedBox.square(
        key: const ValueKey('conversation-card-avatar'),
        dimension: 36,
        child: Center(child: face),
      );
    }
    final muted = t.colors['foreground-muted']!;
    return SizedBox.square(
      key: const ValueKey('conversation-card-avatar'),
      dimension: 36,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: t.colors['fill-muted'],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: kind == RaftConversationAvatarKind.dm
                    ? RaftDirectMessageIcon(size: 16, color: muted)
                    : RaftIcon(RaftGlyph.hash, size: 16, color: muted),
              ),
            ),
          ),
          if (kind == RaftConversationAvatarKind.thread)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.colors['layer-card'],
                  border: Border.all(color: t.colors['line-muted']!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: RaftThreadIcon(size: 11, color: muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// ThreadsInbox `SectionEyebrow` over the list ("Pinned" with a pin,
/// "All conversations"): `flex items-center gap-1.5 px-4 pb-1`, `pt-2` for the
/// first heading and `pt-4` after a section.
class RaftActivityListSection extends StatelessWidget {
  const RaftActivityListSection({
    super.key,
    required this.label,
    this.pinned = false,
    this.first = false,
  });
  final String label;
  final bool pinned, first;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final color = t.colors['foreground-muted']!;
    return Padding(
      key: const ValueKey('activity-list-section'),
      padding: EdgeInsets.fromLTRB(16, first ? 8 : 16, 16, 4),
      child: Row(
        children: [
          if (pinned) ...[
            RaftIcon(RaftGlyph.pin, size: 12, color: color),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RaftTypography.body(t, size: 12, line: 16, color: color)
                  .copyWith(
                    fontFamily: t.headingFont,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The task chip of a list row's title line: the status mark and `#N`.
class RaftListRowTaskBadge extends StatelessWidget {
  const RaftListRowTaskBadge({
    super.key,
    required this.status,
    required this.label,
  });
  final Widget status;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [status, const SizedBox(width: 4), Text(label, maxLines: 1)],
  );
}

/// The sender in front of a list row's preview: their small face, then their
/// name in bold. [face] is optional (a system line has none).
class RaftListRowSender {
  const RaftListRowSender._();

  static InlineSpan face(Widget face) => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(padding: const EdgeInsets.only(right: 4), child: face),
  );

  static InlineSpan name(BuildContext context, String name) => TextSpan(
    text: '$name: ',
    style: TextStyle(
      fontWeight: FontWeight.w600,
      color: RaftTokens.of(context).strong,
    ),
  );
}
