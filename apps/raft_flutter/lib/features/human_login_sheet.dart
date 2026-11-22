import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_install_expectation.dart';
import 'human_login.dart';
import 'human_login_servers.dart';
import 'second_factor_step_up.dart';

const _loginDialogWidth = 600.0 + RaftSpace.x4 * 2;
const _unavailableDialogWidth = _loginDialogWidth + RaftSpace.x4 * 2;

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
  Future<bool> Function(Uri)? openExternal,
  Future<void> Function(Uri location)? openInApp,
}) => showRaftForm<Uri>(
  context,
  builder: (_) => HumanLoginSheet(
    api: api,
    request: request,
    openExternal: openExternal,
    openInApp: openInApp,
  ),
  // No text input: nothing to guard.
  guardUnsaved: false,
  label: 'Login with Raft',
  dialogMaxWidth: _unavailableDialogWidth,
);

class HumanLoginSheet extends StatefulWidget {
  const HumanLoginSheet({
    super.key,
    required this.api,
    required this.request,
    this.openExternal,
    this.openInApp,
  });
  final HumanLoginApi api;
  final HumanLoginRequest request;

  /// Opens a Web page in the system browser (tests replace it).
  final Future<bool> Function(Uri)? openExternal;

  /// Leaves the sign-in for an app location (`/s/<slug>/members`); called
  /// after the sheet closes. Null outside the app shell: the page then opens
  /// in the browser.
  final Future<void> Function(Uri location)? openInApp;

  @override
  State<HumanLoginSheet> createState() => _HumanLoginSheetState();
}

