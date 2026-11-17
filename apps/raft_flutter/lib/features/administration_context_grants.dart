// Administration › Context access (Web v1.24.0
// features/settings/administration/ContextViewGrantsSection.tsx and
// GrantContextViewDialog.tsx): the agents an owner or admin has let search and
// read other agents' context on this server, Grant access and Revoke. Behind
// `agent_context_view_v0`, for owners and admins only. A revoke the server no
// longer has a grant for reads as already gone: the list reloads and says so.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/context_view_grants_api.dart';
import '../data/feature_flag_client_facts.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'administration_onboarding_section.dart' show isAgentInMemberLists;
import 'administration_support.dart';
import 'agent_detail_view.dart' show agentTimeFormatter;
import 'icu_message.dart';
import 'management_support.dart'
    show cachedServerFlag, pageIdentity, rememberServerFlag;

class AdminContextViewGrantsSection extends StatefulWidget {
  const AdminContextViewGrantsSection({super.key, required this.w});
  final WorkspaceController w;
  @override
  State<AdminContextViewGrantsSection> createState() => _GateState();
}

/// `useServerFeatureFlag(AGENT_CONTEXT_VIEW_FEATURE_FLAG_KEY)` for an owner or
/// admin; anyone else never reads it.
class _GateState extends State<AdminContextViewGrantsSection> {
  WorkspaceController get w => widget.w;
  static const flag = RaftFeatureFlags.agentContextView;
  late bool enabled = cachedServerFlag(w, flag) ?? false;

  bool get isAdminOrOwner {
    final role = w.server?.string('role');
    return role == 'owner' || role == 'admin';
  }

  @override
  void initState() {
    super.initState();
    if (isAdminOrOwner) unawaited(evaluate());
  }

  Future<void> evaluate() async {
    final server = w.server?.id;
    if (server == null) return;
    final identity = pageIdentity(w);
    try {
      final result = await w.command(
        'POST',
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(keys: const [flag], serverId: server),
      );
      final on =
          result is Map &&
          (result['evaluations'] as List? ?? const []).whereType<Map>().any(
            (f) => f['key'] == flag && f['enabled'] == true,
          );
      rememberServerFlag(w, flag, on, identity);
      if (mounted && on != enabled) setState(() => enabled = on);
    } catch (_) {
      // Unknown stays as it was.
    }
  }

  @override
  Widget build(BuildContext context) {
    final server = w.server?.id;
    if (!enabled || !isAdminOrOwner || server == null) {
      return const SizedBox.shrink();
    }
    return _GrantsCard(w: w, serverId: server);
  }
}

class _GrantsCard extends StatefulWidget {
  const _GrantsCard({required this.w, required this.serverId});
  final WorkspaceController w;
  final String serverId;
  @override
  State<_GrantsCard> createState() => _GrantsState();
}

class _GrantsState extends State<_GrantsCard> {
  WorkspaceController get w => widget.w;
  WorkspaceEntityDirectory get directory => w.services.entityDirectory;
  List<ContextViewGrant>? grants;
  bool failed = false;
  int _ticket = 0;
  // ignore: raft_lints/avoid_imperative_notice_state -- Web setNote(null) when Grant access opens and when a revoke goes through; the section is remounted on server/account change.
  String? note;

  @override
  void initState() {
    super.initState();
    directory.addListener(_changed);
    directory.ensure(const [WorkspaceEntityKind.agents]);
    reload();
  }

