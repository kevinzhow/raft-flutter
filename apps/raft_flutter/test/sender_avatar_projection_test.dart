import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/sender_avatar_projection.dart';

void main() {
  SenderAvatarProjection project({
    String id = 'person',
    String type = 'user',
    List<Map<String, dynamic>> agents = const [],
    List<Map<String, dynamic>> members = const [],
    Map<String, dynamic>? user,
    Map<String, dynamic>? external,
  }) => projectSenderAvatar(
    origin: 'https://active.invalid',
    senderId: id,
    senderType: type,
    agents: agents,
    members: members,
    currentUser: user,
    externalAuthor: external,
  );
  test('uploaded human discovery uses identity, not duplicate display name or provider default', () {
    final hash = 'a' * 64;
    final value = project(
      members: [
        {
          'userId': 'wrong',
          'name': 'Same',
          'avatarUrl': '/api/avatars/users/b.webp',
        },
        {
          'userId': 'person',
          'name': 'Same',
          'avatarUrl': '/api/avatars/users/c.webp',
          'gravatarHash': hash,
        },
      ],
    );
    expect(
      value.uploadedUrl,
      'https://active.invalid/api/avatars/users/c.webp',
    );
    expect(Uri.parse(value.gravatarUrl!).host, 'www.gravatar.com');
    expect(Uri.parse(value.gravatarUrl!).queryParameters, {
      's': '80',
      'd': '404',
    });
    final legacyProvider = project(
      members: [
        {
          'userId': 'person',
          'avatarUrl': 'https://provider.invalid/default.png',
          'gravatarHash': hash,
        },
      ],
    );
    expect(legacyProvider.uploadedUrl, isNull);
    expect(legacyProvider.gravatarUrl, isNotNull);
  });
  test('only own email may derive a fallback hash, no display-name or other-user email lookup', () {
    final own = project(
      user: {'id': 'person', 'email': ' Alice@Example.Invalid '},
    );
    expect(own.gravatarUrl, isNotNull);
    expect(
      project(user: {'id': 'other', 'email': 'Alice@Example.Invalid'})
          .gravatarUrl,
      isNull,
    );
    expect(
      project(
        members: [
          {'userId': 'person', 'email': 'Alice@Example.Invalid'},
        ],
      ).gravatarUrl,
      isNull,
    );
    expect(
      project(
        members: [
          {'userId': 'person', 'gravatarHash': 'invalid/hash'},
        ],
      ).gravatarUrl,
      isNull,
    );
  });
  test(
    'agent pixel/custom and external app avatar stay explicit and public',
    () {
      expect(
        project(
          id: 'agent',
          type: 'agent',
          agents: [
            {'id': 'agent', 'avatarUrl': 'pixel:random:public-seed'},
          ],
        ).pixelKey,
        'random:public-seed',
      );
      final custom = project(
        id: 'agent',
        type: 'agent',
        agents: [
          {'id': 'agent', 'avatarUrl': '/api/avatars/agent/c.webp'},
        ],
      );
      expect(
        custom.uploadedUrl,
        'https://active.invalid/api/avatars/agent/c.webp',
      );
      expect(custom.gravatarUrl, isNull);
      expect(
        project(
          type: 'external_projection',
          external: {'avatarUrl': 'https://cdn.invalid/avatar.webp'},
        ).kind,
        'app',
      );
      expect(
        project(
          type: 'external_projection',
          external: {
            'avatarUrl': 'https://credentials@cdn.invalid/avatar.webp',
          },
        ).uploadedUrl,
        isNull,
      );
      expect(project().uploadedUrl, isNull);
      expect(project(type: 'agent').pixelKey, isNull);
    },
  );
}
