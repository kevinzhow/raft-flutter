import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/cause_notice.dart';
import '../data/user_error.dart';
import 'action_card_spec.dart';

abstract interface class ActionCardMcpApi {
  Future<CardJson> authorization();
  Future<CardJson> defaultImpact(String connection);
  Future<void> setDefault(String connection);
  Future<void> grant(String? connection);
  Future<void> discard(String connection);
}

class RaftActionCardMcpApi implements ActionCardMcpApi {
  const RaftActionCardMcpApi(this.client, this.app, this.agent);

  final RaftClient client;
  final String app, agent;

  @override
  Future<CardJson> authorization() async => cardObject(
    await client.get(
      '/mcp/servers/$app/connection-authorization',
      query: {'agentId': agent},
    ),
  );

  @override
  Future<CardJson> defaultImpact(String connection) async => cardObject(
    await client.get(
      '/mcp/apps/$app/default/impact',
      query: {'connectionId': connection},
    ),
  );

  @override
  Future<void> setDefault(String connection) async {
    await client.request(
      'PUT',
      '/mcp/apps/$app/default',
      data: {'connectionId': connection},
    );
  }

  @override
  Future<void> grant(String? connection) async {
    await client.request(
      'PUT',
      '/mcp/agents/$agent/assignments/$app',
      data: {'connectionId': connection, 'enabled': true},
    );
  }

  @override
  Future<void> discard(String connection) async {
    await client.delete('/mcp/apps/$app/connections/$connection');
  }
}

class ActionCardMcpPicker extends StatefulWidget {
  const ActionCardMcpPicker({
    super.key,
    required this.api,
    required this.agent,
    required this.verify,
    required this.onGranted,
    required this.onOpenWeb,
  });

  final ActionCardMcpApi api;
  final String agent;
  final VoidCallback verify;
  final Future<void> Function() onGranted;
  final VoidCallback onOpenWeb;

  @override
  State<ActionCardMcpPicker> createState() => _ActionCardMcpPickerState();
}

