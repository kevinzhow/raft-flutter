import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'human_login.dart';
import 'human_login_servers.dart';

/// The native "Login with Raft" confirmation: Web `HumanLoginSetupPage` for
/// an app that opened its sign-in inside the in-app browser. A bottom sheet on
/// narrow windows, a dialog on wide ones ([showRaftForm]).
///
/// Resolves to the URL the browser goes to once the person confirmed and
/// Raft issued the code, or null when they cancelled or it failed. Nothing is
/// authorized unless the person presses "Login with Raft" (or "Continue
/// login"), and nothing is installed unless they press "Install and
/// continue": selecting a server does neither.
Future<Uri?> showHumanLoginSheet(
  BuildContext context, {
  required HumanLoginApi api,
  required HumanLoginRequest request,
}) => showRaftForm<Uri>(
  context,
  builder: (_) => HumanLoginSheet(api: api, request: request),
  // No text input: nothing to guard.
  guardUnsaved: false,
  label: 'Login with Raft',
);

class HumanLoginSheet extends StatefulWidget {
  const HumanLoginSheet({super.key, required this.api, required this.request});
  final HumanLoginApi api;
  final HumanLoginRequest request;

  @override
  State<HumanLoginSheet> createState() => _HumanLoginSheetState();
}

class _HumanLoginSheetState extends State<HumanLoginSheet> {
  HumanLoginLookup? lookupResult;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared by a new attempt (Login with Raft, Install and continue or another server) and gone with the sheet.
  String? failure;
  String selectedId = '';

  /// The authorization is under way.
  bool submitting = false;

  /// The server an install (and the login after it) is under way on.
  String installingId = '';

  /// A lookup that found nothing, or never answered: only Back remains.
  bool lookupFailed = false;

