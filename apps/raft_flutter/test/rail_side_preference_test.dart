import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/rail_side_preference.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(DevicePreferences.reset);

  test('parse: end only for the stored "end"', () {
    expect(RailSideStore.parse(null), RaftRailSide.start);
    expect(RailSideStore.parse('start'), RaftRailSide.start);
    expect(RailSideStore.parse('left'), RaftRailSide.start);
    expect(RailSideStore.parse('end'), RaftRailSide.end);
  });

  test('round trip through the device preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    DevicePreferences.adopt(prefs);
    final store = RailSideStore();
    addTearDown(store.dispose);
    expect(store.side, RaftRailSide.start);
    var notified = 0;
    store.addListener(() => notified++);
    store.update(RaftRailSide.end);
    await Future<void>.delayed(Duration.zero);
    expect(notified, 1);
    expect(prefs.getString(RailSideStore.preferenceKey), 'end');
    // A new session reads it on the first frame, synchronously.
    final next = RailSideStore();
    addTearDown(next.dispose);
    expect(next.side, RaftRailSide.end);
    store.update(RaftRailSide.end);
    expect(notified, 1, reason: 'no change, no notification');
    store.update(RaftRailSide.start);
    await Future<void>.delayed(Duration.zero);
    expect(prefs.containsKey(RailSideStore.preferenceKey), isFalse);
    expect(RailSideStore().side, RaftRailSide.start);
  });

  test('without preloaded preferences the default holds', () {
    DevicePreferences.reset();
    final store = RailSideStore();
    addTearDown(store.dispose);
    expect(store.side, RaftRailSide.start);
  });
}
