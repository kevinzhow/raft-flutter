import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_page.dart';
import 'agent_profile.dart' show RaftPanelSection;
import 'indicators.dart' show RaftSkeleton;
import 'design_primitives.dart';
import 'dialog_card.dart';
import 'icons.dart';
import 'inline_badge_editor.dart';
import 'localization.dart';
import 'task.dart';
import 'theme.dart';
import 'thread_composition.dart';

/// Mounted Source TaskModalBar/TaskModalHead/TaskProperties and the separate
/// LegacyTaskPanel. API and discussion ownership belong to the scoped model.
class RaftTaskSurface extends StatefulWidget {
  const RaftTaskSurface({
    super.key,
    required this.task,
    required this.history,
    required this.assignees,
    required this.legacy,
    required this.loading,
    required this.historyLoading,
    required this.busy,
    required this.canStatus,
    required this.canAssign,
    required this.canCleanupDelete,
    required this.statusOptions,
    required this.onClose,
    required this.onRetry,
    required this.onLoadAssignees,
    required this.onUpdate,
    required this.formatTime,
    this.error,
    this.historyError,
    this.discussionBuilder,
    this.onCleanupDelete,
    this.onBack,
    this.unresolvedBody,
  });
  final Map<String, dynamic> task;
  final List<Map<String, dynamic>> history, assignees;
  final bool legacy, loading, historyLoading, busy;
  final bool canStatus, canAssign, canCleanupDelete;
  final List<String> statusOptions;
  final Object? error, historyError;
  final VoidCallback onClose;
  final VoidCallback? onBack;
  final Widget? unresolvedBody;
  final Future<void> Function() onRetry, onLoadAssignees;
  final Future<void> Function(String, dynamic) onUpdate;
  final String Function(dynamic) formatTime;
  final Widget Function(Widget parentSlot)? discussionBuilder;
  final VoidCallback? onCleanupDelete;
  @override
  State<RaftTaskSurface> createState() => _RaftTaskSurfaceState();
}

