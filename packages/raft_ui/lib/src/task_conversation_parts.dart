// Task v2 dialog chrome (Web v1.24 TaskConversationDialog.tsx): the bar that
// names the task by its ref and holds the More menu, and the facts the
// dialog adds to the task's properties. The app owns every command.
import 'package:flutter/material.dart';

import 'channel_header.dart' show raftConversationHeaderToggle;
import 'design_primitives.dart';
import 'icons.dart';
import 'interaction.dart';
import 'localization.dart';
import 'raft/button.dart';
import 'raft/ui_tokens.dart';
import 'task_head_editor.dart';
import 'space.dart';
import 'theme.dart';
import 'tokens/tokens.dart' show RaftDesktopMetrics, RaftTypeScale;

/// The facts and commands of a task's own conversation (task v2). With it,
/// [RaftTaskSurface] draws the task dialog: the bar names the task by [ref],
/// the head can be edited, and Source, Created at and Earlier discussion
/// join the properties.
@immutable
class RaftTaskConversation {
  const RaftTaskConversation({
    required this.ref,
    required this.onViewInChannel,
    this.followed = false,
    this.onFollow,
    this.onSearch,
    this.onDelete,
    this.onAmend,
    this.source,
    this.createdAt,
    this.earlierDiscussion,
    this.assigneeAvatar,
  });

  /// `#channel:#7` (Web formatTaskConversationRef).
  final String ref;

  /// Leaves the dialog for the task's place in its channel.
  final VoidCallback onViewInChannel;

  /// Whether the reader follows the conversation; [onFollow] toggles it
  /// (null while a toggle is on its way).
  final bool followed;
  final VoidCallback? onFollow;

  /// Search in task (null before the conversation exists).
  final VoidCallback? onSearch;

  /// Delete task (null for someone who may not delete it).
  final VoidCallback? onDelete;

  /// Writes an edit of the title or the description; null: not editable.
  final Future<RaftTaskAmendOutcome> Function(
    RaftTaskHeadField field,
    String value,
  )?
  onAmend;

  /// The Source property's value; null: no row.
  final Widget? source;

  /// Created at, formatted; null: no row.
  final String? createdAt;

  /// Earlier discussion (a pre-v2 task's host thread): its label (the reply
  /// count, or View) and the way there; null: no row.
  final ({String label, VoidCallback onOpen})? earlierDiscussion;

  final Widget? assigneeAvatar;
}

/// The bar of the task dialog: the task's ref and "Task #7" (one line on a
/// desktop, the ref over the label on a phone), then the More menu (Search in
/// task, View in channel, Follow / Unfollow task, Delete task) and the way
/// out.
class RaftTaskConversationBar extends StatelessWidget {
  const RaftTaskConversationBar({
    super.key,
    required this.conversation,
    required this.taskNumber,
    required this.mobile,
    required this.onClose,
    this.summary,
    this.detailsToggle,
    this.pageStatus,
    this.bottomBorder,
    this.compactPage = false,
    this.desktopBar = false,
    this.focusMode,
  });
  final RaftTaskConversation conversation;
  final Object? taskNumber;
  final bool mobile, compactPage, desktopBar;
  final ({bool focused, VoidCallback toggle})? focusMode;
  final VoidCallback onClose;

