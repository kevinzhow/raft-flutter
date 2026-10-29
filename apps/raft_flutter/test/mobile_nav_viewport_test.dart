import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

// Real RaftApp composition: a docked bar spends its height once, while the
// legacy capsule overlays the list. This is a geometry contract, so every
// theme variant runs rather than sampling away the distinguishing cases.
void main() {
  for (final (pack, mode, inset, docked) in raftThemeMatrix([
    (raftThemePackId, 'light', 24.0, true),
    (raftThemePackId, 'dark', 48.0, true),
    (brutalThemePackId, 'light', 24.0, true),
    (elegantThemePackId, 'light', 24.0, false),
    (elegantThemePackId, 'dark', 24.0, false),
    (brutalThemePackId, 'dark', 24.0, false),
  ], look: (v) => raftLookOf(v.$1))) {
    testWidgets('$pack $mode preserves the visible sidebar viewport', (
      t,
    ) async {
      final f = RootFixture();
      await f.mount(
        t,
        mode,
        390,
        uri: Uri.parse('/s/alpha'),
        preferences: {appearanceThemeKey: pack},
      );
      t.view.viewPadding = FakeViewPadding(bottom: inset);
      t.view.padding = FakeViewPadding(bottom: inset);
      addTearDown(t.view.reset);
      await f.flush(t);
      final list = find.byKey(const Key('workspace-sidebar'));
      final bar = find.byKey(const Key('workspace-mobile-navigation'));
      final listRect = t.getRect(list), barRect = t.getRect(bar);
      expect(barRect.bottom, closeTo(900 - inset, .01));
      if (docked) {
        expect(
          listRect.bottom,
          closeTo(barRect.top, .01),
          reason: 'The visible list must end above the in-flow tab bar.',
        );
        final point = listRect.bottomLeft + const Offset(24, -30);
        expect(barRect.contains(point), isFalse);
        await t.longPressAt(point);
        await f.flush(t);
        expect(find.byType(RaftSidebarContextMenu), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(RaftSidebarContextMenu),
            matching: find.text('New Section…'),
          ),
          findsOneWidget,
        );
      } else {
        expect(listRect.bottom, greaterThan(barRect.top));
        expect(listRect.bottom, closeTo(900, .01));
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }
}
