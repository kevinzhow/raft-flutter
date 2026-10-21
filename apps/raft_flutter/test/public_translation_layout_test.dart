// The Public server page's translation and v1.21.23 layout: messages translate
// through the slug-scoped public route, Language & Region follows the server's
// gate, phones show one column at a time with Back to channels, and the banner
// sits under the conversation only.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/public_server_view.dart';
import 'package:raft_flutter/features/public_translation.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/public_server_fixture.dart' as fixture;

const _base = '/public/servers/raft-design';

class _Client extends RaftClient {
  _Client({this.translation = true})
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  final bool translation;
  final calls = <String>[];
  final bodies = <Map<String, dynamic>>[];
  @override
  void connect() {}
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
    calls.add('$method $path');
    if (path == _base) {
      return {
        'server': {
          'id': 's',
          'name': 'Raft Design',
          'slug': 'raft-design',
          'translationEnabled': translation,
        },
        'translationAvailable': translation,
        'channels': [
          {'id': 'c1', 'name': 'general', 'description': null},
          {'id': 'c2', 'name': 'help', 'description': null},
        ],
        'canJoinAsGuest': true,
      };
    }
    if (path == '$_base/channels/c1/messages') {
      return {
        'messages': [
          {
            'id': '11111111-1111-4111-8111-111111111111',
            'senderType': 'user',
            'sender': {'displayName': 'Wenyi'},
            'messageType': 'chat',
            'content': 'Bonjour tout le monde',
            'createdAt': '2026-06-18T09:12:00.000Z',
            'threadId': null,
            'replyCount': 0,
          },
        ],
      };
    }
    if (path == '$_base/channels/c2/messages') return {'messages': const []};
    if (method == 'POST' && path == '$_base/message-translations:batch') {
      bodies.add(Map<String, dynamic>.from(data as Map));
      return {
        'results': [
          for (final id in (data['messageIds'] as List))
            {
              'messageId': id,
              'status': 'translated',
              'translatedContent': 'Hello everyone',
              'sourceLanguage': 'fr',
              'targetLanguage': data['targetLanguage'],
            },
        ],
      };
    }
    throw RaftApiException('Not found', status: 404);
  }
}

