import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/source_channel_files_store.dart';
import 'package:raft_flutter/data/source_feedback_store.dart';
import 'package:raft_flutter/features/source_feedback_view.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/agent_migration_view.dart';
import 'package:raft_flutter/features/agent_scopes_view.dart';
import 'package:raft_flutter/features/attachment_view.dart';
import 'package:raft_flutter/features/incoming_share_picker.dart';
import 'package:raft_flutter/features/message_image_export.dart';
import 'package:raft_flutter/features/public_server_view.dart';
import 'package:raft_flutter/features/quick_switcher.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/features/source_channel_files_actions.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_context_transition_test.dart' show row;
import 'message_presentation_test.dart' show MessageAdapter;
import 'incoming_share_review_test.dart' show PickerClient;
import 'source_feedback_store_test.dart' as fx;
import 'task_surface_test.dart' show modernTask, taskRoutes, flush;
import 'workspace_legacy_task_presentation_test.dart' show legacyTask;
import 'workspace_source_location_contract_test.dart' show pageFixture;

import 'support/close_registry_viewers.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';
import 'support/app_services_fixture.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/enabled')) return {'enabled': true};
    if (path.endsWith('/comments')) {
      return {
        'comments': [],
        'viewer': {'canComment': true},
      };
    }
    if (path.endsWith('/preview')) {
      return {
        'status': 'ok',
        'data': {'kind': 'text', 'text': 'Fixture document'},
      };
    }
    return {'url': 'https://storage.example.invalid/image'};
  }
}

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
);

class _Files extends AttachmentFiles {
  @override
  Future<Uint8List> image(
    String url, {
    required CancelToken cancel,
    void Function(int, int)? onProgress,
  }) async => _png;
}

/// A MaterialApp at [size] with one [AttachmentView] for [metadata].
Future<void> mountAttachment(
  WidgetTester t,
  Size size,
  Map<String, dynamic> metadata,
) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final client = _Client()..user = RaftRecord({'id': 'alice'});
  client.selectServer('server');
  final w = WorkspaceController(client)
    ..server = RaftRecord({'id': 'server', 'role': 'owner'})
    ..channel = RaftChannel({'id': 'channel', 'joined': true});
  w.channels = [w.channel!];
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    w.dispose();
    await client.dispose();
  });
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(
        body: AttachmentView(
          controller: w,
          files: _Files(),
          metadata: metadata,
        ),
      ),
    ),
  );
  await frames(t, 4);
}

