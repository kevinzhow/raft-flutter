import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/cache_exit.dart';
import 'package:raft_updater/raft_updater.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    bindCacheExit(null);
    resetCacheExitForTest();
  });

  test('the actual updater required-exit path honors only the explicit unsaved-child-draft veto and retries later', () async {
    final updater = AppUpdater();
    var exits = 0;
    updater.performRequiredExit = () async {
      exits++;
    };
    bindCacheExit(() async => CacheExitOutcome.vetoed);
    await updater.quitAfterHook();
    expect(exits, 0);
    bindCacheExit(() async => CacheExitOutcome.completed);
    await updater.quitAfterHook();
    expect(exits, 1);
  });

  for (final result in [CacheExitOutcome.failed, CacheExitOutcome.timedOut]) {
    test(
      'old cache $result remains compatible with updater required quit',
      () async {
        final updater = AppUpdater();
        var exits = 0;
        updater.performRequiredExit = () async {
          exits++;
        };
        bindCacheExit(() async => result);
        await updater.quitAfterHook();
        expect(exits, 1);
      },
    );
  }
}
