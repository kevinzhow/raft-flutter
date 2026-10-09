import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/create_agent_dialog.dart';
import 'package:raft_flutter/features/runtime_form_dialog.dart';
import 'package:raft_flutter/features/server_setup_gate.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/members_settings/runtime_forms.dart';

class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  late Future<dynamic> Function(String path) getFn;
  late Future<dynamic> Function(String path, dynamic data) postFn;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      getFn(path);
  @override
  Future<dynamic> post(String path, {dynamic data}) => postFn(path, data);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

const _machine = {
  'id': 'm',
  'name': 'Computer',
  'status': 'online',
  'runtimes': ['codex'],
};

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final requests = <String>[], commands = <Map<String, dynamic>>[];
  Completer<dynamic>? heldMachines, heldSave;
  bool atLimit = false, admitted = true, failCompletion = false;
  Map<String, dynamic> setupProjection = {
    'phase': 'in_progress',
    'surface': 'create_agent',
    'blocksChat': true,
    'sideEffectState': {'completion': 'enabled'},
  };
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    requests.add(path);
    if (path.endsWith('/setup-projection')) return setupProjection;
    if (path == '/servers/s/machines') {
      return heldMachines?.future ??
          {
            'machines': [_machine],
          };
    }
    if (path == '/billing/subscription') {
      return {
        'displayName': 'Free',
        'capacity': {'maxAgents': 2},
        'usage': {'agents': atLimit ? 2 : 0},
      };
    }
    if (path.endsWith('/runtime-options')) {
      return {
        'options': [
          {'runtimeId': 'codex', 'canSelectInThisContext': admitted},
        ],
      };
    }
    if (path.endsWith('/runtime-forms/v2/codex')) {
      return msRuntimeForms['forms']['codex'];
    }
    if (path.endsWith('/option-sources/model')) {
      return {
        ...(msRuntimeForms['forms']['codex']['optionSources']['model'] as Map),
        'options': [
          {'value': 'gpt-5', 'label': 'GPT-5'},
        ],
        'defaultValue': 'gpt-5',
      };
    }
    throw RaftApiException('Not found: $path', status: 404);
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    commands.add({'method': method, 'path': path, 'data': data});
    if (path.endsWith('/runtimes/rescan')) return {'accepted': true};
    if (path.endsWith('/setup-transition')) {
      if (failCompletion) {
        throw const RaftApiException('Completion failed', status: 503);
      }
      return setupProjection = {
        'phase': 'complete',
        'surface': 'complete',
        'blocksChat': false,
      };
    }
    return heldSave?.future ?? {'id': 'cindy', 'name': 'Cindy'};
  }
}

