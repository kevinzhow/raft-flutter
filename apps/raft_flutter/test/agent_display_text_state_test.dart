// Web utils/activity.ts formatAgentDisplayStateText (v1.24): the plain status
// text of lists (members, followers, DM header) says what a held agent says:
// the Computer blockers, "Likely online", "Paused", and a coded error's title.
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_metadata_projection.dart';

Map<String, dynamic> _row({
  String status = 'active',
  Map<String, dynamic> extra = const {},
}) => {'id': 'a1', 'status': status, ...extra};

String _text(Map<String, dynamic> row, {Map? live}) =>
    agentDisplayText(agentRowAmbientDisplay(row, live: live));

void main() {
  test('a server blocker reads as its words, whatever the activity was', () {
    expect(
      _text(
        _row(
          extra: {
            'blockedReason': 'computer_version_unsupported',
            'activityKind': 'working',
          },
        ),
      ),
      'Computer update required',
    );
    expect(
      _text(_row(extra: {'blockedReason': 'computer_access_revoked'})),
      startsWith('Computer access revoked'),
    );
  });

  test('an active agent with no activity state yet is likely online', () {
    expect(_text(_row()), 'Likely online');
    expect(
      _text(_row(extra: {'activityKind': 'thinking'})),
      isNot('Likely online'),
    );
    expect(_text(_row(status: 'stopped')), isNot('Likely online'));
  });

  test('a paused assistant reads Paused; an external agent is never held', () {
    expect(
      _text(_row(extra: {'assistantPausedAt': '2026-01-01T00:00:00Z'})),
      'Paused',
    );
    expect(
      _text(
        _row(
          extra: {'external': true, 'blockedReason': 'computer_access_revoked'},
        ),
      ),
      isNot(startsWith('Computer access')),
    );
  });

  test('a coded error reads as its title, an uncoded one as before', () {
    final coded = _text(
      _row(
        extra: {
          'activityKind': 'error',
          'activityDetail': 'raw server words',
          'activityErrorCode': 'usage_limit',
        },
      ),
    );
    expect(coded, isNot(contains('raw server words')));
    expect(
      _text(
        _row(
          extra: {
            'activityKind': 'error',
            'activityDetail': 'raw server words',
          },
        ),
      ),
      'Error: raw server words',
    );
  });
}
