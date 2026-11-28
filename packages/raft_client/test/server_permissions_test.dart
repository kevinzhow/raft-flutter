import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

void main() {
  const members = {
    'viewServerProfile',
    'createChannels',
    'joinPublicChannels',
    'addChannelMembers',
    'viewMembers',
    'viewAgents',
    'controlAgentRuntime',
    'viewMachines',
    'assignTasks',
  };

  test(
    'serverPermissions.ts separates role grants from channel visibility',
    () {
      expect(raftServerCapabilities, hasLength(41));
      for (final role in [
        'owner',
        'admin',
        'member',
        'guest',
        'visitor',
        null,
      ]) {
        final expected = switch (role) {
          'owner' => raftServerCapabilities,
          'admin' => raftServerCapabilities.difference({
            'manageBilling',
            'manageSso',
          }),
          'member' => members,
          _ => <String>{},
        };
        expect(
          raftServerCapabilities.where((cap) => raftCan(role, cap)).toSet(),
          expected,
          reason: '$role',
        );
        for (final obsolete in [
          'viewChannel',
          'viewChannelMembers',
          'manageGuestAccess',
        ]) {
          expect(raftCan(role, obsolete), isFalse, reason: '$role / $obsolete');
        }
      }
      expect(raftCan('owner', 'inventedPermission'), isFalse);
      expect(
        raftServerCapabilities,
        containsAll(['manageVisitorAccess', 'manageSso']),
      );
    },
  );
}
