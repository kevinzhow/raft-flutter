// Web v1.24.0 step-up for sensitive actions (components/settings/
// secondFactorStepUp.ts, SecondFactorStepUpHost.tsx, VerifyItsYouDialog.tsx):
// with two-step verification on, the server refuses changing the password,
// connecting or disconnecting a sign-in method, executing an action card
// whose kind needs a second factor (and more) with 403
// `second_factor_step_up_required` and the methods, unless this sign-in passed
// the second step in the last 10 minutes. [withSecondFactorStepUp] runs the
// request; on that refusal it opens "Verify it's you", and once POST
// /auth/second-factor/step-up passed it sends the request once more.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/source_time_formatter.dart';

/// What the dialog says the step-up is for (Web `StepUpReason`).
enum StepUpReason {
  signInMethod(
    'Changing how you sign in needs a fresh second step. It lasts 10 minutes.',
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
    await (_inFlight ??= _verifyItsYou(
      context,
      client,
      methods,
      reason,
    ).whenComplete(() => _inFlight = null));
    return request();
  }
}

Future<void> _verifyItsYou(
  BuildContext context,
  RaftClient client,
  List<SecondFactorMethod> listed,
  StepUpReason reason,
) async {
  final verified = await showRaftForm<bool>(
    context,
    label: raftText(context, "Verify it's you"),
    // Web closes the dialog at once: a typed code is not a draft.
    guardUnsaved: false,
    builder: (_) => _VerifyItsYouDialog(
      client: client,
      methods: usableSecondFactorMethods(listed),
      reason: reason,
    ),
  );
  if (verified != true) throw const SecondFactorStepUpCancelled();
}

class _VerifyItsYouDialog extends StatefulWidget {
  const _VerifyItsYouDialog({
    required this.client,
    required this.methods,
    required this.reason,
  });
  final RaftClient client;
  final ({List<SecondFactorMethod> methods, bool passkeyUnsupported}) methods;
  final StepUpReason reason;

  @override
  State<_VerifyItsYouDialog> createState() => _VerifyItsYouDialogState();
}

class _VerifyItsYouDialogState extends State<_VerifyItsYouDialog> {
  late SecondFactorMethod? method = widget.methods.methods.firstOrNull;

  Future<void> answer(Map<String, String> values) async {
    final current = method;
    if (current == null) return;
    final entered = normalizeSecondFactorCode(values[current.wire] ?? '');
    final backup = current == SecondFactorMethod.backupCode;
    try {
      await widget.client.stepUpSecondFactor(
        code: backup ? null : entered,
        backupCode: backup ? entered : null,
      );
    } catch (error) {
      final failure = SecondFactorFailure.of(error);
      // Turned off meanwhile: nothing to step up, the request goes as it is.
      if (failure.code == 'second_factor_not_enabled') return;
      if (!mounted) rethrow;
      throw RaftUserError(switch (failure.code) {
        'second_factor_code_invalid' =>
          backup ? "That backup code didn't work. Check it and try again." : "That code didn't work. Check the time on your phone is set automatically, then try the newest code.",
        'backup_code_used' => 'That backup code was already used. Each code works once, so try another one.',
        'second_factor_locked' => raftFormat(
          context,
          'Too many wrong codes. Try again after {time}.',
          {
            'time': failure.lockedUntil == null
                ? ''
                : _clock(failure.lockedUntil!),
          },
        ),
        'second_factor_unavailable' =>
          "Two-step verification isn't available right now. Try again later.",
        'session_family_required' =>
          "This sign-in can't be verified. Sign in again, then try once more.",
        _ => 'Something went wrong',
      });
    }
  }

  /// Web `formatClock` with the account's time preferences.
  String _clock(DateTime value) {
    final user = widget.client.user;
    return SourceTimeFormatter(
      locale: Localizations.localeOf(context).toLanguageTag(),
      preferredTimezone:
          user?.string('preferredTimezone') ?? user?.string('timezone'),
      preferredTimeFormat: sourceTimeFormatPreference(
        user?.string('preferredTimeFormat') ?? user?.string('timeFormat'),
      ),
      systemTimeFormat: MediaQuery.alwaysUse24HourFormatOf(context)
          ? SourceTimeFormat.twentyFourHour
          : null,
    ).clock(value);
  }

  @override
  Widget build(BuildContext context) {
    final current = method;
    final others = [
      for (final other in widget.methods.methods)
        if (other != current) other,
    ];
    return RaftFormDialog(
      title: "Verify it's you",
      description: widget.reason.description,
      submitLabel: 'Verify',
      submitEnabled: current != null,
      fields: [
        if (current != null)
          RaftFormField(
            current.wire,
            current == SecondFactorMethod.backupCode
                ? 'Backup code'
                : 'Authenticator code',
            required: true,
          ),
      ],
      extra: current == null && others.isEmpty
          ? RaftBanner(
              status: RaftBannerRecipeStatus.warning,
              description: raftText(
                context,
                "This browser can't use passkeys. Use another way, or open Raft in a browser that has your passkey.",
              ),
            )
          : others.isEmpty
          ? null
          : Wrap(
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
                    onTap: () => setState(() => method = other),
                  ),
              ],
            ),
      onSubmit: answer,
    );
  }
}
