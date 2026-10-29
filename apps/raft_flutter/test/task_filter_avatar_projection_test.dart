import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/sender_avatar_projection.dart';

void main() {
  test('Tasks alone opts into authorized matching member email fallback', () {
    const member = {
      'userId': 'designer',
      'email': ' Designer@Example.Invalid ',
    };
    SenderAvatarProjection project({
      bool allow = false,
      String id = 'designer',
    }) => projectSenderAvatar(
      origin: 'https://task-fixture.invalid',
      senderId: id,
      senderType: 'user',
      members: const [member],
      agents: const [],
      allowMemberEmailFallback: allow,
      requestSize: 16,
    );
    expect(project().gravatarUrl, isNull);
    expect(
      project(allow: true).gravatarUrl,
      'https://www.gravatar.com/avatar/a524b05cedcd99954a521487868165449c74dd0878dd304570b0c5c1e4fe889f?s=16&d=404',
    );
    expect(project(allow: true, id: 'unrelated').gravatarUrl, isNull);
    expect(project(allow: true).uploadedUrl, isNull);
  });

  test(
    'explicit hash and uploaded-human rules retain precedence and URL safety',
    () {
      final hash = 'b' * 64;
      final members = [
        {
          'userId': 'user',
          'email': 'designer@example.invalid',
          'gravatarHash': hash,
          'avatarUrl': '/api/avatars/users/abcd.webp',
        },
        {
          'userId': 'provider',
          'email': 'designer@example.invalid',
          'avatarUrl': 'https://provider.invalid/default.png',
        },
      ];
      final values = projectTaskFilterAvatars(
        origin: 'https://task-fixture.invalid',
        identityKeys: ['user:user', 'user:provider'],
        agents: const [],
        members: members,
      );
      expect(
        values['user:user']!.uploadedUrl,
        'https://task-fixture.invalid/api/avatars/users/abcd.webp',
      );
      expect(
        Uri.parse(values['user:user']!.gravatarUrl!).path,
        '/avatar/$hash',
      );
      expect(values['user:provider']!.uploadedUrl, isNull);
      expect(values['user:provider']!.gravatarUrl, isNotNull);
    },
  );

  test('typed identity pool preserves agent/human collision and pixel/custom content', () {
    final values = projectTaskFilterAvatars(
      origin: 'https://task-fixture.invalid',
      identityKeys: [
        'user:same',
        'agent:same',
        'agent:custom',
        'unassigned',
        'channel:c',
      ],
      members: const [
        {'userId': 'same', 'email': 'designer@example.invalid'},
      ],
      agents: const [
        {'id': 'same', 'avatarUrl': 'pixel:random:stable'},
        {'id': 'custom', 'avatarUrl': '/api/avatars/agents/abcd.webp'},
      ],
    );
    expect(values.keys, ['user:same', 'agent:same', 'agent:custom']);
    expect(values['user:same']!.kind, 'human');
    expect(values['agent:same']!.kind, 'agent');
    expect(values['agent:same']!.pixelKey, 'random:stable');
    expect(
      values['agent:custom']!.uploadedUrl,
      'https://task-fixture.invalid/api/avatars/agents/abcd.webp',
    );
    expect(values['agent:custom']!.gravatarUrl, isNull);
  });

  test('opting into member emails never looks up a different current user', () {
    final value = projectSenderAvatar(
      origin: 'https://task-fixture.invalid',
      senderId: 'missing',
      senderType: 'user',
      members: const [],
      agents: const [],
      allowMemberEmailFallback: true,
      currentUser: const {
        'id': 'self',
        'email': 'private-current@example.invalid',
      },
    );
    expect(value.gravatarUrl, isNull);
  });
}