void main() {
  late _Client c;
  late _Workspace w;
  setUp(() {
    c = _Client()..user = RaftRecord({'id': 'viewer'});
    c.selectServer('s');
    w = _Workspace(c)..server = RaftRecord({'id': 's', 'role': 'owner'});
    c.getFn = (path) => w.query(path);
    c.postFn = (path, data) => w.command('POST', path, data: data);
  });
  tearDown(() async {
    w.dispose();
    await c.stream.close();
    await c.dispose();
  });
  Future<void> host(WidgetTester t, Widget child) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(390, 1000);
    addTearDown(t.view.reset);
    await t.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await t.pumpAndSettle();
  }

  CreateAgentDialog step({
    VoidCallback? onSwitch,
    void Function(Map<String, dynamic>)? onCreated,
  }) => CreateAgentDialog(
    controller: w,
    machines: const [_machine],
    initialRuntimeId: 'codex',
    onboarding: true,
    onSwitchServer: onSwitch,
    onCreated: onCreated,
  );
  Finder create() => find.ancestor(
    of: find.text('Create Cindy'),
    matching: find.byType(RaftButton),
  );
  testWidgets('setup admits array machine catalog and real workspace switch', (t) async {
    final original = c.getFn;
    c.getFn = (path) => path == '/servers/s/machines'
        ? Future.value([_machine])
        : original(path);
    var switches = 0;
    await host(t, ServerSetupGate(
      controller: w,
      onSwitchServer: () => switches++,
      child: const Text('Conversation'),
    ));
    final form = t.widget<CreateAgentDialog>(find.byType(CreateAgentDialog));
    expect(form.machines.single['id'], 'm');
    await t.ensureVisible(find.text('Switch server'));
    await t.pumpAndSettle();
    await t.tap(find.text('Switch server'));
    await t.pump();
    expect(switches, 1);
    expect(w.commands, isEmpty);
  });

  testWidgets(
    'authoritative setup directly mounts Cindy without picker or route pop',
    (t) async {
      await host(
        t,
        ServerSetupGate(controller: w, child: const Text('Conversation')),
      );
      expect(find.byType(CreateAgentDialog), findsOneWidget);
      expect(find.byType(SimpleDialog), findsNothing);
      expect(find.text('Conversation'), findsNothing);
      expect(find.text('Meet Cindy'), findsOneWidget);
      await t.ensureVisible(find.text('Create Cindy'));
      await t.pumpAndSettle();
      await t.tap(find.text('Create Cindy'));
      await t.pumpAndSettle();
      expect(w.commands.map((c) => c['path']).toList(), [
        '/agents',
        '/servers/s/setup-transition',
      ]);
      expect(find.text('Conversation'), findsOneWidget);
    },
  );
  testWidgets('setup completion retries transition without a second agent', (
    t,
  ) async {
    w.failCompletion = true;
    await host(
      t,
      ServerSetupGate(controller: w, child: const Text('Conversation')),
    );
    await t.ensureVisible(find.text('Create Cindy'));
    await t.pumpAndSettle();
    await t.tap(find.text('Create Cindy'));
    await t.pumpAndSettle();
    expect(find.text('Conversation'), findsNothing);
    expect(find.textContaining('Completion failed'), findsOneWidget);
    w.failCompletion = false;
    await t.ensureVisible(find.text('Create Cindy'));
    await t.pumpAndSettle();
    await t.tap(find.text('Create Cindy'));
    await t.pumpAndSettle();
    expect(w.commands.where((c) => c['path'] == '/agents'), hasLength(1));
    expect(
      w.commands.where(
        (c) => (c['path'] as String).endsWith('/setup-transition'),
      ),
      hasLength(2),
    );
    expect(find.text('Conversation'), findsOneWidget);
  });
  testWidgets(
    'setup switch-server remains host owned without creating an agent',
    (t) async {
      var switches = 0;
      await host(
        t,
        ServerSetupGate(
          controller: w,
          onSwitchServer: () => switches++,
          child: const Text('Conversation'),
        ),
      );
      await t.ensureVisible(find.text('Switch server'));
      await t.pumpAndSettle();
      await t.tap(find.text('Switch server'));
      await t.pump();
      expect(switches, 1);
      expect(w.commands, isEmpty);
    },
  );
  testWidgets(
    'old setup catalog cannot publish after workspace authority changes',
    (t) async {
      final oldCatalog = Completer<dynamic>();
      w.heldMachines = oldCatalog;
      await host(
        t,
        ServerSetupGate(controller: w, child: const Text('Conversation')),
      );
      expect(find.byType(CreateAgentDialog), findsNothing);
      expect(w.requests, contains('/servers/s/machines'));
      w.server = RaftRecord({'id': 'new-server', 'role': 'owner'});
      w.notifyListeners();
      await t.pumpAndSettle();
      oldCatalog.complete({
        'machines': [_machine],
      });
      await t.pumpAndSettle();
      expect(find.byType(CreateAgentDialog), findsNothing);
      expect(w.commands, isEmpty);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'setup session link actual Tab focus and keyboard activation $family/$dark',
      (t) async {
        var switches = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: RaftCindySessionLink(onPressed: () => switches++),
            ),
          ),
        );
        await t.pumpAndSettle();
        RaftCssFocusOutline outline() =>
            t
                    .widget<CustomPaint>(
                      find.byWidgetPredicate(
                        (w) =>
                            w is CustomPaint &&
                            w.foregroundPainter is RaftCssFocusOutline,
                      ),
                    )
                    .foregroundPainter!
                as RaftCssFocusOutline;
        expect(outline().enabled, false);
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump();
        expect(outline().enabled, true);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pump();
        expect(switches, 1);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: const Scaffold(body: RaftCindySessionLink(onPressed: null)),
          ),
        );
        await t.pump();
        expect(outline().enabled, false);
      },
    );
  }
  testWidgets(
    'production onboarding delegates genuine shell and v2 admission',
    (t) async {
      await host(
        t,
        RuntimeFormDialog(
          controller: w,
          machineId: 'm',
          runtimeId: 'codex',
          onboarding: true,
        ),
      );
      expect(find.byType(RaftCindySetupScreen), findsOneWidget);
      expect(find.text('Meet Cindy'), findsOneWidget);
      for (final label in ['NAME', 'DESCRIPTION', 'COMPUTER', 'MORE']) {
        expect(find.text(label), findsNothing);
      }
      expect(w.requests, contains('/servers/s/machines'));
      expect(
        w.requests,
        contains('/servers/s/machines/m/runtime-forms/v2/codex'),
      );
      expect(find.text('GPT-5'), findsOneWidget);
    },
  );
  testWidgets('real create submits canonical Cindy and fences revoked ACK', (
    t,
  ) async {
    w.heldSave = Completer<dynamic>();
    Map<String, dynamic>? created;
    await host(t, step(onCreated: (v) => created = v));
    expect(w.commands, isEmpty);
    await t.ensureVisible(create());
    await t.pumpAndSettle();
    await t.tap(create());
    await t.pump();
    expect(w.commands, hasLength(1));
    final d = w.commands.single['data'] as Map;
    expect(d['name'], 'Cindy');
    expect(d['description'], 'Onboarding Assistant');
    expect(d['avatarUrl'], 'pixel:mug');
    expect(d['onboarding'], true);
    expect(d['runtime'], 'codex');
    expect(d['machineId'], 'm');
    expect(d['formDefinitionRef'], {
      'protocolVersion': 2,
      'runtimeId': 'codex',
    });
    expect((d['formValues'] as Map)['model'], 'gpt-5');
    w.server = RaftRecord({'id': 's', 'role': 'member'});
    w.notifyListeners();
    await t.pump();
    w.heldSave!.complete({'id': 'cindy'});
    await t.pumpAndSettle();
    expect(created, isNull);
    expect(find.byType(RaftCindySetupScreen), findsNothing);
  });
  testWidgets('late machine reply cannot reveal a different server setup', (
    t,
  ) async {
    w.heldMachines = Completer<dynamic>();
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(390, 1000);
    addTearDown(t.view.reset);
    await t.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(
          body: RuntimeFormDialog(
            controller: w,
            machineId: 'm',
            runtimeId: 'codex',
            onboarding: true,
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.text('Meet Cindy'), findsOneWidget);
    w.server = RaftRecord({'id': 'other', 'role': 'owner'});
    w.notifyListeners();
    await t.pump();
    w.heldMachines!.complete({
      'machines': [_machine],
    });
    await t.pump();
    expect(find.byType(CreateAgentDialog), findsNothing);
    expect(w.requests.where((p) => p.endsWith('/runtime-options')), isEmpty);
  });
  testWidgets('capacity and unavailable admission prevent submit', (t) async {
    w.atLimit = true;
    await host(t, step());
    expect(find.textContaining('Agent limit reached'), findsOneWidget);
    expect(t.widget<RaftButton>(create()).onPressed, isNull);
    await t.pumpWidget(const SizedBox());
    w.atLimit = false;
    w.admitted = false;
    await host(t, step());
    expect(t.widget<RaftButton>(create()).onPressed, isNull);
    expect(w.commands, isEmpty);
  });
  testWidgets('rescan uses real command and removed runtime blocks create', (
    t,
  ) async {
    await host(t, step());
    w.admitted = false;
    await t.tap(find.byKey(const Key('cindy-rescan-runtimes')));
    await t.pumpAndSettle();
    expect(w.commands.single['path'], '/servers/s/machines/m/runtimes/rescan');
    expect(t.widget<RaftButton>(create()).onPressed, isNull);
  });
  testWidgets('session escape is explicit host action, no create or logout', (
    t,
  ) async {
    var switches = 0;
    await host(t, step(onSwitch: () => switches++));
    await t.ensureVisible(find.text('Switch server'));
    await t.pumpAndSettle();
    await t.tap(find.text('Switch server'));
    await t.pump();
    expect(switches, 1);
    expect(w.commands, isEmpty);
    expect(c.user!.id, 'viewer');
  });
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('responsive same-source shell ${family.name} dark=$dark', (
      t,
    ) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(1100, 800);
      addTearDown(t.view.reset);
      await t.binding.setSurfaceSize(const Size(1100, 800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: Scaffold(
            body: Center(
              child: RaftCindySetupScreen(
                fields: const Text('Fields'),
                onCreate: () {},
              ),
            ),
          ),
        ),
      );
      expect(t.getSize(find.byType(RaftCindySetupScreen)).width, 960);
      expect(t.getSize(find.byType(RaftAvatarSlot)), const Size(132, 132));
      expect(
        t.getTopLeft(find.text('Fields')).dx,
        greaterThan(t.getTopLeft(find.text('Cindy')).dx),
      );
      t.view.physicalSize = const Size(390, 844);
      await t.binding.setSurfaceSize(const Size(390, 844));
      await t.pump();
      expect(t.getSize(find.byType(RaftCindySetupScreen)).width, 374);
      expect(t.getSize(find.byType(RaftAvatarSlot)), const Size(88, 88));
      expect(
        t.getTopLeft(find.text('Fields')).dy,
        greaterThan(t.getTopLeft(find.text('Cindy')).dy),
      );
      expect(t.takeException(), isNull);
    });
  }
}
