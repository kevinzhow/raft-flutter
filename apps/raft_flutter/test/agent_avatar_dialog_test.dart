import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_avatar_dialog.dart';
import 'package:raft_flutter/features/fleet_views.dart';

import 'parity/parity_harness.dart' show loadParityFonts;

const agent = <String, dynamic>{
  'id': 'a',
  'name': 'Cindy',
  'runtime': 'codex',
  'status': 'active',
  'serverRole': 'member',
  'creatorType': 'user',
  'creatorId': 'viewer',
  'avatarUrl': 'pixel:cat',
};

class Client extends RaftClient {
  Client()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

class Workspace extends WorkspaceController {
  Workspace(super.client);
  final writes = <(String, String, dynamic)>[];
  Completer<dynamic>? pending;
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      path == '/agents/a' ? agent : [];
  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    writes.add((method, path, data));
    return pending?.future ??
        (method == 'PATCH'
            ? data
            : {'avatarUrl': '/api/uploads/avatar-public.png'});
  }
}

void main() {
  setUpAll(loadParityFonts);
  late Client c;
  late Workspace w;
  late bool authorized;
  final saved = <Map<String, dynamic>>[];
  setUp(() {
    c = Client()..user = RaftRecord({'id': 'viewer'});
    c.selectServer('s');
    w = Workspace(c)..server = RaftRecord({'id': 's', 'role': 'owner'});
    authorized = true;
    saved.clear();
  });
  tearDown(() async {
    w.dispose();
    await c.stream.close();
    await c.dispose();
  });
  Future<void> open(
    WidgetTester t, {
    Future<AgentAvatarUpload?> Function()? pick,
    RaftFamily family = RaftFamily.brutal,
    bool dark = false,
    bool fleet = false,
  }) async {
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(family, dark: dark),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                DialogRoute<void>(
                  context: context,
                  builder: (_) => fleet
                      ? FleetDetail(
                          controller: w,
                          computers: false,
                          initial: agent,
                        )
                      : AgentAvatarDialog(
                          controller: w,
                          agent: agent,
                          authorized: () => authorized,
                          onSaved: saved.add,
                          pickUpload: pick ?? () => Future.value(null),
                        ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
  }

  Future<void> choice(WidgetTester t, String key) async {
    await t.tap(find.byKey(ValueKey('avatar-choice-$key')));
    await t.pump();
  }

  testWidgets(
    'preset staging has no write; Save PATCHes only selected field and closes',
    (t) async {
      await open(t);
      expect(w.writes, isEmpty);
      await choice(t, 'heart');
      expect(w.writes, isEmpty);
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(w.writes.single.$1, 'PATCH');
      expect(w.writes.single.$2, '/agents/a');
      expect(w.writes.single.$3, {'avatarUrl': 'pixel:heart'});
      expect(saved.single['avatarUrl'], 'pixel:heart');
      expect(find.byType(AgentAvatarDialog), findsNothing);
    },
  );
  testWidgets('default robot sends null instead of a pixel URL', (t) async {
    await open(t);
    await choice(t, 'robot');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(w.writes.single.$3, {'avatarUrl': null});
    expect(saved.single['avatarUrl'], isNull);
  });
  testWidgets(
    'dirty close Keep editing preserves selection, Discard never writes',
    (t) async {
      await open(t);
      await choice(t, 'star');
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsOneWidget);
      await t.tap(find.text('Keep editing'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<RaftAgentAvatarPicker>(find.byType(RaftAgentAvatarPicker))
            .selectedKey,
        'star',
      );
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      await t.tap(find.text('Discard'));
      await t.pumpAndSettle();
      expect(w.writes, isEmpty);
      expect(find.text('Open'), findsOneWidget);
      expect(find.byType(AgentAvatarDialog), findsNothing);
    },
  );
  testWidgets(
    'upload decodes staged bytes and POSTs multipart avatar field only on Save',
    (t) async {
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/lY4AAAAASUVORK5CYII=',
      );
      await open(
        t,
        pick: () => Future.value(AgentAvatarUpload('public.png', bytes)),
      );
      await t.tap(find.byKey(const ValueKey('avatar-upload')));
      await t.pumpAndSettle();
      expect(w.writes, isEmpty);
      expect(find.byType(Image), findsOneWidget);
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(w.writes.single.$1, 'POST');
      expect(w.writes.single.$2, '/agents/a/avatar');
      final data = w.writes.single.$3 as FormData;
      expect(data.files.single.key, 'avatar');
      expect(data.files.single.value.filename, 'public.png');
      expect(data.files.single.value.length, bytes.length);
      expect(saved.single['avatarUrl'], '/api/uploads/avatar-public.png');
    },
  );
  testWidgets(
    'oversized upload is rejected before transfer and leaves Save disabled',
    (t) async {
      await open(
        t,
        pick: () => Future.value(
          AgentAvatarUpload('large.png', Uint8List(5 * 1024 * 1024 + 1)),
        ),
      );
      await t.tap(find.byKey(const ValueKey('avatar-upload')));
      await t.pumpAndSettle();
      expect(w.writes, isEmpty);
      expect(find.textContaining('5 MB'), findsOneWidget);
      expect(
        t
            .widget<RaftAgentAvatarPicker>(find.byType(RaftAgentAvatarPicker))
            .dirty,
        false,
      );
    },
  );
  testWidgets(
    'late upload selection after revocation never becomes a preview',
    (t) async {
      final pending = Completer<AgentAvatarUpload?>();
      await open(t, pick: () => pending.future);
      await t.tap(find.byKey(const ValueKey('avatar-upload')));
      await t.pump();
      authorized = false;
      w.notifyListeners();
      pending.complete(AgentAvatarUpload('public.png', Uint8List(8)));
      await t.pumpAndSettle();
      expect(find.byType(RaftAgentAvatarPicker), findsNothing);
      expect(w.writes, isEmpty);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'pending save blocks duplicate activation and drops revoked ACK',
    (t) async {
      w.pending = Completer<dynamic>();
      await open(t);
      await choice(t, 'sun');
      await t.tap(find.text('Save'));
      await t.pump();
      await t.tap(find.byType(RaftButton).last);
      await t.pump();
      expect(w.writes, hasLength(1));
      authorized = false;
      w.notifyListeners();
      w.pending!.complete({'avatarUrl': 'private-old-scope'});
      await t.pumpAndSettle();
      expect(saved, isEmpty);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('owned nested discard route is removed on authority revocation', (
    t,
  ) async {
    await open(t);
    await choice(t, 'sun');
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    authorized = false;
    w.notifyListeners();
    await t.pumpAndSettle();
    expect(find.byType(RaftAvatarDiscardConfirmation), findsNothing);
    expect(w.writes, isEmpty);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'actual Fleet profile trigger opens editor and account switch closes both routes',
    (t) async {
      await open(t, fleet: true);
      await t.tap(find.byKey(const ValueKey('agent-profile-avatar-trigger')));
      await t.pumpAndSettle();
      expect(find.byType(AgentAvatarDialog), findsOneWidget);
      await choice(t, 'sun');
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      c.user = RaftRecord({'id': 'other'});
      w.notifyListeners();
      await t.pumpAndSettle();
      expect(find.byType(AgentAvatarDialog), findsNothing);
      expect(find.byType(RaftAvatarDiscardConfirmation), findsNothing);
      expect(find.text('Open'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'preset controls have real 40px targets and keyboard activation $family/$dark',
      (t) async {
        await open(t, family: family, dark: dark);
        final target = find.byKey(const ValueKey('avatar-choice-tree'));
        expect(t.getSize(target), const Size(40, 40));
        final focus = find.descendant(
          of: target,
          matching: find.byType(FocusableActionDetector),
        );
        final detector = t.widget<FocusableActionDetector>(focus);
        final context = t.element(
          find.descendant(of: focus, matching: find.byType(Semantics)).first,
        );
        Focus.of(context).requestFocus();
        await t.pump();
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pump();
        expect(
          t
              .widget<RaftAgentAvatarPicker>(find.byType(RaftAgentAvatarPicker))
              .selectedKey,
          'tree',
        );
        expect(detector.enabled, true);
        expect(w.writes, isEmpty);
      },
    );
  }
  test(
    'public avatar resolution preserves pixel keys and rejects unsafe URLs',
    () {
      expect(
        agentProfileAvatarUrl(
          'https://fixture.test',
          '/api/uploads/public.png',
        ),
        'https://fixture.test/api/uploads/public.png',
      );
      expect(
        agentProfileAvatarUrl('https://fixture.test', 'pixel:mug'),
        'pixel:mug',
      );
      expect(
        agentProfileAvatarUrl('https://fixture.test', 'javascript:alert(1)'),
        isNull,
      );
      expect(
        agentProfileAvatarUrl(
          'https://fixture.test',
          'https://user:secret@fixture.test/a',
        ),
        isNull,
      );
    },
  );
}
