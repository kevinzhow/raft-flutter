// Web v1.24 components/machine/RuntimeAccountUsageChip.tsx
// (useRuntimeUsageCard, RuntimeUsageHoverCard, RuntimeAccountUsageChip,
// GateChip): the runtime chip on Computer detail "Detected runtimes" and the
// agent Runtime Config row. A runtime with a usage provider reads the
// Computer's private usage snapshot; a runtime the person can sign in from
// here reads the Computer's sign-in view. The chip shows the state (a health
// Status, or the warning words "not signed in" / readiness) and opens the
// card on hover / focus / click; the card is where a person signs in, signs
// out, adds a provider, connects a provider key or uses a Codex limit reset.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/runtime_account_usage.dart';
import '../data/runtime_auth.dart';
import '../data/workspace_controller.dart';
import 'computer_readiness_copy.dart';
import 'computer_runtime_limit_reset_dialog.dart';
import 'computer_runtime_pi_sign_in_dialog.dart';
import 'computer_runtime_provider_connect_dialog.dart';
import 'computer_runtime_sign_in_dialog.dart';
import 'computer_runtime_sign_out_dialog.dart';
import 'computers_rack/computers_rack_model.dart' show rackRuntimeDisplayName;
import 'icu_message.dart';
import 'resource_cards.dart' show resourceRelativeTime;

/// The workspace's usage client, bound to the server-level identity (the
/// panel cache empties on account / server / role changes).
RuntimeAccountUsageClient runtimeUsageClient(WorkspaceController w) =>
    w.agentTabCache.putIfAbsent(
      'runtime-account-usage',
      () => RuntimeAccountUsageClient(
        get: (path) => w.query(path),
        post: (path, body) => w.command('POST', path, data: body),
      ),
    ) as RuntimeAccountUsageClient;

/// machineRuntimeUsageVisibility.ts canViewMachineRuntimeAccountUsage: the
/// attaching human, the creator, or `editMachines`.
bool canViewRuntimeUsage(WorkspaceController w, Map<String, dynamic>? m) {
  if (m == null) return false;
  final me = w.client.user?.id;
  final creator = m['creator'];
  return m['computerAttachedByCurrentUser'] == true ||
      (me != null && creator is Map && creator['id'] == me) ||
      w.can('editMachines');
}

/// runtimeInstallCommands.ts: the command that installs a runtime's own CLI
/// on macOS or Linux, by Raft runtime id.
const runtimeInstallCommands = <String, String>{
  'claude': 'npm install -g @anthropic-ai/claude-code',
  'codex': 'npm install -g @openai/codex',
  'kimi-sdk': 'curl -fsSL https://code.kimi.com/kimi-code/install.sh | bash',
  'codebuddy': 'npm install -g @tencent-ai/codebuddy-code',
};

/// Claude's OAuth apps' window (third-party apps' use) is never listed
/// (CLAUDE_OAUTH_APPS_WINDOW_LABEL).
const claudeOAuthAppsWindowLabel = 'Current week (OAuth apps)';

/// What the chip knows, for the trigger that draws it.
class RuntimeChipState {
  const RuntimeChipState({
    required this.status,
    required this.signedOut,
    required this.attention,
    required this.suffix,
  });

  /// The health Status dot; null when there is no snapshot, or the chip is a
  /// warning (it carries no dot).
  final Widget? status;

  /// Signed out on the Computer.
  final bool signedOut;

  /// Signed out, stale, or an account or window not ok.
  final bool attention;

  /// " (not signed in)" or the readiness suffix " (title)"; empty when none.
  /// The chip is a warning Badge whenever it is not empty.
  final String suffix;
  bool get warn => suffix.isNotEmpty;
}

