// The channel header the workspace mounts: description links open through the
// launcher, the muted bell follows `activityMuted`, and a dead link says so.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/workspace_channel_header.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/joint_channel_fixture.dart' show fixture;

void main() {
  Future<List<String>> mount(
    WidgetTester t,
    Map<String, dynamic> row, {
    Future<void> Function(String url)? launch,
  }) async {
    final (w, _) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    final opened = <String>[];
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: RaftToastHost(
          child: Scaffold(
            body: SizedBox(
              width: 700,
              child: WorkspaceChannelHeader(
                headerKey: const Key('header'),
                controller: w,
                channel: RaftChannel(row),
                backLabel: 'Back',
                onSearch: () {},
                onSettings: () {},
                launch:
                    launch ??
                    (url) async {
                      opened.add(url);
                    },
              ),
            ),
          ),
        ),
      ),
    );
    return opened;
  }

  Map<String, dynamic> row({bool muted = false, String? description}) => {
    'id': 'c1',
    'name': 'docs',
    'type': 'channel',
    'joined': true,
    'description': description ?? 'Read https://docs.example.com/guide first',
    'activityMuted': muted,
  };

  testWidgets('a description link opens through the launcher', (t) async {
    final opened = await mount(t, row());
    await t.tapOnText(
      find.textRange.ofSubstring('https://docs.example.com/guide'),
    );
    expect(opened, ['https://docs.example.com/guide']);
  });

  testWidgets('a link the system cannot open shows a toast', (t) async {
    await mount(t, row(), launch: (_) async => throw StateError('no handler'));
    await t.tapOnText(
      find.textRange.ofSubstring('https://docs.example.com/guide'),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Could not open this address.'), findsOneWidget);
  });

  testWidgets('the muted bell follows the channel row', (t) async {
    await mount(t, row());
    expect(
      find.byKey(const ValueKey('channel-activity-muted-badge')),
      findsNothing,
    );
    await mount(t, row(muted: true));
    await t.pump();
    expect(
      find.byKey(const ValueKey('channel-activity-muted-badge')),
      findsOneWidget,
    );
  });
}
