import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/features/workspace_settings.dart';
import 'package:raft_flutter/platform/app_update.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_updater/raft_updater.dart';

import '../../../packages/raft_ui/test/task_typography_test.dart'
    show loadTaskFonts;
import 'workspace_source_location_contract_test.dart' show pageFixture;
import 'flutter_test_config.dart' show leakDebt;

class _Memory implements SearchMemoryStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// An [AppUpdater] whose native side is replaced by a scripted outcome.
class _FakeUpdater implements AppUpdater {
  _FakeUpdater({bool available = true, this.outcome = AppUpdateOutcome.started})
    : _availability = ValueNotifier<bool>(available) {
    addTearDown(_availability.dispose);
  }

  final ValueNotifier<bool> _availability;
  AppUpdateOutcome outcome;
  int calls = 0;

  @override
  bool get available => _availability.value;
  @override
  ValueListenable<bool> get availability => _availability;
  @override
  String? get unavailableReason => null;
  @override
  String get feedUrl => '';

  @override
  Future<AppUpdateOutcome> checkAndInstall() async {
    calls++;
    return outcome;
  }

  /// Linux AppImage updater; null elsewhere.
  _FakeAppImage? image;
  @override
  AppImageUpdater? get appImage => image;
  @override
  void configureAppImage({
    required AppImageHttpClientFactory httpClientFactory,
    Uri? origin,
  }) {}

  @override
  Future<void> Function()? beforeQuit;

  @override
  Future<void> Function() performRequiredExit = () async {};

  @override
  Future<void> quitAfterHook() async {
    final hook = beforeQuit;
    if (hook != null) {
      try {
        await hook();
      } on Object {
        // The required exit still proceeds.
      }
    }
    await performRequiredExit();
  }
}

/// An [AppImageUpdater] whose steps are scripted; only what the card calls.
class _FakeAppImage extends AppImageUpdater {
  _FakeAppImage()
    : super(
        path: '/tmp/Raft.AppImage',
        information: AppImageUpdateInformation.parse(
          AppImageUpdateInformation.official,
        )!,
        http: AppImageHttp((_) async => throw UnimplementedError()),
        publicKey: '',
      );

  final notifier = ValueNotifier<AppImageUpdateStatus>(
    const AppImageUpdateStatus.idle(),
  );
  final installed = <AppImageRelease>[];
  int restarts = 0, cancels = 0, resets = 0;
  bool restartWorks = true;

  @override
  ValueListenable<AppImageUpdateStatus> get status => notifier;
  @override
  Future<void> install(AppImageRelease release) async => installed.add(release);
  @override
  Future<bool> restart() async {
    restarts++;
    return restartWorks;
  }

  @override
  void cancel() => cancels++;
  @override
  void reset() {
    resets++;
    notifier.value = const AppImageUpdateStatus.idle();
  }
}

AppUpdateService _service(String platform, {bool checksum = false}) =>
    AppUpdateService(
      currentVersion: '0.1.0',
      currentBuild: 20,
      platformKey: platform,
      storage: _Memory(),
      scheduleTimer: false,
      fetch: (_) async => jsonEncode([
        {
          'platform': platform.split('-').first,
          'arch': platform.split('-').last,
          'version': '0.1.0',
          'buildNumber': '37',
          'releaseTag': 'v0.1.0+5',
          'artifact': 'raft-flutter-0.1.0+5-$platform.zip',
          if (checksum) 'sha256': 'ab' * 32,
          if (checksum) 'bytes': 124586488,
          if (checksum) 'edSignature': '${'A' * 86}==',
        },
      ]),
    );

