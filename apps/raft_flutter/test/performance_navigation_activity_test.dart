import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/features/mobile_workspace_pages.dart';
import 'package:raft_flutter/main.dart' as app;
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration_test/perf_lab/fixtures.dart';
import '../integration_test/perf_lab/navigation_activity.dart';
import '../integration_test/perf_lab/navigation_host.dart';
import 'flutter_test_config.dart' show leakDebt;

void main() {
  // Leak debt (other): see docs/development.md, Leak tracking.
  leakDebt(const ['_NativePicture']);
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'live lab restores the production root, not onboarding or a static host',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final images = await tester.runAsync(LabImages.start);
      addTearDown(() => images!.server.close(force: true));
      final channel = LabChannel('one', mixKinds(20));
      final (seed, api, client) = (await tester.runAsync(
        () => labWorkspace([channel], images!, mobile: true, ownsClient: false),
      ))!;
      seed.dispose();
      api.routes['GET /auth/me'] = (_) => {
        'id': 'alice',
        'name': 'Alice Zhang',
        'email': 'alice@example.invalid',
        'emailVerified': true,
      };
      api.routes['GET /servers'] = (_) => [
        {'id': 's1', 'slug': 'lab', 'name': 'Lab', 'role': 'owner'},
      ];
      api.routes['GET /channels/inbox'] = (_) => {'items': []};
      api.routes['GET /channels/public'] = (_) => [];
      api.routes['GET /announcements/active'] = (_) => {'announcements': []};
      api.routes['GET /servers/unread-summary'] = (_) => [];
      api.routes['GET /product-feedback/tickets'] = (_) => {
        'unread_total': 0,
        'tickets': [],
      };
      SharedPreferences.setMockInitialValues({
        'raft.origin': client.origin,
        'raft.mode': 'light',
      });
      final content = LabNavigationContent();
      await tester.pumpWidget(
        app.RaftApp(
          services: const AppServices.updatesDisabledForTestOrPreview(),
          sessionStore: client.sessionStore,
          createClient: (_, _, _) => client,
          initialLocation: Uri(path: '/s/lab'),
          nativeContent: content,
          nativeSharing: NativeSharing(supported: false),
          openWorkspaceCache: () async => null,
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(content.workspace?.server?.id, 's1');
      expect(find.byType(MobileWorkspacePages), findsOneWidget);
      expect(api.misses, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  test(
    'navigation replay mutates accepted production state and revalidates it',
    () async {
      final images = await LabImages.start();
      addTearDown(() => images.server.close(force: true));
      final channels = [
        LabChannel('one', mixKinds(20)),
        LabChannel('two', mixKinds(20)),
      ];
      final (workspace, api, client) = await labWorkspace(
        channels,
        images,
        mobile: true,
      );
      addTearDown(workspace.dispose);
      api.responseDelay = const Duration(milliseconds: 80);
      final agents = <Map<String, dynamic>>[
        {
          'id': 'agent-0',
          'name': 'worker',
          'status': 'active',
          'activity': 'online',
          'runtime': 'codex',
          'model': 'fixture',
          'machineId': 'k8',
        },
      ];
      final machines = <Map<String, dynamic>>[
        {'id': 'k8', 'name': 'K8+', 'status': 'online', 'isComputer': true},
      ];
      api.routes['GET /agents'] = (_) => agents;
      api.routes['GET /servers/s1/machines'] = (_) => {'machines': machines};
      await workspace.entityDirectory.preload();
      final activity = LabNavigationActivity(
        workspace: workspace,
        client: client,
        channels: channels,
        agents: agents,
        machines: machines,
      );
      final reads = api.hits['GET /agents']!;
      for (var n = 1; n <= 2; n++) {
        final result = await activity.transition(foreground: channels.first);
        expect(result['accepted'], {
          'messageCreate': 1,
          'messageEdit': 1,
          'messageTaskUpdate': 1,
          'backgroundMessage': 1,
          'computerStatus': 1,
          'agentActivity': 1,
          'agentCreate': 1,
          'agentDelete': 1,
          'agentRevalidation': 1,
          'editedMessageRetained': 1,
        });
        expect(result['workspaceNotifications'], greaterThanOrEqualTo(4));
        final events = result['events']! as List;
        expect(events, hasLength(9));
        expect(
          workspace.messageDomain.ledger.message(
            'one',
            'nav-live-$n',
          )?['taskStatus'],
          'in_progress',
        );
        expect(
          workspace.messageDomain.ledger.contains('two', 'nav-background-$n'),
          isTrue,
        );
        expect(workspace.entityDirectory.agent('nav-agent-$n'), isNull);
      }
      expect(api.hits['GET /agents'], greaterThan(reads));
      expect(api.completedHits['GET /agents'], api.hits['GET /agents']);
      expect(api.peakPending, greaterThanOrEqualTo(2));
      expect(api.misses, isEmpty);
    },
  );
}