  /// A phone whose head has scrolled away: the bar names the task's state
  /// instead of just its label, and it pulls the head down.
  final Widget Function(String label)? summary;
  final Widget? detailsToggle, pageStatus;
  final Border? bottomBorder;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final c = conversation;
    final label = raftFormat(context, 'Task #{taskNumber}', {
      'taskNumber': taskNumber ?? '',
    });
    final refText = Text(
      c.ref,
      key: const ValueKey('task-modal-bar-ref'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: t.scale(
        RaftTypeScale.monoMeta,
        mono: true,
        color: t.ui.foregroundMuted,
      ),
    );
    final labelText = Text(
      label,
      key: const ValueKey('task-modal-bar-label'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: t.scale(RaftTypeScale.subhead, weight: FontWeight.w700),
    );
    final menuLabel = raftText(context, 'Task actions');
    final actionExtent = desktopBar ? RaftDesktopMetrics.barButtonSize : null;
    final actionPadding = desktopBar ? EdgeInsets.zero : null;
    final actions = <Widget>[
      RaftDropdownMenu(
        key: const ValueKey('task-overflow'),
        label: menuLabel,
        tooltip: 'Task actions',
        width: 220,
        align: RaftDropdownAlign.end,
        triggerBuilder: (context, focus, open) => Focus(
          focusNode: focus,
          child: RaftButton(
            key: const ValueKey('task-overflow-trigger'),
            label: '',
            glyph: RaftGlyph.ellipsisVertical,
            uiVariant: RaftButtonVariant.ghost,
            uiSize: RaftButtonSize.iconSm,
            physicalHeight: actionExtent,
            visualWidth: actionExtent,
            padding: actionPadding,
            semanticLabel: raftText(context, 'Task actions'),
            tooltip: raftText(context, 'Task actions'),
            onPressed: open,
          ),
        ),
        entries: [
          if (c.onSearch != null)
            RaftMenuEntry(
              label: raftText(context, 'Search in task'),
              glyph: RaftGlyph.search,
              onPressed: c.onSearch,
            ),
          RaftMenuEntry(
            label: raftText(context, 'View in channel'),
            glyph: RaftGlyph.mapPin,
            onPressed: c.onViewInChannel,
          ),
          RaftMenuEntry(
            label: raftText(
              context,
              c.followed ? 'Unfollow task' : 'Follow task',
            ),
            glyph: c.followed
                ? RaftGlyph.messageCircleOff
                : RaftGlyph.messageCirclePlus,
            onPressed: c.onFollow,
          ),
          if (c.onDelete != null) ...[
            const RaftMenuEntry.separator(),
            RaftMenuEntry(
              label: raftText(context, 'Delete task'),
              glyph: RaftGlyph.trash2,
              onPressed: c.onDelete,
            ),
          ],
        ],
      ),
      if (focusMode case final focus? when !mobile)
        raftConversationHeaderToggle(
          key: const Key('task-focus-mode'),
          glyph: focus.focused ? RaftGlyph.minimize2 : RaftGlyph.maximize2,
          label: raftText(context, focus.focused ? 'Restore' : 'Expand'),
          pressed: focus.focused,
          onPressed: focus.toggle,
        ),
      if (!mobile)
        RaftButton(
          key: const ValueKey('task-modal-close'),
          label: '',
          glyph: RaftGlyph.x,
          uiVariant: RaftButtonVariant.ghost,
          uiSize: RaftButtonSize.iconSm,
          physicalHeight: actionExtent,
          visualWidth: actionExtent,
          padding: actionPadding,
          semanticLabel: raftText(context, 'Close task'),
          tooltip: raftText(context, 'Close task'),
          onPressed: onClose,
        ),
    ];
    const columnMargin = RaftDesktopMetrics.pageInset;
    const iconInset =
        (RaftDesktopMetrics.barButtonSize -
            RaftDesktopMetrics.controlIconSize) /
        2;
    return Container(
      key: const ValueKey('task-modal-bar'),
      constraints: BoxConstraints(minHeight: compactPage ? 56 : 44),
      padding: desktopBar
          ? const EdgeInsetsDirectional.fromSTEB(
              columnMargin,
              0,
              columnMargin - iconInset,
              0,
            )
          : const EdgeInsets.symmetric(horizontal: RaftSpace.x3),
      decoration: BoxDecoration(
        border:
            bottomBorder ??
            Border(bottom: BorderSide(color: t.ui.lineHairline)),
      ),
      child: Row(
        spacing: desktopBar ? RaftSpace.x3 : RaftSpace.x2,
        children: [
          if (mobile)
            RaftButton(
              key: const ValueKey('task-modal-mobile-back'),
              label: '',
              glyph: RaftGlyph.arrowLeft,
              uiVariant: RaftButtonVariant.ghost,
              uiSize: RaftButtonSize.iconSm,
              semanticLabel: raftText(context, 'Close task'),
              tooltip: raftText(context, 'Close task'),
              onPressed: onClose,
            ),
          Expanded(
            child: mobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      refText,
                      if (pageStatus case final status?)
                        Row(
                          spacing: 4,
                          children: [
                            Flexible(child: labelText),
                            Flexible(child: status),
                          ],
                        )
                      else
                        summary?.call(label) ?? labelText,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    spacing: 8,
                    children: [
                      labelText,
                      Flexible(child: refText),
                    ],
                  ),
          ),
          if (detailsToggle case final toggle?) toggle,
          if (desktopBar)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: RaftSpace.x1,
              children: [
                for (final action in actions)
                  SizedBox.square(
                    dimension: RaftDesktopMetrics.barButtonSize,
                    child: action,
                  ),
              ],
            )
          else
            ...actions,
        ],
      ),
    );
  }
}