/// RuntimeAccountUsageGateChip: the runtime chip when [enabled] and the
/// runtime has a usage provider or a sign-in from here, otherwise [chip] as
/// is. [chip] draws the plain chip with the health Status; a chip that is a
/// warning (signed out, readiness) is drawn as the warning Badge unless
/// [chipBuilder] draws it.
Widget runtimeUsageGateChip({
  required WorkspaceController controller,
  required bool enabled,
  required String runtimeId,
  required String machineId,
  required String label,
  String? runtimeVersion,
  required Widget Function(Widget? status) chip,
  Widget Function(RuntimeChipState state)? chipBuilder,
  RuntimeAccountUsageClient? client,
  RuntimeAuthClient? authClient,
}) {
  final serverId = controller.server?.id;
  if (!enabled ||
      serverId == null ||
      machineId.isEmpty ||
      (runtimeUsageProvider(runtimeId) == null &&
          runtimeAuthRuntimeFor(runtimeId) == null)) {
    return chip(null);
  }
  return RuntimeUsageChip(
    key: ValueKey('runtime-usage-$machineId-$runtimeId'),
    controller: controller,
    serverId: serverId,
    machineId: machineId,
    runtimeId: runtimeId,
    runtimeVersion: runtimeVersion,
    label: label,
    chip: chip,
    chipBuilder: chipBuilder,
    client: client,
    authClient: authClient,
  );
}

class RuntimeUsageChip extends StatefulWidget {
  const RuntimeUsageChip({
    super.key,
    required this.controller,
    required this.serverId,
    required this.machineId,
    required this.runtimeId,
    required this.label,
    required this.chip,
    this.chipBuilder,
    this.runtimeVersion,
    this.client,
    this.authClient,
  });
  final WorkspaceController controller;
  final String serverId, machineId, runtimeId, label;
  final String? runtimeVersion;
  final Widget Function(Widget? status) chip;

  /// Draws the chip from its whole state (a rack cell that wants the
  /// signed-out state); [chip] is used when null.
  final Widget Function(RuntimeChipState state)? chipBuilder;
  final RuntimeAccountUsageClient? client;
  final RuntimeAuthClient? authClient;
  @override
  State<RuntimeUsageChip> createState() => _RuntimeUsageChipState();
}

class _RuntimeUsageChipState extends State<RuntimeUsageChip> {
  static const followUpDelay = Duration(milliseconds: 1200);
  static const followUpAttempts = 8;

  late RuntimeAccountUsageClient client;
  late RuntimeAuthClient authClient;
  final model = _UsageModel();
  RuntimeUsageRead? result;
  // ignore: raft_lints/avoid_imperative_notice_state -- loadError is reset when each read starts and set only for the current subject ticket.
  bool loading = false, loadError = false;

  /// idle | requesting | requested | unconfirmed | timeout | cooldown |
  /// computer_offline.
  String refreshState = 'idle';
  int subject = 0, poll = 0;
  Timer? ticker, reread;

  /// The card is on screen: only then does the refresh countdown tick.
  bool visible = false;

  /// The Computer's runtime sign-in state, read once (cached per Computer)
  /// and again whenever the Computer reports a new one.
  RuntimeAuthView? authView;
  void Function()? unwatchAuth;
  int authSeq = 0;

  /// What the last limit reset did, said once in the action row; the subject
  /// is the one it was made for.
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared by the next manual refresh and by a change of subject (didUpdateWidget); shown once in the action row.
  String? limitResetNote;
  ({String key, String? account, int resets})? limitResetTarget;

  /// The usage provider read now; null while a server-gated runtime
  /// (Antigravity) is not yet listed for this Computer.
  String? provider;

  String? get authRuntime => runtimeAuthRuntimeFor(widget.runtimeId);
  bool get serverGated =>
      authRuntime != null &&
      runtimeAuthServerGatedRuntimes.contains(authRuntime);
  bool get perProvider =>
      authRuntime != null && runtimeAuthSignsInPerProvider(authRuntime!);

  /// A runtime with neither usage nor a sign-in offered here has no card.
  bool get offered =>
      authRuntime != null &&
      (!serverGated || (authView != null && authView!.supports(authRuntime!)));

  String? get computedProvider =>
      serverGated && !offered ? null : runtimeUsageProvider(widget.runtimeId);

