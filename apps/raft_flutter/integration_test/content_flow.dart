import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/main.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';
import 'package:raft_flutter/platform/content_target.dart';

/// Real main wiring + mounted membership/channel/context reads. OS link and
/// notification activation are proven separately by the isolated native probe.
Future<void> verifyContentNavigation(
  WidgetTester tester,
  WorkspaceController w,
  Future<void> Function(String) capture,
) async {
  final selected = w.channel;
  if (selected == null || w.messages.isEmpty) {
    throw StateError('A real channel and message are required for link proof.');
  }
  final message = w.messages.last;
  final dynamic appState = tester.state(find.byType(RaftApp));
  final NativeContentCoordinator content = appState.content;
  final target = ContentTarget.parse(
    Uri.parse(
      'raft://v1/servers/${w.client.serverId}/${selected.type == 'dm' ? 'dms' : 'channels'}/${selected.id}/messages/${message.id}',
    ),
    origin: Uri.parse(w.client.origin),
  )!;
  await content.navigate(target);
  await tester.pump(const Duration(milliseconds: 300));
  expect(w.channel?.id, selected.id);
  expect(w.highlightedMessageId, message.id);
  expect(w.messages.any((m) => m.id == message.id), true);
  final scope = w.client.serverId, principal = w.client.user!.id;
  content.receiveLink(
    Uri.parse(
      'https://untrusted.example/s/${w.server?.string('slug')}/channel/${selected.id}?msg=${message.id}',
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  expect(w.client.serverId, scope);
  expect(w.client.user!.id, principal);
  expect(w.highlightedMessageId, message.id);
  await capture('linux-content-message-navigation');
}
