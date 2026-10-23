import 'dart:async';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/attachment_comments_view.dart';
import 'package:raft_flutter/features/attachment_preview_dialog.dart';
import 'package:raft_flutter/features/attachment_preview_gate.dart';
import 'package:raft_flutter/features/attachment_view.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_flutter/features/source_channel_files_actions.dart';
import 'package:raft_flutter/data/source_channel_files_store.dart';
import 'package:raft_flutter/features/management_support.dart'
    show pageIdentity, rememberServerFlag;
import 'package:raft_flutter/features/message_action_card.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/features/message_presentation.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart'
    show ActivityClient, ActivityWorkspace, skeleton;
import 'message_presentation_test.dart' show card, host;
import 'task_snapshot_navigation_test.dart' show taskRow;
import 'support/close_support.dart';
import 'support/no_wait_support.dart';
import 'flutter_test_config.dart' show leakDebt;

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
);

const _flag = 'composer_resource_references_v0';

/// Activity, Saved, Search and Tasks reads that can be held open.
class _Content extends ActivityWorkspace {
  _Content(super.client);
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path.startsWith('/tasks/')) {
      final gate = hold;
      if (gate != null) await gate.future;
      final status = query?['status'];
      return {
        'tasks': [
          for (var n = 12; n > 0; n--)
            if (status == null || status == 'todo') taskRow(n, 'todo'),
        ],
        'next_cursor': null,
      };
    }
    if (path == '/messages/search') {
      final gate = hold;
      if (gate != null) await gate.future;
    }
    return super.query(path, query: query);
  }
}

