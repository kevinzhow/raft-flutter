// The Lounge's raft_ui pieces (Web v1.24 LoungeAvatar.tsx, ReadOnlyComposer.tsx,
// useChannelHeadToggles.tsx): the mark on the face, the disabled composer and
// the head's extra button.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _host(Widget child, {double scale = 1}) => MaterialApp(
  theme: raftTheme(),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('the Lounge avatar carries the mark and no presence light', (
    t,
  ) async {
    await t.pumpWidget(
      _host(const Center(child: RaftLoungeAvatar(name: 'Bot'))),
    );
    expect(find.byKey(const ValueKey('lounge-avatar-badge')), findsOneWidget);
    expect(find.byKey(const ValueKey('mounted-avatar-presence')), findsNothing);
    expect(find.bySemanticsLabel('Bot'), findsOneWidget);
    // Panel header 36px, whose size class draws a 14px mark.
    expect(
      t.getSize(find.byKey(const ValueKey('lounge-avatar-frame'))).width,
      36,
    );
    expect(
      t.getSize(find.byKey(const ValueKey('lounge-avatar-badge'))).width,
      14,
    );
  });

  testWidgets('the read-only composer says so and grows with the text', (
    t,
  ) async {
    await t.pumpWidget(
      _host(
        const Align(
          alignment: Alignment.bottomCenter,
          child: RaftChannelReadOnlyComposer(),
        ),
      ),
    );
    final base = t.getSize(find.text('Chat is unavailable'));
    expect(find.text('Chat is unavailable'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await t.pumpWidget(
      _host(
        const Align(
          alignment: Alignment.bottomCenter,
          child: RaftChannelReadOnlyComposer(),
        ),
        scale: 3,
      ),
    );
    final big = t.getSize(find.text('Chat is unavailable'));
    expect(big.height, greaterThan(base.height));
  });

  testWidgets('the DM head keeps its buttons unless it is given more', (
    t,
  ) async {
    Widget head({List<Widget> middle = const [], bool warn = false}) => _host(
      RaftDmHeader(
        name: 'Bot',
        avatar: const SizedBox.square(dimension: 36),
        activity: RaftActivityTone.working,
        activityText: 'Stuck on bash',
        activityTextWarning: warn,
        middleActions: middle,
        onSearch: () {},
        onSettings: () {},
      ),
    );
    await t.pumpWidget(head());
    expect(find.byKey(const ValueKey('agent-dm-open-lounge')), findsNothing);
    var taps = 0;
    await t.pumpWidget(
      head(
        middle: [
          raftConversationHeaderAction(
            key: const ValueKey('agent-dm-open-lounge'),
            glyph: RaftGlyph.users,
            tooltip: 'Lounge',
            onPressed: () => taps++,
          ),
        ],
        warn: true,
      ),
    );
    final search = t.getCenter(
      find.byKey(const ValueKey('channel-topbar-search')),
    );
    final lounge = t.getCenter(
      find.byKey(const ValueKey('agent-dm-open-lounge')),
    );
    final settings = t.getCenter(
      find.byKey(const ValueKey('channel-overflow-trigger')),
    );
    expect(search.dx, lessThan(lounge.dx));
    expect(lounge.dx, lessThan(settings.dx));
    await t.tap(find.byKey(const ValueKey('agent-dm-open-lounge')));
    expect(taps, 1);
    final style = t.widget<Text>(find.text('Stuck on bash')).style;
    final tokens = RaftTokens.of(t.element(find.byType(RaftDmHeader)));
    expect(style?.color, tokens.colors['warning-strong']);
  });
}