  @override
  void dispose() {
    directory.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// The list read (Web: loading again shows the spinner and keeps no rows).
  void reload() {
    final ticket = ++_ticket, identity = pageIdentity(w);
    setState(() {
      grants = null;
      failed = false;
    });
    listContextViewGrants(w, widget.serverId).then(
      (value) {
        if (mounted && ticket == _ticket && identity == pageIdentity(w)) {
          setState(() => grants = value);
        }
      },
      onError: (Object _) {
        if (mounted && ticket == _ticket && identity == pageIdentity(w)) {
          setState(() => failed = true);
        }
      },
    );
  }

  Map<String, Map<String, dynamic>> get agentsById => {
    for (final a in directory.authorAgents)
      if (a['id'] is String) a['id'] as String: a,
  };

  String _display(Map<String, dynamic>? agent, String fallback) =>
      agent?['displayName'] is String &&
          (agent!['displayName'] as String).isNotEmpty
      ? agent['displayName'] as String
      : fallback;

  /// The agent's display name where this server's agents list has it; the
  /// grant's own name otherwise.
  String label(ContextViewGrant g) =>
      _display(agentsById[g.agentId], g.agentName);

  /// Ordinary agents only (the server refuses the rest): not a personal
  /// assistant, not an App Bot, not deleted, and not one that already has
  /// access.
  List<Map<String, dynamic>> get candidates {
    final granted = {for (final g in grants ?? const <ContextViewGrant>[]) g.agentId};
    return [
      for (final a in directory.authorAgents)
        if (a['id'] is String &&
            isAgentInMemberLists(a) &&
            a['managedByAppInstallId'] == null &&
            !granted.contains(a['id']))
          a,
    ];
  }

  void openGrant() {
    setState(() => note = null);
    final options = [
      for (final a in candidates)
        (a['id'] as String, _display(a, '${a['name']}')),
    ];
    final picked = ValueNotifier<String>('');
    final canConfirm = ValueNotifier<bool>(false);
    picked.addListener(() => canConfirm.value = picked.value.isNotEmpty);
    unawaited(
      RaftConfirmDialog.show(
        context,
        RaftConfirmDialog(
          surfaceKey: const ValueKey('admin-confirm-dialog'),
          confirmKey: const ValueKey('context-view-grant-confirm'),
          title: 'Grant context access',
          size: RaftDialogSize.md,
          plainMessage: true,
          confirmVariant: RaftButtonRecipeVariant.accent,
          confirmLabel: 'Grant access',
          loadingLabel: 'Granting…',
          confirmEnabled: canConfirm,
          content: ValueListenableBuilder<String>(
            valueListenable: picked,
            builder: (context, id, _) {
              final name = options.where((o) => o.$1 == id).firstOrNull?.$2;
              return RaftGrantContextBody(
                options: options,
                agentId: id,
                onAgent: (value) => picked.value = value,
                disclosure: icuText(
                  context,
                  "The access is server-wide: {agent} can search and read other agents' context on this whole server, limited to messages {agent} can see. Whoever controls {agent} can read what it reads: its creator, who may be an ordinary member, and anyone on its Computer.",
                  {'agent': name ?? raftText(context, 'this agent')},
                ),
              );
            },
          ),
          onConfirm: () async {
            if (picked.value.isEmpty) return;
            final grant = await grantContextView(
              w,
              widget.serverId,
              picked.value,
            );
            if (!mounted) return;
            final list = grants;
            if (list != null && !list.any((g) => g.id == grant.id)) {
              setState(() => grants = [...list, grant]);
            }
          },
        ),
      ).whenComplete(() {
        picked.dispose();
        canConfirm.dispose();
      }),
    );
  }

  void revoke(ContextViewGrant grant) {
    final agent = label(grant);
    unawaited(
      adminConfirm(
        context,
        title: raftFormat(context, "Revoke {agent}'s access?", {
          'agent': agent,
        }),
        message: raftFormat(
          context,
          "{agent} will no longer be able to search or read other agents' context.",
          {'agent': agent},
        ),
        confirmLabel: 'Revoke',
        loadingLabel: 'Revoking…',
        confirmVariant: RaftButtonRecipeVariant.warning,
        confirmKey: const ValueKey('context-view-revoke-confirm'),
        onConfirm: () async {
          final revoked = await revokeContextViewGrant(
            w,
            widget.serverId,
            grant.id,
          );
          if (!mounted) return;
          if (!revoked) {
            setState(
              () => note = raftFormat(
                context,
                "{agent}'s access was already revoked.",
                {'agent': agent},
              ),
            );
            reload();
          } else {
            setState(() {
              note = null;
              grants = [
                for (final g in grants ?? const <ContextViewGrant>[])
                  if (g.id != grant.id) g,
              ];
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = agentTimeFormatter(context, w);
    final list = grants;
    return RaftAdminSection(
      regionKey: adminRegion('context-view-grants'),
      label: 'Context access for agents',
      glyph: RaftGlyph.scanSearch,
      count: list?.length,
      child: RaftContextGrantsCard(
        loading: list == null && !failed,
        failed: failed,
        note: note,
        onGrant: list == null ? null : openGrant,
        onRetry: reload,
        grants: [
          for (final g in list ?? const <ContextViewGrant>[])
            RaftContextGrant(
              id: g.id,
              name: label(g),
              avatarUrl: agentsById[g.agentId]?['avatarUrl'] as String?,
              subtitle: g.granterName == null
                  ? raftFormat(context, 'Granted by a former member · {when}', {
                      'when': f.shortDateTime(g.grantedAt),
                    })
                  : raftFormat(context, 'Granted by {name} · {when}', {
                      'name': g.granterName,
                      'when': f.shortDateTime(g.grantedAt),
                    }),
              onRevoke: () => revoke(g),
            ),
        ],
      ),
    );
  }
}