class _ActionCardMcpPickerState extends State<ActionCardMcpPicker> {
  CardJson? _data;
  String? _picked;
  final _notice = CauseNotice();
  bool? _makeDefault;
  bool _loading = true, _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _notice.clear();
    });
    try {
      final data = await widget.api.authorization();
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) setState(() => _notice.raise(_failure(error)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _failure(Object error) => userErrorText(
    error,
    fallback: 'Failed to execute action',
    where: 'MCP connect card',
  );

  Future<void> _grant(
    String connection,
    String name, {
    required bool changeDefault,
    required bool followsDefault,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice.clear();
    });
    Future<void> write() async {
      widget.verify();
      if (changeDefault) await widget.api.setDefault(connection);
      if (!mounted) return;
      widget.verify();
      await widget.api.grant(
        followsDefault || changeDefault ? null : connection,
      );
      if (mounted) await widget.onGranted();
    }

    try {
      if (changeDefault) {
        widget.verify();
        final impact = await widget.api.defaultImpact(connection);
        if (!mounted) return;
        if (impact['currentDefaultConnectionId'] != null ||
            impact['agentsChangingNow'] != 0) {
          await RaftConfirmDialog.show(
            context,
            RaftConfirmDialog(
              title: raftFormat(
                context,
                'Make {name} the default for all agents?',
                {'name': name},
              ),
              message: raftFormat(context, 'Agents switching now: {count}', {
                'count': impact['agentsChangingNow'] ?? 0,
              }),
              confirmLabel: 'Make default and grant',
              confirmVariant: RaftButtonRecipeVariant.outline,
              onConfirm: write,
            ),
          );
          return;
        }
      }
      await write();
    } catch (error) {
      if (mounted) setState(() => _notice.raise(_failure(error)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discard(String connection) async {
    setState(() => _busy = true);
    try {
      widget.verify();
      await widget.api.discard(connection);
      if (!mounted) return;
      _picked = null;
      await _load();
    } catch (error) {
      if (mounted) setState(() => _notice.raise(_failure(error)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Text(raftText(context, 'Loading…'));
    final data = _data;
    final error = _notice.message;
    if (data == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: RaftSpace.x2,
        children: [
          if (error != null) RaftErrorBanner(error, small: true),
          RaftButton(
            label: 'Try again',
            uiSize: RaftButtonSize.md,
            onPressed: _load,
          ),
        ],
      );
    }
    if (data['viewerRole'] == 'observer') {
      return const RaftActionNote(
        'Someone who can manage this Agent needs to connect this App.',
      );
    }
    final tokens = RaftTokens.of(context);
    final caption = tokens.scale(
      RaftTypeScale.caption,
      color: tokens.ui.foregroundMuted,
    );
    final candidates = cardList(data['candidates']).map(cardObject).toList();
    final pending = cardObject(data['pendingGrant']);
    final pendingId = cardString(pending['connectionId']);
    final defaultEntry = candidates
        .where((entry) => entry['isServerDefault'] == true)
        .firstOrNull;
    final usable = candidates.where((entry) => entry['status'] == 'ready');
    final selected =
        pendingId ??
        _picked ??
        cardString(
          (defaultEntry?['status'] == 'ready'
              ? defaultEntry
              : usable.firstOrNull)?['connectionId'],
        );
    final entry = candidates
        .where((entry) => entry['connectionId'] == selected)
        .firstOrNull;
    final isDefault = entry?['isServerDefault'] == true;
    final canDefault = data['canSetServerDefault'] == true;
    final forcedDefault =
        pendingId != null &&
        data['newConnectionPinnable'] == false &&
        canDefault;
    final makeDefault = forcedDefault || (_makeDefault ?? defaultEntry == null);
    final app = cardObject(data['app']);
    final name =
        cardString(pending['name'] ?? entry?['name']) ??
        raftText(context, 'Unnamed connection');
    return Padding(
      padding: const EdgeInsets.only(top: RaftSpace.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: RaftSpace.x2,
        children: [
          if (error != null) RaftErrorBanner(error, small: true),
          if (pendingId != null) ...[
            RaftActionNote(raftText(context, 'Ready to grant')),
            RaftActionNote(
              raftFormat(
                context,
                '{name} is signed in. {agent} can use it once you grant access.',
                {'name': name, 'agent': widget.agent},
              ),
            ),
          ] else if (candidates.isEmpty)
            RaftActionNote(
              raftFormat(context, '{app} has no connections yet.', {
                'app': app['name'] ?? '',
              }),
            )
          else
            RaftRadioGroup<String>(
              value: selected,
              semanticLabel: raftText(context, 'Choose a connection'),
              onChanged: _busy
                  ? null
                  : (id) => setState(() {
                      _picked = id;
                      _notice.clear();
                    }),
              children: [
                for (final candidate in candidates)
                  if (cardString(candidate['connectionId'])
                      case final String id)
                    RaftRadioGroupItem(
                      value: id,
                      enabled: candidate['status'] == 'ready',
                      gap: RaftSpace.x2,
                      markInset: const EdgeInsets.only(top: RaftSpace.half),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      child: _CandidateDetails(candidate),
                    ),
              ],
            ),
          if (canDefault && selected != null)
            if (isDefault)
              RaftCssText(
                raftFormat(context, 'Server default: {name}', {'name': name}),
                style: caption,
              )
            else
              RaftCheckboxRow(
                title: raftText(context, 'Make this the server default'),
                value: makeDefault,
                onChanged: _busy || forcedDefault
                    ? null
                    : (value) => setState(() => _makeDefault = value),
              ),
          Wrap(
            spacing: RaftSpace.x2,
            runSpacing: RaftSpace.x2,
            children: [
              if (data['canAuthorizeNew'] == true)
                if (pendingId != null)
                  RaftButton(
                    label: 'Discard connection',
                    uiVariant: RaftButtonVariant.outline,
                    uiSize: RaftButtonSize.md,
                    onPressed: _busy ? null : () => _discard(pendingId),
                  )
                else if (app['authKind'] != 'headers')
                  RaftButton(
                    label: 'Authorize new connection',
                    tooltip: raftText(context, 'Open in browser'),
                    uiVariant: RaftButtonVariant.outline,
                    uiSize: RaftButtonSize.md,
                    onPressed: _busy ? null : widget.onOpenWeb,
                  ),
              if (candidates.isNotEmpty || pendingId != null)
                RaftButton(
                  label: _busy
                      ? 'Granting…'
                      : raftFormat(context, 'Grant access to {agent}', {
                          'agent': widget.agent,
                        }),
                  uiVariant: RaftButtonVariant.outline,
                  uiSize: RaftButtonSize.md,
                  onPressed: _busy || selected == null
                      ? null
                      : () => _grant(
                          selected,
                          name,
                          changeDefault:
                              canDefault && makeDefault && !isDefault,
                          followsDefault: isDefault,
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CandidateDetails extends StatelessWidget {
  const _CandidateDetails(this.candidate);

  final CardJson candidate;

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    final isDefault = candidate['isServerDefault'] == true;
    final ready = candidate['status'] == 'ready';
    final name = cardString(candidate['name']?.toString().trim());
    final caption = tokens.scale(
      RaftTypeScale.caption,
      color: ready ? tokens.ui.foregroundMuted : tokens.ui.foregroundDisabled,
    );
    final body = tokens.scale(RaftTypeScale.body);
    final bodySize = body.fontSize ?? RaftTypeScale.body.fontSize;
    final metadataLine = RaftScaled.extent(
      context,
      bodySize * (body.height ?? 1.5),
      fontSize: bodySize,
    );
    final status = switch (candidate['status']) {
      'ready' => 'Ready',
      'pending' => 'Signing in',
      'needs_auth' => 'Needs sign-in',
      'expired' => 'Authorization expired',
      'error' => 'Error',
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RaftCssText(
          name ?? raftText(context, 'Unnamed connection'),
          style: tokens.scale(
            RaftTypeScale.subhead,
            weight: FontWeight.w700,
            color: ready ? tokens.ui.foreground : tokens.ui.foregroundDisabled,
          ),
        ),
        if (isDefault || status != null)
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: metadataLine),
            child: Padding(
              padding: const EdgeInsets.only(top: RaftSpace.half),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: RaftSpace.x1_5,
                  children: [
                    if (isDefault)
                      const RaftBadge(
                        label: 'Default',
                        variant: RaftBadgeRecipeVariant.success,
                      ),
                    if (status != null)
                      RaftCssText(raftText(context, status), style: caption),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: RaftSpace.x1),
          child: RaftCssText(
            raftText(
              context,
              isDefault
                  ? 'Follows future changes to the server default.'
                  : 'Keeps this connection when the server default changes.',
            ),
            style: caption,
          ),
        ),
      ],
    );
  }
}
