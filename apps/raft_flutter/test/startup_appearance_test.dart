import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/main.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_global_server_selector_test.dart';

/// Whether a built theme carries the dark tokens.
bool _isDark(ThemeData theme) => theme.extension<RaftTokens>()!.dark;

class _PendingSessionStore extends MemorySessionStore {
  final pending = Completer<Session?>();
  @override
  Future<Session?> read(String origin) => pending.future;
}

Future<MaterialApp> _firstBuilt(
  WidgetTester t,
  Map<String, Object> stored, {
  required bool preload,
  SessionStore? sessions,
}) async {
  SharedPreferences.setMockInitialValues(stored);
  DevicePreferences.reset();
  if (preload) await t.runAsync(DevicePreferences.load);
  addTearDown(DevicePreferences.reset);
  final f = RootFixture();
  // One pump: no awaited startup work (restore) has run yet, so this is
  // exactly the tree the first frame would paint.
  await t.pumpWidget(
    RaftApp(
      services: const AppServices.updatesDisabledForTestOrPreview(),
      sessionStore: sessions ?? f.sessions,
      nativeContent: f.content,
      nativeSharing: NativeSharing(supported: false),
      openWorkspaceCache: () async => f.cache,
      createClient: (origin, store, kind) =>
          f.client = RootClient(origin, store, kind, f.adapter),
    ),
  );
  return t.widget<MaterialApp>(find.byType(MaterialApp));
}

