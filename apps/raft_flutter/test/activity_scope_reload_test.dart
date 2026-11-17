import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/activity_filter_choice.dart';
import 'package:raft_flutter/features/activity_scope_reload.dart';

void main() {
  bool call(
    ActivityScopeReload r,
    ActivityFilterChoice c,
    Object? pins,
    int saved,
  ) => r.changed(choice: c, pinned: pins, savedRevision: saved);

  test('Pinned reloads when the pinned list changes, not before', () {
    final r = ActivityScopeReload();
    expect(call(r, ActivityFilterChoice.pinned, [], 0), isFalse);
    expect(call(r, ActivityFilterChoice.pinned, [], 0), isFalse);
    expect(
      call(r, ActivityFilterChoice.pinned, [
        {'kind': 'channel', 'id': 'a'},
      ], 0),
      isTrue,
    );
    expect(
      call(r, ActivityFilterChoice.pinned, [
        {'kind': 'channel', 'id': 'a'},
      ], 0),
      isFalse,
    );
  });

  test('Saved reloads when savedRevision changes', () {
    final r = ActivityScopeReload();
    expect(call(r, ActivityFilterChoice.saved, null, 0), isFalse);
    expect(call(r, ActivityFilterChoice.saved, null, 1), isTrue);
    expect(call(r, ActivityFilterChoice.saved, null, 1), isFalse);
  });

  test(
    'other choices never reload, and a change under them is not replayed',
    () {
      final r = ActivityScopeReload();
      call(r, ActivityFilterChoice.all, [], 0);
      expect(call(r, ActivityFilterChoice.all, [1], 1), isFalse);
      expect(call(r, ActivityFilterChoice.pinned, [1], 1), isFalse);
      expect(call(r, ActivityFilterChoice.saved, [1], 1), isFalse);
      expect(call(r, ActivityFilterChoice.unread, [2], 2), isFalse);
    },
  );

  test('a pin change does not reload Saved nor a save reload Pinned', () {
    final r = ActivityScopeReload();
    call(r, ActivityFilterChoice.saved, [], 0);
    expect(call(r, ActivityFilterChoice.saved, [1], 0), isFalse);
    expect(call(r, ActivityFilterChoice.pinned, [1], 1), isFalse);
  });
}
