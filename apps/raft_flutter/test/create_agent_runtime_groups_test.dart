// Create agent: the runtime picker groups the server's runtime-options rows
// (Web components/agent/runtimePickerOptions.ts, RuntimeConfigFields.tsx
// RuntimeSelectControl), the computer picker orders and disables like Web,
// and an old record of pre-admission never reappears.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/create_agent_dialog.dart';
import 'package:raft_flutter/features/managed_agent_launcher.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/members_settings/runtime_forms.dart';

class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  List<Map<String, dynamic>> machines = [];
  List<Map<String, dynamic>> options = [];
  final posts = <Map<String, dynamic>>[];
  final reads = <String>[];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    reads.add(path);
    if (path == '/servers/s/machines') return {'machines': machines};
    if (path.endsWith('/runtime-options')) return {'options': options};
    if (path.endsWith('/runtime-forms/v2/codex')) {
      return msRuntimeForms['forms']['codex'];
    }
    if (path.endsWith('/runtime-forms/v2/codex/option-sources/model')) {
      return {
        ...(msRuntimeForms['forms']['codex']['optionSources']['model'] as Map),
        'options': [
          {'value': 'gpt-5', 'label': 'GPT-5'},
        ],
        'defaultValue': 'gpt-5',
        'customValueAllowed': true,
      };
    }
    throw RaftApiException('Not found: $path', status: 404);
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    posts.add({'method': method, 'path': path, 'data': data});
    return {'id': 'agent-new', 'name': data['name']};
  }
}

Map<String, dynamic> _option(
  String id, {
  bool selectable = true,
  String status = 'available',
  String reason = 'available',
}) => {
  'runtimeId': id,
  'canSelectInThisContext': selectable,
  'runtimeFormV2': {'protocolVersion': 2},
  'capabilityStatus': status,
  'admissionReason': reason,
};

Map<String, dynamic> _machine(
  String id,
  String name, {
  String status = 'online',
  String? hostname,
  bool mine = false,
  String? daemon,
}) => {
  'id': id,
  'name': name,
  'status': status,
  'hostname': ?hostname,
  'runtimes': ['codex', 'claude', 'qoder'],
  'computerAttachedByCurrentUser': mine,
  'daemonVersion': ?daemon,
};

