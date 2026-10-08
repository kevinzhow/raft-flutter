import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../platform/oauth_broker.dart';
import 'management_support.dart';

class AccountConnectionsView extends StatefulWidget {
  const AccountConnectionsView({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<AccountConnectionsView> createState() => _AccountConnectionsState();
}

class _AccountConnectionsState extends ManagementState<AccountConnectionsView> {
  @override
  WorkspaceController get w => widget.controller;
  List<Map<String, dynamic>> providers = [], identities = [];
  bool passwordConfigured = false, passwordSetupSent = false;
  NativeOAuthBroker? broker;
  @override
  void initState() {
    super.initState();
    startManagement();
  }

  @override
  void clearData() {
    providers = [];
    identities = [];
    passwordConfigured = false;
    passwordSetupSent = false;
    unawaited(broker?.cancel() ?? Future<void>.value());
  }

  @override
  void dispose() {
    unawaited(broker?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Future<void> loadData(int request, int generation) async {
    final result = await Future.wait([
      w.client.get('/auth/identities'),
      w.client.get('/auth/providers', query: {'platform': 'mobile'}),
    ]);
    if (!accepts(generation, request)) return;
    final methods = managementMap(result[0]);
    identities = managementRows(methods['identities']);
    passwordConfigured = methods['passwordConfigured'] == true;
    providers = managementRows(result[1]['providers']);
  }

  Future<void> connect(String provider) async {
    final generation = w.client.generation, scope = authority;
    final active = NativeOAuthBroker();
    broker = active;
    await run(() async {
      try {
        final handoff = await active.begin(w.client, provider, mode: 'link');
        if (!accepts(generation) || scope != authority) return;
        await w.client.post(
          '/auth/mobile/oauth/$provider/link/complete',
          data: {'code': handoff.code, 'codeVerifier': handoff.verifier},
        );
      } finally {
        await active.cancel();
        if (identical(broker, active)) broker = null;
      }
    });
  }

  Future<void> sendPasswordSetup() async {
    final sourceScope = authority, generation = w.client.generation;
    final email = w.client.user?.string('email');
    if (email == null || email.isEmpty) {
      throw StateError(
        'Refresh your account before requesting password setup.',
      );
    }
    await confirm(
      'Set password by email',
      'Send a password setup link to your account email address?',
      () async {
        await w.client.post('/auth/forgot-password', data: {'email': email});
        if (accepts(generation) && sourceScope == authority) {
          setState(() => passwordSetupSent = true);
        }
      },
      submit: 'Send email',
    );
  }

  @override
  Widget build(BuildContext context) => page('Connected sign-in accounts', [
    Text(
      raftText(
        context,
        passwordConfigured
            ? 'Password sign-in is configured.'
            : 'Password sign-in is not configured.',
      ),
    ),
    if (!passwordConfigured && !loading)
      action(
        'Set password by email',
        () => run(sendPasswordSetup, refresh: false),
      ),
    if (passwordSetupSent)
      Text(
        raftText(
          context,
          'Check your account email for a password setup link. Refresh after setting your password.',
        ),
      ),
    for (final provider in providers) ...[
      Builder(
        builder: (context) {
          final id = provider['id'] as String;
          final identity = identities
              .where((i) => i['provider'] == id)
              .firstOrNull;
          final canUnlink = passwordConfigured || identities.length > 1;
          return ListTile(
            title: Text('${provider['label'] ?? id}'),
            subtitle: Text(
              identity == null
                  ? raftText(context, 'Not connected')
                  : '${identity['providerEmail'] ?? ''}',
            ),
            trailing: identity == null
                ? (provider['enabled'] == true
                      ? action('Connect', () => connect(id))
                      : null)
                : action(
                    'Disconnect',
                    canUnlink
                        ? () => run(() async {
                            await confirm(
                              'Disconnect this sign-in account?',
                              'You can still sign in with your remaining account methods.',
                              () async {
                                await w.client.delete('/auth/identities/$id');
                              },
                              submit: 'Disconnect',
                              destructive: true,
                            );
                          })
                        : null,
                  ),
          );
        },
      ),
    ],
    for (final identity in identities.where(
      (i) => !providers.any((p) => p['id'] == i['provider']),
    ))
      ListTile(
        title: Text('${identity['provider']}'),
        subtitle: Text('${identity['providerEmail'] ?? ''}'),
        trailing: action(
          'Disconnect',
          passwordConfigured || identities.length > 1
              ? () => run(() async {
                  await confirm(
                    'Disconnect this sign-in account?',
                    'You can still sign in with your remaining account methods.',
                    () async {
                      await w.client.delete(
                        '/auth/identities/${identity['provider']}',
                      );
                    },
                    submit: 'Disconnect',
                    destructive: true,
                  );
                })
              : null,
        ),
      ),
    if (!passwordConfigured && identities.length <= 1)
      Text(
        raftText(
          context,
          'Set a password before disconnecting your last sign-in account.',
        ),
      ),
    if (broker != null)
      TextButton(
        onPressed: () => broker?.cancel(),
        child: Text(raftText(context, 'Cancel sign-in')),
      ),
  ]);
}
