// Web v1.24 LanguageRegionSection: every choice applies the moment it is
// made. One PATCH /auth/me per change (no Save button, no reload), nothing
// said once it is stored, and a failure shows under its own row while the
// control goes back to the stored value.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/message_translation_store.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/locale_settings_page.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/screens/screen_fixture.dart';

typedef _Patch = FutureOr<dynamic> Function(Map<String, dynamic> fields);

class _Client extends ScreenFixtureClient {
  _Client(super.route, {super.user, super.server});
  final patches = <Map<String, dynamic>>[];

  /// What `PATCH /auth/me` answers; throws to refuse.
  _Patch onPatch = (fields) => <String, dynamic>{};

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
  }) async {
    if (method == 'PATCH' && path == '/auth/me') {
      requests.add('$method $path');
      final fields = Map<String, dynamic>.from(data as Map);
      patches.add(fields);
      return onPatch(fields);
    }
    return super.request(method, path, data: data, query: query);
  }

  // The fixture has no session to persist the user into: adopt it here, as
  // the signed-in client does.
  @override
  Future<void> replaceUser(Map<String, dynamic> json) async {
    user = RaftRecord(Map<String, dynamic>.from(json));
    emit(const RaftEvent('account:updated', null));
  }
}

RaftApiException _refused(String message) =>
    RaftApiException.response(message, status: 400, body: {'error': message});

Widget _app(Widget home, {Locale? locale}) => MaterialApp(
  theme: raftTheme(),
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(body: SingleChildScrollView(child: home)),
);

