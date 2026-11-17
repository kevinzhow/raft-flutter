// Web v1.24 translationStore `followDisplayLanguage` and the Language & Region
// choices built on it: the no-preference translation target is "Same as display
// language" (not the browser's), follows the display language, and the other
// targets are named in the UI language.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/message_translation_store.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/locale_settings_page.dart';
import 'package:raft_flutter/features/settings_anchor.dart';
import 'package:raft_flutter/features/translation_language_options.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/screens/screen_fixture.dart';

class _Client extends ScreenFixtureClient {
  _Client(super.route, {super.user, super.server});
  final patches = <Map<String, dynamic>>[];
  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) {
    if (method == 'PATCH' && path == '/auth/me') {
      patches.add(Map<String, dynamic>.from(data as Map));
    }
    return super.request(method, path, data: data, query: query);
  }
}

Widget _app(Widget home, {Locale? locale}) => MaterialApp(
  theme: raftTheme(),
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(body: SingleChildScrollView(child: home)),
);

(_Client, WorkspaceController) _fixture({
  Map<String, dynamic> user = const {},
}) {
  final client = _Client(
    (method, path, query) {
      if (path == '/auth/me') return {'id': 'alice', ...user};
      if (path.endsWith('/translation-settings')) {
        return {
          'translationEnabled': true,
          'translationAvailable': true,
          'canManageTranslation': false,
        };
      }
      return <dynamic>[];
    },
    user: {'id': 'alice', ...user},
    server: 's',
  );
  final w = WorkspaceController(client)
    ..server = RaftRecord({'id': 's', 'name': 'S', 'role': 'member'});
  return (client, w);
}

void main() {
  setUp(() => MessageTranslationStore.deviceLanguages = () => ['en-US']);
  tearDown(() => MessageTranslationStore.followDisplayLanguage('en'));

  group('followDisplayLanguage', () {
    test(
      'a person with no preference translates into the display language',
      () {
        final (client, w) = _fixture();
        addTearDown(w.dispose);
        final store = w.services.translations;
        expect(store.settings.effectiveLanguage, 'en');
        var told = 0;
        store.addListener(() => told++);
        MessageTranslationStore.followDisplayLanguage('zh-cn');
        expect(store.settings.effectiveLanguage, 'zh-cn');
        expect(told, 1, reason: 'the rows translating into it are told');
        // The browser's language no longer decides it.
        MessageTranslationStore.deviceLanguages = () => ['ja-JP'];
        MessageTranslationStore.followDisplayLanguage('en');
        expect(store.settings.effectiveLanguage, 'en');
        expect(client.requests, isNotNull);
      },
    );

    test('a stored preference is not followed', () {
      final (_, w) = _fixture(user: {'preferredLanguage': 'ja'});
      addTearDown(w.dispose);
      final store = w.services.translations;
      MessageTranslationStore.followDisplayLanguage('zh-cn');
      expect(store.settings.effectiveLanguage, 'ja');
    });

    test('the choice that stores no preference is "display" (and the old "browser")', () {
      expect(followDisplayLanguageTarget, 'display');
      expect(normalizeTranslationLanguage('display'), isNull);
      expect(normalizeTranslationLanguage('browser'), isNull);
      expect(messageTranslationLanguages, contains('ru'));
    });

    test('before the app reports a locale the device language seeds it', () {
      MessageTranslationStore.deviceLanguages = () => ['zh-Hans-CN'];
      // followDisplayLanguage('en') in tearDown cleared the seed.
      MessageTranslationStore.followDisplayLanguage('zh-cn');
      expect(MessageTranslationStore.displayLanguageTarget, 'zh-cn');
    });
  });

  group('translation target choices', () {
    testWidgets(
      'same as display language first, then names in the UI language',
      (t) async {
        late List<RaftLanguageOption> en, zh;
        await t.pumpWidget(
          _app(
            Builder(
              builder: (c) {
                en = translationTargetOptions(c);
                return const SizedBox();
              },
            ),
          ),
        );
        await t.pumpWidget(
          _app(
            Builder(
              builder: (c) {
                zh = translationTargetOptions(c);
                return const SizedBox();
              },
            ),
            locale: const Locale('zh', 'CN'),
          ),
        );
        expect(en.first, ('display', 'Same as display language'));
        expect(
          [for (final o in en.skip(1)) o.$2],
          [
            'English',
            'French',
            'German',
            'Italian',
            'Japanese',
            'Korean',
            'Brazilian Portuguese',
            'Russian',
            'Simplified Chinese',
            'Spanish',
            'Traditional Chinese',
          ],
        );
        expect(zh.first.$1, 'display');
        expect(
          {for (final o in zh.skip(1)) o.$1},
          {for (final o in en.skip(1)) o.$1},
        );
        expect(zh[1], ('pt-br', '巴西葡萄牙语'));
        expect(zh.last, ('en', '英语'));
        expect(en.any((o) => o.$2 == 'Browser language'), isFalse);
      },
    );

    testWidgets('picking Same as display language saves no preference', (
      t,
    ) async {
      final (client, w) = _fixture(user: {'preferredLanguage': 'ja'});
      addTearDown(w.dispose);
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(900, 3200);
      addTearDown(t.view.reset);
      await t.pumpWidget(_app(LocaleSettingsPage(controller: w)));
      await t.pumpAndSettle();
      final state = t.state(find.byType(LocaleSettingsPage)) as dynamic;
      expect(state.savedTarget, 'ja');
      await t.tap(find.byKey(const ValueKey('translation-target')));
      await t.pumpAndSettle();
      await t.tap(find.text('Same as display language').last);
      await t.pumpAndSettle();
      expect(client.patches.single, {'preferredLanguage': null});
      // The old explanation of the browser's language is gone.
      expect(find.textContaining('Browser language'), findsNothing);
    });

    testWidgets(
      'a person with no preference sees Same as display language selected',
      (t) async {
        final (_, w) = _fixture();
        addTearDown(w.dispose);
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(900, 3200);
        addTearDown(t.view.reset);
        await t.pumpWidget(_app(LocaleSettingsPage(controller: w)));
        await t.pumpAndSettle();
        expect(find.text('Same as display language'), findsOneWidget);
      },
    );
  });

  testWidgets(
    'Language & Region rows are the targets of #display-language, #translation-mode, #timezone and #time-format',
    (t) async {
      final (_, w) = _fixture();
      addTearDown(w.dispose);
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(900, 3200);
      addTearDown(t.view.reset);
      final registry = SettingsAnchorRegistry();
      addTearDown(registry.dispose);
      await t.pumpWidget(
        _app(
          SettingsAnchorScope(
            registry: registry,
            child: LocaleSettingsPage(controller: w),
          ),
        ),
      );
      await t.pumpAndSettle();
      for (final id in [
        'display-language',
        'translation-mode',
        'timezone',
        'time-format',
      ]) {
        registry.jump(id);
        await t.pump();
        await t.pump();
        expect(registry.waiting, isFalse, reason: '#$id has a row to land on');
      }
    },
  );

  test('the timezone label is the offset and the city', () {
    final options = localeTimezoneOptions('Asia/Shanghai');
    final shanghai = options.firstWhere((o) => o.$1 == 'Asia/Shanghai');
    expect(shanghai.$2, 'UTC+08:00 Shanghai');
    expect(
      options.firstWhere((o) => o.$1 == 'America/Argentina/Buenos_Aires').$2,
      endsWith(' Buenos Aires'),
    );
    expect(options.firstWhere((o) => o.$1 == 'UTC').$2, 'UTC+00:00 UTC');
  });
}