Future<List<String>> _mount(
  WidgetTester t,
  AppUpdateService service,
  AppUpdater? updater,
  TargetPlatform platform, {
  bool start = true,
  Size size = const Size(1000, 900),
  bool dark = false,
}) async {
  final launched = <String>[];
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/url_launcher'),
    (call) async {
      if (call.method == 'launch') {
        launched.add((call.arguments as Map)['url'] as String);
      }
      return true;
    },
  );
  addTearDown(
    () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      null,
    ),
  );
  final (w, _) = await pageFixture(t, section: 'chat');
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  if (start) await t.runAsync(service.start);
  await t.pumpWidget(
    RepaintBoundary(
      key: _shotKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: raftTheme(dark: dark).copyWith(platform: platform),
        home: Scaffold(
          body: SingleChildScrollView(
            child: WorkspaceAboutSection(
              controller: w,
              appUpdate: service,
              updater: updater,
              showMobileApp: false,
            ),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return launched;
}

final _shotKey = GlobalKey();
final _action = find.byKey(const ValueKey('settings-about-update-action'));

void main() {
  // Leak debt (other): see docs/development.md, Leak tracking.
  leakDebt(const ['ValueNotifier<AppImageUpdateStatus>', 'ValueNotifier<bool>']);
  group('Linux AppImage in-place update', () {
    Future<(AppUpdateService, _FakeUpdater, _FakeAppImage, List<String>)> mount(
      WidgetTester t,
    ) async {
      final service = _service('appimage-x64', checksum: true);
      addTearDown(service.dispose);
      final image = _FakeAppImage();
      final updater = _FakeUpdater()..image = image;
      final launched = await _mount(t, service, updater, TargetPlatform.linux);
      return (service, updater, image, launched);
    }

    testWidgets(
      'Update now installs the release with its checksum and signature',
      (t) async {
        final (_, _, image, launched) = await mount(t);
        expect(find.text('Update Now'), findsOneWidget);
        expect(find.text('View Release'), findsNothing);
        await t.tap(_action);
        await t.pumpAndSettle();
        expect(image.installed, hasLength(1));
        expect(image.installed.single.tag, 'v0.1.0+5');
        expect(image.installed.single.sha256, 'ab' * 32);
        expect(image.installed.single.bytes, 124586488);
        expect(image.installed.single.edSignature, '${'A' * 86}==');
        expect(launched, isEmpty);
        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets('shows progress per stage and Cancel', (t) async {
      final (_, _, image, _) = await mount(t);
      image.notifier.value = const AppImageUpdateStatus.running(
        AppImageUpdateStage.downloading,
        0.5,
      );
      await t.pump();
      expect(find.text('Updating to 0.1.0 (37)'), findsOneWidget);
      expect(find.text('Downloading the changes… 50%'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('settings-about-update-progress')),
        findsOneWidget,
      );
      // No second update and no recheck while one runs.
      expect(find.text('Check for Updates'), findsOneWidget);
      expect(
        t
            .widget<RaftButton>(
              find.byKey(const ValueKey('settings-about-update-check')),
            )
            .onPressed,
        isNull,
      );
      await t.tap(_action);
      expect(find.text('Cancel'), findsOneWidget);
      expect(image.cancels, 1);
      for (final (stage, text) in [
        (AppImageUpdateStage.preparing, 'Comparing with your current version…'),
        (AppImageUpdateStage.verifying, 'Verifying the update…'),
        (AppImageUpdateStage.installing, 'Installing the update…'),
      ]) {
        image.notifier.value = AppImageUpdateStatus.running(stage, 0.95);
        await t.pump();
        expect(find.text(text), findsOneWidget);
      }
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('offers Restart to finish and says when restarting failed', (
      t,
    ) async {
      final (_, _, image, _) = await mount(t);
      image.notifier.value = const AppImageUpdateStatus.ready();
      await t.pump();
      expect(find.text('Raft 0.1.0 (37) is installed'), findsOneWidget);
      expect(find.text('Restart Raft to finish updating.'), findsOneWidget);
      image.restartWorks = false;
      await t.tap(_action);
      await t.pumpAndSettle();
      expect(image.restarts, 1);
      expect(
        find.text(
          "Raft couldn't restart itself. Quit it and start it again to finish updating.",
        ),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets(
      'a failure names its cause and falls back to the release page',
      (t) async {
        final (_, _, image, launched) = await mount(t);
        image.notifier.value = const AppImageUpdateStatus.failed(
          AppImageUpdateFailure(
            AppImageUpdateFailureKind.notWritable,
            '/opt/apps',
          ),
        );
        await t.pump();
        expect(find.text("Couldn't install the update"), findsOneWidget);
        expect(
          find.text(
            "Raft can't write to /opt/apps. Move the AppImage to a folder you own, or download the update from the release page.",
          ),
          findsOneWidget,
        );
        await t.tap(_action);
        await t.pumpAndSettle();
        expect(launched, [
          'https://github.com/kevinzhow/raft-flutter/releases/tag/v0.1.0+5',
        ]);
        // Check for updates clears the failure so Update now is offered again.
        await t.tap(find.byKey(const ValueKey('settings-about-update-check')));
        await t.pumpAndSettle();
        expect(image.resets, 1);
        expect(find.text('Update Now'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets('every failure kind has a specific sentence', (t) async {
      final (_, _, image, _) = await mount(t);
      final seen = <String>{};
      for (final kind in AppImageUpdateFailureKind.values) {
        image.notifier.value = AppImageUpdateStatus.failed(
          AppImageUpdateFailure(kind, 'x'),
        );
        await t.pump();
        final text = t
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data ?? '')
            .where((d) => d.contains(' ') && d.length > 40)
            .toList();
        expect(text, isNotEmpty, reason: '$kind');
        seen.addAll(text);
      }
      expect(
        seen.length,
        greaterThanOrEqualTo(AppImageUpdateFailureKind.values.length),
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets(
      'without an in-place updater (not an AppImage) it stays View release',
      (t) async {
        final service = _service('appimage-x64', checksum: true);
        addTearDown(service.dispose);
        final launched = await _mount(
          t,
          service,
          _FakeUpdater(available: false),
          TargetPlatform.linux,
        );
        expect(find.text('View Release'), findsOneWidget);
        expect(find.text('Update Now'), findsNothing);
        await t.tap(_action);
        await t.pumpAndSettle();
        expect(launched, [
          'https://github.com/kevinzhow/raft-flutter/releases/tag/v0.1.0+5',
        ]);
        await t.pumpWidget(const SizedBox());
      },
    );
  });

  for (final (platform, key) in [
    (TargetPlatform.macOS, 'macos-arm64'),
    (TargetPlatform.windows, 'windows-x64'),
  ]) {
    group('$platform with an in-place updater', () {
      testWidgets('reads Update now and starts the native updater', (t) async {
        final service = _service(key);
        addTearDown(service.dispose);
        final updater = _FakeUpdater();
        final launched = await _mount(t, service, updater, platform);
        expect(find.text('Update Now'), findsOneWidget);
        expect(find.text('View Release'), findsNothing);
        await t.tap(_action);
        await t.pumpAndSettle();
        expect(updater.calls, 1);
        // Sparkle/WinSparkle show their own dialog: nothing else opens.
        expect(launched, isEmpty);
        await t.pumpWidget(const SizedBox());
      });

      testWidgets('openedReleasePage is not opened a second time', (t) async {
        final service = _service(key);
        addTearDown(service.dispose);
        final updater = _FakeUpdater(
          outcome: AppUpdateOutcome.openedReleasePage,
        );
        final launched = await _mount(t, service, updater, platform);
        await t.tap(_action);
        await t.pumpAndSettle();
        expect(updater.calls, 1);
        expect(launched, isEmpty);
        await t.pumpWidget(const SizedBox());
      });

      testWidgets('failed falls back to the release page', (t) async {
        final service = _service(key);
        addTearDown(service.dispose);
        final updater = _FakeUpdater(outcome: AppUpdateOutcome.failed);
        final launched = await _mount(t, service, updater, platform);
        await t.tap(_action);
        await t.pumpAndSettle();
        expect(updater.calls, 1);
        expect(launched, [
          'https://github.com/kevinzhow/raft-flutter/releases/tag/v0.1.0+5',
        ]);
        await t.pumpWidget(const SizedBox());
      });

      testWidgets('falls back to View release once updating is disabled', (
        t,
      ) async {
        final service = _service(key);
        addTearDown(service.dispose);
        final updater = _FakeUpdater();
        await _mount(t, service, updater, platform);
        expect(find.text('Update Now'), findsOneWidget);
        updater._availability.value = false;
        await t.pumpAndSettle();
        expect(find.text('Update Now'), findsNothing);
        expect(find.text('View Release'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
      });
    });

    testWidgets('$platform without an in-place updater keeps View release', (
      t,
    ) async {
      final service = _service(key);
      addTearDown(service.dispose);
      final updater = _FakeUpdater(available: false);
      final launched = await _mount(t, service, updater, platform);
      expect(find.text('View Release'), findsOneWidget);
      expect(find.text('Update Now'), findsNothing);
      await t.tap(_action);
      await t.pumpAndSettle();
      expect(updater.calls, 0);
      expect(launched, [
        'https://github.com/kevinzhow/raft-flutter/releases/tag/v0.1.0+5',
      ]);
      await t.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Android ignores the updater and downloads the APK', (t) async {
    final service = _service('android-arm64');
    addTearDown(service.dispose);
    final updater = _FakeUpdater();
    final launched = await _mount(t, service, updater, TargetPlatform.android);
    expect(find.text('Download Update'), findsOneWidget);
    expect(find.text('Update Now'), findsNothing);
    await t.tap(_action);
    await t.pumpAndSettle();
    expect(updater.calls, 0);
    expect(launched, [
      'https://github.com/kevinzhow/raft-flutter/releases/download/v0.1.0+5/raft-flutter-0.1.0+5-android-arm64.zip',
    ]);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Linux AppImage ignores the updater and views the release', (
    t,
  ) async {
    final service = _service('appimage-x64');
    addTearDown(service.dispose);
    final updater = _FakeUpdater();
    final launched = await _mount(t, service, updater, TargetPlatform.linux);
    expect(find.text('View Release'), findsOneWidget);
    expect(find.text('Update Now'), findsNothing);
    await t.tap(_action);
    await t.pumpAndSettle();
    expect(updater.calls, 0);
    expect(launched, [
      'https://github.com/kevinzhow/raft-flutter/releases/tag/v0.1.0+5',
    ]);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('up to date: no update action, even when updatable', (t) async {
    final service = AppUpdateService(
      currentVersion: '0.1.0',
      currentBuild: 99,
      platformKey: 'macos-arm64',
      storage: _Memory(),
      scheduleTimer: false,
      fetch: (_) async => '[]',
    );
    addTearDown(service.dispose);
    await _mount(t, service, _FakeUpdater(), TargetPlatform.macOS);
    expect(find.text('Update Now'), findsNothing);
    expect(_action, findsNothing);
    expect(find.text("You're on the latest version"), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  _updatesCardTests();
  _screenshots();
}

final _check = find.byKey(const ValueKey('settings-about-update-check'));
final _card = find.byKey(const ValueKey('settings-about-update'));

/// A service whose fetch is scripted; [fetches] counts requests.
class _Script {
  _Script({
    this.platform = 'android-arm64',
    int build = 20,
    TargetPlatform? target,
    String version = '0.1.0',
  }) {
    service = AppUpdateService(
      currentVersion: version,
      currentBuild: build,
      platformKey: platform,
      target: target,
      storage: _Memory(),
      scheduleTimer: false,
      clock: () => at ?? DateTime.now(),
      log: (_) {},
      fetch: (_) {
        fetches++;
        return next();
      },
    );
  }
  final String? platform;
  late final AppUpdateService service;

  /// Pins the service clock; null follows the wall clock (the card does).
  DateTime? at;
  int fetches = 0;
  late Future<String?> Function() next = () async => body(build: 37);

  String body({required int build}) => jsonEncode([
    {
      'platform': platform!.split('-').first,
      'arch': platform!.split('-').last,
      'version': '0.1.0',
      'buildNumber': '$build',
      'releaseTag': 'v0.1.0+5',
      'artifact': 'raft-flutter-0.1.0+5-$platform.zip',
    },
  ]);
}

void _updatesCardTests() {
  group('Updates card', () {
    // (name, platform, manifest key, updater available)
    final supported = <(String, TargetPlatform, String, bool?)>[
      ('android', TargetPlatform.android, 'android-arm64', null),
      ('macOS with updater', TargetPlatform.macOS, 'macos-arm64', true),
      ('macOS without updater', TargetPlatform.macOS, 'macos-arm64', false),
      ('windows with updater', TargetPlatform.windows, 'windows-x64', true),
      ('windows without updater', TargetPlatform.windows, 'windows-x64', false),
      ('linux AppImage', TargetPlatform.linux, 'appimage-x64', null),
    ];
    for (final (name, platform, key, updatable) in supported) {
      group(name, () {
        _FakeUpdater? updater() =>
            updatable == null ? null : _FakeUpdater(available: updatable);

        testWidgets('up to date: message, last checked, check button', (
          t,
        ) async {
          final s = _Script(platform: key, build: 99);
          addTearDown(s.service.dispose);
          final fake = updater();
          await _mount(t, s.service, fake, platform);
          expect(_card, findsOneWidget);
          expect(find.text("You're on the latest version"), findsOneWidget);
          expect(find.text('Last checked: this minute'), findsOneWidget);
          expect(_check, findsOneWidget);
          expect(find.text('Check for Updates'), findsOneWidget);
          expect(_action, findsNothing);
          await t.pumpWidget(const SizedBox());
        });

        testWidgets('Check for updates forces a check inside the throttle', (
          t,
        ) async {
          final s = _Script(platform: key, build: 99);
          addTearDown(s.service.dispose);
          final fake = updater();
          await _mount(t, s.service, fake, platform);
          expect(s.fetches, 1);
          await t.runAsync(s.service.checkIfDue);
          expect(s.fetches, 1, reason: 'the 6 h throttle holds');
          await t.tap(_check);
          await t.pump();
          await t.runAsync(() => Future<void>.delayed(Duration.zero));
          await t.pump();
          expect(s.fetches, 2);
          expect(find.text('Last checked: this minute'), findsOneWidget);
          // The native updater is never asked: no second dialog.
          expect(fake?.calls ?? 0, 0);
          await t.pumpWidget(const SizedBox());
        });

        testWidgets('a found release brings the action; check stays', (
          t,
        ) async {
          final s = _Script(platform: key, build: 20);
          addTearDown(s.service.dispose);
          await _mount(t, s.service, updater(), platform);
          expect(find.textContaining('New version available'), findsOneWidget);
          expect(_action, findsOneWidget);
          expect(_check, findsOneWidget);
          expect(find.byType(RaftAttentionDot), findsOneWidget);
          await t.pumpWidget(const SizedBox());
        });

        testWidgets('checking shows a spinner and disables the button', (
          t,
        ) async {
          final s = _Script(platform: key, build: 99);
          addTearDown(s.service.dispose);
          final gate = Completer<String?>();
          s.next = () => gate.future;
          await _mount(t, s.service, updater(), platform, start: false);
          unawaited(s.service.start());
          await t.pump();
          await t.pump();
          expect(find.text('Checking for updates…'), findsOneWidget);
          expect(find.byType(RaftSpinner), findsOneWidget);
          expect(t.widget<RaftButton>(_check).onPressed, isNull);
          expect(s.fetches, 1);
          gate.complete(s.body(build: 1));
          await t.pump();
          await t.pump();
          expect(find.text("You're on the latest version"), findsOneWidget);
          expect(find.byType(RaftSpinner), findsNothing);
          await t.pumpWidget(const SizedBox());
        });

        testWidgets('failure shows a short reason, success clears it', (
          t,
        ) async {
          final s = _Script(platform: key, build: 99);
          addTearDown(s.service.dispose);
          s.next = () async => throw StateError('socket: 10.0.0.1 refused');
          await _mount(t, s.service, updater(), platform);
          expect(find.text("Couldn't check for updates"), findsOneWidget);
          expect(
            find.text('Check your connection and try again.'),
            findsOneWidget,
          );
          // Never the raw exception text.
          expect(find.textContaining('socket'), findsNothing);
          expect(find.textContaining('StateError'), findsNothing);
          expect(find.text('Last checked: this minute'), findsNothing);
          expect(_check, findsOneWidget);

          s.next = () async => s.body(build: 1);
          await t.tap(_check);
          await t.pump();
          await t.runAsync(() => Future<void>.delayed(Duration.zero));
          await t.pump();
          expect(find.text("Couldn't check for updates"), findsNothing);
          expect(
            find.text('Check your connection and try again.'),
            findsNothing,
          );
          expect(find.text("You're on the latest version"), findsOneWidget);
          await t.pumpWidget(const SizedBox());
        });
      });
    }

    testWidgets('last checked renders the elapsed time', (t) async {
      final old = _Script(build: 99);
      addTearDown(old.service.dispose);
      old.at = DateTime.now().subtract(const Duration(hours: 3));
      await _mount(t, old.service, null, TargetPlatform.android);
      expect(find.text('Last checked: 3 hours ago'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    for (final (name, platform, script, reason) in [
      (
        'iOS',
        TargetPlatform.iOS,
        () => _Script(platform: null, target: TargetPlatform.iOS),
        "iOS builds aren't distributed through GitHub releases.",
      ),
      (
        'dev build',
        TargetPlatform.android,
        () => _Script(platform: 'android-arm64', build: 0),
        'This is a development build without a CI build number.',
      ),
      (
        'Linux outside an AppImage',
        TargetPlatform.linux,
        () => _Script(platform: null, target: TargetPlatform.linux),
        'Only the AppImage build can check for updates.',
      ),
    ]) {
      testWidgets('$name: unsupported with a reason and no button', (t) async {
        final s = script();
        addTearDown(s.service.dispose);
        await _mount(t, s.service, _FakeUpdater(), platform);
        expect(_card, findsOneWidget);
        expect(
          find.text("Update checks aren't available for this build"),
          findsOneWidget,
        );
        expect(find.text(reason), findsOneWidget);
        expect(_check, findsNothing);
        expect(_action, findsNothing);
        expect(s.fetches, 0);
        await t.pumpWidget(const SizedBox());
      });
    }

    testWidgets('no card without a service', (t) async {
      final (w, _) = await pageFixture(t, section: 'chat');
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(body: WorkspaceAboutSection(controller: w)),
        ),
      );
      await t.pumpAndSettle();
      expect(_card, findsNothing);
      await t.pumpWidget(const SizedBox());
    });
  });
}

/// Evidence renders of every Updates state, written only when
/// RAFT_UPDATE_SHOTS_DIR is set (otherwise a no-op).
void _screenshots() {
  final dir = Platform.environment['RAFT_UPDATE_SHOTS_DIR'];
  if (dir == null) return;

  Future<void> shot(WidgetTester t, String name) async {
    await t.runAsync(() async {
      final boundary =
          _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$dir/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  final cases =
      <
        (
          String,
          TargetPlatform,
          _Script Function(),
          AppUpdater? Function(),
          String?,
        )
      >[
        (
          'up-to-date-android',
          TargetPlatform.android,
          () => _Script(build: 99)..at = _ago(const Duration(hours: 3)),
          () => null,
          null,
        ),
        (
          'up-to-date-macos',
          TargetPlatform.macOS,
          () =>
              _Script(platform: 'macos-arm64', build: 99)
                ..at = _ago(const Duration(minutes: 1)),
          () => _FakeUpdater(),
          null,
        ),
        (
          'available-android',
          TargetPlatform.android,
          () => _Script(),
          () => null,
          null,
        ),
        (
          'available-macos-update-now',
          TargetPlatform.macOS,
          () => _Script(platform: 'macos-arm64'),
          () => _FakeUpdater(),
          null,
        ),
        (
          'available-windows-view-release',
          TargetPlatform.windows,
          () => _Script(platform: 'windows-x64'),
          () => _FakeUpdater(available: false),
          null,
        ),
        (
          'failed',
          TargetPlatform.android,
          () =>
              _Script(build: 99)
                ..next = () async => throw StateError('socket refused'),
          () => null,
          null,
        ),
        (
          'unsupported-ios',
          TargetPlatform.iOS,
          () => _Script(platform: null, target: TargetPlatform.iOS),
          () => null,
          null,
        ),
        (
          'unsupported-dev-build',
          TargetPlatform.macOS,
          () => _Script(platform: 'macos-arm64', build: 0),
          () => _FakeUpdater(),
          null,
        ),
        (
          'unsupported-linux-package',
          TargetPlatform.linux,
          () => _Script(platform: null, target: TargetPlatform.linux),
          () => null,
          null,
        ),
      ];

  for (final (dark, suffix) in [(false, 'light'), (true, 'dark')]) {
    for (final (name, platform, script, updater, _) in cases) {
      testWidgets('screenshot $name $suffix', (t) async {
        await loadTaskFonts(t);
        final s = script();
        addTearDown(s.service.dispose);
        await _mount(
          t,
          s.service,
          updater(),
          platform,
          size: const Size(520, 360),
          dark: dark,
        );
        await shot(t, '$name-$suffix');
        await t.pumpWidget(const SizedBox());
      });
    }
    testWidgets('screenshot checking $suffix', (t) async {
      await loadTaskFonts(t);
      final s = _Script(build: 99);
      addTearDown(s.service.dispose);
      s.next = () => Completer<String?>().future;
      await _mount(
        t,
        s.service,
        null,
        TargetPlatform.android,
        start: false,
        size: const Size(520, 360),
        dark: dark,
      );
      unawaited(s.service.start());
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      await shot(t, 'checking-$suffix');
      await t.pumpWidget(const SizedBox());
    });
  }
}

DateTime _ago(Duration d) => DateTime.now().subtract(d);
