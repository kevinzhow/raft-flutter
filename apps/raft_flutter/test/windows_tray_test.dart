import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/windows_tray_settings.dart';
import 'package:raft_flutter/platform/windows_tray.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/tray-preference');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late WindowsTray tray;
  var enabled = true, fail = false;
  Completer<Map<String, dynamic>>? pending;
  final calls = <MethodCall>[];
  setUp(() {
    enabled = true;
    fail = false;
    pending = null;
    calls.clear();
    tray = WindowsTray(
      platform: TargetPlatform.windows,
      channel: channel,
      lab: true,
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'setCloseToTray') {
        if (fail) throw PlatformException(code: 'tray-preference-failed');
        enabled = (call.arguments as Map)['enabled'] == true;
      }
      return pending?.future ?? {'available': true, 'closeToTray': enabled};
    });
  });
  tearDown(() async {
    pending = null;
    await tray.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });
  test(
    'localized configuration is deduplicated and copy changes are applied',
    () async {
      await tray.initialize((s) => 'translated $s');
      await tray.configure((s) => 'translated $s');
      expect(calls.where((c) => c.method == 'configure'), hasLength(1));
      expect((calls.first.arguments as Map)['lab'], true);
      expect((calls.first.arguments as Map)['quit'], 'translated Quit Raft');
      await tray.configure((s) => s);
      expect(calls.where((c) => c.method == 'configure'), hasLength(2));
    },
  );
  test('unsupported hosts do not touch the native tray', () async {
    final unsupported = WindowsTray(
      platform: TargetPlatform.android,
      channel: channel,
    );
    await unsupported.initialize((s) => s);
    expect((await unsupported.readState()).available, false);
    await unsupported.dispose();
    expect(calls, isEmpty);
  });
  for (final throws in [false, true]) {
    test(
      'unchanged labels do not retry an unavailable shell (throws=$throws)',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (throws) throw MissingPluginException('No tray available');
          return {'available': false};
        });
        await tray.initialize((s) => s);
        await tray.configure((s) => s);
        await tray.configure((s) => s);
        expect(calls.where((c) => c.method == 'configure'), hasLength(1));
        await tray.configure((s) => 'translated $s');
        expect(calls.where((c) => c.method == 'configure'), hasLength(2));
      },
    );
  }
  test(
    'pending native configuration is deduplicated before it completes',
    () async {
      pending = Completer<Map<String, dynamic>>();
      final initialization = tray.initialize((s) => s);
      final duplicate = tray.configure((s) => s);
      await Future<void>.delayed(Duration.zero);
      expect(calls.where((c) => c.method == 'configure'), hasLength(1));
      pending!.complete({'available': true});
      pending = null;
      await Future.wait([initialization, duplicate]);
    },
  );
  for (final (dark) in [(false), (true)]) {
    testWidgets(
      'preference readback, pending save, error and retry dark=$dark',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: SingleChildScrollView(
                child: WindowsTraySettings(tray: tray),
              ),
            ),
          ),
        );
        await t.pump();
        final toggle = find.byKey(const ValueKey('windows-close-to-tray'));
        expect(t.widget<RaftSwitch>(toggle).value, true);
        pending = Completer<Map<String, dynamic>>();
        await t.tap(toggle);
        await t.pump();
        expect(t.widget<RaftSwitch>(toggle).onChanged, isNull);
        pending!.complete({'available': true, 'closeToTray': false});
        pending = null;
        await t.pump();
        expect(t.widget<RaftSwitch>(toggle).value, false);
        fail = true;
        await t.tap(toggle);
        await t.pump();
        await t.pump();
        expect(find.byType(RaftErrorBanner), findsOneWidget);
        expect(t.widget<RaftSwitch>(toggle).value, false);
        fail = false;
        await t.tap(find.text('Retry'));
        await t.pump();
        await t.pump();
        expect(find.byType(RaftErrorBanner), findsNothing);
        expect(t.widget<RaftSwitch>(toggle).value, false);
        expect(calls.where((c) => c.method == 'setCloseToTray'), hasLength(2));
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'native unavailable read, retry, keyboard and 3.1x narrow layout',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final semantics = t.ensureSemantics();
      pending = Completer<Map<String, dynamic>>();
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(3.1)),
            child: RaftTextScaling(child: child!),
          ),
          home: Scaffold(
            body: SingleChildScrollView(child: WindowsTraySettings(tray: tray)),
          ),
        ),
      );
      final toggle = find.byKey(const ValueKey('windows-close-to-tray'));
      expect(t.widget<RaftSwitch>(toggle).onChanged, isNull);
      pending!.complete({'available': false});
      pending = null;
      await t.pump();
      expect(find.byType(RaftErrorBanner), findsOneWidget);
      await t.ensureVisible(find.text('Retry'));
      await t.tap(find.text('Retry'));
      await t.pump();
      await t.pump();
      expect(find.byType(RaftErrorBanner), findsNothing);
      expect(
        t.getSemantics(toggle).label,
        'Keep Raft running when the window closes',
      );
      await t.ensureVisible(toggle);
      await t.tap(toggle);
      await t.pump();
      await t.pump();
      expect(enabled, false);
      // Saving temporarily disables the switch, so establish keyboard focus
      // again after the native readback before testing its activation action.
      t
          .widget<FocusableActionDetector>(
            find.descendant(
              of: toggle,
              matching: find.byType(FocusableActionDetector),
            ),
          )
          .focusNode!
          .requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pump();
      await t.pump();
      expect(enabled, true);
      expect(t.widget<RaftSwitch>(toggle).value, true);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    },
  );
}
