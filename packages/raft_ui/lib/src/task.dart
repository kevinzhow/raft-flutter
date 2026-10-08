import 'package:flutter/material.dart';

import 'localization.dart';

import 'theme.dart';

const raftTaskStatuses = ['todo', 'in_progress', 'in_review', 'done', 'closed'];
const raftTaskTransitions = <String, List<String>>{
  'todo': ['in_progress', 'closed'],
  'in_progress': ['in_review', 'done', 'closed'],
  'in_review': ['done', 'in_progress', 'closed'],
  'done': ['todo', 'in_progress', 'in_review', 'closed'],
  'closed': ['todo', 'in_progress'],
};
String raftTaskStatusLabel(String status) => switch (status) {
  'todo' => 'Todo',
  'in_progress' => 'In Progress',
  'in_review' => 'In Review',
  'done' => 'Done',
  'closed' => 'Closed',
  _ => status,
};

class RaftTaskStatus extends StatelessWidget {
  const RaftTaskStatus({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final (semantic, brutal, icon) = switch (status) {
      'in_progress' => ('info', 'cyan', Icons.play_arrow_outlined),
      'in_review' => ('accent', 'lavender', Icons.visibility_outlined),
      'done' => ('success', 'lime', Icons.check_circle_outline),
      'closed' => ('muted', 'stone', Icons.block),
      _ => ('warning', 'orange', Icons.circle_outlined),
    };
    final bg =
        t.colors[t.brutal
            ? 'color-brutal-$brutal'
            : status == 'closed'
            ? 'fill-muted'
            : '$semantic-soft']!;
    final fg = t.brutal
        ? Colors.black
        : t.colors[status == 'closed'
              ? 'foreground-strong'
              : '$semantic-strong']!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(t.brutal ? 0 : 6),
        border: t.brutal ? Border.all(color: t.ink) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 5,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 14, color: fg)),
          Text(
            raftText(context, raftTaskStatusLabel(status)),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class RaftTaskCard extends StatelessWidget {
  const RaftTaskCard({
    super.key,
    required this.title,
    required this.number,
    required this.status,
    this.channel = '',
    this.description = '',
    this.assignee,
    this.onTap,
    this.onStatus,
    this.statusOptions = const [],
  });
  final String title, number, status, channel, description;
  final String? assignee;
  final VoidCallback? onTap;
  final ValueChanged<String>? onStatus;
  final List<String> statusOptions;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Semantics(
      button: true,
      label: 'Open task #$number: $title',
      onTap: onTap,
      explicitChildNodes: true,
      child: Material(
        color: t.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radius),
          side: BorderSide(color: t.line, width: t.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${channel.isEmpty ? '' : '#$channel · '}task #$number',
                        style: TextStyle(fontSize: 12, color: t.muted),
                      ),
                    ),
                    if (onStatus != null && statusOptions.isNotEmpty)
                      PopupMenuButton<String>(
                        tooltip: raftText(context, 'Task status'),
                        onSelected: onStatus,
                        itemBuilder: (_) => [
                          for (final s in statusOptions)
                            PopupMenuItem(
                              value: s,
                              child: RaftTaskStatus(status: s),
                            ),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: RaftTaskStatus(status: status),
                        ),
                      )
                    else
                      RaftTaskStatus(status: status),
                  ],
                ),
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: t.muted, height: 1.4),
                    ),
                  ),
                if (assignee != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      spacing: 6,
                      children: [
                        Icon(Icons.person_outline, size: 16, color: t.muted),
                        Expanded(
                          child: Text(
                            assignee!,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: t.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
