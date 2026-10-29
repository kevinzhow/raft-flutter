import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

void main() {
  for (final theme in raftThemeMatrix(['light', 'dark'])) {
    testWidgets('Home bell remains tappable inside Android back edge: $theme', (
      t,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final fixture = RootFixture();
      await fixture.mount(t, theme, 412, uri: Uri.parse('/s/alpha'));
      // Moto's configured back sensitivity reserves 114 physical pixels on
      // each side. The bell sits inside that band at this display density.
      t.view.systemGestureInsets = const FakeViewPadding(left: 40, right: 40);
      addTearDown(t.view.resetSystemGestureInsets);
      await fixture.flush(t);
      expect(find.byType(StretchingOverscrollIndicator), findsWidgets);
      expect(find.byType(GlowingOverscrollIndicator), findsNothing);
      final bell = find.byType(RaftMobileNotificationButton);
      expect(bell, findsOneWidget);
      expect(t.getCenter(bell).dx, greaterThan(412 - 40));
      await t.tap(bell);
      await fixture.flush(t);
      expect(find.byType(RaftNotificationCenter), findsOneWidget);
      await t.binding.handlePopRoute();
      await fixture.flush(t);
      expect(find.byType(RaftNotificationCenter), findsNothing);
      expect(fixture.workspace(t).location.uri.path, '/s/alpha');
      await t.tap(bell);
      await t.pump();
      expect(find.byType(RaftNotificationCenter), findsOneWidget);
      await fixture.close(t);
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
