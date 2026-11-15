// Web v1.24.0 step-up for sensitive actions (components/settings/
// secondFactorStepUp.ts, SecondFactorStepUpHost.tsx, VerifyItsYouDialog.tsx):
// with two-step verification on, the server refuses changing the password,
// connecting or disconnecting a sign-in method, creating an agent key or a
// machine key, a new app secret, giving an app access, executing an action
// card whose kind needs a second factor (and more) with 403
// `second_factor_step_up_required` and the methods, unless this sign-in
// passed the second step in the last 10 minutes. [withSecondFactorStepUp]
// runs the request; on that refusal it opens "Verify it's you", and once POST
// /auth/second-factor/step-up passed it sends the request once more.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/second_factor_last_method.dart';
import 'account_security_answer.dart';

/// What the dialog says the step-up is for (Web `StepUpReason`,
/// SecondFactorStepUpHost `DESCRIPTION_IDS`).
enum StepUpReason {
  signInMethod(
    'Changing how you sign in needs a fresh second step. It lasts 10 minutes.',
  ),
  agentKey(
    'Generating a login token needs a fresh second step. It lasts 10 minutes.',
  ),
  appAccess(
    'Giving an app access to your account needs a sign-in that passed the second step.',
  ),
  agentAccess(
    'Letting an app act as an agent needs a sign-in that passed the second step.',
  ),
  secret(
    'Creating a new secret needs a fresh second step. It lasts 10 minutes.',
  ),
  actionCard('This action needs your second step first.'),
  other('This needs a fresh second step. It lasts 10 minutes.');

  const StepUpReason(this.description);
  final String description;
}

/// "Verify it's you" was closed: callers do nothing and show no error.
class SecondFactorStepUpCancelled implements Exception {
  const SecondFactorStepUpCancelled();
  @override
  String toString() => 'second_factor_step_up_cancelled';
}

bool isSecondFactorStepUpCancelled(Object? error) =>
    error is SecondFactorStepUpCancelled;

/// One dialog for every refused request at the same time (Web `inFlight`).
Future<void>? _inFlight;

/// [request], and after a step-up the same request once more (a second
/// refusal goes to the caller like any other error). People without two-step
/// verification are never refused, so for them this is just the request.
Future<T> withSecondFactorStepUp<T>(
  BuildContext context,
  RaftClient client,
  Future<T> Function() request, {
  StepUpReason reason = StepUpReason.other,
}) async {
  try {
    return await request();
  } catch (error) {
    final methods = stepUpRequiredMethods(error);
    if (methods == null || !context.mounted) rethrow;
    await (_inFlight ??= _stepUp(
      context,
      client,
      methods,
      reason,
    ).whenComplete(() => _inFlight = null));
    return request();
  }
}

/// SecondFactorStepUpHost: POST /step-up with the answer; turned off
/// meanwhile, the request goes as it is. "Sign in again" (403
/// `session_family_required`) closes the dialog and signs out.
Future<void> _stepUp(
  BuildContext context,
  RaftClient client,
  List<SecondFactorMethod> listed,
  StepUpReason reason,
) async {
  final verified = await showVerifyItsYou(
    context,
    client,
    methods: listed,
    description: reason.description,
    onSignInAgain: () => unawaited(client.logout()),
    onAnswer: (answer) async {
      try {
        await client.stepUpSecondFactor(
          code: answer.code,
          backupCode: answer.backupCode,
        );
      } catch (error) {
        if (SecondFactorFailure.of(error).code != 'second_factor_not_enabled') {
          rethrow;
        }
      }
    },
  );
  if (!verified) throw const SecondFactorStepUpCancelled();
}

/// Web VerifyItsYouDialog: a code or a backup code among the `methods` the
/// server listed (this client has no passkeys: a listed passkey alone says
/// so), the others as links. [onAnswer] sends it; what it refuses stays in
/// the dialog. True once [onAnswer] passed, false when closed.
Future<bool> showVerifyItsYou(
  BuildContext context,
  RaftClient client, {
  required List<SecondFactorMethod> methods,
  required String description,
  required Future<void> Function(StepUpAnswer answer) onAnswer,
  VoidCallback? onSignInAgain,
}) async {
  var signInAgain = false;
  final verified = await showRaftForm<bool>(
    context,
    label: raftText(context, "Verify it's you"),
    // Web StepDialog `<Dialog disablePointerDismissal>`: a stray tap must
    // not cancel the step-up and drop the typed code.
    dismissible: false,
    dragDismissible: false,
    // Web closes the dialog at once: a typed code is not a draft.
    guardUnsaved: false,
    builder: (_) => _VerifyItsYouDialog(
      client: client,
      methods: usableSecondFactorMethods(methods).methods,
      description: description,
      onAnswer: onAnswer,
      onSignInAgain: onSignInAgain == null ? null : () => signInAgain = true,
    ),
  );
  if (signInAgain) onSignInAgain?.call();
  return verified == true;
}