Future<void> settleImage(WidgetTester t) async {
  for (var i = 0; i < 20; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// A [WorkspaceView] at [size] over the page fixture, with [task] in the
/// channel's task list. [tasksRoute] opens the Tasks section; otherwise the
/// channel's Tasks tab. Taps the task row.
Future<WorkspaceController> openTask(
  WidgetTester t,
  Size size,
  Map<String, dynamic> task, {
  required bool tasksRoute,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final (w, api) = await pageFixture(t, section: tasksRoute ? 'tasks' : 'chat');
  taskRoutes(api, task);
  api.routes['GET /tasks/channel/c1'] = (r) => {
    'tasks':
        r.queryParameters['status'] == null ||
            r.queryParameters['status'] == 'todo'
        ? [task]
        : [],
  };
  w.messageDomain.ledger.ingest([
    row('accepted-main', 'c1', 1),
  ], expectedGeneration: w.messageDomain.ledger.generation);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: withAppServices(
        WorkspaceView(
          controller: w,
          appearance: RaftAppearance(light: RaftFamily.elegant),
          onAppearance: (_) async {},
          onLogout: () async {},
        ),
      ),
    ),
  );
  await flush(t);
  if (!tasksRoute) {
    final tabs = find.byKey(const Key('conversation-tabs'));
    await t.tap(find.descendant(of: tabs, matching: find.text('Tasks')));
    await flush(t);
  }
  await t.tap(find.text(task['title'] as String));
  await flush(t);
  await t.pumpAndSettle();
  return w;
}

SurfaceProbe taskProbe(Size size) => SurfaceProbe(
  isOpen: () => find.byType(SourceTaskSurface).evaluate().isNotEmpty,
  x: find.byKey(const ValueKey('task-close')),
  back: find.byKey(const ValueKey('task-back')),
  scrim: const Offset(8, 8),
);

Future<WorkspaceController> mountAt(
  WidgetTester t,
  Size size,
  String uri, {
  String section = 'chat',
  void Function(MessageAdapter api)? routes,
}) async {
  final (w, api) = await mountWorkspace(t, size, section: section);
  if (routes != null) {
    routes(api);
    await t.runAsync(() async {
      for (final kind in WorkspaceEntityKind.values) {
        await w.entityDirectory.refresh(kind, force: true);
      }
    });
  }
  w.navigation.navigate(RaftLocation.parse(uri));
  w.notifyListeners();
  await frames(t, 25);
  return w;
}

const _machine = {
  'id': 'm1',
  'name': 'Build Computer',
  'isComputer': true,
  'status': 'online',
  'hostname': 'fixture-host',
  'userId': 'alice',
  'runtimes': ['codex'],
};

/// Just enough of the public-server REST surface for one channel with a
/// thread (mirrors test/public_server_view_test.dart).
class _PublicClient extends RaftClient {
  _PublicClient()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
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
    Map<String, dynamic> message(String id, String who, String text) => {
      'id': id,
      'senderType': 'user',
      'sender': {'displayName': who, 'avatarUrl': null, 'description': null},
      'messageType': 'chat',
      'content': text,
      'createdAt': '2026-06-18T09:12:00.000Z',
      'threadId': id == 'm2' ? 't1' : null,
      'replyCount': id == 'm2' ? 2 : 0,
    };
    const base = '/public/servers/raft-design';
    return switch ('$method $path') {
      'GET $base' => {
        'server': {'id': 's', 'name': 'Raft Design', 'slug': 'raft-design'},
        'channels': [
          {'id': 'c1', 'name': 'general', 'description': 'Announcements'},
        ],
        'canJoinAsGuest': true,
      },
      'GET $base/channels/c1/messages' => {
        'messages': [
          message('m1', 'Wenyi', 'Welcome'),
          message('m2', 'Artin', 'Feedback on the rail?'),
        ],
      },
      'GET $base/threads/t1/messages' => {
        'messages': [message('r1', 'Jun', 'Looks good to me')],
      },
      _ => throw RaftApiException('Not found', status: 404),
    };
  }
}

/// The test font (Ahem, 1em glyphs) overflows the 390px layouts of pages that
/// fit with the product fonts; layout is not what this file checks.
void tolerateOverflow() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (!'${details.exception}'.contains('overflowed')) previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
}

/// The Settings > Feedback inbox over a fixture store.
Future<SourceFeedbackStore> mountFeedback(WidgetTester t, Size size) async {
  tolerateOverflow();
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final store = SourceFeedbackStore(
    authority: () => 'account',
    get: (path, {query}) async => path == '/product-feedback/tickets'
        ? fx.page([fx.ticket(fx.first)])
        : fx.detail(fx.first),
    post: (path, {json, form, onProgress, abort}) async => {'id': fx.first},
  );
  addTearDown(store.dispose);
  await store.loadList();
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(body: SourceFeedbackProjectionView(store: store)),
    ),
  );
  await t.pumpAndSettle();
  return store;
}

bool lightboxOpen() =>
    find.byType(RaftAttachmentLightbox).evaluate().isNotEmpty ||
    find.byType(RaftMediaImmersiveShell).evaluate().isNotEmpty;

/// A point on the stage well away from the (16px) image in the middle.
Offset emptyStage(Size size) =>
    Offset(size.width / 2 + 100, size.height / 2 + 100);

