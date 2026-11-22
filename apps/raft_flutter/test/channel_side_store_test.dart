import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_side_layout.dart';
import 'package:raft_flutter/features/channel_side_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef S = ChannelSideSection;

class _Patch {
  _Patch(this.data);
  final Map<String, dynamic> data;
  final done = Completer<dynamic>();

  ChannelSideLayout? get layout =>
      ChannelSideLayout.parse(data['channelSideLayout']);
}

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://side-store.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s1');
  }

  final patches = <_Patch>[];
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);

  @override
  Stream<RaftEvent> get events => ingress.stream;

  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
    bool workspaceScoped = true,
  }) {
    expect(method, 'PATCH');
    expect(path, '/servers/s1/sidebar-order');
    final patch = _Patch(Map<String, dynamic>.from(data as Map));
    patches.add(patch);
    return patch.done.future;
  }

  @override
  Future<void> dispose() async {
    await ingress.close();
    await super.dispose();
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);

  /// The sidebar order as the server (or the device cache) delivers it.
  void ping() => notifyListeners();

  void deliver(Map<String, dynamic> order) {
    sidebarOrder = order;
    notifyListeners();
  }
}

ChannelSideLayout lay(List<(List<S>, int)> columns) => ChannelSideLayout([
  for (final (sections, width) in columns) ChannelSideColumn(sections, width),
]);

String shape(ChannelSideLayout l) =>
    l.columns.map((c) => c.sections.map((s) => s.name).join('+')).join(' | ');

/// A layout the person saved: Files left of Tasks, the profile in the thread's
/// column. Complete, so the store shows exactly it.
final saved = lay([
  ([S.files], 300),
  ([S.tasks, S.thread], 420),
  ([S.artifact], 500),
  ([S.profile, S.context, S.details], 380),
]);
final other = lay([
  ([S.thread], 400),
  ([S.files, S.tasks], 330),
  ([S.artifact], 480),
  ([S.profile, S.context, S.details], 400),
]);

Map<String, dynamic> orderWith(ChannelSideLayout? layout) => {
  'pinned': ['x'],
  'channelSideLayout': ?layout?.toJson(),
};

const _deviceLayout = 'raft.channelSide.layout';
const _deviceConversationWidth = 'raft.channelSide.conversationWidth';