class _VerifyItsYouDialog extends StatefulWidget {
  const _VerifyItsYouDialog({
    required this.client,
    required this.methods,
    required this.description,
    required this.onAnswer,
    this.onSignInAgain,
  });
  final RaftClient client;
  final List<SecondFactorMethod> methods;
  final String description;
  final Future<void> Function(StepUpAnswer answer) onAnswer;
  final VoidCallback? onSignInAgain;

  @override
  State<_VerifyItsYouDialog> createState() => _VerifyItsYouDialogState();
}

class _VerifyItsYouDialogState extends State<_VerifyItsYouDialog> {
  /// Web `initialMethod`: the way this device answered with last.
  late SecondFactorMethod? method = initialSecondFactorMethod(widget.methods);

  /// 403 `session_family_required`: the banner offers Sign in again.
  bool signInAgain = false;

  Future<void> answer(Map<String, String> values) async {
    final current = method;
    if (current == null) return;
    final entered = normalizeSecondFactorCode(values[current.wire] ?? '');
    final backup = current == SecondFactorMethod.backupCode;
    if (signInAgain) setState(() => signInAgain = false);
    try {
      await widget.onAnswer(
        backup ? StepUpAnswer.backupCode(entered) : StepUpAnswer.code(entered),
      );
      rememberSecondFactorMethod(current);
    } catch (error) {
      if (!mounted) rethrow;
      final code = SecondFactorFailure.of(error).code;
      if (widget.onSignInAgain != null && code == 'session_family_required') {
        setState(() => signInAgain = true);
        throw RaftUserError(
          raftText(
            context,
            "This sign-in can't be verified. Sign in again, then try once more.",
          ),
        );
      }
      final text = secondFactorFailureText(
        context,
        widget.client,
        error,
        backup
            ? SecondFactorAnswerKind.backupCode
            : SecondFactorAnswerKind.totp,
      );
      // Web `FailureCopy`: a wrong or used code under the field (gone once it
      // is edited), a lock or anything else in the banner.
      if (secondFactorFailureUnderField(error)) {
        throw RaftFieldError(current.wire, text);
      }
      throw RaftUserError(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = method;
    final others = [
      for (final other in widget.methods)
        if (other != current) other,
    ];
    return RaftFormDialog(
      // Web `AnswerField key={method}` and `reset()` on a switch: the other
      // way starts empty, without the last failure.
      key: ValueKey('step-up-${current?.wire}'),
      title: "Verify it's you",
      description: widget.description,
      submitLabel: 'Verify',
      submitEnabled: current != null,
      // Web `disabled={!normalizeEnteredCode(value)}`.
      submitWhenFilled: true,
      fields: [
        if (current == SecondFactorMethod.backupCode)
          RaftFormField.typedCode(current!.wire, 'Backup code')
        else if (current != null)
          RaftFormField.oneTimeCode(current.wire, 'Authenticator code'),
      ],
      extra: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (current == null)
            RaftBanner(
              status: RaftBannerRecipeStatus.warning,
              description: raftText(
                context,
                "This browser can't use passkeys. Use another way, or open Raft in a browser that has your passkey.",
              ),
            ),
          if (others.isNotEmpty)
            Wrap(
              // Web `flex flex-wrap gap-x-4 gap-y-1`.
              spacing: RaftSpace.x4,
              runSpacing: RaftSpace.x1,
              children: [
                for (final other in others)
                  RaftAuthTextLink(
                    key: ValueKey('step-up-use-${other.wire}'),
                    label: raftText(
                      context,
                      other == SecondFactorMethod.backupCode
                          ? 'Use a backup code'
                          : 'Use authenticator code',
                    ),
                    onTap: () => setState(() {
                      method = other;
                      signInAgain = false;
                    }),
                  ),
              ],
            ),
          if (signInAgain) ...[
            const SizedBox(height: RaftSpace.x3),
            Align(
              alignment: Alignment.centerLeft,
              child: RaftButton(
                key: const ValueKey('step-up-sign-in-again'),
                label: raftText(context, 'Sign in again'),
                secondary: true,
                onPressed: () {
                  widget.onSignInAgain?.call();
                  Navigator.of(context).pop(false);
                },
              ),
            ),
          ],
        ],
      ),
      onSubmit: answer,
    );
  }
}
