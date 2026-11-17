// "Your account will be deleted" (Web pages/AccountDeletionPendingPage.tsx,
// store/accountDeletionPending.ts): while a deletion is scheduled only reading
// and cancelling it and signing out are answered, every other API says 403
// `account_deletion_pending`. The app shows this page in place of the whole
// shell, so nothing in the shell (restore retries, the socket, live data)
// keeps asking; the page reads the deletion once.
//
// v7: the date as the title, the days left under it, Cancel Deletion and
// Sign Out; nothing else.
//
// Cancel Deletion: DELETE bound to the request id, then back into Settings >
// Account with the session started over ([onCancelled]); a deletion already
// gone is confirmed by a fresh GET answering "none" after any failed DELETE.
// Sign Out: the app's own sign-out (POST /auth/logout is still answered).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'account_deletion_frame.dart';

class AccountDeletionPendingPage extends StatefulWidget {
  const AccountDeletionPendingPage({
    super.key,
    required this.client,
    required this.onCancelled,
    required this.onSignOut,
    this.now = DateTime.now,
  });
  final RaftClient client;

  /// The deletion is cancelled and the subscription is settled: the app starts
  /// the session over and lands in Settings > Account.
  final VoidCallback onCancelled;
  final VoidCallback onSignOut;
  final DateTime Function() now;

  @override
  State<AccountDeletionPendingPage> createState() =>
      _AccountDeletionPendingPageState();
}