Future<void> _mount(
  WidgetTester t,
  _Client client, {
  Size size = const Size(1280, 800),
  String? channel,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(
        body: PublicServerView(
          client: client,
          slug: 'raft-design',
          initialChannelId: channel,
          onUnavailable: () {},
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void _prefs(Map<String, Object?> value) =>
    SharedPreferences.setMockInitialValues({
      publicTranslationPreferencesKey: jsonEncode(value),
    });

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('translation', () {
    testWidgets(
      'a signed-out visitor reads translations from the public route',
      (t) async {
        _prefs({'preferredLanguage': 'en', 'preferredTranslationMode': 'auto'});
        final client = _Client();
        await _mount(t, client);
        await t.pump(const Duration(seconds: 1));
        await t.pumpAndSettle();
        expect(client.bodies, [
          {
            'messageIds': ['11111111-1111-4111-8111-111111111111'],
            'targetLanguage': 'en',
            'mode': 'auto',
          },
        ]);
        expect(
          client.calls,
          isNot(contains('POST /message-translations:batch')),
        );
        expect(find.text('Hello everyone'), findsOneWidget);
        expect(find.text('Bonjour tout le monde'), findsNothing);
        // The indicator offers the original back.
        expect(find.text('Show original'), findsOneWidget);
      },
    );

    testWidgets('a server without translation never asks', (t) async {
      _prefs({'preferredTranslationMode': 'auto'});
      final client = _Client(translation: false);
      await _mount(t, client);
      await t.pump(const Duration(seconds: 1));
      expect(client.bodies, isEmpty);
      expect(find.text('Bonjour tout le monde'), findsOneWidget);
    });

    testWidgets('off or manual mode asks for nothing by itself', (t) async {
      for (final mode in ['off', 'manual']) {
        _prefs({'preferredTranslationMode': mode});
        final client = _Client();
        await _mount(t, client);
        await t.pump(const Duration(seconds: 1));
        expect(client.bodies, isEmpty, reason: mode);
        await t.pumpWidget(const SizedBox());
      }
    });
  });

  group('settings tabs follow the gate (getPublicPersonalSettingsTabIds)', () {
    test('which personal tabs a visitor gets', () {
      expect(
        publicPersonalSettingsTabs(
          authenticated: false,
          translationEnabled: false,
        ),
        ['appearance'],
      );
      expect(
        publicPersonalSettingsTabs(
          authenticated: false,
          translationEnabled: true,
        ),
        ['language-region', 'appearance'],
      );
      expect(
        publicPersonalSettingsTabs(
          authenticated: true,
          translationEnabled: false,
        ),
        ['account', 'appearance'],
      );
      expect(
        publicPersonalSettingsTabs(
          authenticated: true,
          translationEnabled: true,
        ),
        ['account', 'language-region', 'appearance'],
      );
    });

    testWidgets(
      'Language & Region is only a tab where translation is offered',
      (t) async {
        await _mount(t, _Client(translation: false));
        await t.tap(find.byKey(const ValueKey('public-rail-settings')));
        await t.pumpAndSettle();
        expect(find.text('Language & Region'), findsNothing);
        await t.pumpWidget(const SizedBox());
        await _mount(t, _Client());
        await t.tap(find.byKey(const ValueKey('public-rail-settings')));
        await t.pumpAndSettle();
        expect(find.text('Language & Region'), findsWidgets);
      },
    );

    testWidgets('a signed-out visitor saves the choices on this device', (
      t,
    ) async {
      await _mount(t, _Client());
      await t.tap(find.byKey(const ValueKey('public-rail-settings')));
      await t.pumpAndSettle();
      await t.tap(find.text('Language & Region').first);
      await t.pumpAndSettle();
      expect(find.byType(RaftLanguageRegionView), findsOneWidget);
      final view = t.widget<RaftLanguageRegionView>(
        find.byType(RaftLanguageRegionView),
      );
      view.onTranslationMode('manual');
      await t.pump();
      t
          .widget<RaftLanguageRegionView>(find.byType(RaftLanguageRegionView))
          .onSaveLanguage();
      await t.pumpAndSettle();
      final saved = jsonDecode(
        (await SharedPreferences.getInstance()).getString(
          publicTranslationPreferencesKey,
        )!,
      ) as Map;
      expect(saved['preferredTranslationMode'], 'manual');
    });

    testWidgets(
      'a signed-in non-member shares the gate with the account page',
      (t) async {
        final account = fixture.nonMemberAccount();
        await fixture.mountPublicServer(t, account: account, translation: true);
        final store = account.settings!.controller.services.translations;
        expect(store.settings.available, isTrue);
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
        expect(store.settings.available, isFalse);
      },
    );
  });

  group('one column at a time below sm', () {
    testWidgets('the list first, then a channel with Back to channels', (
      t,
    ) async {
      final client = _Client(translation: false);
      await _mount(t, client, size: const Size(620, 900));
      final width = t.getSize(
        find.byKey(const ValueKey('public-server-channel-sidebar')),
      );
      expect(width.width, 620);
      expect(
        find.byKey(const ValueKey('public-server-phone-back')),
        findsNothing,
      );
      expect(find.text('Bonjour tout le monde'), findsNothing);

      await t.tap(find.byKey(const ValueKey('public-channel-c1')));
      await t.pumpAndSettle();
      expect(find.text('Bonjour tout le monde'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('public-server-channel-sidebar')),
        findsNothing,
      );
      expect(find.byTooltip('Back to channels'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('public-server-phone-back')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('public-server-channel-sidebar')),
        findsOneWidget,
      );
      expect(find.text('Bonjour tout le monde'), findsNothing);
    });

    testWidgets('a link to a channel opens it directly', (t) async {
      await _mount(
        t,
        _Client(translation: false),
        size: const Size(620, 900),
        channel: 'c1',
      );
      expect(find.text('Bonjour tout le monde'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('public-server-phone-back')),
        findsOneWidget,
      );
    });

    testWidgets('the banner keeps its copy and actions on one row', (t) async {
      await _mount(t, _Client(translation: false), size: const Size(620, 900));
      final banner = find.byKey(const ValueKey('public-server-bottom-action'));
      expect(t.getSize(banner).width, 620);
      expect(t.getSize(banner).height, lessThan(80));
    });
  });

  testWidgets(
    'wide: the banner sits under the conversation, beside the full-height channel column',
    (t) async {
      await _mount(t, _Client(translation: false));
      final sidebar = t.getRect(
        find.byKey(const ValueKey('public-server-channel-sidebar')),
      );
      final banner = t.getRect(
        find.byKey(const ValueKey('public-server-bottom-action')),
      );
      expect(banner.left, closeTo(sidebar.right, 1));
      expect(sidebar.bottom, closeTo(800, 1));
      expect(banner.bottom, closeTo(800, 1));
    },
  );
}
