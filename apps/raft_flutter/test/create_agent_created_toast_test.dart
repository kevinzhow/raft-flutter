// Web features/agent/createdAgentToast.ts + CreateAgentDialog's `toastCreated`:
// "Created {name}" with View after the dialog has closed; View opens the DM,
// then the profile beside it; not for a first agent, a channel's Add members
// create, an action card or onboarding.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/managed_agent_launcher.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/members_settings/runtime_forms.dart';

class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final dmPosts = <Object?>[];
  Completer<dynamic>? dmAnswer;
  bool failDm = false;
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    if (path != '/channels/dm') return super.post(path, data: data);
    dmPosts.add(data);
    if (failDm) throw RaftApiException('no', status: 500);
    return dmAnswer?.future ?? {'id': 'dm-1'};
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  bool hasAgents = true;
  int revision = 0;
  final opened = <String>[];
  final profiles = <String>[];
  var threadsClosed = 0;
  @override
  int get navigationRevision => revision;
  @override
  void closeThread({bool navigate = true}) => threadsClosed++;
  @override
  Future<void> jumpToMessage(
    String channelId,
    String? messageId, {
    bool navigate = true,
    bool replaceEntry = false,
  }) async => opened.add(channelId);
  @override
  void openProfile(
    RaftProfileKind kind,
    String id, {
    String? agentTab,
    String? channelId,
    Map<String, dynamic>? externalAuthor,
  }) => profiles.add('${kind.name}:$id');

  final posts = <Map<String, dynamic>>[];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/servers/s/machines') {
      return {
        'machines': [
          {
            'id': 'mbp',
            'name': 'Studio Mac',
            'status': 'online',
            'runtimes': ['codex'],
          },
        ],
      };
    }
    if (path == '/agents') {
      return hasAgents
          ? [
              {'id': 'old', 'name': 'old-agent'},
            ]
          : [];
    }
    if (path.endsWith('/runtime-options')) {
      return {
        'options': [
          {
            'runtimeId': 'codex',
            'canSelectInThisContext': true,
            'runtimeFormV2': {'protocolVersion': 2},
          },
        ],
      };
    }
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

  Future<void> createAgent(
    WidgetTester t, {
    Size size = const Size(1280, 800),
    String? channel,
    String? actionCard,
    bool? stayOnCreate,
  }) async {
    await w.services.entityDirectory.refresh(WorkspaceEntityKind.agents);
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        builder: (context, child) => RaftToastHost(child: child!),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showManagedAgentForm(
                context,
                w,
                initialName: 'planner-bot',
                autoJoinChannelName: channel,
                actionCardMessageId: actionCard,
                stayOnCreate: stayOnCreate,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    // The toast is never shown over the open dialog.
    expect(find.text('Created planner-bot'), findsNothing);
    final submit = find.descendant(
      of: find.byType(RaftAgentDialogButton),
      matching: find.text('Create'),
    );
    await t.ensureVisible(submit);
    await t.pumpAndSettle();
    await t.tap(submit);
    await t.pumpAndSettle();
    expect(w.posts, hasLength(1));
  }

  testWidgets(
    'shows after the dialog closes and View opens the DM, then the profile',
    (t) async {
      await createAgent(t);
      expect(find.text('Create agent'), findsNothing);
      expect(find.text('Created planner-bot'), findsOneWidget);
      expect(w.opened, isEmpty);
      await t.tap(find.text('View'));
      await t.pumpAndSettle();
      expect(c.dmPosts, [
        {'agentId': 'agent-new'},
      ]);
      expect(w.opened, ['dm-1']);
      expect(w.profiles, ['agent:agent-new']);
      expect(w.threadsClosed, 1);
      expect(find.text('Created planner-bot'), findsNothing);
    },
  );

  testWidgets('on a phone only the DM opens, the profile would cover it', (
    t,
  ) async {
    await createAgent(t, size: const Size(390, 844));
    await t.tap(find.text('View'));
    await t.pumpAndSettle();
    expect(w.opened, ['dm-1']);
    expect(w.profiles, isEmpty);
  });

  testWidgets('a folded-out tablet width opens the profile beside the DM', (
    t,
  ) async {
    await createAgent(t, size: const Size(944, 856));
    await t.tap(find.text('View'));
    await t.pumpAndSettle();
    expect(w.opened, ['dm-1']);
    expect(w.profiles, ['agent:agent-new']);
  });

  testWidgets('a DM that cannot be opened says so, and nothing moves', (
    t,
  ) async {
    c.failDm = true;
    await createAgent(t);
    await t.tap(find.text('View'));
    await t.pumpAndSettle();
    expect(
      find.text("Couldn't open your conversation with planner-bot. Try again."),
      findsOneWidget,
    );
    expect(w.opened, isEmpty);
    expect(w.profiles, isEmpty);
  });

  testWidgets('the person going on while the DM opens moves nothing', (
    t,
  ) async {
    c.dmAnswer = Completer<dynamic>();
    await createAgent(t);
    await t.tap(find.text('View'));
    await t.pump();
    w.revision++;
    c.dmAnswer!.complete({'id': 'dm-1'});
    await t.pumpAndSettle();
    expect(w.opened, isEmpty);
    expect(w.profiles, isEmpty);
  });

  testWidgets('the server\'s first agent gets no toast', (t) async {
    w.hasAgents = false;
    await createAgent(t);
    expect(find.text('Created planner-bot'), findsNothing);
  });

  testWidgets('a channel\'s Add members create gets no toast', (t) async {
    await createAgent(t, channel: 'design');
    expect(find.textContaining('Created '), findsNothing);
  });

  testWidgets('an action card create gets no toast', (t) async {
    await createAgent(t, actionCard: 'm1');
    expect(find.textContaining('Created '), findsNothing);
  });

  testWidgets('stayOnCreate gets no toast', (t) async {
    await createAgent(t, stayOnCreate: true);
    expect(find.textContaining('Created '), findsNothing);
  });
}
