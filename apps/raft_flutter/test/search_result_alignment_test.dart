import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/resource_search.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

Map<String, dynamic> hit(String id, {String date = '2026-06-19T10:00:00Z'}) => {
  'id': id,
  'channelId': 'ops',
  'channelType': 'channel',
  'channelName': 'ops',
  'senderId': 'alice',
  'senderName': 'Alice',
  'senderType': 'user',
  'snippet': 'ALPHA separated from [Beta].* and alpha again',
  'createdAt': date,
};

List<String> highlighted(WidgetTester t) {
  final text = t.widget<Text>(
    find.descendant(
      of: find.byType(SearchHighlight).first,
      matching: find.byType(Text),
    ),
  );
  return (text.textSpan! as TextSpan).children!
      .whereType<TextSpan>()
      .where((span) => span.style?.backgroundColor != null)
      .map((span) => span.text!)
      .toList();
}

Future<void> mount(
  WidgetTester t,
  bool dark,
  List<Map<String, dynamic>> rows, {
  double width = 1280,
  Locale locale = const Locale('en'),
  void Function(Map<String, dynamic>)? open,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, 900);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(() async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });
  await t.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: raftTheme(dark: dark),
      home: Scaffold(
        body: ResourceSearchResults(
          query: 'alpha\t[beta].*',
          rows: rows,
          entities: const [],
          origin: 'https://fixture.invalid',
          plan: 'free',
          now: DateTime.utc(2026, 10, 18),
          selectedKey: 'message:${rows.first['id']}',
          onMessage: open ?? (_) {},
          onEntity: (_) {},
          hasMore: false,
          onMore: () {},
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  // Web v1.21.12 MessageHitRow + MessageSearchPage.SearchHighlight:
  // whitespace-separated literal terms, not a whole-query substring.
  for (final (dark) in raftThemeMatrix([(false), (true)], full: true)) {
    for (final width in [390.0, 1280.0]) {
      testWidgets(
        'search row highlights terms and opens its own hit ${dark ? 'dark' : 'light'}/$width',
        (t) async {
          Map<String, dynamic>? opened;
          var opens = 0;
          final semantics = t.ensureSemantics();
          try {
            final row = hit('m1');
            await mount(
              t,
              dark,
              [row],
              width: width,
              open: (r) {
                opened = r;
                opens++;
              },
            );
            expect(highlighted(t), ['ALPHA', '[Beta].*', 'alpha']);
            expect(find.text('#ops'), findsOneWidget);
            expect(find.text('Alice'), findsOneWidget);
            final rich = t.widget<Text>(
              find.descendant(
                of: find.byType(SearchHighlight),
                matching: find.byType(Text),
              ),
            );
            expect(rich.textSpan!.toPlainText(), row['snippet']);
            expect(rich.maxLines, 2);
            await t.tap(find.byKey(const ValueKey('search-message:m1')));
            expect(identical(opened, row), isTrue);
            expect(
              t
                  .getSemantics(find.byType(RaftInteractive))
                  .getSemanticsData()
                  .label,
              contains(row['snippet']),
            );
            await t.sendKeyEvent(LogicalKeyboardKey.enter);
            await t.pump();
            expect(opens, 2);
            expect(t.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
    testWidgets(
      'search warning badges are not all caps ${dark ? 'dark' : 'light'}',
      (t) async {
        await mount(t, dark, [hit('m1')..['channelArchivedAt'] = '2026-01-01']);
        final badges = t.widgetList<RaftBadge>(find.byType(RaftBadge)).toList();
        expect(badges.where((b) => b.label == 'Archived'), hasLength(1));
        expect(badges.where((b) => b.label == 'Upgrade to view'), hasLength(1));
        expect(find.text('Archived'), findsOneWidget);
        expect(find.text('Upgrade to view'), findsOneWidget);
      },
    );
    testWidgets(
      'empty parent identity stays an individual hit ${dark ? 'dark' : 'light'}',
      (t) async {
        await mount(t, dark, [
          for (final id in ['m1', 'm2'])
            hit(id)
              ..['threadId'] = 'thread-1'
              ..['parentMessageId'] = '',
        ]);
        expect(find.byType(RaftQuickSwitcherThreadGroup), findsNothing);
        expect(find.byType(RaftQuickSwitcherHit), findsNWidgets(2));
      },
    );
    testWidgets(
      'Chinese search metadata uses the app locale ${dark ? 'dark' : 'light'}',
      (t) async {
        await mount(t, dark, [
          hit('m1', date: 'invalid'),
        ], locale: const Locale('zh'));
        expect(find.text('未知时间'), findsOneWidget);
        expect(highlighted(t), ['ALPHA', '[Beta].*', 'alpha']);
      },
    );
    testWidgets(
      'invalid search timestamp has localized unknown label ${dark ? 'dark' : 'light'}',
      (t) async {
        await mount(t, dark, [hit('m1', date: 'invalid')]);
        expect(find.text('unknown time'), findsOneWidget);
      },
    );
  }
}