class _SyncMemory
    implements SearchMemoryStorage, SynchronousSearchMemoryStorage {
  final values = <String, String>{};
  @override
  bool get ready => true;
  @override
  String? readSync(String key) => values[key];
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

MessagePresentation _presentation(
  WorkspaceController w, {
  Map<String, dynamic>? Function(int)? taskByNumber,
  ValueChanged<Map<String, dynamic>>? onOpenTask,
}) => MessagePresentation(
  controller: w,
  message: RaftMessage({
    'id': 'link-host',
    'channelId': 'c1',
    'content': 'see links',
  }),
  onExternalLink: (_) {},
  taskByNumber: taskByNumber,
  onOpenTask: onOpenTask,
);

void main() {
  // Leak debt (dialog notifier): see docs/development.md, Leak tracking.
  leakDebt(const ['ValueNotifier<Map<String, dynamic>?>']);
  group('message links and references open from what is loaded', () {
    testWidgets('computer: opens the machine detail from the directory', (
      t,
    ) async {
      final (w, api) = await mountWorkspace(t, const Size(1280, 800));
      api.routes['GET /servers/s1/machines'] = (_) => {
        'machines': [
          {'id': 'box1', 'name': 'Box', 'isComputer': true, 'status': 'online'},
        ],
      };
      await t.runAsync(
        () => w.entityDirectory.refresh(
          WorkspaceEntityKind.computers,
          force: true,
        ),
      );
      rememberServerFlag(w, _flag, true, pageIdentity(w));
      final machineReads = api.calls
          .where((c) => c.path == '/servers/s1/machines')
          .length;
      final held = await expectOpensWithoutNetwork(
        t,
        w,
        api,
        open: (context) => _presentation(w).open(context, 'computer:box1'),
        surface: find.byType(FleetDetail),
      );
      // The flag and the machines list were not needed to open it.
      expect(
        api.calls.where((c) => c.path == '/servers/s1/machines').length,
        machineReads,
        reason: 'the machines read was not needed to open the detail',
      );
      expect(find.text('Box'), findsWidgets);
      expect(held, isNonNegative);
    });

    testWidgets('app: opens Integrations at once; the apps read only vouches', (
      t,
    ) async {
      final (w, api) = await mountWorkspace(t, const Size(1280, 800));
      rememberServerFlag(w, _flag, true, pageIdentity(w));
      api.hangAll = true;
      unawaited(
        _presentation(
          w,
        ).open(t.element(find.byType(WorkspaceView)), 'app:github'),
      );
      await frames(t, 3);
      expect(w.section, 'settings', reason: 'Integrations lives in Settings');
      api.hangAll = false;
    });

    testWidgets('a task reference opens its dialog before the task arrives', (
      t,
    ) async {
      final (w, api) = await mountWorkspace(t, const Size(1280, 800));
      final reply = Completer<dynamic>();
      api.routes['GET /tasks/channel/c1/number/7'] = (_) => reply.future;
      final context = t.element(find.byType(WorkspaceView));
      unawaited(_presentation(w).open(context, 'raft-ref://task/7'));
      await frames(t, 4);
      expect(find.text('task #7'), findsOneWidget, reason: 'skeleton dialog');
      reply.complete({
        'task': {'id': 'k7', 'title': 'Ship it', 'status': 'todo'},
      });
      await frames(t, 4);
      expect(find.text('task #7 · Ship it'), findsOneWidget);
    });

    testWidgets('a task reference known to the loaded tasks opens it at once', (
      t,
    ) async {
      final (w, api) = await mountWorkspace(t, const Size(1280, 800));
      Map<String, dynamic>? opened;
      api.hangAll = true;
      unawaited(
        _presentation(
          w,
          taskByNumber: (n) => {'id': 'k$n', 'taskNumber': n, 'title': 'T$n'},
          onOpenTask: (task) => opened = task,
        ).open(t.element(find.byType(WorkspaceView)), 'raft-ref://task/3'),
      );
      await frames(t, 2);
      expect(opened?['id'], 'k3');
      api.hangAll = false;
    });
  });

  group('action cards', () {
    testWidgets('Create channel opens its form without any request', (t) async {
      final (w, api) = await mountWorkspace(t, const Size(1280, 800));
      await t.pumpWidget(
        host(MessageActionCard(controller: w, message: card('channel:create'))),
      );
      await frames(t, 3);
      api.hangAll = true;
      await t.tap(find.text('Create Channel').last);
      await frames(t, 6);
      expect(find.byKey(const ValueKey('field-name')), findsOneWidget);
      api.hangAll = false;
    });
  });

  group('revisiting a page shows what it held, with no loading state', () {
    late ActivityClient client;
    late _Content w;
    setUp(() {
      client = ActivityClient()..user = RaftRecord({'id': 'alice'});
      client.selectServer('s1');
      w = _Content(client)
        ..server = RaftRecord({'id': 's1', 'role': 'owner'})
        ..channels = [
          for (var i = 0; i < 60; i++)
            RaftChannel({'id': 'ch$i', 'name': 'Channel $i', 'joined': true}),
        ];
    });
    tearDown(() async {
      w.dispose();
      await client.dispose();
    });

    Widget page(
      String section, {
      String? channelId,
      String? initialQuery,
      SearchMemoryStore? memory,
    }) => MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: RaftDensityScope(
        density: RaftDensity.desktop,
        child: Scaffold(
          body: ResourceView(
            controller: w,
            section: section,
            channelId: channelId,
            initialQuery: initialQuery,
            searchMemory: memory,
            onMessage: (_, _) async {},
          ),
        ),
      ),
    );
    final away = MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: const Scaffold(body: SizedBox.expand()),
    );

    final cases = <(String, Widget Function(), String)>[
      ('Activity', () => page('activity'), 'Channel 0'),
      ('Saved', () => page('saved'), 'Saved body 0'),
      ('server Tasks', () => page('tasks'), 'Task 12'),
      ('channel Tasks', () => page('tasks', channelId: 'ch1'), 'Task 12'),
      (
        'Search with its query',
        () => page('search', initialQuery: 'body'),
        'Search body 0',
      ),
    ];
    for (final (label, build, text) in cases) {
      testWidgets('$label: the first frame of a revisit is final', (t) async {
        await t.pumpWidget(build());
        await t.pumpAndSettle();
        expect(find.textContaining(text, findRichText: true), findsWidgets);
        await t.pumpWidget(away);
        await t.pumpAndSettle();

        w.hold = Completer<void>();
        await t.pumpWidget(build());
        final dynamic state = t.state(find.byType(ResourceView));
        expect(state.loading, isFalse, reason: 'first frame is not loading');
        expect(skeleton, findsNothing);
        expect(
          find.textContaining(text, findRichText: true),
          findsWidgets,
          reason: 'the cached rows are on screen at the first frame',
        );
        await t.pump(const Duration(milliseconds: 16));
        expect(skeleton, findsNothing);
        w.hold!.complete();
        w.hold = null;
        await t.pumpAndSettle();
        expect(find.textContaining(text, findRichText: true), findsWidgets);
      });
    }

    for (final device in [false, true]) {
      testWidgets(
        'Search restored from ${device ? 'the device' : 'memory'} reopens on '
        'its query and results at the first frame',
        (t) async {
          final storage = _SyncMemory();
          var memory = SearchMemoryStore(storage: storage);
          await t.pumpWidget(
            page('search', initialQuery: 'body', memory: memory),
          );
          await t.pumpAndSettle();
          expect(
            find.textContaining('Search body 0', findRichText: true),
            findsWidgets,
          );
          await t.pumpWidget(away);
          await t.pumpAndSettle();
          await t.runAsync(memory.flush);
          // A restart reads the same storage with a new store.
          if (device) memory = SearchMemoryStore(storage: storage);

          w.hold = Completer<void>();
          await t.pumpWidget(page('search', memory: memory));
          final dynamic state = t.state(find.byType(ResourceView));
          expect(state.query.text, 'body');
          expect(state.loading, isFalse);
          expect(skeleton, findsNothing);
          expect(
            find.textContaining('Search body 0', findRichText: true),
            findsWidgets,
          );
          w.hold!.complete();
          w.hold = null;
          await t.pumpAndSettle();
          expect(
            find.textContaining('Search body 0', findRichText: true),
            findsWidgets,
          );
        },
      );
    }
  });

  group('attachments', () {
    testWidgets('a document preview opens before the preview gate answers', (
      t,
    ) async {
      final (w, api) = await mountWorkspace(t, const Size(1280, 800));
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: AttachmentView(
              controller: w,
              metadata: const {
                'id': 'doc1',
                'filename': 'notes.md',
                'mimeType': 'text/markdown',
              },
            ),
          ),
        ),
      );
      await frames(t, 3);
      api.hangAll = true;
      await t.tap(find.text('notes.md'));
      await frames(t, 4);
      expect(find.byType(AttachmentPreviewDialog), findsOneWidget);
      api.hangAll = false;
    });

    testWidgets('a gate seen disabled before still downloads, not previews', (
      t,
    ) async {
      final (w, api) = await mountWorkspace(t, const Size(1280, 800));
      api.routes['GET /messages/attachment-preview/enabled'] = (_) => {
        'enabled': false,
      };
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: AttachmentView(
              controller: w,
              metadata: const {
                'id': 'doc1',
                'filename': 'notes.md',
                'mimeType': 'text/markdown',
              },
            ),
          ),
        ),
      );
      await t.runAsync(() => readAttachmentPreviewGate(w));
      expect(knownAttachmentPreviewGate(w), isFalse);
      await t.tap(find.text('notes.md'));
      await frames(t, 6);
      expect(find.byType(AttachmentPreviewDialog), findsNothing);
      await t.pumpWidget(const SizedBox());
      await frames(t, 40);
    });

    testWidgets('the Files lightbox opens before the original arrives', (
      t,
    ) async {
      final (w, _) = await mountWorkspace(t, const Size(1280, 800));
      final original = Completer<SourceChannelImageLease?>();
      var released = 0;
      final context = t.element(find.byType(WorkspaceView));
      final actions = SourceChannelFilesActions(
        controller: w,
        authorized: (_) => true,
        context: () => context,
        acquireImage: (file, authorized, rendition) => original.future,
      );
      addTearDown(actions.dispose);
      unawaited(
        actions.preview(
          const SourceChannelFileEntry(
            {
              'id': 'f1',
              'filename': 'shot.png',
              'mimeType': 'image/png',
              'sizeBytes': 1024,
              'width': 400,
              'height': 300,
            },
            'm1',
            'c1',
            'c1',
            null,
            'channel',
            '2026-06-22T00:00:00Z',
          ),
        ),
      );
      await frames(t, 4);
      expect(find.byType(RaftAttachmentLightbox), findsOneWidget);
      expect(find.byType(RaftTransferPlaceholder), findsOneWidget);
      original.complete(
        SourceChannelImageLease(
          provider: MemoryImage(_png),
          release: () async => released++,
        ),
      );
      await frames(t, 4);
      expect(find.byType(RaftTransferPlaceholder), findsNothing);
      expect(find.byType(Image), findsWidgets);
      Navigator.of(context, rootNavigator: true).pop();
      await frames(t, 20);
      expect(find.byType(RaftAttachmentLightbox), findsNothing);
      expect(released, 1, reason: 'the image is handed back on close');
    });

    testWidgets('attachment comments revisit shows the last read at once', (
      t,
    ) async {
      final (w, api) = await mountWorkspace(t, const Size(1280, 800));
      api.routes['GET /attachments/a1/comments'] = (_) => {
        'comments': [
          {
            'id': 'cm1',
            'senderId': 'bob',
            'senderType': 'user',
            'senderName': 'Bob',
            'content': 'Looks good',
            'createdAt': '2026-06-22T02:30:00.000Z',
          },
        ],
        'viewer': {'canComment': true},
      };
      Widget comments() => MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: AttachmentCommentsView(
            controller: w,
            attachmentId: 'a1',
            filename: 'notes.md',
          ),
        ),
      );
      await t.pumpWidget(comments());
      await frames(t, 4);
      expect(find.text('Looks good'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      api.hangAll = true;
      await t.pumpWidget(comments());
      expect(find.text('Looks good'), findsOneWidget, reason: 'first frame');
      api.hangAll = false;
      await t.pumpWidget(const SizedBox());
      await frames(t, 40);
    });
  });
}
