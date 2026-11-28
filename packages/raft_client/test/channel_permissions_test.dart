import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

void main() {
  const all = {
    'editChannelMetadata',
    'archiveChannels',
    'deleteChannels',
    'changeChannelVisibility',
    'manageVisitorAccess',
    'federateChannels',
    'addChannelMembers',
    'removeChannelMembers',
    'changeChannelMemberRoles',
  };
  const add = {'addChannelMembers'};
  const local = {
    ...add,
    'editChannelMetadata',
    'archiveChannels',
    'removeChannelMembers',
    'changeChannelMemberRoles',
  };
  const host = {...local, 'federateChannels'};
  const jointManager = {
    ...add,
    'editChannelMetadata',
    'archiveChannels',
    'removeChannelMembers',
  };
  const disconnect = {...add, 'deleteChannels'};
  const none = <String>{};
  const denied = [none, none, none];
  const inherited = [
    [all, all, all],
    [add, all, all],
    [none, host, host],
    [none, disconnect, disconnect],
    denied,
  ];
  const kinds = ['channel', 'private', 'joint', 'joint', 'dm'];
  const matrix = {
    'owner': inherited,
    'admin': inherited,
    'member': [
      [none, add, local],
      [none, add, local],
      [none, add, jointManager],
      [none, add, add],
      denied,
    ],
    'guest': [denied, denied, denied, denied, denied],
    'visitor': [denied, denied, denied, denied, denied],
  };

  test('channelPermissions.ts respects projected authority for every role', () {
    for (final row in matrix.entries) {
      for (final (channel, states) in row.value.indexed) {
        for (final (membership, grants) in states.indexed) {
          final projection = {
            for (final capability in all)
              capability: grants.contains(capability),
          };
          for (final capability in all) {
            expect(
              raftCan(
                row.key,
                capability,
                channelCapabilities: projection,
                channelType: kinds[channel],
              ),
              grants.contains(capability),
              reason: '${row.key} / $channel / $membership / $capability',
            );
          }
        }
      }
    }
  });

  test('a joint or DM row without a projection confers no management', () {
    for (final type in ['joint', 'dm']) {
      for (final capability in all) {
        expect(raftCan('owner', capability, channelType: type), isFalse);
      }
    }
  });

  test('conversation admission is independent of server management', () {
    const admitted = ['owner', 'admin', 'member', 'guest'];
    for (final role in [...admitted, 'visitor', null, 'unknown']) {
      expect(raftCanReadAdmittedConversation(role), admitted.contains(role));
    }
  });
}
