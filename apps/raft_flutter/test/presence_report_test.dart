// `presence:activity` (Web v1.24 notifications/presenceReport.ts,
// docs/contracts/notifications.md §1.3, §5): what this device tells the
// server so a phone stays quiet while its person is at a computer.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/platform/presence_report.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.example',
        sessionStore: MemorySessionStore(),
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  bool live = true;
  final sent = <Map<String, Object?>>[];
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  bool get connected => live;
  @override
  bool emitSocketEvent(String event, [Object? payload]) {
    if (!live) return false;
    expect(event, 'presence:activity');
    sent.add(Map<String, Object?>.from(payload as Map));
    return true;
  }

  void reconnect() {
    live = true;
    stream.add(const RaftEvent('connected', null));
  }

  void drop() {
    live = false;
    stream.add(const RaftEvent('disconnected', null));
  }
}

class _Timers implements PresenceTimers {
  final pending = <({Duration at, void Function() run, Object handle})>[];
  Duration now = Duration.zero;
  @override
  Object start(Duration after, void Function() callback) {
    final handle = Object();
    pending.add((at: now + after, run: callback, handle: handle));
    return handle;
  }

  @override
  void cancel(Object handle) =>
      pending.removeWhere((timer) => identical(timer.handle, handle));

  void advance(Duration by) {
    final end = now + by;
    while (true) {
      final due = pending.where((t) => t.at <= end).toList()
        ..sort((a, b) => a.at.compareTo(b.at));
      if (due.isEmpty) break;
      pending.remove(due.first);
      now = due.first.at;
      due.first.run();
    }
    now = end;
  }
}

void main() {
  late _Client client;
  late _Timers timers;
  final start = DateTime.utc(2026, 11, 14, 10);
  DateTime clock() => start.add(timers.now);

  setUp(() {
    client = _Client();
    timers = _Timers();
  });
  tearDown(() => client.stream.close());

  group('desktop', () {
    late PresenceReporter reporter;
    setUp(() {
      reporter = PresenceReporter(mobile: false, timers: timers, now: clock)
        ..setAckAlerts(true)
        ..bind(client);
    });
    tearDown(() => reporter.dispose());

    test(
      'coming to the front is input: active at once, with the ack capability',
      () {
        reporter.setAttended(true);
        expect(client.sent.last, {
          'active': true,
          'idleSeconds': 0,
          'locked': false,
          'attended': true,
          'ackAlerts': true,
        });
      },
    );

    test('the last input turning 3 minutes old is reported as away; new input is active again', () {
      reporter.setAttended(true);
      client.sent.clear();
      timers.advance(const Duration(minutes: 3));
      expect(client.sent.where((p) => p['active'] == false), isNotEmpty);
      expect(client.sent.last['active'], isFalse);
      expect(client.sent.last['idleSeconds'], 180);
      reporter.input();
      expect(client.sent.last['active'], isTrue);
    });

    test(
      'a heartbeat every 60 s while connected; input moved on 30 s is re-sent',
      () {
        reporter.setAttended(true);
        final first = client.sent.length;
        timers.advance(const Duration(seconds: 60));
        expect(client.sent.length, first + 1, reason: 'heartbeat');
        timers.advance(const Duration(seconds: 1));
        reporter.input();
        expect(client.sent.length, first + 2, reason: 'input 61 s newer');
        reporter.input();
        expect(client.sent.length, first + 2, reason: 'the same state');
      },
    );

    test('nothing is queued while disconnected; a reconnect reports again', () {
      client.drop();
      client.sent.clear();
      reporter.setAttended(true);
      expect(client.sent, isEmpty);
      expect(timers.pending, isEmpty, reason: 'no timers without a socket');
      client.reconnect();
      expect(client.sent.single['active'], isTrue);
    });
  });

  group('mobile', () {
    late PresenceReporter reporter;
    setUp(() {
      reporter = PresenceReporter(mobile: true, timers: timers, now: clock)
        ..bind(client);
    });
    tearDown(() => reporter.dispose());

    test('the foreground is active (idle 0); the background is not and needs no heartbeat', () {
      client.sent.clear();
      reporter.setAttended(true);
      expect(client.sent.last, {'active': true, 'idleSeconds': 0});
      reporter.setAttended(false);
      expect(client.sent.last, {'active': false, 'idleSeconds': null});
      expect(timers.pending, isEmpty);
      reporter.input();
      expect(client.sent, hasLength(2), reason: 'a phone counts no input');
    });
  });
}
