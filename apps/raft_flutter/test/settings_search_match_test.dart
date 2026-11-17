// Web features/settings/tests/settingsSearchMatch.test.ts, ported: Settings
// search's matching and order (raft-design settings.md#searching-settings).
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/settings_search_index.dart';
import 'package:raft_flutter/features/settings_search_match.dart';

SearchableSetting setting(
  String id, {
  String page = 'appearance',
  String? name,
  String pageLabel = 'Appearance',
  String? description,
  String? sectionLabel,
  List<String> aliases = const [],
}) => SearchableSetting(
  id: id,
  page: page,
  name: name ?? id,
  pageLabel: pageLabel,
  description: description,
  sectionLabel: sectionLabel,
  aliases: aliases,
);

// In the list's order.
final settings = [
  setting(
    'message-font-size',
    name: 'Message font size',
    description: 'Text size of messages.',
    sectionLabel: 'Appearance',
  ),
  setting(
    'send-with',
    name: 'Send messages with',
    sectionLabel: 'Message box',
    aliases: ['enter', 'return', 'send key'],
  ),
  setting(
    'push-notifications',
    page: 'notifications',
    pageLabel: 'Notifications',
    name: 'Browser notifications',
    description: 'Uses web push to send them.',
    sectionLabel: 'This device',
    aliases: ['push'],
  ),
  setting(
    'leave-server',
    page: 'server',
    pageLabel: 'Server profile',
    name: 'Leave server',
    description: 'You will lose access to messages.',
    sectionLabel: 'Danger zone',
    aliases: ['quit'],
  ),
];

List<String> ids(String query) => [
  for (final r in searchSettings(settings, query)) r.setting.id,
];

void main() {
  test(
    'names first, then other words, then descriptions, then page and section; the list order within each',
    () {
      expect(ids('message'), ['message-font-size', 'send-with', 'leave-server']);
      expect(ids('send'), ['send-with', 'push-notifications']);
      expect(
        [
          for (final r in searchSettings(settings, 'push'))
            (r.setting.id, r.field),
        ],
        [('push-notifications', SettingsSearchMatchField.alias)],
      );
      expect(ids('danger'), ['leave-server'], reason: 'a section finds its settings');
      expect(searchSettings(settings, 'danger').first.field, SettingsSearchMatchField.where);
    },
  );

  test('each kind of match outranks the next, against the list order', () {
    final list = [
      setting('where', name: 'Volume', sectionLabel: 'Chime'),
      setting('description', name: 'Sound', description: 'Plays a chime.'),
      setting('alias', name: 'Send messages with', aliases: ['chime']),
      setting('name', name: 'Chime'),
    ];
    expect(
      [for (final r in searchSettings(list, 'chime')) (r.setting.id, r.field)],
      [
        ('name', SettingsSearchMatchField.name),
        ('alias', SettingsSearchMatchField.alias),
        ('description', SettingsSearchMatchField.description),
        ('where', SettingsSearchMatchField.where),
      ],
    );
  });

  test('another word that matched is the result alias, so the row can show it', () {
    final result = searchSettings(settings, 'Return').single;
    expect(result.setting.id, 'send-with');
    expect(result.field, SettingsSearchMatchField.alias);
    expect(result.alias, 'return');
    expect(searchSettings(settings, 'font').first.alias, isNull);
  });

  test('case, full-width letters and extra spaces do not matter', () {
    expect(ids('ENTER'), ['send-with']);
    expect(ids('Ｅｎｔｅｒ'), ['send-with']);
    expect(ids('  message   font '), ['message-font-size']);
    expect(normalizeSettingsSearchText('  Ｓｅｎｄ　Key '), 'send key');
  });

  test('an empty or blank query finds nothing, and so does a word no setting has', () {
    expect(ids(''), isEmpty);
    expect(ids('   '), isEmpty);
    expect(ids('launch'), isEmpty);
  });

  test('the other words are the display language, then English, each once', () {
    const entry = SettingsSearchEntry(
      id: 'x',
      page: 'p',
      name: 'X',
      aliases: ['dark', 'night'],
      aliasesZh: ['深色', 'night'],
    );
    expect(settingsSearchAliases(entry, zh: true), ['深色', 'night', 'dark']);
    expect(settingsSearchAliases(entry, zh: false), ['dark', 'night']);
  });

  test('a cut description keeps its words findable through the index aliases', () {
    List<SettingsSearchMatchField> finds(String id, bool zh, String query) {
      final entry = settingsSearchIndex.firstWhere((e) => e.id == id);
      return [
        for (final r in searchSettings([
          setting(id, aliases: settingsSearchAliases(entry, zh: zh)),
        ], query))
          r.field,
      ];
    }

    expect(finds('message-font-size', true, '代码块'), [SettingsSearchMatchField.alias]);
    expect(finds('live-agent-activity', false, 'above the composer'), [SettingsSearchMatchField.alias]);
    expect(finds('show-agent-model', false, 'next to its name'), [SettingsSearchMatchField.alias]);
    expect(finds('time-format', true, '仅显示'), [SettingsSearchMatchField.alias]);
    expect(finds('passkeys', false, 'screen lock'), [SettingsSearchMatchField.alias]);
    expect(finds('theme', false, 'follow your device'), [SettingsSearchMatchField.alias]);
    expect(finds('push-notifications', false, 'web push'), [SettingsSearchMatchField.alias]);
  });

  test('the index is the Web list: unique ids, none the app does not have', () {
    final seen = <String>{};
    for (final entry in settingsSearchIndex) {
      expect(seen.add(entry.id), isTrue, reason: 'duplicate ${entry.id}');
    }
    expect(seen, isNot(contains('desktop-app')));
    expect(seen, containsAll(['display-name', 'delete-account', 'two-step', 'plan']));
  });
}
