import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

void main() {
  test('server role grants match the pinned closed matrix', () {
    expect(raftServerCapabilities, hasLength(41));
    for (final capability in raftServerCapabilities) {
      expect(raftCan('owner', capability), isTrue);
      expect(raftCan('admin', capability), capability != 'manageBilling');
      expect(raftCan('guest', capability), isFalse);
      expect(raftCan(null, capability), isFalse);
      expect(raftCan('unexpected', capability), isFalse);
    }
    expect(
      raftServerCapabilities.where((c) => raftCan('member', c)),
      hasLength(11),
    );
    expect(raftCan('owner', 'inventedPermission'), isFalse);
  });
  test(
    'channel authority overrides management but preserves server read grants',
    () {
      expect(
        raftCan(
          'owner',
          'deleteChannels',
          channelCapabilities: {'deleteChannels': false},
        ),
        isFalse,
      );
      expect(
        raftCan(
          'member',
          'editChannelMetadata',
          channelCapabilities: {'editChannelMetadata': true},
        ),
        isTrue,
      );
      expect(
        raftCan('owner', 'deleteChannels', channelCapabilities: {}),
        isFalse,
      );
      expect(
        raftCan(
          'member',
          'viewChannelMembers',
          channelCapabilities: {'addChannelMembers': false},
        ),
        isTrue,
      );
      expect(
        raftCan('guest', 'viewChannelMembers', channelCapabilities: {}),
        isFalse,
      );
      expect(raftCan('member', 'archiveChannels'), isFalse);
    },
  );
}
