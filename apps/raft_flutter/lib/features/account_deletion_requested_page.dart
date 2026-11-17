// Right after this app requested the account deletion (Web pages/
// AccountDeletionRequestedPage.tsx): every sign-in, this one too, is already
// gone, and the confirmation stands in for the whole shell so nothing in it
// keeps asking (and getting 401s) meanwhile. v7: "Deletion scheduled", the
// date it takes effect, how to cancel (and that cancelling means signing in
// again on each device and reconnecting the computers: every Computer and
// agent key was revoked), that every device is signed out; OK signs out the
// way Sign Out does.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'account_deletion_frame.dart';

class AccountDeletionRequestedPage extends StatelessWidget {
  const AccountDeletionRequestedPage({
    super.key,
    required this.scheduledFor,
    required this.onOk,
  });
  final String? scheduledFor;
  final VoidCallback onOk;

  @override
  Widget build(BuildContext context) {
    String tr(String s) => raftText(context, s);
    final t = RaftTokens.of(context);
    final date = accountDeletionDate(context, scheduledFor);
    final strong = RaftTypography.heading(
      t,
      size: 15,
      line: 20,
      weight: FontWeight.w600,
    ).copyWith(color: t.semantic.foreground);
    final muted = RaftTypography.heading(
      t,
      size: 14,
      line: 20,
      weight: FontWeight.w400,
    ).copyWith(color: t.muted);
    return AccountDeletionFrame(
      child: Column(
        key: const ValueKey('account-deletion-scheduled'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AccountDeletionHeading(
            glyph: RaftGlyph.calendarCheck,
            title: tr('Deletion scheduled'),
            subtitleSpan: date.isEmpty
                ? null
                : accountDeletionDateSpan(
                    raftText(context, 'Takes effect on {date}'),
                    date,
                    strong,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: RaftSpace.x5),
            child: RaftCard(
              padding: const EdgeInsets.all(RaftSpace.x4),
              child: Column(
                key: const ValueKey('account-deletion-how-to-cancel'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('How to cancel'),
                    style: RaftTypography.heading(
                      t,
                      size: 14,
                      line: 20,
                      weight: FontWeight.w600,
                    ).copyWith(color: t.colors['foreground-hint'] ?? t.muted),
                  ),
                  const SizedBox(height: AccountDeletionMetrics.gap10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: RaftSpace.half),
                        child: ExcludeSemantics(
                          child: RaftIcon(
                            RaftGlyph.logIn,
                            size: 20,
                            color: t.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: AccountDeletionMetrics.gap10),
                      Expanded(
                        // Web `<b className="font-semibold">` on the date.
                        child: Text.rich(
                          date.isEmpty
                              ? TextSpan(
                                  text: tr(
                                    'Sign in before the deletion date to cancel',
                                  ),
                                )
                              : accountDeletionDateSpan(
                                  raftText(
                                    context,
                                    'Sign in to Raft before {date}',
                                  ),
                                  date,
                                  strong,
                                ),
                          key: const ValueKey('account-deletion-cancel-by'),
                          style: RaftTypography.heading(
                            t,
                            size: 15,
                            line: 22,
                            weight: FontWeight.w400,
                          ).copyWith(color: t.semantic.foreground),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AccountDeletionMetrics.gap10),
                  Text(
                    tr(
                      'Once cancelled, sign in again on your devices and reconnect your computers.',
                    ),
                    key: const ValueKey('account-deletion-reconnect'),
                    style: muted,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: RaftSpace.x5),
            child: Text(
              tr("You've been signed out on every device."),
              textAlign: TextAlign.center,
              style: muted,
            ),
          ),
          RaftButton(
            key: const ValueKey('account-deletion-ok'),
            label: tr('OK'),
            variant: RaftControlVariant.accent,
            size: RaftButtonRecipeSize.xl,
            expand: true,
            onPressed: onOk,
          ),
        ],
      ),
    );
  }
}
