import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart'
    show RaftButtonRecipeSize, RaftButtonRecipeVariant;

import '../data/workspace_controller.dart';
import '../platform/oauth_broker.dart';
import 'management_support.dart';
import 'account_password_editor.dart';
import 'account_sign_in_recipe.dart';

class AccountConnectionsView extends StatefulWidget {
  const AccountConnectionsView({
    super.key,
    required this.controller,
    this.inline = false,
  });
  final WorkspaceController controller;
  final bool inline;
  @override
  State<AccountConnectionsView> createState() => _AccountConnectionsState();
}

class _AccountConnectionsState extends ManagementState<AccountConnectionsView> {
  @override
  WorkspaceController get w => widget.controller;
  @override
  String get authority =>
      '${identityHashCode(w.client)}|${w.client.origin}|${w.client.generation}|${w.client.user?.id}';
  List<Map<String, dynamic>> providers = [], identities = [];
  bool passwordConfigured = false,
      passwordSetupSent = false,
      passwordStateKnown = false;
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
    passwordStateKnown = false;
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
    passwordStateKnown = methods['passwordConfigured'] is bool;
    passwordConfigured = methods['passwordConfigured'] == true;
    providers = managementRows(result[1]['providers']);
  }

  Future<void> connect(
    String provider, {
    required String sourceAuthority,
  }) async {
    if (!mounted ||
        sourceAuthority != authority ||
        !passwordStateKnown ||
        !providers.any((p) => p['id'] == provider && p['enabled'] == true)) {
      return;
    }
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
    if (!passwordStateKnown ||
        passwordConfigured ||
        email == null ||
        email.isEmpty) {
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

  Future<void> disconnect(
    String provider, {
    required String sourceAuthority,
  }) async {
    if (!mounted || sourceAuthority != authority) return;
    if (!passwordStateKnown ||
        !identities.any((i) => i['provider'] == provider)) {
      return;
    }
    if (!passwordConfigured && identities.length <= 1) {
      await requestPasswordSetup(sourceAuthority);
      return;
    }
    final accepted = await confirm(
      'Disconnect this sign-in account?',
      'You can still sign in with your remaining account methods.',
      () async {
        await w.client.delete(
          '/auth/identities/${Uri.encodeComponent(provider)}',
        );
      },
      submit: 'Disconnect',
      destructive: true,
    );
    if (accepted && mounted && sourceAuthority == authority) await reload();
  }

  Future<void> requestPasswordSetup(String scope) async {
    if (!mounted || scope != authority || busy) return;
    try {
      // Waiting for human confirmation is not mutation progress. The form
      // owns its submit progress, so no outer spinner runs behind the dialog.
      await sendPasswordSetup();
    } catch (e) {
      if (mounted && scope == authority) setState(() => error = '$e');
    }
  }

  List<Widget> inlineContent(BuildContext context) {
    final sourceScope = authority;
    final recipe = RaftAccountSignInRecipe(RaftTokens.of(context));
    final visible = [
      for (final provider in providers)
        if (provider['enabled'] == true ||
            identities.any((i) => i['provider'] == provider['id']))
          provider,
      for (final identity in identities)
        if (!providers.any((p) => p['id'] == identity['provider']))
          {
            'id': identity['provider'],
            'label': identity['provider'],
            'enabled': false,
          },
    ];
    return [
      if (loading)
        Semantics(
          liveRegion: true,
          child: Text(
            raftText(context, 'Loading sign-in methods…'),
            style: recipe.detail,
          ),
        ),
      if (error != null)
        Semantics(liveRegion: true, child: Text(error!, style: recipe.detail)),
      if (!loading && !passwordStateKnown)
        Text(
          raftText(
            context,
            'Sign-in methods could not be verified. Refresh before changing them.',
          ),
          style: recipe.detail,
        ),
      if (visible.isNotEmpty) ...[
        // `mb-2 text-sm font-bold`
        Text(raftText(context, 'Connected accounts'), style: recipe.heading),
        const SizedBox(height: 8),
        for (final provider in visible) ...[
          Builder(
            builder: (context) {
              final id = provider['id'];
              if (id is! String || id.isEmpty) return const SizedBox();
              final identity = identities
                  .where((i) => i['provider'] == id)
                  .firstOrNull;
              return Semantics(
                container: true,
                label: '${provider['label'] ?? id} account',
                child: Container(
                  padding: RaftAccountSignInRecipe.rowInset,
                  decoration: recipe.providerDecoration,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // `mb-1 flex items-center gap-2 text-xs`:
                            // SocialProviderIcon `size-[18px]` + label.
                            Row(
                              children: [
                                const SizedBox.square(dimension: 18),
                                const SizedBox(width: 8),
                                Text(
                                  '${provider['label'] ?? id}',
                                  style: recipe.providerTitle,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              identity == null
                                  ? raftText(context, 'Not connected')
                                  : raftFormat(
                                      context,
                                      'Connected as {email}',
                                      {
                                        'email':
                                            identity['providerEmail'] ?? '',
                                      },
                                    ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: recipe.detail,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      RaftRecipeButton(
                        label: identity == null ? 'Connect' : 'Disconnect',
                        size: RaftButtonRecipeSize.sm,
                        onPressed: loading || busy || !passwordStateKnown
                            ? null
                            : identity != null
                            ? () => disconnect(id, sourceAuthority: sourceScope)
                            : provider['enabled'] == true
                            ? () => connect(id, sourceAuthority: sourceScope)
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // `space-y-2`
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        Container(height: recipe.dividerWidth, color: recipe.dividerColor),
        const SizedBox(height: RaftAccountSignInRecipe.gap),
      ],
      if (!loading && passwordStateKnown)
        if (passwordConfigured)
          AccountPasswordEditor(
            key: ValueKey('password-$authority'),
            controller: w,
            onUpdated: reload,
          )
        else ...[
          Text(raftText(context, 'Set a password'), style: recipe.heading),
          const SizedBox(height: 4),
          Text(
            raftText(
              context,
              'Add an email and password sign-in method before removing your final connected account.',
            ),
            style: recipe.passwordDetail,
          ),
          const SizedBox(height: RaftAccountSignInRecipe.gap),
          Align(
            alignment: Alignment.centerLeft,
            // `variant="accent" size="sm"`
            child: RaftRecipeButton(
              label: busy ? 'Sending setup email...' : 'Set password by email',
              variant: RaftButtonRecipeVariant.accent,
              size: RaftButtonRecipeSize.sm,
              onPressed: busy
                  ? null
                  : () {
                      if (mounted && sourceScope == authority) {
                        requestPasswordSetup(sourceScope);
                      }
                    },
            ),
          ),
        ],
      if (passwordSetupSent)
        Semantics(
          liveRegion: true,
          child: Text(
            raftText(
              context,
              'Check your account email for a password setup link. Refresh after setting your password.',
            ),
            style: recipe.detail,
          ),
        ),
      if (visible.isEmpty || error != null || !passwordStateKnown)
        Align(
          alignment: Alignment.centerLeft,
          child: RaftTextButton(
            label: 'Refresh sign-in methods',
            glyph: RaftGlyph.refreshCw,
            onPressed: busy ? null : reload,
          ),
        ),
      if (broker != null)
        RaftTextButton(
          label: 'Cancel sign-in',
          onPressed: () => broker?.cancel(),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sourceScope = authority;
    if (widget.inline) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: inlineContent(context),
      );
    }
    return page('Connected sign-in accounts', [
      Text(
        raftText(
          context,
          !passwordStateKnown
              ? 'Loading sign-in methods…'
              : passwordConfigured
              ? 'Password sign-in is configured.'
              : 'Password sign-in is not configured.',
        ),
      ),
      if (passwordStateKnown && !passwordConfigured && !loading)
        action('Set password by email', () {
          if (mounted && sourceScope == authority) {
            requestPasswordSetup(sourceScope);
          }
        }),
      if (passwordSetupSent)
        Text(
          raftText(
            context,
            'Check your account email for a password setup link. Refresh after setting your password.',
          ),
        ),
      for (final provider in [
        ...providers,
        for (final identity in identities)
          if (!providers.any((p) => p['id'] == identity['provider']))
            {
              'id': identity['provider'],
              'label': identity['provider'],
              'enabled': false,
            },
      ])
        Builder(
          builder: (context) {
            final id = provider['id'];
            if (id is! String || id.isEmpty) return const SizedBox();
            final identity = identities
                .where((i) => i['provider'] == id)
                .firstOrNull;
            final canUnlink =
                passwordStateKnown &&
                (passwordConfigured || identities.length > 1);
            return ListTile(
              title: Text('${provider['label'] ?? id}'),
              subtitle: Text(
                identity == null
                    ? raftText(context, 'Not connected')
                    : '${identity['providerEmail'] ?? ''}',
              ),
              trailing: identity == null
                  ? (provider['enabled'] == true &&
                            passwordStateKnown &&
                            !loading
                        ? action(
                            'Connect',
                            () => connect(id, sourceAuthority: sourceScope),
                          )
                        : null)
                  : action(
                      'Disconnect',
                      canUnlink
                          ? () => disconnect(id, sourceAuthority: sourceScope)
                          : null,
                    ),
            );
          },
        ),
      if (passwordStateKnown && !passwordConfigured && identities.length <= 1)
        Text(
          raftText(
            context,
            'Set a password before disconnecting your last sign-in account.',
          ),
        ),
      if (broker != null)
        RaftTextButton(
          label: 'Cancel sign-in',
          onPressed: () => broker?.cancel(),
        ),
    ]);
  }
}
