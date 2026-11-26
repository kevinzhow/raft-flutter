import 'dart:async';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/channel_form_fields.dart';
import 'package:raft_flutter/features/channel_members.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'workspace_source_location_contract_test.dart'
    show mountPage, pageFixture;

void main() {
  const human = {'userId': 'bob', 'name': 'bob', 'displayName': 'Bob'};
  const agent = {
    'id': 'a1',
    'name': 'cindy',
    'displayName': 'Cindy',
    'status': 'active',
    'runtime': 'claude',
    'model': 'sonnet',
  };

  for (final page in [false, true]) {
    final surface = page ? 'full page control' : 'non-page modal';
    for (final (kind, id, name) in [
      ('human', 'bob', 'Bob'),
      ('agent', 'a1', 'Cindy'),
    ]) {
      testWidgets('$surface shows the $kind profile after an avatar click', (
        t,
      ) async {
        final (w, api) = await pageFixture(t, section: 'chat');
        final channel = w.channel!;
        api.routes.addAll({
          'GET /channels/c1/members': (_) => {
            'humans': [human],
            'agents': [agent],
          },
          'GET /agents': (_) => [agent],
          'GET /agents/a1': (_) => agent,
          'GET /agents/a1/skills': (_) => {'global': [], 'workspace': []},
          'GET /servers/s1/machines': (_) => {'machines': []},
          'GET /servers/s1/members': (_) => [human],
          'GET /servers/s1/members/bob/profile': (_) => human,
        });
        await mountPage(t, w, false, platform: TargetPlatform.linux);
        final context = t.element(find.byType(WorkspaceView));
        if (page) {
          unawaited(
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: ChannelMembers(
                    controller: w,
                    channel: channel,
                    page: true,
                  ),
                ),
              ),
            ),
          );
        } else {
          expect(w.mobileNavigation, isFalse);
          unawaited(
            ChannelMembers.show(context, controller: w, channel: channel),
          );
        }
        await t.pumpAndSettle();

        try {
          final roster = find.byType(RaftChannelMembersModal);
          final row = find.descendant(
            of: roster,
            matching: find.byKey(ValueKey('member-page-row-$kind-$id')),
          );
          final avatar = find.descendant(
            of: row,
            matching: find.byType(ChannelCandidateAvatar),
          );
          final profile = page
              ? find.byKey(ValueKey('member-page-profile-$id'))
              : find.byKey(ValueKey('profile-$kind-$id'));
          expect(roster, findsOneWidget);
          expect(t.widget<RaftChannelMembersModal>(roster).page, page);
          expect(ModalRoute.of(t.element(roster))?.isCurrent, isTrue);
          expect(
            find.descendant(of: row, matching: find.text(name)),
            findsOneWidget,
          );
          expect(avatar, findsOneWidget);
          expect(profile, findsNothing);
          final center = t.getCenter(avatar);
          expect(t.getRect(row).contains(center), isTrue);
          expect(t.getRect(roster).contains(center), isTrue);

          await t.tapAt(center, kind: PointerDeviceKind.mouse);
          await t.pumpAndSettle();

          expect(
            (profile.evaluate().length, roster.evaluate().length),
            (1, 0),
            reason:
                'Expected one visible $kind profile and a closed roster '
                'after clicking the avatar. Counts are (profile, roster).',
          );
          expect(
            find.descendant(of: profile, matching: find.text(name)),
            findsWidgets,
          );
          if (page) {
            await t.binding.handlePopRoute();
          } else {
            await t.tap(
              find
                  .descendant(
                    of: profile,
                    matching: find.byWidgetPredicate(
                      (widget) =>
                          widget is RaftButton &&
                          widget.tooltip == 'Close Profile',
                    ),
                  )
                  .hitTestable(),
              kind: PointerDeviceKind.mouse,
            );
          }
          await t.pumpAndSettle();
          expect(profile, findsNothing);
          if (page) {
            expect(roster, findsOneWidget);
            await t.binding.handlePopRoute();
            await t.pumpAndSettle();
          }
          expect(roster, findsNothing);
          expect(find.byType(WorkspaceView), findsOneWidget);
          expect(t.takeException(), isNull);
        } finally {
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
        }
      });
    }
  }
}
