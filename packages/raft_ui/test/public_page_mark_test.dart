import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _host(Widget child) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('the server globe draws only for a live public page', (t) async {
    await t.pumpWidget(_host(const RaftPublicPageGlobe(live: false)));
    expect(find.byKey(const ValueKey('public-page-globe')), findsNothing);
    await t.pumpWidget(_host(const RaftPublicPageGlobe(live: true)));
    expect(find.byKey(const ValueKey('public-page-globe')), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Public: anyone can read its public channels without signing in',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the channel mark says what it means, in Chinese too', (t) async {
    await t.pumpWidget(_host(const RaftPublicChannelMark(size: 16)));
    expect(find.byKey(const ValueKey('public-channel-mark')), findsOneWidget);
    expect(
      find.bySemanticsLabel('Anyone can read this channel on the public page'),
      findsOneWidget,
    );
    await t.pumpWidget(
      _host(
        Builder(
          builder: (context) => Localizations.override(
            context: context,
            locale: const Locale('zh'),
            child: const RaftPublicChannelMark(size: 16),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('任何人都能在公开页阅读这个频道'), findsOneWidget);
  });

  testWidgets('a public channel header swaps the # for the mark', (t) async {
    Widget header(bool publicPage) =>
        _host(RaftChannelHeader(name: 'general', publicPage: publicPage));
    await t.pumpWidget(header(false));
    expect(find.byKey(const ValueKey('public-channel-mark')), findsNothing);
    await t.pumpWidget(header(true));
    expect(find.byKey(const ValueKey('public-channel-mark')), findsOneWidget);
  });
}
