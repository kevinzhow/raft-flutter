import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'support/channel_footer_inset_fixture.dart';

const _windows = [
  (Size(856, 944), TargetPlatform.android, 32.0),
  (Size(944, 856), TargetPlatform.android, 32.0),
  (Size(390, 844), TargetPlatform.linux, 0.0),
];

const _themes = [
  (raftLookRaft, raftThemePackId, false),
  (raftLookRaft, raftThemePackId, true),
  (raftLookElegant, elegantThemePackId, false),
  (raftLookElegant, elegantThemePackId, true),
  (raftLookBrutal, brutalThemePackId, false),
];

Finder get _join => find.descendant(
  of: find.byType(RaftChannelJoinFooter),
  matching: find.byType(RaftRecipeButton),
);

void main() {
  for (final (look, pack, dark) in raftThemeMatrix(
    _themes,
    look: (theme) => theme.$1,
    dark: (theme) => theme.$3,
  )) {
    for (final (size, platform, inset) in _windows) {
      for (final thread in [false, true]) {
        testWidgets(
          '$look/$dark ${size.width}x${size.height} '
          '${thread ? 'thread' : 'workspace'} Join clears the system bar then becomes a composer',
          (t) async {
            final f = await FooterInsetFixture.mount(
              t,
              size: size,
              platform: platform,
              inset: inset,
              pack: pack,
              dark: dark,
              thread: thread,
            );
            expect(find.byType(RaftChatView), findsOneWidget);
            expect(_join, findsOneWidget);
            expect(find.byType(RaftComposer), findsNothing);
            expect(
              RaftInteraction.of(t.element(find.byType(RaftChatView))).touch,
              platform == TargetPlatform.android,
            );
            final footer = t.getRect(find.byType(RaftChannelJoinFooter));
            expect(footer.bottom, closeTo(size.height, .01));
            final button = t.getRect(_join);
            expect(
              button.bottom,
              closeTo(size.height - inset - 12, .01),
              reason:
                  'The Web p-3 footer gap must sit above the system bar once.',
            );
            expect(_join.hitTestable(), findsOneWidget);
            await t.tap(_join);
            await t.pumpAndSettle();
            expect(f.client.joinRequests, 1);
            expect(f.workspace.channels.single.joined, isTrue);
            expect(find.byType(RaftChannelJoinFooter), findsNothing);
            expect(find.byType(RaftComposer), findsOneWidget);
            final shell = find.byKey(const ValueKey('composer-shell-slot'));
            final rest = t.getRect(shell);
            expect(rest.bottom, lessThanOrEqualTo(size.height - inset));
            if (platform == TargetPlatform.android) {
              t.view
                ..viewInsets = const FakeViewPadding(bottom: 300)
                ..padding = FakeViewPadding.zero;
              await t.pumpAndSettle();
              final host = find.byKey(const ValueKey('composer-host-slot'));
              expect(t.getRect(host).bottom, closeTo(size.height - 300, .01));
              expect(
                t.getRect(shell).bottom,
                lessThanOrEqualTo(size.height - 300),
                reason: 'The IME replaces the navigation inset, not adds it.',
              );
              t.view
                ..viewInsets = FakeViewPadding.zero
                ..padding = FakeViewPadding(bottom: inset);
              await t.pumpAndSettle();
              expect(t.getRect(shell), rest);
            }
            expect(t.takeException(), isNull);
          },
        );
      }
    }

    for (final (state, message) in [
      (
        FooterState.guest,
        'Guest access is read-only. You can read and follow updates, but you cannot post or react.',
      ),
      (FooterState.archived, 'This channel is archived.'),
      (
        FooterState.jointLocked,
        'This Joint Channel is read-only because it has more than 2 free servers. It becomes writable again when one server\'s admin upgrades or a free server leaves.',
      ),
    ]) {
      testWidgets('$look/$dark mounted $state notice clears the system bar', (
        t,
      ) async {
        const size = Size(856, 944);
        const inset = 32.0;
        await FooterInsetFixture.mount(
          t,
          size: size,
          platform: TargetPlatform.android,
          inset: inset,
          pack: pack,
          dark: dark,
          state: state,
          workspace: false,
        );
        final notice = find.text(message, findRichText: true);
        expect(notice, findsOneWidget);
        expect(find.byType(RaftComposer), findsNothing);
        expect(
          t.getRect(notice).bottom,
          lessThanOrEqualTo(size.height - inset),
          reason: 'Read-only content must remain outside the system bar too.',
        );
        expect(t.takeException(), isNull);
      });
    }
  }
}
