import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final dark in [false, true]) {
    for (final phone in [false, true]) {
      testWidgets('details surface $dark / phone $phone', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(phone ? 390 : 1280, 844);
        addTearDown(t.view.reset);
        var closes = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: SizedBox(
                width: phone ? 390 : 400,
                child: RaftOverflowSheet(
                  details: true,
                  page: phone,
                  title: '#fixture',
                  badge: 'Public',
                  subtitle: 'First line\nSecond line',
                  onClose: () => closes++,
                  children: const [Text('Settings content')],
                ),
              ),
            ),
          ),
        );
        expect(find.text('Details'), findsOneWidget);
        expect(find.text('#fixture'), findsOneWidget);
        expect(find.text('First line\nSecond line'), findsOneWidget);
        expect(find.text('Settings content'), findsOneWidget);
        final surface = find.byKey(const Key('channel-details'));
        expect(t.getSize(surface).width, phone ? 390 : 400);
        final canvas = t.widget<ColoredBox>(surface);
        final tokens = RaftTokens.of(t.element(surface));
        expect(canvas.color, tokens.colors['layer-canvas']);
        await t.tap(
          find.byKey(
            Key(phone ? 'channel-overflow-back' : 'channel-details-close'),
          ),
        );
        expect(closes, 1);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'details description expands and a subpage head replaces Details',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(1280, 844);
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: RaftOverflowSheet(
                details: true,
                title: '#fixture',
                subtitle: List.filled(8, 'Description line').join('\n'),
                onClose: () {},
                children: const [],
              ),
            ),
          ),
        ),
      );
      final description = find.byKey(
        const Key('channel-settings-description-readonly'),
      );
      final before = t.getSize(description).height;
      await t.tap(find.text('Show more'));
      await t.pump();
      expect(t.getSize(description).height, greaterThan(before));
      await t.tap(find.text('Show less'));
      await t.pump();
      expect(t.getSize(description).height, before);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: RaftOverflowBareSheet(
                details: true,
                child: const Text('Members page'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Members page'), findsOneWidget);
      expect(find.text('Details'), findsNothing);
      expect(find.byKey(const Key('channel-details-close')), findsNothing);
      expect(find.byKey(const Key('channel-overflow-back')), findsNothing);
    },
  );
}
