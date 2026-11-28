import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

void main() {
  test(
    'taskPermissions.ts gates writes through the admitted parent channel',
    () {
      const channelTypes = [
        (type: 'channel', jointRole: null),
        (type: 'private', jointRole: null),
        (type: 'joint', jointRole: 'host'),
        (type: 'joint', jointRole: 'participant'),
        (type: 'dm', jointRole: null),
      ];
      for (final role in ['owner', 'admin', 'member', 'guest', 'visitor']) {
        for (final (index, kind) in channelTypes.indexed) {
          for (final membership in [null, 'member', 'admin']) {
            if (kind.type == 'dm' && membership == null) continue;
            for (final blocked in [
              null,
              'archivedAt',
              'deletedAt',
              'canPost',
            ]) {
              final resource = RaftChannel({
                'id': 'c1',
                'name': 'project',
                'type': kind.type,
                'jointRole': kind.jointRole,
                'joined': membership != null,
                'channelRole': membership,
                if (blocked != null) blocked: false,
              });
              final expected =
                  membership != null &&
                  role != 'visitor' &&
                  (role != 'guest' || index < 3) &&
                  blocked == null;
              final canWrite = raftCanWriteTaskChannel(role, resource);
              expect(
                canWrite,
                expected,
                reason: '$role / $kind / $membership / $blocked',
              );
              expect(
                raftAuthorizeTaskWrite(
                  canWriteChannel: canWrite,
                  readOnlyReason: null,
                ),
                expected,
              );
              expect(
                raftAuthorizeTaskWrite(
                  canWriteChannel: canWrite,
                  readOnlyReason: 'historical_joint_task',
                ),
                isFalse,
              );
            }
          }
        }
      }
    },
  );
}
