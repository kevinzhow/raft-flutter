import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/channel_announcement_store.dart';
import 'package:raft_flutter/features/channel_announcement_strip.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets(
    'copy link writes the Artifact address without waiting for a request',
    (t) async {
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
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: ChannelAnnouncementStrip(
              announcement: const ChannelAnnouncement(
                artifactId: 'pt_123',
                title: 'Announcement',
                version: 1,
                updatedAt: '2026-11-01T00:00:00Z',
                updatedBy: {'type': 'user', 'id': 'u1', 'name': 'Ana'},
                seen: false,
              ),
              webOrigin: Uri.parse('https://example.invalid'),
              onOpen: () {},
            ),
          ),
        ),
      );
      await t.tap(find.byKey(const Key('channel-announcement-strip-options')));
      await t.pumpAndSettle();
      await t.tap(find.text('Copy link'));
      await t.pumpAndSettle();
      expect(copied, 'https://example.invalid/artifacts/pt_123');
    },
  );
}
