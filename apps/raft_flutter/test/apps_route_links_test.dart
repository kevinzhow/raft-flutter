import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/profile_side_panel.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

const _details = ValueKey('connected-app-installed-detail');
const _unavailable = ValueKey('connected-apps-bot-link-not-installed');

RootFixture _fixture() {
  final fixture = RootFixture();
  fixture.overrides.addAll({
    'GET /integrations/clients': (_) => [],
    'GET /integrations/marketplace': (_) => [],
    'GET /integrations/overview': (_) => [],
    'GET /integrations/marketplace/listings': (_) => {'items': [], 'total': 0},
    'GET /mcp/apps': (_) => {'apps': []},
  });
  return fixture;
}

void main() {
  testWidgets('an installed bot profile opens beside Apps and closes to Apps', (
    tester,
  ) async {
    final fixture = _fixture();
    fixture.overrides['GET /integrations/marketplace'] = (_) => [
      {
        'id': 'installed-garden',
        'clientId': 'garden-journal',
        'name': 'Garden Journal',
        'publishStatus': 'published',
        'installedAt': '2026-11-20T00:00:00Z',
        'bot': {
          'offered': true,
          'handle': 'garden',
          'grant': 'granted',
          'agentId': 'garden-bot',
        },
      },
    ];
    await fixture.mount(
      tester,
      'light',
      1280,
      uri: Uri.parse('/s/alpha/apps?installed_app=installed-garden'),
    );
    expect(find.byKey(_details), findsOneWidget);
    final action = find.text('View profile');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await fixture.flush(tester);
    expect(find.byKey(_details), findsNothing);
    expect(find.byType(ProfileSidePanel), findsOneWidget);
    expect(find.byKey(const ValueKey('apps-page')), findsOneWidget);

    final workspace = fixture.workspace(tester);
    expect(workspace.location.profile?.id, 'garden-bot');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await fixture.flush(tester);
    expect(find.byType(ProfileSidePanel), findsNothing);
    expect(workspace.location.uri.path, '/s/alpha/apps');
    await fixture.close(tester);
  });

  testWidgets('an app bot link opens its installed detail once', (
    tester,
  ) async {
    final fixture = _fixture();
    fixture.overrides['GET /integrations/marketplace'] = (_) => [
      {
        'id': 'installed-garden',
        'clientId': 'garden-journal',
        'name': 'Garden Journal',
        'publishStatus': 'published',
        'installedAt': '2026-11-20T00:00:00Z',
        'bot': {'offered': true, 'handle': 'garden', 'grant': 'pending'},
      },
    ];
    await fixture.mount(
      tester,
      'light',
      390,
      uri: Uri.parse(
        '/s/alpha/apps?app_bot=garden-journal&installed_app=ignore&from=app#apps',
      ),
    );
    final workspace = fixture.workspace(tester);
    expect(find.byKey(_details), findsOneWidget);
    expect(find.text('Add @garden'), findsOneWidget);
    final identity = find.byKey(const ValueKey('connected-app-bot-section'));
    expect(tester.getRect(identity).center.dy, inInclusiveRange(0, 844));
    expect(
      find.descendant(
        of: identity,
        matching: find.byWidgetPredicate(
          (widget) => widget is RaftOuterRings && widget.rings.isNotEmpty,
        ),
      ),
      findsOneWidget,
    );
    expect(workspace.location.uri.queryParameters, {'from': 'app'});
    expect(workspace.location.uri.fragment, 'apps');

    await tester.tap(find.text('Close').last);
    await fixture.flush(tester);
    expect(find.byKey(_details), findsNothing);
    expect(find.byKey(_unavailable), findsNothing);
    await fixture.close(tester);
  });

  testWidgets('a dismissed unknown bot link stays consumed on reopen', (
    tester,
  ) async {
    var fixture = _fixture();
    await fixture.mount(
      tester,
      'light',
      390,
      uri: Uri.parse('/s/alpha/apps?app_bot=unknown&from=app'),
    );
    final banner = find.byKey(_unavailable);
    expect(banner, findsOneWidget);
    expect(find.byKey(_details), findsNothing);
    final restored = fixture.workspace(tester).location.uri;
    expect(restored.queryParameters, {'from': 'app'});
    final close = find.descendant(
      of: banner,
      matching: find.byKey(const ValueKey('banner-close')),
    );
    await tester.tap(close);
    await fixture.flush(tester);
    expect(banner, findsNothing);
    await fixture.close(tester);

    fixture = _fixture();
    await fixture.mount(tester, 'light', 390, uri: restored);
    expect(banner, findsNothing);
    expect(find.byKey(_details), findsNothing);
    await fixture.close(tester);
  });
}
