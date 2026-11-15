// A computer's agent slot is Web AgentRackSlot's AvatarSlot context
// "compact-row": a 27px square sticker (raft-ui Avatar `sm`) on the rack's
// 27px agents line (MobileComputersPanel RACK_SLOTS_LINE_CLASS), in the
// cards, the list and the phone list alike. Never a 20px avatar stretched
// to the line's height.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/computers_rack/computers_rack_preferences.dart';
import 'package:raft_flutter/features/computers_rack/computers_rack_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/machines')) {
      return {
        'machines': [
          {
            'id': 'gaya',
            'name': 'gaya-k17',
            'status': 'online',
            'isComputer': true,
            'computerVersion': '1.25.3',
            'os': 'linux',
            'osRelease': 'Ubuntu 26.04',
            'runtimes': ['claude'],
          },
        ],
      };
    }
    if (path == '/agents') {
      return [
        {'id': 'a1', 'name': 'one', 'machineId': 'gaya', 'status': 'active'},
        {'id': 'a2', 'name': 'two', 'machineId': 'gaya', 'status': 'active'},
      ];
    }
    return <dynamic>[];
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DevicePreferences.load();
    ComputersRackPreferences.instance.resetForTests();
  });
  tearDown(() {
    ComputersRackPreferences.instance.resetForTests();
    DevicePreferences.reset();
  });

  for (final (label, view, phone, width) in [
    ('cards', RackView.cards, false, 1222.0),
    ('list', RackView.list, false, 1400.0),
    ('phone list', RackView.list, true, 390.0),
  ]) {
    testWidgets('$label: an agent slot is a 27px square', (t) async {
      t.view.physicalSize = Size(width, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final c = _Client();
      final w = _Workspace(c)
        ..server = RaftRecord({'id': 's', 'role': 'owner', 'slug': 'f'});
      addTearDown(() async {
        await t.pumpWidget(const SizedBox.shrink());
        w.dispose();
        await c.stream.close();
        await c.dispose();
      });
      ComputersRackPreferences.instance.setView(view);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: ComputersRackView(
              controller: w,
              phone: phone,
              onOpenComputer: (_) {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      for (final id in ['a1', 'a2']) {
        final slot = find.byKey(ValueKey('rack-slot-$id'));
        expect(slot, findsOneWidget);
        expect(t.getSize(slot), const Size(27, 27), reason: id);
        final frame = find.descendant(
          of: slot,
          matching: find.byKey(const ValueKey('mounted-avatar-frame')),
        );
        expect(t.getSize(frame), const Size(27, 27), reason: id);
      }
      // The agents line is the avatar's height (Web h-[27px]).
      expect(
        t.getSize(find.byKey(const ValueKey('rack-slots-gaya'))).height,
        27,
      );
    });
  }
}