  RuntimeAuthStatus? get authStatus => authRuntime == null || authView == null
      ? null
      : authView!.statusOf(authRuntime!);

  /// Signed out on the Computer; a provider-key runtime's presence-only "not
  /// configured" does not count, nor Pi with no stored sign-in (a key in the
  /// environment or its models.json may still serve it).
  bool get signedOut =>
      authStatus?.loggedOut == true &&
      authRuntime != null &&
      !runtimeAuthHasProviderKey(authRuntime!) &&
      !perProvider;

  String get limitResetSubject => RuntimeLimitResetAttemptKeys.subject(
    widget.serverId,
    widget.machineId,
    provider ?? '',
  );

  Map<String, dynamic>? get machine =>
      widget.controller.services.entityDirectory.computer(widget.machineId);

  /// useMachineRuntimeReadiness: this runtime's readiness on the Computer, as
  /// the machine list sent it (trimmed for the viewer).
  Map? get readiness {
    final all = machine?['readiness'];
    final runtimes = all is Map ? all['runtimes'] : null;
    final mine = runtimes is Map ? runtimes[widget.runtimeId] : null;
    return mine is Map ? mine : null;
  }

  /// readinessHolds.
  bool get readinessHeld {
    final state = readiness?['state'];
    return state == 'blocked' || state == 'waiting';
  }

  @override
  void initState() {
    super.initState();
    widget.controller.services.entityDirectory.addListener(machineChanged);
    startAuth();
    start();
  }

  @override
  void didUpdateWidget(RuntimeUsageChip old) {
    super.didUpdateWidget(old);
    if (old.serverId != widget.serverId ||
        old.machineId != widget.machineId ||
        old.runtimeId != widget.runtimeId ||
        old.client != widget.client ||
        old.authClient != widget.authClient) {
      reread?.cancel();
      result = null;
      refreshState = 'idle';
      limitResetNote = null;
      limitResetTarget = null;
      startAuth();
      start();
    }
  }

  @override
  void dispose() {
    widget.controller.services.entityDirectory.removeListener(machineChanged);
    subject++;
    poll++;
    authSeq++;
    unwatchAuth?.call();
    ticker?.cancel();
    reread?.cancel();
    model.dispose();
    super.dispose();
  }

  void machineChanged() {
    if (mounted) changed();
  }

  // --- the sign-in view (useRuntimeAuthView) ---

  void startAuth() {
    unwatchAuth?.call();
    unwatchAuth = null;
    authClient = widget.authClient ?? runtimeAuthClientOf(widget.controller);
    authView = null;
    if (authRuntime == null) return;
    authView = authClient.cached(widget.serverId, widget.machineId);
    unwatchAuth = authClient.watch(widget.machineId, rereadAuth);
    rereadAuth();
  }

  /// Only the newest read may land: an older answer that arrives after a
  /// newer read started (a status update mid-read) is stale.
  void rereadAuth() {
    if (authRuntime == null) return;
    final seq = ++authSeq;
    final server = widget.serverId, machine = widget.machineId;
    authClient.read(server, machine).then(
      (view) {
        if (!mounted || seq != authSeq) return;
        authView = view;
        changed();
        syncProvider();
      },
      // Not allowed to see it, or the read failed: the card stays as usage
      // alone.
      onError: (Object _) {},
    );
  }

  /// A server-gated runtime's usage starts once the server lists it.
  void syncProvider() {
    if (computedProvider != provider) start();
  }

  // --- the usage snapshot ---

