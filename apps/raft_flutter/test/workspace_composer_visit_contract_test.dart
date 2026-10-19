import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_cache.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

typedef _Warning = ({List<String> unresolved, bool agentStopped});
const _warning = (unresolved: ['fixture'], agentStopped: false);

class _Warnings extends MapBase<String, _Warning> {
  final valuesByScope = <String, _Warning>{};
  final removals = <String>[];
  String? throwOnceFor;
  @override
  _Warning? operator [](Object? key) => valuesByScope[key];
  @override
  void operator []=(String key, _Warning value) => valuesByScope[key] = value;
  @override
  Iterable<String> get keys => valuesByScope.keys;
  @override
  void clear() => valuesByScope.clear();
  @override
  _Warning? remove(Object? key) {
    removals.add('$key');
    if (key == throwOnceFor) {
      throwOnceFor = null;
      throw StateError('fixture warning removal');
    }
    return valuesByScope.remove(key);
  }
}

class _Cache implements WorkspaceCache {
  @override
  Future<dynamic> read(o, p, s, String kind, String id) async => null;
  @override
  Future<void> write(o, p, s, String kind, String id, value) async {}
  @override
  Future<void> revokeChannel(o, p, s, String id) async {}
  @override
  Future<void> revokeServer(o, p, s) async {}
  @override
  Future<void> clearAccount(o, p) async {}
  @override
  Future<List<Map<String, dynamic>>> readTranslations(o, p, s) async => [];
  @override
  Future<void> writeTranslations(o, p, s, entries) async {}
  @override
  Future<void> close() async {}
}

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://composer-visits.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s1');
  }
  final bus = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => bus.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => {};
  @override
  Future<void> dispose() async {
    await bus.close();
    await super.dispose();
  }
}

// Public scope and warning hooks provide controlled inputs and an observable
// side effect. No new product getter exposes the private visit counters.
class _Workspace extends WorkspaceController {
  _Workspace(super.client, {required super.cache, super.presentationSource})
    : super(ownsClient: false);
  String? mainScope, replyScope;
  final scopeReads = <String>[];
  final _warnings = _Warnings();
  @override
  _Warnings get sendWarnings => _warnings;
  bool closed = false;
  @override
  String? draftScope({bool thread = false}) {
    scopeReads.add(thread ? 'thread' : 'channel');
    return thread ? replyScope : mainScope;
  }

  @override
  void dispose() {
    if (closed) return;
    closed = true;
    super.dispose();
  }
}

class _Fixture {
  _Fixture() {
    root = make();
    addTearDown(() async {
      for (final page in pages.reversed) {
        if (!page.closed) await page.flushCache();
        page.dispose();
      }
      await client.dispose();
    });
  }
  final client = _Client(), cache = _Cache();
  final pages = <_Workspace>[];
  late final _Workspace root;
  _Workspace make({WorkspaceController? source}) {
    final w = _Workspace(client, cache: cache, presentationSource: source);
    pages.add(w);
    w.server = RaftRecord({'id': 's1', 'role': 'owner'});
    w.channel = RaftChannel({'id': 'c1', 'joined': true});
    w.channels = [w.channel!];
    if (source == null) w.messageDomain.ledger.switchServer('s1');
    return w;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'V01 first scope admission does not remove current warning or notice',
    () {
      final w = _Fixture().root;
      w.sendWarnings['c1'] = _warning;
      w.mainScope = 'c1';
      w.setComposerError('first visit');
      expect(w.sendWarnings.removals, isEmpty);
      expect(w.sendWarnings['c1'], _warning);
      expect(w.composerErrorFor(), 'first visit');
    },
  );

  test(
    'V02 repeated sync and reads retain the current visit without notifying',
    () {
      final w = _Fixture().root..mainScope = 'c1';
      w.setComposerError('same visit');
      w.sendWarnings['c1'] = _warning;
      w.notifyListeners();
      var notified = 0;
      w.addListener(() => notified++);
      for (var i = 0; i < 3; i++) {
        expect(w.composerErrorFor(), 'same visit');
      }
      expect(notified, 0);
      w.notifyListeners();
      expect(notified, 1);
      expect(w.sendWarnings.removals, isEmpty);
      expect(w.sendWarnings['c1'], _warning);
    },
  );

