import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/features/public_translation.dart';
import 'package:raft_flutter/main.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/platform/desktop_title_bar.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_global_server_selector_test.dart' show RootFixture, RootClient;

const _localeKey = 'slock.displayLanguage';
const _public = '/public/servers/raft-design';

class _PublicApp {
  _PublicApp({this.translation = true}) {
    f.adapter.routes['GET $_public'] = (_) => {
      'server': {
        'id': 'public',
        'name': 'Raft Design',
        'slug': 'raft-design',
        'translationEnabled': translation,
      },
      'translationAvailable': translation,
      'channels': <Object>[],
      'canJoinAsGuest': true,
    };
  }
  final bool translation;
  final f = RootFixture();
  Future<void> mount(WidgetTester t) async {
    await t.pumpWidget(
      RaftApp(
        key: UniqueKey(),
        services: AppServices.updatesDisabledForTestOrPreview(
          localNetwork: f.network,
        ),
        sessionStore: f.sessions,
        initialLocation: Uri(path: '/s/raft-design'),
        nativeContent: f.content,
        nativeSharing: NativeSharing(supported: false),
        openWorkspaceCache: () async => f.cache,
        createClient: (origin, store, kind) =>
            f.client = RootClient(origin, store, kind, f.adapter),
      ),
    );
    await t.pumpAndSettle();
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });
  }

  List<String> get calls => [
    for (final o in f.adapter.calls) '${o.method} ${o.path}',
  ];
}

Future<void> _open(WidgetTester t, String tab) async {
  final narrow = t.view.physicalSize;
  // Web and Flutter both hide the public rail below md. The Linux journey
  // opens settings in a wider window, then retains the page when resized.
  if (narrow.width < 768) {
    t.view.physicalSize = Size(1280, narrow.height);
    await t.pumpAndSettle();
  }
  await t.tap(find.byKey(const ValueKey('public-rail-settings')));
  await t.pumpAndSettle();
  final navigation = find.byKey(ValueKey('workspace-settings-nav-$tab'));
  expect(navigation, findsOneWidget);
  await t.tap(navigation);
  await t.pumpAndSettle();
  t.view.physicalSize = narrow;
  await t.pumpAndSettle();
}

Future<void> _chat(WidgetTester t) async {
  final narrow = t.view.physicalSize;
  if (narrow.width < 768) {
    t.view.physicalSize = Size(1280, narrow.height);
    await t.pumpAndSettle();
  }
  await t.tap(find.byKey(const ValueKey('rail-chat')));
  await t.pumpAndSettle();
  t.view.physicalSize = narrow;
  await t.pumpAndSettle();
}

MaterialApp _app(WidgetTester t) => t.widget(find.byType(MaterialApp));

