/// Isolated native acceptance host: synthetic inbox, in-memory preferences,
/// notification-lab identity and the tray's separate lab registry preference.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/windows_tray_settings.dart';
import 'package:raft_flutter/platform/app_window.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_flutter/platform/windows_notifications.dart';
import 'package:raft_flutter/platform/windows_tray.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // This acceptance host must never read or write the product's preference file.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final lab = _Lab();
  await lab.start();
  runApp(
    MaterialApp(
      theme: raftTheme(),
      navigatorKey: lab.navigator,
      builder: (_, child) =>
          AppWindowCommands(navigatorKey: lab.navigator, child: child!),
      home: _Page(lab),
    ),
  );
}

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://tray-lab.invalid',
        sessionStore: MemorySessionStore(),
        clientKind: 'desktop',
      ) {
    user = RaftRecord({'id': 'tray-lab-user'});
    selectServer('tray-lab');
  }
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);
  List<Map<String, dynamic>> rows = [];
  @override
  bool get signedIn => user != null;
  @override
  Stream<RaftEvent> get events => ingress.stream;
  @override
  Future<List<RaftRecord>> servers() async => [
    RaftRecord({'id': 'tray-lab'}),
  ];
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/servers/unread-summary') {
      return [
        {
          'serverId': 'tray-lab',
          'unreadCount': 0,
          'activityUnreadCount': rows.length,
        },
      ];
    }
    if (path.endsWith('/notification-settings')) {
      return {'serverPushMode': 'all', 'serverPushMuted': false};
    }
    if (path == '/channels/inbox') {
      return {'items': rows, 'totalUnreadCount': rows.length};
    }
    if (path == '/channels/lab-dm') {
      return {'id': 'lab-dm', 'serverId': 'tray-lab', 'type': 'dm'};
    }
    if (path.startsWith('/messages/context/')) {
      return {
        'messages': [
          {'id': path.split('/').last, 'channelId': 'lab-dm'},
        ],
      };
    }
    throw StateError('Unexpected synthetic request: $path');
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client) : super(ownsClient: false);
  String? opened;
  @override
  Future<void> jumpToMessage(
    String id,
    String? message, {
    bool navigate = true,
    bool replaceEntry = false,
  }) async {
    opened = '$id/$message';
    notifyListeners();
  }
}

class _Windows extends WindowsNotifications {
  _Windows() : super(lab: true);
  int posted = 0;
  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    await super.show(id: id, title: title, body: body, payload: payload);
    posted++;
  }
}

class _Lab extends ChangeNotifier {
  final navigator = GlobalKey<NavigatorState>();
  final client = _Client();
  late final workspace = _Workspace(client)
    ..server = RaftRecord({'id': 'tray-lab', 'role': 'owner'})
    ..servers = [
      RaftRecord({'id': 'tray-lab', 'role': 'owner'}),
    ];
  final windows = _Windows();
  final tray = WindowsTray(platform: TargetPlatform.windows, lab: true);
  late final service = NativeNotificationService(
    platform: TargetPlatform.windows,
    windows: windows,
  );
  late final coordinator = NativeContentCoordinator(
    notifications: service,
    tray: tray,
    links: const Stream.empty(),
  );
  final draft = TextEditingController(text: 'Synthetic retained draft 56');
  bool queued = false, previewOpen = false, pageOpen = false;
  int serial = 0;
  Future<void> writes = Future.value();

  Future<void> start() async {
    workspace.activityUnread.start();
    await coordinator.init();
    coordinator.bindWorkspace(workspace);
    coordinator.onForegroundChanged = () {
      // Match the main root's visibility synchronization for this always-mounted
      // synthetic workspace; the lab has no server picker or covered workspace.
      workspace.setForeground(coordinator.appForeground);
      unawaited(record());
    };
    workspace.addListener(() => unawaited(record()));
    await service.bind(coordinator.currentScope);
    await record();
  }

