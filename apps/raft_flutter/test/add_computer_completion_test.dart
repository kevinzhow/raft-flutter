import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/add_computer_dialog.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  List<Map<String, dynamic>> machines = [];
  final commands = <(String, String, dynamic)>[];
  final reads = <String>[];
  Completer<dynamic>? registration;
  Completer<void>? deletion;
  bool failRead = false, failRegistration = false;
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    reads.add(path);
    if (path.endsWith('/machines')) {
      if (failRead) throw const RaftApiException('Temporary read failure.');
      return {'machines': machines.map(Map<String, dynamic>.from).toList()};
    }
    return <dynamic>[];
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    commands.add((method, path, data));
    if (method == 'POST') {
      if (failRegistration) {
        throw const RaftApiException('Failed to register computer');
      }
      return registration?.future ??
          {
            'machine': {'id': 'placeholder'},
          };
    }
    if (method == 'DELETE') await deletion?.future;
    return <String, dynamic>{};
  }
}

Map<String, dynamic> _computer(
  String id, {
  bool online = true,
  bool owned = true,
  bool computer = true,
}) => {
  'id': id,
  'name': id,
  'hostname': '$id-host',
  'os': 'linux',
  'status': online ? 'online' : 'offline',
  'isComputer': computer,
  'computerAttachedByCurrentUser': owned,
};

class _Fixture {
  final c = _Client();
  late final w = _Workspace(c)
    ..server = RaftRecord({'id': 's', 'role': 'owner', 'slug': 'fixture'});

