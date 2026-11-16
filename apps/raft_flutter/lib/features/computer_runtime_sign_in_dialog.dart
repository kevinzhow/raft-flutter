// Web v1.24 features/computer/RuntimeSignInDialog.tsx: sign a Computer's
// runtime (Claude Code, Codex, Kimi, Qoder, Antigravity, Grok, CodeBuddy) in
// from the app. The login runs on the Computer; this dialog shows its link
// or device code and relays the pasted code or page address.
//
// The pasted code is never logged or traced, and is cleared once it is sent
// or the login ends. Closing the dialog while a login runs cancels it.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/runtime_auth.dart';
import '../data/workspace_controller.dart';
import 'agent_runtime_labels.dart';
import 'icu_message.dart';
import 'computer_runtime_sign_in_parts.dart';

/// Opens the sign-in dialog for [runtime] (a runtime-auth id) on the
/// Computer [machineId]; [runtimeId] is the Raft runtime id it is shown for.
Future<void> showComputerRuntimeSignInDialog(
  BuildContext context, {
  required WorkspaceController controller,
  required RuntimeAuthClient client,
  required String serverId,
  required String machineId,
  required String runtimeId,
  required String runtime,
}) => showSignInStep(
  context,
  label: raftText(context, 'Sign in'),
  builder: (_) => ComputerRuntimeSignInView(
    controller: controller,
    client: client,
    serverId: serverId,
    machineId: machineId,
    runtimeId: runtimeId,
    runtime: runtime,
  ),
);

const _regionLabels = <String, String>{
  'mainland-cn': 'Kimi Code (kimi.com/code)',
  'global': 'Kimi Code (kimi.ai/code)',
};

/// `invalid`: the server refused the value; `sendFailed`: it never got there
/// (the value is kept to resend).
enum _CodeState { idle, submitting, sent, invalid, sendFailed }

/// The sign-in window's content and its login. [provider] is the provider to
/// sign in for a runtime that signs in per provider (Pi, OpenCode): the
/// dialog is named after it, and its paste step says what it takes.
class ComputerRuntimeSignInView extends StatefulWidget {
  const ComputerRuntimeSignInView({
    super.key,
    required this.controller,
    required this.client,
    required this.serverId,
    required this.machineId,
    required this.runtimeId,
    required this.runtime,
    this.provider,
  });
  final WorkspaceController controller;
  final RuntimeAuthClient client;
  final String serverId, machineId, runtimeId, runtime;
  final SignInProvider? provider;

  @override
  State<ComputerRuntimeSignInView> createState() => _SignInState();
}

class _SignInState extends State<ComputerRuntimeSignInView> {
  final code = TextEditingController();
  StreamSubscription<RuntimeAuthLoginPush>? pushes;

  /// The login this dialog shows: its id, and whether it still runs.
  ({String id, bool running})? shown;

  /// Pushes that arrive before the start request answers; non-null only
  /// while it runs.
  List<RuntimeAuthLoginPush>? early;
  static const earlyLimit = 16;
  int attempt = 0;
  bool closed = false;

  // What the person sees.
  /// True once the Computer sent its first event; until then the dialog says
  /// it is starting.
  bool started = false;
  String? authUrl;
  ({String userCode, String uri, int? expires})? deviceCode;
  String? info;
  ({String? message, bool retry})? codePrompt;
  _CodeState codeState = _CodeState.idle;
  bool done = false;
  RuntimeAuthAccount? account;
  SignInFailure? failure;

  /// Kimi asks for a region first, with nothing chosen: no default, no
  /// guess. [region] is the choice; [startedRegion] the one the login runs
  /// with, which Try again keeps.
  String? region, startedRegion;

  List<String> get regionChoices =>
      runtimeAuthLoginRegionChoices[widget.runtime] ?? const [];
  bool get asksRegion => regionChoices.isNotEmpty;
  bool get choosingRegion => asksRegion && startedRegion == null;

  @override
  void initState() {
    super.initState();
    pushes = widget.client.loginPushes.listen(route);
    // Started once on open and again from Try again, never by a rebuild.
    if (!asksRegion) begin();
  }