void main() {
  testWidgets(
    'device glyph locale remains independent of English UI and updates live',
    (t) async {
      final sessions = _PendingSessionStore();
      // Traditional Chinese is not a shipped UI translation, but its regional
      // glyph preference must survive the English UI fallback.
      t.platformDispatcher.localeTestValue = const Locale('zh', 'TW');
      addTearDown(t.platformDispatcher.clearLocaleTestValue);
      final app = await _firstBuilt(t, {}, preload: true, sessions: sessions);
      expect(app.locale, const Locale('en'));
      expect(app.theme!.textTheme.bodyMedium!.locale, const Locale('zh', 'TW'));
      expect(
        app.darkTheme!.textTheme.bodyMedium!.locale,
        const Locale('zh', 'TW'),
      );
      t.platformDispatcher.localeTestValue = const Locale('ja', 'JP');
      await t.pump();
      final updated = t.widget<MaterialApp>(find.byType(MaterialApp));
      expect(updated.locale, const Locale('en'));
      expect(
        updated.theme!.textTheme.bodyMedium!.locale,
        const Locale('ja', 'JP'),
      );
      await t.pumpWidget(const SizedBox());
      sessions.pending.complete(null);
      await t.pump();
    },
  );

  testWidgets('the first built MaterialApp uses the stored mode', (t) async {
    final app = await _firstBuilt(t, {'raft.mode': 'dark'}, preload: true);
    expect(app.themeMode, ThemeMode.dark);
    expect(_isDark(app.theme!), isFalse);
    expect(_isDark(app.darkTheme!), isTrue);
  });

  testWidgets('first build without stored values follows the system', (
    t,
  ) async {
    final app = await _firstBuilt(t, {}, preload: true);
    expect(app.themeMode, ThemeMode.system);
    expect(_isDark(app.theme!), isFalse);
    expect(_isDark(app.darkTheme!), isTrue);
  });

  testWidgets('an unknown stored value falls back to System', (t) async {
    final app = await _firstBuilt(t, {
      'raft.mode': 'retired-mode',
    }, preload: true);
    expect(app.themeMode, ThemeMode.system);
  });

  // Brutal and Elegant are the one Raft look now; `raft.mode` already said
  // Light, Dark or System.
  for (final family in ['brutal', 'elegant', 'retired-family']) {
    testWidgets('the retired theme family "$family" changes nothing', (
      t,
    ) async {
      final app = await _firstBuilt(t, {
        'raft.mode': 'light',
        'raft.light': family,
      }, preload: true);
      expect(app.themeMode, ThemeMode.light);
      expect(_isDark(app.theme!), isFalse);
    });
  }

  test('stored appearance values migrate to Light / Dark / System', () {
    // The retired theme ids map by their brightness; System follows the platform.
    for (final (stored, mode) in [
      ('light', ThemeMode.light),
      ('dark', ThemeMode.dark),
      ('system', ThemeMode.system),
      ('brutal', ThemeMode.light),
      ('elegantLight', ThemeMode.light),
      ('elegantDark', ThemeMode.dark),
    ]) {
      expect(storedThemeMode(stored), mode, reason: stored);
    }
    expect(storedThemeMode('elegant'), isNull);
    expect(storedThemeMode(null), isNull);
  });

  test(
    'storedAppearance reads the theme id independently of the mode',
    () async {
      // The theme and the mode are separate choices stored under separate keys:
      // picking Elegant must not disturb Light/Dark/System, and vice versa.
      SharedPreferences.setMockInitialValues({
        'raft.mode': 'dark',
        'raft.theme': 'brutal',
      });
      final p = await SharedPreferences.getInstance();
      final stored = storedAppearance(p);
      expect(stored.themeId, 'brutal');
      expect(stored.mode, ThemeMode.dark);

      // No stored theme means the default look, not an empty id.
      SharedPreferences.setMockInitialValues({'raft.mode': 'light'});
      expect(
        storedAppearance(await SharedPreferences.getInstance()).themeId,
        raftThemePackId,
      );

      // An id naming no built-in theme is preserved as written: the user's
      // choice is not silently rewritten, it is resolved to the fallback look
      // when painted.
      SharedPreferences.setMockInitialValues({'raft.theme': 'my-own-pack'});
      expect(
        storedAppearance(await SharedPreferences.getInstance()).themeId,
        'my-own-pack',
      );
    },
  );

  test('choosing a theme persists it without touching the mode', () async {
    // The theme id gets its own key, so setting one never rewrites the other.
    // Painting is covered by packages/raft_ui/test/appearance_theme_test.dart,
    // which can assert on tokens without booting the whole app.
    SharedPreferences.setMockInitialValues({'raft.mode': 'light'});
    final p = await SharedPreferences.getInstance();

    const chosen = RaftAppearance(
      mode: ThemeMode.light,
      themeId: brutalThemePackId,
    );
    await p.setString('raft.mode', chosen.mode.name);
    await p.setString(appearanceThemeKey, chosen.themeId);

    expect(p.getString(appearanceThemeKey), brutalThemePackId);
    expect(p.getString('raft.mode'), 'light');
    // And it round-trips through the reader the first frame uses.
    expect(storedAppearance(p).themeId, brutalThemePackId);
    expect(storedAppearance(p).mode, ThemeMode.light);
  });

  test('storedAppearance reads the mode synchronously', () async {
    SharedPreferences.setMockInitialValues({
      'raft.mode': 'light',
      'raft.light': 'elegant',
    });
    final p = await SharedPreferences.getInstance();
    expect(storedAppearance(p).mode, ThemeMode.light);
    SharedPreferences.setMockInitialValues({'raft.mode': 'elegantDark'});
    expect(
      storedAppearance(await SharedPreferences.getInstance()).mode,
      ThemeMode.dark,
    );
    DevicePreferences.reset();
    expect(storedAppearance().mode, ThemeMode.system);
  });

  test('the retired family key is dropped once', () async {
    SharedPreferences.setMockInitialValues({
      'raft.mode': 'dark',
      'raft.light': 'elegant',
    });
    final p = await SharedPreferences.getInstance();
    await retireStoredAppearanceTheme(p);
    expect(p.containsKey(retiredAppearanceThemeKey), isFalse);
    expect(p.getString('raft.mode'), 'dark');
    await retireStoredAppearanceTheme(p);
    expect(p.getString('raft.mode'), 'dark');
  });
}