Future<(_Client, WorkspaceController)> _mount(
  WidgetTester t, {
  Map<String, dynamic> user = const {},
  Object? gateFailure,
  Locale? locale,
  Size size = const Size(900, 3200),
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
  final client = _Client(
    (method, path, query) {
      if (path.endsWith('/translation-settings')) {
        if (gateFailure != null) throw gateFailure;
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
  addTearDown(w.dispose);
  await t.pumpWidget(_app(LocaleSettingsPage(controller: w), locale: locale));
  await t.pumpAndSettle();
  return (client, w);
}

Finder _key(String key) => find.byKey(ValueKey(key));

String _segmentedValue(WidgetTester t, String key) =>
    t.widget<RaftSegmentedControl<String>>(_key(key)).value;

bool _segmentedEnabled(WidgetTester t, String key) =>
    t.widget<RaftSegmentedControl<String>>(_key(key)).onChanged != null;

Future<void> _choose(WidgetTester t, String selectKey, String option) async {
  await t.tap(_key(selectKey));
  await t.pumpAndSettle();
  await t.tap(find.text(option).last);
  await t.pumpAndSettle();
}

double _top(WidgetTester t, Finder f) => t.getTopLeft(f.first).dy;

/// A zone the open list shows without scrolling: the first one it offers.
(String, String) _firstZone() {
  final choices = localeTimezoneChoices('');
  return choices.options.firstWhere((o) => !choices.unlisted.contains(o.$1));
}

void main() {
  setUp(() => MessageTranslationStore.deviceLanguages = () => ['en-US']);
  tearDown(() => MessageTranslationStore.followDisplayLanguage('en'));

  group('the rows', () {
    testWidgets('are the Web list rows, in order, with no Save button', (
      t,
    ) async {
      await _mount(t);
      final titles = [
        'Language',
        'Display language',
        'Translation mode',
        'Translation target',
        'Default view',
        'Date & time',
        'Timezone',
        'Time format',
      ];
      double? previous;
      for (final title in titles) {
        final at = _top(t, find.text(title));
        if (previous != null) {
          expect(at, greaterThan(previous), reason: '$title follows');
        }
        previous = at;
      }
      expect(_key('language-save'), findsNothing);
      expect(_key('date-time-save'), findsNothing);
      expect(find.text('Save'), findsNothing);
      // The rows' own descriptions are gone with the cards.
      expect(
        find.textContaining('Choose the language for the app'),
        findsNothing,
      );
      expect(find.textContaining('Auto translates visible'), findsNothing);
      expect(find.textContaining('Used for local timestamps'), findsNothing);
      expect(find.textContaining('Display only'), findsNothing);
      expect(_key('language-region-card'), findsOneWidget);
      expect(_key('date-time-card'), findsOneWidget);
    });

    testWidgets('no Chinese rollout notice under the display language', (
      t,
    ) async {
      await _mount(t, locale: const Locale('zh', 'CN'));
      expect(find.textContaining('简体中文仍在完善'), findsNothing);
    });

    testWidgets('translation off leaves out the target and the default view', (
      t,
    ) async {
      await _mount(t, user: {'preferredTranslationMode': 'off'});
      expect(find.text('Translation mode'), findsOneWidget);
      expect(find.text('Translation target'), findsNothing);
      expect(find.text('Default view'), findsNothing);
    });

    testWidgets('the open list does not offer the chosen value again', (
      t,
    ) async {
      await _mount(
        t,
        user: {'preferredLanguage': 'ja', 'preferredTimezone': 'Asia/Tokyo'},
      );
      await t.tap(_key('translation-target'));
      await t.pumpAndSettle();
      expect(find.text('Japanese'), findsOneWidget, reason: 'the field only');
      expect(find.text('Same as display language'), findsOneWidget);
      expect(find.text('French'), findsOneWidget);
      await t.tapAt(const Offset(2, 2));
      await t.pumpAndSettle();
      await t.tap(_key('timezone-select'));
      await t.pumpAndSettle();
      expect(find.text('UTC+09:00 Tokyo'), findsOneWidget);
      expect(find.text('UTC+08:00 Shanghai'), findsOneWidget);
    });

    testWidgets('no timezone preference shows the Timezone placeholder', (
      t,
    ) async {
      await _mount(t);
      final select = t.widget<RaftSettingsSelect<String>>(
        _key('timezone-select'),
      );
      expect(select.value, isNull);
      expect(select.placeholder, 'Timezone');
    });

    testWidgets('the display language list uses Web endonyms and order', (
      t,
    ) async {
      await _mount(t);
      final picker = t.widget<RaftSettingsSelect<String>>(
        _key('display-language-select'),
      );
      expect(picker.items.map((item) => item.label), [
        'English',
        'Español',
        'Português (Brasil)',
        'Русский',
        '한국어',
        '日本語',
        '简体中文',
        '繁體中文',
      ]);
      await t.tap(_key('display-language-select'));
      await t.pumpAndSettle();
      expect(find.text('English'), findsNWidgets(2));
      expect(find.text('简体中文'), findsOneWidget);
    });
  });

  group('a change applies at once', () {
    testWidgets('translation mode: one PATCH, no reload, nothing said', (
      t,
    ) async {
      final (client, _) = await _mount(t);
      client.onPatch = (fields) => {...fields};
      await t.tap(find.text('Manual'));
      await t.pumpAndSettle();
      expect(client.patches, [
        {'preferredTranslationMode': 'manual'},
      ]);
      expect(client.requests.where((r) => r == 'GET /auth/me'), isEmpty);
      expect(_segmentedValue(t, 'translation-mode'), 'manual');
      expect(find.text('Saved'), findsNothing);
      expect(find.byType(RaftSaveStatus), findsNothing);
    });

    testWidgets('choosing the value it already has sends nothing', (t) async {
      final (client, _) = await _mount(
        t,
        user: {'preferredTranslationMode': 'manual'},
      );
      await t.tap(find.text('Manual'));
      await t.pumpAndSettle();
      expect(client.patches, isEmpty);
    });

    testWidgets('translation target: a language, then Same as display', (
      t,
    ) async {
      final (client, _) = await _mount(t);
      client.onPatch = (fields) => {...fields};
      await _choose(t, 'translation-target', 'Japanese');
      expect(client.patches.last, {'preferredLanguage': 'ja'});
      await _choose(t, 'translation-target', 'Same as display language');
      expect(client.patches.last, {'preferredLanguage': null});
      expect(client.patches, hasLength(2));
    });

    testWidgets('default view', (t) async {
      final (client, _) = await _mount(t);
      client.onPatch = (fields) => {...fields};
      await t.tap(find.text('Bilingual'));
      await t.pumpAndSettle();
      expect(client.patches.single, {
        'preferredTranslationDisplay': 'bilingual',
      });
      expect(_segmentedValue(t, 'translation-display'), 'bilingual');
    });

    testWidgets('timezone and time format', (t) async {
      final (client, _) = await _mount(t);
      client.onPatch = (fields) => {...fields};
      final zone = _firstZone();
      await _choose(t, 'timezone-select', zone.$2);
      expect(client.patches.last, {'preferredTimezone': zone.$1});
      await t.tap(find.text('24-hour'));
      await t.pumpAndSettle();
      expect(client.patches.last, {'preferredTimeFormat': '24h'});
      expect(_segmentedValue(t, 'time-format'), '24h');
      expect(client.patches, hasLength(2));
    });

    testWidgets('display language joins the account, then the app follows', (
      t,
    ) async {
      final (client, w) = await _mount(t);
      client.onPatch = (fields) => {...fields};
      await _choose(t, 'display-language-select', '日本語');
      expect(client.patches.single, {'displayLanguage': 'ja'});
      expect(w.client.user?.string('displayLanguage'), 'ja');
      expect(client.requests.where((r) => r == 'GET /auth/me'), isEmpty);
    });

    testWidgets('what was sent holds where the answer does not name it', (
      t,
    ) async {
      final (client, w) = await _mount(t);
      client.onPatch = (fields) => <String, dynamic>{'id': 'alice'};
      await t.tap(find.text('Manual'));
      await t.pumpAndSettle();
      expect(w.translations.settings.mode, MessageTranslationMode.manual);
    });
  });

  group('a failure', () {
    testWidgets('puts the control back and speaks under its own row', (
      t,
    ) async {
      final (client, _) = await _mount(t);
      client.onPatch = (_) => throw _refused('Mode is locked');
      await t.tap(find.text('Manual'));
      await t.pumpAndSettle();
      expect(_segmentedValue(t, 'translation-mode'), 'auto');
      final message = find.text('Mode is locked');
      expect(message, findsOneWidget);
      expect(find.byType(RaftSaveStatus), findsOneWidget);
      // Under Translation mode, above Translation target.
      expect(
        _top(t, message),
        greaterThan(_top(t, find.text('Translation mode'))),
      );
      expect(
        _top(t, message),
        lessThan(_top(t, find.text('Translation target'))),
      );
      expect(_segmentedEnabled(t, 'translation-mode'), isTrue);
    });

    testWidgets('without a server message says the setting\'s own', (t) async {
      final (client, _) = await _mount(t);
      client.onPatch = (_) => throw StateError('socket closed');
      await _choose(t, 'translation-target', 'Japanese');
      expect(
        find.text('Failed to update language preferences'),
        findsOneWidget,
      );
      expect(find.textContaining('socket'), findsNothing);
      await t.tap(find.text('24-hour'));
      await t.pumpAndSettle();
      expect(
        find.text('Failed to update date and time preferences'),
        findsOneWidget,
        reason: 'the date and time rows say theirs',
      );
      expect(
        find.text('Failed to update language preferences'),
        findsOneWidget,
        reason: 'and each failure stays with its own row',
      );
    });

    testWidgets('stays until that row\'s next change, which ends it', (
      t,
    ) async {
      final (client, _) = await _mount(t);
      client.onPatch = (_) => throw _refused('Mode is locked');
      await t.tap(find.text('Manual'));
      await t.pumpAndSettle();
      expect(find.text('Mode is locked'), findsOneWidget);
      // Another row's change leaves it.
      client.onPatch = (fields) => {...fields};
      await t.tap(find.text('Bilingual'));
      await t.pumpAndSettle();
      expect(find.text('Mode is locked'), findsOneWidget);
      // Its own next change ends it, success says nothing.
      await t.tap(find.text('Off'));
      await t.pumpAndSettle();
      expect(find.text('Mode is locked'), findsNothing);
      expect(_segmentedValue(t, 'translation-mode'), 'off');
    });

    testWidgets('display language: the select goes back, the message is the '
        'setting\'s own whatever the server said', (t) async {
      final (client, _) = await _mount(t);
      client.onPatch = (_) => throw _refused('Locale refused');
      await _choose(t, 'display-language-select', '简体中文');
      expect(
        find.text('Failed to update language preferences'),
        findsOneWidget,
      );
      expect(find.text('Locale refused'), findsNothing);
      final select = t.widget<RaftSettingsSelect<String>>(
        _key('display-language-select'),
      );
      expect(select.value, 'en');
    });

    testWidgets('timezone: the server\'s message under Timezone', (t) async {
      final (client, _) = await _mount(t);
      client.onPatch = (_) => throw _refused('Unknown zone');
      await _choose(t, 'timezone-select', _firstZone().$2);
      final message = find.text('Unknown zone');
      expect(message, findsOneWidget);
      expect(_top(t, message), greaterThan(_top(t, find.text('Timezone'))));
      expect(_top(t, message), lessThan(_top(t, find.text('Time format'))));
      final select = t.widget<RaftSettingsSelect<String>>(
        _key('timezone-select'),
      );
      expect(
        select.value,
        isNull,
        reason: 'back to no preference: the placeholder',
      );
    });
  });

  group('while a change is stored', () {
    testWidgets('its control shows the choice and waits, the rest do not', (
      t,
    ) async {
      final (client, _) = await _mount(t);
      final held = Completer<dynamic>();
      client.onPatch = (_) => held.future;
      await t.tap(find.text('Manual'));
      await t.pump();
      expect(_segmentedValue(t, 'translation-mode'), 'manual');
      expect(_segmentedEnabled(t, 'translation-mode'), isFalse);
      expect(_segmentedEnabled(t, 'translation-display'), isTrue);
      expect(_segmentedEnabled(t, 'time-format'), isTrue);
      held.complete(<String, dynamic>{'preferredTranslationMode': 'manual'});
      await t.pumpAndSettle();
      expect(_segmentedEnabled(t, 'translation-mode'), isTrue);
    });

    testWidgets('a change of another row goes out at once, in parallel', (
      t,
    ) async {
      final (client, _) = await _mount(t);
      client.onPatch = (_) => Completer<dynamic>().future;
      await t.tap(find.text('Manual'));
      await t.pump();
      await t.tap(find.text('24-hour'));
      await t.pump();
      expect(client.patches, [
        {'preferredTranslationMode': 'manual'},
        {'preferredTimeFormat': '24h'},
      ]);
    });
  });

  // A choice is made with the finger on a folded or tablet screen and the
  // mouse in a narrow desktop window: the rows stack the control under the
  // text under 32rem, and a failure still sits under its own row.
  for (final (size, platform) in [
    (const Size(856, 944), TargetPlatform.android),
    (const Size(944, 856), TargetPlatform.android),
    (const Size(390, 844), TargetPlatform.linux),
  ]) {
    testWidgets(
      'applies at once, and a failure shows under its row, at $size',
      (t) async {
        final (client, _) = await _mount(t, size: size);
        client.onPatch = (fields) => {...fields};
        await t.ensureVisible(find.text('Manual'));
        await t.tap(find.text('Manual'));
        await t.pumpAndSettle();
        expect(client.patches.single, {'preferredTranslationMode': 'manual'});
        expect(_segmentedValue(t, 'translation-mode'), 'manual');
        client.onPatch = (_) => throw _refused('Format refused');
        final format = find.text('24-hour');
        await t.ensureVisible(format);
        await t.tap(format);
        await t.pumpAndSettle();
        final message = find.text('Format refused');
        expect(message, findsOneWidget);
        expect(message.hitTestable(), findsOneWidget);
        expect(
          _top(t, message),
          greaterThan(_top(t, find.text('Time format'))),
        );
        expect(_segmentedValue(t, 'time-format'), '12h');
        await t.ensureVisible(_key('display-language-select'));
        await t.tap(_key('display-language-select'));
        await t.pumpAndSettle();
        expect(find.text('简体中文'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }

  group('the translation settings', () {
    testWidgets('a failed read shows under both groups and holds the rows', (
      t,
    ) async {
      await _mount(t, gateFailure: StateError('down'));
      expect(
        find.text('Failed to load translation settings'),
        findsNWidgets(2),
      );
    });
  });
}
