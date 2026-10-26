// Native Profile probe of the actual Activity conversation list. A normal
// WidgetsFlutterBinding drives the production drag/physics path while a local
// synthetic client delivers a live update. No production login or network.
// Set RAFT_ACTIVITY_BOUNCE_OUT to a new absolute JSON path before building.
// This measures a deterministic content-update collision, not native trackpad
// event delivery or the cause of all long-session CPU growth.
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' show FramePhase;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const output = String.fromEnvironment('RAFT_ACTIVITY_BOUNCE_OUT');
const revision = String.fromEnvironment('RAFT_ACTIVITY_BOUNCE_REVISION');

Map<String, dynamic> row(int i) => {
  'kind': 'channel',
  'channelId': 'ch$i',
  'channelName': 'Fixture channel $i',
  'lastMessageId': 'm$i',
  'lastMessageAt': '2026-10-10T00:00:00Z',
  'lastMessagePreview': '本地合成动态摘要 / Synthetic preview $i',
  'lastMessageSenderId': 'bob',
  'lastMessageSenderType': 'user',
  'lastMessageSenderName': 'Fixture Bob',
  'latestActivitySeq': '${1000 - i}',
  'doneFrontierSeq': '${1000 - i}',
  'unreadCount': 0,
};

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      );
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => ingress.stream;
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
  }) async => path == '/feature-flags/evaluate'
      ? {
          'evaluations': [
            {'key': 'activity_conversation_list_v0', 'enabled': true},
          ],
        }
      : <String, dynamic>{};
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final inbox = [for (var i = 0; i < 40; i++) row(i)];
  @override
  Future<void> refreshUnread() async {}
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/channels/inbox') {
      return {
        'items': List.of(inbox),
        'hasMore': false,
        'totalCount': inbox.length,
        'totalUnreadCount': 0,
      };
    }
    if (path == '/agents' || path.endsWith('/members')) return <dynamic>[];
    return {'items': <dynamic>[], 'hasMore': false};
  }
}

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  if (!kProfileMode || output.isEmpty || File(output).existsSync()) {
    throw StateError('Requires Profile mode and a new output path');
  }
  // This native fixture must never read or write real device preferences.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  // Keep this identical for both builds; native accessibility commonly turns
  // it on in the real workspace too.
  binding.ensureSemantics();
  final client = _Client()..user = RaftRecord({'id': 'reader'});
  client.selectServer('fixture-server');
  final workspace = _Workspace(client)
    ..server = RaftRecord({'id': 'fixture-server', 'role': 'owner'})
    ..channels = [
      for (var i = 0; i < 40; i++)
        RaftChannel({'id': 'ch$i', 'name': 'Fixture $i', 'joined': true}),
    ];
  // A minimal Material host keeps the SDK's experimental desktop-windowing
  // branch out of this probe (the pinned SDK can fail AOT on its FFI structs).
  runApp(
    MediaQuery.fromView(
      view: binding.platformDispatcher.views.first,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Localizations(
          locale: const Locale('en'),
          delegates: const [
            DefaultWidgetsLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
          ],
          child: Theme(
            data: raftTheme().copyWith(platform: TargetPlatform.macOS),
            child: DefaultTextStyle(
              style: const TextStyle(fontSize: 14, color: Colors.black),
              child: FocusScope(
                child: Overlay(
                  initialEntries: [
                    OverlayEntry(builder: (_) => _Lab(workspace, client)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Lab extends StatefulWidget {
  const _Lab(this.workspace, this.client);
  final _Workspace workspace;
  final _Client client;
  @override
  State<_Lab> createState() => _LabState();
}

class _LabState extends State<_Lab> {
  final pageKey = GlobalKey();
  final frames = <Map<String, int>>[];
  final rounds = <Map<String, dynamic>>[];
  bool busy = false;
  String status = 'Ready';

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(timings);
  }

  void timings(List<FrameTiming> values) {
    if (!busy) return;
    frames.addAll([
      for (final frame in values)
        {
          'startUs': frame.timestampInMicroseconds(FramePhase.buildStart),
          'ui': frame.buildDuration.inMicroseconds,
          'r': frame.rasterDuration.inMicroseconds,
        },
    ]);
  }

  Future<void> nextFrame() => WidgetsBinding.instance.endOfFrame;

  ScrollPosition? listPosition() {
    ScrollPosition? position;
    var rowsReady = false;
    void visit(Element element) {
      if (element.widget is RaftConversationListRow) rowsReady = true;
      if (element case StatefulElement(state: final ScrollableState state)) {
        if (axisDirectionToAxis(state.position.axisDirection) ==
            Axis.vertical) {
          position ??= state.position;
        }
      }
      element.visitChildren(visit);
    }

    final context = pageKey.currentContext;
    if (context is Element) visit(context);
    return rowsReady ? position : null;
  }

  Future<void> run() async {
    if (busy) return;
    final scroll = listPosition();
    if (scroll == null || !scroll.hasContentDimensions) {
      setState(() => status = 'Waiting for fixture rows');
      return;
    }
    setState(() {
      busy = true;
      status = 'Running';
    });
    try {
      for (var i = 0; i < 20; i++) {
        final update = i.isOdd;
        scroll.jumpTo(scroll.maxScrollExtent - 20);
        await nextFrame();
        final start = developer.Timeline.now;
        final drag = scroll.drag(
          DragStartDetails(globalPosition: const Offset(200, 400)),
          () {},
        );
        double before = 0, after = 0;
        try {
          for (final amount in [100.0, 40.0]) {
            drag.update(
              DragUpdateDetails(
                delta: Offset(0, -amount),
                primaryDelta: -amount,
                globalPosition: const Offset(200, 300),
              ),
            );
            await nextFrame();
          }
          before = scroll.pixels;
          final limitBefore = scroll.maxScrollExtent;
          if (!scroll.outOfRange) {
            throw StateError('No held elastic overscroll');
          }
          if (update) {
            final target = i % 4 == 1 ? 'ch5' : 'ch6';
            final index = widget.workspace.inbox.indexWhere(
              (row) => row['channelId'] == target,
            );
            final old = widget.workspace.inbox.removeAt(index);
            widget.workspace.inbox.insert(0, {
              ...old,
              'lastMessageId': 'live$i',
              'latestActivitySeq': '${10000 + i}',
            });
            widget.client.ingress.add(
              RaftEvent('message:new', {
                'id': 'live$i',
                'channelId': target,
                'seq': 10000 + i,
                'content': old['lastMessagePreview'],
                'senderId': 'bob',
                'senderType': 'user',
                'senderName': 'Fixture Bob',
              }),
            );
          }
          await nextFrame();
          after = scroll.pixels;
          rounds.add({
            'round': i,
            'warmup': i < 4,
            'update': update,
            'startUs': start,
            'before': before,
            'after': after,
            'jumpPx': (after - before).abs(),
            'maxBefore': limitBefore,
            'maxAfter': scroll.maxScrollExtent,
            'outsideAfter': scroll.outOfRange,
          });
        } finally {
          drag.end(DragEndDetails(primaryVelocity: 0));
        }
        await Future<void>.delayed(const Duration(milliseconds: 700));
        rounds.last['endUs'] = developer.Timeline.now;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      await File(output).writeAsString(
        jsonEncode({
          'revision': revision,
          'mode': 'profile',
          'binding': 'normal WidgetsFlutterBinding',
          'fixture': 'synthetic 40-row production ResourceView, no network',
          'input':
              'production ScrollPosition.drag; native event delivery excluded',
          'semantics':
              WidgetsBinding.instance.platformDispatcher.semanticsEnabled,
          'refreshRate': view.display.refreshRate,
          'dpr': view.devicePixelRatio,
          'physicalSize': [view.physicalSize.width, view.physicalSize.height],
          'rounds': rounds,
          'frames': frames,
          'rss': ProcessInfo.currentRss,
        }),
      );
      setState(() => status = 'Complete: ${rounds.length} rounds');
    } catch (error, stack) {
      await File(output).writeAsString(
        jsonEncode({'error': '$error', 'stack': '$stack', 'rounds': rounds}),
      );
      setState(() => status = 'Failed: $error');
    } finally {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Row(
          children: [
            TextButton(
              onPressed: busy ? null : run,
              child: const Text('Run bounce probe'),
            ),
            Text('$revision / $status'),
          ],
        ),
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 400,
                child: ResourceView(
                  key: pageKey,
                  controller: widget.workspace,
                  section: 'activity',
                  activitySidebarEnabled: true,
                  onMessage: (_, _) async {},
                ),
              ),
              const Expanded(child: Center(child: Text('Synthetic fixture'))),
            ],
          ),
        ),
      ],
    ),
  );
}
