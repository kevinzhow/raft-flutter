import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/computer_detail_view.dart';
import 'package:raft_flutter/features/management_support.dart';
import 'package:raft_flutter/features/bulk_agent_model_change.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> agent(String id, {String model = 'gpt-5-codex'}) => {
  'id': id,
  'name': id,
  'displayName': 'Agent $id',
  'machineId': 'm1',
  'runtime': 'codex',
  'model': model,
  'reasoningEffort': 'medium',
  'status': 'inactive',
  'activity': 'offline',
  'envVars': {'OWN_ENV': id},
};

const machine = <String, dynamic>{
  'id': 'm1',
  'name': 'Fixture computer',
  'status': 'online',
  'isComputer': false,
  'runtimes': ['codex', 'claude'],
};

class ModelClient extends RaftClient {
  ModelClient()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  final agents = <String, Map<String, dynamic>>{'a1': agent('a1')};
  final calls = <(String, String, dynamic)>[];
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  bool flag = true;
  bool allowSwitch = true;
  final failBefore = <String>{}, failAfter = <String>{};
  Completer<void>? writeGate, admissionGate;
  Completer<dynamic>? modelGate;
  Map<String, dynamic>? usage;
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
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
    calls.add((method, path, data));
    if (path == '/agents') return agents.values.toList();
    if (path == '/feature-flags/evaluate') {
      return {
        'evaluations': [
          {'key': 'bulk_change_model_web_v0', 'enabled': flag},
        ],
      };
    }
    if (path.endsWith('/runtime-options')) {
      await admissionGate?.future;
      return {
        'options': [
          {'runtimeId': 'codex', 'canSelectInThisContext': true},
          {'runtimeId': 'claude', 'canSelectInThisContext': allowSwitch},
        ],
      };
    }
    if (path.contains('/runtime-models/')) {
      if (modelGate != null) return modelGate!.future;
      if (path.endsWith('/claude')) {
        return {
          'models': [
            {'id': 'sonnet', 'label': 'Claude Sonnet'},
          ],
          'default': 'sonnet',
        };
      }
      return {
        'models': [
          {'id': 'gpt-6-astra', 'label': 'GPT-6-Astra'},
          {'id': 'gpt-5-codex', 'label': 'GPT-5 Codex'},
        ],
        'default': 'gpt-6-astra',
      };
    }
    if (method == 'GET' && path.startsWith('/agents/')) {
      return agents[path.split('/').last];
    }
    if (method == 'PATCH' && path.startsWith('/agents/')) {
      await writeGate?.future;
      if (failBefore.remove(path.split('/').last)) {
        throw const RaftApiException('synthetic save failure');
      }
      final row = agents[path.split('/').last]!;
      row.addAll(Map<String, dynamic>.from(data as Map));
      if (failAfter.remove(path.split('/').last)) {
        throw const RaftApiException('synthetic restart failure');
      }
      return Map<String, dynamic>.from(row);
    }
    if (path.contains('/runtime-account-usage/')) {
      return usage == null ? {} : {'state': 'fresh', 'snapshot': usage};
    }
    return <String, dynamic>{};
  }
}