void main() {
  late _Client c;
  late _Workspace w;
  setUp(() {
    c = _Client()..user = RaftRecord({'id': 'alice'});
    c.selectServer('s');
    w = _Workspace(c)..server = RaftRecord({'id': 's', 'role': 'owner'});
  });
  tearDown(() async {
    w.dispose();
    await c.stream.close();
    await c.dispose();
  });

  Future<void> open(WidgetTester t, {Size size = const Size(390, 1400)}) async {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showManagedAgentForm(context, w, initialName: 'planner'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  Future<void> openRuntimeList(WidgetTester t) async {
    await t.tap(find.byType(RaftSelectField<String>).last);
    await t.pumpAndSettle();
  }

  List<RaftMenuPopupEntry> entries(WidgetTester t) =>
      t.widget<RaftMenuPopupBackend>(find.byType(RaftMenuPopupBackend)).entries;

  final admission = [
    _option('codex'),
    _option('qoder'),
    _option('claude', selectable: false, status: 'update_required'),
    _option('grok', selectable: false, status: 'not_installed'),
    _option('pi', selectable: false),
  ];

  for (final size in const [Size(856, 944), Size(944, 856), Size(390, 844)]) {
    testWidgets(
      'runtimes are grouped, Show all supported never becomes the value $size',
      (t) async {
        w
          ..machines = [_machine('mbp', 'Studio Mac')]
          ..options = admission;
        await open(t, size: size);
        expect(find.text('Codex CLI'), findsOneWidget);
        await openRuntimeList(t);
        expect(
          [
            for (final e in entries(t))
              e.kind == RaftMenuPopupEntryKind.item
                  ? e.label
                  : '[${e.kind.name}] ${e.label}',
          ],
          [
            '[heading] Ready on this computer',
            'Codex CLI',
            'Qoder Experimental',
            '[separator] ',
            '[heading] Needs a Raft Computer update',
            'Claude Code',
            '[separator] ',
            'Show all supported',
          ],
        );
        // Not installed and "not offered here" rows stay out until asked for.
        expect(find.text('Grok Build'), findsNothing);
        expect(find.text('Pi'), findsNothing);
        // Update-required rows are disabled and drop the suffix their heading says.
        expect(entries(t)[5].enabled, isFalse);
        expect(find.textContaining('Update required'), findsNothing);

        await t.tap(find.text('Show all supported'));
        await t.pumpAndSettle();
        // The list stays open, the value is unchanged, and the group appears.
        expect(find.byType(RaftMenuPopupBackend), findsOneWidget);
        expect(find.text('Not installed on this computer'), findsOneWidget);
        expect(find.text('Grok Build'), findsOneWidget);
        expect(find.text('Show installed only'), findsOneWidget);
        await t.tap(find.text('Show installed only'));
        await t.pumpAndSettle();
        expect(find.text('Grok Build'), findsNothing);

        await t.tap(find.textContaining('Qoder', findRichText: true));
        await t.pumpAndSettle();
        expect(find.byType(RaftMenuPopupBackend), findsNothing);
        expect(find.text('Show all supported'), findsNothing);
        expect(find.byKey(const ValueKey('runtime-model')), findsNothing);
      },
    );
  }

  testWidgets(
    'keyboard reaches the action row, which toggles without selecting',
    (t) async {
      w
        ..machines = [_machine('mbp', 'Studio Mac')]
        ..options = admission;
      await open(t);
      await openRuntimeList(t);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.text('Grok Build'), findsOneWidget);
      expect(find.byType(RaftMenuPopupBackend), findsOneWidget);
      expect(find.text('Codex CLI'), findsWidgets);
    },
  );

  testWidgets('another computer starts collapsed again', (t) async {
    w
      ..machines = [_machine('a', 'Alpha', mine: true), _machine('b', 'Beta')]
      ..options = admission;
    await open(t);
    await openRuntimeList(t);
    await t.tap(find.text('Show all supported'));
    await t.pumpAndSettle();
    expect(find.text('Grok Build'), findsOneWidget);
    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
    await t.tap(find.byType(RaftSelectField<String>).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Beta'));
    await t.pumpAndSettle();
    await openRuntimeList(t);
    expect(find.text('Grok Build'), findsNothing);
    expect(find.text('Show all supported'), findsOneWidget);
  });

  testWidgets(
    'computers are ordered mine first, labelled, and offline ones are disabled',
    (t) async {
      w
        ..machines = [
          _machine('x', 'Office', status: 'offline', hostname: 'office.local'),
          _machine('y', 'Rig', hostname: 'rig.local'),
          _machine('z', 'Laptop', mine: true),
        ]
        ..options = admission;
      await open(t);
      // The first usable computer is the viewer's own.
      expect(find.text('Laptop'), findsOneWidget);
      await t.tap(find.byType(RaftSelectField<String>).first);
      await t.pumpAndSettle();
      final rows = entries(t);
      expect(rows.map((e) => e.label), [
        'Laptop',
        'Office (office.local) · Offline',
        'Rig (rig.local)',
      ]);
      expect(rows.map((e) => e.enabled), [true, false, true]);
    },
  );

  testWidgets(
    'a minimum daemon version disables older computers and says why',
    (t) async {
      w
        ..machines = [
          _machine('old', 'Old', daemon: '1.2.0'),
          _machine('new', 'New', daemon: '1.9.0'),
          _machine('unknown', 'Unknown'),
        ]
        ..options = admission;
      await t.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showRaftForm<bool>(
                  context,
                  builder: (_) => CreateAgentDialog(
                    controller: w,
                    machines: w.machines,
                    minimumDaemonVersion: '1.5.0',
                    initialName: 'planner',
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.text('New'), findsOneWidget);
      expect(
        find.text('Use a Computer updated to 1.5.0 or newer.'),
        findsOneWidget,
      );
      await t.tap(find.byType(RaftSelectField<String>).first);
      await t.pumpAndSettle();
      expect(entries(t).map((e) => e.label), [
        'Old · Update required',
        'New',
        'Unknown · Update required',
      ]);
      expect(entries(t).map((e) => e.enabled), [false, true, false]);
    },
  );

  testWidgets(
    'no pre-admission picker: before the rows arrive there is no runtime and no form',
    (t) async {
      w
        ..machines = [_machine('mbp', 'Studio Mac')]
        ..options = [];
      await open(t);
      expect(find.text('Select…'), findsOneWidget);
      expect(find.text('Claude Opus'), findsNothing);
      expect(find.text('More'), findsNothing);
      expect(w.reads.any((p) => p.contains('/runtime-models/')), isFalse);
      // Create stays off: there is nothing to create with.
      await t.tap(
        find.descendant(
          of: find.byType(RaftAgentDialogButton),
          matching: find.text('Create'),
        ),
      );
      await t.pump();
      expect(w.posts, isEmpty);
    },
  );

  testWidgets(
    'onboarding keeps one flat runtime list with suffixes and shows Advanced',
    (t) async {
      w
        ..machines = [_machine('mbp', 'Studio Mac')]
        ..options = [
          _option('codex'),
          _option('grok', selectable: false, status: 'not_installed'),
        ];
      t.view
        ..physicalSize = const Size(390, 1000)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CreateAgentDialog(
                controller: w,
                machines: w.machines,
                onboarding: true,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byType(RaftSelectField<String>).first);
      await t.pumpAndSettle();
      // Flat: no headings, no action row; the not-installed row says so.
      expect(entries(t).map((e) => e.kind).toSet(), {
        RaftMenuPopupEntryKind.item,
      });
      expect(entries(t).map((e) => e.label), [
        'Codex CLI',
        'Grok Build (not installed)',
      ]);
      expect(entries(t).map((e) => e.enabled), [true, false]);
      await t.tapAt(const Offset(5, 5));
      await t.pumpAndSettle();
      // The same form as a normal create: its technical fields sit in the
      // collapsed Advanced section, not hidden.
      expect(find.text('Advanced'), findsOneWidget);
    },
  );
}
