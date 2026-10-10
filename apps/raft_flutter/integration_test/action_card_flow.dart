import 'native_control.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_ui/raft_ui.dart';

/// Seeds an isolated card through the mounted agent API, then confirms it
/// through the real human UI. The issued credential remains in memory only.
Future<void> verifyPreparedActionCard(
  WidgetTester tester,
  WorkspaceController w,
  Future<void> Function(String) capture,
) async {
  final previousServer = w.server!, previous = w.channel;
  final marker = DateTime.now().microsecondsSinceEpoch;
  final carrierName = 'card-$marker', draftName = 'draft-$marker';
  final confirmedName = 'confirmed-$marker';
  String? ownedServerId, agentId, carrierId;
  Dio? agentApi;
  Future<dynamic> safeRequest(
    String method,
    String path, {
    dynamic data,
  }) async {
    try {
      return await w.client.request(method, path, data: data);
    } on RaftApiException catch (e) {
      // Credential-shaped response fields and request headers never appear in
      // test failures, screenshots, or transport logs.
      throw TestFailure(
        'Prepared-card fixture request failed: $method $path '
        '(HTTP ${e.status ?? 'unknown'}).',
      );
    }
  }

  try {
    final workspace = await safeRequest(
      'POST',
      '/servers',
      data: {
        'name': 'Native prepared action card',
        'slug': 'native-card-$marker',
      },
    );
    ownedServerId = workspace['id'] as String;
    await w.recoverMembership();
    await w.selectServer(w.servers.singleWhere((s) => s.id == ownedServerId));
    final carrier = await safeRequest(
      'POST',
      '/channels',
      data: {'name': carrierName, 'type': 'channel', 'visibility': 'public'},
    );
    carrierId = carrier['id'] as String;
    final agent = await safeRequest(
      'POST',
      '/agents',
      data: {
        'name': 'card-agent-$marker',
        'external': true,
        'description': 'Isolated native action-card verification',
      },
    );
    agentId = agent['id'] as String;
    await safeRequest(
      'PUT',
      '/agents/$agentId/scopes',
      data: {
        'scopes': ['action:prepare', 'message:send', 'channel:read'],
      },
    );
    await safeRequest(
      'POST',
      '/channels/$carrierId/members/batch',
      data: {
        'userIds': <String>[],
        'agentIds': [agentId],
      },
    );
    final credential = await safeRequest(
      'POST',
      '/agents/$agentId/credentials',
      data: {
        'name': 'Native action-card verification',
        'scopes': ['tasks', 'channels', 'read'],
      },
    );
    final key = credential['apiKey'];
    if (key is! String || key.isEmpty) {
      throw TestFailure(
        'Agent credential issuance returned no usable credential.',
      );
    }
    agentApi = Dio(
      BaseOptions(
        baseUrl: w.client.origin,
        headers: {'Authorization': 'Bearer $key'},
        contentType: Headers.jsonContentType,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    // Drop the one-time response as soon as its value is bound to transport.
    credential.remove('apiKey');
    dynamic prepared;
    try {
      prepared = (await agentApi.post(
        '/internal/agent-api/prepare-action',
        data: {
          'target': '#$carrierName',
          'idempotencyKey': 'native-card-$marker',
          'action': {
            'type': 'channel:create',
            'name': draftName,
            'description': 'Prepared description',
            'visibility': 'public',
          },
        },
      )).data;
    } on DioException catch (e) {
      throw TestFailure(
        'Mounted action preparation failed '
        '(HTTP ${e.response?.statusCode ?? 'unknown'}).',
      );
    }
    final messageId = prepared['messageId'] as String;
    expect(prepared['metadata']['state'], 'prepared');
    final setup = await safeRequest(
      'GET',
      '/servers/$ownedServerId/setup-projection',
    );
    // Source createAgent stamps durable completion in the same transaction,
    // including external agents. The owner's handoff remains a real UI step.
    expect(setup['blocksChat'], false);
    expect(
      setup['postSetup']['surveyPending'],
      false,
      reason: 'This fixture account must already have its real survey answers.',
    );
    await w.refreshChannels();
    await w.selectChannel(w.channels.singleWhere((c) => c.id == carrierId));
    w.setSection('chat');
    await w.jumpToMessage(carrierId, messageId);
    if (setup['postSetup']['handoffPending'] == true) {
      final handoff = find.text("Let's Go");
      for (var i = 0; i < 200 && handoff.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(handoff, findsOneWidget);
      await tester.ensureVisible(handoff);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(handoff);
      for (var i = 0; i < 150 && handoff.evaluate().isNotEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final acknowledged = await safeRequest(
        'GET',
        '/servers/$ownedServerId/setup-projection',
      );
      expect(acknowledged['postSetup']['handoffPending'], false);
      expect(acknowledged['blocksChat'], false);
    }
    final tile = find.byKey(ValueKey('message-$messageId'));
    final card = find.descendant(
      of: tile,
      matching: find.byType(RaftActionCard),
    );
    for (var i = 0; i < 100 && card.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(card, findsOneWidget);
    final confirm = find.descendant(
      of: card,
      matching: find.widgetWithText(RaftButton, 'Create channel'),
    );
    await revealNativeControl(tester, confirm);
    await capture('linux-prepared-action-card');
    // Capturing pumps a real frame too; re-observe before the first press.
    final ready = await revealNativeControl(tester, confirm);
    expect(ready, findsOneWidget);
    await tester.tap(ready);
    for (
      var i = 0;
      i < 100 && find.byType(RaftFormDialog).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(RaftFormDialog), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('field-name')))
          .controller!
          .text,
      draftName,
    );
    await tester.enterText(
      find.byKey(const ValueKey('field-name')),
      confirmedName,
    );
    await tester.enterText(
      find.byKey(const ValueKey('field-description')),
      'Human-reviewed description',
    );
    await capture('linux-action-card-authoritative-preview');
    final submit = find.descendant(
      of: find.byType(RaftFormDialog),
      matching: find.text('Create'),
    );
    await tester.ensureVisible(submit);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(submit);
    for (
      var i = 0;
      i < 150 && find.byType(RaftFormDialog).evaluate().isNotEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(RaftFormDialog), findsNothing);
    final context = await w.query(
      '/messages/context/$messageId',
      query: {'channelId': carrierId},
    );
    final receipt = (context['messages'] as List).whereType<Map>().singleWhere(
      (m) => m['id'] == messageId,
    );
    final metadata = receipt['actionMetadata'] as Map;
    expect(metadata['state'], 'executed');
    expect(metadata['result']['kind'], 'channel');
    final createdId = metadata['result']['id'] as String;
    final created = await w.client.get('/channels/$createdId');
    expect(created['name'], confirmedName);
    expect(created['description'], 'Human-reviewed description');
    final rendered = tester.widget<RaftActionCard>(card);
    expect(rendered.state, 'executed');
    expect(rendered.completedBy, isNotEmpty);
    await capture('linux-action-card-completed');
  } finally {
    agentApi?.options.headers.clear();
    agentApi?.close(force: true);
    // Restore the UI first; cleanup has its own exact workspace header and
    // never selects a different server underneath the restored controller.
    try {
      await w.recoverMembership();
      final original = w.servers
          .where((s) => s.id == previousServer.id)
          .firstOrNull;
      if (original != null) {
        await w.selectServer(original);
        if (previous != null) {
          final prior = w.channels
              .where((c) => c.id == previous.id)
              .firstOrNull;
          if (prior != null) await w.selectChannel(prior);
        }
      }
    } finally {
      if (ownedServerId != null) {
        final session = await w.client.sessionStore.read(w.client.origin);
        if (session == null) {
          throw TestFailure(
            'Owned action-card workspace cleanup has no session.',
          );
        }
        try {
          await w.client.request(
            'DELETE',
            '/servers/$ownedServerId',
            authorized: false,
            headers: {
              'Authorization': 'Bearer ${session.accessToken}',
              'X-Server-Id': ownedServerId,
            },
          );
        } on RaftApiException catch (e) {
          throw TestFailure(
            'Owned action-card workspace cleanup failed (HTTP ${e.status ?? 'unknown'}).',
          );
        }
        w.revokeServer(ownedServerId);
        await w.recoverMembership();
        expect(w.servers.any((s) => s.id == ownedServerId), false);
      }
    }
    await tester.pump(const Duration(milliseconds: 300));
  }
}
