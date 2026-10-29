import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('loading list metrics and rules follow a user pack', (
    tester,
  ) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    final pack = RaftThemePack.parse(
      jsonEncode({
        'format': raftThemePackFormat,
        'id': 'user:loading-card-metrics',
        'name': {'en': 'Loading card metrics'},
        'version': '1.0.0',
        'extends': 'raft',
        'modes': {
          'light': {
            'geometry': {
              'space.activityLoadingInline': 23,
              'space.activityLoadingBlock': 17,
              'radius.activityLoadingCard': 9,
              'radius.taskLoadingCard': 11,
              'space.tasksViewportInline': 29,
            },
            'colors': {'line-loading-card': '#123456'},
          },
          'dark': {},
        },
      }),
    );
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final activity in [true, false]) {
      final child = activity
          ? const RaftActivityLoadingList()
          : const RaftTaskLoadingList();
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: pack),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(1280, 800),
              disableAnimations: true,
            ),
            child: Scaffold(body: child),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final root = find.byWidget(child);
      final list = tester.widget<ListView>(
        find.descendant(of: root, matching: find.byType(ListView)),
      );
      expect(
        list.padding,
        activity
            ? const EdgeInsets.symmetric(horizontal: 23, vertical: 17)
            : const EdgeInsets.symmetric(horizontal: 29, vertical: 16),
      );
      final card = tester.widget<Container>(
        find.descendant(of: root, matching: find.byType(Container)).first,
      );
      final decoration = card.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(activity ? 9 : 11));
      expect(decoration.border, Border.all(color: const Color(0xff123456)));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
