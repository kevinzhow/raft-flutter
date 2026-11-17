// ThreadsInbox `inbox-load-failed` as Web draws it: one warning banner with
// the TriangleAlert glyph, as tall as its content at the top of the list (Web
// 347x88 desktop, 350x84 phone), never stretched over the list's height.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/activity_filter_choice.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_incremental_refresh_test.dart'
    show ActivityClient, activityFixture, channelRow;
import 'activity_scopes_widget_test.dart' show ScopeWorkspace;

void main() {
  late ActivityClient client;
  late ScopeWorkspace w;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DevicePreferences.adopt(await SharedPreferences.getInstance());
    final (c, base) = activityFixture();
    client = c;
    w = ScopeWorkspace(c)
      ..server = base.server
      ..channels = base.channels
      ..inbox = [for (var i = 0; i < 4; i++) channelRow(i)];
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
    DevicePreferences.reset();
  });

  for (final (name, size, platform) in [
    ('1440x900 Linux', const Size(1440, 900), TargetPlatform.linux),
    ('390x844 Android', const Size(390, 844), TargetPlatform.android),
  ]) {
    testWidgets('$name: the failed-load banner has the warning glyph and '
        'its own height', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: platform),
          home: Scaffold(
            body: ResourceView(
              controller: w,
              section: 'activity',
              onMessage: (_, _) async {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final dynamic state = t.state(find.byType(ResourceView));
      w.failScope = true;
      state.chooseActivityFilter(ActivityFilterChoice.pinned);
      await t.pumpAndSettle();
      final failed = find.byKey(const ValueKey('inbox-load-failed'));
      expect(failed, findsOneWidget);
      final banner = find.descendant(
        of: failed,
        matching: find.byType(RaftBanner),
      );
      expect(t.widget<RaftBanner>(banner).glyph, RaftGlyph.triangleAlert);
      expect(t.getSize(banner).height, lessThan(120));
    });
  }

  // Web: a failed first load is a settled load; the header reads
  // "0 in progress · 0 unread" over the banner, not an empty line.
  testWidgets('a failed first load settles the counts line at zero', (t) async {
    ActivityFilterPreference.write('s1', ActivityFilterChoice.pinned);
    w.failScope = true;
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ResourceView(
            controller: w,
            section: 'activity',
            onMessage: (_, _) async {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('inbox-load-failed')), findsOneWidget);
    expect(find.byKey(const ValueKey('activity-counts-loading')), findsNothing);
    expect(
      find.textContaining('0 in progress · 0 unread', findRichText: true),
      findsOneWidget,
    );
  });
}
