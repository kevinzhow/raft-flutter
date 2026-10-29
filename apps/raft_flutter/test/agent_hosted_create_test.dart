// Web CreateAgentDialog "Cloud agent" choice (`useAgentRuntimeProvider`,
// `useHostedRuntimeModels`, `HostedModelChoice`): offered only where the
// server's flag is on and the provider answers `available`; a model picker
// unless the server decides; created as an external agent on the provider.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/managed_agent_launcher.dart';
import 'package:raft_ui/raft_ui.dart';

const _option = 'Cloud agent, runs in the cloud · Free for a limited time';
const _hint =
    'Raft creates the agent in the cloud and connects it for you. No command line needed.';

class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  bool flagOn = true;
  int flagReads = 0;
  @override
  Stream<RaftEvent> get events => stream.stream;
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
    if (path == '/feature-flags/evaluate') {
      flagReads++;
      return {
        'evaluations': [
          for (final key in (data as Map)['keys'] as List)
            {'key': key, 'enabled': flagOn},
        ],
      };
    }
    throw RaftApiException('Not found: $path', status: 404);
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  List<Map<String, dynamic>> machines = [];
  Object? probe = {'kind': 'antiproton', 'available': true};
  Object? models = {
    'models': [
      {'id': 'fast', 'label': 'Fast', 'provider': 'p'},
      {'id': 'smart', 'label': 'Smart', 'provider': 'p'},
    ],
    'default': 'balanced',
    'defaultLabel': 'Balanced',
    'locked': false,
  };
  Completer<dynamic>? modelsGate;
  final reads = <String>[];
  final posts = <Map<String, dynamic>>[];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    reads.add(path);
    if (path == '/servers/s/machines') return {'machines': machines};
    if (path == '/agent-runtime-providers/antiproton') {
      final out = probe;
      if (out is Exception) throw out;
      return out;
    }
    if (path == '/agent-runtime-providers/antiproton/models') {
      if (modelsGate case final gate?) return gate.future;
      final out = models;
      if (out is Exception) throw out;
      return out;
    }
    if (path == '/billing/subscription') {
      throw RaftApiException('no billing', status: 403);
    }
    throw RaftApiException('Not found: $path', status: 404);
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    posts.add({'method': method, 'path': path, 'data': data});
    return {'id': 'agent-new', 'name': (data as Map)['name']};
  }
}