  void start() {
    client = widget.client ?? runtimeUsageClient(widget.controller);
    provider = computedProvider;
    final generation = ++subject;
    final p = provider;
    result = p == null
        ? null
        : client.cached(widget.serverId, widget.machineId, p);
    if (p == null) {
      loading = loadError = false;
      changed();
      return;
    }
    // ignore: raft_lints/avoid_unreviewed_idle_work -- One-shot deferral out of a build or notification; the callback does not schedule another microtask itself.
    scheduleMicrotask(() {
      if (!mounted || generation != subject) return;
      read(generation).then((next) {
        if (generation != subject) return;
        // Only a stale or missing snapshot is worth a background refresh;
        // `unsupported` is "no usage" (no attention, nothing to refresh).
        if (next != null &&
            (next.state == 'missing' || next.state == 'stale')) {
          backgroundRefresh(generation);
        }
      });
      tick();
    });
  }

  void changed() {
    if (!mounted) return;
    setState(() {});
    model.ping();
  }

  /// Drains the refresh countdown once a second, only while the card is
  /// shown.
  void tick() {
    ticker?.cancel();
    if (!visible || cooldownLeft == Duration.zero) return;
    // ignore: raft_lints/avoid_unreviewed_idle_work -- One-second countdown that exists only while the card is on screen and a refresh cooldown runs; it cancels itself at zero or when the card closes.
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!visible || cooldownLeft == Duration.zero) ticker?.cancel();
      changed();
    });
  }

  void setVisible(bool value) {
    if (visible == value) return;
    visible = value;
    tick();
  }

  Duration get cooldownLeft => provider == null
      ? Duration.zero
      : client.cooldownRemaining(widget.serverId, widget.machineId, provider!);

  Future<RuntimeUsageRead?> read([int? generation]) async {
    final p = provider;
    if (p == null) return null;
    final ticket = generation ?? subject;
    loading = true;
    loadError = false;
    changed();
    try {
      final next = await client.read(widget.serverId, widget.machineId, p);
      if (mounted && ticket == subject) result = next;
      return next;
    } catch (_) {
      if (mounted && ticket == subject) loadError = true;
      return null;
    } finally {
      if (mounted && ticket == subject) {
        loading = false;
        changed();
      }
    }
  }

  void followUp(int generation) {
    final ticket = ++poll;
    var attempt = 0;
    void next() {
      if (!mounted || generation != subject || ticket != poll) return;
      if (attempt >= followUpAttempts) {
        refreshState = 'unconfirmed';
        changed();
        return;
      }
      reread?.cancel();
      reread = Timer(followUpDelay, () async {
        attempt++;
        client.invalidate(widget.serverId, widget.machineId, provider!);
        final value = await read(generation);
        if (value == null ||
            !mounted ||
            generation != subject ||
            ticket != poll) {
          return;
        }
        if (value.state == 'fresh') {
          refreshState = 'idle';
          changed();
          return;
        }
        next();
      });
    }

    next();
  }

  Future<void> backgroundRefresh(int generation) async {
    final p = provider;
    if (p == null) return;
    try {
      final out = await client.refresh(
        widget.serverId,
        widget.machineId,
        p,
        'stale_or_missing',
      );
      if (!mounted || generation != subject) return;
      refreshState = out.state;
      tick();
      changed();
      if (out.state == 'requested' || out.state == 'cooldown') {
        followUp(generation);
      }
    } catch (_) {
      if (mounted && generation == subject) {
        refreshState = 'computer_offline';
        changed();
      }
    }
  }

  Future<void> refresh() async {
    final p = provider;
    if (p == null) return;
    final generation = subject;
    refreshState = 'requesting';
    changed();
    try {
      final out = await client.refresh(
        widget.serverId,
        widget.machineId,
        p,
        'manual',
      );
      if (!mounted || generation != subject) return;
      tick();
      if (out.state == 'fresh') {
        if (out.snapshot != null) {
          loadError = false;
          result = RuntimeUsageRead('fresh', out.snapshot);
          refreshState = 'idle';
        } else {
          refreshState = 'unconfirmed';
        }
        changed();
        return;
      }
      refreshState = out.state;
      changed();
      if (out.accepted || out.state == 'cooldown') followUp(generation);
    } catch (_) {
      if (mounted && generation == subject) {
        refreshState = 'computer_offline';
        changed();
      }
    }
  }

  /// The Refresh button: it also drops the last limit reset's note.
  void handleRefresh() {
    limitResetNote = null;
    refresh();
  }

  // --- limit resets ---

  /// The account whose reset the button spends (Codex reports one account).
  /// Claude's resets are used by kind, never through this kind-less action.
  Map? get resetAccount {
    final p = provider;
    final snapshot = result?.snapshot;
    if (p == null || p == 'claude' || snapshot == null) return null;
    for (final a in (snapshot['accounts'] as List? ?? const [])) {
      if (a is Map && ((a['limitResetsAvailable'] as num?) ?? 0) > 0) return a;
    }
    return null;
  }

  bool get canActOnRuntimes =>
      authView?.canAct == true && authView?.availability == 'ok';

  void openLimitReset() {
    final account = resetAccount;
    final p = provider;
    if (account == null || p == null || !mounted) return;
    // Fixed for the dialog's life: the usage read after an outcome may change
    // the count under it.
    final subjectKey = limitResetSubject;
    final target = (
      key: RuntimeLimitResetAttemptKeys.instance.keyFor(subjectKey),
      account: (account['maskedLabel'] ?? account['displayName']) as String?,
      resets: ((account['limitResetsAvailable'] as num?) ?? 0).toInt(),
    );
    limitResetTarget = target;
    showComputerRuntimeLimitResetDialog(
      context,
      client: authClient,
      serverId: widget.serverId,
      machineId: widget.machineId,
      runtimeId: widget.runtimeId,
      provider: p,
      account: target.account,
      resetsAvailable: target.resets,
      idempotencyKey: target.key,
      onOutcome: (outcome) => limitResetOutcome(subjectKey, outcome),
    );
  }

  /// Never assume the limits recovered: show the usage the Computer read
  /// right after the redeem, or read it again.
  void showUsageAfterReset(RuntimeLimitResetOutcome outcome) {
    final p = provider;
    if (p == null || !mounted) return;
    final snapshot = runtimeUsageSnapshotOf(outcome.snapshot);
    if (snapshot != null) {
      client.storeSnapshot(widget.serverId, widget.machineId, p, snapshot);
      poll++;
      loadError = false;
      result = RuntimeUsageRead('fresh', snapshot);
      refreshState = 'idle';
      changed();
    } else {
      refresh();
    }
  }

  void limitResetOutcome(String subjectKey, RuntimeLimitResetOutcome outcome) {
    if (limitResetOutcomeIsSettled(outcome.result)) {
      RuntimeLimitResetAttemptKeys.instance.forget(subjectKey);
    }
    // The card may be gone, but the key above must still be settled.
    if (!mounted || subjectKey != limitResetSubject) return;
    final source = outcome.result == null
        ? null
        : limitResetNoteSource(outcome.result!);
    limitResetNote = source == null ? null : raftText(context, source);
    showUsageAfterReset(outcome);
  }

  // --- the dialogs ---

  Future<void> openSignIn() async {
    final runtime = authRuntime;
    if (runtime == null || !mounted) return;
    final open = perProvider
        ? showComputerRuntimePiSignInDialog
        : showComputerRuntimeSignInDialog;
    await open(
      context,
      controller: widget.controller,
      client: authClient,
      serverId: widget.serverId,
      machineId: widget.machineId,
      runtimeId: widget.runtimeId,
      runtime: runtime,
    );
    // Whatever the dialog ended with, the card reads the Computer's state.
    authClient.invalidate(widget.serverId, widget.machineId);
  }

  void openSignOut([RuntimeAuthSignedInProvider? target]) {
    final runtime = authRuntime;
    if (runtime == null || !mounted) return;
    showComputerRuntimeSignOutDialog(
      context,
      controller: widget.controller,
      client: authClient,
      serverId: widget.serverId,
      machineId: widget.machineId,
      runtimeId: widget.runtimeId,
      runtime: runtime,
      provider: target,
    );
  }

  void openConnectProvider() {
    final runtime = authRuntime;
    if (runtime == null || !mounted) return;
    showComputerRuntimeProviderConnectDialog(
      context,
      controller: widget.controller,
      client: authClient,
      serverId: widget.serverId,
      machineId: widget.machineId,
      runtimeId: widget.runtimeId,
      runtime: runtime,
    );
  }

  // --- drawing ---

  String? relative(BuildContext context, Object? at) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final text = resourceRelativeTime(
      at as String?,
      now: client.now(),
      chinese: zh,
    );
    return text.isEmpty ? null : text;
  }

  /// runtimeAuthAction + the header line's inputs.
  RaftRuntimeAuthData? authData(BuildContext context) {
    final runtime = authRuntime;
    final view = authView;
    if (runtime == null || view == null) return null;
    final status = authStatus;
    final providerKey = runtimeAuthHasProviderKey(runtime);
    var action = RaftRuntimeAuthActionKind.none;
    String? hint, unavailableText, install;
    var outline = false;
    if (view.canAct) {
      // A daemon that predates this runtime's sign-in from the web (Kimi,
      // Qoder) would drop a start.
      final needsNewer = view.availability == 'ok' && !view.supports(runtime);
      if (view.availability == 'computer_upgrade_required' ||
          view.availability == 'computer_not_attached' ||
          needsNewer) {
        action = RaftRuntimeAuthActionKind.hint;
        hint = raftText(
          context,
          view.availability == 'computer_not_attached'
              ? (providerKey
                    ? "This Computer has no owner, so its runtimes can't be connected from here"
                    : "This Computer has no owner, so its runtimes can't be signed in from here")
              : (providerKey
                    ? 'Upgrade this Computer to connect a provider from here'
                    : 'Upgrade this Computer to sign in from here'),
        );
      } else if (view.availability == 'ok') {
        if (status?.kind == 'unavailable') {
          // Before the provider button too: Qwen Code with no usable CLI
          // can't connect a provider either.
          action = RaftRuntimeAuthActionKind.unavailable;
          final reason = status!.reason;
          unavailableText = raftText(
            context,
            reason == 'not_installed'
                ? "Install this runtime's command-line tool on the Computer, then use Rescan runtimes on the Computer's page."
                : reason == 'version_unsupported'
                ? (widget.runtimeId == 'opencode'
                      ? "Upgrade OpenCode on the Computer to 2.x, then use Rescan runtimes on the Computer's page."
                      : "Update this runtime's command-line tool on the Computer, then use Rescan runtimes on the Computer's page.")
                : 'Sign in to this runtime on the Computer itself.',
          );
          if (reason != 'unsupported_installation') {
            install = runtimeInstallCommands[widget.runtimeId];
          }
        } else if (perProvider) {
          // Pi: one more provider at a time (an account or a key).
          action = RaftRuntimeAuthActionKind.addProvider;
          outline = status?.loggedIn == true;
        } else if (providerKey) {
          // One provider is enough; connecting another is the quieter action
          // then.
          action = RaftRuntimeAuthActionKind.connectProvider;
          outline = status?.loggedIn == true;
        } else if (status?.loggedIn == true) {
          // Qoder has no sign-out; a Computer from before Antigravity's signs
          // it in but not out.
          if (view.signsOut(runtime)) {
            action = RaftRuntimeAuthActionKind.signOut;
          }
        } else if (status == null ||
            status.loggedOut ||
            status.kind == 'unknown') {
          action = RaftRuntimeAuthActionKind.signIn;
        }
      }
    }
    final canSignOutProvider =
        view.canAct && view.availability == 'ok' && view.signsOut(runtime);
    return RaftRuntimeAuthData(
      runtime: runtime,
      status: status?.kind,
      accountText: runtimeAuthAccountText(status?.account),
      perProvider: perProvider,
      providerKey: providerKey,
      providers: [
        if (perProvider && status?.loggedIn == true)
          for (final p
              in status?.providers ?? const <RuntimeAuthSignedInProvider>[])
            RaftRuntimeAuthProvider(
              id: p.id,
              label: p.label,
              isKey: p.method == 'api_key',
              detail: raftText(
                context,
                p.method == 'api_key'
                    ? 'API key'
                    // OpenCode does not say whether an account is a
                    // subscription: neither is claimed.
                    : p.subscription == null
                    ? 'Signed in'
                    : p.subscription!
                    ? 'Subscription account'
                    : 'Account',
              ),
              onSignOut: canSignOutProvider ? () => openSignOut(p) : null,
            ),
      ],
      action: action,
      outlineAction: outline,
      hint: hint,
      unavailableText: unavailableText,
      installCommand: install,
      onSignIn: openSignIn,
      onSignOut: openSignOut,
      onConnectProvider: openConnectProvider,
    );
  }

  /// The one caption under the actions: the last limit reset's note, a
  /// refresh in flight or refused, the countdown, the Computer offline.
  String? statusText(BuildContext context) {
    final cooldown = cooldownLeft;
    return limitResetNote ??
        switch (refreshState) {
          'requested' => raftText(context, 'Refresh requested'),
          'unconfirmed' => raftText(
            context,
            'Refresh sent, but no update was observed',
          ),
          'timeout' => raftText(
            context,
            'Refresh timed out — the computer did not return usage in time',
          ),
          _ when cooldown > Duration.zero => raftFormat(
            context,
            'Refresh again in ~{seconds}s',
            {'seconds': (cooldown.inMilliseconds / 1000).ceil()},
          ),
          'computer_offline' => raftText(context, 'Computer offline'),
          _ => null,
        };
  }

  RaftRuntimeReadinessNotice? readinessNotice(BuildContext context) {
    final held = readiness;
    if (held == null || !readinessHeld) return null;
    final copy = formatReadiness(context, held, runtimeId: widget.runtimeId);
    final link = copy.link;
    return RaftRuntimeReadinessNotice(
      heading: readinessHeading(context, copy),
      body: readinessBody(context, copy),
      linkText: link?.text,
      onOpenLink: link == null
          ? null
          : () => unawaited(
              launchUrl(
                Uri.parse(link.href),
                mode: LaunchMode.externalApplication,
              ),
            ),
    );
  }

  /// A Claude runtime's limit resets by kind (claude_limit_reset): the card's
  /// buttons and owner-only line are drawn from this; the Claude flow wires
  /// it later.
  RaftRuntimeClaudeLimitReset? get claudeLimitReset => null;

  RaftRuntimeUsageData data(BuildContext context) {
    final r = result;
    final snapshot = r?.snapshot;
    final p = provider;
    final account = resetAccount;
    final auth = authData(context);
    final name = rackRuntimeDisplayName(widget.runtimeId);
    final providerKey =
        authRuntime != null && runtimeAuthHasProviderKey(authRuntime!);
    return RaftRuntimeUsageData(
      provider: p == null ? null : runtimeUsageProviderName(p),
      runtimeName: name,
      runtimeId: widget.runtimeId,
      version: widget.runtimeVersion,
      dialogLabel: raftFormat(
        context,
        p != null
            ? '{runtime} runtime account usage'
            : providerKey
            ? '{runtime} provider'
            : '{runtime} sign-in',
        {'runtime': name},
      ),
      loading: loading,
      loadError: loadError,
      state: r?.state,
      updated: relative(context, snapshot?['collectedAt']),
      accounts: [
        for (final a in (snapshot?['accounts'] as List? ?? const []))
          if (a is Map) _account(context, a),
      ],
      statusText: statusText(context),
      refreshing: refreshState == 'requesting',
      refreshDisabled:
          refreshState == 'requesting' || cooldownLeft > Duration.zero,
      auth: auth,
      limitReset:
          account != null &&
              canActOnRuntimes &&
              authStatus?.kind != 'logged_out'
          ? RaftRuntimeLimitReset(
              primary:
                  account['health'] == 'rate_limited' ||
                  [
                    for (final w in (account['windows'] as List? ?? const []))
                      if (w is Map) w['status'],
                  ].contains('limit_reached'),
              onUse: openLimitReset,
            )
          : null,
      claudeLimitReset: claudeLimitReset,
      readiness: readinessNotice(context),
    );
  }

  RaftRuntimeUsageAccount _account(BuildContext context, Map a) {
    final resets = a['limitResetsAvailable'];
    return RaftRuntimeUsageAccount(
      health: '${a['health'] ?? 'error'}',
      plan: a['planLabel'] as String?,
      identity: (a['maskedLabel'] ?? a['displayName']) as String?,
      resetsText: resets is! num
          ? null
          : resets > 0
          ? icuText(
              context,
              '{count, plural, one {# reset left} other {# resets left}}',
              {'count': resets.toInt()},
            )
          : raftText(context, 'No resets left'),
      windows: [
        for (final w in (a['windows'] as List? ?? const []))
          if (w is Map && w['label'] != claudeOAuthAppsWindowLabel)
            _window(context, w),
      ],
    );
  }

  RaftRuntimeUsageWindow _window(BuildContext context, Map w) {
    final ratio = ((w['usedRatio'] as num?) ?? 0).toDouble();
    return RaftRuntimeUsageWindow(
      label: '${w['label'] ?? ''}',
      status: '${w['status'] ?? 'ok'}',
      percent: (ratio * 100).round(),
      usedUp: w['status'] == 'limit_reached' || ratio >= 1,
      reset: w['resetsAt'] == null
          ? null
          : relative(context, w['resetsAt']) ?? raftText(context, 'later'),
    );
  }

  void openSheet(BuildContext context) {
    setVisible(true);
    showRaftRuntimeUsageSheet(
      context,
      listenable: model,
      data: data,
      onRefresh: handleRefresh,
    ).whenComplete(() => setVisible(false));
    onOpen();
  }

  /// The card opened: re-read the snapshot and the sign-in view (Web
  /// `openNow`).
  void onOpen() {
    read();
    rereadAuth();
  }

  /// The chip's state words: " (not signed in)" or the readiness suffix.
  String suffix(BuildContext context) {
    if (readinessHeld) {
      final title = formatReadiness(
        context,
        readiness!,
        runtimeId: widget.runtimeId,
      ).title;
      return raftFormat(context, ' ({title})', {'title': title});
    }
    return signedOut ? raftText(context, ' (not signed in)') : '';
  }

  @override
  Widget build(BuildContext context) {
    final p = provider;
    if (p == null && !offered) {
      // Neither usage nor a sign-in offered here: its plain badge.
      final suffix = readinessHeld ? this.suffix(context) : '';
      return suffix.isEmpty
          ? widget.chip(null)
          : RaftRuntimeWarningChip(
              label: '${rackRuntimeDisplayName(widget.runtimeId)}$suffix',
            );
    }
    final value = data(context);
    final suffix = this.suffix(context);
    final attention = signedOut || (result?.attention ?? false);
    final state = RuntimeChipState(
      // The status light is for presence and task status, not a runtime's
      // sign-in: a warning chip carries no dot.
      status: suffix.isEmpty && result?.snapshot != null
          ? RaftRuntimeUsageStatus(attention: attention)
          : null,
      signedOut: signedOut,
      attention: attention,
      suffix: suffix,
    );
    final builder = widget.chipBuilder;
    final trigger = builder != null
        ? builder(state)
        : state.warn
        ? RaftRuntimeWarningChip(
            label: '${rackRuntimeDisplayName(widget.runtimeId)}$suffix',
          )
        : widget.chip(state.status);
    return RaftRuntimeUsageChip(
      label: '${widget.label}$suffix',
      data: value,
      onOpen: onOpen,
      onRefresh: handleRefresh,
      onOpenSheet: openSheet,
      onVisibleChanged: (open) {
        setVisible(open);
      },
      chip: trigger,
    );
  }
}

class _UsageModel extends ChangeNotifier {
  void ping() => notifyListeners();
}
