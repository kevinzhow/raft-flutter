// Work benchmark on the actual native profile ResourceView. No server or input.
// Build with --profile --target=../../tool/performance/activity_row_work.dart
// and --dart-define=RAFT_ACTIVITY_WORK_OUT=<new absolute output file>.
// This measures synchronous row acceptance + identity/anchor observation, not
// complete frame latency, Socket.IO delivery or the overall 120 Hz budget.
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

const output = String.fromEnvironment('RAFT_ACTIVITY_WORK_OUT');
const revision = String.fromEnvironment('RAFT_ACTIVITY_WORK_REVISION');
bool measuring = false;
int unrelatedReads = 0;

class _MeasuredRow extends MapBase<String, dynamic> {
  _MeasuredRow(this.data, this.affected);
  final Map<String, dynamic> data;
  final bool affected;
  @override
  dynamic operator [](Object? key) {
    if (measuring && !affected) unrelatedReads++;
    return data[key];
  }

  @override
  void operator []=(String key, dynamic value) => data[key] = value;
  @override
  Iterable<String> get keys => data.keys;
  @override
  void clear() => data.clear();
  @override
  dynamic remove(Object? key) => data.remove(key);
}

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      );
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
  }) async => <String, dynamic>{};
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client, this.inbox);
  final List<Map<String, dynamic>> inbox;
  @override
  Future<void> refreshUnread() async {}
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/channels/inbox') {
      return {'items': inbox, 'totalCount': inbox.length, 'hasMore': false};
    }
    if (path == '/agents' || path.endsWith('/members')) return <dynamic>[];
    return {'items': <dynamic>[], 'hasMore': false};
  }
}

Map<String, dynamic> row(int i) => {
  'kind': 'channel',
  'channelId': 'ch$i',
  'channelName': 'Channel $i',
  'lastMessageId': 'old$i',
  'lastMessageAt': '2026-10-10T00:00:00Z',
  'lastMessagePreview': 'Local benchmark $i',
  'lastMessageSenderId': 'bob',
  'lastMessageSenderName': 'Bob',
  'lastMessageSenderType': 'user',
  'latestActivitySeq': '1',
  'doneFrontierSeq': '1',
  'unreadCount': 0,
};

Future<Map<String, dynamic>> run(int size) async {
  final client = _Client()..user = RaftRecord({'id': 'alice'});
  client.selectServer('s1');
  final workspace = _Workspace(client, [for (var i = 0; i < size; i++) row(i)])
    ..server = RaftRecord({'id': 's1', 'role': 'owner'})
    ..channels = [
      for (var i = 0; i < size; i++)
        RaftChannel({'id': 'ch$i', 'name': 'Channel $i', 'joined': true}),
    ];
  final key = GlobalKey();
  runApp(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: ResourceView(
          key: key,
          controller: workspace,
          section: 'activity',
          activitySidebarEnabled: true,
          onMessage: (_, _) async {},
        ),
      ),
    ),
  );
  await WidgetsBinding.instance.endOfFrame;
  dynamic page = key.currentState;
  for (
    var attempt = 0;
    attempt < 10 && (page.loading == true || page.rows.length != size);
    attempt++
  ) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await WidgetsBinding.instance.endOfFrame;
    page = key.currentState;
  }
  if (page.rows.length != size)
    throw StateError('Accepted window is not ready');
  final measured = [
    for (var i = 0; i < size; i++)
      _MeasuredRow(page.rows[i] as Map<String, dynamic>, i >= size - 50),
  ];
  page.setState(() {
    page.rows = measured;
    page.acceptedActivityItems = measured;
  });
  await WidgetsBinding.instance.endOfFrame;
  final samples = <int>[];
  final batchReads = <int>[];
  var lastReads = 0;
  unrelatedReads = 0;
  for (var i = 0; i < 6200; i++) {
    final target = size - 1 - i % 50;
    final event = RaftEvent('message:new', {
      'id': 'new$i',
      'channelId': 'ch$target',
      'seq': 100000 + i,
      'content': 'Synthetic local message $i',
      'senderId': 'bob',
      'senderType': 'user',
      'senderName': 'Bob',
    });
    final clock = Stopwatch();
    measuring = i >= 200;
    clock.start();
    page.patchActivity(event);
    page.observeListUpdates();
    clock.stop();
    measuring = false;
    if (i >= 200) samples.add(clock.elapsedMicroseconds);
    if (samples.isNotEmpty && samples.length % 1000 == 0) {
      batchReads.add(unrelatedReads - lastReads);
      lastReads = unrelatedReads;
    }
    if (i % 50 == 49) await WidgetsBinding.instance.endOfFrame;
  }
  if (page.rows.length != size ||
      page.rows.first['lastMessageId'] != 'new6199') {
    throw StateError('The accepted live preview did not advance');
  }
  final reads = unrelatedReads;
  page = null;
  runApp(const SizedBox.shrink());
  await WidgetsBinding.instance.endOfFrame;
  workspace.dispose();
  await client.dispose();
  final ordered = samples.toList()..sort();
  return {
    'rows': size,
    'warmupMessages': 200,
    'measuredMessages': samples.length,
    'unrelatedFieldReads': reads,
    'medianUs': ordered[ordered.length ~/ 2],
    'p95Us': ordered[(ordered.length * .95).ceil() - 1],
    'maxUs': ordered.last,
    'over1ms': samples.where((value) => value >= 1000).length,
    'batches': [
      for (var batch = 0; batch < 6; batch++)
        {
          ...statistics(samples.sublist(batch * 1000, (batch + 1) * 1000)),
          'unrelatedFieldReads': batchReads[batch],
        },
    ],
    'samplesUs': samples,
  };
}

Map<String, dynamic> statistics(List<int> samples) {
  final ordered = samples.toList()..sort();
  return {
    'messages': samples.length,
    'medianUs': ordered[ordered.length ~/ 2],
    'p95Us': ordered[(ordered.length * .95).ceil() - 1],
    'maxUs': ordered.last,
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kProfileMode || output.isEmpty)
    throw StateError('Requires profile mode and a new output file');
  final destination = File(output);
  if (destination.existsSync())
    throw StateError('Earlier results must remain unchanged');
  final result = {
    'revision': revision,
    'profile': kProfileMode,
    'platform': Platform.operatingSystem,
    'dartVersion': Platform.version,
    'scope': 'ResourceView.patchActivity(message:new) + observeListUpdates; excludes layout, paint, network and outer workspace event listeners',
    'fixture': 'synthetic-local-no-network',
    'windows': [await run(100), await run(3000)],
  };
  await destination.writeAsString(
    const JsonEncoder.withIndent('  ').convert(result),
  );
  exit(0);
}