/// The task head's title or description with its pencil, or its editor while
/// it is edited (Web TaskModalHead with TaskHeadFieldEditor).
class RaftTaskHeadText extends StatefulWidget {
  const RaftTaskHeadText({
    super.key,
    required this.field,
    required this.value,
    required this.display,
    required this.editing,
    required this.onEdit,
    required this.onClose,
    this.onSave,
    this.revealOnHover = false,
  });
  final RaftTaskHeadField field;
  final String value;

  /// The field as shown when not edited.
  final Widget display;
  final bool editing, revealOnHover;
  final VoidCallback onEdit, onClose;
  final Future<RaftTaskAmendOutcome> Function(String text)? onSave;

  @override
  State<RaftTaskHeadText> createState() => _RaftTaskHeadTextState();
}

class _RaftTaskHeadTextState extends State<RaftTaskHeadText> {
  bool hovered = false, focusWithin = false;

  @override
  Widget build(BuildContext context) {
    final save = widget.onSave;
    final field = widget.field;
    if (widget.editing && save != null) {
      return RaftTaskHeadFieldEditor(
        field: field,
        value: widget.value,
        onSave: save,
        onClose: widget.onClose,
      );
    }
    if (save == null) return widget.display;
    final alwaysVisible =
        !widget.revealOnHover || !RaftInteraction.of(context).hover;
    final visible = alwaysVisible || hovered || focusWithin;
    Widget pencil = RaftTaskHeadEditButton(
      key: ValueKey(
        field == RaftTaskHeadField.title
            ? 'task-modal-title-edit'
            : 'task-modal-description-edit',
      ),
      label: field == RaftTaskHeadField.title
          ? 'Edit title'
          : 'Edit description',
      onPressed: widget.onEdit,
    );
    if (widget.revealOnHover) {
      final size = RaftButtonMetrics.of(
        RaftButtonSize.iconMd,
        RaftButtonVariant.ghost,
        RaftTokens.of(context),
      ).height;
      // The pencil hangs four pixels above and below the title's row.
      pencil = Align(
        widthFactor: 1,
        heightFactor: (size - 8) / size,
        child: pencil,
      );
    }
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Expanded(child: widget.display),
        IgnorePointer(
          ignoring: !visible,
          child: Opacity(opacity: visible ? 1 : 0, child: pencil),
        ),
      ],
    );
    if (alwaysVisible) return row;
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: Focus(
        canRequestFocus: false,
        onFocusChange: (value) => setState(() => focusWithin = value),
        child: row,
      ),
    );
  }
}

/// A fact's value that leads somewhere (Source, Earlier discussion): its text
/// and an arrow, the whole value the target.
class RaftTaskPropertyLink extends StatelessWidget {
  const RaftTaskPropertyLink({
    super.key,
    required this.semanticLabel,
    required this.onPressed,
    required this.children,
  });
  final String semanticLabel;
  final VoidCallback onPressed;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftInteractive(
      semanticLabel: raftText(context, semanticLabel),
      onPressed: onPressed,
      builder: (context, state) => DecoratedBox(
        decoration: BoxDecoration(
          color: state.hovered || state.pressed ? t.ui.fillPressed : null,
          borderRadius: BorderRadius.circular(t.radius),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                ...children,
                RaftIcon(
                  RaftGlyph.arrowRight,
                  size: 14,
                  color: t.ui.foregroundHint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
