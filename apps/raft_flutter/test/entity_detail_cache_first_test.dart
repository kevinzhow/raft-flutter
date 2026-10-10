import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _agents = <Map<String, dynamic>>[
  {
    'id': 'a',
    'name': 'Alpha Agent',
    'status': 'active',
    'runtime': 'codex',
    'model': 'alpha-model-1',
    'activity': 'online',
  },
  {
    'id': 'b',
    'name': 'Beta Agent',
    'status': 'active',
    'runtime': 'claude',
    'model': 'beta-model-2',
    'activity': 'online',
  },
];
const _computers = <Map<String, dynamic>>[
  {'id': 'c1', 'name': 'Alpha Computer', 'status': 'online', 'userId': 'alice'},
  {'id': 'c2', 'name': 'Beta Computer', 'status': 'online', 'userId': 'alice'},
];

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
  @override
  Future<List<RaftRecord>> servers() async => [
    RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'}),
  ];
  @override
  Future<List<RaftChannel>> channels({bool dm = false}) async => [];
}

/// The shared entity directory answers at once; detail-only reads stay open
/// so only accepted directory facts can be on screen.
class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final lists = <(String, Completer<dynamic>)>[];
  bool holdLists = false;
  final detailReads = <String>[];
  final pending = <Completer<dynamic>>[];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (holdLists && (path == '/agents' || path.endsWith('/machines'))) {
      final held = Completer<dynamic>();
      lists.add((path, held));
      return held.future;
    }
    if (path == '/agents') return _agents;
    if (path == '/servers/s/machines') return {'machines': _computers};
    if (path == '/servers/s/members') return [];
    if (path.startsWith('/agents/') || path.contains('/machines/')) {
      detailReads.add(path);
      final held = Completer<dynamic>();
      pending.add(held);
      return held.future;
    }
    return [];
  }
}

/// ProfilePanel.tsx:67-172 / MainLayout.tsx:547-580: a detail opens from the
/// accepted store at once; it never invents defaults and a changed target never
/// shows the previous entity's facts.
void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final computers in [false, true]) {
      final kind = computers ? 'computer' : 'agent';
      final rows = computers ? _computers : _agents;
      testWidgets(
        '[L09] $family/$dark desktop $kind detail opens from the accepted store and switching target hides the previous entity at once',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = const Size(1440, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final client = _Client()..selectServer('s');
          final w = _Workspace(client)
            ..server = RaftRecord({
              'id': 's',
              'name': 'Fixture',
              'role': 'owner',
            })
            ..section = computers ? 'computers' : 'agents';
          addTearDown(() async {
            w.dispose();
            await client.stream.close();
          });
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: WorkspaceView(
                controller: w,
                appearance: RaftAppearance(light: family),
                onAppearance: (_) async {},
                onLogout: () async {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          final detail = find.byType(FleetDetail);
          expect(detail, findsNothing);
          Finder inDetail(String text) =>
              find.descendant(of: detail, matching: find.text(text));
          Finder row(int i) =>
              find.byKey(ValueKey('desktop-directory-$kind-${rows[i]['id']}'));
          // ("Default" is a real Runtime Config value for an unset reasoning
          // effort, so only the cold shell is asserted against it.)
          const invented = ['offline', 'Unassigned', 'null'];

          // First entity: the first frame after the click already has its real
          // name; its detail read is still open and no default stands in.
          await tester.tap(row(0));
          await tester.pump();
          expect(detail, findsOneWidget);
          // An agent's detail-only read is open, a computer has none; either
          // way nothing but the accepted directory is on screen.
          if (!computers) expect(w.detailReads, ['/agents/a']);
          expect(w.pending.every((p) => !p.isCompleted), isTrue);
          expect(inDetail(rows[0]['name'] as String), findsWidgets);
          expect(
            find.descendant(of: detail, matching: find.text('Loading...')),
            findsNothing,
          );
          for (final text in invented) {
            expect(inDetail(text), findsNothing, reason: text);
          }

          // Second entity: not a frame of the first entity's name or facts.
          await tester.tap(row(1));
          await tester.pump();
          expect(inDetail(rows[1]['name'] as String), findsWidgets);
          expect(inDetail(rows[0]['name'] as String), findsNothing);
          if (!computers) {
            expect(inDetail('alpha-model-1'), findsNothing);
          }
          for (final text in invented) {
            expect(inDetail(text), findsNothing, reason: text);
          }
          for (var frame = 0; frame < 6; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(inDetail(rows[0]['name'] as String), findsNothing);
            expect(inDetail(rows[1]['name'] as String), findsWidgets);
          }

          // An older detail answer for the first entity cannot repaint it.
          if (!computers) {
            expect(w.detailReads, ['/agents/a', '/agents/b']);
            w.pending.first.complete({
              ...rows[0],
              'description': 'Late first answer',
            });
          }
          await tester.pumpAndSettle();
          expect(inDetail(rows[0]['name'] as String), findsNothing);
          expect(inDetail('Late first answer'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        },
      );

      testWidgets(
        '[L09] $family/$dark $kind detail with only an id shows no invented defaults',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = const Size(900, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final client = _Client()..selectServer('s');
          final w = _Workspace(client)
            ..server = RaftRecord({
              'id': 's',
              'name': 'Fixture',
              'role': 'owner',
            });
          addTearDown(() async {
            w.dispose();
            await client.stream.close();
          });
          // Nothing accepted: the shared directory has not answered.
          w.holdLists = true;
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: Scaffold(
                body: FleetDetail(
                  controller: w,
                  computers: computers,
                  initial: {'id': rows[0]['id'] as String},
                  onClose: () {},
                ),
              ),
            ),
          );
          await tester.pump();
          expect(find.text('Loading...'), findsOneWidget);
          for (final text in [
            'Default',
            'offline',
            'Unassigned',
            'null',
            rows[0]['name'] as String,
          ]) {
            expect(find.text(text), findsNothing, reason: text);
          }
          // The real answer then replaces the placeholder in place.
          for (final (path, held) in w.lists) {
            held.complete(
              path == '/agents' ? _agents : {'machines': _computers},
            );
          }
          if (!computers) {
            for (final held in w.pending) {
              held.complete(rows[0]);
            }
          }
          await tester.pumpAndSettle();
          expect(find.text(rows[0]['name'] as String), findsWidgets);
          expect(find.text('Loading...'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        },
      );
    }
  }
}
