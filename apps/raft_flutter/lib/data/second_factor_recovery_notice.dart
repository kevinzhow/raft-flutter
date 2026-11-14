// Web v1.24.0 useSecondFactorRecoveryNotification: "Reset requested" /
// "Reset ready" as the notification center's first entry in every signed-in
// session while a request to reset two-step verification by email waits.
// It can't be dismissed: it goes only when the request does (cancelled,
// finished, auto-cancelled, lapsed). Cancel reset ends it in one step.
import 'package:raft_client/raft_client.dart';

import 'system_notification_projection.dart';

const secondFactorRecoveryNoticeId = 'second-factor-recovery';

/// `GET /auth/second-factor/recovery` read for the center; null when there is
/// no request or it can't be read (a 404 while the feature is off).
SecondFactorRecovery? parseSecondFactorRecoveryRead(Object? data) =>
    SecondFactorRecovery.parse(data is Map ? data['recovery'] : null);

/// The center's entry for [recovery]; the copy is made at display time with
/// the account's time preferences.
SystemNotice? secondFactorRecoveryNotice(SecondFactorRecovery? recovery) =>
    recovery == null
    ? null
    : SystemNotice(
        id: secondFactorRecoveryNoticeId,
        kind: SystemNoticeKind.warning,
        title: recovery.ready ? 'Reset ready' : 'Reset requested',
        body: '',
        destination: SystemNoticeDestination.secondFactorRecovery,
        parameters: {
          'ready': recovery.ready,
          'eligibleAt': recovery.eligibleAt.toIso8601String(),
          'expiresAt': recovery.expiresAt.toIso8601String(),
          'setPasswordFirst': recovery.setPasswordFirst,
        },
      );
