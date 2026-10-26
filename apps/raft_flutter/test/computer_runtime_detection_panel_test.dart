// The Computer detail page for WP-COMP (Web MachineDetailPanel v1.21.23):
// the runtime detection notice with Rescan runtimes, the "What's new" release
// notes and the creator link.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/computer_detail_view.dart';
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
  final writes = <(String, String)>[];

  /// Completes the rescan request; null answers at once.
  Completer<void>? rescanGate;
  Object? rescanError;
  Map<String, dynamic> envelope = {};

  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/machines')) return {'machines': [], ...envelope};
    return [];
  }

  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    if (method == 'GET') return get(path, query: query);
    writes.add((method, path));
    if (path.endsWith('/runtimes/rescan')) {
      await rescanGate?.future;
      if (rescanError != null) throw rescanError!;
    }
    return <String, dynamic>{};
  }
}

Map<String, dynamic> machine({
  String status = 'online',
  Map<String, dynamic>? detection,
  Map<String, dynamic>? creator,
  String version = '1.4.0',
}) => {
  'id': 'm1',
  'name': 'Studio Mac',
  'isComputer': true,
  'status': status,
  'computerVersion': version,
  'runtimes': ['claude'],
  'creator': ?creator,
  'runtimeDetection': ?detection,
};

const incomplete = {
  'status': 'incomplete',
  'reason': 'deadline',
  'unfinishedRuntimes': ['codex', 'grok'],
};

