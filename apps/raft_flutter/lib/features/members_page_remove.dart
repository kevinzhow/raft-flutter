import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'agent_activity_summaries.dart' show joinConjunction;
import 'icu_message.dart';
import 'member_removal_impact.dart';

class RemoveMemberDialog extends StatefulWidget {
  const RemoveMemberDialog({
    super.key,
    required this.workspace,
    required this.serverId,
    required this.memberId,
    required this.name,
    required this.onConfirm,
  });

  final WorkspaceController workspace;
  final String serverId, memberId, name;
  final Future<void> Function() onConfirm;

  @override
  State<RemoveMemberDialog> createState() => _RemoveMemberDialogState();
}

class _RemoveMemberDialogState extends State<RemoveMemberDialog> {
  final _enabled = ValueNotifier(false);
  late final MemberRemovalImpactRead _read;

  @override
  void initState() {
    super.initState();
    _read = MemberRemovalImpactRead(widget.workspace, () {
      if (!mounted) return;
      _enabled.value = true;
      setState(() {});
    })..sync(widget.serverId, widget.memberId);
  }

  @override
  void dispose() {
    _read.sync(null, null);
    _enabled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RaftConfirmDialog(
    surfaceKey: const ValueKey('agent-dialog'),
    confirmKey: const ValueKey('human-remove-member-confirm'),
    cssTitle: true,
    title: raftText(context, 'Remove member'),
    content: RaftGapColumn(
      gap: 8,
      children: [
        RaftCssText(
          raftFormat(
            context,
            '{name} will be removed from every channel on this server. Their past messages will remain in history.',
            {'name': widget.name},
          ),
        ),
        ..._impact(context),
      ],
    ),
    confirmLabel: raftText(context, 'Remove'),
    loadingLabel: raftText(context, 'Removing…'),
    confirmEnabled: _enabled,
    onConfirm: widget.onConfirm,
  );

  List<Widget> _impact(BuildContext context) {
    switch (_read.kind) {
      case MemberRemovalImpactKind.none:
        return [];
      case MemberRemovalImpactKind.loading:
        return [
          RaftGapRow(
            gap: 8,
            children: [
              const RaftSpinner(),
              Flexible(
                child: RaftCssText(
                  raftText(
                    context,
                    'Checking which Computers this takes offline…',
                  ),
                ),
              ),
            ],
          ),
        ];
      case MemberRemovalImpactKind.failed:
        return [
          RaftCssText(
            raftText(
              context,
              "Couldn't check which Computers this takes offline.",
            ),
          ),
        ];
      case MemberRemovalImpactKind.ready:
        final impact = _read.impact!;
        if (impact.computers == 0) return [];
        final names = joinConjunction([
          ...impact.computerNames,
          if (impact.computerNames.length < impact.computers)
            raftText(context, 'others'),
        ], chinese: Localizations.localeOf(context).languageCode == 'zh');
        final line = icuText(
          context,
          'Removing {name} takes {computers, plural, one {# Computer} other {# Computers}} offline: {names}.',
          {'name': widget.name, 'computers': impact.computers, 'names': names},
        );
        final details = impact.othersAgents == 0
            ? line
            : raftFormat(context, '{computersLine} {othersLine}', {
                'computersLine': line,
                'othersLine': icuText(
                  context,
                  '{count, plural, one {# agent on them belongs to other people and goes offline too.} other {# agents on them belong to other people and go offline too.}}',
                  {'count': impact.othersAgents},
                ),
              });
        return [
          RaftGapColumn(
            gap: RaftSpace.x1,
            children: [
              RaftCssText(
                details,
                key: const ValueKey('member-removal-impact'),
              ),
              RaftCssText(
                icuText(
                  context,
                  'To bring {computers, plural, one {it} other {them}} back, someone who stays in this server sets up that machine again. Its agents keep their settings.',
                  {'computers': impact.computers},
                ),
              ),
            ],
          ),
        ];
    }
  }
}