void main() {
  late ModelClient client;
  late WorkspaceController workspace;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    client = ModelClient();
    workspace = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner'});
    rememberServerFlag(
      workspace,
      'bulk_change_model_web_v0',
      true,
      pageIdentity(workspace),
    );
  });
  tearDown(() async {
    workspace.dispose();
    await client.stream.close();
    await client.dispose();
  });

  Future<void> panel(
    WidgetTester tester, {
    RaftFamily family = RaftFamily.brutal,
    bool dark = false,
    Locale locale = const Locale('en'),
    double width = 1100,
    double scale = 1,
    bool cleanup = true,
    Map<String, dynamic> computer = machine,
  }) async {
    if (cleanup) {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: raftTheme(family, dark: dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: RaftTextScaling(child: child!),
        ),
        home: Scaffold(
          body: ComputerDetailPanel(
            controller: workspace,
            machine: computer,
            now: () => tester.binding.clock.now(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, {bool all = false}) async {
    await tap(tester, 'computer-agents-select');
    await tap(tester, all ? 'computer-agents-select-all' : 'computer-agent-a1');
    await tap(tester, 'computer-bulk-change-model');
    expect(
      find.byKey(const ValueKey('bulk-change-model-dialog')),
      findsOneWidget,
    );
  }

  List<(String, String, dynamic)> getWrites() => [
    for (final call in client.calls)
      if (call.$1 == 'PATCH' || call.$2.endsWith('/reset')) call,
  ];

  BulkModelReceipt? savedReceipt() =>
      readPageSnapshot(workspace, 'bulk-model-receipt:m1')?['receipt']
          as BulkModelReceipt?;

  testWidgets('computer selection exposes the gated bulk model action', (
    tester,
  ) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
    tester.view.physicalSize = const Size(1100, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(
          body: ComputerDetailPanel(controller: workspace, machine: machine),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final select = find.byKey(const ValueKey('computer-agents-select'));
    await tester.ensureVisible(select);
    await tester.tap(select);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('computer-agent-a1')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('computer-bulk-change-model')),
      findsOneWidget,
    );
  });

  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'choose/review/cancel and keyboard dismissal do not write ($family/$dark)',
      (tester) async {
        await panel(tester, family: family, dark: dark);
        await open(tester);
        await tap(tester, 'bulk-model-next');
        expect(find.byKey(const ValueKey('bulk-model-row-a1')), findsOneWidget);
        expect(getWrites(), isEmpty);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('bulk-change-model-dialog')),
          findsNothing,
        );
        expect(getWrites(), isEmpty);
        expect(savedReceipt(), isNull);
      },
    );
  }

  testWidgets(
    'real chooser applies target, preserves env and expires success without replay',
    (tester) async {
      await panel(tester);
      await open(tester);
      await tap(tester, 'bulk-model-next');
      await tap(tester, 'bulk-model-apply');
      final writes = getWrites();
      expect(writes, hasLength(1));
      expect(writes.single.$1, 'PATCH');
      expect(writes.single.$2, '/agents/a1');
      final body = writes.single.$3 as Map;
      expect(body['model'], 'gpt-6-astra');
      expect(body.containsKey('restartMode'), isFalse);
      expect((body['runtimeConfig'] as Map)['envVars'], {'OWN_ENV': 'a1'});
      expect(
        workspace.services.entityDirectory.agent('a1')?['model'],
        'gpt-6-astra',
      );
      expect(
        find.byKey(const ValueKey('bulk-model-success-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('computer-agents-select')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 6));
      expect(
        find.byKey(const ValueKey('bulk-model-success-banner')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await panel(tester, cleanup: false);
      expect(
        find.byKey(const ValueKey('bulk-model-success-banner')),
        findsNothing,
      );
      expect(getWrites(), hasLength(1));
    },
  );

  testWidgets(
    'partial result survives revisit and retry only restarts the already-saved unfinished agent',
    (tester) async {
      client.agents['a2'] = agent('a2')
        ..addAll({'activity': 'idle', 'status': 'active'});
      client.failAfter.add('a2');
      await panel(tester);
      await open(tester, all: true);
      await tap(tester, 'bulk-model-next');
      expect(find.text('1 running agent will restart.'), findsOneWidget);
      await tap(tester, 'bulk-model-apply');
      expect(savedReceipt()!.unfinished, {
        'a2': BulkUnfinishedPhase.restartPending,
      });
      expect(
        find.byKey(const ValueKey('bulk-model-partial-banner')),
        findsOneWidget,
      );
      expect(getWrites().where((c) => c.$1 == 'PATCH'), hasLength(2));
      expect((getWrites().last.$3 as Map)['restartMode'], 'restart');
      await tester.pumpWidget(const SizedBox.shrink());
      await panel(tester, cleanup: false);
      expect(
        find.byKey(const ValueKey('bulk-model-partial-banner')),
        findsOneWidget,
      );
      await tap(tester, 'bulk-model-try-again');
      await tap(tester, 'bulk-model-next');
      expect(find.byKey(const ValueKey('bulk-model-row-a1')), findsNothing);
      expect(find.byKey(const ValueKey('bulk-model-row-a2')), findsOneWidget);
      await tap(tester, 'bulk-model-apply');
      expect(getWrites().where((c) => c.$1 == 'PATCH'), hasLength(2));
      expect(getWrites().last.$2, '/agents/a2/reset');
      expect(getWrites().last.$3, {'mode': 'restart'});
      expect(
        find.byKey(const ValueKey('bulk-model-partial-banner')),
        findsNothing,
      );
      expect(savedReceipt()!.success, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await panel(tester, cleanup: false);
      expect(
        find.byKey(const ValueKey('bulk-model-partial-banner')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'a save failure retries the save and removes the persistent failure after success',
    (tester) async {
      client.failBefore.add('a1');
      await panel(tester);
      await open(tester);
      await tap(tester, 'bulk-model-next');
      await tap(tester, 'bulk-model-apply');
      expect(savedReceipt()!.unfinished, {
        'a1': BulkUnfinishedPhase.saveFailed,
      });
      expect(client.agents['a1']!['model'], 'gpt-5-codex');
      await tap(tester, 'bulk-model-try-again');
      await tap(tester, 'bulk-model-next');
      await tap(tester, 'bulk-model-apply');
      expect(getWrites().map((c) => c.$1), ['PATCH', 'PATCH']);
      expect(
        find.byKey(const ValueKey('bulk-model-partial-banner')),
        findsNothing,
      );
      expect(client.agents['a1']!['model'], 'gpt-6-astra');
    },
  );

  testWidgets(
    'custom config is explained and excluded while eligible agents change',
    (tester) async {
      client.agents['a2'] = agent('a2')
        ..['runtimeConfig'] = {
          'runtime': 'codex',
          'model': {'kind': 'custom', 'name': 'private-model'},
        };
      await panel(tester);
      await open(tester, all: true);
      await tap(tester, 'bulk-model-next');
      expect(find.text('Custom settings'), findsOneWidget);
      await tap(tester, 'bulk-model-apply');
      expect(getWrites(), hasLength(1));
      expect(savedReceipt()!.skipped, ['a2']);
      expect((client.agents['a2']!['runtimeConfig'] as Map)['model'], {
        'kind': 'custom',
        'name': 'private-model',
      });
    },
  );

  testWidgets('runtime switch admission failure is closed and disables Apply', (
    tester,
  ) async {
    client.allowSwitch = false;
    await panel(tester);
    await open(tester);
    await tap(tester, 'bulk-model-runtime');
    await tester.tap(find.text('Claude Code').last);
    await tester.pumpAndSettle();
    await tap(tester, 'bulk-model-next');
    expect(find.text('Not available'), findsOneWidget);
    final button = tester.widget<RaftAgentDialogButton>(
      find.byKey(const ValueKey('bulk-model-apply')),
    );
    expect(button.onPressed, isNull);
    expect(getWrites(), isEmpty);
  });

  testWidgets(
    'pending models cannot advance until the actual catalog arrives',
    (tester) async {
      client.modelGate = Completer<dynamic>();
      await panel(tester);
      await open(tester);
      final next = tester.widget<RaftAgentDialogButton>(
        find.byKey(const ValueKey('bulk-model-next')),
      );
      expect(next.onPressed, isNull);
      client.modelGate!.complete({
        'models': [
          {'id': 'live-only', 'label': 'Live only'},
        ],
      });
      await tester.pumpAndSettle();
      expect(find.text('Live only'), findsOneWidget);
      expect(
        tester
            .widget<RaftAgentDialogButton>(
              find.byKey(const ValueKey('bulk-model-next')),
            )
            .onPressed,
        isNotNull,
      );
      expect(getWrites(), isEmpty);
    },
  );

  testWidgets(
    'busy apply cannot be dismissed; authority loss drops the late response and receipt',
    (tester) async {
      client.writeGate = Completer<void>();
      await panel(tester);
      await open(tester);
      await tap(tester, 'bulk-model-next');
      await tester.tap(find.byKey(const ValueKey('bulk-model-apply')));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.tapAt(const Offset(4, 4));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('bulk-change-model-dialog')),
        findsOneWidget,
      );
      workspace.server = RaftRecord({'id': 's', 'role': 'member'});
      workspace.notifyListeners();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('bulk-change-model-dialog')),
        findsNothing,
      );
      client.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(savedReceipt(), isNull);
      expect(
        find.byKey(const ValueKey('bulk-model-success-banner')),
        findsNothing,
      );
      expect(getWrites(), hasLength(1));
    },
  );

  testWidgets('server flag off hides the bulk model entry', (tester) async {
    client.flag = false;
    rememberServerFlag(
      workspace,
      bulkModelFlag,
      false,
      pageIdentity(workspace),
    );
    await panel(tester);
    await tap(tester, 'computer-agents-select');
    await tap(tester, 'computer-agent-a1');
    expect(
      find.byKey(const ValueKey('computer-bulk-change-model')),
      findsNothing,
    );
  });

  testWidgets('a member cannot open bulk changes or read private usage', (
    tester,
  ) async {
    workspace.server = RaftRecord({'id': 's', 'role': 'member'});
    await panel(tester);
    expect(
      find.byKey(const ValueKey('computer-bulk-change-model')),
      findsNothing,
    );
    expect(
      client.calls.where((c) => c.$2.contains('/runtime-account-usage/')),
      isEmpty,
    );
    expect(getWrites(), isEmpty);
  });

  testWidgets('no eligible runtimes or unchanged targets cannot write', (
    tester,
  ) async {
    await panel(
      tester,
      computer: {
        ...machine,
        'runtimes': ['builtin', 'pi'],
      },
    );
    await open(tester);
    expect(
      find.text('No runtime on this computer can be changed in bulk.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<RaftAgentDialogButton>(
            find.byKey(const ValueKey('bulk-model-next')),
          )
          .onPressed,
      isNull,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    client.agents['a1'] = agent('a1', model: 'gpt-6-astra');
    await workspace.services.entityDirectory.refresh(
      WorkspaceEntityKind.agents,
      force: true,
    );
    await panel(tester, cleanup: false);
    await open(tester);
    await tap(tester, 'bulk-model-reasoning');
    await tester.tap(find.text('Medium').last);
    await tester.pumpAndSettle();
    await tap(tester, 'bulk-model-next');
    expect(find.text('No change'), findsOneWidget);
    expect(
      tester
          .widget<RaftAgentDialogButton>(
            find.byKey(const ValueKey('bulk-model-apply')),
          )
          .onPressed,
      isNull,
    );
    expect(getWrites(), isEmpty);
  });

  testWidgets(
    'repeated failure remains retryable and dismissal stays dismissed',
    (tester) async {
      client.failBefore.add('a1');
      await panel(tester);
      await open(tester);
      await tap(tester, 'bulk-model-next');
      await tap(tester, 'bulk-model-apply');
      client.failBefore.add('a1');
      await tap(tester, 'bulk-model-try-again');
      await tap(tester, 'bulk-model-next');
      await tap(tester, 'bulk-model-apply');
      expect(getWrites(), hasLength(2));
      expect(savedReceipt()!.unfinished, {
        'a1': BulkUnfinishedPhase.saveFailed,
      });
      expect(client.agents['a1']!['model'], 'gpt-5-codex');
      await tap(tester, 'bulk-model-dismiss');
      expect(savedReceipt(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await panel(tester, cleanup: false);
      expect(
        find.byKey(const ValueKey('bulk-model-partial-banner')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'pending runtime admission cannot apply before each check completes',
    (tester) async {
      client.admissionGate = Completer<void>();
      await panel(tester);
      await open(tester);
      await tap(tester, 'bulk-model-runtime');
      await tester.tap(find.text('Claude Code').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bulk-model-next')));
      await tester.pump();
      expect(find.byKey(const ValueKey('bulk-model-apply')), findsNothing);
      expect(getWrites(), isEmpty);
      client.admissionGate!.complete();
      await tester.pumpAndSettle();
      await tap(tester, 'bulk-model-apply');
      expect(client.agents['a1']!['runtime'], 'claude');
      expect(client.agents['a1']!['model'], 'sonnet');
      expect(getWrites(), hasLength(1));
    },
  );

  testWidgets(
    'partial receipts clear on authority changes and client reconstruction',
    (tester) async {
      client.failBefore.add('a1');
      await panel(tester);
      await open(tester);
      await tap(tester, 'bulk-model-next');
      await tap(tester, 'bulk-model-apply');
      expect(savedReceipt(), isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
      final fresh = WorkspaceController(client, ownsClient: false)
        ..server = RaftRecord({'id': 's', 'role': 'owner'});
      expect(readPageSnapshot(fresh, 'bulk-model-receipt:m1'), isNull);
      fresh.dispose();
      client.user = RaftRecord({'id': 'bob'});
      workspace.notifyListeners();
      expect(savedReceipt(), isNull);
      client.selectServer('other');
      workspace.server = RaftRecord({'id': 'other', 'role': 'owner'});
      workspace.notifyListeners();
      expect(savedReceipt(), isNull);
      expect(getWrites(), hasLength(1));
    },
  );

  testWidgets(
    'runtime choices show authorized account usage without refreshing it',
    (tester) async {
      client.usage = {
        'accounts': [
          {
            'planLabel': 'Pro',
            'health': 'ok',
            'windows': [
              {'status': 'ok', 'usedRatio': .42},
            ],
          },
        ],
      };
      await panel(tester);
      await open(tester);
      await tap(tester, 'bulk-model-runtime');
      expect(find.textContaining('Pro · 42% used'), findsWidgets);
      expect(
        client.calls.where((c) => c.$2.contains('/runtime-account-usage/')),
        isNotEmpty,
      );
      expect(client.calls.where((c) => c.$2.endsWith('/refresh')), isEmpty);
      expect(getWrites(), isEmpty);
    },
  );

  testWidgets(
    'reopening shares pending models and reuses only recent live catalogs',
    (tester) async {
      int reads() =>
          client.calls.where((c) => c.$2.contains('/runtime-models/')).length;
      client.modelGate = Completer<dynamic>();
      await panel(tester);
      await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tap(tester, 'computer-bulk-change-model');
      expect(reads(), 1);
      client.modelGate!.complete({
        'models': [
          {'id': 'live-only', 'label': 'Live only'},
        ],
      });
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tap(tester, 'computer-bulk-change-model');
      expect(find.text('Live only'), findsOneWidget);
      expect(reads(), 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 61));
      client.modelGate = null;
      await tap(tester, 'computer-bulk-change-model');
      expect(reads(), 2);
      expect(find.text('GPT-6-Astra'), findsOneWidget);
      expect(getWrites(), isEmpty);
    },
  );

  testWidgets('Chinese phone dialog remains actionable at large text', (
    tester,
  ) async {
    await panel(tester, width: 430, scale: 3.1, locale: const Locale('zh'));
    await open(tester);
    await tap(tester, 'bulk-model-next');
    expect(find.text('为 1 个 AGENT 更换模型'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tap(tester, 'bulk-model-apply');
    expect(client.agents['a1']!['model'], 'gpt-6-astra');
    expect(tester.takeException(), isNull);
  });
}
