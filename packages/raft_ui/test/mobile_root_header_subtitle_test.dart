import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web v1.24 TabRootBar: a tab root's name with one optional line under it
/// (Activity's counts), inside the same header height, never a Back.
void main() {
  for (final theme in [raftTheme(), raftTheme(dark: true)]) {
    testWidgets('root header seam in ${theme.brightness}', (t) async {
      const headerKey = Key('root');
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);

      // TabRootBar uses the same PanelSectionHeader with a title or with
      // replacement content such as the Search field.
      for (final header in [
        const RaftMobileRootHeader(
          key: headerKey,
          title: 'Tasks',
          subtitle: '6 tasks',
        ),
        const RaftMobileRootHeader(
          key: headerKey,
          title: 'Search',
          content: Text('Search messages'),
        ),
      ]) {
        await t.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Align(alignment: Alignment.topCenter, child: header),
            ),
          ),
        );

        final root = find.byKey(headerKey);
        final band = find.descendant(
          of: root,
          matching: find.byType(DecoratedBox),
        );
        final decoration =
            t.widget<DecoratedBox>(band).decoration as BoxDecoration;
        final tokens = RaftTokens.of(t.element(root));
        expect(t.getSize(root), const Size(390, 56));
        expect(decoration.color, tokens.colors['layer-frame']);
        expect(
          decoration.border,
          Border(bottom: BorderSide(color: tokens.colors['line-seam']!)),
          reason: header.title,
        );
      }
    });

    testWidgets('root header subtitle line in ${theme.brightness}', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      Future<Size> mount(String? subtitle) async {
        await t.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Column(
                children: [
                  RaftMobileRootHeader(
                    key: const Key('root'),
                    title: 'Activity',
                    subtitle: subtitle,
                  ),
                ],
              ),
            ),
          ),
        );
        return t.getSize(find.byKey(const Key('root')));
      }

      final bare = await mount(null);
      expect(find.text('Activity'), findsOneWidget);
      expect(find.byType(RaftBackButton), findsNothing);

      final withLine = await mount('5 active · 2 unread');
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('5 active · 2 unread'), findsOneWidget);
      final caption = t.widget<Text>(find.text('5 active · 2 unread'));
      final spans = (caption.textSpan as TextSpan?)?.children ?? [];
      final tokens = RaftTokens.of(t.element(find.byKey(const Key('root'))));
      expect(
        spans
            .whereType<TextSpan>()
            .where((span) => span.style?.fontFamily == tokens.monoFont)
            .map((span) => span.text),
        ['5', '2'],
      );
      expect(find.byType(RaftBackButton), findsNothing);
      // The line sits under the name, inside the same bar.
      expect(withLine, bare);
      expect(
        t.getTopLeft(find.text('5 active · 2 unread')).dy,
        greaterThan(t.getBottomLeft(find.text('Activity')).dy - 1),
      );
      expect(t.takeException(), isNull);

      // A long line truncates on one line instead of growing the bar.
      final long = await mount('${'9' * 40} active · ${'9' * 40} unread');
      expect(long, bare);
      expect(t.takeException(), isNull);
    });
  }
}
