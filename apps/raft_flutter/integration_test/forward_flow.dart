import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/forward_messages_dialog.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

Future<void> verifyForwardFlow(
  WidgetTester tester,
  WorkspaceController w, {
  required Future<void> Function(String) capture,
}) async {
  final original = w.channel;
  final owned = <RaftChannel>[];
  final marker = DateTime.now().millisecondsSinceEpoch.toString();
  Future<void> wait(bool Function() condition) async {
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (condition()) return;
    }
    throw TestFailure('Native forward flow did not reach the required state.');
  }

  try {
    for (final suffix in ['source', 'a', 'b']) {
      final channel = RaftChannel(
        Map<String, dynamic>.from(
          await w.command(
            'POST',
            '/channels',
            data: {'name': 'nf-$marker-$suffix', 'visibility': 'public'},
          ),
        ),
      );
      owned.add(channel);
    }
    await w.refreshChannels();
    await w.selectChannel(owned.first);
    expect(await w.send('Native forwarded text 中文 日本語 $marker'), true);
    final source = w.messages.singleWhere((m) => m.content.contains(marker));
    expect(source.string('messageType'), 'chat');
    await tester.pump(const Duration(milliseconds: 500));
    var done = false, accepted = false;
    unawaited(
      forwardMessages(tester.element(find.byType(WorkspaceView)), w, [
        source,
      ]).then((value) {
        accepted = value;
        done = true;
      }),
    );
    await wait(() => find.byType(ForwardMessagesDialog).evaluate().isNotEmpty);
    await tester.enterText(
      find.widgetWithText(TextField, 'Search channels or people'),
      'nf-$marker',
    );
    await wait(() => find.byType(CheckboxListTile).evaluate().isNotEmpty);
    final list = find.descendant(
      of: find.byType(ForwardMessagesDialog),
      matching: find.byType(ListView),
    );
    final scroll = find
        .descendant(of: list, matching: find.byType(Scrollable))
        .first;
    for (final channel in owned.skip(1)) {
      final target = find.widgetWithText(CheckboxListTile, '#${channel.name}');
      await tester.scrollUntilVisible(target, 100, scrollable: scroll);
      await tester.ensureVisible(target);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 200));
    }
    await capture('linux-forward-destinations');
    await tester.tap(find.widgetWithText(RaftButton, 'Forward'));
    await wait(() => done);
    expect(accepted, true);
    for (final channel in owned.skip(1)) {
      final page = await w.client.messagePage(channel.id);
      final forwarded = (page['messages'] as List)
          .cast<Map>()
          .where(
            (m) =>
                m['actionMetadata'] is Map &&
                m['actionMetadata']['kind'] == 'forwarded-bundle',
          )
          .toList();
      expect(
        forwarded.length,
        1,
        reason:
            'Each selected destination gets exactly one server-created bundle.',
      );
      expect(
        (forwarded.single['actionMetadata']['forwardedItems'] as List)
            .single['contentSnapshot'],
        source.content,
      );
    }
    await w.selectChannel(owned[1]);
    await wait(
      () => w.messages.any(
        (m) =>
            m.json['actionMetadata'] is Map &&
            m.json['actionMetadata']['kind'] == 'forwarded-bundle',
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await capture('linux-forwarded-message');
  } finally {
    if (original != null) await w.selectChannel(original);
    for (final channel in owned.reversed) {
      await w.command('DELETE', '/channels/${channel.id}');
    }
    await w.refreshChannels();
    await tester.pump(const Duration(milliseconds: 500));
  }
}