void main() {
  final harness = <String, OpenSurface>{
    'task-modern-tasks-route': (t, size) async {
      await openTask(t, size, modernTask, tasksRoute: true);
      return taskProbe(size);
    },
    'task-modern-channel': (t, size) async {
      await openTask(t, size, modernTask, tasksRoute: false);
      return taskProbe(size);
    },
    'task-legacy-tasks-route': (t, size) async {
      await openTask(t, size, legacyTask, tasksRoute: true);
      return taskProbe(size);
    },
    'task-legacy-channel': (t, size) async {
      await openTask(t, size, legacyTask, tasksRoute: false);
      return taskProbe(size);
    },
    'public-thread-panel': (t, size) async {
      tolerateOverflow();
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: PublicServerView(
              client: _PublicClient(),
              slug: 'raft-design',
              onSignIn: () {},
              onRegister: () {},
              onUnavailable: () {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('public-thread-open-m2')));
      await t.pumpAndSettle();
      final panel = find.byKey(const ValueKey('public-server-thread-panel'));
      return SurfaceProbe(
        isOpen: () => panel.evaluate().isNotEmpty,
        x: find.byKey(const ValueKey('thread-close')),
        back: find.byTooltip('Back'),
      );
    },
    'agent-migration-page': (t, size) async {
      final (w, api) = await mountWorkspace(t, size);
      api.routes['GET /agents/a1/migration'] = (_) => {'migration': null};
      unawaited(
        Navigator.of(t.element(find.byType(WorkspaceView))).push(
          MaterialPageRoute<void>(
            builder: (_) => AgentMigrationView(controller: w, agentId: 'a1'),
          ),
        ),
      );
      await frames(t, 30);
      return SurfaceProbe(
        isOpen: () => find.byType(AgentMigrationView).evaluate().isNotEmpty,
        back: find.byTooltip('Back'),
      );
    },
    'agent-scopes-page': (t, size) async {
      final (w, _) = await mountWorkspace(t, size);
      unawaited(
        Navigator.of(t.element(find.byType(WorkspaceView))).push(
          MaterialPageRoute<void>(
            builder: (_) => AgentScopesView(controller: w, agentId: 'a1'),
          ),
        ),
      );
      await frames(t, 30);
      return SurfaceProbe(
        isOpen: () => find.byType(AgentScopesView).evaluate().isNotEmpty,
        back: find.byTooltip('Back'),
      );
    },
    'incoming-share-picker': (t, size) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: const Scaffold(body: Text('host')),
        ),
      );
      unawaited(
        Navigator.of(t.element(find.text('host'))).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => IncomingSharePicker(
              client: PickerClient(),
              servers: [
                RaftRecord({'id': 'a', 'name': 'Server A'}),
              ],
              valid: () => true,
              onContinue: (server, target) async {},
            ),
          ),
        ),
      );
      await frames(t, 30);
      return SurfaceProbe(
        isOpen: () => find.byType(IncomingSharePicker).evaluate().isNotEmpty,
        back: find.byTooltip('Back'),
      );
    },
    'feedback-ticket': (t, size) async {
      final store = await mountFeedback(t, size);
      await t.tap(find.byKey(ValueKey('feedback-ticket-${fx.first}')));
      await t.pumpAndSettle();
      return SurfaceProbe(
        isOpen: () => store.route == SourceFeedbackRoute.ticket,
        back: find.byKey(const ValueKey('feedback-back')),
      );
    },
    'feedback-create': (t, size) async {
      final store = await mountFeedback(t, size);
      await t.tap(find.byKey(const ValueKey('feedback-new')));
      await t.pumpAndSettle();
      return SurfaceProbe(
        isOpen: () => store.route == SourceFeedbackRoute.create,
        back: find.byKey(const ValueKey('feedback-back')),
      );
    },
    'settings-subpage': (t, size) async {
      final w = await mountAt(
        t,
        size,
        '/s/demo/settings/account',
        section: 'settings',
        routes: (api) {
          api.routes['GET /auth/identities'] = (_) => {
            'passwordConfigured': true,
            'identities': [],
          };
          api.routes['GET /auth/providers'] = (_) => {'providers': []};
        },
      );
      return SurfaceProbe(
        isOpen: () => w.location.toString() == '/s/demo/settings/account',
        back: find.byKey(const Key('mobile-settings-back')),
      );
    },
    'quick-switcher': (t, size) async {
      final w = await mountAt(t, size, '/s/demo');
      if (size.width >= 768) {
        await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await t.sendKeyEvent(LogicalKeyboardKey.keyK);
        await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await frames(t, 20);
        return SurfaceProbe(
          isOpen: () => find.byType(QuickSwitcher).evaluate().isNotEmpty,
          scrim: const Offset(4, 4),
        );
      }
      w.navigation.navigate(RaftLocation.parse('/s/demo/search'));
      w.notifyListeners();
      await frames(t, 25);
      return SurfaceProbe(
        isOpen: () => w.location.route == RaftRoute.search,
        back: find.byTooltip('Back'),
      );
    },
    'computer-detail': (t, size) async {
      final w = await mountAt(
        t,
        size,
        '/s/demo/computer/m1',
        routes: (api) {
          api.routes['GET /servers/s1/machines'] = (_) => {
            'machines': [_machine],
          };
        },
      );
      expect(find.text('Build Computer'), findsWidgets);
      return SurfaceProbe(
        isOpen: () => w.location.route == RaftRoute.computer,
        back: find.byTooltip('Back'),
        x: find.byTooltip('Close'),
      );
    },
    'agent-directory-detail': (t, size) async {
      final w = await mountAt(t, size, '/s/demo/agent/a1');
      expect(find.text('Cindy'), findsWidgets);
      return SurfaceProbe(
        isOpen: () => w.location.route == RaftRoute.agent,
        back: find.byTooltip('Back'),
        x: find.byTooltip('Close profile'),
      );
    },
    'image-lightbox-timeline': (t, size) async {
      await mountAttachment(t, size, const {
        'id': 'image',
        'filename': 'image.png',
        'mimeType': 'image/png',
      });
      await t.tap(find.byTooltip('Preview image.png'));
      await settleImage(t);
      final phone = size.width < 640;
      return SurfaceProbe(
        isOpen: lightboxOpen,
        x: find.byTooltip('Close preview'),
        back: phone
            ? find.bySemanticsLabel('Back')
            : find.byTooltip('Close preview'),
        scrim: emptyStage(size),
      );
    },
    'image-lightbox-draft': (t, size) async {
      final (w, api) = await mountWorkspace(t, size);
      api.routes['POST /attachments/upload'] = (_) => {
        'attachments': [
          {'id': 'draft-att', 'filename': 'pic.png', 'mimeType': 'image/png'},
        ],
      };
      await t.runAsync(() => w.attachUpload('pic.png', _png));
      await frames(t, 20);
      await t.tap(find.byKey(const ValueKey('composer-attachment-0')));
      await frames(t, 20);
      await settleImage(t); // display-size decode is real async work
      return SurfaceProbe(
        isOpen: lightboxOpen,
        x: find.byTooltip('Close preview'),
        scrim: emptyStage(size),
      );
    },
    'image-lightbox-files': (t, size) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final client = _Client()..user = RaftRecord({'id': 'alice'});
      client.selectServer('server');
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 'server', 'role': 'owner'})
        ..channel = RaftChannel({'id': 'channel', 'joined': true});
      addTearDown(() async {
        await t.pumpWidget(const SizedBox());
        w.dispose();
        await client.dispose();
      });
      late BuildContext host;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Builder(
            builder: (context) {
              host = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );
      final actions = SourceChannelFilesActions(
        controller: w,
        authorized: (_) => true,
        context: () => host,
        acquireImage: (file, authorized, rendition) async =>
            SourceChannelImageLease(
              provider: MemoryImage(_png),
              release: () async {},
            ),
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
            },
            'm1',
            'channel',
            'channel',
            null,
            'channel',
            '2026-06-22T00:00:00Z',
          ),
        ),
      );
      await frames(t, 20);
      await settleImage(t); // display-size decode is real async work
      return SurfaceProbe(
        isOpen: lightboxOpen,
        x: find.byTooltip('Close preview'),
        scrim: emptyStage(size),
      );
    },
    'attachment-preview': (t, size) async {
      await mountAttachment(t, size, const {
        'id': 'doc',
        'filename': 'research.md',
        'mimeType': 'text/markdown',
      });
      await t.tap(find.text('research.md'));
      await settleImage(t);
      return SurfaceProbe(
        isOpen: () =>
            find.byType(RaftAttachmentPreviewShell).evaluate().isNotEmpty,
        x: find.byTooltip('Close preview'),
        back: find.byTooltip('Close preview'),
      );
    },
    'attachment-html-preview': (t, size) async {
      await mountAttachment(t, size, const {
        'id': 'page',
        'filename': 'page.html',
        'mimeType': 'text/html',
      });
      await t.tap(find.text('page.html'));
      await settleImage(t);
      return SurfaceProbe(
        isOpen: () =>
            find.byType(RaftAttachmentPreviewShell).evaluate().isNotEmpty,
        x: find.byTooltip('Close preview'),
        back: find.byTooltip('Close preview'),
      );
    },
    'attachment-comments-aside': (t, size) async {
      await mountAttachment(t, size, const {
        'id': 'doc',
        'filename': 'research.md',
        'mimeType': 'text/markdown',
      });
      await t.tap(find.text('research.md'));
      await settleImage(t);
      final toggle = find.byKey(const ValueKey('attachment-preview-mode'));
      await t.tap(toggle);
      await frames(t, 20);
      return SurfaceProbe(
        isOpen: () =>
            find.byType(RaftComposer).hitTestable().evaluate().isNotEmpty,
        x: toggle,
      );
    },
    'mermaid-fullscreen': (t, size) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: RaftMessageBody(
                content:
                    '```mermaid\nflowchart LR\n A[Draft] --> B[Review]\n```',
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Expand diagram'));
      await t.pumpAndSettle();
      return SurfaceProbe(
        isOpen: () =>
            find.byKey(const Key('mermaid-fullscreen')).evaluate().isNotEmpty,
        x: find.byTooltip('Close fullscreen'),
        scrim: Offset(4, size.height / 2),
      );
    },
    'image-export-review': (t, size) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final client = _Client()..user = RaftRecord({'id': 'alice'});
      client.selectServer('server');
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 'server', 'role': 'owner'})
        ..channel = RaftChannel({'id': 'channel', 'joined': true});
      addTearDown(() async {
        await t.pumpWidget(const SizedBox());
        w.dispose();
        await client.dispose();
      });
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => MessageImageReview(
                    controller: w,
                    bytes: _png,
                    filename: 'export.png',
                    authorized: () => true,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await frames(t, 20);
      return SurfaceProbe(
        isOpen: () => find.byType(MessageImageReview).evaluate().isNotEmpty,
        x: find.byTooltip('Close preview'),
        scrim: const Offset(4, 4),
      );
    },
  };
  registerCloseTests(viewerSurfaces, harness);

  // Web ImageLightbox: only an *empty-stage* click closes - not a click on
  // the image and not a drag that ends on the empty stage.
  for (final id in [
    'image-lightbox-timeline',
    'image-lightbox-draft',
    'image-lightbox-files',
  ]) {
    testWidgets('$id: a tap on the image or a drag stays open', (t) async {
      final probe = await harness[id]!(t, const Size(1280, 800));
      final image = find.descendant(
        of: find.byType(RaftAttachmentLightbox),
        matching: find.byType(Image),
      );
      expect(image, findsOneWidget);
      await t.tapAt(t.getCenter(image));
      await frames(t, 20);
      expect(probe.isOpen(), isTrue, reason: '$id closed on an image tap');
      final from = probe.scrim!;
      final gesture = await t.startGesture(from);
      await gesture.moveBy(const Offset(60, 0));
      await gesture.up();
      await frames(t, 20);
      expect(probe.isOpen(), isTrue, reason: '$id closed after a drag');
      await t.tapAt(from);
      await frames(t, 20);
      expect(probe.isOpen(), isFalse, reason: '$id: empty-stage tap');
    });
  }

  // The shell's Scaffold registers its own DismissIntent action; a scope
  // above it never sees Escape once a control inside the Scaffold has focus.
  testWidgets('Escape closes the profile panel after a shell control took '
      'focus', (t) async {
    final (w, _) = await mountWorkspace(t, const Size(1280, 800));
    // A tap on a control gives it focus (here: the channel's Tasks tab).
    final tabs = find.byKey(const Key('conversation-tabs'));
    await t.tap(find.descendant(of: tabs, matching: find.text('Tasks')));
    await frames(t, 20);
    w.openProfile(RaftProfileKind.human, 'bob');
    await frames(t, 25);
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<RaftControl>(),
      isNotNull,
      reason: 'a shell control must hold focus for this check',
    );
    await pressEscape(t);
    expect(find.byKey(const Key('profile-panel')), findsNothing);
  });

  testWidgets('a dialog above the lightbox owns Escape; the lightbox still '
      'closes afterwards', (t) async {
    final probe = await harness['image-lightbox-timeline']!(
      t,
      const Size(1280, 800),
    );
    final navigator = Navigator.of(
      t.element(find.byType(RaftAttachmentLightbox)),
      rootNavigator: true,
    );
    final top = DialogRoute<void>(
      context: t.element(find.byType(RaftAttachmentLightbox)),
      barrierDismissible: false,
      builder: (_) => const AlertDialog(title: Text('Downloading')),
    );
    unawaited(navigator.push(top));
    await frames(t, 20);
    await t.tap(find.byTooltip('Close preview'), warnIfMissed: false);
    await frames(t, 20);
    expect(probe.isOpen(), isTrue, reason: 'X reached through the dialog');
    navigator.removeRoute(top);
    await frames(t, 20);
    await pressEscape(t);
    expect(probe.isOpen(), isFalse, reason: 'Escape stuck after the dialog');
  });
}
