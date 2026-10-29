// Request budget of a realistic session, measured on the whole app against a
// fake server, on a fake clock: cold start, five channels opened quickly, a
// channel full of attachments scrolled back and forth, Activity and Search,
// the mouse sweeping a list of messages, backgrounding and alt-tab, a network
// drop with a flapping socket, and a logout whose retries fail.
//
// The assertion is the guard: no server rate limit may see more than half of
// its allowance in any window (the rest is headroom for the user's other
// clients, which count against the same per-user bucket), nothing may be
// answered with a 429, and an identical question must not be asked twice in a
// short window.
@Tags(['slow'])
library;

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/source_activity_unread_store.dart';
import 'package:raft_flutter/data/source_server_unread.dart';
import 'package:raft_flutter/features/attachment_view.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/inline_attachment_media.dart';
import 'package:raft_flutter/platform/attachment_http.dart';
import 'package:raft_flutter/features/workspace_view.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'support/scroll_session.dart';

/// A budget a limiter must stay under: [share] of its allowance per window.
const share = 0.5;

void main() {
  testWidgets(
    'a realistic five-minute session stays under half of every server limit',
    (t) async {
      DateTime now() => t.binding.clock.now();
      final meter = RequestMeter.instance
        ..reset()
        ..enable(clock: now);
      // The freshness guards of the return-to-foreground reads follow the
      // test's clock, as the 5 s guard would in a real session.
      SourceActivityUnreadStore.clock = now;
      SourceServerUnreadStore.clock = now;
      addTearDown(() {
        SourceActivityUnreadStore.clock = DateTime.now;
        SourceServerUnreadStore.clock = DateTime.now;
        meter
          ..disable()
          ..reset()
          ..clock = DateTime.now;
      });

      // The app builds its own URL cache on the real clock; sign against that.
      final server = FakeServer(now, signClock: DateTime.now);
      final rows = attachmentHistory(server, count: 160, channel: 'ca');
      final png = (await t.runAsync(tinyPng))!;
      final storage = FakeStorage(png, server);
      AttachmentHttp.debugReplace(
        Dio()
          ..httpClientAdapter = storage
          ..interceptors.add(meter.interceptor()),
      );
      final mediaDir = Directory.systemTemp.createTempSync('rate-session');
      final media = FakeMediaFiles(mediaDir);
      InlineMediaTestHooks.playerFactory = media.player;
      addTearDown(() {
        InlineMediaTestHooks.playerFactory = null;
        AttachmentHttp.debugReplace(null);
        if (mediaDir.existsSync()) mediaDir.deleteSync(recursive: true);
      });

      final f = RootFixture();
      var down = false;
      final channels = [
        for (var i = 0; i < 6; i++)
          {
            'id': i == 0 ? 'ca' : 'cx$i',
            'name': i == 0 ? 'general-a' : 'room-$i',
            'type': 'channel',
            'serverId': 'a',
            'joined': true,
            'latestSeq': '160',
          },
      ];
      f.overrides['GET /channels'] = (_) => channels;
      // Every attachment id a signed URL was requested for, in order.
      final signedIds = <String>[];
      f.overrides['POST /attachments/urls'] = (o) {
        final ids = ((o.data as Map)['attachmentIds'] as List).cast<String>();
        signedIds.addAll(ids);
        return {
          'urls': [
            for (final id in ids)
              {
                'id': id,
                'url': server.signed('https://storage.invalid/o/$id'),
                'expiresAt': null,
              },
          ],
        };
      };
      // The document cards' summary line (`report-N.pdf`): the server's
      // answer for a PDF it can preview.
      for (final row in rows) {
        for (final a in (row['attachments'] as List? ?? const [])) {
          final id = (a as Map)['id'] as String;
          if (!id.startsWith('doc-')) continue;
          f.overrides['GET /attachments/$id/preview'] = (_) => {
            'status': 'ok',
            'data': {'kind': 'pdf'},
            'truncated': false,
          };
        }
      }
      for (final c in channels) {
        final id = c['id'] as String;
        f.overrides['GET /messages/channel/$id'] = (_) => {
          'messages': id == 'ca'
              ? rows
              : [
                  for (var i = 0; i < 20; i++)
                    {
                      'id': '$id-$i',
                      'channelId': id,
                      'seq': '${i + 1}',
                      'senderId': 'alice',
                      'content': 'm$i',
                      'createdAt': '2026-10-10T00:00:00Z',
                    },
                ],
          'hasMore': false,
        };
        f.overrides['POST /channels/$id/read'] = (_) => {};
        f.overrides['GET /channels/$id/members'] = (_) => [];
      }
      f.overrides['GET /channels/inbox'] = (_) => {
        'items': [],
        'hasMore': false,
        'totalUnreadCount': 0,
      };
      f.overrides['GET /messages/search'] = (_) => {'messages': [], 'total': 0};
      for (final row in rows) {
        for (final a in (row['attachments'] as List).cast<Map>()) {
          f.overrides['GET /attachments/${a['id']}/url'] = (_) {
            signedIds.add('${a['id']}');
            return {
              'url': server.signed('https://storage.invalid/o/${a['id']}'),
              'expiresAt': DateTime.now()
                  .add(const Duration(seconds: 300))
                  .toIso8601String(),
            };
          };
        }
      }
      await f.mount(t, 'light', 1280, settle: false);
      void install() {
        for (final key in f.adapter.routes.keys.toList()) {
          final route = f.adapter.routes[key]!;
          f.adapter.routes[key] = (o) {
            if (down) throw const SocketException('network is unreachable');
            return route(o);
          };
        }
      }

      install();
      Future<void> pumpFor(Duration d, {int stepMs = 100}) async {
        for (
          var e = Duration.zero;
          e < d;
          e += Duration(milliseconds: stepMs)
        ) {
          await t.runAsync(() => Future<void>.delayed(Duration.zero));
          await t.pump(Duration(milliseconds: stepMs));
        }
      }

      // The platform walks the lifecycle one step at a time.
      void lifecycle(AppLifecycleState to) {
        const down = [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ];
        final b = t.binding;
        if (to == AppLifecycleState.resumed) {
          for (final s in down.reversed.skip(1)) {
            b.handleAppLifecycleStateChanged(s);
          }
          b.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        } else {
          for (final s in down) {
            b.handleAppLifecycleStateChanged(s);
            if (s == to) break;
          }
        }
      }

      final marks = <String, int>{};
      void mark(String name) {
        marks[name] = meter.requests.length;
        // ignore: avoid_print
        print('STEP $name (${meter.requests.length} requests so far)');
      }

      // 1. Cold start.
      // ignore: avoid_print
      print('STEP mounted');
      await pumpFor(const Duration(seconds: 2));
      await t.tap(find.byKey(const ValueKey('global-server-a')));
      await pumpFor(const Duration(seconds: 5));
      expect(find.byType(WorkspaceView), findsOneWidget);
      final w = f.workspace(t);
      mark('cold start');

      // 2. Open five channels quickly.
      for (final c in channels.take(5)) {
        final channel = w.channels.firstWhere((x) => x.id == c['id']);
        unawaited(w.selectChannel(channel));
        await pumpFor(const Duration(seconds: 1));
      }
      mark('open 5 channels');

      // 3. Scroll a channel with many attachments, back and forth, 60 s.
      unawaited(w.selectChannel(w.channels.firstWhere((x) => x.id == 'ca')));
      await pumpFor(const Duration(seconds: 3));
      final state = t.state(find.byType(RaftChatView).first) as dynamic;
      Future<void> sweep(double px, int seconds) async {
        final ScrollController v = state.viewport;
        final frames = seconds * 20;
        for (var i = 0; i < frames; i++) {
          v.jumpTo(
            (v.offset + px / frames).clamp(
              v.position.minScrollExtent,
              v.position.maxScrollExtent,
            ),
          );
          await t.pump(const Duration(milliseconds: 50));
        }
      }

      for (var i = 0; i < 6; i++) {
        await sweep(-8000, 5);
        await sweep(8000, 5);
      }
      mark('scroll attachments 60 s');

      // 4. Activity and Search.
      w.setSection('activity');
      await pumpFor(const Duration(seconds: 6));
      w.setSection('search');
      await pumpFor(const Duration(seconds: 6));
      w.setSection('chat');
      await pumpFor(const Duration(seconds: 3));
      mark('activity + search');

      // 5. The mouse sweeps a list of messages.
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 10));
      addTearDown(mouse.removePointer);
      for (var round = 0; round < 3; round++) {
        for (final e in find.byType(AttachmentView).evaluate().take(30)) {
          final box = e.renderObject;
          if (box is! RenderBox || !box.attached) continue;
          await mouse.moveTo(box.localToGlobal(box.size.center(Offset.zero)));
          await t.pump(const Duration(milliseconds: 150));
        }
      }
      mark('hover sweep');
      final hoverSlice = meter.requests.sublist(
        marks['activity + search']!,
        marks['hover sweep'],
      );
      expect(
        hoverSlice.where((r) => r.label.contains('/attachments/')),
        isEmpty,
        reason: 'hovering messages must not sign or fetch attachments',
      );

      // 6. Background, foreground, alt-tab.
      lifecycle(AppLifecycleState.paused);
      await pumpFor(const Duration(seconds: 45));
      lifecycle(AppLifecycleState.resumed);
      await pumpFor(const Duration(seconds: 3));
      for (var i = 0; i < 10; i++) {
        lifecycle(AppLifecycleState.inactive);
        await pumpFor(const Duration(seconds: 1));
        lifecycle(AppLifecycleState.resumed);
        await pumpFor(const Duration(seconds: 1));
      }
      mark('background + alt-tab');
      // Returning to the foreground reads the Activity window and the
      // cross-server summary at once, but never twice inside the 5 s guard
      // (10 alt-tabs 2 s apart made 10 of each without it).
      final resumed = meter.requests.sublist(
        marks['hover sweep']!,
        marks['background + alt-tab'],
      );
      for (final route in ['/servers/unread-summary', '/channels/inbox']) {
        final at = [
          for (final r in resumed)
            if (r.route == route) r.at,
        ];
        if (route == '/servers/unread-summary') {
          expect(at, isNotEmpty, reason: 'the return reads the summary');
          expect(at.length, lessThanOrEqualTo(6), reason: '$route: $at');
        }
      }
      final summaryAt = [
        for (final r in resumed)
          if (r.route == '/servers/unread-summary') r.at,
      ];
      for (var i = 1; i < summaryAt.length; i++) {
        expect(
          summaryAt[i].difference(summaryAt[i - 1]),
          greaterThanOrEqualTo(const Duration(seconds: 5)),
          reason: 'summary reads inside the freshness guard',
        );
      }

      // 7. Network drop and reconnect; the socket flaps while it is back.
      down = true;
      f.client.event('disconnected', null);
      await pumpFor(const Duration(seconds: 40));
      down = false;
      for (var i = 0; i < 6; i++) {
        f.client.event('connected', null);
        f.client.event('rooms:joined', null);
        await pumpFor(const Duration(seconds: 2));
        f.client.event('disconnected', null);
        await pumpFor(const Duration(seconds: 3));
      }
      f.client.event('connected', null);
      f.client.event('rooms:joined', null);
      await pumpFor(const Duration(seconds: 10));
      mark('network drop + reconnect');

      // The retries below ask the same question again on purpose; the
      // duplicate budget covers everything before them.
      final dupsBeforeLive = meter.duplicates(
        within: const Duration(seconds: 5),
      );

      // 8. Live messages while the server's inbox lags them by a second:
      // three conversations, ten messages, one a second. The window must
      // converge on every conversation's last message, and the reads this
      // costs stay a few per message (retries share reads and are budgeted).
      final sentAt = <String, (String, DateTime)>{};
      final lagStart = meter.requests.length;
      f.adapter.routes['GET /channels/inbox'] = (o) {
        final cutoff = now().subtract(const Duration(seconds: 1));
        return {
          'items': [
            for (final e in sentAt.entries)
              if (e.value.$2.isBefore(cutoff))
                {
                  'kind': 'channel',
                  'channelId': e.key,
                  'lastMessageId': e.value.$1,
                  'latestActivitySeq': e.value.$1.split('-').last,
                  'unreadCount': 1,
                },
          ],
          'hasMore': false,
          'totalUnreadCount': 3,
        };
      };
      w.setSection('activity');
      await pumpFor(const Duration(seconds: 2));
      for (var i = 0; i < 10; i++) {
        final channel = ['ca', 'cx1', 'cx2'][i % 3];
        final id = 'live-$channel-${200 + i}';
        sentAt[channel] = (id, now());
        f.client.event('message:new', {
          'id': id,
          'channelId': channel,
          'seq': 200 + i,
          'senderId': 'bob',
          'senderType': 'user',
          'content': 'live $i',
          'createdAt': '2026-10-10T00:00:00Z',
        });
        await pumpFor(const Duration(seconds: 1));
      }
      await pumpFor(const Duration(seconds: 6));
      final lagReads = meter.requests
          .sublist(lagStart)
          .where((r) => r.route == '/channels/inbox')
          .length;
      // ignore: avoid_print
      print('STEP live messages: $lagReads inbox reads for 10 messages');
      final listed = {
        for (final row in w.activityUnreadIfBound!.acceptedRows)
          row['channelId']: row['lastMessageId'],
      };
      for (final entry in sentAt.entries) {
        expect(
          listed[entry.key],
          entry.value.$1,
          reason: 'Activity converged on the last message of ${entry.key}',
        );
      }
      expect(
        lagReads,
        lessThanOrEqualTo(10 * 2 + 6),
        reason: 'reads: $lagReads',
      );
      w.setSection('chat');
      await pumpFor(const Duration(seconds: 1));
      mark('live messages, lagging inbox');

      // 9. Logout while the server cannot be reached.
      down = true;
      unawaited(f.client.logout().catchError((Object _) {}));
      await pumpFor(const Duration(seconds: 120));
      mark('logout');

      // ---- Report -------------------------------------------------------
      final out = StringBuffer('Session request report (fake clock)\n');
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
        for (final c in top.take(8)) {
          out.writeln('  ${c.value.toString().padLeft(4)}  ${c.key}');
        }
      }
      out.writeln(
        '\nLimiter peaks (any sliding window of the limiter\'s own length):',
      );
      for (final l in ServerRateLimits.all) {
        final peak = meter.peakInWindow(l.id);
        if (meter.countFor(l.id) == 0) continue;
        out.writeln(
          '  ${l.id.padRight(16)} total=${meter.countFor(l.id).toString().padLeft(4)} '
          'peak=${peak.toString().padLeft(4)} of ${l.max} per ${l.window.inSeconds}s',
        );
      }
      final dups = dupsBeforeLive;
      final extra = dups.values.fold<int>(0, (a, b) => a + b);
      out.writeln(
        '\nIdentical requests repeated within 5 s, live-message retries '
        'included: ${meter.duplicates(within: const Duration(seconds: 5)).values.fold<int>(0, (a, b) => a + b)}',
      );
      out.writeln('\nIdentical requests repeated within 5 s: $extra');
      for (final d
          in (dups.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
              .take(8)) {
        out.writeln('  ${d.value.toString().padLeft(4)}  ${d.key}');
      }
      out.writeln(
        'Total requests: ${meter.requests.length}; 429s: ${meter.rateLimited}',
      );
      final report = Platform.environment['RATE_LIMIT_REPORT'];
      if (report != null) File(report).writeAsStringSync(out.toString());
      // ignore: avoid_print
      print(out);

      for (final l in ServerRateLimits.all) {
        expect(
          meter.peakInWindow(l.id),
          lessThanOrEqualTo((l.max * share).floor()),
          reason: '${l.id} must keep half of its ${l.max} per ${l.window} free',
        );
      }
      expect(meter.rateLimited, 0);
      expect(extra, lessThanOrEqualTo(40), reason: 'duplicate requests: $dups');
      // No speculative signing: images with a thumbnail (`img-*`) load it
      // directly and are never signed by scrolling, hovering or pressing.
      expect(signedIds, isNotEmpty, reason: 'images without a thumbnail sign');
      expect(
        signedIds.where((id) => id.startsWith('img-')),
        isEmpty,
        reason: 'thumbnailed images are never signed ahead of an open',
      );

      w.attachmentMedia.playerSessions.clear();
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
