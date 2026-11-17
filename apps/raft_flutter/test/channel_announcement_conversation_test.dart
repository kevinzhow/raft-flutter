import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/conversation_panel.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  testWidgets('the channel announcement appears above the conversation', (
    t,
  ) async {
    final (w, api) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    w.client.http.transformer = SyncTransformer();
    w.channel = RaftChannel({
      'id': 'c1',
      'type': 'channel',
      'name': 'work',
      'joined': true,
    });
    w.channels = [w.channel!];
    final files = w.services.channelFilesStore('c1');
    api.routes['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [
        {'key': 'channel_announcement_v0', 'enabled': true},
      ],
    };
    api.routes['GET /channels/c1/announcement'] = (_) => {
      'announcement': {
        'artifactId': 'pt_123',
        'title': 'Read this',
        'version': 1,
        'updatedAt': '2026-11-01T00:00:00Z',
        'updatedBy': {'type': 'user', 'id': 'u1', 'name': 'Ana'},
        'seen': false,
      },
    };
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(body: ConversationPanel(controller: w)),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const Key('channel-announcement-strip')), findsOneWidget);
    expect(find.text('Read this'), findsOneWidget);
    expect(
      api.calls.where((c) => c.path == '/channels/c1/announcement'),
      hasLength(1),
    );
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await t.tap(find.byKey(const Key('channel-announcement-strip-options')));
    await t.pumpAndSettle();
    final callsBeforeCopy = api.calls.length;
    await t.tap(find.text('Copy link'));
    await t.pumpAndSettle();
    expect(copied, 'https://example.invalid/artifacts/pt_123');
    expect(api.calls.length, callsBeforeCopy);
    await t.pumpWidget(const SizedBox.shrink());
    files.dispose();
  });
}