class _AccountDeletionPendingPageState
    extends State<AccountDeletionPendingPage> {
  late String? scheduledFor = widget.client.accountDeletion.scheduledFor;
  bool busy = false, failed = false;
  SubscriptionRestoration? restoration;
  String? requestId;
  bool requestLoadFailed = false,
      requestChanged = false,
      cancellationUnconfirmed = false;
  int reads = 0;

  @override
  void initState() {
    super.initState();
    unawaited(read());
  }

  /// The one read of the deletion: the request to cancel, and the date.
  Future<void> read() async {
    final version = ++reads;
    try {
      final status = await widget.client.accountDeletionStatus();
      if (!mounted || version != reads) return;
      setState(() {
        if (status.scheduled) {
          scheduledFor = status.scheduledFor;
          requestId = status.requestId;
          requestLoadFailed = status.requestId == null;
          cancellationUnconfirmed = status.subscriptionCancellationUnconfirmed;
        } else {
          restoration = status.subscriptionRestoration;
        }
      });
    } catch (_) {
      if (mounted && version == reads) setState(() => requestLoadFailed = true);
    }
  }

  Future<void> cancel() async {
    final id = requestId;
    if (id == null || requestLoadFailed || busy) return;
    setState(() {
      busy = true;
      failed = false;
      requestChanged = false;
    });
    SubscriptionRestoration result;
    try {
      try {
        result = await widget.client.cancelAccountDeletion(id);
      } catch (err) {
        // Every unsuccessful or lost response needs a current-state read. An
        // absent old request is not evidence that no newer deletion exists.
        AccountDeletionStatus? status;
        try {
          status = await widget.client.accountDeletionStatus(requestId: id);
        } catch (_) {
          status = null;
        }
        if (status != null && status.scheduled) {
          if (!mounted) return;
          setState(() {
            scheduledFor = status!.scheduledFor;
            requestChanged = status.requestId != null && status.requestId != id;
            final same = status.requestId == id;
            requestId = status.requestId;
            requestLoadFailed = status.requestId == null;
            cancellationUnconfirmed =
                status.subscriptionCancellationUnconfirmed;
            if (same) failed = true;
            busy = false;
          });
          return;
        }
        if (status == null) rethrow;
        result = status.subscriptionRestoration;
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          failed = true;
        });
      }
      return;
    }
    if (!mounted) return;
    if (result != SubscriptionRestoration.restored) {
      setState(() {
        busy = false;
        restoration = result;
      });
      return;
    }
    widget.onCancelled();
  }

  /// Forget the request that could not be read or cancelled and read it again.
  void retry() {
    setState(() {
      requestId = null;
      requestLoadFailed = false;
      failed = false;
      requestChanged = false;
    });
    unawaited(read());
  }

  Widget banner(String text, {Key? key}) => Padding(
    padding: const EdgeInsets.only(bottom: RaftSpace.x4),
    child: RaftBanner(
      key: key,
      status: RaftBannerRecipeStatus.warning,
      description: raftText(context, text),
    ),
  );

  Widget button(
    String key,
    String label,
    VoidCallback? onPressed, {
    bool accent = false,
    bool loading = false,
    String? loadingLabel,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: RaftSpace.x3),
    child: RaftButton(
      key: ValueKey(key),
      label: label,
      variant: accent ? RaftControlVariant.accent : RaftControlVariant.outline,
      size: RaftButtonRecipeSize.xl,
      expand: true,
      busy: loading,
      loadingLabel: loadingLabel ?? 'Loading',
      onPressed: onPressed,
    ),
  );

  @override
  Widget build(BuildContext context) {
    String tr(String s) => raftText(context, s);
    final t = RaftTokens.of(context);
    final settled = restoration;
    if (settled != null) {
      return AccountDeletionFrame(
        child: Column(
          key: const ValueKey('account-deletion-cancel-warning'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AccountDeletionHeading(
              glyph: RaftGlyph.circleCheck,
              title: tr('Deletion cancelled'),
              subtitle: tr(
                'Once cancelled, sign in again on your devices and reconnect your computers.',
              ),
            ),
            banner(
              settled == SubscriptionRestoration.notRestored
                  ? "Your subscription wasn't automatically restored. Go to Plan & Billing to subscribe again."
                  : "We couldn't confirm your subscription's renewal status. Check Plan & Billing before making another subscription change.",
            ),
            button(
              'account-deletion-go-to-raft',
              tr('Go to Raft'),
              widget.onCancelled,
              accent: true,
            ),
          ],
        ),
      );
    }
    final dateText = accountDeletionDate(context, scheduledFor);
    final days = daysUntilDeletion(scheduledFor, widget.now());
    return AccountDeletionFrame(
      child: Column(
        key: const ValueKey('account-deletion-pending-page'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AccountDeletionHeading(
            glyph: RaftGlyph.clock,
            title: dateText.isEmpty
                ? tr('Your account will be deleted')
                : raftFormat(
                    context,
                    'Your account will be deleted on {date}',
                    {'date': dateText},
                  ),
            subtitle: days != null && days > 0
                ? accountDeletionCount(
                    context,
                    days,
                    '{count} day left',
                    '{count} days left',
                  )
                : dateText.isEmpty
                ? tr(
                    'Your account is scheduled for deletion. Cancel the deletion to keep using Raft.',
                  )
                : null,
          ),
          // Every Computer and agent key was revoked at the request:
          // cancelling doesn't bring them back.
          Padding(
            padding: const EdgeInsets.only(bottom: RaftSpace.x5),
            child: Text(
              tr(
                'Once cancelled, sign in again on your devices and reconnect your computers.',
              ),
              key: const ValueKey('account-deletion-reconnect'),
              textAlign: TextAlign.center,
              style: RaftTypography.heading(
                t,
                size: 14,
                line: 20,
                weight: FontWeight.w400,
              ).copyWith(color: t.muted),
            ),
          ),
          if (cancellationUnconfirmed)
            banner(
              'We could not confirm cancellation of subscription renewal. To check your subscription, cancel account deletion first, then open Plan & Billing.',
              key: const ValueKey('account-deletion-unconfirmed-subscription'),
            ),
          if (requestChanged)
            banner(
              'A newer deletion request is still scheduled. Review it before cancelling.',
              key: const ValueKey('account-deletion-request-changed'),
            ),
          if (requestLoadFailed)
            banner(
              'The current deletion request could not be confirmed. Load it again before cancelling.',
              key: const ValueKey('account-deletion-request-unconfirmed'),
            ),
          if (failed)
            banner(
              "Couldn't confirm the deletion status. Check the current request and try again.",
              key: const ValueKey('account-deletion-cancel-failed'),
            ),
          button(
            'account-deletion-cancel',
            tr('Cancel deletion'),
            busy || requestId == null || requestLoadFailed ? null : cancel,
            accent: true,
            loading: busy,
            loadingLabel: tr('Cancelling deletion…'),
          ),
          if (requestLoadFailed || failed)
            button('account-deletion-retry', tr('Try again'), retry),
          button(
            'account-deletion-sign-out',
            tr('Sign out'),
            busy ? null : widget.onSignOut,
          ),
        ],
      ),
    );
  }
}
