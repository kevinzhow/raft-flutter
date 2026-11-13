import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/activity_rollout_flags.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _flag = ActivityRolloutFlags.activityConversationListKey;
const _scope = ['https://flag-fixture.invalid', 'alice', 's', 'owner'];

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://flag-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
  }

  final pending = <Completer<dynamic>>[];
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);

  @override
  Stream<RaftEvent> get events => ingress.stream;

  @override
  Future<dynamic> post(String path, {dynamic data}) {
    expect(path, '/feature-flags/evaluate');
    expect((data as Map)['keys'], ActivityRolloutFlags.keys);
    final next = Completer<dynamic>();
    pending.add(next);
    return next.future;
  }

  @override
  Future<void> dispose() async {
    await ingress.close();
    await super.dispose();
  }
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Client client;
  late WorkspaceController workspace;
  late ActivityRolloutFlags flags;

  setUp(() async {
    DevicePreferences.reset();
    SharedPreferences.setMockInitialValues({});
    DevicePreferences.adopt(await SharedPreferences.getInstance());
    FeatureFlagMemory.write(_scope, {
      for (final key in ActivityRolloutFlags.keys) key: true,
    });
    client = _Client();
    workspace = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner'});
    flags = ActivityRolloutFlags.of(workspace);
    expect(flags.activityConversationList, isTrue);
  });

  tearDown(() async {
    workspace.dispose();
    await client.dispose();
    DevicePreferences.reset();
  });

  final unknown = <String, Object?>{
    'missing evaluations': <String, dynamic>{},
    'empty evaluations': {'evaluations': <dynamic>[]},
    'invalid evaluations type': {'evaluations': 'unavailable'},
    'omitted requested key': {
      'evaluations': [
        {'key': 'thread_unread_badge_v0', 'enabled': true},
      ],
    },
    'invalid boolean': {
      'evaluations': [
        {'key': _flag, 'enabled': 'true'},
      ],
    },
    'duplicate false then true': {
      'evaluations': [
        {'key': _flag, 'enabled': false},
        {'key': _flag, 'enabled': true},
      ],
    },
    'duplicate true then false': {
      'evaluations': [
        {'key': _flag, 'enabled': true},
        {'key': _flag, 'enabled': false},
      ],
    },
    'duplicate false then false': {
      'evaluations': [
        {'key': _flag, 'enabled': false},
        {'key': _flag, 'enabled': false},
      ],
    },
  };
  for (final entry in unknown.entries) {
    test('${entry.key} keeps accepted layout and disk value', () async {
      client.pending.single.complete(entry.value);
      await _settle();
      expect(flags.activityConversationList, isTrue);
      expect(FeatureFlagMemory.read(_scope, _flag), isTrue);
    });
  }

  for (final reversed in [false, true]) {
    test('duplicate boolean rows cannot enable an accepted false '
        '(reversed=$reversed)', () async {
      client.pending.single.complete({
        'evaluations': [
          {'key': _flag, 'enabled': false},
        ],
      });
      await _settle();
      expect(flags.activityConversationList, isFalse);
      flags.reevaluate();
      client.pending.last.complete({
        'evaluations': [
          {'key': _flag, 'enabled': reversed},
          {'key': _flag, 'enabled': !reversed},
        ],
      });
      await _settle();
      expect(flags.activityConversationList, isFalse);
      expect(FeatureFlagMemory.read(_scope, _flag), isFalse);
    });
  }

  test('one explicit false is accepted and persisted', () async {
    client.pending.single.complete({
      'evaluations': [
        {'key': _flag, 'enabled': false},
      ],
    });
    await _settle();
    expect(flags.activityConversationList, isFalse);
    expect(FeatureFlagMemory.read(_scope, _flag), isFalse);
  });

  // Web 1.24 retired `thread_unread_badge_v0` and `sidebar_mark_all_read_v0`:
  // they are neither asked nor taken from an answer that still carries them.
  test('retired and unrequested keys in the answer change nothing', () async {
    expect(ActivityRolloutFlags.keys, [_flag]);
    client.pending.single.complete({
      'evaluations': [
        {'key': 'thread_unread_badge_v0', 'enabled': false},
        {'key': 'sidebar_mark_all_read_v0', 'enabled': false},
        {'key': 'unrequested_flag', 'enabled': true},
      ],
    });
    await _settle();
    expect(flags.activityConversationList, isTrue);
    expect(FeatureFlagMemory.read(_scope, 'thread_unread_badge_v0'), isNull);
    expect(FeatureFlagMemory.read(_scope, _flag), isTrue);
    expect(FeatureFlagMemory.read(_scope, 'unrequested_flag'), isNull);
  });

  test(
    'cold unknown stays off without creating an accepted disk value',
    () async {
      workspace.dispose();
      await client.dispose();
      client = _Client();
      workspace = WorkspaceController(client)
        ..server = RaftRecord({'id': 'cold', 'role': 'owner'});
      flags = ActivityRolloutFlags.of(workspace);
      expect(flags.activityConversationList, isFalse);
      expect(client.pending, hasLength(1));
      client.pending.single.complete({'evaluations': <dynamic>[]});
      await _settle();
      expect(flags.activityConversationList, isFalse);
      expect(
        FeatureFlagMemory.read([
          'https://flag-fixture.invalid',
          'alice',
          'cold',
          'owner',
        ], _flag),
        isNull,
      );
    },
  );

  test('transient failure preserves accepted value and disk memory', () async {
    client.pending.single.completeError(
      const RaftApiException('fixture outage', status: 503),
    );
    await _settle();
    expect(flags.activityConversationList, isTrue);
    expect(FeatureFlagMemory.read(_scope, _flag), isTrue);
  });

  for (final status in [401, 403]) {
    test('$status retains the existing denial behavior', () async {
      client.pending.single.completeError(
        RaftApiException('fixture denial', status: status),
      );
      await _settle();
      expect(flags.activityConversationList, isFalse);
      expect(FeatureFlagMemory.read(_scope, _flag), isFalse);
    });
  }

  test(
    'late old role denial cannot clear a new role remembered layout',
    () async {
      FeatureFlagMemory.write(
        ['https://flag-fixture.invalid', 'alice', 's', 'member'],
        {_flag: true},
      );
      workspace.server = RaftRecord({'id': 's', 'role': 'member'});
      workspace.notifyListeners();
      expect(client.pending, hasLength(2));
      client.pending.first.completeError(
        const RaftApiException('fixture stale denial', status: 403),
      );
      await _settle();
      expect(flags.activityConversationList, isTrue);
      expect(
        FeatureFlagMemory.read([
          'https://flag-fixture.invalid',
          'alice',
          's',
          'member',
        ], _flag),
        isTrue,
      );
      client.pending.last.complete({
        'evaluations': [
          {'key': _flag, 'enabled': true},
        ],
      });
      await _settle();
    },
  );

  test(
    'same-authority recheck keeps layout until explicit false arrives',
    () async {
      client.pending.first.complete({
        'evaluations': [
          {'key': _flag, 'enabled': true},
        ],
      });
      await _settle();
      client.ingress.add(const RaftEvent('connected', null));
      expect(client.pending, hasLength(2));
      expect(flags.activityConversationList, isTrue);
      client.pending.last.complete({
        'evaluations': [
          {'key': _flag, 'enabled': false},
        ],
      });
      await _settle();
      expect(flags.activityConversationList, isFalse);
    },
  );
}
