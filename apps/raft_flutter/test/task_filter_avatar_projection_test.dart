import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/sender_avatar_projection.dart';

void main() {
  test('a Tasks member email draws no image (Gravatar retired in v1.24)', () {
    final values = projectTaskFilterAvatars(
      origin: 'https://task-fixture.invalid',
      identityKeys: ['user:designer'],
      agents: const [],
      members: const [
        {'userId': 'designer', 'email': ' Designer@Example.Invalid '},
      ],
    );
    expect(values['user:designer']!.kind, 'human');
    expect(values['user:designer']!.uploadedUrl, isNull);
    expect(values['user:designer']!.pixelKey, isNull);
  });

  test('uploaded-human rules hold whatever gravatar hash a row carries', () {
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
    expect(values['user:provider']!.uploadedUrl, isNull);
  });

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
  });

  test('a different current user is never looked up', () {
    final value = projectSenderAvatar(
      origin: 'https://task-fixture.invalid',
      senderId: 'missing',
      senderType: 'user',
      members: const [],
      agents: const [],
      currentUser: const {
        'id': 'self',
        'avatarUrl': '/api/avatars/users/abcd.webp',
      },
    );
    expect(value.uploadedUrl, isNull);
  });
}
