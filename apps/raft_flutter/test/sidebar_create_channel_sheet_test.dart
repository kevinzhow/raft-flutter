import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/create_channel_dialog.dart';

import 'mounted_message_navigation_test.dart' show mountPage, pageFixture;

Finder _key(String value) => find.byKey(ValueKey(value));

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
    testWidgets('Home opens a pinned Create action on narrow $platform', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        final pointer = platform == TargetPlatform.android
            ? PointerDeviceKind.touch
            : PointerDeviceKind.mouse;
        final (workspace, api) = await pageFixture(tester);
        workspace
          ..mobileNavigation = true
          ..channel = null
          ..section = 'home';
        api.routes['POST /channels'] = (_) => {
          'id': 'created-review',
          'name': 'review-notes',
          'type': 'channel',
          'joined': true,
        };
        await mountPage(tester, workspace, false, width: 390, height: 844);
        addTearDown(() => tester.pumpWidget(const SizedBox()));
        final home = workspace.location.uri;
        final open = find.bySemanticsLabel('Create Channel');
        Future<void> openSheet() async {
          await tester.tap(open, kind: pointer);
          await tester.pumpAndSettle();
          expect(workspace.location.uri, home);
          expect(find.byType(CreateChannelDialog), findsOneWidget);
        }

        await openSheet();
        final head = _key('raft-form-sheet-head');
        final close = find.descendant(
          of: head,
          matching: find.bySemanticsLabel('Close'),
        );
        final create = find.descendant(of: head, matching: find.text('Create'));
        expect(head, findsOneWidget);
        expect(close.hitTestable(), findsOneWidget);
        expect(create.hitTestable(), findsOneWidget);
        expect(find.bySemanticsLabel('Create channel'), findsWidgets);
        final header = tester.getRect(head);
        expect(header.left, 0);
        expect(header.right, 390);
        expect(header.top, closeTo(84.4, 1));
        expect(header.height, 56);
        expect(
          tester.getCenter(close).dx,
          lessThan(tester.getCenter(create).dx),
        );
        expect(find.text('Cancel'), findsNothing);
        await tester.tap(close, kind: pointer);
        await tester.pumpAndSettle();
        expect(workspace.location.uri, home);
        expect(find.byType(CreateChannelDialog), findsNothing);

        await openSheet();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(workspace.location.uri, home);
        expect(find.byType(CreateChannelDialog), findsNothing);

        await openSheet();
        final name = _key('create-channel-name');
        await tester.enterText(name, 'Invalid name');
        tester.view.viewInsets = const FakeViewPadding(bottom: 420);
        await tester.pumpAndSettle();
        final initial = tester.getRect(head);
        final formScroll = find.descendant(
          of: find.byType(CreateChannelDialog),
          matching: find.byType(CustomScrollView),
        );
        if (pointer == PointerDeviceKind.touch) {
          await tester.drag(formScroll, const Offset(0, -200));
        } else {
          await tester.sendEventToBinding(
            PointerScrollEvent(
              position: tester.getCenter(formScroll),
              scrollDelta: const Offset(0, 200),
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(tester.getRect(head), initial);
        expect(create.hitTestable(), findsOneWidget);
        await tester.tap(create, kind: pointer);
        await tester.pumpAndSettle();
        final validation = find.text(
          'Start with a letter, then letters, numbers, - or _',
        );
        expect(validation.hitTestable(), findsOneWidget);
        expect(
          api.calls.where(
            (call) => call.method == 'POST' && call.path == '/channels',
          ),
          isEmpty,
        );
        await tester.ensureVisible(name);
        await tester.enterText(name, 'review-notes');
        await tester.pump();
        expect(validation, findsNothing);
        expect(create.hitTestable(), findsOneWidget);
        await tester.tap(create, kind: pointer);
        await tester.pumpAndSettle();
        final requests = api.calls.where(
          (call) => call.method == 'POST' && call.path == '/channels',
        );
        expect(requests.single.data, containsPair('name', 'review-notes'));
        expect(find.byType(CreateChannelDialog), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      } finally {
        semantics.dispose();
      }
    }, variant: TargetPlatformVariant.only(platform));
  }

  testWidgets(
    'dark Home keeps channel details when Back returns from Members',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final (workspace, api) = await pageFixture(tester);
        workspace
          ..mobileNavigation = true
          ..channel = null
          ..section = 'home';
        api.routes['POST /feature-flags/evaluate'] = (request) => {
          'evaluations': [
            for (final key in request.data['keys'] as List)
              {'key': key, 'enabled': key == 'external_channels_v1'},
          ],
        };
        api.routes['GET /channels/external-availability'] = (_) => {
          'freeLimitReached': false,
        };
        api.routes['POST /channels'] = (_) => {
          'id': 'created-review',
          'name': 'review-notes',
          'type': 'channel',
          'joined': true,
        };
        await mountPage(tester, workspace, true, width: 390, height: 844);
        addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
        final home = workspace.location.uri;
        final form = find.byType(CreateChannelDialog);
        final head = _key('raft-form-sheet-head');
        final name = _key('create-channel-name');
        final description = find
            .descendant(of: form, matching: find.byType(EditableText))
            .at(1);
        Finder action(String label) =>
            find.descendant(of: head, matching: find.text(label)).hitTestable();
        final writes = api.calls.where(
          (call) => call.method == 'POST' && call.path == '/channels',
        );

        await tester.tap(find.bySemanticsLabel('Create Channel').hitTestable());
        await tester.pumpAndSettle();
        expect(form, findsOneWidget);
        final initialHeader = tester.getRect(head);
        await tester.enterText(name, 'review-notes');
        await tester.enterText(description, 'Keep these details');
        expect(action('Next'), findsOneWidget);
        await tester.tap(action('Next'));
        await tester.pumpAndSettle();
        expect(find.text('Add people to #review-notes'), findsOneWidget);
        expect(tester.getRect(head), initialHeader);
        expect(writes, isEmpty);

        final back = find.descendant(of: form, matching: find.text('Back'));
        expect(back.hitTestable(), findsOneWidget);
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(find.text('Add people to #review-notes'), findsNothing);
        expect(find.text('review-notes'), findsOneWidget);
        expect(find.text('Keep these details'), findsOneWidget);
        expect(writes, isEmpty);
        expect(workspace.location.uri, home);
        await tester.tap(action('Next'));
        await tester.pumpAndSettle();
        expect(action('Create'), findsOneWidget);
        await tester.tap(action('Create'));
        await tester.pumpAndSettle();
        expect(writes.single.data, containsPair('name', 'review-notes'));
        expect(
          writes.single.data,
          containsPair('description', 'Keep these details'),
        );
        expect(form, findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
