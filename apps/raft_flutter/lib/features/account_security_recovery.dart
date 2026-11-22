// Resetting two-step verification by email, for someone who lost every
// second step (Web v1.24.0 components/auth/secondFactorRecovery.ts,
// SecondFactorRecoveryScreens.tsx, SecondFactorSignInStep.tsx). Server:
// routes/secondFactor.ts "Email recovery".
//
//   Signed out (the sign-in's second step): POST /auth/second-factor/recovery
//   {email} answers the same for every address. Once the request is past its
//   72-hour wait the challenge lists `recovery`, and POST
//   /auth/second-factor/verify {challenge, recovery: true} finishes it like a
//   code (409 recovery_not_ready / recovery_not_found otherwise).
//
// The emailed confirm and cancel links open the Web page that handles them
// (SecondFactorRecoveryLinkPage): this client has no app links for that
// origin (2654e77c), so a link always opens in the browser.
import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/system_notification_projection.dart';
import '../data/system_notification_store.dart';
import 'account_security_answer.dart';
import 'auth_view.dart' show isValidAuthEmail;

/// Which recovery screen takes the second step's page.
enum SecondFactorRecoveryView { lost, finish }

class SecondFactorRecoveryScreen extends StatefulWidget {
  const SecondFactorRecoveryScreen({
    super.key,
    required this.view,
    required this.pending,
    required this.request,
    required this.finish,
    required this.onBack,
    required this.onBackToSignIn,
    required this.onExpired,
    this.onUseBackupCode,
  });
  final SecondFactorRecoveryView view;
  final SecondFactorRequired pending;

  /// POST /auth/second-factor/recovery {email}, signed out.
  final Future<void> Function(String email) request;

  /// Answers the challenge with `{recovery: true}`; signs in.
  final Future<void> Function() finish;

  /// Back to the second step.
  final VoidCallback onBack;

  /// After the email is sent: this sign-in is done with.
  final VoidCallback onBackToSignIn;

  /// The challenge expired while finishing: the step says so.
  final VoidCallback onExpired;

  /// Present when the account has backup codes.
  final VoidCallback? onUseBackupCode;

  @override
  State<SecondFactorRecoveryScreen> createState() => _RecoveryState();
}

class _RecoveryState extends State<SecondFactorRecoveryScreen> {
  // The email typed at a password sign-in; a social sign-in only knows the
  // masked address, so the field starts empty.
  late final email = TextEditingController(text: widget.pending.email ?? '');
  bool busy = false, sent = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the email is edited, on every submit and when the screen goes; the state is dropped with it.
  String? fieldError, failure;

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> request() async {
    if (busy) return;
    if (!isValidAuthEmail(email.text)) {
      setState(() => fieldError = raftText(context, 'Invalid email format'));
      return;
    }
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await widget.request(email.text.trim());
      if (mounted) setState(() => sent = true);
    } catch (error) {
      if (!mounted) return;
      // 429 comes the same for every address too, so saying so tells
      // nothing about the account.
      final limited = error is RaftApiException && error.status == 429;
      setState(
        () => failure = raftText(
          context,
          limited
              ? 'Too many requests. Try again later.'
              : "The email wasn't sent. Try again.",
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Finishing: the same success as a code, with every factor removed and
  /// every other sign-in signed out (the screen said so first).
  Future<void> finish() async {
    if (busy) return;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await widget.finish();
    } catch (error) {
      if (!mounted) return;
      final code = SecondFactorFailure.of(error).code;
      if (code == 'challenge_expired') {
        widget.onExpired();
        return;
      }
      setState(
        () => failure = raftText(
          context,
          code == 'recovery_not_ready' || code == 'recovery_not_found'
              ? "This reset can't be finished now: it was cancelled, has lapsed, or isn't ready yet. Use your second step, or start a new reset."
              : 'Sign-in failed',
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.view == SecondFactorRecoveryView.finish) {
      return RaftAuthFinishRecoveryPage(
        maskedEmail: widget.pending.challenge.maskedEmail,
        busy: busy,
        failure: failure,
        onFinish: finish,
        onBack: widget.onBack,
      );
    }
    return RaftAuthRecoveryRequestPage(
      sent: sent,
      busy: busy,
      canSubmit: email.text.trim().isNotEmpty,
      fieldError: fieldError,
      failure: failure,
      onSubmit: request,
      onBack: widget.onBack,
      onBackToSignIn: widget.onBackToSignIn,
      onUseBackupCode: widget.onUseBackupCode,
      emailField: RaftTextInput(
        key: const ValueKey('second-factor-recovery-email'),
        controller: email,
        enabled: !busy,
        invalid: fieldError != null,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        semanticLabel: raftText(context, 'Email'),
        onChanged: (_) => setState(() => fieldError = null),
        onSubmitted: (_) => request(),
      ),
    );
  }
}

/// "Reset requested" / "Reset ready" in the notification center (Web
/// useSecondFactorRecoveryNotification): no Dismiss, it stays until the
/// request is gone; Cancel reset ends it in one step, with no step-up and no
/// confirm (cancelling is the safe direction).
RaftNotificationEntry secondFactorRecoveryEntry(
  BuildContext context,
  RaftClient client,
  SystemNotice notice,
  SystemNotificationStore store,
  String scope,
) {
  final p = notice.parameters;
  final ready = p['ready'] == true;
  String when(String key) {
    final time = DateTime.tryParse('${p[key] ?? ''}');
    return time == null ? '' : secondFactorDateTime(context, client, time);
  }

  final body = [
    ready
        ? raftFormat(
            context,
            'Someone asked to reset two-step verification on your account, and the next sign-in can finish it without the second step, until {time}. Not you? Cancel the reset and change your password.',
            {'time': when('expiresAt')},
          )
        : raftFormat(
            context,
            'Someone asked to reset two-step verification on your account. Signing in can finish it after {time}. Not you? Cancel the reset.',
            {'time': when('eligibleAt')},
          ),
    if (p['setPasswordFirst'] == true)
      raftText(
        context,
        'This account has no password yet: set one with Forgot Password on the sign-in page, then sign in to finish it.',
      ),
  ].join(' ');
  return RaftNotificationEntry(
    id: notice.id,
    kind: RaftNotificationKind.warning,
    iconForeground: RaftTokens.of(context).colors['foreground'],
    title: raftText(context, ready ? 'Reset ready' : 'Reset requested'),
    body: body,
    glyph: RaftGlyph.shieldAlert,
    actions: [
      RaftNotificationAction(
        label: raftText(context, 'Cancel reset'),
        // Web `disabled: busy`.
        enabled: !store.secondFactorRecoveryCancelling,
        onPressed: () async {
          if (!store.beginSecondFactorRecoveryCancel()) return;
          try {
            if (await cancelSecondFactorRecoveryWithToast(context, client)) {
              store.secondFactorRecoveryCancelled(scope);
            }
          } finally {
            store.endSecondFactorRecoveryCancel();
          }
        },
      ),
    ],
  );
}

/// Cancels it and says so in a toast (Web `handleCancel`).
Future<bool> cancelSecondFactorRecoveryWithToast(
  BuildContext context,
  RaftClient client,
) async {
  try {
    await client.cancelSecondFactorRecovery();
    if (context.mounted) {
      showRaftToast(
        context,
        'Reset cancelled. Two-step verification stays on, and we emailed you.',
        tone: RaftToastRecipeTone.success,
      );
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      showRaftToast(context, "The reset wasn't cancelled. Try again.");
    }
    return false;
  }
}