  bool get busy => submitting || installingId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    unawaited(lookup());
  }

  Future<void> lookup() async {
    try {
      final found = await lookupHumanLoginClient(widget.api, widget.request);
      if (!mounted) return;
      setState(() {
        lookupResult = found;
        // Web: the best server first (ready, then installable).
        selectedId = found.choices.first.server.id;
      });
    } on HumanLoginException catch (error) {
      if (!mounted) return;
      setState(() {
        failure = error.text;
        lookupFailed = true;
      });
    }
  }

  HumanLoginRow? get row =>
      lookupResult?.rows.where((r) => r.server.id == selectedId).firstOrNull;

  HumanLoginChoice? get choice => row?.choice;

  Future<void> confirm() async {
    final current = choice;
    if (current == null ||
        busy ||
        !humanLoginCanContinue(widget.request, current)) {
      return;
    }
    setState(() {
      submitting = true;
      failure = null;
    });
    try {
      final location = await authorizeHumanLogin(
        widget.api,
        widget.request,
        current,
      );
      if (!mounted) return;
      Navigator.of(context).pop(location);
    } on HumanLoginException catch (error) {
      if (!mounted) return;
      setState(() {
        submitting = false;
        failure = error.text;
      });
    }
  }

  /// Web `installMarketplaceApp`: the person pressed "Install and continue"
  /// for the selected server. Installs there, then asks for the login.
  Future<void> installAndContinue() async {
    final current = choice;
    if (current == null ||
        busy ||
        !humanLoginCanInstall(widget.request, current)) {
      return;
    }
    setState(() {
      installingId = current.server.id;
      failure = null;
    });
    final HumanLoginChoice installed;
    try {
      installed = await installHumanLoginApp(widget.api, current);
    } on HumanLoginException catch (error) {
      if (!mounted) return;
      setState(() {
        installingId = '';
        failure = error.text;
      });
      return;
    }
    if (!mounted) return;
    // The app is on the server now, whatever the login answers.
    setState(() => lookupResult = lookupResult!.replaced(installed));
    try {
      final location = await authorizeHumanLogin(
        widget.api,
        widget.request,
        installed,
      );
      if (!mounted) return;
      Navigator.of(context).pop(location);
    } on HumanLoginException catch (error) {
      if (!mounted) return;
      setState(() {
        installingId = '';
        failure = error.text;
      });
    }
  }

  void cancel() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    String tr(String s) => raftText(context, s);
    final found = lookupResult;
    final current = row;
    final scopes = widget.request.scopes;
    final marketplace = found?.isMarketplace ?? false;
    final commit = humanLoginCommit(current);
    final details = found?.detailsClient(selectedId);
    final notAccessible =
        lookupFailed && failure == HumanLoginMessages.notRegisteredForAny;
    final choiceNow = choice;
    // The primary button, as Web words it: a Marketplace app continues with
    // "Continue login", or installs first; any other app is "Login with Raft".
    final installing = installingId.isNotEmpty;
    final String? primaryLabel = lookupFailed
        ? null
        : !marketplace
        ? (submitting ? 'Continuing...' : 'Login with Raft')
        : switch (commit) {
            HumanLoginCommit.adminNeeded => null,
            HumanLoginCommit.install =>
              installing
                  ? 'Installing and continuing...'
                  : 'Install and continue',
            _ => submitting ? 'Continuing...' : 'Continue login',
          };
    final VoidCallback? primary = choiceNow == null || busy
        ? null
        : commit == HumanLoginCommit.install
        ? (humanLoginCanInstall(widget.request, choiceNow)
              ? installAndContinue
              : null)
        : (humanLoginCanContinue(widget.request, choiceNow) ? confirm : null);
    return PopScope(
      // The code is being issued, or the app installed: closing now would
      // leave it half done.
      canPop: !busy,
      child: RaftDialog.card(
        key: const ValueKey('human-login-sheet'),
        title: 'Login with Raft',
        onClose: busy ? () {} : cancel,
        // "Installing and continuing..." does not fit beside Cancel on a
        // phone: the buttons wrap instead of overflowing.
        actions: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: RaftSpace.x3,
          runSpacing: RaftSpace.x2,
          children: [
            RaftButton(
              key: const ValueKey('human-login-cancel'),
              label: tr(lookupFailed ? 'Back' : 'Cancel'),
              tone: RaftButtonRecipeVariant.outline,
              size: RaftButtonRecipeSize.md,
              onPressed: busy ? null : cancel,
            ),
            if (primaryLabel != null)
              RaftButton(
                key: const ValueKey('human-login-continue'),
                label: tr(primaryLabel),
                tone: RaftButtonRecipeVariant.accent,
                size: RaftButtonRecipeSize.md,
                onPressed: primary,
              ),
          ],
        ),
        child: _Scrolls(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: RaftSpace.x3,
            children: [
              if (found == null && !lookupFailed)
                RaftDialogDescription('Loading available Raft Servers...'),
              if (notAccessible)
                const HumanLoginNotAccessible()
              else if (found != null && details != null) ...[
                ..._app(context, current, details),
                HumanLoginServerField(
                  lookup: found,
                  selectedId: selectedId,
                  enabled: !busy,
                  installingId: installingId,
                  onSelect: (id) => setState(() {
                    selectedId = id;
                    failure = null;
                  }),
                ),
                _ConsentCard(
                  key: const ValueKey('human-login-scopes'),
                  scopes: scopes,
                ),
                ..._notices(context, current?.client, scopes),
                if (marketplace)
                  HumanLoginCommitZone(
                    row: current,
                    scopes: scopes,
                    busy: installing,
                  ),
              ],
              if (failure != null && !notAccessible)
                RaftErrorBanner(
                  tr(failure!),
                  key: const ValueKey('human-login-error'),
                  bold: true,
                ),
              if (found != null || notAccessible) const HumanLoginFaq(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _app(
    BuildContext context,
    HumanLoginRow? current,
    HumanLoginClient client,
  ) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final serviceName = client.name.isNotEmpty ? client.name : tr('this app');
    return [
      Text(
        raftFormat(context, '{serviceName} wants to connect to {serverName}', {
          'serviceName': serviceName,
          'serverName': current?.server.name ?? tr('this server'),
        }),
        key: const ValueKey('human-login-title'),
        style: RaftTypography.heading(t, size: 16, line: 22),
      ),
      Text.rich(
        TextSpan(
          children: raftRichText(
            context,
            'Use your Raft account with <b>{serviceName}</b> on an available Raft Server.',
            {
              'b': (inner) => TextSpan(
                text: inner,
                style: RaftTypography.inherited(
                  t,
                  size: 14,
                  line: 20,
                  weight: FontWeight.w700,
                  color: t.ink,
                ),
              ),
            },
            values: {'serviceName': serviceName},
          ),
        ),
        style: RaftTypography.inherited(t, size: 14, line: 20, color: t.muted),
      ),
      if (widget.api.signedInAs case final String who when who.isNotEmpty)
        Text(
          '${tr('Signed in as')} $who',
          style: RaftTypography.inherited(
            t,
            size: 12,
            line: 16,
            color: t.colors['foreground-hint'],
          ),
        ),
      RaftDialogSectionEyebrow('App details'),
      _AppCard(client: client),
    ];
  }

  List<Widget> _notices(
    BuildContext context,
    HumanLoginClient? client,
    List<String> scopes,
  ) {
    if (client == null) return const [];
    String tr(String s) => raftText(context, s);
    String fill(String s, Map<String, Object?> values) =>
        raftFormat(context, s, values);
    final name = client.name.isNotEmpty ? client.name : tr('this app');
    final disallowed = client.disallowedScopes;
    final reason = client.scopeReason;
    return [
      if (disallowed.isNotEmpty)
        RaftErrorBanner(
          key: const ValueKey('human-login-scope-error'),
          '${tr(reason == 'unsupported'
              ? 'Unsupported OAuth scope'
              : reason == 'mixed'
              ? 'Invalid OAuth scope request'
              : 'OAuth client permissions need attention')}\n'
          '${fill(reason == 'unsupported'
              ? "{appName} requested OAuth scopes Raft does not support: {scopes}. Update the app's requested scopes before trying again."
              : reason == 'mixed'
              ? '{appName} requested scopes that are unsupported or not granted to this OAuth client: {scopes}. Update the app request or client permissions before trying again.'
              : '{appName} is requesting access it has not been granted: {scopes}. Ask the app owner to add these scopes to the OAuth client before trying again.', {'appName': name, 'scopes': disallowed.join(', ')})}',
        ),
    ];
  }
}