  Future<void> open(
    WidgetTester t, {
    RaftFamily family = RaftFamily.elegant,
    bool dark = false,
    double width = 1280,
  }) async {
    t.view.physicalSize = Size(width, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    addTearDown(() async {
      if (w.registration case final pending? when !pending.isCompleted) {
        pending.complete({
          'machine': {'id': 'placeholder'},
        });
      }
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
      w.dispose();
      await c.stream.close();
      await c.dispose();
    });
    await w.entityDirectory.preload();
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(family, dark: dark),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: RaftButton(
                label: 'Open computers',
                onPressed: () => showAddComputerDialog(context, w),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open computers'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('add-computer-next')));
    await t.pumpAndSettle();
  }

  Future<void> event(WidgetTester t) async {
    c.stream.add(const RaftEvent('machine:created', {'machineId': 'actual'}));
    await t.pump(const Duration(milliseconds: 200));
    await t.pumpAndSettle();
  }

  int get computerReads => w.reads.where((p) => p.endsWith('/machines')).length;
}

void main() {
  for (final (family, dark) in raftThemeMatrix([
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ])) {
    for (final width in [390.0, 1280.0]) {
      testWidgets(
        '$family/$dark/$width the real Computer finishes the placeholder registration and Done targets its identity',
        (t) async {
          final f = _Fixture();
          await f.open(t, family: family, dark: dark, width: width);
          expect(
            find.text('Waiting for computer to connect...'),
            findsOneWidget,
          );
          f.w.machines = [_computer('actual')];
          await f.event(t);
          expect(find.text('COMPUTER CONNECTED'), findsOneWidget);
          expect(find.text('Waiting for computer to connect...'), findsNothing);
          expect(
            find.byKey(const ValueKey('add-computer-confirm-match')),
            findsNothing,
          );
          expect(
            t.widget<TextField>(find.byType(TextField)).controller!.text,
            'actual-host',
          );
          await t.enterText(find.byType(TextField), 'My connected computer');
          await t.tap(find.widgetWithText(RaftRecipeButton, 'Done'));
          await t.pumpAndSettle();
          expect(find.byType(RaftAddComputerDialog), findsNothing);
          final rename = f.w.commands.singleWhere((c) => c.$1 == 'PATCH');
          expect(rename.$2, '/servers/s/machines/actual');
          expect(rename.$3, {'name': 'My connected computer'});
          expect(f.w.commands.where((c) => c.$1 == 'DELETE').map((c) => c.$2), [
            '/servers/s/machines/placeholder',
          ]);
          final reads = f.computerReads;
          await t.pump(const Duration(seconds: 10));
          expect(
            f.computerReads,
            reads,
            reason: 'closed dialog leaves no fallback poll',
          );
          expect(t.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'a dropped event and a failed recovery read retry without inventing success',
    (t) async {
      final f = _Fixture();
      await f.open(t);
      f.w.failRead = true;
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
      expect(find.text('Waiting for computer to connect...'), findsOneWidget);
      f.w.failRead = false;
      f.w.machines = [_computer('actual')];
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
      expect(find.text('COMPUTER CONNECTED'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'an online event before the registration response is still observed',
    (t) async {
      final f = _Fixture();
      f.w.registration = Completer<dynamic>();
      await f.open(t);
      f.w.machines = [_computer('placeholder', computer: false)];
      await f.event(t);
      f.w.registration!.complete({
        'machine': {'id': 'placeholder'},
      });
      await t.pumpAndSettle();
      expect(find.text('COMPUTER CONNECTED'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('a real Computer event can precede the registration response', (
    t,
  ) async {
    final f = _Fixture();
    f.w.registration = Completer<dynamic>();
    await f.open(t);
    f.w.machines = [_computer('actual')];
    await f.event(t);
    f.w.registration!.complete({
      'machine': {'id': 'placeholder'},
    });
    await t.pumpAndSettle();
    expect(find.text('COMPUTER CONNECTED'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('registration failure can retry and clears the old error', (
    t,
  ) async {
    final f = _Fixture();
    f.w.failRegistration = true;
    await f.open(t);
    expect(find.text('Failed to register computer'), findsOneWidget);
    f.w.failRegistration = false;
    await t.tap(find.byKey(const ValueKey('add-computer-next')));
    await t.pumpAndSettle();
    expect(find.text('Failed to register computer'), findsNothing);
    f.w.machines = [_computer('actual')];
    await f.event(t);
    await t.tap(find.widgetWithText(RaftRecipeButton, 'Done'));
    await t.pumpAndSettle();
    expect(find.byType(RaftAddComputerDialog), findsNothing);
    expect(f.w.commands.where((c) => c.$1 == 'POST'), hasLength(2));
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'cancel while registration is pending cleans only its late placeholder',
    (t) async {
      final f = _Fixture();
      f.w.registration = Completer<dynamic>();
      await f.open(t);
      await t.tap(find.widgetWithText(RaftRecipeButton, 'Cancel'));
      await t.pumpAndSettle();
      expect(find.byType(RaftAddComputerDialog), findsNothing);
      f.w.registration!.complete({
        'machine': {'id': 'late-placeholder'},
      });
      await t.pumpAndSettle();
      expect(f.w.commands.where((c) => c.$1 == 'DELETE').map((c) => c.$2), [
        '/servers/s/machines/late-placeholder',
      ]);
      expect(f.w.commands.where((c) => c.$1 == 'PATCH'), isEmpty);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'a canceled attempt cannot advance while placeholder deletion is pending',
    (t) async {
      final f = _Fixture();
      await f.open(t);
      f.w.deletion = Completer<void>();
      await t.tap(find.widgetWithText(RaftRecipeButton, 'Cancel'));
      await t.pump();
      f.w.machines = [_computer('late')];
      await f.event(t);
      final advanced = find.text('COMPUTER CONNECTED').evaluate().isNotEmpty;
      f.w.deletion!.complete();
      await t.pumpAndSettle();
      expect(
        advanced,
        isFalse,
        reason: 'cancel retires the attempt before awaiting cleanup',
      );
      expect(find.byType(RaftAddComputerDialog), findsNothing);
      expect(f.w.commands.where((c) => c.$1 == 'PATCH'), isEmpty);
    },
  );

  testWidgets('hidden windows stop polling and resumed windows recover', (
    t,
  ) async {
    final f = _Fixture();
    await f.open(t);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    final reads = f.computerReads;
    f.w.machines = [_computer('actual')];
    await t.pump(const Duration(seconds: 10));
    expect(f.computerReads, reads);
    expect(find.text('Waiting for computer to connect...'), findsOneWidget);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();
    expect(find.text('COMPUTER CONNECTED'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'another member or an already-online computer cannot finish this attempt',
    (t) async {
      final f = _Fixture();
      f.w.machines = [_computer('existing')];
      await f.open(t);
      f.w.machines = [
        _computer('existing'),
        _computer('foreign', owned: false),
        _computer('plain-daemon', computer: false),
      ];
      await f.event(t);
      expect(find.text('COMPUTER CONNECTED'), findsNothing);
      expect(find.text('Waiting for computer to connect...'), findsOneWidget);
      expect(f.w.commands.where((c) => c.$1 == 'PATCH'), isEmpty);
    },
  );

  testWidgets(
    'a resumed owned computer requires confirmation before naming or completing',
    (t) async {
      final f = _Fixture();
      f.w.machines = [_computer('resumed', online: false)];
      await f.open(t);
      f.w.machines = [_computer('resumed')];
      await f.event(t);
      expect(find.text('COMPUTER CONNECTED'), findsOneWidget);
      final confirm = find.byKey(const ValueKey('add-computer-confirm-match'));
      expect(confirm, findsOneWidget);
      final done = find.widgetWithText(RaftRecipeButton, 'Done');
      expect(t.widget<RaftRecipeButton>(done).disabled, isTrue);
      final semantics = t.ensureSemantics();
      expect(
        t.getSemantics(confirm),
        isSemantics(
          label: 'This is the computer I just set up (resumed-host).',
          hasCheckedState: true,
          isChecked: false,
          hasTapAction: true,
        ),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pump();
      semantics.dispose();
      expect(t.widget<RaftRecipeButton>(done).disabled, isFalse);
      await t.tap(done);
      await t.pumpAndSettle();
      expect(
        f.w.commands.any((c) => c.$1 == 'PATCH' && c.$2.endsWith('/resumed')),
        isTrue,
      );
      expect(
        f.w.commands.any((c) => c.$1 == 'DELETE' && c.$2.endsWith('/resumed')),
        isFalse,
      );
      expect(find.byType(RaftAddComputerDialog), findsNothing);
    },
  );

  testWidgets(
    'canceling an ambiguous match removes only the unused placeholder',
    (t) async {
      final f = _Fixture();
      await f.open(t);
      f.w.machines = [_computer('first'), _computer('second')];
      await f.event(t);
      expect(
        find.byKey(const ValueKey('add-computer-confirm-match')),
        findsOneWidget,
      );
      await t.tap(find.byType(RaftCloseButton));
      await t.pumpAndSettle();
      expect(f.w.commands.where((c) => c.$1 == 'DELETE').map((c) => c.$2), [
        '/servers/s/machines/placeholder',
      ]);
      expect(f.w.commands.where((c) => c.$1 == 'PATCH'), isEmpty);
      expect(find.byType(RaftAddComputerDialog), findsNothing);
    },
  );

  testWidgets(
    'canceling the wait stops recovery reads and late online events',
    (t) async {
      final f = _Fixture();
      await f.open(t);
      await t.tap(find.widgetWithText(RaftRecipeButton, 'Cancel'));
      await t.pumpAndSettle();
      final reads = f.computerReads;
      f.w.machines = [_computer('late')];
      await t.pump(const Duration(seconds: 10));
      expect(f.computerReads, reads);
      expect(find.byType(RaftAddComputerDialog), findsNothing);
      expect(f.w.commands.where((c) => c.$1 == 'PATCH'), isEmpty);
    },
  );

  testWidgets(
    'losing authority closes the wait without sending commands into the next workspace',
    (t) async {
      final f = _Fixture();
      await f.open(t);
      f.c.selectServer('other');
      f.w.server = RaftRecord({'id': 'other', 'role': 'owner'});
      f.w.notifyListeners();
      await t.pumpAndSettle();
      final reads = f.computerReads;
      f.w.machines = [_computer('actual')];
      await t.pump(const Duration(seconds: 10));
      expect(find.byType(RaftAddComputerDialog), findsNothing);
      expect(f.computerReads, reads);
      expect(
        f.w.commands.where((c) => c.$2.startsWith('/servers/other/')),
        isEmpty,
      );
    },
  );
}