  test(
    'V03 leaving a channel clears only its warning and expires its notice',
    () {
      final w = _Fixture().root..mainScope = 'c1';
      w.setComposerError('old channel visit');
      w.sendWarnings.addAll({'c1': _warning, 'c2': _warning});
      w.mainScope = 'c2';
      w.notifyListeners();
      expect(w.sendWarnings.removals, ['c1']);
      expect(w.sendWarnings.keys, ['c2']);
      w.mainScope = 'c1';
      w.notifyListeners();
      expect(w.composerErrorFor(), isNull);
    },
  );

  test('V04 changing thread leaves the channel visit intact', () {
    final w = _Fixture().root
      ..mainScope = 'c1'
      ..replyScope = 'thread:m1';
    w.setComposerError('channel stays');
    w.setComposerError('old thread visit', thread: true);
    w.sendWarnings.addAll({'c1': _warning, 'thread:m1': _warning});
    w.replyScope = 'thread:m2';
    w.notifyListeners();
    expect(w.sendWarnings.removals, ['thread:m1']);
    expect(w.sendWarnings['c1'], _warning);
    expect(w.composerErrorFor(), 'channel stays');
    w.replyScope = 'thread:m1';
    w.notifyListeners();
    expect(w.composerErrorFor(thread: true), isNull);
  });

  test('V05 closing and reopening a thread does not resurrect its notice', () {
    final w = _Fixture().root..replyScope = 'thread:m1';
    w.setComposerError('thread visit', thread: true);
    w.sendWarnings['thread:m1'] = _warning;
    w.replyScope = null;
    w.notifyListeners();
    expect(w.sendWarnings.removals, ['thread:m1']);
    expect(w.composerErrorFor(thread: true), isNull);
    w.replyScope = 'thread:m1';
    w.notifyListeners();
    expect(w.composerErrorFor(thread: true), isNull);
  });

  test(
    'V06 leaving to no channel clears the old warning and admits no notice',
    () {
      final w = _Fixture().root..mainScope = 'c1';
      w.setComposerError('old');
      w.sendWarnings['c1'] = _warning;
      w.mainScope = null;
      w.notifyListeners();
      w.setComposerError('must not enter a null scope');
      expect(w.sendWarnings.removals, ['c1']);
      expect(w.composerErrorFor(), isNull);
      w.mainScope = 'c1';
      w.notifyListeners();
      expect(w.composerErrorFor(), isNull);
    },
  );

  test(
    'V07 both inputs are read channel then thread and leave in that order',
    () {
      final w = _Fixture().root
        ..mainScope = 'c1'
        ..replyScope = 'thread:m1';
      w.notifyListeners();
      w.sendWarnings.addAll({
        'c1': _warning,
        'thread:m1': _warning,
        'unrelated': _warning,
      });
      w.mainScope = 'c2';
      w.replyScope = 'thread:m2';
      w.scopeReads.clear();
      w.notifyListeners();
      expect(w.scopeReads.take(2), ['channel', 'thread']);
      expect(w.sendWarnings.removals, ['c1', 'thread:m1']);
      expect(w.sendWarnings.keys, ['unrelated']);
    },
  );

  test('V08 identical keys in the two visit slots are not deduplicated', () {
    final w = _Fixture().root
      ..mainScope = 'same'
      ..replyScope = 'same';
    w.setComposerError('same key');
    w.sendWarnings['same'] = _warning;
    w.mainScope = 'next-main';
    w.replyScope = 'next-thread';
    w.notifyListeners();
    expect(w.sendWarnings.removals, ['same', 'same']);
    w.mainScope = 'same';
    w.replyScope = 'same';
    w.notifyListeners();
    expect(w.composerErrorFor(), isNull);
  });

  test('V09 raising a notice synchronizes before capturing its visit', () {
    final w = _Fixture().root..mainScope = 'c1';
    w.setComposerError('first');
    w.mainScope = 'c2';
    w.setComposerError('second without an intervening notify');
    w.notifyListeners();
    expect(w.composerErrorFor(), 'second without an intervening notify');
    w.mainScope = 'c1';
    expect(w.composerErrorFor(), isNull);
  });

  test('V10 a false cause expires the notice permanently', () {
    final w = _Fixture().root..mainScope = 'c1';
    var cause = true;
    w.setComposerError('cause bound', whileTrue: () => cause);
    expect(w.composerErrorFor(), 'cause bound');
    cause = false;
    expect(w.composerErrorFor(), isNull);
    cause = true;
    w.mainScope = 'c2';
    w.notifyListeners();
    w.mainScope = 'c1';
    w.notifyListeners();
    expect(w.composerErrorFor(), isNull);
  });

