// Web `LanguageRegionSection` with `browserLocalPreferences` (a signed-out
// visitor of a public server): every choice is written on this device at
// once. There is no Save button and no request, so nothing can fail.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/display_language_preferences.dart';
import 'package:raft_flutter/data/message_translation_store.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/public_language_settings.dart';
import 'package:raft_flutter/features/public_translation.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'parity/cases/screens/screen_fixture.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

Future<
  ({
    PublicLocalPreferences preferences,
    DisplayLanguagePreferences language,
    ScreenFixtureClient client,
  })
>
_mount(WidgetTester t, {Size size = const Size(900, 3200)}) async {
  SharedPreferences.setMockInitialValues({});
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
  final client = ScreenFixtureClient(
    (method, path, query) => <dynamic>[],
    server: 's',
  );
  final w = WorkspaceController(client)
    ..server = RaftRecord({'id': 's', 'name': 'S', 'role': 'member'});
  addTearDown(w.dispose);
  final preferences = PublicLocalPreferences();
  addTearDown(preferences.dispose);
  final language = DisplayLanguagePreferences();
  addTearDown(language.dispose);
  final store = w.services.translations
    ..usePublicServer(
      PublicTranslationScope(
        serverId: 's',
        slug: 'raft-design',
        enabled: true,
        available: true,
        preferences: () => preferences.json,
      ),
    );
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: PublicLanguageRegionPage(
            preferences: preferences,
            translations: store,
            displayLanguage: language,
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return (preferences: preferences, language: language, client: client);
}

void main() {
  setUp(() => MessageTranslationStore.deviceLanguages = () => ['en-US']);
  tearDown(() => MessageTranslationStore.followDisplayLanguage('en'));

  for (final (size, platform) in [
    (const Size(900, 3200), TargetPlatform.linux),
    (const Size(856, 944), TargetPlatform.android),
    (const Size(944, 856), TargetPlatform.android),
    (const Size(390, 844), TargetPlatform.linux),
  ]) {
    testWidgets(
      'each choice is stored on the device at once, with no Save and no request, at $size',
      (t) async {
        final m = await _mount(t, size: size);
        expect(_key('language-save'), findsNothing);
        expect(find.text('Save'), findsNothing);
        await t.ensureVisible(find.text('Manual'));
        await t.tap(find.text('Manual'));
        await t.pumpAndSettle();
        expect(m.preferences.json['preferredTranslationMode'], 'manual');
        await t.ensureVisible(find.text('Bilingual'));
        await t.tap(find.text('Bilingual'));
        await t.pumpAndSettle();
        expect(m.preferences.json['preferredTranslationDisplay'], 'bilingual');
        await t.ensureVisible(find.text('24-hour'));
        await t.tap(find.text('24-hour'));
        await t.pumpAndSettle();
        expect(m.preferences.json['preferredTimeFormat'], '24h');
        await t.ensureVisible(_key('translation-target'));
        await t.tap(_key('translation-target'));
        await t.pumpAndSettle();
        await t.tap(find.text('Japanese').last);
        await t.pumpAndSettle();
        expect(m.preferences.json['preferredLanguage'], 'ja');
        await t.ensureVisible(_key('display-language-select'));
        await t.tap(_key('display-language-select'));
        await t.pumpAndSettle();
        await t.tap(find.text('简体中文').last);
        await t.pumpAndSettle();
        expect(m.language.value, 'zh-cn');
        final saved = jsonDecode(
          (await SharedPreferences.getInstance()).getString(
            publicTranslationPreferencesKey,
          )!,
        ) as Map;
        expect(saved['preferredTranslationMode'], 'manual');
        expect(saved['preferredTranslationDisplay'], 'bilingual');
        expect(saved['preferredTimeFormat'], '24h');
        expect(saved['preferredLanguage'], 'ja');
        expect(m.client.requests.where((r) => r.contains('/auth/')), isEmpty);
        expect(find.byType(RaftSaveStatus), findsNothing);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