Future<void> expectDeviceWidths(ChannelSideLayout layout, int? width) async {
  final prefs = DevicePreferences.current!;
  await prefs.reload();
  expect(
    ChannelSideLayout.parse(jsonDecode(prefs.getString(_deviceLayout)!)),
    layout,
  );
  expect(prefs.getString(_deviceConversationWidth), width?.toString());
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Client client;
  late _Workspace w;

  Future<void> boot([Map<String, Object> prefs = const {}]) async {
    DevicePreferences.reset();
    SharedPreferences.setMockInitialValues(prefs);
    DevicePreferences.adopt(await SharedPreferences.getInstance());
    client = _Client();
    w = _Workspace(client)..server = RaftRecord({'id': 's1', 'role': 'owner'});
  }

  tearDown(() async {
    w.dispose();
    await client.dispose();
    DevicePreferences.reset();
  });

  group('the layout follows the sidebar order', () {
    test('what the server saved is the layout, completed', () async {
      await boot();
      w.sidebarOrder = orderWith(saved);
      final store = ChannelSideStore.of(w);
      expect(store.layout, saved);
      expect(ChannelSideStore.of(w), same(store));
    });

    test('a layout arriving later replaces the shown one and is kept on the device', () async {
      await boot();
      final store = ChannelSideStore.of(w);
      expect(store.layout, ChannelSideLayout.defaults);
      var heard = 0;
      store.addListener(() => heard++);
      w.deliver(orderWith(saved));
      expect(store.layout, saved);
      expect(heard, 1);
      expect(
        ChannelSideLayout.parse(
          jsonDecode(DevicePreferences.current!.getString(_deviceLayout)!),
        ),
        saved,
      );
      w.deliver(orderWith(other));
      expect(store.layout, other);
    });

    test('a saved layout missing a section is completed (never a section without a place)', () async {
      await boot();
      w.sidebarOrder = orderWith(
        lay([
          ([S.tasks], 300),
        ]),
      );
      final store = ChannelSideStore.of(w);
      expect(
        shape(store.layout),
        'thread | tasks+files | artifact | profile+context+details',
      );
      expect(store.layout.columns[1].width, 300);
    });

    test('a value that is not a layout reads as none saved', () async {
      await boot();
      w.sidebarOrder = {
        'channelSideLayout': {'v': 2, 'columns': []},
      };
      expect(ChannelSideStore.of(w).layout, ChannelSideLayout.defaults);
    });

    test('unrelated sidebar-order changes and controller notifications change nothing', () async {
      await boot();
      w.sidebarOrder = orderWith(saved);
      final store = ChannelSideStore.of(w);
      var heard = 0;
      store.addListener(() => heard++);
      w.deliver({
        ...orderWith(saved),
        'pinned': ['y'],
      });
      w.deliver({...w.sidebarOrder});
      expect(heard, 0);
      expect(store.layout, saved);
    });
  });

  group('device fallback when the server has none', () {
    test(
      'this device\'s copy is the first frame and the answer with none saved',
      () async {
        await boot({_deviceLayout: jsonEncode(saved.toJson())});
        final store = ChannelSideStore.of(w);
        expect(
          store.layout,
          saved,
          reason: 'first frame, nothing from the server yet',
        );
        w.deliver(orderWith(null));
        expect(store.layout, saved, reason: 'the server holds none');
      },
    );

    test('a broken device copy is the default', () async {
      await boot({_deviceLayout: '{"v":1,"columns":[]}'});
      expect(ChannelSideStore.of(w).layout, ChannelSideLayout.defaults);
      w.dispose();
      await client.dispose();
      await boot({_deviceLayout: 'not json'});
      expect(ChannelSideStore.of(w).layout, ChannelSideLayout.defaults);
    });

    test('the server\'s layout wins over the device copy, then none saved goes back to it', () async {
      await boot({_deviceLayout: jsonEncode(other.toJson())});
      final store = ChannelSideStore.of(w);
      w.deliver(orderWith(saved));
      expect(store.layout, saved);
      // The server copy is now this device's too: a server without one shows it.
      w.deliver(orderWith(null));
      expect(store.layout, saved);
    });

    test('with no server open a move is kept on this device only', () async {
      await boot();
      client.selectServer(null);
      final store = ChannelSideStore.of(w);
      store.moveSection(S.files, const ChannelSideDropNewColumn(0));
      expect(client.patches, isEmpty);
      expect(store.layout.columns.first.sections, [S.files]);
      expect(
        ChannelSideLayout.parse(
          jsonDecode(DevicePreferences.current!.getString(_deviceLayout)!),
        ),
        store.layout,
      );
    });
  });

  test(
    'expanded resize without a server saves both widths on this device',
    () async {
      await boot();
      client.selectServer(null);
      final store = ChannelSideStore.of(w);
      final resized = store.layout.resize(1, 960);
      store.resizeDock({1: 960}, 240);
      expect((store.layout, store.conversationWidth), (resized, 240));
      expect(client.patches, isEmpty);
      await expectDeviceWidths(resized, 240);
      final fresh = _Workspace(client);
      addTearDown(fresh.dispose);
      final reopened = ChannelSideStore.of(fresh);
      expect((reopened.layout, reopened.conversationWidth), (resized, 240));
    },
  );

  group('saving', () {
    test(
      'a drop shows at once and is saved once, in the sidebar order',
      () async {
        await boot();
        w.sidebarOrder = orderWith(saved);
        final store = ChannelSideStore.of(w);
        store.moveSection(S.tasks, const ChannelSideDropInto(0, S.files));
        final moved = store.layout;
        expect(
          shape(moved),
          'tasks+files | thread | artifact | profile+context+details',
        );
        expect(client.patches, hasLength(1));
        expect(client.patches.single.data.keys, ['channelSideLayout']);
        expect(client.patches.single.layout, moved);
        expect(w.sidebarOrder['channelSideLayout'], moved.toJson());
        client.patches.single.done.complete({
          'channelSideLayout': moved.toJson(),
        });
        await _settle();
        expect(store.layout, moved);
        expect(client.patches, hasLength(1));
      },
    );

    test('a drop where the section already is saves nothing', () async {
      await boot();
      w.sidebarOrder = orderWith(saved);
      final store = ChannelSideStore.of(w);
      var heard = 0;
      store.addListener(() => heard++);
      store.moveSection(S.files, const ChannelSideDropInto(0, null));
      store.moveSection(S.files, const ChannelSideDropNewColumn(0));
      expect(client.patches, isEmpty);
      expect(heard, 0);
    });

    test('a resize shows live and is saved only on release', () async {
      await boot();
      w.sidebarOrder = orderWith(saved);
      final store = ChannelSideStore.of(w);
      store.resizeColumn(1, 450, false);
      store.resizeColumn(1, 480.4, false);
      expect(store.layout.columns[1].width, 480);
      expect(client.patches, isEmpty);
      store.resizeColumn(1, 500, true);
      expect(store.layout.columns[1].width, 500);
      expect(client.patches, hasLength(1));
      expect(client.patches.single.layout!.columns[1].width, 500);
    });

    test('a layout the server echoes back unchanged does not reset a live resize', () async {
      await boot();
      w.sidebarOrder = orderWith(saved);
      final store = ChannelSideStore.of(w);
      store.resizeColumn(1, 470, false);
      // Any sidebar-order write answers with the whole order, layout included.
      w.deliver(orderWith(saved));
      w.deliver({
        ...orderWith(ChannelSideLayout.parse(saved.toJson())),
        'pinned': ['z'],
      });
      expect(store.layout.columns[1].width, 470);
    });

    test(
      'a different layout from another client replaces a live resize',
      () async {
        await boot();
        w.sidebarOrder = orderWith(saved);
        final store = ChannelSideStore.of(w);
        store.resizeColumn(1, 470, false);
        w.deliver(orderWith(other));
        expect(store.layout, other);
      },
    );

    test('while a save is in flight, an older order arriving does not undo the drop', () async {
      await boot();
      w.sidebarOrder = orderWith(saved);
      final store = ChannelSideStore.of(w);
      store.moveSection(S.tasks, const ChannelSideDropInto(0, S.files));
      final moved = store.layout;
      w.deliver(orderWith(saved));
      expect(store.layout, moved);
      client.patches.single.done.complete({
        'channelSideLayout': moved.toJson(),
      });
      await _settle();
      expect(store.layout, moved);
    });
  });

  group('a refused save rolls back', () {
    test('to what the server held', () async {
      await boot();
      w.sidebarOrder = orderWith(saved);
      final store = ChannelSideStore.of(w);
      store.moveSection(S.tasks, const ChannelSideDropInto(0, S.files));
      expect(store.layout, isNot(saved));
      client.patches.single.done.completeError(
        const RaftApiException('no', status: 500),
      );
      await _settle();
      expect(store.layout, saved);
      expect(w.sidebarOrder['channelSideLayout'], saved.toJson());
      expect(
        ChannelSideLayout.parse(
          jsonDecode(DevicePreferences.current!.getString(_deviceLayout)!),
        ),
        saved,
        reason: 'this device does not keep a layout the server refused',
      );
    });

    test('with none saved: to what was last confirmed here', () async {
      await boot({_deviceLayout: jsonEncode(other.toJson())});
      w.sidebarOrder = orderWith(null);
      final store = ChannelSideStore.of(w);
      expect(store.layout, other);
      store.resizeColumn(1, 600, true);
      expect(store.layout.columns[1].width, 600);
      client.patches.single.done.completeError(
        const RaftApiException('no', status: 403),
      );
      await _settle();
      expect(store.layout, other);
    });

    test('a refused resize release goes back too', () async {
      await boot();
      w.sidebarOrder = orderWith(saved);
      final store = ChannelSideStore.of(w);
      store.resizeColumn(1, 600, false);
      store.resizeColumn(1, 610, true);
      client.patches.single.done.completeError(StateError('offline'));
      await _settle();
      expect(store.layout, saved);
    });

    test(
      'a refused expanded resize restores the absent legacy width preference',
      () async {
        await boot({_deviceLayout: jsonEncode(other.toJson())});
        w.sidebarOrder = orderWith(null);
        final store = ChannelSideStore.of(w);
        store.resizeDock({1: 960}, 240);
        expect(store.conversationWidth, 240);
        expect(client.patches.single.data.keys, ['channelSideLayout']);
        client.patches.single.done.completeError(
          const RaftApiException('no', status: 403),
        );
        await _settle();
        expect((store.layout, store.conversationWidth), (other, null));
        await expectDeviceWidths(other, null);
      },
    );

    test('a refused resize with the same dock restores the accepted conversation width', () async {
      await boot({_deviceConversationWidth: '260'});
      w.sidebarOrder = orderWith(saved);
      final store = ChannelSideStore.of(w);
      store.resizeDock({1: saved.columns[1].width}, 240);
      expect(store.conversationWidth, 240);
      expect(client.patches.single.layout, saved);
      client.patches.single.done.completeError(StateError('offline'));
      await _settle();
      expect((store.layout, store.conversationWidth), (saved, 260));
      await expectDeviceWidths(saved, 260);
    });

    for (final newestSettlesFirst in [false, true]) {
      test(
        'resize rollback keeps the accepted older pair (newest settles first: $newestSettlesFirst)',
        () async {
          await boot();
          w.sidebarOrder = orderWith(saved);
          final store = ChannelSideStore.of(w);
          store.resizeDock({1: 520}, 240);
          final first = store.layout;
          store.resizeColumn(1, 540, false, conversationWidth: 220);
          expect(client.patches, hasLength(1));
          store.resizeColumn(1, 560, true, conversationWidth: 200);
          final second = store.layout;
          expect(client.patches, hasLength(2));

          void acceptOlder() => client.patches.first.done.complete({
            'channelSideLayout': first.toJson(),
          });
          void refuseNewest() => client.patches.last.done.completeError(
            const RaftApiException('no', status: 500),
          );
          if (newestSettlesFirst) {
            refuseNewest();
          } else {
            acceptOlder();
          }
          await _settle();
          expect((store.layout, store.conversationWidth), (second, 200));
          if (newestSettlesFirst) {
            acceptOlder();
          } else {
            refuseNewest();
          }
          await _settle();
          expect((store.layout, store.conversationWidth), (first, 240));
          await expectDeviceWidths(first, 240);
        },
      );
    }

    test('overlapping saves: the layout shown is the newest one asked for until all settle', () async {
      await boot();
      w.sidebarOrder = orderWith(saved);
      final store = ChannelSideStore.of(w);
      store.moveSection(S.tasks, const ChannelSideDropInto(0, S.files));
      final first = store.layout;
      store.resizeColumn(0, 350, true);
      final second = store.layout;
      expect(client.patches, hasLength(2));
      expect(second, isNot(first));
      // The older one is refused first: its rollback restores the order from
      // before it, but a newer save is still out and the layout shown is its.
      client.patches[0].done.completeError(
        const RaftApiException('no', status: 500),
      );
      await _settle();
      expect(store.layout, second);
      client.patches[1].done.complete({'channelSideLayout': second.toJson()});
      await _settle();
      expect(store.layout, second, reason: 'the newest was saved: it stands');
    });

    test('overlapping saves: a refused newest goes back to what the server holds', () async {
      await boot();
      w.sidebarOrder = orderWith(saved);
      final store = ChannelSideStore.of(w);
      store.moveSection(S.tasks, const ChannelSideDropInto(0, S.files));
      final first = store.layout;
      store.resizeColumn(0, 350, true);
      // The first is accepted, the newer one refused: the server holds `first`.
      client.patches[0].done.complete({'channelSideLayout': first.toJson()});
      await _settle();
      client.patches[1].done.completeError(
        const RaftApiException('no', status: 500),
      );
      await _settle();
      expect(store.layout, first);
    });
  });

  group('the cards beside the chat', () {
    test('open and collapsed are the person\'s, not the channel\'s, and kept on the device', () async {
      await boot();
      final store = ChannelSideStore.of(w);
      expect(store.cardOpen(ChannelSideCard.tasks), isFalse);
      expect(store.collapsed(ChannelSideCard.files), isFalse);
      store.setCardOpen(ChannelSideCard.tasks, true);
      store.setCollapsed(ChannelSideCard.files, true);
      expect(store.cardOpen(ChannelSideCard.tasks), isTrue);
      expect(store.cardOpen(ChannelSideCard.files), isFalse);
      expect(store.collapsed(ChannelSideCard.files), isTrue);
      expect(store.collapsed(ChannelSideCard.tasks), isFalse);
      // Another channel, even another server: the same cards.
      w.channel = RaftChannel({'id': 'c1', 'name': 'one', 'type': 'channel'});
      w.ping();
      expect(store.cardOpen(ChannelSideCard.tasks), isTrue);
      w.channel = RaftChannel({'id': 'c2', 'name': 'two', 'type': 'channel'});
      w.ping();
      expect(store.cardOpen(ChannelSideCard.tasks), isTrue);
      expect(store.collapsed(ChannelSideCard.files), isTrue);
      // The next launch (a new workspace on the same device) starts from them.
      final next = _Workspace(client)
        ..server = RaftRecord({'id': 's2', 'role': 'member'});
      addTearDown(next.dispose);
      final again = ChannelSideStore.of(next);
      expect(again.cardOpen(ChannelSideCard.tasks), isTrue);
      expect(again.cardOpen(ChannelSideCard.files), isFalse);
      expect(again.collapsed(ChannelSideCard.files), isTrue);
      expect(again.collapsed(ChannelSideCard.tasks), isFalse);
    });

    test(
      'opening an open card only picks it; setting a value it has tells nobody',
      () async {
        await boot();
        final store = ChannelSideStore.of(w);
        var heard = 0;
        store.addListener(() => heard++);
        store.setCardOpen(ChannelSideCard.files, false);
        store.setCollapsed(ChannelSideCard.files, false);
        expect(heard, 0);
        store.setCardOpen(ChannelSideCard.files, true);
        store.setCardOpen(ChannelSideCard.tasks, true);
        store.setCardOpen(ChannelSideCard.files, true);
        expect(store.activeCard(['tasks', 'files']), 'files');
        store.setCardOpen(ChannelSideCard.files, false);
        expect(store.cardOpen(ChannelSideCard.files), isFalse);
        expect(heard, 4);
      },
    );

    test('a bad stored value reads as closed and expanded', () async {
      await boot({
        'raft.channelSide.open': '{"tasks":"yes","files":true}',
        'raft.channelSide.collapsed': '[1]',
      });
      final store = ChannelSideStore.of(w);
      expect(store.cardOpen(ChannelSideCard.tasks), isFalse);
      expect(store.cardOpen(ChannelSideCard.files), isTrue);
      expect(store.collapsed(ChannelSideCard.tasks), isFalse);
    });

    test('the card opened or picked last is the one that shows where only one fits', () async {
      await boot();
      final store = ChannelSideStore.of(w);
      store.setCardOpen(ChannelSideCard.tasks, true);
      store.setCardOpen(ChannelSideCard.files, true);
      expect(store.activeCard(['tasks', 'files']), 'files');
      store.focus('tasks');
      expect(store.activeCard(['tasks', 'files']), 'tasks');
      store.focus('app');
      expect(store.activeCard(['tasks', 'files', 'app']), 'app');
      expect(store.activeCard(['tasks', 'files']), 'tasks');
      expect(store.activeCard(<String>[]), isNull);
      // Closing does not move focus; opening again does.
      store.setCardOpen(ChannelSideCard.tasks, false);
      store.setCardOpen(ChannelSideCard.tasks, true);
      expect(store.activeCard(['tasks', 'files']), 'tasks');
    });

    test(
      'activeSideCard: ties go to the first in the list, no focus is zero',
      () {
        expect(activeSideCard(['tasks', 'files'], const {}), 'tasks');
        expect(activeSideCard(['files', 'tasks'], const {'tasks': 0}), 'files');
        expect(
          activeSideCard(['tasks', 'files'], const {'files': 2, 'tasks': 1}),
          'files',
        );
        expect(activeSideCard(<String>[], const {}), isNull);
      },
    );

    test('the task filter is All until picked, and in memory only', () async {
      await boot();
      final store = ChannelSideStore.of(w);
      expect(store.taskFilter, ChannelTasksFilter.all);
      var heard = 0;
      store.addListener(() => heard++);
      store.setTaskFilter(ChannelTasksFilter.mine);
      store.setTaskFilter(ChannelTasksFilter.mine);
      expect(store.taskFilter, ChannelTasksFilter.mine);
      expect(heard, 1);
      final next = _Workspace(client)
        ..server = RaftRecord({'id': 's1', 'role': 'owner'});
      addTearDown(next.dispose);
      expect(ChannelSideStore.of(next).taskFilter, ChannelTasksFilter.all);
    });
  });

  group('stack splits', () {
    test('defaults: Tasks over Files 60/40; the thread, the Artifact and the profile 3 to a section\'s 2; else even', () async {
      await boot();
      final store = ChannelSideStore.of(w);
      expect(store.splitShares([S.tasks, S.files]), [0.6, 0.4]);
      expect(store.splitShares([S.thread, S.tasks]), [0.6, 0.4]);
      expect(store.splitShares([S.artifact, S.files]), [0.6, 0.4]);
      expect(store.splitShares([S.tasks, S.artifact]), [0.4, 0.6]);
      expect(store.splitShares([S.files, S.tasks]), [0.5, 0.5]);
      final three = store.splitShares([S.tasks, S.files, S.artifact]);
      expect(three[0], closeTo(2 / 7, 1e-9));
      expect(three[1], closeTo(2 / 7, 1e-9));
      expect(three[2], closeTo(3 / 7, 1e-9));
      expect(store.splitShares([S.profile, S.context]), [0.5, 0.5]);
      expect(store.splitShares([S.tasks]), [1.0]);
    });

    test('a saved split is kept on the device per stack and read by the next launch', () async {
      await boot();
      final store = ChannelSideStore.of(w);
      var heard = 0;
      store.addListener(() => heard++);
      store.saveSplit([S.tasks, S.files], [0.3, 0.7]);
      expect(store.splitShares([S.tasks, S.files]), [0.3, 0.7]);
      expect(store.splitShares([S.files, S.tasks]), [
        0.5,
        0.5,
      ], reason: 'another stack');
      expect(heard, 1);
      final saved = jsonDecode(
        DevicePreferences.current!.getString('raft.channelSide.splits')!,
      ) as Map;
      expect(saved.keys, ['tasks|files']);
      final next = _Workspace(client)
        ..server = RaftRecord({'id': 's1', 'role': 'owner'});
      addTearDown(next.dispose);
      expect(ChannelSideStore.of(next).splitShares([S.tasks, S.files]), [
        0.3,
        0.7,
      ]);
    });

    test(
      'a saved split that does not fit the stack reads as the default',
      () async {
        await boot({
          'raft.channelSide.splits': jsonEncode({
            'tasks|files': [0.5],
            'thread|tasks': [0.5, 0],
            'files|tasks': [0.7, 0.3],
            'artifact|files': 'x',
          }),
        });
        final store = ChannelSideStore.of(w);
        expect(store.splitShares([S.tasks, S.files]), [0.6, 0.4]);
        expect(store.splitShares([S.thread, S.tasks]), [0.6, 0.4]);
        expect(store.splitShares([S.files, S.tasks]), [0.7, 0.3]);
        expect(store.splitShares([S.artifact, S.files]), [0.6, 0.4]);
      },
    );
  });
}
