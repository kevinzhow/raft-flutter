import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/add_computer_dialog.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

/// The waiting banner's spinner never stops animating, so settle by time.
Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 400));
}

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
  bool failRead = false, failRename = false;
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
    if (method == 'PATCH' && failRename) {
      throw RaftApiException.response(
        'Could not save computer name.',
        status: 503,
        body: {'error': 'Could not save computer name.'},
      );
    }
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
    bool dark = false,
    double width = 1280,
    ValueChanged<String>? onOpen,
  }) async {
    t.view.physicalSize = Size(width, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
      w.dispose();
      await c.stream.close();
      await c.dispose();
    });
    await w.entityDirectory.preload();
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: dark),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: RaftButton(
                label: 'Open computers',
                onPressed: () =>
                    showAddComputerDialog(context, w, onOpenComputer: onOpen),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open computers'));
    await _settle(t);
  }

  Future<void> event(WidgetTester t) async {
    c.stream.add(const RaftEvent('machine:created', {'machineId': 'actual'}));
    await t.pump(const Duration(milliseconds: 200));
    await _settle(t);
  }

  int get computerReads => w.reads.where((p) => p.endsWith('/machines')).length;
}

void main() {
  testWidgets('late computer details replace loading and prefill the name', (
    t,
  ) async {
    final f = _Fixture();
    await f.open(t);
    f.w.machines = [
      _computer('actual')
        ..remove('hostname')
        ..remove('os'),
    ];
    await f.event(t);
    expect(find.textContaining('Unknown OS'), findsNothing);
    expect(
      find.byKey(const ValueKey('add-computer-details-loading')),
      findsOneWidget,
    );
    expect(
      t.widget<TextField>(find.byType(TextField)).decoration!.hintText,
      'Computer name',
    );
    expect(
      t.widget<RaftButton>(find.widgetWithText(RaftButton, 'Done')).disabled,
      isTrue,
    );
    f.c.stream.add(
      const RaftEvent('machine:capabilities', {
        'machineId': 'actual',
        'hostname': 'actual-host',
        'os': 'macOS',
      }),
    );
    await _settle(t);
    expect(find.text('actual-host — macOS'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('add-computer-details-loading')),
      findsNothing,
    );
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      'actual-host',
    );
    await t.tap(find.widgetWithText(RaftButton, 'Done'));
    await _settle(t);
    expect(find.byType(RaftAddComputerDialog), findsNothing);
    expect(f.w.commands.where((c) => c.$1 == 'DELETE'), isEmpty);
    expect(f.w.commands.where((c) => c.$1 == 'POST'), isEmpty);
  });

  testWidgets('details recovery preserves a name the user has already typed', (
    t,
  ) async {
    final f = _Fixture();
    await f.open(t);
    f.w.machines = [_computer('actual')..remove('os')];
    await f.event(t);
    await t.enterText(find.byType(TextField), 'My chosen name');
    f.w.machines = [_computer('actual')..['os'] = 'macOS'];
    // No socket event: the incomplete details must keep the recovery poll.
    await t.pump(const Duration(seconds: 3));
    await _settle(t);
    expect(find.text('actual-host — macOS'), findsOneWidget);
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      'My chosen name',
    );
    await t.tap(find.widgetWithText(RaftButton, 'Done'));
    await _settle(t);
    expect(find.byType(RaftAddComputerDialog), findsNothing);
    expect(f.w.commands.singleWhere((c) => c.$1 == 'PATCH').$3, {
      'name': 'My chosen name',
    });
  });

  for (final dark in raftThemeMatrix([false, true])) {
    for (final width in [390.0, 1280.0]) {
      testWidgets(
        '${dark ? 'dark' : 'light'}/$width the real Computer connects without any registration and Done targets its identity',
        (t) async {
          final f = _Fixture();
          await f.open(t, dark: dark, width: width);
          expect(
            find.text('Waiting for computer to connect...'),
            findsOneWidget,
          );
          f.w.machines = [_computer('actual')];
          await f.event(t);
          expect(find.text('Computer connected'), findsOneWidget);
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
          await t.tap(find.widgetWithText(RaftButton, 'Done'));
          await _settle(t);
          expect(find.byType(RaftAddComputerDialog), findsNothing);
          final rename = f.w.commands.singleWhere((c) => c.$1 == 'PATCH');
          expect(rename.$2, '/servers/s/machines/actual');
          expect(rename.$3, {'name': 'My connected computer'});
          expect(f.w.commands.where((c) => c.$1 == 'DELETE'), isEmpty);
          expect(f.w.commands.where((c) => c.$1 == 'POST'), isEmpty);
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
      await _settle(t);
      expect(find.text('Waiting for computer to connect...'), findsOneWidget);
      f.w.failRead = false;
      f.w.machines = [_computer('actual')];
      await t.pump(const Duration(seconds: 3));
      await _settle(t);
      expect(find.text('Computer connected'), findsOneWidget);
      expect(t.takeException(), isNull);
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
    await _settle(t);
    expect(find.text('Computer connected'), findsOneWidget);
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
      expect(find.text('Computer connected'), findsNothing);
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
      expect(find.text('Computer connected'), findsOneWidget);
      final confirm = find.byKey(const ValueKey('add-computer-confirm-match'));
      expect(confirm, findsOneWidget);
      final done = find.widgetWithText(RaftButton, 'Done');
      expect(t.widget<RaftButton>(done).disabled, isTrue);
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
      expect(t.widget<RaftButton>(done).disabled, isFalse);
      await t.tap(done);
      await _settle(t);
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
    'canceling the wait stops recovery reads and late online events',
    (t) async {
      final f = _Fixture();
      await f.open(t);
      await t.tap(find.widgetWithText(RaftButton, 'Cancel'));
      await _settle(t);
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
      await _settle(t);
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

  testWidgets('opening the dialog registers nothing and opens on the command', (
    t,
  ) async {
    final f = _Fixture();
    await f.open(t);
    expect(find.text('Connect computer'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('add-machine-own-computer-hint')),
      findsOne,
    );
    expect(find.byKey(const ValueKey('add-computer-next')), findsNothing);
    expect(find.text('Cloud Computer'), findsNothing);
    expect(find.text('Experimental'), findsNothing);
    expect(f.w.commands, isEmpty);
    await t.tap(find.widgetWithText(RaftButton, 'Cancel'));
    await _settle(t);
    expect(find.byType(RaftAddComputerDialog), findsNothing);
    expect(f.w.commands, isEmpty, reason: 'Cancel leaves nothing behind');
  });

  testWidgets('a rename failure stays visible and Done retries the same row', (
    t,
  ) async {
    final f = _Fixture();
    await f.open(t);
    f.w.machines = [_computer('actual')];
    await f.event(t);
    await t.enterText(find.byType(TextField), 'Renamed');
    f.w.failRename = true;
    await t.tap(find.widgetWithText(RaftButton, 'Done'));
    await _settle(t);
    expect(find.byType(RaftAddComputerDialog), findsOneWidget);
    expect(find.text('Could not save computer name.'), findsOneWidget);
    f.w.failRename = false;
    await t.tap(find.widgetWithText(RaftButton, 'Done'));
    await _settle(t);
    expect(find.byType(RaftAddComputerDialog), findsNothing);
    expect(f.w.commands.where((c) => c.$1 == 'PATCH').map((c) => c.$2), [
      '/servers/s/machines/actual',
      '/servers/s/machines/actual',
    ]);
  });

  testWidgets('Done opens the connected computer', (t) async {
    final f = _Fixture();
    final opened = <String>[];
    await f.open(t, onOpen: opened.add);
    f.w.machines = [_computer('actual')];
    await f.event(t);
    await t.tap(find.widgetWithText(RaftButton, 'Done'));
    await _settle(t);
    expect(opened, ['actual']);
  });
}
