import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/background_inbox.dart';
import 'package:raft_flutter/platform/background_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Work implements BackgroundWork {
  final calls = <String>[];
  Object? cancelError;
  @override
  Future<void> initialize(Function callbackDispatcher) async =>
      calls.add('initialize');
  @override
  Future<void> registerPeriodic(String name, Duration frequency) async =>
      calls.add('register:$name:${frequency.inMinutes}');
  @override
  Future<void> cancel(String name) async {
    calls.add('cancel:$name');
    final error = cancelError;
    if (error != null) throw error;
  }
}

const _scope = 'https://fixture.example\nalice\ns';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Work work;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    work = _Work();
  });

  test(
    'Android never registers the periodic task and cancels the old one once',
    () async {
      final scheduler = BackgroundNotificationScheduler(
        work: work,
        android: true,
        ios: false,
      );
      await scheduler.initialize();
      await scheduler.bind(_scope, true);
      await scheduler.bind(_scope, true);
      await scheduler.bind(null, false);
      expect(work.calls, ['cancel:$backgroundInboxTask']);
      expect(work.calls.where((c) => c.startsWith('register')), isEmpty);
      expect(work.calls, isNot(contains('initialize')));
    },
  );

  test(
    'Android drops the scope an old worker selected and no state is activated',
    () async {
      final store = BackgroundInboxStore();
      await store.select(_scope);
      final scheduler = BackgroundNotificationScheduler(
        work: work,
        store: store,
        android: true,
        ios: false,
      );
      await scheduler.bind(_scope, true);
      expect(await store.scope(), isNull);
      expect(await store.state(_scope), isNull);
    },
  );

  test(
    'a failed Android cancel does not throw from bind and is retried',
    () async {
      final scheduler = BackgroundNotificationScheduler(
        work: work,
        android: true,
        ios: false,
      );
      work.cancelError = StateError('plugin unavailable');
      await scheduler.bind(null, false);
      await expectLater(scheduler.initialize(), throwsStateError);
      work.cancelError = null;
      await scheduler.initialize();
      await scheduler.initialize();
      expect(work.calls, [
        'cancel:$backgroundInboxTask',
        'cancel:$backgroundInboxTask',
        'cancel:$backgroundInboxTask',
      ]);
    },
  );

  test('iOS still registers its refresh and cancels it on opt-out', () async {
    final store = BackgroundInboxStore();
    final scheduler = BackgroundNotificationScheduler(
      work: work,
      store: store,
      android: false,
      ios: true,
    );
    await scheduler.bind(_scope, true);
    expect(work.calls, ['initialize', 'register:$backgroundInboxTask:15']);
    expect(await store.scope(), _scope);
    expect(await store.state(_scope), isNotNull);
    await scheduler.bind(_scope, true);
    expect(work.calls, hasLength(2));
    await scheduler.bind(_scope, false);
    expect(work.calls.last, 'cancel:$backgroundInboxTask');
    expect(await store.scope(), isNull);
    expect(await store.state(_scope), isNull);
  });

  test('other platforms touch no background API', () async {
    final scheduler = BackgroundNotificationScheduler(
      work: work,
      android: false,
      ios: false,
    );
    await scheduler.initialize();
    await scheduler.bind(_scope, true);
    expect(work.calls, isEmpty);
  });
}