void main() {
  // The desktop controller is a process owner, shared by every app restart.
  tearDownAll(() => DesktopTitleBarController.platform.state.dispose());
  setUp(() {
    DevicePreferences.reset();
    SharedPreferences.setMockInitialValues({
      'raft.origin': 'https://fixture.invalid',
    });
  });
  tearDown(DevicePreferences.reset);

  for (final size in [
    const Size(1280, 900),
    const Size(390, 844),
    const Size(856, 944),
    const Size(944, 856),
  ]) {
    testWidgets(
      'anonymous Appearance $size changes mode, reopens and survives app restart without account requests',
      (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final first = _PublicApp(translation: false);
        await first.mount(t);
        await _open(t, 'appearance');
        expect(find.byType(RaftAppearanceModeCards), findsOneWidget);
        for (final mode in [
          ThemeMode.dark,
          ThemeMode.light,
          ThemeMode.system,
          ThemeMode.dark,
        ]) {
          final card = find.byKey(ValueKey('appearance-theme-${mode.name}'));
          await t.ensureVisible(card);
          await t.pumpAndSettle();
          expect(card.hitTestable(), findsOneWidget);
          await t.tap(card);
          await t.pumpAndSettle();
          expect(_app(t).themeMode, mode);
        }
        expect(
          (await SharedPreferences.getInstance()).getString('raft.mode'),
          'dark',
        );
        await _chat(t);
        await t.pumpAndSettle();
        await _open(t, 'appearance');
        expect(
          t
              .widget<RaftAppearanceModeCards>(
                find.byType(RaftAppearanceModeCards),
              )
              .appearance
              .mode,
          ThemeMode.dark,
        );
        await t.pumpWidget(const SizedBox());
        final disk = await SharedPreferences.getInstance();
        SharedPreferences.setMockInitialValues({
          for (final key in disk.getKeys()) key: disk.get(key)!,
        });
        DevicePreferences.reset();
        final restarted = _PublicApp(translation: false);
        await restarted.mount(t);
        expect(_app(t).themeMode, ThemeMode.dark);
        await _open(t, 'appearance');
        expect(
          find.text('Language & Region'),
          findsNothing,
          reason: 'The upstream translation gate still applies.',
        );
        expect(
          [
            ...first.calls,
            ...restarted.calls,
          ].where((c) => c.contains('/auth/')),
          isEmpty,
        );
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        size.width < 640 || size.width > 1000
            ? TargetPlatform.linux
            : TargetPlatform.android,
      }),
    );

    testWidgets(
      'anonymous UI language $size is a Save draft and stays separate from translation preferences on reopen and restart',
      (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final oldTranslation = {
          'preferredLanguage': 'ja',
          'preferredTranslationMode': 'manual',
          'preferredTranslationDisplay': 'original',
          'preferredTimezone': 'Asia/Tokyo',
          'preferredTimeFormat': '24h',
        };
        SharedPreferences.setMockInitialValues({
          'raft.origin': 'https://fixture.invalid',
          'raft.mode': 'dark',
          'raft.theme': 'elegant',
          publicTranslationPreferencesKey: jsonEncode(oldTranslation),
        });
        final first = _PublicApp();
        await first.mount(t);
        await _open(t, 'language-region');
        var view = t.widget<RaftLanguageRegionView>(
          find.byType(RaftLanguageRegionView),
        );
        expect(view.displayLanguageOptions, [
          ('en', 'English'),
          ('zh-cn', '简体中文'),
        ]);
        expect(view.languageDirty, isFalse);
        expect(view.languageSave, RaftLanguageSaveState.idle);
        // Use the actual select and Save controls, not the view callbacks.
        await t.tap(find.byKey(const ValueKey('display-language-select')));
        await t.pumpAndSettle();
        await t.tap(find.text('简体中文').last);
        await t.pumpAndSettle();
        expect(
          _app(t).locale,
          const Locale('en'),
          reason: 'Only Save applies a UI language draft.',
        );
        final save = find.byKey(const ValueKey('language-save'));
        await t.ensureVisible(save);
        await t.pumpAndSettle();
        expect(save.hitTestable(), findsOneWidget);
        await t.tap(save);
        await t.pumpAndSettle();
        expect(_app(t).locale, const Locale('zh', 'CN'));
        final p = await SharedPreferences.getInstance();
        expect(p.getString(_localeKey), 'zh-cn');
        expect(
          jsonDecode(p.getString(publicTranslationPreferencesKey)!),
          oldTranslation,
        );
        expect(p.getString('raft.theme'), 'elegant');
        expect(p.getString('raft.mode'), 'dark');
        await _chat(t);
        await t.pumpAndSettle();
        await _open(t, 'language-region');
        view = t.widget<RaftLanguageRegionView>(
          find.byType(RaftLanguageRegionView),
        );
        expect(view.displayLanguage, 'zh-cn');
        expect(
          view.languageSave,
          RaftLanguageSaveState.idle,
          reason: 'No saved notice when reopened.',
        );
        expect(view.languageDirty, isFalse);
        await t.pumpWidget(const SizedBox());
        final disk = await SharedPreferences.getInstance();
        SharedPreferences.setMockInitialValues({
          for (final key in disk.getKeys()) key: disk.get(key)!,
        });
        DevicePreferences.reset();
        final restarted = _PublicApp();
        await restarted.mount(t);
        expect(_app(t).locale, const Locale('zh', 'CN'));
        await _open(t, 'language-region');
        view = t.widget<RaftLanguageRegionView>(
          find.byType(RaftLanguageRegionView),
        );
        expect(view.displayLanguage, 'zh-cn');
        expect(view.translationTarget, 'ja');
        expect(view.translationDisplay, 'original');
        expect(view.languageSave, RaftLanguageSaveState.idle);
        expect(
          [
            ...first.calls,
            ...restarted.calls,
          ].where((c) => c.contains('/auth/')),
          isEmpty,
        );
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        size.width < 640 || size.width > 1000
            ? TargetPlatform.linux
            : TargetPlatform.android,
      }),
    );
  }

  for (final (principal, language) in [('alice', 'en'), ('bob', 'zh-cn')]) {
    testWidgets(
      'signed-in $principal keeps its own language over an opposite anonymous choice',
      (t) async {
        final f = RootFixture();
        f.overrides['GET /auth/me'] = (_) => {
          'id': principal,
          'name': principal,
          'email': '$principal@example.invalid',
          'emailVerified': true,
          'displayLanguage': language,
        };
        final anonymous = language == 'en' ? 'zh-cn' : 'en';
        await f.mount(
          t,
          'light',
          1280,
          principal: principal,
          preferences: {_localeKey: anonymous},
        );
        addTearDown(() async {
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
        });
        expect(
          _app(t).locale,
          language == 'en' ? const Locale('en') : const Locale('zh', 'CN'),
        );
        expect(
          (await SharedPreferences.getInstance()).getString(_localeKey),
          anonymous,
        );
        expect(f.client.user!.string('displayLanguage'), language);
        expect(
          f.adapter.calls.where(
            (o) => o.method == 'PATCH' && o.path == '/auth/me',
          ),
          isEmpty,
        );
      },
    );
  }

  testWidgets(
    'an unset account language keeps the local fallback without automatic account writeback',
    (t) async {
      final f = RootFixture();
      await f.mount(t, 'light', 1280, preferences: {_localeKey: 'zh-cn'});
      addTearDown(() async {
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      });
      expect(_app(t).locale, const Locale('zh', 'CN'));
      expect(f.client.user!.json['displayLanguage'], isNull);
      expect(
        f.adapter.calls.where(
          (o) => o.method == 'PATCH' && o.path == '/auth/me',
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'preloaded anonymous UI language is present on the first app frame',
    (t) async {
      SharedPreferences.setMockInitialValues({_localeKey: 'zh-cn'});
      await t.runAsync(DevicePreferences.load);
      final f = _PublicApp();
      addTearDown(() async {
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      });
      await t.pumpWidget(
        RaftApp(
          services: AppServices.updatesDisabledForTestOrPreview(
            localNetwork: f.f.network,
          ),
          sessionStore: MemorySessionStore(),
          nativeContent: f.f.content,
          nativeSharing: NativeSharing(supported: false),
          openWorkspaceCache: () async => f.f.cache,
          createClient: (o, s, k) => RootClient(o, s, k, f.f.adapter),
        ),
      );
      expect(_app(t).locale, const Locale('zh', 'CN'));
      await t.pumpAndSettle();
    },
  );
}
