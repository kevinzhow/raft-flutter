import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/computers_rack/computers_rack_preferences.dart';
import 'package:raft_flutter/features/computers_rack/computers_rack_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/close_registry_rack_popovers.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';

/// The Computers rack row's manual-upgrade popover and its failure / repair
/// hint popover (Web RackRowAction.tsx): Esc and an outside press close them.
/// Their own file keeps the `close_popups` part under its budget.
class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  @override
  void connect() {}
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client, this.machine);
  final Map<String, dynamic> machine;
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      path.endsWith('/machines')
      ? {
          'machines': [Map<String, dynamic>.from(machine)],
          'latestComputerVersion': '1.0.47',
        }
      : <dynamic>[];
}

Map<String, dynamic> _machine({required bool manual}) => {
  'id': 'm1',
  'name': 'Studio',
  'status': 'online',
  'isComputer': true,
  'computerVersion': '1.0.46',
  'os': 'linux',
  'hostname': 'studio.host',
  'runtimes': ['claude'],
  'computerAttachedByCurrentUser': true,
  'remoteUpgradeSupported': !manual,
  'computerUpgradeAvailable': true,
  'computerBroadcastPolicy': {
    'eligibility': 'eligible',
    'targetVersion': '1.0.47',
  },
  if (!manual) 'installerRepairHint': {'reason': 'unrecovered_operation'},
};

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DevicePreferences.load();
    ComputersRackPreferences.instance.resetForTests();
  });
  tearDown(() async {
    ComputersRackPreferences.instance.resetForTests();
    DevicePreferences.reset();
  });

  OpenSurface open({required bool manual, required String popover}) =>
      (t, size) async {
        ComputersRackPreferences.instance.setView(RackView.list);
        final client = _Client();
        final w = _Workspace(
          client,
          _machine(manual: manual),
        )..server = RaftRecord({'id': 's', 'role': 'owner', 'slug': 'fixture'});
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        addTearDown(() async {
          await t.pumpWidget(const SizedBox.shrink());
          w.services.entityDirectory.dispose();
          w.dispose();
          await client.dispose();
        });
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: closePlatform(size)),
            home: Scaffold(
              body: ComputersRackView(
                controller: w,
                phone: size.width < 768,
                onOpenComputer: (_) {},
              ),
            ),
          ),
        );
        await frames(t, 20);
        final trigger = find.byKey(
          ValueKey(manual ? 'rack-manual-upgrade-m1' : 'rack-repair-hint-m1'),
        );
        await t.ensureVisible(trigger);
        await t.tap(trigger);
        await frames(t, 20);
        return SurfaceProbe(
          isOpen: () => find.byKey(ValueKey(popover)).evaluate().isNotEmpty,
          scrim: const Offset(4, 4),
        );
      };

  registerCloseTests(rackPopoverSurfaces, {
    'rack-manual-upgrade-popover': open(
      manual: true,
      popover: 'rack-manual-upgrade-popover',
    ),
    'rack-upgrade-hint-popover': open(
      manual: false,
      popover: 'rack-repair-hint-popover',
    ),
  });
}
