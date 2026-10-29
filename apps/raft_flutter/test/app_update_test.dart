import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/platform/app_update.dart';

class _Memory implements SearchMemoryStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

Map<String, Object?> _row({
  String platform = 'android',
  String arch = 'arm64',
  Object? build = '37',
  String version = '0.1.0',
  String tag = 'v0.1.0+5',
  String artifact = 'raft-flutter-0.1.0+5-android-arm64.apk',
}) => {
  'platform': platform,
  'arch': arch,
  'version': version,
  'buildNumber': build,
  'releaseTag': tag,
  'commit': 'abc',
  'artifact': artifact,
  'sha256': 'x',
  'bytes': 1,
};

String _manifest([List<Object?>? rows]) => jsonEncode(rows ?? [_row()]);

void main() {
  group('AppImage update inputs', () {
    final sha = 'ab' * 32;
    test('the manifest checksum and size reach the release, normalised', () {
      final release = parseBuildManifest(
        _manifest([
          _row(platform: 'appimage', arch: 'x64')
            ..['sha256'] = sha.toUpperCase()
            ..['bytes'] = 124684792,
        ]),
        'appimage-x64',
      )!;
      expect(release.sha256, sha);
      expect(release.bytes, 124684792);
      // They survive the remembered copy used between runs.
      expect(AppRelease.fromJson(release.toJson()), release);
    });

    test('the manifest signature reaches the release and survives the remembered copy', () {
      final signature = 'Qm9ndXM${'A' * 79}==';
      final release = parseBuildManifest(
        _manifest([
          _row(platform: 'appimage', arch: 'x64')..['edSignature'] = signature,
        ]),
        'appimage-x64',
      )!;
      expect(release.edSignature, signature);
      expect(AppRelease.fromJson(release.toJson()), release);
      expect(AppRelease.fromJson(release.toJson())!.edSignature, signature);
    });

    test('a missing or malformed signature leaves the field empty, not the release', () {
      for (final bad in [
        null,
        '',
        'x',
        'A' * 86,
        'A' * 88,
        '${'A' * 85}!==',
        5,
      ]) {
        final row = _row(platform: 'appimage', arch: 'x64')
          ..['edSignature'] = bad;
        final release = parseBuildManifest(_manifest([row]), 'appimage-x64')!;
        expect(release.edSignature, isEmpty, reason: '$bad');
        expect(release.toJson(), isNot(contains('edSignature')));
      }
    });

    test(
      'a manifest without a usable checksum still parses, with empty fields',
      () {
        for (final bad in [null, 'x', 'ab' * 31, 5]) {
          final row = _row(platform: 'appimage', arch: 'x64')
            ..['sha256'] = bad
            ..['bytes'] = bad;
          final release = parseBuildManifest(_manifest([row]), 'appimage-x64')!;
          expect(release.sha256, isEmpty, reason: '$bad');
          expect(release.bytes, bad == 5 ? 5 : 0);
        }
      },
    );

    test('RAFT_UPDATE_ORIGIN is honoured by test builds only', () {
      const env = {'RAFT_UPDATE_ORIGIN': 'http://127.0.0.1:8099'};
      expect(
        updateOriginOverride(
          environment: env,
          releaseBuild: false,
          isolatedSuffix: '',
        ),
        Uri.parse('http://127.0.0.1:8099'),
      );
      expect(
        updateOriginOverride(
          environment: env,
          releaseBuild: true,
          isolatedSuffix: '.isolated',
        ),
        Uri.parse('http://127.0.0.1:8099'),
      );
      // The official release build never moves its feed.
      expect(
        updateOriginOverride(
          environment: env,
          releaseBuild: true,
          isolatedSuffix: '',
        ),
        isNull,
      );
      for (final bad in [
        '',
        'ftp://x',
        'http://',
        'http://h/?q=1',
        'not a url',
        'http://h/#f',
      ]) {
        expect(
          updateOriginOverride(
            environment: {'RAFT_UPDATE_ORIGIN': bad},
            releaseBuild: false,
            isolatedSuffix: '',
          ),
          isNull,
          reason: bad,
        );
      }
      expect(
        updateOriginOverride(
          environment: const {},
          releaseBuild: false,
          isolatedSuffix: '',
        ),
        isNull,
      );
    });

    test('the override moves the manifest URL', () {
      final service = AppUpdateService.forThisBuild(
        version: '0.1.0',
        buildNumber: '5',
        platformKey: 'appimage-x64',
        fetch: (_) async => null,
        storage: _Memory(),
        origin: Uri.parse('http://127.0.0.1:8099/'),
      );
      addTearDown(service.dispose);
      expect(
        service.manifestUrl.toString(),
        'http://127.0.0.1:8099/kevinzhow/raft-flutter/releases/latest/download/build-manifest-appimage-x64.json',
      );
      final official = AppUpdateService.forThisBuild(
        version: '0.1.0',
        buildNumber: '5',
        platformKey: 'appimage-x64',
        fetch: (_) async => null,
        storage: _Memory(),
      );
      addTearDown(official.dispose);
      expect(
        official.manifestUrl.toString(),
        '${AppUpdateService.manifestBase}/build-manifest-appimage-x64.json',
      );
    });
  });

  group('parseBuildManifest', () {
    test('reads the array entry for the platform', () {
      final release = parseBuildManifest(_manifest(), 'android-arm64')!;
      expect(release.version, '0.1.0');
      expect(release.buildNumber, 37);
      expect(release.releaseTag, 'v0.1.0+5');
      expect(release.artifact, 'raft-flutter-0.1.0+5-android-arm64.apk');
      expect(
        release.releasePage.toString(),
        'https://github.com/kevinzhow/raft-flutter/releases/tag/v0.1.0+5',
      );
      expect(
        release.downloadUrl.toString(),
        'https://github.com/kevinzhow/raft-flutter/releases/download/v0.1.0+5/'
        'raft-flutter-0.1.0+5-android-arm64.apk',
      );
    });

    test('accepts numeric build numbers and a single object', () {
      expect(
        parseBuildManifest(
          jsonEncode(_row(build: 41)),
          'android-arm64',
        )!.buildNumber,
        41,
      );
    });

    test('takes the highest build and ignores other platforms', () {
      final release = parseBuildManifest(
        _manifest([
          _row(build: '30'),
          _row(platform: 'macos', arch: 'arm64', build: '99'),
          _row(build: '38'),
        ]),
        'android-arm64',
      )!;
      expect(release.buildNumber, 38);
      expect(parseBuildManifest(_manifest(), 'windows-x64'), isNull);
    });

    test('rejects missing, malformed and unsafe fields', () {
      for (final bad in [
        _row(build: null),
        _row(build: 'abc'),
        _row(build: '0'),
        _row(version: ''),
        _row(tag: 'nightly'),
        _row(tag: 'v1/../x'),
        _row(artifact: 'a/b.apk'),
        _row(artifact: ''),
      ]) {
        expect(
          parseBuildManifest(_manifest([bad]), 'android-arm64'),
          isNull,
          reason: '$bad',
        );
      }
      final noArtifact = _row()..remove('artifact');
      expect(
        parseBuildManifest(_manifest([noArtifact]), 'android-arm64'),
        isNull,
      );
    });

    test('bad JSON and wrong shapes are null', () {
      for (final body in [
        '',
        'not json',
        '{',
        '[1, "a", null]',
        'null',
        '"x"',
      ]) {
        expect(parseBuildManifest(body, 'android-arm64'), isNull, reason: body);
      }
    });
  });

  // Proof against the real latest release; never runs in the normal suite.
  //   RAFT_LIVE_MANIFEST=1 flutter test test/app_update_test.dart --plain-name live
  test(
    'live: real manifests parse for every platform',
    () async {
      HttpOverrides.global = null; // flutter_test answers every request 400
      for (final key in [
        'android-arm64',
        'macos-arm64',
        'windows-x64',
        'appimage-x64',
      ]) {
        final body = await fetchManifestOverHttp(
          Uri.parse(
            '${AppUpdateService.manifestBase}/build-manifest-$key.json',
          ),
        );
        final release = parseBuildManifest(body!, key)!;
        // ignore: avoid_print
        print(
          'live $key -> ${release.version} (${release.buildNumber}) '
          '${release.releaseTag} ${release.artifact}',
        );
        expect(release.buildNumber, greaterThan(0));
      }
      expect(
        await fetchManifestOverHttp(
          Uri.parse('${AppUpdateService.manifestBase}/no-such-file.json'),
        ),
        isNull,
      );
    },
    skip: Platform.environment['RAFT_LIVE_MANIFEST'] == null
        ? 'set RAFT_LIVE_MANIFEST=1'
        : false,
  );

  group('appUpdatePlatformKey', () {
    test('maps the distributed platforms', () {
      String? key(TargetPlatform p, [Map<String, String> env = const {}]) =>
          appUpdatePlatformKey(web: false, target: p, environment: env);
      expect(key(TargetPlatform.android), 'android-arm64');
      expect(key(TargetPlatform.macOS), 'macos-arm64');
      expect(key(TargetPlatform.windows), 'windows-x64');
      expect(
        key(TargetPlatform.linux, {'APPIMAGE': '/x.AppImage'}),
        'appimage-x64',
      );
    });

    test('skips iOS, web and Linux outside an AppImage', () {
      expect(
        appUpdatePlatformKey(web: false, target: TargetPlatform.iOS),
        isNull,
      );
      expect(
        appUpdatePlatformKey(web: true, target: TargetPlatform.android),
        isNull,
      );
      expect(
        appUpdatePlatformKey(
          web: false,
          target: TargetPlatform.linux,
          environment: {},
        ),
        isNull,
      );
      expect(
        appUpdatePlatformKey(
          web: false,
          target: TargetPlatform.linux,
          environment: {'APPIMAGE': ''},
        ),
        isNull,
      );
    });
  });

  group('AppUpdateService', () {
    late _Memory storage;
    late DateTime now;
    late List<Uri> requests;
    late List<String> logs;
    Future<String?> Function(Uri) fetcher = (_) async => _manifest();

    AppUpdateService make({
      String version = '0.1.0',
      int? build = 20,
      String? platform = 'android-arm64',
      TargetPlatform? target,
    }) => AppUpdateService(
      currentVersion: version,
      currentBuild: build,
      platformKey: platform,
      target: target,
      fetch: (url) {
        requests.add(url);
        return fetcher(url);
      },
      storage: storage,
      clock: () => now,
      scheduleTimer: false,
      log: logs.add,
    );

    setUp(() {
      storage = _Memory();
      now = DateTime(2026, 10, 13, 9);
      requests = [];
      logs = [];
      fetcher = (_) async => _manifest();
    });

    test('newer remote build is available and unseen', () async {
      final service = make();
      await service.start();
      expect(
        requests.single.toString(),
        'https://github.com/kevinzhow/raft-flutter/releases/latest/download/'
        'build-manifest-android-arm64.json',
      );
      expect(service.available!.buildNumber, 37);
      expect(service.hasUnseen, isTrue);
    });

    test('same or older remote build is not an update', () async {
      for (final build in [37, 38, 2037]) {
        final service = make(build: build);
        await service.start();
        expect(service.available, isNull, reason: '$build');
        expect(service.hasUnseen, isFalse);
      }
    });

    test('markSeen clears the dot until a newer build arrives', () async {
      final service = make();
      await service.start();
      var notified = 0;
      service.addListener(() => notified++);
      service.markSeen();
      expect(service.hasUnseen, isFalse);
      expect(service.available, isNotNull);
      expect(notified, 1);
      service.markSeen();
      expect(notified, 1);

      now = now.add(const Duration(hours: 7));
      fetcher = (_) async => _manifest([_row(build: '38', tag: 'v0.1.0+6')]);
      await service.checkIfDue();
      expect(service.available!.buildNumber, 38);
      expect(service.hasUnseen, isTrue);
    });

    test('seen state and last release survive a restart', () async {
      final first = make();
      await first.start();
      first.markSeen();
      await Future<void>.delayed(Duration.zero);

      fetcher = (_) async => throw StateError('offline');
      requests.clear();
      final second = make();
      await second.start();
      // Within 6 h: no request, remembered release, still seen.
      expect(requests, isEmpty);
      expect(second.available!.buildNumber, 37);
      expect(second.hasUnseen, isFalse);
    });

    test('throttles to one request per interval', () async {
      final service = make();
      await service.start();
      await service.checkIfDue();
      now = now.add(const Duration(hours: 5, minutes: 59));
      await service.checkIfDue();
      expect(requests, hasLength(1));
      now = now.add(const Duration(minutes: 2));
      await service.checkIfDue();
      expect(requests, hasLength(2));
    });

    test('a clock set back counts as due', () async {
      final service = make();
      await service.start();
      now = now.subtract(const Duration(days: 1));
      await service.checkIfDue();
      expect(requests, hasLength(2));
    });

    test('skip rules make no request', () async {
      for (final service in [
        make(version: '0.1.0-dev.abc1234'),
        make(version: '0.1.0-dev.abc1234.dirty'),
        make(build: null),
        make(build: 0),
        make(version: ''),
        make(platform: null),
      ]) {
        await service.start();
        await service.checkIfDue();
        expect(service.enabled, isFalse);
        expect(service.available, isNull);
        expect(service.hasUnseen, isFalse);
      }
      expect(requests, isEmpty);
    });

    test('forThisBuild without defines is disabled', () {
      final service = AppUpdateService.forThisBuild(
        platformKey: 'android-arm64',
        fetch: (_) async => _manifest(),
        storage: storage,
      );
      expect(service.enabled, isFalse);
    });

    test('failures are silent, logged once, and retried sooner', () async {
      fetcher = (_) async => throw StateError('offline');
      final service = make();
      var notified = 0;
      service.addListener(() => notified++);
      await service.start();
      expect(service.available, isNull);
      expect(service.hasUnseen, isFalse);
      // Checking on, then failed: the card needs both, the dot neither.
      expect(notified, 2);
      expect(service.status, AppUpdateStatus.failed);
      expect(logs, hasLength(1));

      now = now.add(const Duration(minutes: 10));
      await service.checkIfDue();
      expect(requests, hasLength(1));
      now = now.add(const Duration(minutes: 21));
      await service.checkIfDue();
      expect(requests, hasLength(2));
      expect(logs, hasLength(1), reason: 'logged once per run');

      fetcher = (_) async => _manifest();
      now = now.add(const Duration(minutes: 31));
      await service.checkIfDue();
      expect(service.hasUnseen, isTrue);
    });

    test('404 and unusable manifests keep what was known', () async {
      final service = make();
      await service.start();
      for (final body in [
        null,
        'garbage',
        _manifest([_row(build: 'x')]),
      ]) {
        now = now.add(const Duration(hours: 7));
        fetcher = (_) async => body;
        await service.checkIfDue();
        expect(service.available!.buildNumber, 37);
      }
      expect(logs, isEmpty);
    });

    test(
      'checkNow ignores the throttle, taps during a check are ignored',
      () async {
        final service = make();
        await service.start();
        expect(requests, hasLength(1));
        now = now.add(const Duration(minutes: 1));
        await service.checkIfDue();
        expect(requests, hasLength(1), reason: 'throttled');
        await service.checkNow();
        expect(requests, hasLength(2), reason: 'forced');

        final gate = Completer<String?>();
        fetcher = (_) => gate.future;
        final first = service.checkNow();
        await Future<void>.delayed(Duration.zero);
        expect(service.status, AppUpdateStatus.checking);
        await service.checkNow();
        await service.checkIfDue();
        expect(requests, hasLength(3), reason: 'one request while checking');
        gate.complete(_manifest());
        await first;
        expect(service.status, AppUpdateStatus.available);
      },
    );

    test(
      'status: idle, up to date with a time, available, unsupported',
      () async {
        final service = make(build: 99);
        expect(service.status, AppUpdateStatus.idle);
        expect(service.lastChecked, isNull);
        await service.start();
        expect(service.status, AppUpdateStatus.upToDate);
        expect(service.lastChecked, now);
        expect(service.failure, isNull);
        expect(make().unsupported, isNull);
        final newer = make();
        await newer.start();
        expect(newer.status, AppUpdateStatus.available);
        expect(make(build: null).status, AppUpdateStatus.unsupported);
      },
    );

    test(
      'a failure is kept until the next successful check clears it',
      () async {
        final service = make(build: 99);
        await service.start();
        fetcher = (_) async => throw StateError('offline');
        await service.checkNow();
        expect(service.status, AppUpdateStatus.failed);
        expect(service.failure, isA<StateError>());
        // The last good check time is not overwritten by the failure.
        expect(service.lastChecked, now);
        now = now.add(const Duration(minutes: 2));
        fetcher = (_) async => _manifest();
        await service.checkNow();
        expect(service.failure, isNull);
        expect(service.status, AppUpdateStatus.upToDate);
        expect(service.lastChecked, now);
      },
    );

    test(
      'a failure with a known newer release still shows the release',
      () async {
        final service = make();
        await service.start();
        fetcher = (_) async => throw StateError('offline');
        await service.checkNow();
        expect(service.status, AppUpdateStatus.available);
        expect(service.failure, isA<StateError>());
      },
    );

    test('unsupported explains why', () {
      expect(
        make(platform: null, target: TargetPlatform.iOS).unsupported,
        AppUpdateUnsupported.ios,
      );
      expect(
        make(platform: null, target: TargetPlatform.linux).unsupported,
        AppUpdateUnsupported.linuxPackage,
      );
      expect(
        make(platform: null, target: TargetPlatform.fuchsia).unsupported,
        AppUpdateUnsupported.platform,
      );
      expect(make(build: null).unsupported, AppUpdateUnsupported.development);
      expect(
        make(version: '0.1.0-dev').unsupported,
        AppUpdateUnsupported.development,
      );
    });

    test('checkNow makes no request for an unsupported build', () async {
      final service = make(platform: null, target: TargetPlatform.iOS);
      await service.checkNow();
      expect(requests, isEmpty);
      expect(service.status, AppUpdateStatus.unsupported);
    });

    test('corrupt stored state behaves like a first run', () async {
      storage.values[AppUpdateService.storageKey] = '{broken';
      final service = make();
      await service.start();
      expect(service.hasUnseen, isTrue);
    });
  });
}
