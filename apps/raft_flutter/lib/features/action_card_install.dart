import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/app_install_expectation.dart' show effectiveAllowedOAuthScopes;
import '../data/cause_notice.dart';
import '../data/user_error.dart';
import 'action_card_spec.dart';
import 'integrations_views.dart'
    show integrationScopeCopy, integrationVisibleScopes;
import 'second_factor_step_up.dart';

class ActionCardInstallDialog extends StatefulWidget {
  const ActionCardInstallDialog({
    super.key,
    required this.action,
    required this.agent,
    required this.readMarketplace,
    required this.execute,
  });

  final CardJson action;
  final String agent;
  final Future<({List<CardJson> apps, bool promptConsent})> Function(bool fresh)
  readMarketplace;
  final Future<void> Function(BuildContext) execute;

  @override
  State<ActionCardInstallDialog> createState() =>
      _ActionCardInstallDialogState();
}

class _ActionCardInstallDialogState extends State<ActionCardInstallDialog> {
  CardJson? _record;
  bool _promptConsent = false;
  bool _loading = true, _failed = false, _busy = false;
  final _notice = CauseNotice();
  bool _blocked = false;

  CardJson get _action => widget.action;
  bool get _bound =>
      _action['installScopes'] is List && _action['installGroups'] is List;

  @override
  void initState() {
    super.initState();
    if (_bound) unawaited(_load(false));
  }

  Future<void> _load(bool fresh) async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final result = await widget.readMarketplace(fresh);
      if (!mounted) return;
      setState(() {
        _promptConsent = result.promptConsent;
        _record = result.apps
            .where((entry) => entry['id'] == _action['clientId'])
            .firstOrNull;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Set<String> _scopes(CardJson record) =>
      effectiveAllowedOAuthScopes(record['allowedScopes']).toSet();

  bool _sameSet(Iterable<String> left, Object? raw) {
    final right = cardList(raw).whereType<String>().toSet();
    return right.length == left.length && left.every(right.contains);
  }

  String? _stale(CardJson record) {
    final name = cardString(record['name']);
    if (name == null ||
        record['clientId'] != _action['clientKey'] ||
        sha256.convert(utf8.encode(name)).toString() !=
            _action['clientNameSha256'] ||
        record['appType'] != 'third_party_global' ||
        record['humanMarketplaceVisible'] != true ||
        !const {
          'published',
          'unpublish_requested',
        }.contains(record['publishStatus'])) {
      return '{client} can no longer be installed from this request. Ask {agent} to prepare it again.';
    }
    if (!_sameSet(_scopes(record), _action['installScopes']) ||
        !_sameSet(
          cardList(record['appNotificationGroups']).whereType<String>().toSet(),
          _action['installGroups'],
        )) {
      return '{client} changed its permissions after this request was prepared. Ask {agent} to prepare it again.';
    }
    if (_promptConsent &&
        record['promptTextRevisionId'] != _action['installTextRevisionId']) {
      return '{client} changed the text it adds to agent prompts after this request was prepared. Ask {agent} to prepare it again.';
    }
    return null;
  }

  Future<void> _install() async {
    setState(() {
      _busy = true;
      _notice.clear();
    });
    try {
      await widget.execute(context);
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted || isSecondFactorStepUpCancelled(error)) return;
      final terminal = switch (error) {
        RaftApiException(:final code)
            when const {
              'APP_PERMISSIONS_CHANGED',
              'MARKETPLACE_APP_CHANGED',
              'SCOPE_BINDING_CHANGED',
              'AGENT_BINDING_CHANGED',
              'APP_PROMPT_TEXT_CHANGED',
              'APP_TEXT_CHANGED',
            }.contains(code) =>
          true,
        _ => false,
      };
      setState(() {
        final copy = userErrorText(
          error,
          fallback: 'Failed to execute action',
          where: 'install app card',
        );
        _blocked = terminal;
        _notice.raise(copy);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    final name = cardString(record?['name']) ?? '';
    final values = {'agent': widget.agent, 'client': name};
    final stale = record == null ? null : _stale(record);
    final canInstall =
        _bound &&
        !_loading &&
        !_failed &&
        record != null &&
        stale == null &&
        !_blocked;
    final error = _notice.message;
    final description = raftFormat(
      context,
      record == null || !_bound
          ? "{agent} asked to sign in to an app that isn't installed on this Server."
          : "{agent} asked to sign in to {client}, which isn't installed on this Server. Installing it approves all of the following for this Server: the permissions {client} declared when this request was prepared.",
      values,
    );
    return PopScope(
      canPop: !_busy,
      child: RaftDialog.card(
        title: 'Install App',
        description: description,
        onClose: () {
          if (!_busy) Navigator.of(context).maybePop();
        },
        actions: Wrap(
          alignment: WrapAlignment.end,
          spacing: RaftSpace.x2,
          children: [
            RaftButton(
              label: 'Cancel',
              uiVariant: RaftButtonVariant.ghost,
              uiSize: RaftButtonSize.md,
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            ),
            if (canInstall)
              RaftButton(
                label: _busy ? 'Installing…' : 'Install',
                uiVariant: RaftButtonVariant.outline,
                uiSize: RaftButtonSize.md,
                onPressed: _busy ? null : _install,
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: RaftSpace.x3,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_bound)
              RaftErrorBanner(
                raftFormat(
                  context,
                  "This request was prepared before Raft recorded the app's permissions on it, so it can't be installed from here. Ask {agent} to prepare a fresh one.",
                  values,
                ),
                small: true,
              )
            else if (_loading)
              const Center(child: RaftSpinner())
            else if (_failed) ...[
              const RaftErrorBanner(
                'Could not load Marketplace apps.',
                small: true,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: RaftButton(
                  label: 'Try again',
                  uiSize: RaftButtonSize.md,
                  onPressed: () => _load(true),
                ),
              ),
            ] else if (record == null)
              RaftErrorBanner(
                raftFormat(
                  context,
                  'This app can no longer be installed from this request. Ask {agent} to prepare a fresh one.',
                  values,
                ),
                small: true,
              )
            else ...[
              RaftActionScopeList(
                scopes: [
                  for (final scope in _scopes(
                    record,
                  ).where(integrationVisibleScopes.contains))
                    (scope: scope, copy: integrationScopeCopy[scope] ?? ''),
                  for (final group in cardList(
                    record['appNotificationGroups'],
                  ).whereType<String>())
                    (scope: group, copy: ''),
                ],
              ),
              if (_promptConsent)
                for (final key in [
                  'description',
                  'shortDescription',
                  'setupDescription',
                ])
                  if (cardString(record[key]) case final String text)
                    Text(text),
              if (stale != null)
                RaftErrorBanner(
                  raftFormat(context, stale, values),
                  small: true,
                ),
            ],
            if (error != null) RaftErrorBanner(error, small: true),
          ],
        ),
      ),
    );
  }
}