class _RaftTaskSurfaceState extends State<RaftTaskSurface> {
  bool historyOpen = false, descriptionExpanded = false;
  final popover = MenuController();
  final assigneeSearch = TextEditingController();
  String needle = '';
  @override
  void didUpdateWidget(RaftTaskSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task['id'] != widget.task['id'] ||
        oldWidget.task['description'] != widget.task['description']) {
      descriptionExpanded = false;
    }
  }

  @override
  void dispose() {
    assigneeSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), size = MediaQuery.sizeOf(context);
    final mobile = size.width < 768;
    final legacy = widget.legacy;
    final body =
        widget.unresolvedBody ??
        (legacy ? legacyBody(context) : modernBody(context));
    final panel = Material(
      key: ValueKey(legacy ? 'legacy-task-panel' : 'task-thread-modal'),
      color: t.panel,
      child: SizedBox(
        width: mobile
            ? size.width
            : math.min(legacy ? 760 : 960, size.width - 32),
        height: mobile
            ? size.height
            : math.min(legacy ? 720 : 900, size.height * (legacy ? .78 : .86)),
        child: Column(
          children: [
            header(context, mobile),
            Expanded(child: body),
          ],
        ),
      ),
    );
    final framed = mobile
        ? panel
        : RaftModalBackdrop(
            child: GestureDetector(
              onTap: () {},
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: t.brutal ? t.ink : t.colors['line-muted']!,
                    width: t.brutal ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(
                    t.brutal || legacy ? 0 : 8,
                  ),
                  boxShadow: t.brutal
                      ? [BoxShadow(color: t.ink, offset: const Offset(4, 4))]
                      : t.shadows,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    t.brutal || legacy ? 0 : 8,
                  ),
                  child: panel,
                ),
              ),
            ),
          );
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              widget.onClose();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: mobile
              ? framed
              : GestureDetector(
                  onTap: widget.onClose,
                  behavior: HitTestBehavior.opaque,
                  child: framed,
                ),
        ),
      ),
    );
  }

  Widget header(BuildContext context, bool mobile) {
    final t = RaftTokens.of(context);
    final task = widget.task;
    if (widget.unresolvedBody != null) {
      return RaftThreadHeader(
        presentation: mobile
            ? RaftThreadPresentation.mobileModal
            : RaftThreadPresentation.modal,
        threadLabel: raftText(context, 'Thread'),
        backLabel: raftText(context, 'Close task'),
        closeLabel: raftText(context, 'Close task'),
        jumpLabel: raftText(context, 'Jump to beginning'),
        onBack: widget.onBack ?? widget.onClose,
        onClose: widget.onClose,
      );
    }
    return Container(
      key: const ValueKey('task-modal-bar'),
      // TaskModalBar px-4 py-2 with 16+20 line boxes and a 1/2px border.
      // LegacyTaskPanel uses the separate h-panel-header recipe.
      height: widget.legacy
          ? (t.brutal ? RaftMetrics.brutalPanelHeader : RaftMetrics.panelHeader)
          : (t.brutal ? 54 : 53),
      padding: EdgeInsets.symmetric(horizontal: widget.legacy ? 20 : 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: t.brutal
                ? t.ink
                : t.colors[widget.legacy ? 'line-hairline' : 'line-muted']!,
            width: t.brutal ? 2 : 1,
          ),
        ),
      ),
      child: Row(
        spacing: 12,
        children: [
          if (mobile)
            RaftIconButton(
              glyph: RaftGlyph.arrowLeft,
              tooltip: raftText(context, 'Close task'),
              onPressed: widget.onBack ?? widget.onClose,
              visualSize: 28,
              glyphSize: 14,
            ),
          if (widget.legacy) const RaftIcon(RaftGlyph.fileText, size: 18),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${task['channelName'] ?? raftText(context, 'unknown')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RaftTypography.heading(
                    t,
                    size: widget.legacy ? 16 : 12,
                    line: widget.legacy ? 24 : 16,
                  ).copyWith(color: t.muted),
                ),
                Text(
                  'Task #${task['taskNumber'] ?? ''}${widget.legacy ? ' · LEGACY' : ''}',
                  style: RaftTypography.heading(
                    t,
                    size: widget.legacy ? 12 : 14,
                    line: widget.legacy ? 16 : 20,
                  ),
                ),
              ],
            ),
          ),
          if (!mobile)
            RaftIconButton(
              glyph: RaftGlyph.x,
              tooltip: raftText(context, 'Close task'),
              onPressed: widget.onClose,
              visualSize: 28,
              glyphSize: 14,
            ),
        ],
      ),
    );
  }

  Widget modernBody(BuildContext context) {
    final head = properties(context);
    if (widget.error != null && widget.loading == false)
      return SingleChildScrollView(
        child: Column(
          children: [
            RaftAuthBanner(text: '${widget.error}'),
            RaftTextButton(
              label: 'Retry',
              onPressed: () => unawaited(widget.onRetry()),
            ),
          ],
        ),
      );
    final buildDiscussion = widget.discussionBuilder;
    if (buildDiscussion == null) {
      return SingleChildScrollView(
        child: Column(
          children: [head, if (widget.loading) const RaftSkeleton(height: 16)],
        ),
      );
    }
    return buildDiscussion(head);
  }

  Widget properties(BuildContext context) {
    final t = RaftTokens.of(context), task = widget.task;
    final description = '${task['description'] ?? ''}'.trim();
    return RaftPanelSection(
      topBorder: false,
      gap: 8,
      children: [
        Text(
          '${task['title'] ?? ''}',
          key: const ValueKey('task-modal-title'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: RaftTypography.heading(t, size: 18, line: 22.5),
        ),
        if (description.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              final style = RaftTypography.heading(
                t,
                size: 14,
                line: 20,
                weight: FontWeight.w400,
              ).copyWith(color: t.muted);
              final measure = TextPainter(
                text: TextSpan(text: description, style: style),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout(maxWidth: constraints.maxWidth);
              final long = measure.height > 61;
              measure.dispose();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    key: const ValueKey('task-modal-description'),
                    maxLines: long && !descriptionExpanded ? 3 : null,
                    overflow: long && !descriptionExpanded
                        ? TextOverflow.ellipsis
                        : TextOverflow.clip,
                    style: style,
                  ),
                  if (long)
                    RaftTextButton(
                      label: descriptionExpanded ? 'Collapse' : 'Show more',
                      onPressed: () => setState(
                        () => descriptionExpanded = !descriptionExpanded,
                      ),
                    ),
                ],
              );
            },
          ),
        Container(
          padding: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.colors['line-muted']!)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                expanded: historyOpen,
                child: RaftTextButton(
                  key: const ValueKey('task-properties-history'),
                  label: 'History',
                  glyph: historyOpen
                      ? RaftGlyph.chevronDown
                      : RaftGlyph.chevronRight,
                  onPressed: () => setState(() => historyOpen = !historyOpen),
                ),
              ),
              if (historyOpen) history(context),
            ],
          ),
        ),
        Wrap(
          key: const ValueKey('task-properties'),
          spacing: 24,
          runSpacing: 8,
          children: [
            property(context, 'Status', status(context)),
            property(context, 'Assignee', assignee(context)),
            property(
              context,
              'Created by',
              Text(
                '@${task['createdByName'] ?? raftText(context, 'Unknown')}',
                style: RaftTypography.heading(
                  t,
                  size: 12,
                  line: 16,
                  weight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
        if (task['readOnlyReason'] != null)
          Text(
            raftText(
              context,
              'This task predates the channel conversion. Only the source workspace can change it.',
            ),
            style: RaftTypography.heading(
              t,
              size: 12,
              line: 16,
              weight: FontWeight.w400,
            ),
          ),
        if (widget.canCleanupDelete && widget.onCleanupDelete != null)
          RaftTextButton(label: 'Delete', onPressed: widget.onCleanupDelete),
      ],
    );
  }

  Widget property(BuildContext context, String label, Widget value) {
    final t = RaftTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Text(
          raftText(context, label),
          style: RaftTypography.heading(
            t,
            size: 12,
            line: 16,
            weight: FontWeight.w400,
          ).copyWith(color: t.muted),
        ),
        value,
      ],
    );
  }

  Widget status(BuildContext context) {
    final t = RaftTokens.of(context), value = '${widget.task['status']}';
    if (!raftTaskStatuses.contains(value)) return Text(value);
    final (bg, fg) = raftTaskStatusBadgeColors(t, value);
    return RaftInlineBadgeEditor(
      key: const ValueKey('task-properties-status'),
      label: raftText(context, raftTaskStatusLabel(value)),
      selectedId: value,
      options: [
        for (final next in widget.statusOptions)
          RaftInlineBadgeOption(
            id: next,
            label: raftText(
              context,
              value == 'closed' && next == 'todo'
                  ? 'Reopen to Todo'
                  : raftTaskStatusLabel(next),
            ),
          ),
      ],
      enabled: widget.canStatus && !widget.busy,
      onSelect: (next) => unawaited(widget.onUpdate('status', next)),
      background: bg,
      foreground: fg,
    );
  }

  Widget assignee(BuildContext context) {
    final task = widget.task;
    final assigned =
        task['claimedById'] != null && task['claimedByType'] != null;
    final label = assigned
        ? '@${task['claimedByName'] ?? raftText(context, 'Unknown')}'
        : raftText(context, 'Unassigned');
    return MenuAnchor(
      controller: popover,
      style: const MenuStyle(
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
      ),
      menuChildren: [
        RaftMenuPanel(
          width: math.min(248, MediaQuery.sizeOf(context).width - 24),
          kind: RaftMenuKind.selectionPopover,
          onDismiss: popover.close,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                key: const ValueKey('task-assignee-search'),
                controller: assigneeSearch,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: raftText(context, 'Search people and agents'),
                ),
                onChanged: (s) =>
                    setState(() => needle = s.trim().toLowerCase()),
              ),
            ),
            RaftMenuItem(
              label: raftText(context, 'Unassigned'),
              onPressed: () {
                if (!widget.canAssign || widget.busy) return;
                popover.close();
                unawaited(widget.onUpdate('assignee', null));
              },
            ),
            for (final person in widget.assignees.where(
              (p) => '${p['displayName'] ?? p['name']}'.toLowerCase().contains(
                needle,
              ),
            ))
              RaftMenuItem(
                label: '${person['displayName'] ?? person['name']}',
                onPressed: () {
                  if (!widget.canAssign || widget.busy) return;
                  popover.close();
                  unawaited(
                    widget.onUpdate('assignee', {
                      'type': person['actorType'],
                      'id': person['userId'] ?? person['id'],
                    }),
                  );
                },
              ),
          ],
        ),
      ],
      builder: (context, controller, child) => RaftTextButton(
        key: const ValueKey('task-properties-assignee'),
        label: label,
        onPressed: !widget.canAssign || widget.busy
            ? null
            : () async {
                try {
                  await widget.onLoadAssignees();
                  if (!mounted || !widget.canAssign) return;
                  assigneeSearch.clear();
                  needle = '';
                  controller.open();
                } catch (_) {
                  if (mounted) setState(() {});
                }
              },
      ),
    );
  }

  Widget history(BuildContext context) {
    final t = RaftTokens.of(context);
    if (widget.historyLoading)
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: RaftSkeleton(height: 16),
      );
    if (widget.historyError != null)
      return Text(
        raftText(context, 'Unable to load history.'),
        key: const ValueKey('task-history-error'),
      );
    if (widget.history.isEmpty)
      return Text(raftText(context, 'No history yet.'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final event in widget.history)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  raftText(context, switch (event['eventType']) {
                    'created' => 'Created task',
                    'amended' => 'Updated task',
                    'status_changed' => 'Changed status',
                    'assignee_changed' => 'Changed assignee',
                    'closed' => 'Closed task',
                    'reopened' => 'Reopened task',
                    _ => '${event['eventType']}',
                  }),
                  style: RaftTypography.heading(t, size: 12, line: 16),
                ),
                Text(
                  '${event['actorName'] ?? event['actorType']} · ${widget.formatTime(event['createdAt'])}',
                  style: RaftTypography.heading(
                    t,
                    size: 12,
                    line: 16,
                    weight: FontWeight.w400,
                  ).copyWith(color: t.muted),
                ),
                if (event['payload'] is Map &&
                    event['payload']['from'] != null &&
                    event['payload']['to'] != null)
                  Text(
                    '${raftText(context, raftTaskStatusLabel('${event['payload']['from']}'))} → ${raftText(context, raftTaskStatusLabel('${event['payload']['to']}'))}',
                    style: RaftTypography.heading(
                      t,
                      size: 12,
                      line: 16,
                      weight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget legacyBody(BuildContext context) {
    final t = RaftTokens.of(context), task = widget.task;
    String tr(String value) => raftText(context, value);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          RaftTaskStatus(status: '${task['status']}'),
          RaftRecipeCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Text(
                  tr('Title'),
                  style: RaftTypography.mono(t, size: 12, line: 16),
                ),
                Text(
                  '${task['title'] ?? ''}',
                  style: RaftTypography.heading(t, size: 18, line: 28),
                ),
                Text(
                  tr('Description'),
                  style: RaftTypography.mono(t, size: 12, line: 16),
                ),
                Text(
                  '${task['description'] ?? ''}'.trim().isEmpty
                      ? tr('No description')
                      : '${task['description']}',
                  style: RaftTypography.heading(
                    t,
                    size: 14,
                    line: 20,
                    weight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          RaftRecipeCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              spacing: 8,
              children: [
                for (final entry in <String, String>{
                  'Created by': '@${task['createdByName'] ?? tr('Unknown')}',
                  'Created at': taskTime(task['createdAt']),
                  'Assignee': task['claimedByName'] == null
                      ? tr('Unassigned')
                      : '@${task['claimedByName']}',
                  'Completed': task['completedAt'] == null
                      ? tr('Not done')
                      : taskTime(task['completedAt']),
                }.entries)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 12,
                    children: [
                      Expanded(
                        child: Text(
                          tr(entry.key),
                          style: RaftTypography.mono(
                            t,
                            size: 14,
                            line: 20,
                          ).copyWith(color: t.muted),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value,
                          textAlign: TextAlign.right,
                          style: RaftTypography.heading(
                            t,
                            size: 14,
                            line: 20,
                            weight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          RaftAuthBanner(
            info: true,
            text:
                '${tr('Read-only panel')}\n${tr('Legacy tasks do not map to a message thread. This panel shows task metadata only, and posting is disabled.')}',
          ),
        ],
      ),
    );
  }

  String taskTime(dynamic value) => widget.formatTime(value);
}
