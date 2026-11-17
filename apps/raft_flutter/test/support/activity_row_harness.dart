import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/activity_row_host.dart';
import 'package:raft_ui/raft_ui.dart';

/// The clock the rows are read at: Tuesday 17 November 2026, 15:30 local.
final fixedNow = DateTime(2026, 11, 17, 15, 30);

/// Pins the wall clock rows tell time by, for one test.
void useFixedClock([DateTime? now]) {
  final before = sourceTimeNow;
  sourceTimeNow = () => now ?? fixedNow;
  addTearDown(() => sourceTimeNow = before);
}

/// A client with nothing to say: the Activity row reads the controller's lists.
class RowClient extends RaftClient {
  RowClient()
    : super(
        origin: 'https://row-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  final _stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => _stream.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
}

/// The calls a row made to its page.
class RowCalls {
  final actions = <String>[];
  final menus = <Offset>[];
  final activations = <int>[];
  var opened = 0, objects = <Map<String, dynamic>>[];
}

class RowFixture {
  RowFixture({
    List<RaftChannel> channels = const [],
    List<RaftChannel> dms = const [],
    this.agents = const [],
    this.people = const [],
  }) {
    client = RowClient();
    client.selectServer('s1');
    w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'})
      ..channels = channels
      ..dms = dms;
  }
  late final RowClient client;
  late final WorkspaceController w;
  final List<Map<String, dynamic>> agents, people;
  final calls = RowCalls();

  Future<void> dispose() async {
    w.dispose();
    await client.dispose();
  }

  ActivityRowHost host({
    String filter = 'all',
    bool selected = false,
    bool located = false,
    bool? phoneTouch,
    bool? taskV2 = false,
    bool canonical = false,
    bool withObjectOpen = false,
  }) => ActivityRowHost(
    controller: w,
    filter: filter,
    interval: const Duration(milliseconds: 300),
    selected: selected,
    located: located,
    canonical: canonical,
    popupOpen: false,
    phoneTouch: phoneTouch,
    taskV2: taskV2,
    open: () => calls.opened++,
    activate: (detail, height, {bool pointer = false}) =>
        calls.activations.add(detail),
    menu: calls.menus.add,
    action: calls.actions.add,
    stableSender: (key, build) => build(),
    directorySenderLabel: (id, type) => '',
    agents: agents,
    people: people,
    onOpenObject: withObjectOpen ? calls.objects.add : null,
  );
}

/// Pumps [child] in the Raft theme at [size] on [platform] (Android is touch,
/// Linux a mouse).
Future<void> pumpRowApp(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1440, 900),
  TargetPlatform platform = TargetPlatform.linux,
  bool dark = false,
  double width = 379,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: raftTheme(dark: dark).copyWith(platform: platform),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width < size.width ? width : size.width,
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The environments AGENTS.md names for interaction tests.
const rowEnvs = [
  ('linux 1440x900 mouse', Size(1440, 900), TargetPlatform.linux),
  ('linux 390x844 mouse', Size(390, 844), TargetPlatform.linux),
  ('android 856x944 touch', Size(856, 944), TargetPlatform.android),
  ('android 944x856 touch', Size(944, 856), TargetPlatform.android),
  ('android 390x844 touch', Size(390, 844), TargetPlatform.android),
];

Map<String, dynamic> channelRow({
  String id = 'c1',
  String name = 'launch-week',
  String preview = 'Draft is ready',
  String sender = 'Bob',
  String senderId = 'bob',
  int unread = 0,
  Object? at,
  Map<String, dynamic> extra = const {},
}) => {
  'kind': 'channel',
  'channelId': id,
  'channelName': name,
  'channelType': 'channel',
  'lastMessagePreview': preview,
  'lastMessageSenderType': 'user',
  'lastMessageSenderId': senderId,
  'lastMessageSenderName': sender,
  'lastMessageAt': (at ?? fixedNow.subtract(const Duration(minutes: 3)))
      .toString()
      .replaceFirst(' ', 'T'),
  'unreadCount': unread,
  ...extra,
};

Map<String, dynamic> threadRow({
  String id = 't1',
  String parentPreview = 'Ship the build',
  String preview = 'Looks good',
  String sender = 'Bob',
  String senderId = 'bob',
  int unread = 0,
  Object? at,
  Map<String, dynamic> extra = const {},
}) => {
  'kind': 'thread',
  'threadChannelId': id,
  'parentChannelId': 'c1',
  'parentChannelName': 'launch-week',
  'parentChannelType': 'channel',
  'parentMessagePreview': parentPreview,
  'latestActivityPreview': preview,
  'latestActivitySenderType': 'user',
  'latestActivitySenderId': senderId,
  'latestActivitySenderName': sender,
  'lastActivityAt': (at ?? fixedNow.subtract(const Duration(minutes: 3)))
      .toString()
      .replaceFirst(' ', 'T'),
  'unreadCount': unread,
  'isFollowing': true,
  ...extra,
};

RaftChannel channelRecord(
  String id,
  String name, {
  String type = 'channel',
  Map<String, dynamic> extra = const {},
}) => RaftChannel({
  'id': id,
  'serverId': 's1',
  'name': name,
  'type': type,
  'joined': true,
  ...extra,
});
