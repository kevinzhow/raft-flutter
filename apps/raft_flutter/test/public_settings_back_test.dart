import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/features/public_server_view.dart';
import 'package:raft_flutter/main.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/platform/desktop_title_bar.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_global_server_selector_test.dart' show RootClient, RootFixture;

class _PublicApp {
  final f = RootFixture();
  Future<void> mount(WidgetTester t) async {
    f.adapter.routes['GET /public/servers/raft-design'] = (_) => {
      'server': {
        'id': 'public',
        'slug': 'raft-design',
        'name': 'Raft Design',
        'translationEnabled': true,
      },
      'translationAvailable': true,
      'channels': <Object>[],
      'canJoinAsGuest': true,
    };
    await t.pumpWidget(
      RaftApp(
        key: UniqueKey(),
        initialLocation: Uri(path: '/s/raft-design'),
        services: AppServices.updatesDisabledForTestOrPreview(
          localNetwork: f.network,
        ),
        sessionStore: f.sessions,
        nativeContent: f.content,
        nativeSharing: NativeSharing(supported: false),
        openWorkspaceCache: () async => f.cache,
        createClient: (origin, store, kind) =>
            f.client = RootClient(origin, store, kind, f.adapter),
      ),
    );
    await t.pumpAndSettle();
  }
}

Future<void> _settings(WidgetTester t, String tab) async {
  t.view.physicalSize = const Size(1280, 844);
  await t.pumpAndSettle();
  await t.tap(find.byKey(const ValueKey('public-rail-settings')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(ValueKey('workspace-settings-nav-$tab')));
  await t.pumpAndSettle();
}

Future<void> _resize(WidgetTester t, double width) async {
  t.view.physicalSize = Size(width, 844);
  await t.pumpAndSettle();
}

void main() {
  final back = find.byKey(const ValueKey('public-settings-back'));
  setUp(() {
    DevicePreferences.reset();
    SharedPreferences.setMockInitialValues({
      'raft.origin': 'https://fixture.invalid',
      'slock.displayLanguage': 'en',
    });
  });
  tearDown(DevicePreferences.reset);
  tearDownAll(() => DesktopTitleBarController.platform.state.dispose());

  Future<void> cleanup(WidgetTester t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(1280, 844);
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      t.view.reset();
    });
  }

  testWidgets(
    'public Settings resize Back returns through the real Root and keeps Appearance',
    (t) async {
      await cleanup(t);
      final app = _PublicApp();
      await app.mount(t);
      await _settings(t, 'appearance');
      await t.tap(find.byKey(const ValueKey('appearance-theme-dark')));
      await t.pumpAndSettle();
      expect(back.hitTestable(), findsNothing);
      await _resize(t, 768);
      expect(back.hitTestable(), findsNothing);
      await _resize(t, 767);
      expect(back.hitTestable(), findsOneWidget);
      await _resize(t, 390);
      expect(back.hitTestable(), findsOneWidget);
      await t.tap(back);
      await t.pumpAndSettle();
      expect(find.byType(PublicServerView), findsNothing);
      expect(find.byType(AuthView), findsOneWidget);
      expect(
        t.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      expect(
        (await SharedPreferences.getInstance()).getString('raft.mode'),
        'dark',
      );
      expect(
        app.f.adapter.calls.where(
          (c) => c.method == 'PATCH' || c.path.startsWith('/auth/'),
        ),
        isEmpty,
      );
      expect(t.takeException(), isNull);
    },
  );

  for (final save in [false, true]) {
    testWidgets(
      'public Settings Back ${save ? 'keeps saved' : 'discards unsaved'} UI language on reopen',
      (t) async {
        await cleanup(t);
        final app = _PublicApp();
        await app.mount(t);
        await _settings(t, 'language-region');
        await t.tap(find.byKey(const ValueKey('display-language-select')));
        await t.pumpAndSettle();
        await t.tap(find.text('简体中文').last);
        await t.pumpAndSettle();
        if (save) {
          await t.tap(find.byKey(const ValueKey('language-save')));
          await t.pumpAndSettle();
        }
        await _resize(t, 390);
        expect(back.hitTestable(), findsOneWidget);
        await t.tap(back);
        await t.pumpAndSettle();
        expect(find.byType(PublicServerView), findsNothing);
        expect(find.byType(AuthView), findsOneWidget);
        expect(
          t.widget<MaterialApp>(find.byType(MaterialApp)).locale,
          save ? const Locale('zh', 'CN') : const Locale('en'),
        );
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
        DevicePreferences.reset();
        final reopened = _PublicApp();
        await reopened.mount(t);
        await _settings(t, 'language-region');
        final form = t.widget<RaftLanguageRegionView>(
          find.byType(RaftLanguageRegionView),
        );
        expect(form.displayLanguage, save ? 'zh-cn' : 'en');
        expect(form.languageDirty, isFalse);
        expect(form.languageSave, RaftLanguageSaveState.idle);
        expect(
          [
            ...app.f.adapter.calls,
            ...reopened.f.adapter.calls,
          ].where((c) => c.method == 'PATCH' || c.path.startsWith('/auth/')),
          isEmpty,
        );
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'public Settings uses the canonical responsive content inset through Root',
    (t) async {
      await cleanup(t);
      await _PublicApp().mount(t);
      await _settings(t, 'language-region');
      for (final width in [390.0, 767.0, 768.0, 1280.0]) {
        await _resize(t, width);
        final frame = t.getTopLeft(find.byType(RaftSettingsPanelFrame));
        final select = t.getTopLeft(
          find.byKey(const ValueKey('display-language-select')),
        );
        // Web px-4/md:px-5 (16/20) + SurfaceList border/padding (1+16).
        // The existing attached Flutter frame adds one seam from md up.
        expect(select.dx - frame.dx, width < 768 ? 33 : 38);
      }
      expect(t.takeException(), isNull);
    },
  );
}
