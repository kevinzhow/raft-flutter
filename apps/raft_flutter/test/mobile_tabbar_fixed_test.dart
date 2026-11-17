import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'support/server_tab.dart';

// Web v1.24 has no bottom bar customisation: the phone bar is fixed. A value
// the old Bottom bar setting stored is ignored, not read and not removed.
void main() {
  testWidgets('a stored legacy raft.mobileTabbar value does not change the bar', (
    t,
  ) async {
    final f = RootFixture();
    await f.mount(
      t,
      'light',
      390,
      uri: Uri.parse('/s/alpha'),
      preferences: {
        'raft.mobileTabbar': '{"order":["search","chat"],"enabled":["chat"]}',
      },
    );
    final bar = find.byKey(const Key('workspace-mobile-navigation'));
    expect(bar, findsOneWidget);
    expect(t.widget<RaftMobileNav>(bar).items.map((i) => i.id), [
      'chat',
      'activity',
      'tasks',
      'search',
    ]);
    // Left to right: Home, Activity, Tasks, Search, then the server tab.
    final xs = [
      for (final id in ['home', 'activity', 'tasks', 'search', 'server'])
        t.getCenter(find.byKey(Key('mobile-tab-$id'))).dx,
    ];
    expect(xs, [...xs]..sort());
    expect(xs.toSet(), hasLength(5));

    await openServerPage(t, 'settings', flush: f.flush);
    expect(
      find.byKey(const ValueKey('workspace-settings-nav-appearance')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('workspace-settings-nav-bottom-bar')),
      findsNothing,
    );
    expect(find.text('Bottom bar'), findsNothing);
    await f.close(t);
  });
}
