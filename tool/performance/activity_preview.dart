// Manual background Computer Use benchmark. No scripted input or live server.
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show FramePhase;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

const output = String.fromEnvironment('RAFT_ACTIVITY_PREVIEW_OUT');
const revision = String.fromEnvironment('RAFT_ACTIVITY_PREVIEW_REVISION');
const row = <String, dynamic>{
  'kind': 'thread',
  'threadChannelId': 'thread-1',
  'parentChannelId': 'c1',
  'parentChannelName': 'Fixture',
  'parentMessageId': 'parent',
  'parentMessagePreview': 'Measure Activity preview',
  'latestActivityPreview': 'Local fixture reply',
  'unreadCount': 0,
  'latestActivityMessageId': 'reply',
  'replyCount': 1,
};
Map<String, dynamic> message(String id, String channel) => {
  'id': id,
  'channelId': channel,
  'seq': '1',
  'senderId': 'alice',
  'senderType': 'user',
  'senderName': 'Fixture user',
  'content': 'Fixture $id',
};

class FixtureTransport implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    final Object value;
    if (o.path == '/auth/login') {
      value = {
        'accessToken': 'fixture-only',
        'refreshToken': 'fixture-only',
        'user': {'id': 'alice'},
      };
    } else if (o.path == '/channels/inbox') {
      value = {
        'items': [row],
        'hasMore': false,
      };
    } else if (o.path.startsWith('/messages/context/')) {
      final parent = o.path.endsWith('/parent');
      value = {
        'messages': [
          message(parent ? 'parent' : 'reply', parent ? 'c1' : 'thread-1'),
        ],
      };
    } else if (o.path == '/feature-flags/evaluate') {
      value = {'evaluations': []};
    } else if (o.path.endsWith('/setup-projection')) {
      value = {'phase': 'complete', 'surface': 'complete', 'blocksChat': false};
    } else if (o.path.endsWith('/unread')) {
      value = {'channels': <String, int>{}};
    } else if (o.path.endsWith('/followed')) {
      value = {'threads': []};
    } else if (o.method != 'GET') {
      value = <String, dynamic>{};
    } else {
      value = <dynamic>[];
    }
    return ResponseBody.fromString(
      jsonEncode(value),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final client = RaftClient(
    origin: 'https://public-fixture.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = FixtureTransport(),
  );
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client);
  w.server = RaftRecord({'id': 's1', 'role': 'owner'});
  w.channel = RaftChannel({'id': 'c1', 'name': 'Fixture', 'joined': true});
  w.channels = [w.channel!];
  w.messageDomain.ledger.switchServer('s1');
  w.loading = false;
  w.setSection('activity');
  runApp(_Lab(w));
}

class _Lab extends StatefulWidget {
  const _Lab(this.w);
  final WorkspaceController w;
  @override
  State<_Lab> createState() => _LabState();
}

class _LabState extends State<_Lab> {
  final samples = <Map<String, dynamic>>[];
  int? pointerTime;
  bool warmAtPointer = false;
  String? lastContent;
  @override
  void initState() {
    super.initState();
    widget.w.addListener(changed);
    SchedulerBinding.instance.addTimingsCallback(timings);
  }

  void save() {
    if (output.isNotEmpty)
      File(output).writeAsStringSync(
        jsonEncode({
          'revision': revision,
          'profile': true,
          'fixture': 'local-no-network',
          'samples': samples,
        }),
      );
  }

  void changed() {
    final id = widget.w.location.content?.id;
    if (id != null && id != lastContent && pointerTime != null) {
      final sample = <String, dynamic>{
        'pointerUs': pointerTime,
        'selectionUs': developer.Timeline.now,
        'cache': warmAtPointer ? 'warm' : 'cold',
      };
      samples.add(sample);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        sample['firstUiFrameUs'] = developer.Timeline.now;
      });
    }
    lastContent = id;
  }

  void timings(List<FrameTiming> frames) {
    for (final sample in samples.where((s) => s['rasterFinishUs'] == null)) {
      for (final frame in frames) {
        if (frame.timestampInMicroseconds(FramePhase.buildStart) >=
            (sample['selectionUs'] as int)) {
          sample['rasterFinishUs'] = frame.timestampInMicroseconds(
            FramePhase.rasterFinish,
          );
          sample['buildUs'] = frame.buildDuration.inMicroseconds;
          sample['rasterUs'] = frame.rasterDuration.inMicroseconds;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    widget.w.removeListener(changed);
    SchedulerBinding.instance.removeTimingsCallback(timings);
    widget.w.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: raftTheme(RaftFamily.elegant),
    home: Column(
      children: [
        Material(
          child: Row(
            children: [
              Text('Activity preview $revision'),
              TextButton(
                onPressed: () {
                  widget.w.closeThread(navigate: false);
                  widget.w.navigation.navigate(
                    RaftLocation.at(
                      serverSlug: 's1',
                      route: RaftRoute.activity,
                    ),
                  );
                  widget.w.notifyListeners();
                },
                child: const Text('Reset Activity'),
              ),
              TextButton(onPressed: save, child: const Text('Export samples')),
            ],
          ),
        ),
        Expanded(
          child: Listener(
            onPointerUp: (_) {
              pointerTime = developer.Timeline.now;
              warmAtPointer = widget.w.messageDomain.ledger
                  .messages('thread-1')
                  .isNotEmpty;
            },
            child: WorkspaceView(
              controller: widget.w,
              appearance: const RaftAppearance(light: RaftFamily.elegant),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        ),
      ],
    ),
  );
}
