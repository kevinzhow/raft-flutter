import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/workspace_settings.dart';
import 'package:raft_flutter/platform/app_update.dart';
import 'package:raft_flutter/platform/client_release_notes.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show leakDebt;
import 'support/memory_storage.dart';
import 'workspace_source_location_contract_test.dart' show pageFixture;

/// The update prompt is the Updates card in Settings > About (the only place
/// that says a newer release exists besides the red dots that lead to it). It
/// shows what the offered release changes before the user updates.

const _sizes = [Size(412, 915), Size(1280, 800)];
String _note(String tag, String text, {String state = 'published'}) =>
    jsonEncode({
      'releaseId': tag,
      'tag': tag,
      'version': '0.1.0',
      'date': '2026-10-14',
      'state': state,
      'entries': [
        {'type': 'feature', 'text': text, 'emphasis': false},
      ],
    });

String _page(List<(String, String)> notes) => jsonEncode({
  'items': [for (final (tag, text) in notes) jsonDecode(_note(tag, text))],
  'nextCursor': null,
});

/// What GitHub holds: five builds of 0.1.0, newest first.
final _all = _page([
  ('v0.1.0+9', 'Nine notes'),
  ('v0.1.0+8', 'Eight notes'),
  ('v0.1.0+7', 'Seven notes'),
  ('v0.1.0+6', 'Six notes'),
  ('v0.1.0+5', 'Five notes'),
]);

class _Notes {
  _Notes([this.respond]);
  Future<String?> Function()? respond;
  final requests = <Uri>[];
  Future<String?> fetch(Uri url) {
    requests.add(url);
    return (respond ?? () async => _all)();
  }
}

AppUpdateService _service(
  _Notes notes, {
  String offered = 'v0.1.0+9',
  String installed = 'v0.1.0+5',
}) => AppUpdateService(
  currentVersion: '0.1.0',
  currentBuild: 20,
  currentTag: installed,
  platformKey: 'android-arm64',
  storage: MemoryStorage(),
  scheduleTimer: false,
  releaseNotes: ClientReleaseNotes(
    storage: MemoryStorage(),
    appBuild: 20,
    fetch: notes.fetch,
  ),
  fetch: (_) async => jsonEncode([
    {
      'platform': 'android',
      'arch': 'arm64',
      'version': '0.1.0',
      'buildNumber': '37',
      'releaseTag': offered,
      'artifact': 'raft-flutter-0.1.0+9-android-arm64.apk',
    },
  ]),
);

