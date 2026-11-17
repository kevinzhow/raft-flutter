import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_side_flags.dart';
import 'package:raft_flutter/features/message_task_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _scope = ['https://side-flags.invalid', 'alice', 's', 'owner'];
const _taskV2 = ChannelSideFlags.taskV2Key;
const _preview = ChannelSideFlags.webPreviewKey;

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://side-flags.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }

  final requests = <List<Object?>>[];
  final pending = <Completer<dynamic>>[];
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);

  @override
  Stream<RaftEvent> get events => ingress.stream;

  @override
  Future<dynamic> post(String path, {dynamic data}) {
    expect(path, '/feature-flags/evaluate');
    requests.add((data as Map)['keys'] as List<Object?>);
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

Map<String, Object?> _answer({bool? taskV2, bool? preview}) => {
  'evaluations': [
    if (taskV2 != null) {'key': _taskV2, 'enabled': taskV2},
    if (preview != null) {'key': _preview, 'enabled': preview},
  ],
};

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Client client;
  late WorkspaceController workspace;

  setUp(() async {
    DevicePreferences.reset();
    SharedPreferences.setMockInitialValues({});
    DevicePreferences.adopt(await SharedPreferences.getInstance());
    client = _Client();
    workspace = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner'});
  });

  tearDown(() async {
    workspace.dispose();
    await client.dispose();
    DevicePreferences.reset();
  });

  test('both flags are off until evaluated, in one request', () async {
    final flags = ChannelSideFlags.of(workspace);
    expect(flags.taskV2, isFalse);
    expect(flags.webPreview, isFalse);
    expect(client.requests, [
      [_taskV2, _preview],
    ]);
    var heard = 0;
    flags.addListener(() => heard++);
    client.pending.single.complete(_answer(taskV2: true, preview: false));
    await _settle();
    expect(flags.taskV2, isTrue);
    expect(flags.webPreview, isFalse);
    expect(heard, 1);
    expect(FeatureFlagMemory.read(_scope, _taskV2), isTrue);
    expect(FeatureFlagMemory.read(_scope, _preview), isFalse);
    expect(ChannelSideFlags.of(workspace), same(flags));
  });

  test('the remembered answer is the first frame of the next launch', () {
    FeatureFlagMemory.write(_scope, {_taskV2: true, _preview: true});
    final flags = ChannelSideFlags.of(workspace);
    expect(flags.taskV2, isTrue);
    expect(flags.webPreview, isTrue);
  });

  test('a missing, invalid or duplicate row keeps what was accepted', () async {
    FeatureFlagMemory.write(_scope, {_taskV2: true, _preview: true});
    final flags = ChannelSideFlags.of(workspace);
    client.pending.single.complete({
      'evaluations': [
        {'key': _taskV2, 'enabled': 'false'},
        {'key': _preview, 'enabled': false},
        {'key': _preview, 'enabled': true},
      ],
    });
    await _settle();
    expect(flags.taskV2, isTrue);
    expect(flags.webPreview, isTrue);
  });

  test('a failure keeps the accepted flags, a denial turns them off', () async {
    FeatureFlagMemory.write(_scope, {_taskV2: true, _preview: true});
    final flags = ChannelSideFlags.of(workspace);
    client.pending.single.completeError(StateError('offline'));
    await _settle();
    expect(flags.taskV2, isTrue);
    flags.reevaluate();
    client.pending.last.completeError(
      const RaftApiException('denied', status: 403),
    );
    await _settle();
    expect(flags.taskV2, isFalse);
    expect(flags.webPreview, isFalse);
  });

  test('server:updated and connected evaluate again', () async {
    final flags = ChannelSideFlags.of(workspace);
    client.pending.single.complete(_answer(taskV2: false, preview: false));
    await _settle();
    client.ingress.add(const RaftEvent('server:updated', {}));
    await _settle();
    expect(client.requests, hasLength(2));
    client.pending.last.complete(_answer(taskV2: true, preview: true));
    await _settle();
    expect(flags.taskV2, isTrue);
    expect(flags.webPreview, isTrue);
    client.ingress.add(const RaftEvent('connected', {}));
    await _settle();
    expect(client.requests, hasLength(3));
  });

  test(
    'task v2 answered here is handed to the menus: no second request',
    () async {
      final flags = ChannelSideFlags.of(workspace);
      expect(TaskV2ConversationsFlag.of(workspace).enabled, isFalse);
      client.pending.single.complete(_answer(taskV2: true, preview: false));
      await _settle();
      expect(flags.taskV2, isTrue);
      expect(TaskV2ConversationsFlag.of(workspace).enabled, isTrue);
      expect(await TaskV2ConversationsFlag.of(workspace).ensure(), isTrue);
      expect(client.requests, hasLength(1), reason: 'one evaluation, not two');
    },
  );

  test('task_v2_use_create (the menus\' 409) turns task v2 on here', () async {
    final flags = ChannelSideFlags.of(workspace);
    client.pending.single.complete(_answer(taskV2: false, preview: false));
    await _settle();
    expect(flags.taskV2, isFalse);
    var heard = 0;
    flags.addListener(() => heard++);
    TaskV2ConversationsFlag.of(workspace).markEnabled();
    expect(flags.taskV2, isTrue);
    expect(heard, 1);
  });
}
