import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/platform/app_update.dart';
import 'package:raft_flutter/platform/local_network_access.dart';

import 'support/tracked_app_update.dart';

class _UpdateConsumer extends StatefulWidget {
  const _UpdateConsumer();

  @override
  State<_UpdateConsumer> createState() => _UpdateConsumerState();
}

class _UpdateConsumerState extends State<_UpdateConsumer> {
  AppUpdateService? update;

  void changed() {}

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = AppServicesScope.of(context).appUpdate;
    if (identical(next, update)) return;
    update?.removeListener(changed);
    update = next;
    update?.addListener(changed);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();

  @override
  void dispose() {
    update?.removeListener(changed);
    super.dispose();
  }
}

void main() {
  testWidgets('replaced network services reach inherited consumers', (t) async {
    final first = LocalNetworkAccess(lookup: (_) async => []);
    final second = LocalNetworkAccess(lookup: (_) async => []);
    LocalNetworkAccess? seen;
    var builds = 0;
    final child = Builder(
      builder: (context) {
        seen = AppServicesScope.of(context).localNetwork;
        builds++;
        return const SizedBox();
      },
    );
    Future<void> mount(LocalNetworkAccess access) => t.pumpWidget(
      AppServicesScope(
        services: AppServices.updatesDisabledForTestOrPreview(
          localNetwork: access,
        ),
        child: child,
      ),
    );
    await mount(first);
    expect(seen, same(first));
    await mount(second);
    expect(seen, same(second));
    expect(builds, 2);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('missing scope fails with an actionable error', (t) async {
    await t.pumpWidget(
      Builder(
        builder: (context) {
          AppServicesScope.of(context);
          return const SizedBox();
        },
      ),
    );
    expect(
      t.takeException(),
      isA<FlutterError>().having(
        (e) => e.message,
        'message',
        contains('Install it above Navigator'),
      ),
    );
  });

  testWidgets('disabled updates are an explicit scope capability', (t) async {
    AppServices? seen;
    await t.pumpWidget(
      AppServicesHost(
        services: const AppServices.updatesDisabledForTestOrPreview(),
        child: Builder(
          builder: (context) {
            seen = AppServicesScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen, isNotNull);
    expect(seen!.appUpdate, isNull);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'Navigator routes, dialogs, sheets and overlays share the service',
    (t) async {
      final update = TrackedAppUpdate('root', []);
      addTearDown(update.dispose);
      final seen = <String, AppUpdateService?>{};
      Widget probe(String name) => Builder(
        builder: (context) {
          seen[name] = AppServicesScope.of(context).appUpdate;
          return Text(name, textDirection: TextDirection.ltr);
        },
      );
      final navigator = GlobalKey<NavigatorState>();
      await t.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) => AppServicesHost(
            services: AppServices.withUpdates(update),
            child: child!,
          ),
          home: probe('home'),
        ),
      );
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(body: probe('route')),
          ),
        ),
      );
      await t.pumpAndSettle();
      final context = t.element(find.text('route'));
      unawaited(
        showDialog<void>(context: context, builder: (_) => probe('dialog')),
      );
      await t.pumpAndSettle();
      navigator.currentState!.pop();
      await t.pumpAndSettle();
      unawaited(
        showModalBottomSheet<void>(
          context: context,
          builder: (_) => probe('sheet'),
        ),
      );
      await t.pumpAndSettle();
      navigator.currentState!.pop();
      await t.pumpAndSettle();
      final entry = OverlayEntry(builder: (_) => probe('overlay'));
      navigator.currentState!.overlay!.insert(entry);
      await t.pump();
      expect(
        seen.keys,
        unorderedEquals(['home', 'route', 'dialog', 'sheet', 'overlay']),
      );
      expect(seen.values, everyElement(same(update)));
      entry.remove();
      entry.dispose();
      await t.pumpWidget(const SizedBox());
      expect(update.disposals, 0);
    },
  );

  testWidgets('borrowed service survives replacement and host removal', (
    t,
  ) async {
    final a = TrackedAppUpdate('a', []), b = TrackedAppUpdate('b', []);
    for (final service in [a, b]) {
      addTearDown(service.dispose);
    }
    Future<void> mount(AppUpdateService update) => t.pumpWidget(
      AppServicesHost(
        services: AppServices.withUpdates(update),
        child: const _UpdateConsumer(),
      ),
    );
    await mount(a);
    expect(a.listeners, hasLength(1));
    await mount(b);
    expect(a.listeners, isEmpty);
    expect(b.listeners, hasLength(1));
    await t.pumpWidget(const SizedBox());
    expect(b.listeners, isEmpty);
    expect([a.disposals, b.disposals], [0, 0]);
  });

  testWidgets('owned service is released after old consumers detach', (
    t,
  ) async {
    final events = <String>[];
    final a = TrackedAppUpdate('a', events), b = TrackedAppUpdate('b', events);
    Future<void> mount(AppUpdateService update) => t.pumpWidget(
      AppServicesHost(
        services: AppServices.withUpdates(update),
        ownsAppUpdate: true,
        child: const _UpdateConsumer(),
      ),
    );
    await mount(a);
    await mount(b);
    expect(a.disposals, 1);
    expect(b.disposals, 0);
    expect(events.indexOf('a:remove'), lessThan(events.indexOf('a:dispose:0')));
    await t.pumpWidget(const SizedBox());
    expect(b.disposals, 1);
    expect(events.indexOf('b:remove'), lessThan(events.indexOf('b:dispose:0')));
    await t.pump(); // A pending post-frame callback must not dispose twice.
    expect([a.disposals, b.disposals], [1, 1]);
  });

  testWidgets('unchanged identity and service events do not notify the scope', (
    t,
  ) async {
    final update = TrackedAppUpdate('root', []);
    addTearDown(update.dispose);
    var builds = 0;
    final child = Builder(
      builder: (context) {
        AppServicesScope.of(context);
        builds++;
        return const SizedBox();
      },
    );
    Future<void> mount() => t.pumpWidget(
      AppServicesHost(services: AppServices.withUpdates(update), child: child),
    );
    await mount();
    expect(builds, 1);
    await mount();
    update.publish();
    await t.pump();
    expect(builds, 1);
    await t.pumpWidget(const SizedBox());
  });
}