const _machine = {
  'id': 'mbp',
  'name': 'Office-Mac',
  'status': 'online',
  'runtimes': ['codex'],
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

  Future<Future<Map<String, dynamic>?>> open(
    WidgetTester t, {
    String? name = 'Cloud-Bot',
    String? hosting,
    String? hostedModel,
    bool settle = true,
  }) async {
    late Future<Map<String, dynamic>?> result;
    await t.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => result = showManagedAgentForm(
                context,
                w,
                initialName: name,
                initialHosting: hosting,
                initialHostedModel: hostedModel,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    if (settle) {
      await t.pumpAndSettle();
    } else {
      await t.pump(const Duration(milliseconds: 300));
    }
    return result;
  }

  Future<void> chooseCloud(WidgetTester t) async {
    await t.tap(find.text('Office-Mac'));
    await t.pumpAndSettle();
    await t.tap(find.text(_option));
    await t.pumpAndSettle();
  }

  testWidgets(
    'the Computer picker offers the cloud when flag and probe agree',
    (t) async {
      w.machines = [_machine];
      await open(t);
      expect(c.flagReads, 1);
      expect(w.reads, contains('/agent-runtime-providers/antiproton'));
      // Not chosen yet: the computer's own runtime fields show.
      expect(
        find.textContaining('Runtime', findRichText: true),
        findsOneWidget,
      );
      expect(find.text(_hint), findsNothing);
      await t.tap(find.text('Office-Mac'));
      await t.pumpAndSettle();
      expect(find.text(_option), findsOneWidget);
    },
  );

  testWidgets('choosing the cloud drops the runtime and asks for a model', (
    t,
  ) async {
    w.machines = [_machine];
    await open(t);
    await chooseCloud(t);
    expect(find.textContaining('Runtime', findRichText: true), findsNothing);
    expect(find.text(_hint), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is RaftStableField && w.label == 'Model'),
      findsOneWidget,
    );
    expect(find.text('Default (Balanced)'), findsOneWidget);
    expect(w.reads, contains('/agent-runtime-providers/antiproton/models'));
  });

  testWidgets(
    'a cloud agent is created external on the provider, no computer',
    (t) async {
      w.machines = [_machine];
      final result = await open(t);
      await chooseCloud(t);
      await t.tap(
        find.descendant(
          of: find.byType(RaftAgentDialogButton),
          matching: find.text('Create Agent'),
        ),
      );
      await t.pumpAndSettle();
      expect(w.posts, hasLength(1));
      final data = w.posts.single['data'] as Map;
      expect(w.posts.single['path'], '/agents');
      expect(data['name'], 'Cloud-Bot');
      expect(data['external'], isTrue);
      expect(data['provider'], 'antiproton');
      expect(data.containsKey('machineId'), isFalse);
      expect(data.containsKey('runtime'), isFalse);
      expect(data.containsKey('formDefinitionRef'), isFalse);
      // The provider's default: no model is named.
      expect(data.containsKey('hostedModel'), isFalse);
      expect((data['avatarUrl'] as String).startsWith('pixel:'), isTrue);
      expect(await result, {'id': 'agent-new', 'name': 'Cloud-Bot'});
    },
  );

  testWidgets('a picked model is sent as hostedModel', (t) async {
    w.machines = [_machine];
    await open(t);
    await chooseCloud(t);
    await t.tap(find.byKey(const ValueKey('hosted-model-choice')));
    await t.pumpAndSettle();
    await t.tap(find.text('Smart'));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(RaftAgentDialogButton),
        matching: find.text('Create Agent'),
      ),
    );
    await t.pumpAndSettle();
    expect((w.posts.single['data'] as Map)['hostedModel'], 'smart');
  });

  testWidgets('without the picker the model is left to the server', (t) async {
    w
      ..machines = [_machine]
      ..models = {
        'models': [
          {'id': 'fast', 'label': 'Fast', 'provider': 'p'},
        ],
        'default': 'fast',
        'defaultLabel': 'Fast',
        'locked': false,
        'picker': false,
      };
    await open(t);
    await chooseCloud(t);
    expect(
      find.byWidgetPredicate((w) => w is RaftStableField && w.label == 'Model'),
      findsNothing,
    );
    await t.tap(
      find.descendant(
        of: find.byType(RaftAgentDialogButton),
        matching: find.text('Create Agent'),
      ),
    );
    await t.pumpAndSettle();
    expect((w.posts.single['data'] as Map).containsKey('hostedModel'), isFalse);
  });

  testWidgets('a locked model is shown read-only and not sent', (t) async {
    w
      ..machines = [_machine]
      ..models = {
        'models': [
          {'id': 'fast', 'label': 'Fast', 'provider': 'p'},
        ],
        'default': 'fast',
        'defaultLabel': 'Fast',
        'locked': true,
      };
    await open(t);
    await chooseCloud(t);
    expect(
      find.byKey(const ValueKey('hosted-model-choice-locked')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('hosted-model-choice')), findsNothing);
    expect(
      find.text(
        "An administrator has set this agent's model, so it can't be changed here.",
      ),
      findsOneWidget,
    );
    await t.tap(
      find.descendant(
        of: find.byType(RaftAgentDialogButton),
        matching: find.text('Create Agent'),
      ),
    );
    await t.pumpAndSettle();
    expect((w.posts.single['data'] as Map).containsKey('hostedModel'), isFalse);
  });

  testWidgets('Create waits for the list, which a failure turns into a retry', (
    t,
  ) async {
    w.machines = [_machine];
    final gate = w.modelsGate = Completer<dynamic>();
    await open(t);
    await t.tap(find.text('Office-Mac'));
    await t.pumpAndSettle();
    await t.tap(find.text(_option));
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(
      find.descendant(
        of: find.byType(RaftAgentDialogButton),
        matching: find.text('Create Agent'),
      ),
      warnIfMissed: false,
    );
    await t.pump();
    expect(w.posts, isEmpty, reason: 'Create is disabled while loading');
    gate.completeError(RaftApiException('down', status: 502));
    await t.pumpAndSettle();
    expect(find.textContaining("Couldn't load the models"), findsOneWidget);
    expect(
      find.textContaining('Try Again', findRichText: true),
      findsOneWidget,
    );
    w.modelsGate = null;
    await t.tapOnText(find.textRange.ofSubstring('Try Again'));
    await t.pumpAndSettle();
    expect(find.textContaining("Couldn't load the models"), findsNothing);
    expect(find.text('Default (Balanced)'), findsOneWidget);
    expect(
      w.reads.where((p) => p.endsWith('/models')),
      hasLength(2),
      reason: 'Try Again reads the list once more',
    );
  });

  testWidgets('flag off or probe unavailable: no cloud, no model read', (
    t,
  ) async {
    w.machines = [_machine];
    c.flagOn = false;
    await open(t);
    expect(w.reads, isNot(contains('/agent-runtime-providers/antiproton')));
    await t.tap(find.text('Office-Mac'));
    await t.pumpAndSettle();
    expect(find.text(_option), findsNothing);
    expect(find.textContaining('Runtime', findRichText: true), findsOneWidget);
    expect(w.reads.where((p) => p.endsWith('/models')), isEmpty);
  });

  testWidgets(
    'a provider that is not configured or not served offers nothing',
    (t) async {
      w
        ..machines = [_machine]
        ..probe = {'kind': 'antiproton', 'available': false};
      await open(t);
      await t.tap(find.text('Office-Mac'));
      await t.pumpAndSettle();
      expect(find.text(_option), findsNothing);
    },
  );

  testWidgets('an old server that has no probe offers nothing', (t) async {
    w
      ..machines = [_machine]
      ..probe = RaftApiException('missing', status: 404);
    await open(t);
    await t.tap(find.text('Office-Mac'));
    await t.pumpAndSettle();
    expect(find.text(_option), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('no computer: the cloud is the place to run, not a dead end', (
    t,
  ) async {
    await open(t);
    expect(find.text('Connect a computer first'), findsNothing);
    expect(find.text(_hint), findsOneWidget);
    expect(find.textContaining('Runtime', findRichText: true), findsNothing);
    await t.tap(
      find.descendant(
        of: find.byType(RaftAgentDialogButton),
        matching: find.text('Create Agent'),
      ),
    );
    await t.pumpAndSettle();
    final data = w.posts.single['data'] as Map;
    expect(data['provider'], 'antiproton');
    expect(data['external'], isTrue);
  });

  testWidgets('no computer and no cloud still asks to connect a computer', (
    t,
  ) async {
    c.flagOn = false;
    await open(t);
    expect(find.text('Connect a computer first'), findsOneWidget);
    expect(find.text('Add Computer'), findsOneWidget);
  });

  testWidgets('an action card can preselect the cloud and a model', (t) async {
    w.machines = [_machine];
    await open(t, hosting: 'antiproton', hostedModel: 'smart');
    expect(find.textContaining('Runtime', findRichText: true), findsNothing);
    expect(find.text('Smart'), findsOneWidget);
    await t.tap(
      find.descendant(
        of: find.byType(RaftAgentDialogButton),
        matching: find.text('Create Agent'),
      ),
    );
    await t.pumpAndSettle();
    expect((w.posts.single['data'] as Map)['hostedModel'], 'smart');
  });

  testWidgets('a card model the provider no longer offers falls back', (
    t,
  ) async {
    w.machines = [_machine];
    await open(t, hosting: 'antiproton', hostedModel: 'retired');
    expect(find.text('Default (Balanced)'), findsOneWidget);
    await t.tap(
      find.descendant(
        of: find.byType(RaftAgentDialogButton),
        matching: find.text('Create Agent'),
      ),
    );
    await t.pumpAndSettle();
    expect((w.posts.single['data'] as Map).containsKey('hostedModel'), isFalse);
  });
}
