import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/sender_avatar_projection.dart';

const _expected =
    'https://www.gravatar.com/avatar/a524b05cedcd99954a521487868165449c74dd0878dd304570b0c5c1e4fe889f?s=16&d=404';

void main() {
  test(
    'Tasks empty member hash uses email; default path retains no lookup',
    () {
      const members = [
        {
          'userId': 'designer',
          'gravatarHash': '',
          'email': ' Designer@Example.Invalid ',
        },
      ];
      final original = projectSenderAvatar(
        origin: 'https://task-fixture.invalid',
        senderId: 'designer',
        senderType: 'user',
        agents: const [],
        members: members,
        requestSize: 16,
      );
      expect(original.gravatarUrl, isNull);
      final task = projectSenderAvatar(
        origin: 'https://task-fixture.invalid',
        senderId: 'designer',
        senderType: 'user',
        agents: const [],
        members: members,
        requestSize: 16,
        allowMemberEmailFallback: true,
      );
      expect(task.gravatarUrl, _expected);
    },
  );

  test(
    'Tasks empty self hash is normalized after the current-user overlay only',
    () {
      const user = {
        'id': 'self',
        'gravatarHash': '',
        'email': ' Designer@Example.Invalid ',
      };
      final original = projectSenderAvatar(
        origin: 'https://task-fixture.invalid',
        senderId: 'self',
        senderType: 'user',
        agents: const [],
        members: const [],
        currentUser: user,
        requestSize: 16,
      );
      expect(original.gravatarUrl, isNull);
      final task = projectSenderAvatar(
        origin: 'https://task-fixture.invalid',
        senderId: 'self',
        senderType: 'user',
        agents: const [],
        members: const [],
        currentUser: user,
        requestSize: 16,
        allowMemberEmailFallback: true,
      );
      expect(task.gravatarUrl, _expected);
    },
  );

  test(
    'Tasks preserves truthy nonempty hash semantics rather than trimming it',
    () {
      final task = projectSenderAvatar(
        origin: 'https://task-fixture.invalid',
        senderId: 'designer',
        senderType: 'user',
        agents: const [],
        members: const [
          {
            'userId': 'designer',
            'gravatarHash': ' ',
            'email': 'designer@example.invalid',
          },
        ],
        allowMemberEmailFallback: true,
      );
      expect(task.gravatarUrl, isNull);
    },
  );
}
