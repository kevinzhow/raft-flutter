// A DM with the RaftBench service agent shows the read-only notice instead of
// the composer (Web ChatPanel `raftbench-service-dm-notice`); other DMs keep it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_footer_widgets.dart';
import 'package:raft_flutter/features/raftbench_service_notice.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/raftbench_host.dart';

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      switch (path) {
        '/agents' => [
          for (final (id, service) in [('svc', true), ('plain', false)])
            {
              'id': id,
              'name': id,
              'status': 'active',
              'runtime': 'external',
              'model': 'external',
              'serverId': 's',
              if (service) 'raftbenchService': true,
            },
        ],
        '/servers/s/machines' => {'machines': <dynamic>[]},
        _ => <dynamic>[],
      };
}

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
}

Future<_Workspace> _workspace(WidgetTester t, {required String peer}) async {
  final w = _Workspace(_Client())
    ..server = RaftRecord({'id': 's', 'role': 'owner'});
  addTearDown(w.dispose);
  await t.runAsync(w.entityDirectory.preload);
  w.channels = [
    RaftChannel({
      'id': 'dm1',
      'name': 'dm',
      'type': 'dm',
      'joined': true,
      'peerType': 'agent',
      'peerId': peer,
    }),
  ];
  w.dms = w.channels;
  w.channel = w.channels.first;
  return w;
}

void main() {
  testWidgets(
    'the service agent DM replaces the composer with the info notice',
    (t) async {
      final w = await _workspace(t, peer: 'svc');
      expect(isRaftbenchServiceDm(w), isTrue);
      late Widget? footer;
      await mountRaftbench(
        t,
        Builder(
          builder: (context) {
            footer = channelFooterReplacement(
              context,
              w,
              DateTime.utc(2026, 10, 24),
              onOpenChannelSettings: null,
              onViewBilling: null,
              onJoin: () async {},
            );
            return footer ?? const SizedBox();
          },
        ),
      );
      expect(footer, isA<RaftbenchServiceDmNotice>());
      expect(
        find.text(
          'This read-only analysis agent does not reply to DMs. Results appear on the RaftBench page.',
        ),
        findsOneWidget,
      );
      await unmount(t);
    },
  );

  testWidgets('another agent DM keeps its composer', (t) async {
    final w = await _workspace(t, peer: 'plain');
    expect(isRaftbenchServiceDm(w), isFalse);
    late Widget? footer;
    await mountRaftbench(
      t,
      Builder(
        builder: (context) {
          footer = channelFooterReplacement(
            context,
            w,
            DateTime.utc(2026, 10, 24),
            onOpenChannelSettings: null,
            onViewBilling: null,
            onJoin: () async {},
          );
          return const SizedBox();
        },
      ),
    );
    expect(footer, isNull);
    await unmount(t);
  });

  testWidgets('an agent DM whose agent is unknown is not the service DM', (
    t,
  ) async {
    final w = await _workspace(t, peer: 'nobody');
    expect(isRaftbenchServiceDm(w), isFalse);
  });

  testWidgets('Chinese wording (Web zh-cn)', (t) async {
    await mountRaftbench(
      t,
      const RaftbenchServiceDmNotice(),
      locale: const Locale('zh'),
    );
    expect(
      find.text('这是只读分析 agent，不会回复私信。结果显示在 RaftBench 页面。'),
      findsOneWidget,
    );
    await unmount(t);
  });
}
