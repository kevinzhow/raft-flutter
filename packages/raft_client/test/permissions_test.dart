import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

void main() {
  test('server role grants match the pinned closed matrix', () {
    expect(raftServerCapabilities, hasLength(41));
    for (final capability in raftServerCapabilities) {
      expect(raftCan('owner', capability), isTrue);
      expect(raftCan('admin', capability), capability != 'manageBilling');
      // A guest holds nothing server-wide except reading channels, which the
      // server (not this matrix) authorizes per channel.
      expect(raftCan('guest', capability), capability == 'viewChannel');
      expect(raftCan(null, capability), isFalse);
      expect(raftCan('unexpected', capability), isFalse);
    }
    expect(
      raftServerCapabilities.where((c) => raftCan('member', c)),
      hasLength(11),
    );
    expect(raftCan('owner', 'inventedPermission'), isFalse);
  });
  test('a guest may read channels but never act on them', () {
    expect(raftCan('guest', 'viewChannel'), isTrue);
    expect(
      raftCan(
        'guest',
        'viewChannel',
        channelCapabilities: {'viewChannel': false},
      ),
      isTrue,
    );
    for (final capability in raftServerCapabilities.where(
      (c) => c != 'viewChannel',
    )) {
      expect(raftCan('guest', capability), isFalse, reason: capability);
    }
    // Other non-member states still read nothing.
    expect(raftCan(null, 'viewChannel'), isFalse);
    expect(raftCan('unexpected', 'viewChannel'), isFalse);
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
