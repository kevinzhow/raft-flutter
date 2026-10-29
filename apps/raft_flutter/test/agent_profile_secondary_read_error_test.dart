import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _agent = <String, dynamic>{
  'id': 'a',
  'name': 'Alpha Agent',
  'displayName': 'Alpha Agent',
  'status': 'active',
  'runtime': 'codex',
  'model': 'alpha-model-1',
  'activity': 'online',
};

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
}

/// The directory row is accepted; secondary reads fail with a 500 on demand.
class _Workspace extends WorkspaceController {
  _Workspace(super.client, {this.failSkills = false, this.failDetail = false});
  final bool failSkills, failDetail;
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    const boom = RaftApiException('Internal server error', status: 500);
    if (path == '/agents') return [_agent];
    if (path == '/servers/s/machines') return {'machines': []};
    if (path == '/agents/a/skills') {
      if (failSkills) throw boom;
      return {'global': [], 'workspace': []};
    }
    if (path == '/agents/a') {
      if (failDetail) throw boom;
      return _agent;
    }
    return [];
  }
}

/// Web AgentSkills shows a load failure inside its own section (message +
/// Retry) and Web's profile fallback swallows a failed `/agents/:id`; neither
/// secondary read may put a page-level error above the profile.
void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final (label, failSkills, failDetail) in [
      ('skills 500', true, false),
      ('detail 500', false, true),
      ('skills and detail 500', true, true),
    ]) {
      testWidgets(
        '${dark ? 'dark' : 'light'} agent profile with $label has no page error',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = const Size(900, 1600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final client = _Client()..selectServer('s');
          final w =
              _Workspace(client, failSkills: failSkills, failDetail: failDetail)
                ..server = RaftRecord({
                  'id': 's',
                  'name': 'Fixture',
                  'role': 'owner',
                });
          addTearDown(() async {
            w.dispose();
            await client.stream.close();
          });
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark),
              home: Scaffold(
                body: FleetDetail(
                  controller: w,
                  computers: false,
                  initial: const {'id': 'a'},
                  onClose: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AgentDetailPanel), findsOneWidget);
          expect(find.byType(RaftPanelErrorStrip), findsNothing);
          expect(find.text('Profile could not be loaded.'), findsNothing);
          expect(find.text('Alpha Agent'), findsWidgets);
          if (failSkills) {
            await tester.scrollUntilVisible(
              find.text('Retry'),
              300,
              scrollable: find.byType(Scrollable).last,
            );
            // The failure is shown once, inside the Skills section, with Retry.
            expect(find.text('Failed to load skills'), findsOneWidget);
            expect(
              find.descendant(
                of: find.byType(AgentSkillsSection),
                matching: find.text('Failed to load skills'),
              ),
              findsOneWidget,
            );
            expect(find.text('Retry'), findsOneWidget);
            // A body-less 500 shows the Web fallback, never the exception text.
            expect(find.text('Internal server error'), findsNothing);
          } else {
            expect(find.text('Failed to load skills'), findsNothing);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        },
      );
    }
  }
}
