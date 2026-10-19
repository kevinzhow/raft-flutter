// Live request count against the local lab stack (docs/local-test-stack.md).
// Not part of the suite: run it by hand,
//
//   RAFT_LIVE_FIXTURE=/path/to/.local/test-user.json \
//   ../../tool/flutter test tool/rate_limit_live_test.dart --no-pub -r expanded
//
// It signs in with the fixture account (the file is read here and never
// printed), drives the real WorkspaceController through a scripted session and
// prints the metered requests by route template. Credentials, tokens, ids and
// signed URLs never reach the output.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

void main() {
  test('live session request counts', () async {
    final path = Platform.environment['RAFT_LIVE_FIXTURE'];
    if (path == null) {
      markTestSkipped('RAFT_LIVE_FIXTURE is not set');
      return;
    }
    final fixture = jsonDecode(File(path).readAsStringSync()) as Map;
    final meter = RequestMeter.instance
      ..reset()
      ..enable();
    final client = RaftClient(
      origin: fixture['origin'] as String,
      sessionStore: MemorySessionStore(),
    );
    await client.login(fixture['email'] as String, fixture['password'] as String);
    final w = WorkspaceController(client);
    final marks = <String, int>{};
    void mark(String name) => marks[name] = meter.requests.length;
    Future<void> settle([int ms = 1500]) =>
        Future<void>.delayed(Duration(milliseconds: ms));
    try {
      // Cold start.
      await w.bootstrap();
      client.connect();
      await settle(4000);
      mark('cold start');

      // Open five channels quickly.
      final targets = [...w.channels, ...w.dms].take(5).toList();
      for (final c in targets) {
        await w.selectChannel(c);
        await settle(400);
      }
      mark('open 5 channels');

      // What a timeline does for an image tile without a thumbnail: sign it
      // when it is visible (no speculative prefetch).
      final ids = <String>[
        for (final m in w.messageDomain.messages)
          for (final a in (m.json['attachments'] as List? ?? const []))
            if (a is Map && a['id'] is String) a['id'] as String,
      ];
      for (var round = 0; round < 3; round++) {
        for (final id in ids.take(60)) {
          unawaited(
            w
                .attachmentUrl(id, channelId: w.channel?.id, coalesce: true)
                .then((_) {}, onError: (Object _) {}),
          );
        }
        await settle(3000);
      }
      mark('attachments x3 (${ids.length} seen)');

      // Background, foreground, alt-tab, reconnect.
      w.setForeground(false);
      await settle(1000);
      for (var i = 0; i < 8; i++) {
        w.setForeground(true);
        w.resumeLiveSession();
        await settle(800);
        w.setForeground(false);
        await settle(500);
      }
      w.setForeground(true);
      client.suspendConnection();
      await settle(1000);
      for (var i = 0; i < 4; i++) {
        client.connect();
        await settle(1500);
        client.suspendConnection();
        await settle(500);
      }
      client.connect();
      await settle(4000);
      mark('background + alt-tab + reconnect');
    } finally {
      final out = StringBuffer('Live request report (no ids, no tokens)\n');
      var from = 0;
      for (final e in marks.entries) {
        final slice = meter.requests.sublist(from, e.value);
        from = e.value;
        final counts = <String, int>{};
        for (final r in slice) {
          counts.update(r.label, (n) => n + 1, ifAbsent: () => 1);
        }
        final top = counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        out.writeln('\n[${e.key}] ${slice.length} requests');
        for (final c in top.take(12)) {
          out.writeln('  ${c.value.toString().padLeft(4)}  ${c.key}');
        }
      }
      out.writeln('\nLimiter totals:');
      for (final l in ServerRateLimits.all) {
        if (meter.countFor(l.id) == 0) continue;
        out.writeln(
          '  ${l.id.padRight(16)} total=${meter.countFor(l.id)} peak=${meter.peakInWindow(l.id)} of ${l.max}/${l.window.inSeconds}s',
        );
      }
      final dup = meter.duplicates(within: const Duration(seconds: 5));
      out.writeln(
        'Identical requests repeated within 5 s: ${dup.values.fold<int>(0, (a, b) => a + b)}',
      );
      for (final d in (dup.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(10)) {
        out.writeln('  ${d.value.toString().padLeft(4)}  ${d.key.replaceAll(RegExp(r'[0-9a-fA-F-]{20,}'), ':id')}');
      }
      out.writeln('Total: ${meter.requests.length}; 429s: ${meter.rateLimited}');
      final report = Platform.environment['RATE_LIMIT_REPORT'];
      if (report != null) File(report).writeAsStringSync(out.toString());
      // ignore: avoid_print
      print(out);
      w.dispose();
      await client.logout().catchError((Object _) {});
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
