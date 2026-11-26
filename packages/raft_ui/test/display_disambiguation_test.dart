import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/l10n/display_catalogs.g.dart'
    show displayCatalogs, displayKeyed;

/// A label whose English matches several Web keys falls back to English unless
/// the call site says which one it means. `raftTextZh` does that by naming the
/// Simplified Chinese of the intended key, which only separates keys that
/// differ there — `Saved` is three Web keys that are all 已保存 and yet three
/// different words in Russian. Those name the Web key itself.
void main() {
  test('every keyed label resolves per Web key, not per English', () {
    // Sidebar collection, a saved-state confirmation, and a filter: one
    // English word, three Russian words.
    expect(
      displayKeyed['ru']![('Saved', 'layout.sidebar.saved')],
      'Сохранённое',
    );
    expect(
      displayKeyed['ru']![('Saved', 'message.messageItem.saved')],
      'Сохранено',
    );
    expect(
      displayKeyed['ru']![('Saved', 'thread.filter.saved')],
      'Сохранённые',
    );

    // Settings nav labels, which reach their widget as data (labelKey).
    expect(
      displayKeyed['ru']![('Account', 'settings.tabs.account')],
      'Аккаунт',
    );
    expect(
      displayKeyed['ru']![('Feedback', 'settings.about.feedbackTitle')],
      'Обратная связь',
    );
    expect(displayKeyed['zh-tw']![('Account', 'settings.tabs.account')], '帳號');
  });

  test('every declared keyed label is generated for every language', () {
    for (final language in displayCatalogs.keys) {
      final keyed = displayKeyed[language];
      expect(keyed, isNotNull, reason: language);
      for (final (source, webKey) in raftKeyedLabels) {
        expect(
          keyed![(source, webKey)],
          isNotNull,
          reason:
              '$language has no translation for $source ($webKey), so the '
              'label falls back to English where Web shows the language',
        );
      }
    }
  });

  test('the reply count is one ICU plural, so Russian gets few and many', () {
    const source = '{count, plural, one {# reply} other {# replies}}';
    final russian = displayCatalogs['ru']![source];
    expect(russian, isNotNull, reason: 'the count would stay English');
    // A two-way English branch cannot express these; the ICU message can.
    expect(russian, contains('few {'));
    expect(russian, contains('many {'));
    expect(displayCatalogs['ja']![source], isNotNull);
  });

  test('the composer placeholder uses the key Web actually renders', () {
    // Web `message.composer.messagePlaceholder`: the whole name, sigil
    // included, is the argument, so a language may put it first.
    expect(displayCatalogs['ja']!['Message {channel}'], '{channel} へのメッセージ');
    expect(
      displayCatalogs['ru']!['Message {channel}'],
      'Отправить сообщение: {channel}',
    );
  });
}