Future<List<String>> _mount(
  WidgetTester t,
  AppUpdateService service, {
  Size size = const Size(412, 915),
  Locale? locale,
}) async {
  final launched = <String>[];
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
    call,
  ) async {
    if (call.method == 'launch') {
      launched.add((call.arguments as Map)['url'] as String);
    }
    return true;
  });
  addTearDown(
    () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    ),
  );
  final (w, _) = await pageFixture(t, section: 'chat');
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.runAsync(service.start);
  await t.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: raftTheme().copyWith(platform: TargetPlatform.android),
      home: Scaffold(
        body: SingleChildScrollView(
          child: WorkspaceAboutSection(
            controller: w,
            appUpdate: service,
            showMobileApp: false,
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return launched;
}

final _action = find.byKey(const ValueKey('settings-about-update-action'));
final _toggle = find.byKey(
  const ValueKey('settings-about-update-notes-toggle'),
);
final _retry = find.byKey(const ValueKey('settings-about-update-notes-retry'));

double _top(WidgetTester t, String text) => t.getTopLeft(find.text(text)).dy;

void main() {
  leakDebt(const ['ValueNotifier<bool>']);
  for (final size in _sizes) {
    final on = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('$on: the offered version in full, older skipped versions '
        'behind one toggle, newest first', (t) async {
      final notes = _Notes();
      final service = _service(notes);
      addTearDown(service.dispose);
      await _mount(t, service, size: size);
      expect(find.text("What's new in this update"), findsOneWidget);
      // Collapsed: the newest only, and the row says how many are folded.
      expect(find.text('Nine notes'), findsOneWidget);
      for (final text in ['Eight notes', 'Seven notes', 'Six notes']) {
        expect(find.text(text), findsNothing, reason: text);
      }
      expect(_toggle, findsOneWidget);
      expect(find.text('3 More Updates'), findsOneWidget);
      // The notes come before the buttons: readable before updating.
      expect(_top(t, 'Nine notes'), lessThan(t.getTopLeft(_action).dy));
      await t.ensureVisible(_toggle);
      await t.tap(_toggle);
      await t.pumpAndSettle();
      for (final text in [
        'Nine notes',
        'Eight notes',
        'Seven notes',
        'Six notes',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      // The installed version's own notes are never listed.
      expect(find.text('Five notes'), findsNothing);
      final order = [
        for (final text in [
          'Nine notes',
          'Eight notes',
          'Seven notes',
          'Six notes',
        ])
          _top(t, text),
      ];
      expect(order, orderedEquals([...order]..sort()));
      expect(_top(t, 'Six notes'), lessThan(t.getTopLeft(_action).dy));
      expect(find.text('Show Fewer'), findsOneWidget);
      await t.tap(_toggle);
      await t.pumpAndSettle();
      expect(find.text('Eight notes'), findsNothing);
      expect(find.text('3 More Updates'), findsOneWidget);
      expect(notes.requests, hasLength(1));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('$on: one version has no toggle', (t) async {
      final notes = _Notes();
      final service = _service(notes, installed: 'v0.1.0+8');
      addTearDown(service.dispose);
      await _mount(t, service, size: size);
      expect(find.text('Nine notes'), findsOneWidget);
      expect(find.text('Eight notes'), findsNothing);
      expect(_toggle, findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('$on: while loading the update stays available; a '
        'failure keeps it and offers a retry', (t) async {
      final gate = Completer<String?>();
      final notes = _Notes(() => gate.future);
      final service = _service(notes);
      addTearDown(service.dispose);
      final launched = await _mount(t, service, size: size);
      expect(find.text('Loading what\'s new…'), findsOneWidget);
      expect(_action, findsOneWidget);
      gate.completeError(StateError('offline'));
      await t.pumpAndSettle();
      expect(find.text('Loading what\'s new…'), findsNothing);
      expect(find.text('Couldn\'t load what\'s new.'), findsOneWidget);
      expect(_retry, findsOneWidget);
      // A failed read never blocks the update.
      await t.tap(_action);
      await t.pumpAndSettle();
      expect(launched, hasLength(1));
      notes.respond = () async => _all;
      await t.ensureVisible(_retry);
      await t.tap(_retry);
      await t.pumpAndSettle();
      expect(find.text('Nine notes'), findsOneWidget);
      expect(_retry, findsNothing);
      expect(notes.requests, hasLength(2));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('$on: a release without notes says so', (t) async {
      final notes = _Notes(() async => _page([('v0.1.0+5', 'Five notes')]));
      final service = _service(notes);
      addTearDown(service.dispose);
      await _mount(t, service, size: size);
      expect(find.text('No release notes for this update.'), findsOneWidget);
      expect(find.text('Five notes'), findsNothing);
      expect(_action, findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }

  testWidgets('rebuilds and a repeated check do not refetch the notes', (
    t,
  ) async {
    final notes = _Notes();
    final service = _service(notes);
    addTearDown(service.dispose);
    await _mount(t, service);
    expect(notes.requests, hasLength(1));
    t.view.physicalSize = const Size(600, 915);
    await t.pumpAndSettle();
    await t.runAsync(service.checkNow);
    await t.pumpAndSettle();
    expect(find.text('Nine notes'), findsOneWidget);
    expect(notes.requests, hasLength(1));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the toggle speaks Chinese and counts one older version', (
    t,
  ) async {
    final notes = _Notes();
    final service = _service(notes);
    addTearDown(service.dispose);
    await _mount(t, service, locale: const Locale('zh'));
    expect(find.text('还有 3 个版本的更新'), findsOneWidget);
    await t.ensureVisible(_toggle);
    await t.tap(_toggle);
    await t.pumpAndSettle();
    expect(find.text('收起'), findsOneWidget);
    expect(find.text('Eight notes'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('two versions say "1 More Update" in both languages', (t) async {
    for (final (locale, text) in [
      (const Locale('en'), '1 More Update'),
      (const Locale('zh'), '还有 1 个版本的更新'),
    ]) {
      final service = _service(_Notes(), installed: 'v0.1.0+7');
      addTearDown(service.dispose);
      await _mount(t, service, locale: locale);
      expect(find.text(text), findsOneWidget, reason: '$locale');
      await t.pumpWidget(const SizedBox());
    }
  });
}
