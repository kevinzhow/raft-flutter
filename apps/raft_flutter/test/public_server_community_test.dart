// The public page's Help > Join Community (Web LeftRail HelpMenu
// `openCommunity`): join the default community server, reload the server
// list and switch to it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/public_server_settings.dart';
import 'package:raft_flutter/features/public_server_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'announcement_host_test.dart' as host;
import 'support/public_server_fixture.dart';

const _community = {
  'id': 'c',
  'name': 'Raft Community',
  'slug': 'community',
  'role': 'member',
};

class _Run {
  _Run({this.joinError, this.alreadyMember = false}) {
    f.client.route = (method, path, query) {
      calls.add('$method $path');
      if (path == publicBase) {
        return {
          'server': publicServer,
          'channels': [
            {'id': 'c1', 'name': 'general', 'description': null},
          ],
          'canJoinAsGuest': true,
        };
      }
      if (path.startsWith('$publicBase/channels/')) return {'messages': []};
      if (method == 'POST' && path == '/servers/join-community') {
        if (joinError != null) throw RaftApiException(joinError!, status: 500);
        return {'ok': true};
      }
      if (method == 'GET' && path == '/servers') return [_community];
      return f.handle(method, path, query);
    };
  }
  final f = host.Fixture();
  final calls = <String>[];
  final selected = <String>[];
  final String? joinError;
  final bool alreadyMember;

  PublicServerAccount get account => PublicServerAccount(
    servers: [if (alreadyMember) RaftRecord(_community)],
    onSelect: (s) => selected.add(s.string('slug')),
    settings: PublicSettingsAccount(
      controller: f.w,
      appearance: const RaftAppearance(),
      onAppearance: (_) {},
    ),
  );
}

Future<void> _mount(WidgetTester t, _Run run) async {
  t.view.physicalSize = const Size(1280, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(
        body: PublicServerView(
          client: run.f.client,
          slug: 'raft-design',
          account: run.account,
          onUnavailable: () {},
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  await t.tap(find.byKey(const ValueKey('public-rail-help')));
  await t.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('joins the community, reloads the server list and switches', (
    t,
  ) async {
    final run = _Run();
    await _mount(t, run);
    await t.tap(find.text('Join Community'));
    await t.pumpAndSettle();
    expect(
      run.calls,
      containsAllInOrder(['POST /servers/join-community', 'GET /servers']),
    );
    expect(run.selected, ['community']);
  });

  testWidgets('a member of the community just switches', (t) async {
    final run = _Run(alreadyMember: true);
    await _mount(t, run);
    await t.tap(find.text('Join Community'));
    await t.pumpAndSettle();
    expect(run.calls, isNot(contains('POST /servers/join-community')));
    expect(run.selected, ['community']);
  });

  testWidgets('a failed join shows the error and switches nowhere', (t) async {
    final run = _Run(joinError: 'Failed to join community server');
    await _mount(t, run);
    await t.tap(find.text('Join Community'));
    await t.pumpAndSettle();
    expect(run.selected, isEmpty);
    expect(find.text('Failed to join community server'), findsOneWidget);
  });
}
