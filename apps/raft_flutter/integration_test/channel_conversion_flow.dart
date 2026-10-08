import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_ui/raft_ui.dart';

Future<void> _until(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (condition()) return;
  }
  throw TestFailure('Timed out waiting for native conversion state.');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _until(tester, () => finder.evaluate().isNotEmpty);
  await tester.ensureVisible(finder.last);
  await tester.pump();
  await tester.tap(finder.last);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Uses the live scoped flag; never enables rollout or changes existing resources.
/// A default-off fixture proves hidden controls. Enabled fixtures exercise a
/// real ordinary→joint job on an owned channel and delete its owned workspace.
Future<void> verifyChannelConversionFlow(
  WidgetTester tester,
  WorkspaceController w, {
  required Future<void> Function(String) capture,
}) async {
  final original = w.server!;
  String? owned;
  try {
    final marker = DateTime.now().microsecondsSinceEpoch;
    final server = await w.client.post(
      '/servers',
      data: {'name': 'Native conversion', 'slug': 'native-conversion-$marker'},
    );
    owned = server['id'];
    await w.recoverMembership();
    await w.selectServer(w.servers.singleWhere((s) => s.id == owned));
    final created = await w.client.post(
      '/channels',
      data: {
        'name': 'convert_$marker',
        'visibility': 'private',
        'agentIds': [],
        'userIds': [],
      },
    );
    await w.refreshChannels();
    await w.selectChannel(RaftChannel(created));
    await tester.pumpAndSettle();
    final flags = await w.client.post(
      '/feature-flags/evaluate',
      data: {
        'keys': [channelConversionFlag],
        'serverId': owned,
        'platform': 'web',
      },
    );
    final evaluations = flags['evaluations'] as List;
    expect(
      evaluations.any(
        (f) => f['key'] == channelConversionFlag && f['enabled'] is bool,
      ),
      true,
    );
    final enabled = evaluations.any(
      (f) => f['key'] == channelConversionFlag && f['enabled'] == true,
    );
    await _tap(tester, find.byTooltip('Channel settings'));
    await _until(
      tester,
      () =>
          find.byType(ChannelSettings).evaluate().isNotEmpty &&
          find.text('Pin conversation').evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(milliseconds: 300));
    if (!enabled) {
      expect(find.text('Convert to joint channel'), findsNothing);
      await capture('channel-conversion-disabled');
    } else {
      await _tap(tester, find.text('Convert to joint channel'));
      await _tap(
        tester,
        find.widgetWithText(RaftButton, 'Convert to joint channel'),
      );
      await _until(
        tester,
        () => find.text('Conversion complete').evaluate().isNotEmpty,
      );
      final actual = await w.client.get('/channels/${created['id']}');
      expect(actual['type'], 'joint');
      expect(actual['conversionState']['status'], 'done');
      await capture('channel-conversion-complete');
    }
  } finally {
    final settings = find.byType(ChannelSettings);
    if (settings.evaluate().isNotEmpty) {
      final context = tester.element(settings.first),
          route = ModalRoute.of(tester.element(settings.first));
      if (route != null && route.isActive) {
        Navigator.of(context).removeRoute(route);
      }
    }
    if (owned != null) {
      w.client.selectServer(owned);
      await w.client.exitServer(owned, delete: true);
      w.revokeServer(owned);
    }
    await w.recoverMembership();
    final prior = w.servers.where((s) => s.id == original.id).firstOrNull;
    if (prior != null) await w.selectServer(prior);
    await tester.pumpAndSettle();
  }
}
