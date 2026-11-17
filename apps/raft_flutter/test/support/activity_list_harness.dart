import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/activity_filter_choice.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../activity_incremental_refresh_test.dart'
    show ActivityClient, ActivityWorkspace, activityFixture, channelRow;

export '../activity_incremental_refresh_test.dart'
    show ActivityClient, ActivityWorkspace, activityFixture, channelRow;

/// Where a list test runs: the size and the input.
class ListEnv {
  const ListEnv(this.name, this.size, this.platform);
  final String name;
  final Size size;
  final TargetPlatform platform;
  bool get touch => platform == TargetPlatform.android;
  bool get phone => size.width < 768;
}

const phoneTouch = ListEnv('390x844 Android', Size(390, 844), TargetPlatform.android);
const phoneMouse = ListEnv('390x844 Linux', Size(390, 844), TargetPlatform.linux);
const foldA = ListEnv('856x944 Android', Size(856, 944), TargetPlatform.android);
const foldB = ListEnv('944x856 Android', Size(944, 856), TargetPlatform.android);
const desktop = ListEnv('1440x900 Linux', Size(1440, 900), TargetPlatform.linux);

/// A row of day [day] (2026-10-DD), channel [i].
Map<String, dynamic> dayRow(int i, {int day = 10, int unread = 0, int? seq}) => {
  ...channelRow(i, unread: unread, seq: seq),
  'lastMessageAt': '2026-10-${day.toString().padLeft(2, '0')}T12:00:00Z',
};

Map<String, dynamic> threadRow(int i, {int unread = 0, int day = 10}) => {
  'kind': 'thread',
  'threadChannelId': 'th$i',
  'parentChannelId': 'ch$i',
  'parentChannelName': 'Channel $i',
  'parentChannelType': 'channel',
  'parentMessageId': 'pm$i',
  'parentMessagePreview': 'Thread $i',
  'channelName': 'Channel $i',
  'lastActivityAt': '2026-10-${day.toString().padLeft(2, '0')}T12:00:00Z',
  'lastMessagePreview': 'Reply $i',
  'lastMessageSenderType': 'user',
  'lastMessageSenderId': 'bob',
  'lastMessageSenderName': 'Bob',
  'latestActivitySeq': '${900 - i}',
  'doneFrontierSeq': '${900 - i}',
  'unreadCount': unread,
  'isFollowing': true,
  'hasMention': false,
};

class ListRig {
  ListRig(this.client, this.w);
  final ActivityClient client;
  final ActivityWorkspace w;
}

/// Mounts the Activity page in [env] with a toast host.
Future<dynamic> mountActivity(
  WidgetTester t,
  ActivityWorkspace w,
  ListEnv env, {
  bool dark = false,
  List<String>? opened,
}) async {
  SharedPreferences.setMockInitialValues({});
  DevicePreferences.adopt(await SharedPreferences.getInstance());
  addTearDown(DevicePreferences.reset);
  sourceTimeNow = () => DateTime.utc(2026, 10, 12, 15);
  addTearDown(() => sourceTimeNow = DateTime.now);
  t.view.physicalSize = env.size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: raftTheme(dark: dark).copyWith(platform: env.platform),
      builder: (context, child) => RaftToastHost(child: child!),
      home: Scaffold(
        body: ResourceView(
          controller: w,
          section: 'activity',
          onMessage: (id, _) async => opened?.add(id),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return t.state(find.byType(ResourceView));
}

Finder row(String key) => find.byKey(ValueKey(key));

/// A client that is also the server for Done: a written Done removes the row
/// from what the next read answers, so "after a reload" means something.
class ServerClient extends ActivityClient {
  ActivityWorkspace? server;
  final unfollowed = <String>{};

  /// `METHOD path`s the server refuses (500).
  final failPaths = <String>{};
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
  }) {
    if (failPaths.contains('$method $path')) {
      posts.add('$method $path');
      bodies.add(data);
      return Future.error(const RaftApiException('Server error', status: 500));
    }
    final rows = server?.inbox;
    if (method == 'POST' && rows != null && data is Map) {
      if (path == '/channels/inbox/done') {
        rows.removeWhere((r) => r['channelId'] == data['channelId']);
      } else if (path == '/channels/threads/done') {
        rows.removeWhere((r) => r['threadChannelId'] == data['threadChannelId']);
      } else if (path == '/channels/threads/unfollow') {
        for (final r in rows) {
          if (r['threadChannelId'] == data['threadChannelId']) {
            r['isFollowing'] = false;
          }
        }
      }
    }
    return super.request(
      method,
      path,
      data: data,
      query: query,
      authorized: authorized,
      retried: retried,
      cancellation: cancellation,
      onSendProgress: onSendProgress,
      headers: headers,
      acceptServerExit: acceptServerExit,
      receiveTimeout: receiveTimeout,
    );
  }
}

(ServerClient, ActivityWorkspace) serverFixture() {
  final client = ServerClient()..user = RaftRecord({'id': 'alice'});
  client.selectServer('s1');
  final w = ActivityWorkspace(client)
    ..server = RaftRecord({'id': 's1', 'role': 'owner'})
    ..channels = [
      for (var i = 0; i < 60; i++)
        RaftChannel({'id': 'ch$i', 'name': 'Channel $i', 'joined': true}),
    ];
  client.server = w;
  return (client, w);
}