  @override
  void dispose() {
    unawaited(pushes?.cancel());
    // Gone without the close button (the page went away): end the login too.
    cancelRunning();
    code.dispose();
    super.dispose();
  }

  void cancelLogin(String loginId) {
    unawaited(
      widget.client
          .cancelLogin(
            widget.serverId,
            widget.machineId,
            widget.runtime,
            loginId,
          )
          .then<void>((_) {}, onError: (Object _) {}),
    );
  }

  /// Stops the shown login, if it still runs; returns its id when it did.
  String? releaseLogin() {
    final login = shown;
    if (login == null || !login.running) return null;
    shown = (id: login.id, running: false);
    return login.id;
  }

  void cancelRunning() {
    final running = releaseLogin();
    if (running != null) cancelLogin(running);
  }

  void begin([String? loginRegion]) {
    final mine = ++attempt;
    shown = null;
    early = [];
    widget.client
        .startLogin(
          widget.serverId,
          widget.machineId,
          widget.runtime,
          region: loginRegion,
          providerId: widget.provider?.id,
          oauthMethod: widget.provider?.oauthMethod,
        )
        .then<void>(
          (loginId) {
            if (attempt != mine) return;
            final pending = early ?? const <RuntimeAuthLoginPush>[];
            early = null;
            if (!mounted || closed) {
              // Closed while starting: the login began anyway, so end it.
              cancelLogin(loginId);
              return;
            }
            shown = (id: loginId, running: true);
            for (final push in pending) {
              if (push.loginId == loginId) apply(push);
            }
          },
          onError: (Object error) {
            if (attempt != mine) return;
            early = null;
            if (!mounted) return;
            final (:status, :code) = runtimeAuthRequestError(error);
            setState(() {
              this.code.clear();
              failure = signInStartFailure(status, code);
            });
          },
        );
  }

  /// Only this login's pushes are shown; the ones that arrive before its id
  /// is known wait and are replayed (or dropped) once it is.
  void route(RuntimeAuthLoginPush push) {
    if (push.serverId != widget.serverId ||
        push.machineId != widget.machineId ||
        push.runtime != widget.runtime) {
      return;
    }
    final login = shown;
    if (login == null) {
      final waiting = early;
      if (waiting != null && waiting.length < earlyLimit) waiting.add(push);
      return;
    }
    if (push.loginId == login.id) apply(push);
  }

  void apply(RuntimeAuthLoginPush push) {
    if (!mounted) return;
    final payload = push.payload;
    if (!push.isResult) {
      if (done || failure != null) return;
      setState(() {
        started = true;
        switch (push.kind) {
          case 'auth_url':
            authUrl = '${payload['url']}';
          case 'device_code':
            final expires = payload['expiresInSeconds'];
            deviceCode = (
              userCode: '${payload['userCode']}',
              uri: '${payload['verificationUri']}',
              expires: expires is num ? expires.toInt() : null,
            );
          case 'info':
            info = '${payload['message']}';
          default:
            // A new prompt (first, or after a code the runtime did not
            // accept) asks again.
            final message = payload['message'];
            codePrompt = (
              message: message is String ? message : null,
              retry: payload['retry'] == true,
            );
            codeState = _CodeState.idle;
        }
      });
      return;
    }
    releaseLogin();
    final provider = widget.provider;
    if (payload['kind'] == 'failed' &&
        payload['reason'] == 'loopback_required' &&
        provider?.oauthMethod != null) {
      rememberLoopbackRequired(
        widget.machineId,
        widget.runtime,
        provider!.id,
        provider.oauthMethod!,
      );
    }
    if (!done && failure == null) {
      setState(() {
        started = true;
        code.clear();
        if (push.kind == 'logged_in') {
          done = true;
          account = RuntimeAuthAccount.fromJson(payload['account']);
        } else {
          failure = signInResultFailure(payload);
        }
      });
    }
    widget.client.invalidate(widget.serverId, widget.machineId);
  }

  void close() {
    if (closed) return;
    closed = true;
    cancelRunning();
    Navigator.of(context).pop();
  }

