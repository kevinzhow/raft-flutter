// Web features/settings/tests/settingsSearchAnchors.test.ts: every setting the
// search finds can be opened at, because its row carries `id="<id>"`. This is
// the same source check for the app, as a ratchet: a row that gets its anchor
// leaves [pending]; an index entry that is neither anchored nor pending fails.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/settings_search_index.dart';

/// The index ids whose row has no [RaftSettingsAnchor] yet, by the page that
/// owns the file the row is in (the rows there are not this package's files):
/// a result for one of these opens its page at the top.
const pending = <String, List<String>>{
  'account (account_settings.dart)': [
    'display-name',
    'username',
    'email',
    'password',
    'sign-out',
    'delete-account',
  ],
  'appearance (appearance_section.dart)': [
    'message-font-size',
    'live-agent-activity',
    'show-agent-model',
    'show-sender-description',
    'hide-empty-sidebar-sections',
    'send-with',
  ],
  'notifications (notification_settings_cards.dart)': [
    'push-notifications',
    'pause-notifications',
    'quiet-hours',
    'notification-preview',
    'notification-sound',
    'notification-followed-thread-replies',
  ],
  'theme / server-notifications (WP-THEME, WP-NOTIF)': [
    'theme',
    'server-theme',
    'mute-server',
  ],
  'server (server_views.dart)': [
    'server-name',
    'public-access',
    'leave-server',
  ],
  'billing (billing_view.dart)': ['plan'],
  'administration (administration_view.dart)': [
    'invite-links',
    'single-sign-on',
    'member-permissions',
  ],
  'providers (provider_views.dart)': ['ai-providers'],
};

Set<String> anchoredIds() {
  var dir = Directory.current.absolute;
  while (!File('${dir.path}/pubspec.yaml').existsSync() ||
      !Directory('${dir.path}/apps/raft_flutter/lib').existsSync()) {
    dir = dir.parent;
  }
  final sources = [
    for (final root in ['apps/raft_flutter/lib', 'packages/raft_ui/lib'])
      for (final file in Directory(
        '${dir.path}/$root',
      ).listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart')) file,
  ];
  final direct = RegExp(
    r"RaftSettingsAnchor\(\s*(?:key:\s*[^,]+,\s*)?id:\s*'([a-z0-9-]+)'",
  );
  final viaBuilder = RegExp(r"_anchored\(\s*'([a-z0-9-]+)'");
  return {
    for (final file in sources)
      for (final pattern in [direct, viaBuilder])
        for (final m in pattern.allMatches(file.readAsStringSync())) m[1]!,
  };
}

void main() {
  test(
    'every setting in the index has its row anchored, or is listed as pending',
    () {
      final anchored = anchoredIds();
      final listed = {for (final ids in pending.values) ...ids};
      final index = {for (final e in settingsSearchIndex) e.id};
      expect(
        index.difference(anchored).difference(listed),
        isEmpty,
        reason: 'an index entry with no anchor and not listed as pending',
      );
      expect(
        listed.intersection(anchored),
        isEmpty,
        reason: 'an anchored row is no longer pending: delete it from the list',
      );
      expect(listed.difference(index), isEmpty, reason: 'not an index entry');
      expect(
        anchored.difference(index),
        isEmpty,
        reason: 'an anchor with no index entry',
      );
    },
  );

  test('the sections the app anchors itself', () {
    expect(
      anchoredIds(),
      containsAll([
        'display-language',
        'translation-mode',
        'timezone',
        'time-format',
        'passkeys',
        'two-step',
      ]),
    );
  });
}
