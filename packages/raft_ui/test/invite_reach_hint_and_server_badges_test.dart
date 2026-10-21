import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// English Material strings for any locale: the dialog's text fields need
/// MaterialLocalizations even when the app language is Chinese.
class _AnyLocale extends LocalizationsDelegate<MaterialLocalizations> {
  const _AnyLocale();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture(const DefaultMaterialLocalizations());
  @override
  bool shouldReload(
    covariant LocalizationsDelegate<MaterialLocalizations> old,
  ) => false;
}

class _AnyWidgetsLocale extends LocalizationsDelegate<WidgetsLocalizations> {
  const _AnyWidgetsLocale();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      SynchronousFuture(const DefaultWidgetsLocalizations());
  @override
  bool shouldReload(
    covariant LocalizationsDelegate<WidgetsLocalizations> old,
  ) => false;
}

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  theme: raftTheme(RaftFamily.elegant),
  home: Localizations(
    locale: locale,
    delegates: const [_AnyLocale(), _AnyWidgetsLocale()],
    child: Scaffold(body: child),
  ),
);

Widget _narrow(Widget child) =>
    Center(child: SizedBox(width: 360, child: child));

void main() {
  const hint =
      'Members you invite can DM and give instructions to every agent in this server. Keep personal agents in a separate server of your own.';

  testWidgets('the invite dialog says every member can reach every agent', (
    t,
  ) async {
    t.view.physicalSize = const Size(1280, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _app(RaftInviteHumanDialog(onClose: () {}, onSend: (_) async {})),
    );
    expect(
      find.byKey(const ValueKey('invite-agent-reach-hint')),
      findsOneWidget,
    );
    expect(find.text(hint), findsOneWidget);
    // The banner sits above the By email / By link switch, on both tabs.
    expect(
      t.getTopLeft(find.text(hint)).dy,
      lessThan(t.getTopLeft(find.text('By email')).dy),
    );
    await t.tap(find.text('By link'));
    await t.pumpAndSettle();
    expect(find.text(hint), findsOneWidget);
  });

  testWidgets('the invite hint is in Chinese from the Web catalog', (t) async {
    t.view.physicalSize = const Size(1280, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _app(
        RaftInviteHumanDialog(onClose: () {}, onSend: (_) async {}),
        locale: const Locale('zh'),
      ),
    );
    expect(
      find.text('被邀请的成员可以私信并指挥这个服务器里的所有 Agent。个人 Agent 请放在你自己单独的服务器里。'),
      findsOneWidget,
    );
  });

  testWidgets('a joint member row shows one badge per server after the name', (
    t,
  ) async {
    await t.pumpWidget(
      _app(
        _narrow(
          RaftMemberNameLine(
            labels: const ['Acme Partners', 'Home'],
            name: const Text('Pat', maxLines: 1),
          ),
        ),
      ),
    );
    expect(find.text('Pat'), findsOneWidget);
    expect(find.text('Acme Partners'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(
      t.getTopLeft(find.text('Pat')).dx,
      lessThan(t.getTopLeft(find.text('Acme Partners')).dx),
    );
    expect(
      t.getTopLeft(find.text('Acme Partners')).dx,
      lessThan(t.getTopLeft(find.text('Home')).dx),
    );
  });

  testWidgets('a local member row carries no badge strip', (t) async {
    await t.pumpWidget(
      _app(
        _narrow(RaftMemberNameLine(labels: const [], name: const Text('Pat'))),
      ),
    );
    expect(find.byKey(const ValueKey('member-server-badges')), findsNothing);
  });

  testWidgets('long server names never push the name to nothing', (t) async {
    await t.pumpWidget(
      _app(
        _narrow(
          RaftMemberNameLine(
            labels: ['A very long partner server name ' * 4],
            name: const Text('Pat Example', maxLines: 1),
          ),
        ),
      ),
    );
    expect(find.text('Pat Example'), findsOneWidget);
    expect(
      t.getSize(find.byKey(const ValueKey('member-server-badges'))).width,
      lessThanOrEqualTo(180),
    );
    expect(t.takeException(), isNull);
  });
}