  void retry() {
    setState(() {
      started = false;
      authUrl = deviceCode = info = codePrompt = null;
      code.clear();
      codeState = _CodeState.idle;
      done = false;
      account = null;
      failure = null;
    });
    begin(startedRegion);
  }

  void continueWithRegion() {
    final chosen = region;
    if (chosen == null) return;
    setState(() => startedRegion = chosen);
    begin(chosen);
  }

  void submitCode() {
    final trimmed = code.text.trim();
    final login = shown;
    if (login == null || !login.running || trimmed.isEmpty) return;
    if (codeState == _CodeState.submitting) return;
    setState(() => codeState = _CodeState.submitting);
    widget.client
        .submitCode(
          widget.serverId,
          widget.machineId,
          widget.runtime,
          login.id,
          trimmed,
        )
        .then<void>(
          (_) {
            if (!mounted) return;
            // Sent: the code has left this page, so it is not kept.
            setState(() {
              codeState = _CodeState.sent;
              code.clear();
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            // Only the status and the server's code are read: never the
            // request or the value.
            final (:status, code: errorCode) = runtimeAuthRequestError(error);
            setState(() {
              if (errorCode == 'invalid_code' || status == 400) {
                codeState = _CodeState.invalid;
              } else if (status == 404) {
                releaseLogin();
                code.clear();
                failure = const SignInFailure(
                  'This sign-in has ended. Start it again.',
                  retryable: true,
                );
              } else if (errorCode == 'computer_offline') {
                // An offline Computer has already ended the login on its side.
                releaseLogin();
                code.clear();
                failure = signInStartFailure(status, errorCode);
              } else {
                codeState = _CodeState.sendFailed;
              }
            });
          },
        );
  }

  String runtimeName() =>
      widget.provider?.label ?? runtimeDisplayNameOf(widget.runtimeId);

  @override
  Widget build(BuildContext context) {
    final name = runtimeName();
    final computer =
        computerNameOf(widget.controller, widget.machineId) ??
        raftText(context, 'this Computer');
    final ended = done || failure != null;
    return SignInStepDialog(
      title: raftFormat(context, 'Sign in to {runtime}', {'runtime': name}),
      onClosed: () {
        closed = true;
        cancelRunning();
      },
      actions: _actions(context, ended),
      children: _body(context, name, computer),
    );
  }

  List<Widget> _body(BuildContext context, String name, String computer) {
    if (choosingRegion) {
      final prompt = raftFormat(context, 'Choose your {runtime} account.', {
        'runtime': name,
      });
      return [
        Column(
          key: const ValueKey('runtime-sign-in-region'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: RaftSpace.x3,
          children: [
            signInHint(context, prompt),
            RaftRadioGroup<String>(
              value: region,
              semanticLabel: prompt,
              onChanged: (value) => setState(() => region = value),
              spacing: 0,
              children: [
                for (final choice in regionChoices)
                  RaftRadioGroupItem<String>(
                    key: ValueKey('runtime-sign-in-region-$choice'),
                    value: choice,
                    minHeight: 44,
                    child: Text(
                      raftText(context, _regionLabels[choice] ?? choice),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ];
    }
    if (done) {
      final accountLine = runtimeAuthAccountText(account);
      return [
        RaftBanner(
          key: const ValueKey('runtime-sign-in-success'),
          status: RaftBannerRecipeStatus.success,
          glyph: RaftGlyph.circleCheck,
          title: raftFormat(context, '{runtime} is signed in on {computer}', {
            'runtime': name,
            'computer': computer,
          }),
          description: accountLine ?? '',
        ),
      ];
    }
    final failed = failure;
    if (failed != null) {
      final message = signInFailureMessageFor(
        widget.runtime,
        widget.provider != null,
        failed.message,
      );
      return [
        RaftBanner(
          key: const ValueKey('runtime-sign-in-failed'),
          status: RaftBannerRecipeStatus.warning,
          size: RaftBannerRecipeSize.sm,
          glyph: RaftGlyph.alertTriangle,
          description: raftFormat(context, message, {
            'runtime': name,
            'computer': computer,
          }),
        ),
      ];
    }
    if (!started) {
      return [
        signInStatusLine(
          context,
          raftFormat(context, 'Starting sign-in on {computer}…', {
            'computer': computer,
          }),
          key: const ValueKey('runtime-sign-in-starting'),
        ),
      ];
    }
    return [
      if (authUrl != null) _authLink(context, name),
      if (deviceCode != null) _deviceCode(context, deviceCode!),
      if (info != null) signInHint(context, info!, caption: true),
      if (codePrompt != null) _codeForm(context, codePrompt!),
    ];
  }

  /// One pink button per screen: opening the sign-in page leads until a code
  /// is pasted, then sending it does.
  bool get codeEntered => codePrompt != null && code.text.trim().isNotEmpty;

  Widget _authLink(BuildContext context, String name) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: RaftSpace.x3,
    children: [
      // Our own words for the prompt's kind, never the runtime's: the
      // `instructions` are an English line from the runtime.
      signInHint(
        context,
        raftFormat(
          context,
          'Open the sign-in page and finish signing in to {runtime} there.',
          {'runtime': name},
        ),
        key: const ValueKey('runtime-sign-in-hint'),
      ),
      // Typing the code hands the pink button to Submit: this rebuilds on it.
      ListenableBuilder(
        listenable: code,
        builder: (context, _) => RaftButton(
          key: const ValueKey('runtime-sign-in-open-page'),
          label: raftText(context, 'Open sign-in page'),
          // LeavingRaftMark: a link that leaves Raft says so after its label.
          semanticLabel:
              '${raftText(context, 'Open sign-in page')} ${raftText(context, '(opens in a new tab)')}',
          trailingGlyph: RaftGlyph.arrowUpRight,
          tone: codeEntered
              ? RaftButtonRecipeVariant.default_
              : RaftButtonRecipeVariant.accent,
          size: RaftButtonRecipeSize.lg,
          onPressed: () => unawaited(openSignInPage(authUrl!)),
        ),
      ),
    ],
  );

  Widget _deviceCode(
    BuildContext context,
    ({String userCode, String uri, int? expires}) device,
  ) {
    final t = RaftTokens.of(context);
    final expires = device.expires;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x2,
      children: [
        signInHint(
          context,
          raftText(context, 'Open this page and enter the code below:'),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Semantics(
            link: true,
            excludeSemantics: true,
            label: '${device.uri} ${raftText(context, '(opens in a new tab)')}',
            child: RaftTextLink(
              key: const ValueKey('runtime-sign-in-device-link'),
              label: device.uri,
              // `variant="strong" text-subhead`, the external mark after it.
              variant: RaftTextLinkVariant.strong,
              textStyle: t.scale(
                RaftTypeScale.subhead,
                weight: FontWeight.w600,
                color: t.ui.foreground,
              ),
              trailingGlyph: RaftGlyph.arrowUpRight,
              onPressed: () => unawaited(openSignInPage(device.uri)),
            ),
          ),
        ),
        RaftCopyableCode(
          device.userCode,
          copyLabel: raftText(context, 'Copy code'),
          codeKey: const ValueKey('runtime-sign-in-device-code'),
          // `text-title tracking-widest`: the code is what the person types.
          codeStyle: TextStyle(
            fontSize: RaftTypeScale.title.fontSize,
            height: RaftTypeScale.title.height,
            fontWeight: FontWeight.w700,
            letterSpacing: RaftTypeScale.title.fontSize * .1,
          ),
        ),
        if (expires != null)
          Text(
            icuText(
              context,
              'The code expires in {minutes, plural, one {# minute} other {# minutes}}.',
              {'minutes': (expires / 60).round().clamp(1, 1 << 30)},
            ),
            style: RaftTypography.body(
              t,
              size: 12,
              line: 12 * 1.5,
              color: t.colors['foreground-hint'] ?? t.muted,
            ),
          ),
      ],
    );
  }

  Widget _codeForm(
    BuildContext context,
    ({String? message, bool retry}) prompt,
  ) {
    final provider = widget.provider;
    final pastesAddress = provider?.paste == SignInPaste.address;
    final rejected =
        codeState == _CodeState.invalid ||
        (codeState == _CodeState.idle && prompt.retry);
    final busy =
        codeState == _CodeState.submitting || codeState == _CodeState.sent;
    // Pi's pasted step is ours to word (its prompt's own message is Pi's
    // English), and so is OpenCode's; the others keep theirs.
    final hint = provider != null
        ? raftText(
            context,
            widget.runtime == 'pi'
                ? (pastesAddress
                      ? "After signing in, your browser lands on a page that won't load. Paste the full address from the address bar here."
                      : 'After signing in, the page shows a code like abc…#xyz. Paste all of it.')
                : 'Once you finish signing in, the page shows a code. Paste it here.',
          )
        : prompt.message ??
              raftText(
                context,
                widget.runtime == 'antigravity'
                    ? 'After signing in with Google, paste the code shown, or the full address your browser landed on.'
                    : 'Once you finish signing in, the page shows a code. Paste it here.',
              );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x2,
      children: [
        RaftProductFormField(
          label: raftText(
            context,
            pastesAddress
                ? 'Paste the address of the page you land on'
                : 'Paste the code shown after signing in',
          ),
          hint: rejected ? null : hint,
          error: rejected
              ? raftText(
                  context,
                  codeState == _CodeState.invalid
                      ? 'Paste the whole code from the sign-in page.'
                      : 'That code was not accepted, paste it again',
                )
              : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: RaftSpace.x2,
            children: [
              Expanded(
                child: ListenableBuilder(
                  listenable: code,
                  builder: (context, _) => RaftDialogTextInput(
                    fieldKey: const ValueKey('runtime-sign-in-code'),
                    controller: code,
                    enabled: !busy,
                    mono: true,
                    onSubmitted: (_) => submitCode(),
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: code,
                builder: (context, _) => RaftButton(
                  key: const ValueKey('runtime-sign-in-submit-code'),
                  label: raftText(context, 'Submit'),
                  tone: code.text.trim().isNotEmpty
                      ? RaftButtonRecipeVariant.accent
                      : RaftButtonRecipeVariant.default_,
                  size: RaftButtonRecipeSize.lg,
                  busy: codeState == _CodeState.submitting,
                  loadingLabel: raftText(context, 'Sending the code'),
                  onPressed:
                      codeState == _CodeState.sent || code.text.trim().isEmpty
                      ? null
                      : submitCode,
                ),
              ),
            ],
          ),
        ),
        if (codeState == _CodeState.sendFailed)
          RaftBanner(
            key: const ValueKey('runtime-sign-in-code-send-failed'),
            status: RaftBannerRecipeStatus.warning,
            size: RaftBannerRecipeSize.sm,
            glyph: RaftGlyph.alertTriangle,
            description: raftText(
              context,
              "Couldn't send the code. Try again.",
            ),
          ),
        if (codeState == _CodeState.sent)
          signInStatusLine(
            context,
            raftText(context, 'Checking the code…'),
            key: const ValueKey('runtime-sign-in-checking-code'),
          ),
      ],
    );
  }

  List<Widget> _actions(BuildContext context, bool ended) {
    if (choosingRegion) {
      return [
        signInGhost(
          context,
          key: const ValueKey('runtime-sign-in-cancel'),
          label: raftText(context, 'Cancel'),
          onPressed: close,
        ),
        signInCommit(
          context,
          key: const ValueKey('runtime-sign-in-continue'),
          label: raftText(context, 'Continue'),
          onPressed: region == null ? null : continueWithRegion,
        ),
      ];
    }
    if (done) {
      return [
        signInCommit(
          context,
          key: const ValueKey('runtime-sign-in-done'),
          label: raftText(context, 'Done'),
          onPressed: close,
        ),
      ];
    }
    return [
      signInGhost(
        context,
        key: const ValueKey('runtime-sign-in-cancel'),
        label: raftText(context, ended ? 'Close' : 'Cancel'),
        onPressed: close,
      ),
      if (failure?.retryable == true)
        signInCommit(
          context,
          key: const ValueKey('runtime-sign-in-retry'),
          label: raftText(context, 'Try again'),
          onPressed: retry,
        ),
    ];
  }
}
