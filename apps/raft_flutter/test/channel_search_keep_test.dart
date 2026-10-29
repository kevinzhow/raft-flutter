import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'mobile_back_history_test.dart' show finishBackTransition;

/// Phone-width path that used to revoke channel search after opening another
/// channel. The search page and its Back control stay.
void main() {
  testWidgets(
    'channel search stays after opening another channel',
    (t) async {
      final f = RootFixture();
      f.overrides['GET /channels'] = (o) {
        final server = o.headers['X-Server-Id'];
        if (server != null && server != 'a') return [];
        return [
          _channel('alpha', 'lab-alpha'),
          _channel('beta', 'lab-beta'),
        ];
      };
      for (final id in ['alpha', 'beta']) {
        f.overrides['GET /channels/$id'] = (_) => _channel(id, 'lab-$id');
        f.overrides['POST /channels/$id/read'] = (_) => {
          'maxReadSeq': '3',
          'readStateVersion': 1,
        };
        f.overrides['GET /messages/channel/$id'] = (_) => {
          'messages': [
            for (var n = 0; n < (id == 'beta' ? 4 : 1); n++) _message(id, n),
          ],
          'hasMore': false,
          'hasNewer': false,
        };
      }
      f.overrides['GET /messages/search'] = (_) => {
        'hasMore': false,
        'results': [
          {
            ..._message('alpha', 5),
            'snippet': 'alpha message 5',
            'channelName': 'lab-alpha',
            'channelType': 'channel',
          },
        ],
      };
      f.overrides['GET /messages/context/alpha-5'] = (_) => {
        'messages': [_message('alpha', 5)],
        'targetMessageId': 'alpha-5',
        'hasOlder': false,
        'hasNewer': false,
      };
      await f.mount(
        t,
        'light',
        390,
        uri: Uri.parse('/s/alpha/channel/alpha'),
      );
      final w = f.workspace(t);
      expect(find.text('lab-alpha').hitTestable(), findsWidgets);

      await _tap(t, find.bySemanticsLabel('Search This Channel'), 'search');
      await f.flush(t);
      expect(w.location.route, RaftRoute.search, reason: '${w.location}');
      expect(w.location.query('channelId'), 'alpha', reason: '${w.location}');

      final field = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText?.startsWith(
                  'Search channels, DMs, messages…',
                ) ==
                true,
      );
      await t.enterText(field.hitTestable(), 'a');
      await t.pump(const Duration(milliseconds: 300));
      await f.flush(t);
      expect(find.text('alpha message 5').hitTestable(), findsWidgets);
      expect(find.text('lab-beta').hitTestable(), findsWidgets);

      await _tap(t, find.text('alpha message 5'), 'alpha message');
      await f.flush(t);
      expect(w.location.route, RaftRoute.channel, reason: '${w.location}');
      expect(w.location.entityId, 'alpha', reason: '${w.location}');
      final composer = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            (widget.decoration?.hintText?.startsWith('Message') ?? false),
      );
      expect(composer.hitTestable(), findsOneWidget);
      await t.enterText(composer.hitTestable(), '你');
      await t.pump();

      await _tap(t, find.byKey(const Key('mobile-detail-back')), 'back');
      await f.flush(t);
      await finishBackTransition(t);
      expect(w.location.route, RaftRoute.search, reason: '${w.location}');

      await _tap(t, find.text('lab-beta'), 'beta');
      await f.flush(t);
      expect(w.location.entityId, 'beta', reason: '${w.location}');
      expect(
        t.widget<RaftChannelHeader>(
          find.byType(RaftChannelHeader).hitTestable(),
        ).name,
        'lab-beta',
      );

      await _tap(t, find.byKey(const Key('mobile-detail-back')), 'back from beta');
      await f.flush(t);
      await finishBackTransition(t);
      expect(w.location.route, RaftRoute.search, reason: '${w.location}');
      expect(find.text('Channel is no longer available'), findsNothing);
      expect(find.byTooltip('Back').hitTestable(), findsWidgets);
      expect(field.hitTestable(), findsOneWidget);
      await f.close(t);
    },
  );
}

Map<String, dynamic> _channel(String id, String name) => {
  'id': id,
  'name': name,
  'type': 'channel',
  'serverId': 'a',
  'joined': true,
  'latestSeq': '5',
};

Map<String, dynamic> _message(String channel, int n) => {
  'id': '$channel-$n',
  'channelId': channel,
  'seq': '$n',
  'senderId': 'alice',
  'senderType': 'user',
  'senderName': 'Alice',
  'content': n == 5 ? 'alpha message 5' : '$channel message $n',
  'createdAt': '2026-10-01T00:00:00Z',
};

Future<void> _tap(WidgetTester t, Finder finder, String label) async {
  final hit = finder.hitTestable();
  if (hit.evaluate().isEmpty) {
    final texts = t
        .widgetList<Text>(find.byType(Text, skipOffstage: false))
        .map((widget) => widget.data)
        .whereType<String>()
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .take(50)
        .join(' | ');
    fail('$label not tappable. Text: $texts');
  }
  await t.tap(hit.first);
}
