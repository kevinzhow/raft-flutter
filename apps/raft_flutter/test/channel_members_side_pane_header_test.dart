import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/channel_side_drag.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/close_support.dart' show mountWorkspace, frames;

// Members opened from channel Details replaces the Details head with its own
// (Kevin: one header at every width, as on a phone). The side card's drag grip
// moves to whichever head is showing.
void main() {
  Finder key(String value) => find.byKey(ValueKey(value));
  final detailsHead = find.text('Details');
  final detailsControls = find.byWidgetPredicate(
    (w) =>
        w.key == const ValueKey('channel-overflow-back') ||
        w.key == const ValueKey('channel-details-close'),
  );
  bool gripped(Finder head) => find
      .ancestor(of: head, matching: find.byType(ChannelSideHead))
      .evaluate()
      .isNotEmpty;

  for (final scenario in [
    (size: const Size(390, 844), platform: TargetPlatform.linux),
    (size: const Size(856, 944), platform: TargetPlatform.android),
    (size: const Size(944, 856), platform: TargetPlatform.android),
    (size: const Size(1024, 768), platform: TargetPlatform.linux),
    (size: const Size(1280, 900), platform: TargetPlatform.linux),
    (size: const Size(1600, 1000), platform: TargetPlatform.linux),
  ]) {
    testWidgets('members from details shows one header at ${scenario.size} / '
        '${scenario.platform.name}', (t) async {
      await mountWorkspace(t, scenario.size, platform: scenario.platform);
      await t.tap(find.byKey(const Key('channel-overflow-trigger')));
      await frames(t, 25);
      expect(detailsHead, findsOneWidget);
      expect(detailsControls, findsOneWidget);
      final detailsGripped = gripped(detailsHead);

      final entry = key('channel-overflow-members-entry');
      await t.ensureVisible(entry);
      await frames(t, 5);
      await t.tap(entry);
      await frames(t, 25);
      expect(key('member-page'), findsOneWidget);
      expect(key('member-page-back'), findsOneWidget);
      expect(detailsHead, findsNothing, reason: 'Details head above Members');
      expect(detailsControls, findsNothing);
      expect(gripped(key('member-page-back')), detailsGripped);

      await t.tap(key('member-page-back'));
      await frames(t, 25);
      expect(key('member-page'), findsNothing);
      expect(detailsHead, findsOneWidget);
      expect(detailsControls, findsOneWidget);
      expect(gripped(detailsHead), detailsGripped);

      await t.pumpWidget(const SizedBox.shrink());
      await frames(t);
    });
  }

  // A row on that Members page opens its member's profile as the page's second
  // level; the profile's head carries the grip in turn, and Back steps profile,
  // then Members, then Details.
  for (final scenario in [
    (size: const Size(944, 856), platform: TargetPlatform.android),
    (size: const Size(1024, 768), platform: TargetPlatform.linux),
    (size: const Size(1280, 900), platform: TargetPlatform.linux),
  ]) {
    testWidgets('a member profile over members keeps the grip at '
        '${scenario.size} / ${scenario.platform.name}', (t) async {
      final (_, api) = await mountWorkspace(
        t,
        scenario.size,
        platform: scenario.platform,
      );
      api.routes['GET /channels/c1/members'] = (_) => {
        'humans': [
          {'id': 'bob', 'userId': 'bob', 'name': 'bob', 'displayName': 'Bob'},
        ],
        'agents': [
          {'id': 'a1', 'name': 'cindy', 'displayName': 'Cindy'},
        ],
      };
      final grips = find.byType(ChannelSideHead);
      Finder profileHead(Finder profile) => find.descendant(
        of: profile,
        matching: find.byType(RaftPanelHeaderBar),
      );
      Finder back(Finder profile) => find.descendant(
        of: profileHead(profile),
        matching: find.byWidgetPredicate(
          (w) => w is RaftPanelAction && w.tooltip == 'Back',
        ),
      );
      void headGripped(Finder profile) {
        expect(grips, findsOneWidget);
        expect(
          find.descendant(of: profileHead(profile), matching: grips),
          findsOneWidget,
          reason: 'the grip belongs to the profile head, not around the page',
        );
      }

      await t.tap(find.byKey(const Key('channel-overflow-trigger')));
      await frames(t, 25);
      expect(grips, findsOneWidget);
      expect(gripped(detailsHead), isTrue);
      final entry = key('channel-overflow-members-entry');
      await t.ensureVisible(entry);
      await frames(t, 5);
      await t.tap(entry);
      await frames(t, 25);

      await t.tap(key('member-page-row-human-bob-open'));
      await frames(t, 30);
      final bob = key('member-page-profile-bob');
      expect(bob, findsOneWidget);
      headGripped(bob);

      await t.tap(back(bob));
      await frames(t, 25);
      expect(bob, findsNothing);
      expect(key('member-page'), findsOneWidget);
      expect(grips, findsOneWidget);
      expect(gripped(key('member-page-back')), isTrue);

      await t.tap(key('member-page-row-agent-a1-open'));
      await frames(t, 30);
      final agent = key('member-page-profile-a1');
      expect(agent, findsOneWidget);
      headGripped(agent);

      await t.tap(back(agent));
      await frames(t, 25);
      expect(agent, findsNothing);
      expect(key('member-page'), findsOneWidget);
      await t.tap(key('member-page-back'));
      await frames(t, 25);
      expect(key('member-page'), findsNothing);
      expect(grips, findsOneWidget);
      expect(gripped(detailsHead), isTrue);

      await t.pumpWidget(const SizedBox.shrink());
      await frames(t);
    });
  }
}
