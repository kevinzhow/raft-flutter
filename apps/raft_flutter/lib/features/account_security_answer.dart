// Web v1.24.0 components/settings/secondFactorAnswer.ts: the failure wording
// every second-step and re-verification dialog shares (Two-step
// verification, Passkeys, "Verify it's you").
import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/source_time_formatter.dart';

/// What the person answered with.
enum SecondFactorAnswerKind { totp, backupCode, password }

/// Web `useFailureCopy` placement: a wrong or used code or a wrong password
/// goes under the field, anything else in a banner.
bool secondFactorFailureUnderField(Object error) => const {
  'second_factor_code_invalid',
  'backup_code_used',
  'password_incorrect',
}.contains(SecondFactorFailure.of(error).code);

/// A failed call's text for [kind] (Web `useFailureCopy`), already localized;
/// where it goes: [secondFactorFailureUnderField].
String secondFactorFailureText(
  BuildContext context,
  RaftClient client,
  Object error,
  SecondFactorAnswerKind kind,
) {
  final failure = SecondFactorFailure.of(error);
  String tr(String s) => raftText(context, s);
  String locked(String template) => raftFormat(context, template, {
    'time': failure.lockedUntil == null
        ? ''
        : secondFactorClock(context, client, failure.lockedUntil!),
  });
  return switch (failure.code) {
    'second_factor_code_invalid' => tr(
      kind == SecondFactorAnswerKind.backupCode
          ? "That backup code didn't work. Check it and try again."
          : "That code didn't work. Check the time on your phone is set automatically, then try the newest code.",
    ),
    'passkeys_unavailable' => tr(
      "Passkeys aren't available right now. Try again later.",
    ),
    'backup_code_used' => tr(
      'That backup code was already used. Each code works once, so try another one.',
    ),
    'password_incorrect' => tr('That password is incorrect. Try again.'),
    'second_factor_locked' => locked(
      'Too many wrong codes. Try again after {time}.',
    ),
    'reauth_locked' => locked(
      'Too many wrong passwords. Try again after {time}.',
    ),
    'totp_setup_required' => tr(
      'This setup has expired. Close this and turn it on again.',
    ),
    'second_factor_unavailable' => tr(
      "Two-step verification isn't available right now. Try again later.",
    ),
    'session_family_required' => tr(
      'Sign in again to manage two-step verification.',
    ),
    _ => tr('Something went wrong'),
  };
}

/// Web `formatClock` with the account's time preferences.
String secondFactorClock(
  BuildContext context,
  RaftClient client,
  DateTime value,
) => _formatter(context, client).clock(value);

/// Web `formatMediumDateTime` with the account's time preferences.
String secondFactorDateTime(
  BuildContext context,
  RaftClient client,
  DateTime value,
) => _formatter(context, client).mediumDateTime(value);

/// Web `formatCompactDate`: the clock today, "Jun 10" this year, else
/// "2025-06-10".
String secondFactorCompactDate(
  BuildContext context,
  RaftClient client,
  DateTime value,
) {
  final f = _formatter(context, client);
  final day = f.dayKey(value), today = f.dayKey(sourceTimeNow());
  if (day == today) return f.clock(value);
  if (day.substring(0, 4) == today.substring(0, 4)) return f.shortDate(value);
  return day;
}

SourceTimeFormatter _formatter(BuildContext context, RaftClient client) {
  final user = client.user;
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
  );
}
