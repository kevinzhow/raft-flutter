// Settings > Account > Delete Account (/s/<slug>/settings/account/delete; Web
// features/settings/account/DeleteAccountPage.tsx), a level-2 Settings page
// whose title bar and breadcrumb the settings shell draws; this is its body.
//
// 1. The list ([AccountDeletionChecklist], v7) from GET. Delete account sends
//    the request with no proof first: the server answers with what it wants
//    (403 `reauth_required` with `methods`), or schedules at once after a
//    recent sign-in.
// 2. The proof the server asked for, in a small dialog over the page
//    ([showAccountDeletionProof]).
// 3. 409 `sole_owner_servers` (the server checks again; the only check on an
//    older server): those servers join the page's Needs action rows, and the
//    list is read again. Then 409 `others_agents_on_computers`: other members'
//    agents still on the person's computers; the 409's list stands for that
//    group until the read it starts lands. The person's own agents don't hold
//    it up. 403 `session_family_required`: Sign in again.
//
//    Force unbind and request deletion sends the same request, every step of
//    it, with `forceAgentIds`, the agents the person confirmed; a 409
//    `others_agents_on_computers` then means more arrived: the group is
//    redrawn from it and a line asks to confirm again.
//
// The list is read again after every action and whenever the app comes back
// to the foreground (an owner moves their agent elsewhere, so its row goes).
// 4. Scheduled: every sign-in is already gone. The confirmation
//    ([AccountDeletionRequestedPage]) stands in for the whole shell, so
//    nothing keeps asking; it says when, and OK signs out.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'account_deletion_checklist.dart';
import 'account_deletion_flow.dart';
import 'account_deletion_verify.dart';
import 'account_security_answer.dart';

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({
    super.key,
    required this.controller,
    this.moveAgentId,
    this.onMoveConsumed,
    this.onOpenServerSettings,
    this.onMoveElsewhere,
    this.onSignOut,
  });
  final WorkspaceController controller;

  /// Move to another computer from another server's row lands here with
  /// `?move=<agentId>` (Web `MOVE_AGENT_PARAM`).
  final String? moveAgentId;

  /// The agent's move was opened (or could not be): clear `?move=`.
  final VoidCallback? onMoveConsumed;

  /// Opens a server's settings (`/s/<slug>/settings/server`), from a server
  /// the person cannot hand over.
  final void Function(AccountDeletionServer server)? onOpenServerSettings;

  /// Opens this page on another server with that agent's move (`?move=`).
  final void Function(AccountDeletionServer server, String agentId)?
  onMoveElsewhere;

  /// Sign in again / OK: the app's own sign-out. Defaults to the client's.
  final VoidCallback? onSignOut;

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage>
    with WidgetsBindingObserver {
  RaftClient get client => widget.controller.client;

  int reads = 0;

  /// What the last settled GET answered (`checklist` stays as it was when one
  /// fails).
  AccountDeletionChecklist? checklist;
  bool loaded = false;
  List<SoleOwnerServer> refusedSoleOwners = const [];

  /// The 409's others' agents, until a read lands after it (an older read is
  /// dropped as it lands).
  List<AccountDeletionOthersAgent>? refusedOthersAgents;

  /// The confirmed force list, sent with every step of this request (the
  /// proof dialog's too).
  List<String>? forceAgentIds;
  bool forceConflict = false, busy = false, signInAgain = false;
  String? failureBanner;

  /// The proof a refusal named instead, while a dialog closes.
  AccountDeletionReauth? redirect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(read());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Others' agents leave when their owners move them, elsewhere: read again
  /// on coming back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) reload();
  }

  void reload() {
    if (mounted) unawaited(read());
  }

  Future<void> read() async {
    final version = ++reads;
    AccountDeletionStatus? status;
    try {
      // A failed read leaves the fixed facts; the 409 at submit time still
      // guards.
      status = await client.accountDeletionStatus();
    } catch (_) {
      status = null;
    }
    if (!mounted || version != reads) return;
    setState(() {
      checklist = status?.checklist ?? checklist;
      loaded = true;
      if (status != null) refusedOthersAgents = null;
    });
  }

  void signOut() => (widget.onSignOut ?? () => unawaited(client.logout()))();

  /// Sends the request. Scheduled: the page says so; the sign-in is already
  /// gone, so the socket stops asking.
  Future<AccountDeletionOutcome> submit(AccountDeletionProof proof) async {
    String? scheduledFor;
    try {
      final status = await client.requestAccountDeletion(
        proof,
        forceAgentIds: forceAgentIds,
      );
      scheduledFor = status.scheduled ? status.scheduledFor : null;
    } catch (error) {
      final refusal = AccountDeletionRefusal.of(error);
      final forced = forceAgentIds != null;
      if (refusal is! AccountDeletionReauthRefused) forceAgentIds = null;
      if (refusal is AccountDeletionSoleOwner) {
        if (mounted) setState(() => refusedSoleOwners = refusal.servers);
        reload();
        return const AccountDeletionMoved();
      }
      if (refusal is AccountDeletionOthersAgentsRefused) {
        // Forced: more agents arrived since the dialog; nothing was unbound.
        if (mounted) {
          setState(() {
            forceConflict = forced;
            refusedOthersAgents = refusal.agents;
          });
        }
        reload();
        return const AccountDeletionMoved();
      }
      if (refusal is AccountDeletionSignInAgain) {
        return const AccountDeletionNeedsSignIn();
      }
      if (refusal is AccountDeletionReauthRefused) {
        redirect = refusal.reauth;
        return const AccountDeletionMoved();
      }
      return AccountDeletionFailed(error);
    }
    // The confirmation stands in for the whole shell, so nothing in it keeps
    // asking with the revoked session before OK.
    client.accountDeletion.markRequested(scheduledFor);
    return const AccountDeletionMoved();
  }

  /// The proof the server named, until it is cancelled or another phase takes
  /// over (a refusal can name another proof, which replaces the dialog).
  Future<void> prove(AccountDeletionReauth first) async {
    var next = first;
    while (mounted) {
      redirect = null;
      await showAccountDeletionProof(
        context,
        client,
        next,
        submit: submit,
        moveToReauth: (reauth) => redirect = reauth,
        onSignOut: signOut,
      );
      final again = redirect;
      if (again == null) break;
      next = again;
    }
    // Back to the checklist: a cancelled proof drops the force list.
    forceAgentIds = null;
  }

  Future<void> start(List<String>? force) async {
    forceAgentIds = force;
    setState(() {
      forceConflict = false;
      busy = true;
      failureBanner = null;
      signInAgain = false;
    });
    final outcome = await submit(AccountDeletionProof.none);
    if (!mounted) return;
    final shown = accountDeletionFailure(
      context,
      client,
      outcome,
      SecondFactorAnswerKind.password,
    );
    setState(() {
      busy = false;
      failureBanner = shown.banner;
      signInAgain = shown.signInAgain;
    });
    if (redirect case final reauth?) {
      redirect = null;
      await prove(reauth);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AccountDeletionChecklistView(
      controller: widget.controller,
      checklist: checklist,
      loaded: loaded,
      refusedSoleOwners: refusedSoleOwners,
      refusedOthersAgents: refusedOthersAgents,
      autoMoveAgentId: widget.moveAgentId,
      onAutoMoveHandled: widget.onMoveConsumed ?? () {},
      onReload: reload,
      onDelete: () => unawaited(start(null)),
      onForceUnbind: (ids) => unawaited(start(ids)),
      onOpenServerSettings: widget.onOpenServerSettings,
      onMoveElsewhere: widget.onMoveElsewhere,
      busy: busy,
      notice: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: RaftSpace.x2,
        children: [
          if (forceConflict)
            RaftBanner(
              key: const ValueKey('account-deletion-force-conflict'),
              status: RaftBannerRecipeStatus.warning,
              size: RaftBannerRecipeSize.sm,
              description: raftText(
                context,
                'More agents were added to your computers, so nothing was unbound. Check the list and confirm again.',
              ),
            ),
          if (failureBanner case final text?)
            RaftBanner(
              key: const ValueKey('account-deletion-failure'),
              status: RaftBannerRecipeStatus.warning,
              size: RaftBannerRecipeSize.sm,
              description: text,
            ),
          if (signInAgain) AccountDeletionSignInAgainBanner(onSignOut: signOut),
        ],
      ),
    );
  }
}
