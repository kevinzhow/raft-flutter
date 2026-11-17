import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/sender_avatar_projection.dart';
import 'package:raft_ui/raft_ui.dart';

/// A person's built avatar (`pixel-human:v1:...`) is drawn wherever a person's
/// avatar is (Web PersonAvatar / AvatarSlot humanAvatarUrl), in the frame, on
/// the first frame; anything else stays the User placeholder.
void main() {
  const built = 'pixel-human:v1:sky.3.curly.brown.grin.headphones.glasses';

  SenderAvatarProjection project({
    List<Map<String, dynamic>> members = const [],
    Map<String, dynamic>? user,
  }) => projectSenderAvatar(
    origin: 'https://active.invalid',
    senderId: 'person',
    senderType: 'user',
    agents: const [],
    members: members,
    currentUser: user,
  );

  test('the source follows Web isHumanAvatarUrl, not just a prefix', () {
    expect(raftHumanAvatarSource(built), RaftHumanAvatarSource.pixel);
    expect(
      raftHumanAvatarSource(
        'pixel-human:v1:sky.3.curly.brown.grin.cap.none/auto',
      ),
      RaftHumanAvatarSource.pixel,
    );
    // Another version draws the default avatar, as Web does.
    expect(
      raftHumanAvatarSource('pixel-human:v9:anything'),
      RaftHumanAvatarSource.pixel,
    );
    // Outside the recipe alphabet, or too long to be one: placeholder.
    expect(
      raftHumanAvatarSource('pixel-human:v1:eyes=round'),
      RaftHumanAvatarSource.placeholder,
    );
    expect(
      raftHumanAvatarSource('pixel-human:v1:${'a' * 200}'),
      RaftHumanAvatarSource.placeholder,
    );
    expect(
      raftHumanAvatarSource('pixel:robot'),
      RaftHumanAvatarSource.placeholder,
    );
  });

  test(
    'a person projects their built avatar, an uploaded one stays an upload',
    () {
      final member = project(
        members: [
          {'userId': 'person', 'avatarUrl': built},
        ],
      );
      expect(member.pixelKey, built);
      expect(member.uploadedUrl, isNull);
      final own = project(user: {'id': 'person', 'avatarUrl': built});
      expect(own.pixelKey, built);
      final uploaded = project(
        members: [
          {'userId': 'person', 'avatarUrl': '/api/avatars/users/a1.webp'},
        ],
      );
      expect(uploaded.pixelKey, isNull);
      expect(
        uploaded.uploadedUrl,
        'https://active.invalid/api/avatars/users/a1.webp',
      );
      final other = project(
        members: [
          {'userId': 'person', 'avatarUrl': 'https://x.invalid/a.png'},
        ],
      );
      expect(other.pixelKey, isNull);
      expect(other.uploadedUrl, isNull);
    },
  );

  Widget host(Widget child) => MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox.square(dimension: 36, child: child)),
    ),
  );

  testWidgets('RaftAvatarContent draws the built avatar on the first frame', (
    t,
  ) async {
    await t.pumpWidget(
      host(const RaftAvatarContent(name: 'Ada', pixelKey: built)),
    );
    expect(find.byType(RaftHumanPixelAvatar), findsOneWidget);
    expect(find.byType(RaftIcon), findsNothing);
  });

  testWidgets('without a built avatar the User placeholder stays', (t) async {
    for (final value in [null, 'pixel:robot', 'pixel-human:v1:eyes=round']) {
      await t.pumpWidget(host(RaftAvatarContent(name: 'Ada', pixelKey: value)));
      expect(find.byType(RaftHumanPixelAvatar), findsNothing, reason: '$value');
      expect(find.byType(RaftIcon), findsOneWidget, reason: '$value');
    }
  });

  testWidgets('an agent never draws a person recipe', (t) async {
    await t.pumpWidget(
      host(
        const RaftAvatarContent(
          name: 'Bot',
          kind: RaftAvatarContentKind.agent,
          pixelKey: built,
        ),
      ),
    );
    expect(find.byType(RaftHumanPixelAvatar), findsNothing);
  });

  testWidgets('RaftAvatarSlot draws a built avatar for a person', (t) async {
    await t.pumpWidget(
      host(
        const RaftAvatarSlot(
          name: 'Ada',
          agent: false,
          slot: RaftAvatarSlotContext.profileTile,
          avatarUrl: built,
        ),
      ),
    );
    expect(find.byType(RaftHumanPixelAvatar), findsOneWidget);
  });
}
