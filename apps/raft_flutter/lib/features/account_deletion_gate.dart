// The app, or what stands in for it while an account deletion is in play
// (Web pages/AccountDeletionGate.tsx, store/accountDeletionPending.ts): the
// confirmation right after this app requested it, or the pending page once
// any request was refused with 403 `account_deletion_pending`. The app root
// shows it around the whole shell, so nothing in the shell keeps asking.
import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/workspace_controller.dart';
import 'account_deletion_pending_page.dart';
import 'account_deletion_requested_page.dart';

class AccountDeletionGateView extends StatefulWidget {
  const AccountDeletionGateView(
    this.client,
    this.onCancelled,
    this.onSignOut, {
    super.key,
  });
  final RaftClient client;

  /// Cancel Deletion went through: the session starts over in Settings >
  /// Account.
  final VoidCallback onCancelled;

  /// Sign Out / OK: the app's own sign-out.
  final VoidCallback onSignOut;

  @override
  State<AccountDeletionGateView> createState() =>
      _AccountDeletionGateViewState();
}

class _AccountDeletionGateViewState extends State<AccountDeletionGateView> {
  AccountDeletionGate get gate => widget.client.accountDeletion;

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    gate.addListener(changed);
  }

  @override
  void didUpdateWidget(AccountDeletionGateView old) {
    super.didUpdateWidget(old);
    if (!identical(old.client, widget.client)) {
      old.client.accountDeletion.removeListener(changed);
      gate.addListener(changed);
    }
  }

  @override
  void dispose() {
    gate.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => gate.requested
      ? AccountDeletionRequestedPage(
          scheduledFor: gate.requestedScheduledFor,
          onOk: widget.onSignOut,
        )
      : AccountDeletionPendingPage(
          // A new request after a cancel starts a new page state.
          key: ValueKey(widget.client),
          client: widget.client,
          onCancelled: widget.onCancelled,
          onSignOut: widget.onSignOut,
        );
}

/// Where the app lands once a pending deletion is cancelled (Web
/// pages/accountDeletionReturn.ts `accountSettingsAfterCancel`): Settings >
/// Account of the server the person was in, else of the last one they were
/// in ([lastServerKey]'s remembered slug), else the app's start.
Future<Uri> accountSettingsAfterCancel(
  WorkspaceController? old,
  String lastServerKey,
) async {
  final prefs = await SharedPreferences.getInstance();
  final slug = old?.server?.string('slug') ?? prefs.getString(lastServerKey);
  return Uri(path: slug == null ? '/' : '/s/$slug/settings/account');
}