/// The sheet scrolls its body itself; a dialog has no room to grow past the
/// window, so its body scrolls under a cap (above the default text size the
/// card scrolls as a whole).
class _Scrolls extends StatelessWidget {
  const _Scrolls({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (RaftFormFrame.sheetOf(context) || RaftScaled.grows(context)) {
      return child;
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        // ds-allow: the dialog card has no scroller below the large-text size; the body is capped to the window
        maxHeight: math.max(160, MediaQuery.sizeOf(context).height - 260),
      ),
      child: SingleChildScrollView(child: child),
    );
  }
}

class _AppCard extends StatelessWidget {
  const _AppCard({required this.client});
  final HumanLoginClient client;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    return RaftCard(
      padding: const EdgeInsets.all(RaftSpace.x3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: RaftSpace.x3,
        children: [
          RaftAppLogo(initials: client.initials, logoUrl: client.logoUrl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: RaftSpace.x1,
              children: [
                Wrap(
                  spacing: RaftSpace.x2,
                  runSpacing: RaftSpace.x1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      client.name,
                      style: RaftTypography.heading(t, size: 14, line: 20),
                    ),
                    RaftSettingsRecipeBadge(
                      label: tr(
                        client.marketplace || client.installRequired
                            ? 'Marketplace'
                            : 'Ready',
                      ),
                      variant: RaftBadgeRecipeVariant.success,
                      appearance: RaftBadgeRecipeAppearance.soft,
                    ),
                  ],
                ),
                if (client.description != null)
                  Text(
                    client.description!,
                    style: RaftTypography.inherited(
                      t,
                      size: 13,
                      line: 18,
                      color: t.muted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Web `RequestedScopeConsent` / `oauthScopePresentation`: what the request
/// will grant, in the same words.
class _ConsentCard extends StatelessWidget {
  const _ConsentCard({super.key, required this.scopes});
  final List<String> scopes;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final visible = normalizeVisibleOAuthScopes(scopes);
    final unrecognized = <String>[];
    for (final scope in scopes) {
      final trimmed = scope.trim();
      if (trimmed.isNotEmpty &&
          !visible.contains(trimmed) &&
          !unrecognized.contains(trimmed)) {
        unrecognized.add(trimmed);
      }
    }
    final inbound = hasAgentInboundScope(visible);
    final intro = unrecognized.isNotEmpty
        ? 'Recognized capabilities are shown below. Review unrecognized requested scopes before continuing.'
        : visible.contains('agent:read')
        ? 'This app requests access to the agent directory in your selected Server, along with the other permissions listed below.'
        : inbound
        ? 'Recognized capabilities are shown below. Agent messaging requires Agent Login.'
        : 'These scopes are the exact capabilities this Login with Raft request will grant.';
    final muted = RaftTypography.inherited(
      t,
      size: 12,
      line: 16,
      weight: FontWeight.w600,
      color: t.muted,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x1,
      children: [
        RaftDialogSectionEyebrow('Requested access', color: t.ink),
        Text(
          tr(intro),
          style: RaftTypography.inherited(
            t,
            size: 14,
            line: 20,
            color: t.muted,
          ),
        ),
        const SizedBox(height: RaftSpace.x1),
        RaftCard(
          padding: const EdgeInsets.all(RaftSpace.x3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: RaftSpace.x3,
            children: [
              if (visible.isEmpty)
                Text(
                  tr('No recognized Raft scopes were requested.'),
                  style: muted,
                ),
              for (final tier in OAuthScopeTier.values)
                if (visible.any((s) => oauthScopeTier(s) == tier))
                  _TierGroup(
                    tier: tier,
                    scopes: [
                      for (final s in visible)
                        if (oauthScopeTier(s) == tier) s,
                    ],
                  ),
              if (inbound)
                Text(
                  tr(
                    'Agent messaging requires Raft Agent Login. Cannot send chat as you, speak as the agent, read messages, or take actions.',
                  ),
                  style: muted,
                ),
              if (unrecognized.isNotEmpty)
                Wrap(
                  spacing: RaftSpace.x1_5,
                  runSpacing: RaftSpace.x1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(tr('Unrecognized scopes:'), style: muted),
                    for (final scope in unrecognized)
                      Text(
                        scope,
                        style: RaftTypography.mono(t, size: 12, line: 16),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TierGroup extends StatelessWidget {
  const _TierGroup({required this.tier, required this.scopes});
  final OAuthScopeTier tier;
  final List<String> scopes;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: tr(oauthTierLabel(tier)),
                style: RaftTypography.inherited(
                  t,
                  size: 14,
                  line: 20,
                  weight: FontWeight.w700,
                  color: t.ink,
                ),
              ),
              if (tier == OAuthScopeTier.identity)
                TextSpan(
                  text: tr(
                    ' — Who you are and your basic profile · no content access.',
                  ),
                  style: RaftTypography.inherited(
                    t,
                    size: 14,
                    line: 20,
                    color: t.muted,
                  ),
                ),
            ],
          ),
        ),
        for (final scope in scopes)
          Padding(
            key: ValueKey('human-login-scope-$scope'),
            padding: const EdgeInsets.only(top: RaftSpace.x2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: RaftSpace.x1,
              children: [
                Text(
                  scope,
                  style: RaftTypography.mono(
                    t,
                    size: 12,
                    line: 16,
                    color: t.ink,
                  ),
                ),
                Text(
                  tr(oauthScopeCopy(scope)),
                  style: RaftTypography.inherited(
                    t,
                    size: 13,
                    line: 18,
                    color: t.muted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