  Future<void> record() async {
    final state = await WindowsTray.nativeChannel
        .invokeMapMethod<String, dynamic>('state');
    final history = await const MethodChannel('app.raft/windows-notifications')
        .invokeMethod<int>('labHistory');
    final receipt = jsonEncode({
      'pid': pid,
      'tray': state,
      'appForeground': coordinator.appForeground,
      'workspaceForeground': workspace.foreground,
      'unread': workspace.activityUnread.totalUnreadCount,
      'posted': windows.posted,
      'osHistory': history,
      'opened': workspace.opened,
      'draft': draft.text,
      'queued': queued,
      'previewOpen': previewOpen,
      'pageOpen': pageOpen,
      'notificationError': service.error,
    });
    writes = writes.then(
      (_) => File(
        p.join(p.dirname(Platform.resolvedExecutable), 'tray-lab-receipt.json'),
      ).writeAsString(receipt),
    );
    await writes;
    notifyListeners();
  }

  void queue() {
    queued = true;
    notifyListeners();
    // One deliberate lab arrival, never a product/background polling loop.
    Timer(const Duration(seconds: 5), () async {
      queued = false;
      final message = 'lab-${++serial}';
      client.rows = [
        {
          'kind': 'dm',
          'channelId': 'lab-dm',
          'channelName': 'Tray acceptance',
          'lastMessageId': message,
          'lastMessagePreview': 'Synthetic background message',
          'unreadCount': 1,
          'lastMessageAt': DateTime.now().toUtc().toIso8601String(),
        },
      ];
      client.ingress.add(
        RaftEvent('message:new', {
          'id': message,
          'channelId': 'lab-dm',
          'seq': '$serial',
          'senderId': 'synthetic-sender',
          'senderType': 'user',
        }),
      );
      await workspace.activityUnread.refresh();
      await coordinator.desktop?.deliverPending();
      await coordinator.dockUnread.settled;
      await record();
    });
  }

  Future<void> clear() async {
    client.rows = [];
    await workspace.activityUnread.refresh();
    await coordinator.dockUnread.settled;
    await record();
  }

  Future<void> quit() async {
    await service.bind(null); // Clear only the isolated lab's OS notifications.
    await record();
    await tray.quit();
  }
}

class _Page extends StatelessWidget {
  const _Page(this.lab, {this.title = 'Raft tray lab — synthetic data only'});
  final _Lab lab;
  final String title;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListenableBuilder(
      listenable: lab,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PID: $pid | Posted: ${lab.windows.posted} | Unread: ${lab.workspace.activityUnread.totalUnreadCount}',
            ),
            TextField(
              controller: lab.draft,
              decoration: const InputDecoration(
                labelText: 'Draft retained when hidden',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: lab.queued ? null : lab.queue,
              child: Text(
                lab.queued ? 'Message queued' : 'Queue message in 5 seconds',
              ),
            ),
            ElevatedButton(
              onPressed: lab.clear,
              child: const Text('Clear unread'),
            ),
            ElevatedButton(
              onPressed: () {
                lab.previewOpen = true;
                unawaited(lab.record());
                unawaited(
                  showDialog<void>(
                    context: context,
                    builder: (context) => RaftAttachmentPreviewShell(
                      filename: 'synthetic-tray-preview.md',
                      onClose: () => Navigator.of(context).pop(),
                      child: const Text('Ctrl+W closes this preview first.'),
                    ),
                  ).whenComplete(() {
                    lab.previewOpen = false;
                    unawaited(lab.record());
                  }),
                );
              },
              child: const Text('Open synthetic preview'),
            ),
            ElevatedButton(
              onPressed: lab.record,
              child: const Text('Refresh receipt'),
            ),
            ElevatedButton(
              onPressed: lab.pageOpen
                  ? null
                  : () {
                      lab.pageOpen = true;
                      unawaited(lab.record());
                      unawaited(
                        Navigator.of(context)
                            .push<void>(
                              MaterialPageRoute(
                                builder: (_) => _Page(
                                  lab,
                                  title: 'Synthetic retained page',
                                ),
                              ),
                            )
                            .whenComplete(() {
                              lab.pageOpen = false;
                              unawaited(lab.record());
                            }),
                      );
                    },
              child: const Text('Open synthetic full page'),
            ),
            ElevatedButton(
              onPressed: lab.quit,
              child: const Text('Quit test app'),
            ),
            const SizedBox(height: 16),
            WindowsTraySettings(tray: lab.tray),
          ],
        ),
      ),
    ),
  );
}
