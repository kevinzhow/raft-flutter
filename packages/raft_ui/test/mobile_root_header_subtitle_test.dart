import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web v1.24 TabRootBar: a tab root's name with one optional line under it
/// (Activity's counts), inside the same header height, never a Back.
void main() {
  for (final theme in [raftTheme(), raftTheme(dark: true)]) {
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