void main() {
  late _Client client;
  late WorkspaceController w;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    client = _Client();
  });
  tearDown(() async {
    w.dispose();
    await client.stream.close();
    await client.dispose();
  });

  Future<void> mount(
    WidgetTester t,
    Map<String, dynamic> m, {
    String role = 'owner',
    Locale? locale,
  }) async {
    w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'role': role, 'slug': 'fixture'});
    t.view.physicalSize = const Size(900, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: raftTheme(),
        home: Scaffold(
          body: ComputerDetailPanel(
            controller: w,
            machine: m,
            remoteUpgradeV2: true,
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
  }

  // The directory's one-shot grace timer ends with the directory.
  void scenario(String name, Future<void> Function(WidgetTester t) body) =>
      testWidgets(name, (t) async {
        await body(t);
        await t.pumpWidget(const SizedBox.shrink());
        w.services.entityDirectory.dispose();
      });

  final notice = find.byKey(const ValueKey('machine-runtime-detection'));
  final rescan = find.byKey(const ValueKey('machine-runtime-detection-rescan'));
  final hint = find.byKey(
    const ValueKey('machine-runtime-detection-rescan-hint'),
  );
  final error = find.byKey(
    const ValueKey('machine-runtime-detection-rescan-error'),
  );

  group('runtime detection notice', () {
    scenario('an unreported detection shows nothing', (t) async {
      await mount(t, machine());
      expect(notice, findsNothing);
    });

    scenario('a complete detection shows nothing', (t) async {
      await mount(t, machine(detection: {'status': 'complete'}));
      expect(notice, findsNothing);
    });

    scenario(
      'pending says the list is the last confirmed one, with no rescan',
      (t) async {
        await mount(t, machine(detection: {'status': 'pending'}));
        expect(notice, findsOneWidget);
        expect(
          find.text(
            'Detecting runtimes… the list below is the last confirmed one.',
          ),
          findsOneWidget,
        );
        expect(rescan, findsNothing);
        expect(hint, findsNothing);
      },
    );

    scenario('incomplete names the reason and what was not checked', (t) async {
      await mount(t, machine(detection: incomplete));
      expect(
        find.text(
          'Runtime detection did not finish (timed out). Not checked: Codex CLI, Grok Build. Their last known state is shown.',
        ),
        findsOneWidget,
      );
      // The inventory below is still drawn (unconfirmed, not unavailable).
      expect(find.text('Claude Code'), findsWidgets);
    });

    scenario('incomplete with nothing listed falls back to the shorter text', (
      t,
    ) async {
      await mount(
        t,
        machine(detection: {'status': 'incomplete', 'reason': 'cancelled'}),
      );
      expect(
        find.text(
          'Runtime detection did not finish (it was cancelled). The list below is the last confirmed one.',
        ),
        findsOneWidget,
      );
    });

    scenario('an offline Computer shows no detection notice', (t) async {
      await mount(t, machine(status: 'offline', detection: incomplete));
      expect(notice, findsNothing);
    });

    scenario(
      'Rescan runtimes posts to the rescan route and shows the running state',
      (t) async {
        client.rescanGate = Completer<void>();
        await mount(t, machine(detection: incomplete));
        expect(find.text('Rescan runtimes'), findsOneWidget);
        await t.tap(rescan);
        await t.pump();
        expect(client.writes.where((w) => w.$2.endsWith('/runtimes/rescan')), [
          ('POST', '/servers/s/machines/m1/runtimes/rescan'),
        ]);
        expect(find.text('Rescanning…'), findsOneWidget);
        client.rescanGate!.complete();
        await t.pump();
        expect(find.text('Rescan runtimes'), findsOneWidget);
        expect(error, findsNothing);
      },
    );

    scenario('a 403 is refused with its own message', (t) async {
      client.rescanError = const RaftApiException('forbidden', status: 403);
      await mount(t, machine(detection: incomplete));
      await t.tap(rescan);
      await t.pump();
      expect(
        find.text(
          "Rescan was refused: only the Computer's creator or someone with the Edit Machines capability can rescan.",
        ),
        findsOneWidget,
      );
      // Rescanning again is possible.
      expect(find.text('Rescan runtimes'), findsOneWidget);
    });

    scenario('any other failure asks to check the Computer is online', (
      t,
    ) async {
      client.rescanError = const RaftApiException('boom', status: 502);
      await mount(t, machine(detection: incomplete));
      await t.tap(rescan);
      await t.pump();
      expect(
        find.text(
          'Rescan request failed. Check the Computer is online and try again.',
        ),
        findsOneWidget,
      );
    });

    scenario('a member who did not create it is told who can rescan', (
      t,
    ) async {
      await mount(
        t,
        machine(detection: incomplete, creator: {'id': 'bob', 'name': 'bob'}),
        role: 'member',
      );
      expect(rescan, findsNothing);
      expect(
        find.text(
          "Ask the Computer's creator or someone with the Edit Machines capability to rescan.",
        ),
        findsOneWidget,
      );
    });

    scenario('the creator may rescan without Edit Machines', (t) async {
      await mount(
        t,
        machine(
          detection: incomplete,
          creator: {'id': 'alice', 'name': 'alice'},
        ),
        role: 'member',
      );
      expect(rescan, findsOneWidget);
      expect(hint, findsNothing);
    });

    scenario('the Chinese text is the Web zh-cn wording', (t) async {
      await mount(
        t,
        machine(detection: incomplete),
        locale: const Locale('zh'),
      );
      expect(
        find.text('运行时检测未完成（超时）。未检测：Codex CLI, Grok Build，显示的是它们上次已知的状态。'),
        findsOneWidget,
      );
      expect(find.text('重新检测运行时'), findsOneWidget);
    });
  });

  group('release notes ("What\'s new")', () {
    Future<void> publish({String version = '1.5.0'}) async {
      client.envelope = {
        'latestComputerVersion': '1.5.0',
        'latestComputerReleaseNotes': {
          'version': version,
          'en': '- Faster **startup**',
          'zh-CN': '- 启动更快',
        },
      };
      await w.services.entityDirectory.refresh(
        WorkspaceEntityKind.computers,
        force: true,
      );
    }

    final link = find.byKey(const ValueKey('computer-release-notes-open'));
    final dialog = find.byKey(const ValueKey('computer-release-notes-dialog'));

    scenario(
      'shows beside the upgrade when the notes match the available version',
      (t) async {
        client.envelope = {};
        await mount(t, machine(version: '1.4.0'));
        await publish();
        await t.pump();
        expect(link, findsOneWidget);
        await t.tap(link);
        await t.pumpAndSettle();
        expect(dialog, findsOneWidget);
        // The dialog card writes its title in capitals.
        expect(find.text("What's new in v1.5.0"), findsOneWidget);
        expect(
          find.textContaining('Faster', findRichText: true),
          findsOneWidget,
        );
        await t.tap(find.byType(RaftDialogClose));
        await t.pumpAndSettle();
        expect(dialog, findsNothing);
      },
    );

    scenario('notes for another version are not shown', (t) async {
      await mount(t, machine(version: '1.4.0'));
      await publish(version: '1.6.0');
      await t.pump();
      expect(link, findsNothing);
    });

    scenario('an up-to-date Computer has no link', (t) async {
      await mount(t, machine(version: '1.5.0'));
      await publish();
      await t.pump();
      expect(link, findsNothing);
    });

    scenario('offline, the link sits beside the available version', (t) async {
      await mount(t, machine(status: 'offline', version: '1.4.0'));
      await publish();
      await t.pump();
      expect(link, findsOneWidget);
    });

    scenario('a Chinese UI reads the zh-CN notes', (t) async {
      await mount(t, machine(version: '1.4.0'), locale: const Locale('zh'));
      await publish();
      await t.pump();
      expect(find.text('查看更新内容'), findsOneWidget);
      await t.tap(link);
      await t.pumpAndSettle();
      expect(find.text('v1.5.0 更新内容'), findsOneWidget);
      expect(find.textContaining('启动更快', findRichText: true), findsOneWidget);
    });
  });

  group('creator link', () {
    scenario('opens the creator profile', (t) async {
      await mount(
        t,
        machine(creator: {'id': 'bob', 'name': 'bob', 'displayName': 'Bob'}),
      );
      await t.tap(find.byKey(const ValueKey('computer-creator-link')));
      await t.pump();
      final profile = w.location.profile;
      expect(profile?.kind, RaftProfileKind.human);
      expect(profile?.id, 'bob');
    });

    scenario('no creator assigned is plain text', (t) async {
      await mount(t, machine());
      expect(find.byKey(const ValueKey('computer-creator-link')), findsNothing);
      expect(find.text('No creator assigned'), findsOneWidget);
    });
  });
}