  test('V11a a borrowed visit does not advance the source notice visit', () {
    final f = _Fixture(), source = f.root;
    source.mainScope = 'c1';
    source.setComposerError('source visit');
    final page = f.make(source: source)..mainScope = 'c1';
    page.notifyListeners();
    expect(identical(page.composer, source.composer), isTrue);
    page.mainScope = 'c2';
    page.notifyListeners();
    expect(source.composerErrorFor(), 'source visit');
    page.mainScope = 'c1';
    page.notifyListeners();
    expect(page.composerErrorFor(), 'source visit');
  });

  test('V11b a source visit does not advance the borrowed notice visit', () {
    final f = _Fixture(), source = f.root..mainScope = 'c1';
    source.notifyListeners();
    final page = f.make(source: source)..mainScope = 'c1';
    page.setComposerError('borrowed visit');
    expect(source.composerErrorFor(), 'borrowed visit');
    source.mainScope = 'c2';
    source.notifyListeners();
    source.mainScope = 'c1';
    source.notifyListeners();
    expect(page.composerErrorFor(), 'borrowed visit');
    page.mainScope = 'c2';
    page.notifyListeners();
    page.mainScope = 'c1';
    page.notifyListeners();
    expect(source.composerErrorFor(), isNull);
  });

  test(
    'V12 borrowed cleanup mutates source warnings and preserves its unused map',
    () {
      final f = _Fixture(), source = f.root..mainScope = 'c1';
      source.notifyListeners();
      final page = f.make(source: source)..mainScope = 'c1';
      page.notifyListeners();
      source.sendWarnings['c1'] = _warning;
      page.sendWarnings['c1'] = _warning;
      page.mainScope = 'c2';
      page.notifyListeners();
      expect(source.sendWarnings.removals, ['c1']);
      expect(source.sendWarnings.containsKey('c1'), isFalse);
      expect(page.sendWarnings.removals, isEmpty);
      expect(page.sendWarnings['c1'], _warning);
    },
  );

  test(
    'V13 independent receivers sharing a client retain independent notices',
    () {
      final f = _Fixture(), first = f.root..mainScope = 'c1';
      final second = f.make()..mainScope = 'c1';
      first.setComposerError('first visit');
      second.setComposerError('second visit');
      first.sendWarnings['c1'] = _warning;
      second.sendWarnings['c1'] = _warning;
      first.mainScope = 'c2';
      first.notifyListeners();
      first.mainScope = 'c1';
      first.notifyListeners();
      expect(first.composerErrorFor(), isNull);
      expect(second.composerErrorFor(), 'second visit');
      expect(second.sendWarnings['c1'], _warning);
      expect(second.sendWarnings.removals, isEmpty);
    },
  );

  test('V14 notification after disposal does not advance visit cleanup', () {
    final w = _Fixture().root..mainScope = 'c1';
    w.notifyListeners();
    w.sendWarnings['c1'] = _warning;
    w.dispose();
    w.mainScope = 'c2';
    expect(w.notifyListeners, returnsNormally);
    expect(w.sendWarnings.removals, isEmpty);
    expect(w.sendWarnings['c1'], _warning);
  });

  test('V15 a cleanup exception preserves increment-before-assign partial progress', () {
    final w = _Fixture().root
      ..mainScope = 'c1'
      ..replyScope = 'thread:m1';
    w.setComposerError('before throwing leave');
    w.sendWarnings.addAll({'c1': _warning, 'thread:m1': _warning});
    w.sendWarnings.throwOnceFor = 'c1';
    w.mainScope = 'c2';
    w.replyScope = 'thread:m2';
    expect(w.notifyListeners, throwsStateError);
    expect(w.sendWarnings.removals, ['c1']);
    expect(w.sendWarnings['thread:m1'], _warning);
    w.mainScope = 'c1';
    w.replyScope = 'thread:m1';
    expect(w.composerErrorFor(), isNull);
    w.mainScope = 'c2';
    w.replyScope = 'thread:m2';
    w.notifyListeners();
    expect(w.sendWarnings.removals, ['c1', 'c1', 'thread:m1']);
    expect(w.sendWarnings, isEmpty);
  });
}
