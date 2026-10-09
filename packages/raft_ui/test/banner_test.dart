import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final theme in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'Banner description keeps Source small density and announces errors $theme',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(theme.$1, dark: theme.$2),
            home: const Scaffold(
              body: DefaultTextStyle(
                style: TextStyle(fontWeight: FontWeight.bold),
                child: SizedBox(
                  width: 300,
                  child: RaftBanner(
                    description: 'Avatar upload failed',
                    size: RaftBannerRecipeSize.sm,
                  ),
                ),
              ),
            ),
          ),
        );
        final text = tester.widget<Text>(find.text('Avatar upload failed'));
        expect(text.style!.fontSize, 12);
        expect(text.style!.height, 16 / 12);
        expect(text.style!.fontWeight, FontWeight.w400);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.role == SemanticsRole.alert,
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'Banner can change status and density without losing its message $theme',
      (tester) async {
        Future<void> pump(
          RaftBannerRecipeSize size,
          RaftBannerRecipeStatus status,
        ) => tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(theme.$1, dark: theme.$2),
            home: Scaffold(
              body: SizedBox(
                width: 300,
                child: RaftBanner(
                  title: 'Connection',
                  description: 'Your draft is saved.',
                  size: size,
                  status: status,
                ),
              ),
            ),
          ),
        );
        await pump(RaftBannerRecipeSize.md, RaftBannerRecipeStatus.warning);
        final initial = tester.getSize(find.byType(RaftBanner)).height;
        await pump(RaftBannerRecipeSize.sm, RaftBannerRecipeStatus.info);
        expect(
          tester.getSize(find.byType(RaftBanner)).height,
          lessThan(initial),
        );
        expect(find.text('Connection'), findsOneWidget);
        expect(find.text('Your draft is saved.'), findsOneWidget);
        final body = tester.widget<Text>(find.text('Your draft is saved.'));
        expect(body.style!.fontWeight, FontWeight.w400);
        expect(body.style!.fontSize, 12);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
