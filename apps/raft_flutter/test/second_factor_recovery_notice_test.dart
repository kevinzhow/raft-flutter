// Web v1.24.0 useSecondFactorRecoveryNotification: a pending reset of
// two-step verification is the notification center's first entry, it can't
// be dismissed, and it goes once the reset does (cancelled here or
// elsewhere); a failed read keeps what is shown.
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/data/second_factor_recovery_notice.dart';
import 'package:raft_flutter/data/system_notification_projection.dart';
import 'package:raft_flutter/data/system_notification_store.dart';

class _Storage implements SearchMemoryStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

SystemNotificationContext _context() => const SystemNotificationContext(
  scope: 'scope-1',
  origin: 'https://public.invalid',
  principal: 'alice',
  server: {'id': 'srv-1', 'role': 'member'},
  channels: [],
  canViewMachines: false,
  canViewAgents: false,
  mobile: true,
);

Map<String, Object?> _view(String status) => {
  'status': status,
  'requestedAt': '2026-11-10T00:00:00.000Z',
  'eligibleAt': '2026-11-13T00:00:00.000Z',
  'expiresAt': '2026-11-20T00:00:00.000Z',
  'firstFactorRequired': null,
};

Future<void> _settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('a pending reset is the first entry and goes when it does', () async {
    Object? recovery = {'recovery': _view('waiting')};
    var fail = false;
    final store = SystemNotificationStore(
      storage: _Storage(),
      get: (path, {query}) async {
        if (path == '/auth/second-factor/recovery') {
          if (fail) throw const RaftApiException('offline');
          return recovery;
        }
        if (path.endsWith('/joint-invites')) return [];
        return {'unread_total': 2};
      },
    );
    addTearDown(store.dispose);
    await store.bind(_context());
    await _settle();
    final first = store.entries.first;
    expect(first.id, secondFactorRecoveryNoticeId);
    expect(first.title, 'Reset requested');
    expect(first.destination, SystemNoticeDestination.secondFactorRecovery);
    // No Dismiss: it has no fingerprint and no incident.
    expect(first.fingerprint, isNull);
    expect(first.incidentId, isNull);

    recovery = {'recovery': _view('ready')};
    await store.refreshSecondFactorRecovery();
    await _settle();
    expect(store.entries.first.title, 'Reset ready');

    // Not reachable: keep what is shown.
    fail = true;
    await store.refreshSecondFactorRecovery();
    await _settle();
    expect(store.entries.first.id, secondFactorRecoveryNoticeId);

    // Cancelled here: gone at once; finished elsewhere: gone at the next read.
    store.secondFactorRecoveryCancelled('scope-1');
    expect(
      store.entries.where((n) => n.id == secondFactorRecoveryNoticeId),
      isEmpty,
    );
    fail = false;
    recovery = {'recovery': null};
    await store.refreshSecondFactorRecovery();
    await _settle();
    expect(
      store.entries.where((n) => n.id == secondFactorRecoveryNoticeId),
      isEmpty,
    );
  });
}
