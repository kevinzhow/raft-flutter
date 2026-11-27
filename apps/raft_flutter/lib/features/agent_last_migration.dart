import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'agent_migration_panel.dart';
import 'agent_migration_presentation.dart';
import 'agent_migration_retry.dart';

class AgentLastMigration extends StatefulWidget {
  const AgentLastMigration({
    super.key,
    required this.migration,
    required this.machines,
    required this.retry,
    required this.formatTimestamp,
    required this.failurePanel,
    required this.openComputer,
    required this.openMember,
  });

  final Map<String, dynamic> migration;
  final List<Map<String, dynamic>> machines;
  final MigrationRetryDetails? retry;
  final String Function(String) formatTimestamp;
  final Widget? failurePanel;
  final ValueChanged<String> openComputer, openMember;

  @override
  State<AgentLastMigration> createState() => _AgentLastMigrationState();
}

class _AgentLastMigrationState extends State<AgentLastMigration> {
  late bool _open = widget.failurePanel != null;

  @override
  Widget build(BuildContext context) {
    final migration = widget.migration;
    final failed = widget.failurePanel != null;
    String computer(Object? id) => MigrationText('{computer}', {
      'computer': migrationComputerLabel(widget.machines, id),
    }).text(context);
    final source = computer(migration['sourceMachineId']);
    final target = computer(migration['targetMachineId']);
    Widget? computerLink(Object? id, String name) {
      if (id is! String ||
          !widget.machines.any((machine) => machine['id'] == id)) {
        return null;
      }
      return RaftTextLink(
        label: name,
        variant: RaftTextLinkVariant.strong,
        onPressed: () => widget.openComputer(id),
      );
    }

    final starter = migration['initiatedBy'];
    final startedBy = starter is Map
        ? [
            starter['displayName'],
            starter['name'],
          ].whereType<String>().where((name) => name.isNotEmpty).firstOrNull
        : null;
    final stamp =
        migration[failed ? 'abortedAt' : 'completedAt'] ??
        migration['updatedAt'];
    final finished = stamp is String ? widget.formatTimestamp(stamp) : null;
    final outcome = raftText(context, failed ? 'Failed' : 'Completed');
    final summary = [
      '$source → $target',
      ?startedBy,
      ?finished,
      outcome,
    ].join(' · ');
    final tokens = RaftTokens.of(context);
    final style = tokens.scale(
      RaftTypeScale.caption,
      color: tokens.ui.foregroundMuted,
    );
    final title = raftText(context, 'Last migration');
    final retry = widget.retry;
    final ref = '${migration['migrationRef']}';
    return RaftCollapsibleSectionHeader(
      label: '$title $summary',
      expanded: _open,
      leadingDisclosure: true,
      gap: RaftSpace.x3,
      disclosureKey: const ValueKey('agent-last-migration-toggle'),
      onExpandedChanged: (value) => setState(() => _open = value),
      labelSpan: TextSpan(
        style: style,
        children: [
          TextSpan(
            text: title,
            style: tokens.scale(
              RaftTypeScale.caption,
              color: tokens.ui.foregroundMuted,
              weight: FontWeight.w600,
            ),
          ),
          TextSpan(text: '  $summary'),
        ],
      ),
      children: [
        RaftListRowGroup(
          key: const ValueKey('agent-last-migration-body'),
          children: [
            Padding(
              padding: const EdgeInsets.all(RaftSpace.x3),
              child:
                  widget.failurePanel ??
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (retry != null) ...[
                        RaftCssText(retry.note(context), style: style),
                        const SizedBox(height: RaftSpace.x3),
                      ],
                      RaftDescriptionList(
                        entries: [
                          ...?retry?.entries(
                            context,
                            failed: false,
                            completed: true,
                          ),
                          RaftDescriptionEntry(
                            raftText(context, 'Source computer'),
                            source,
                            detailsChild: computerLink(
                              migration['sourceMachineId'],
                              source,
                            ),
                          ),
                          RaftDescriptionEntry(
                            raftText(context, 'Target computer'),
                            target,
                            detailsChild: computerLink(
                              migration['targetMachineId'],
                              target,
                            ),
                          ),
                          if (startedBy != null)
                            RaftDescriptionEntry(
                              raftText(context, 'Started by'),
                              startedBy,
                              detailsChild: switch (starter['id']) {
                                final String id => RaftTextLink(
                                  label: startedBy,
                                  variant: RaftTextLinkVariant.strong,
                                  onPressed: () => widget.openMember(id),
                                ),
                                _ => null,
                              },
                            ),
                          if (finished != null)
                            RaftDescriptionEntry(
                              raftText(context, 'Finished'),
                              finished,
                            ),
                          RaftDescriptionEntry(
                            raftText(context, 'Migration ID'),
                            ref,
                            detailsChild: MigrationReference(
                              migrationRef: ref,
                              valueOnly: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