class _HumanLoginSheetState extends State<HumanLoginSheet> {
  HumanLoginLookup? lookupResult;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared by a new attempt (Login with Raft, Install and continue or another server) and gone with the sheet.
  String? failure;
  String selectedId = '';
  bool loginModeChanged = false;
  HumanLoginAccountRefusal? accountRefusal;
  final installConsentByServer = <String, bool>{};
  final loadingInstallConsent = <String>{};
  (String, bool)? installBotChoice;
  (String, String)? botConflict;

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
        failure = null;
        lookupFailed = false;
        // Web: the best server first (ready, then installable).
        selectedId = found.choices.first.server.id;
      });
      unawaited(_loadInstallConsent());
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

  Future<void> _loadInstallConsent() async {
    final current = choice;
    if (current == null ||
        !current.client.canInstall ||
        current.client.promptTextRevisionId == null) {
      return;
    }
    final id = current.server.id;
    if (installConsentByServer.containsKey(id) ||
        !loadingInstallConsent.add(id)) {
      return;
    }
    var enabled = false;
    try {
      enabled = await widget.api.promptTextConsent(id);
    } finally {
      if (mounted) {
        setState(() {
          loadingInstallConsent.remove(id);
          installConsentByServer[id] = enabled;
        });
      }
    }
  }

  AppInstallExpectation? get reviewedInstall {
    final current = choice;
    if (current == null || !current.client.canInstall) return null;
    final enabled = installConsentByServer[current.server.id];
    if (current.client.promptTextRevisionId != null && enabled == null) {
      return null;
    }
    return current.client.installExpectation(
      promptTextConsent: enabled == true,
    );
  }

  bool get joinsBot => switch (installBotChoice) {
    (final id, final value) when id == selectedId => value,
    _ => true,
  };

  bool get accountView {
    final account = lookupResult?.accountChoice;
    return account != null &&
        (widget.request.serverHint.isNotEmpty ||
            account.client.ready ||
            !lookupResult!.choices.any(
              (choice) => choice.client.installRequired,
            ));
  }

  String? get accountRefusalText {
    if (!accountView) return null;
    if (widget.request.serverHint.isNotEmpty) {
      return HumanLoginMessages.rootIssuerRequired;
    }
    return accountRefusal?.text ??
        (lookupResult!.accountChoice!.client.suspended
            ? HumanLoginMessages.accountSuspended
            : null);
  }

  /// Giving an app access to the account: with two-step verification on,
  /// "Verify it's you" first (Web HumanLoginSetupPage, reason appAccess).
  Future<dynamic> stepUp(Future<dynamic> Function() request) {
    final api = widget.api;
    return api is ClientHumanLoginApi
        ? withSecondFactorStepUp(
            context,
            api.client,
            request,
            reason: StepUpReason.appAccess,
          )
        : request();
  }

  Future<void> confirm() async {
    final current = accountView ? lookupResult?.accountChoice : choice;
    if (current == null ||
        busy ||
        accountRefusalText != null ||
        !humanLoginCanContinue(widget.request, current)) {
      return;
    }
    setState(() {
      submitting = true;
      failure = null;
    });
    await _authorize(current);
  }

  /// Web `installMarketplaceApp`: the person pressed "Install and continue"
  /// for the selected server. Installs there, then asks for the login.
  Future<void> installAndContinue() async {
    final current = choice;
    final reviewed = reviewedInstall;
    if (current == null ||
        reviewed == null ||
        busy ||
        !humanLoginCanInstall(widget.request, current)) {
      return;
    }
    setState(() {
      installingId = current.server.id;
      failure = null;
      botConflict = null;
    });
    final HumanLoginChoice installed;
    try {
      installed = await installHumanLoginApp(
        widget.api,
        current,
        reviewed: reviewed,
        bot: current.client.botHandle == null ? null : joinsBot,
        guard: stepUp,
      );
    } on SecondFactorStepUpCancelled {
      if (mounted) setState(() => installingId = '');
      return;
    } on HumanLoginPermissionsChanged catch (error) {
      if (!mounted) return;
      // Web: the current set replaces the shown one, so the next press
      // confirms what the server holds now.
      setState(() {
        installingId = '';
        lookupResult = lookupResult!.replaced(
          error.choice,
          allInstalling: true,
        );
        failure = error.text;
      });
      return;
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
    setState(() {
      lookupResult = lookupResult!.replaced(installed);
      if (installed.botConflict case final handle?) {
        botConflict = (current.server.id, handle);
      }
    });
    await _authorize(installed);
  }

  Future<void> _authorize(HumanLoginChoice current) async {
    try {
      final location = await authorizeHumanLogin(
        widget.api,
        widget.request,
        current,
        guard: stepUp,
      );
      if (!mounted) return;
      Navigator.of(context).pop(location);
    } on HumanLoginModeChanged {
      if (!mounted) return;
      setState(() {
        lookupResult = null;
        lookupFailed = false;
        loginModeChanged = true;
      });
      await lookup();
    } on SecondFactorStepUpCancelled {
      return;
    } on HumanLoginAccountRefusal catch (error) {
      if (mounted) setState(() => accountRefusal = error);
    } on HumanLoginException catch (error) {
      if (!mounted) return;
      setState(() {
        failure = error.text;
        lookupFailed = error.text == HumanLoginMessages.notRegisteredForAny;
      });
    } finally {
      if (mounted) {
        setState(() {
          installingId = '';
          submitting = false;
        });
      }
    }
  }

  void cancel() => Navigator.of(context).pop();

  /// Web links "Find a server admin" to the Server's members page
  /// (`/s/{slug}/members`) on the Raft Web app. The sheet runs inside an
  /// artifact's sign-in, with no workspace of that Server open, so the page
  /// opens in the browser and the sign-in stays where it is.
  /// Web HumanLoginSetupPage.tsx:755-760: a same-tab link to that Server's
  /// Members page, an app route (App.tsx:1502 `/s/:serverSlug/*`), so the
  /// person leaves the sign-in for it. In the app that is the app's own
  /// Members page; the sheet closes, authorizing nothing.
  void findAdmin(HumanLoginServer server) {
    final members = Uri.parse('/s/${Uri.encodeComponent(server.slug)}/members');
    final inApp = widget.openInApp;
    if (inApp != null) {
      Navigator.of(context).pop();
      unawaited(inApp(members));
      return;
    }
    unawaited(openExternal(widget.api.webOrigin.resolveUri(members)));
  }

  Future<bool> openExternal(Uri uri) =>
      widget.openExternal?.call(uri) ??
      launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    String tr(String s) => raftText(context, s);
    final found = lookupResult;
    final current = row;
    final scopes = widget.request.scopes;
    final marketplace = found?.isMarketplace ?? false;
    final commit = humanLoginCommit(current);
    final account = found?.accountChoice;
    final refusal = accountRefusalText;
    final details = accountView
        ? account?.client
        : found?.detailsClient(selectedId);
    final notAccessible =
        lookupFailed &&
        (failure == HumanLoginMessages.notRegisteredForAny ||
            failure == HumanLoginMessages.noServerAccess);
    final lookupUnavailable =
        lookupFailed && failure == HumanLoginMessages.serverStatusUnavailable;
    final choiceNow = accountView ? account : choice;
    // The primary button, as Web words it: a Marketplace app continues with
    // "Continue login", or installs first; any other app is "Login with Raft".
    final installing = installingId.isNotEmpty;
    final String? primaryLabel =
        found == null || lookupFailed || refusal != null
        ? null
        : accountView || !marketplace
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
        : !accountView && commit == HumanLoginCommit.install
        ? (reviewedInstall != null &&
                  humanLoginCanInstall(widget.request, choiceNow)
              ? installAndContinue
              : null)
        : (humanLoginCanContinue(widget.request, choiceNow) ? confirm : null);
    final actions = Wrap(
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
        if (lookupUnavailable)
          RaftButton(
            label: tr('Retry'),
            tone: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.md,
            onPressed: () {
              setState(() {
                failure = null;
                lookupFailed = false;
              });
              unawaited(lookup());
            },
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
    );
    const contentKey = ValueKey('human-login-content');
    final showCommitZone =
        !notAccessible &&
        (details != null || lookupUnavailable) &&
        marketplace &&
        !accountView;
    final separateCommit =
        showCommitZone && commit != HumanLoginCommit.adminNeeded;
    final consent = Column(
      key: separateCommit ? contentKey : null,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x3,
      children: [
        if (found == null && !lookupFailed) const _LoginLookupLoading(),
        if (notAccessible)
          HumanLoginNotAccessible(signedInAs: widget.api.signedInAs)
        else if (details != null || lookupUnavailable) ...[
          ..._app(
            context,
            current,
            details,
            refusal,
            lookupError: lookupUnavailable ? failure : null,
          ),
          if (!accountView)
            Padding(
              padding: const EdgeInsets.only(top: RaftSpace.x2),
              child: HumanLoginServerField(
                lookup: found ?? const HumanLoginLookup([]),
                selectedId: selectedId,
                enabled: !busy && !lookupUnavailable,
                installingId: installingId,
                onSelect: (id) {
                  setState(() {
                    selectedId = id;
                    failure = null;
                  });
                  unawaited(_loadInstallConsent());
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: RaftSpace.x2),
            child: RequestedAppScopes(
              key: const ValueKey('human-login-scopes'),
              scopes: scopes,
              collapseIdentity: true,
            ),
          ),
          ..._notices(context, choiceNow?.client, scopes),
        ],
      ],
    );
    final content = Column(
      key: separateCommit ? null : contentKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x3,
      children: [
        consent,
        if (showCommitZone)
          Padding(
            padding: const EdgeInsets.only(top: RaftSpace.x3),
            child: HumanLoginCommitZone(
              row: current,
              permissions: reviewedInstall,
              busy: installing,
              onFindAdmin: findAdmin,
              joinsBot: joinsBot,
              onBotChanged: (checked) =>
                  setState(() => installBotChoice = (selectedId, checked)),
            ),
          ),
        if (botConflict case (final id, final handle) when id == selectedId)
          RaftBanner(
            description: raftFormat(
              context,
              '@{handle} is already taken by another agent on this server, so the app didn’t join. Rename that agent, then add @{handle} from Installed apps.',
              {'handle': handle},
            ),
            size: RaftBannerRecipeSize.sm,
          ),
        if (failure != null && !notAccessible && !lookupUnavailable)
          RaftErrorBanner(
            tr(failure!),
            key: const ValueKey('human-login-error'),
            bold: true,
          ),
      ],
    );
    final wide = raftBreakpointWidth(context) >= 640;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x3,
      children: [
        RaftCard(
          padding: EdgeInsets.all(wide ? RaftSpace.x6 : RaftSpace.x4),
          child: content,
        ),
        if (lookupUnavailable || (found != null && !lookupFailed))
          const HumanLoginFaq(),
      ],
    );
    const sheetKey = ValueKey('human-login-sheet');
    return PopScope(
      canPop: !busy,
      child: RaftFormFrame.sheetOf(context)
          ? RaftFormSheet(
              key: sheetKey,
              title: tr('Login with Raft'),
              onClose: busy ? null : cancel,
              footer: actions,
              body: body,
            )
          : RaftDialog.card(
              key: sheetKey,
              title: 'Login with Raft',
              onClose: busy ? () {} : cancel,
              maxWidth: notAccessible
                  ? _unavailableDialogWidth
                  : _loginDialogWidth,
              actions: actions,
              child: _Scrolls(child: body),
            ),
    );
  }

  List<Widget> _app(
    BuildContext context,
    HumanLoginRow? current,
    HumanLoginClient? client,
    String? refusal, {
    String? lookupError,
  }) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final serviceName = (client?.name.isNotEmpty ?? false)
        ? client!.name
        : tr('this app');
    final accountMode = client?.accountMode ?? false;
    final wide = raftBreakpointWidth(context) >= 640;
    return [
      Semantics(
        header: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: RaftSpace.x1,
          children: [
            RaftCssText(
              raftFormat(
                context,
                accountMode
                    ? '{serviceName} wants to use your Raft account'
                    : '{serviceName} wants to connect to {serverName}',
                {
                  'serviceName': serviceName,
                  'serverName': current?.server.name ?? tr('this server'),
                },
              ),
              key: const ValueKey('human-login-title'),
              style: t.scale(
                wide ? RaftTypeScale.title : RaftTypeScale.headline,
              ),
            ),
            RaftCssText(
              serviceName,
              style: t.scale(wide ? RaftTypeScale.hero : RaftTypeScale.display),
            ),
          ],
        ),
      ),
      if (refusal != null)
        Padding(
          padding: const EdgeInsets.only(bottom: RaftSpace.x1),
          child: Focus(
            autofocus: accountRefusal != null,
            skipTraversal: true,
            child: Semantics(
              role: SemanticsRole.alert,
              child: RaftBanner(
                key: const ValueKey('human-login-account-refusal'),
                description: tr(refusal),
                live: false,
              ),
            ),
          ),
        ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: RaftSpace.x2,
        children: [
          RaftCssText.rich(
            TextSpan(
              children: raftRichText(
                context,
                accountMode
                    ? "Sign in to <b>{serviceName}</b> with your Raft account. The app learns who you are. What it can see on each Server is decided by that Server's owners and admins."
                    : 'Use your Raft account with <b>{serviceName}</b> on an available Raft Server.',
                {
                  'b': (inner) => TextSpan(
                    text: inner,
                    style: t.scale(
                      RaftTypeScale.callout,
                      weight: FontWeight.w700,
                      color: t.muted,
                    ),
                  ),
                },
                values: {'serviceName': serviceName},
              ),
            ),
            style: t.scale(RaftTypeScale.callout, color: t.muted),
          ),
          if (widget.api.signedInAs case final String who when who.isNotEmpty)
            RaftCssText.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${tr('Signed in as')} '),
                  TextSpan(
                    text: who,
                    style: t.scale(
                      RaftTypeScale.caption,
                      weight: FontWeight.w700,
                      color: t.ui.foregroundHint,
                    ),
                  ),
                ],
              ),
              style: t.scale(RaftTypeScale.caption, color: t.ui.foregroundHint),
            ),
        ],
      ),
      if (loginModeChanged && accountMode)
        RaftBanner(
          description: raftFormat(
            context,
            '{serviceName} now signs you in with your Raft account. Check the details below, then sign in again.',
            {'serviceName': serviceName},
          ),
          status: RaftBannerRecipeStatus.info,
          size: RaftBannerRecipeSize.sm,
        ),
      if (accountMode && !accountView)
        Text(
          raftFormat(
            context,
            'Install {serviceName} on one of your Servers to continue.',
            {'serviceName': serviceName},
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: RaftSpace.x2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: RaftSpace.x1_5,
          children: [
            RaftCssText(
              tr('App details'),
              style: t.scale(
                RaftTypeScale.footnote,
                weight: FontWeight.w600,
                color: t.muted,
              ),
            ),
            if (client != null)
              _AppCard(client: client, openExternal: openExternal)
            else if (lookupError != null)
              RaftCard(
                key: const ValueKey('human-login-error'),
                padding: const EdgeInsets.symmetric(
                  horizontal: RaftSpace.x3,
                  vertical: RaftSpace.x2 + RaftSpace.half,
                ),
                child: RaftCssText(
                  tr(lookupError),
                  style: t.scale(RaftTypeScale.callout, color: t.muted),
                ),
              ),
            RaftCssText(
              tr('The app you are continuing to with Login with Raft.'),
              style: t.scale(RaftTypeScale.caption, color: t.ui.foregroundHint),
            ),
          ],
        ),
      ),
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
    if (RaftScaled.grows(context)) {
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

class _LoginLookupLoading extends StatefulWidget {
  const _LoginLookupLoading();

  @override
  State<_LoginLookupLoading> createState() => _LoginLookupLoadingState();
}

class _LoginLookupLoadingState extends State<_LoginLookupLoading> {
  final delay = RaftIdleTimer(yieldToAnimation: false);
  bool shown = false;

  @override
  void initState() {
    super.initState();
    delay.start(const Duration(seconds: 1), () => setState(() => shown = true));
  }

  @override
  void dispose() {
    delay.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    final label = raftText(context, 'Loading…');
    return Semantics(
      label: label,
      liveRegion: true,
      excludeSemantics: true,
      child: Opacity(
        key: const ValueKey('human-login-lookup-skeleton'),
        opacity: shown ? 1 : 0,
        child: TickerMode(
          enabled: shown,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                spacing: RaftSpace.x2,
                children: [
                  const RaftSpinner(recipeSize: RaftSpinnerRecipeSize.md),
                  Text(
                    label,
                    style: tokens.scale(
                      RaftTypeScale.callout,
                      color: tokens.ui.foregroundMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RaftSpace.x5),
              for (final (fraction, height) in [
                (.75, RaftSpace.x6),
                (.5, RaftSpace.x5 * 2),
                (1.0, null),
                (2 / 3, null),
              ]) ...[
                FractionallySizedBox(
                  widthFactor: fraction,
                  alignment: Alignment.centerLeft,
                  child: RaftSkeleton(
                    variant: RaftSkeletonVariant.line,
                    height: height,
                    fromRecipe: true,
                  ),
                ),
                if (fraction != 2 / 3) const SizedBox(height: RaftSpace.x3),
              ],
              const SizedBox(height: RaftSpace.x5),
              const RaftSkeleton(height: RaftSpace.x4 * 4, fromRecipe: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  const _AppCard({required this.client, required this.openExternal});
  final HumanLoginClient client;
  final Future<bool> Function(Uri) openExternal;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final url = Uri.tryParse(client.homepageUrl ?? '');
    final homepage =
        url != null &&
            url.host.isNotEmpty &&
            (url.isScheme('https') || url.isScheme('http'))
        ? url
        : null;
    String tr(String s) => raftText(context, s);
    return RaftCard(
      key: homepage == null ? null : const ValueKey('human-login-app-homepage'),
      onTap: homepage == null ? null : () => unawaited(openExternal(homepage)),
      linkUrl: homepage,
      semanticLabel: homepage == null ? null : '${tr('Open')} ${client.name}',
      padding: const EdgeInsets.symmetric(
        horizontal: RaftSpace.x3,
        vertical: RaftSpace.x2 + RaftSpace.half,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: RaftSpace.x3,
        children: [
          RaftAppLogo(
            initials: client.initials,
            logoUrl: client.logoUrl,
            size: RaftAppLogoSize.sm,
          ),
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
                      style: t.scale(
                        RaftTypeScale.subhead,
                        weight: FontWeight.w700,
                      ),
                    ),
                    RaftBadge(
                      label: tr(
                        client.suspended
                            ? 'Suspended'
                            : client.marketplace || client.installRequired
                            ? 'Marketplace'
                            : 'Ready',
                      ),
                      variant: client.suspended
                          ? RaftBadgeRecipeVariant.muted
                          : RaftBadgeRecipeVariant.success,
                      appearance: RaftBadgeRecipeAppearance.soft,
                    ),
                  ],
                ),
                if (client.description != null)
                  Text(
                    client.description!,
                    style: t.scale(RaftTypeScale.footnote, color: t.muted),
                  ),
              ],
            ),
          ),
          if (homepage != null)
            Padding(
              padding: const EdgeInsets.only(top: RaftSpace.half),
              child: RaftIcon(
                RaftGlyph.arrowUpRight,
                size: RaftSpace.x4,
                color: t.ui.foregroundHint,
              ),
            ),
        ],
      ),
    );
  }
}

/// Web `RequestedScopeConsent` / `oauthScopePresentation`: what the request
/// will grant, in the same words.
class RequestedAppScopes extends StatelessWidget {
  const RequestedAppScopes({
    super.key,
    required this.scopes,
    this.collapseIdentity = false,
  });
  final List<String> scopes;
  final bool collapseIdentity;

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
        if (collapseIdentity)
          RaftCssText(
            tr('Requested access'),
            style: t.scale(
              RaftTypeScale.footnote,
              weight: FontWeight.w700,
              color: t.ink,
            ),
          )
        else
          RaftDialogSectionEyebrow('Requested access', color: t.ink),
        if (collapseIdentity)
          RaftCssText(
            tr(intro),
            style: t.scale(RaftTypeScale.callout, color: t.muted),
          )
        else
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
                    collapsible:
                        collapseIdentity && tier == OAuthScopeTier.identity,
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

class _TierGroup extends StatefulWidget {
  const _TierGroup({
    required this.tier,
    required this.scopes,
    this.collapsible = false,
  });
  final OAuthScopeTier tier;
  final List<String> scopes;

  final bool collapsible;
  @override
  State<_TierGroup> createState() => _TierGroupState();
}

class _TierGroupState extends State<_TierGroup> {
  bool expanded = false;
  OAuthScopeTier get tier => widget.tier;
  List<String> get scopes => widget.scopes;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final summary = TextSpan(
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
    );
    final rows = <Widget>[
      for (final scope in scopes) ...[
        const RaftSeparator(),
        Padding(
          key: ValueKey('human-login-scope-$scope'),
          padding: const EdgeInsets.symmetric(vertical: RaftSpace.x2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: RaftSpace.x1,
            children: [
              Text(
                scope,
                style: t.scale(
                  RaftTypeScale.monoMeta,
                  mono: true,
                  weight: FontWeight.w700,
                  color: t.ui.foreground,
                ),
              ),
              Text(
                tr(oauthScopeCopy(scope)),
                style: t.scale(
                  RaftTypeScale.footnote,
                  color: t.ui.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    ];
    if (!widget.collapsible) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(summary),
          const SizedBox(height: RaftSpace.x2),
          ...rows,
        ],
      );
    }
    return RaftDisclosureCard(
      child: RaftCollapsibleSectionHeader(
        label:
            tr(oauthTierLabel(tier)) +
            tr(' — Who you are and your basic profile · no content access.'),
        labelSpan: summary,
        expanded: expanded,
        leadingDisclosure: true,
        disclosureKey: const ValueKey('human-login-identity-disclosure'),
        onExpandedChanged: (value) => setState(() => expanded = value),
        gap: RaftSpace.x2,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ],
      ),
    );
  }
}
