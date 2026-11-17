// Web v1.24 settings shell: level-2 sub-pages with a breadcrumb, Search
// settings, and `/settings/<tab>#<id>` anchors (SettingsPanel.tsx,
// SettingsSubPageTitle.tsx, features/settings/search/SettingsSearch.tsx,
// features/settings/shared/useScrollToSettingsSection.ts).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/settings_anchor.dart';
import 'package:raft_flutter/features/settings_page.dart';
import 'package:raft_flutter/features/settings_search.dart';
import 'package:raft_flutter/features/settings_sub_pages.dart';
import 'package:raft_ui/raft_ui.dart';

class _Opened {
  final results = <(String, String, bool)>[];
  final everywhere = <String>[];
  SettingsSearchHost host({bool Function(String id)? shown}) =>
      SettingsSearchHost(
        shown: shown ?? (_) => true,
        serverName: 'Acme',
        open: (page, id, {required fromKeyboard}) =>
            results.add((page, id, fromKeyboard)),
        searchEverywhere: everywhere.add,
      );
}

List<RaftSettingsDestination> destinations({Widget? accountBody}) => [
  RaftSettingsDestination(
    'account',
    'Account',
    RaftGlyph.user,
    (_) => accountBody ?? const Text('Account body'),
  ),
  RaftSettingsDestination(
    'language-region',
    'Language & Region',
    RaftGlyph.languages,
    (_) => const Text('Language body'),
  ),
  RaftSettingsDestination(
    'appearance',
    'Appearance',
    RaftGlyph.type,
    (_) => const Text('Appearance body'),
  ),
  RaftSettingsDestination(
    'server-notifications',
    'Notifications',
    RaftGlyph.bell,
    (_) => const Text('Server notifications body'),
    group: 'On Acme',
  ),
];

Future<void> pump(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(1280, 800),
  Locale? locale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: raftTheme(),
      home: Scaffold(body: page),
    ),
  );
  await tester.pumpAndSettle();
}

Finder row(String id) => find.byKey(SettingsSearchResults.rowKey(id));
Finder get field => find.byKey(SettingsSearchField.fieldKey);

final deleteAccount = SettingsSubPage(
  id: 'account/delete',
  parentTab: 'account',
  title: 'Delete account',
);
Widget deleteBody(BuildContext _) => const Text('Delete body');

void main() {
  group('level-2 sub-page', () {
    testWidgets(
      'desktop header reads Account > Delete account and the tab link goes back',
      (tester) async {
        final tabs = <String?>[];
        await pump(
          tester,
          RaftSettingsPage(
            destinations: destinations(),
            subPage: deleteAccount,
            subPageBody: deleteBody,
            onMobileLocationChanged: tabs.add,
          ),
        );
        expect(find.byKey(const Key('settings-breadcrumb')), findsOneWidget);
        expect(find.text('Delete body'), findsOneWidget);
        expect(find.text('Account body'), findsNothing);
        // The tab link and the current page, one trail.
        final tab = find.byKey(const Key('settings-breadcrumb-tab'));
        expect(
          find.descendant(of: tab, matching: find.text('Account')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('settings-breadcrumb')),
            matching: find.text('Delete account'),
          ),
          findsOneWidget,
        );
        // The list keeps Account as the open row.
        expect(
          find.byKey(const ValueKey('workspace-settings-nav-account')),
          findsOneWidget,
        );
        await tester.tap(tab);
        await tester.pumpAndSettle();
        expect(tabs, ['account']);
      },
    );

    testWidgets(
      'a phone shows the plain title and Back returns to the parent tab',
      (tester) async {
        var back = 0;
        await pump(
          tester,
          RaftSettingsPage(
            destinations: destinations(),
            subPage: deleteAccount,
            subPageBody: deleteBody,
            mobileRoot: false,
            onSubPageBack: () => back++,
          ),
          size: const Size(390, 844),
        );
        expect(find.byKey(const Key('settings-breadcrumb')), findsNothing);
        expect(find.text('Delete account'), findsOneWidget);
        expect(find.text('Delete body'), findsOneWidget);
        await tester.tap(find.byKey(const Key('mobile-settings-back')));
        await tester.pumpAndSettle();
        expect(back, 1, reason: 'Back leaves the page for its tab');
      },
    );

    testWidgets('a row inside the tab opens the sub-page by id', (
      tester,
    ) async {
      final opened = <(String, Map<String, String>)>[];
      await pump(
        tester,
        RaftSettingsPage(
          destinations: destinations(
            accountBody: Builder(
              builder: (context) => GestureDetector(
                key: const Key('row'),
                onTap: () => openSettingsSubPage(
                  context,
                  'account/delete',
                  query: const {'from': 'row'},
                ),
                child: const Text('Delete this account'),
              ),
            ),
          ),
          onSubPageOpen: (id, query) => opened.add((id, query)),
        ),
      );
      await tester.tap(find.byKey(const Key('row')));
      expect(opened.single.$1, 'account/delete');
      expect(opened.single.$2, {'from': 'row'});
    });

    test(
      'the registry knows account/delete and nothing else is a sub-page',
      () {
        expect(settingsSubPageFor('account', 'delete')?.id, 'account/delete');
        expect(settingsSubPageFor('account', 'other'), isNull);
        expect(settingsSubPageFor('appearance', 'delete'), isNull);
        expect(settingsSubPageFor('account', null), isNull);
      },
    );
  });

  group('search', () {
    testWidgets(
      'the field is pinned above the list; text replaces the list by results',
      (tester) async {
        final opened = _Opened();
        await pump(
          tester,
          RaftSettingsPage(destinations: destinations(), search: opened.host()),
        );
        expect(field, findsOneWidget);
        expect(
          find.byKey(const ValueKey('workspace-settings-nav-appearance')),
          findsOneWidget,
        );
        await tester.enterText(field, 'font');
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('workspace-settings-nav-appearance')),
          findsNothing,
          reason: 'the results take the list place',
        );
        expect(find.byKey(SettingsSearchResults.listKey), findsOneWidget);
        expect(row('message-font-size'), findsOneWidget);
        // Name over "Page · Section".
        expect(find.text('Appearance · Appearance'), findsOneWidget);
        // Clearing brings the list back and keeps the field focused.
        await tester.tap(find.byKey(SettingsSearchField.clearKey));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('workspace-settings-nav-appearance')),
          findsOneWidget,
        );
        expect(find.byKey(SettingsSearchResults.listKey), findsNothing);
      },
    );

    testWidgets('only settings on pages this person sees are found', (
      tester,
    ) async {
      final opened = _Opened();
      await pump(
        tester,
        RaftSettingsPage(
          destinations: destinations(),
          search: opened.host(shown: (id) => id != 'timezone'),
        ),
      );
      await tester.enterText(field, 'zone');
      await tester.pumpAndSettle();
      expect(row('timezone'), findsNothing, reason: 'hidden for this person');
      await tester.enterText(field, 'plan');
      await tester.pumpAndSettle();
      // Plan lives on a page this role does not have.
      expect(row('plan'), findsNothing);
      expect(find.byKey(SettingsSearchResults.emptyKey), findsOneWidget);
      // A page on the server is named after it.
      await tester.enterText(field, 'mute');
      await tester.pumpAndSettle();
      expect(row('mute-server'), findsOneWidget);
      expect(find.textContaining('Notifications on Acme'), findsOneWidget);
    });

    testWidgets(
      'a click opens the page at the setting and the open one stays selected',
      (tester) async {
        final opened = _Opened();
        await pump(
          tester,
          RaftSettingsPage(destinations: destinations(), search: opened.host()),
        );
        await tester.enterText(field, 'font');
        await tester.pumpAndSettle();
        await tester.tap(row('message-font-size'));
        await tester.pumpAndSettle();
        expect(opened.results, [('appearance', 'message-font-size', false)]);
        expect(find.text('Appearance body'), findsOneWidget);
      },
    );

    testWidgets('Enter opens the first result as a keyboard jump', (
      tester,
    ) async {
      final opened = _Opened();
      await pump(
        tester,
        RaftSettingsPage(destinations: destinations(), search: opened.host()),
      );
      await tester.enterText(field, 'language');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(opened.results.single.$3, isTrue);
      expect(opened.results.single.$1, 'language-region');
    });

    testWidgets(
      'Down moves into the results, Up and Escape return to the field',
      (tester) async {
        final opened = _Opened();
        await pump(
          tester,
          RaftSettingsPage(destinations: destinations(), search: opened.host()),
        );
        await tester.tap(field);
        await tester.enterText(field, 'time');
        await tester.pumpAndSettle();
        FocusNode? focused() => FocusManager.instance.primaryFocus;
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        final first = focused();
        expect(first?.debugLabel, startsWith('settings-search-'));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(focused(), isNot(first), reason: 'the second result');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(focused(), first);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(focused()?.debugLabel, 'settings-search', reason: 'the field');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(focused()?.debugLabel, 'settings-search');
        // Enter on a focused result opens it as a keyboard jump.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(opened.results.last.$3, isTrue);
      },
    );

    testWidgets(
      'Escape clears the query; on an empty field it leaves the field',
      (tester) async {
        final opened = _Opened();
        await pump(
          tester,
          RaftSettingsPage(destinations: destinations(), search: opened.host()),
        );
        await tester.tap(field);
        await tester.enterText(field, 'font');
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(field).controller!.text, isEmpty);
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'settings-search',
          reason: 'the field keeps focus while it had text',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          isNot('settings-search'),
        );
      },
    );

    testWidgets('no match offers Search everywhere with the query', (
      tester,
    ) async {
      final opened = _Opened();
      await pump(
        tester,
        RaftSettingsPage(destinations: destinations(), search: opened.host()),
      );
      await tester.enterText(field, '  qqqq ');
      await tester.pumpAndSettle();
      expect(find.text('No settings match "qqqq"'), findsOneWidget);
      await tester.tap(find.byKey(SettingsSearchResults.everywhereKey));
      expect(opened.everywhere, ['qqqq']);
    });

    testWidgets('Ctrl+F focuses and selects the field', (tester) async {
      final opened = _Opened();
      await pump(
        tester,
        RaftSettingsPage(destinations: destinations(), search: opened.host()),
      );
      await tester.enterText(field, 'abc');
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        isNot('settings-search'),
        reason: 'the field is left before the shortcut',
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'settings-search');
      final controller = tester.widget<TextField>(field).controller!;
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 3),
      );
    });

    testWidgets('the query survives opening a result and Back on a phone', (
      tester,
    ) async {
      final opened = _Opened();
      await pump(
        tester,
        RaftSettingsPage(
          destinations: destinations(),
          search: opened.host(),
          mobileRoot: true,
        ),
        size: const Size(390, 844),
      );
      expect(field, findsOneWidget, reason: 'on the Settings root');
      await tester.enterText(field, 'font');
      await tester.pumpAndSettle();
      await tester.tap(row('message-font-size'));
      await tester.pumpAndSettle();
      expect(find.text('Appearance body'), findsOneWidget);
      await tester.tap(find.byKey(const Key('mobile-settings-back')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, 'font');
      expect(row('message-font-size'), findsOneWidget);
    });

    testWidgets('Chinese display language searches the zh words', (
      tester,
    ) async {
      final opened = _Opened();
      await pump(
        tester,
        RaftSettingsPage(destinations: destinations(), search: opened.host()),
        locale: const Locale('zh'),
      );
      await tester.enterText(field, '字号');
      await tester.pumpAndSettle();
      expect(row('message-font-size'), findsOneWidget);
    });
  });

  group('list rows', () {
    List<RaftSettingsDestination> rows() => [
      ...destinations(),
      RaftSettingsDestination.action(
        'documentation',
        'Documentation',
        RaftGlyph.bookOpenText,
        group: 'Resources',
        external: true,
        onOpen: () {},
      ),
    ];

    testWidgets(
      'a row that leaves Raft ends in the arrow and says it opens in a new tab',
      (tester) async {
        await pump(tester, RaftSettingsPage(destinations: rows()));
        final row = find.byKey(
          const ValueKey('workspace-settings-nav-documentation'),
        );
        expect(row, findsOneWidget);
        expect(
          find.descendant(
            of: row,
            matching: find.byWidgetPredicate(
              (w) => w is RaftIcon && w.glyph == RaftGlyph.arrowUpRight,
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp('Documentation .opens in a new tab.')),
          findsOneWidget,
        );
        // The rows that stay in Raft have no mark.
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('workspace-settings-nav-account')),
            matching: find.byWidgetPredicate(
              (w) => w is RaftIcon && w.glyph == RaftGlyph.arrowUpRight,
            ),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'the server notifications row has its own accessible name and says Muted',
      (tester) async {
        await pump(
          tester,
          RaftSettingsPage(
            destinations: [
              ...destinations().take(3),
              RaftSettingsDestination(
                'server-notifications',
                'Notifications',
                RaftGlyph.bell,
                (_) => const Text('Server notifications body'),
                group: 'On Acme',
                semanticLabel: 'Notifications on Acme',
                trailingText: 'Muted',
              ),
            ],
          ),
        );
        expect(
          find.bySemanticsLabel(RegExp('Notifications on Acme')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(
              const ValueKey('workspace-settings-nav-server-notifications'),
            ),
            matching: find.text('Muted'),
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('anchors', () {
    Widget tall({String id = 'two-step', Duration? lateBy}) =>
        _Tall(id, lateBy);

    testWidgets('a link opens the tab scrolled to the section', (tester) async {
      await pump(
        tester,
        RaftSettingsPage(
          destinations: destinations(accountBody: tall()),
          anchor: 'two-step',
        ),
      );
      final top = tester
          .getTopLeft(find.byKey(const Key('anchor-two-step')))
          .dy;
      expect(top, lessThan(200), reason: 'scrolled to the top of the tab');
    });

    testWidgets('a section that renders late is waited for, up to 5 seconds', (
      tester,
    ) async {
      await pump(
        tester,
        RaftSettingsPage(
          destinations: destinations(
            accountBody: tall(lateBy: const Duration(seconds: 3)),
          ),
          anchor: 'two-step',
        ),
      );
      expect(find.byKey(const Key('anchor-two-step')), findsNothing);
      await tester.pump(const Duration(seconds: 3, milliseconds: 100));
      await tester.pump();
      await tester.pump();
      final top = tester
          .getTopLeft(find.byKey(const Key('anchor-two-step')))
          .dy;
      expect(top, lessThan(200));
    });

    testWidgets(
      'a section later than 5 seconds is dropped, with no timer left',
      (tester) async {
        await pump(
          tester,
          RaftSettingsPage(
            destinations: destinations(
              accountBody: tall(lateBy: const Duration(seconds: 6)),
            ),
            anchor: 'two-step',
          ),
        );
        await tester.pump(const Duration(seconds: 7));
        await tester.pump();
        await tester.pump();
        final top = tester
            .getTopLeft(find.byKey(const Key('anchor-two-step')))
            .dy;
        expect(top, greaterThan(400), reason: 'the tab stayed at its top');
      },
    );

    testWidgets(
      'a keyboard jump moves focus to the section; a pointer jump does not',
      (tester) async {
        await pump(
          tester,
          RaftSettingsPage(
            destinations: destinations(accountBody: tall()),
            anchor: 'two-step',
            anchorFromKeyboard: true,
          ),
        );
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'settings-anchor',
        );
      },
    );

    testWidgets('a pointer jump leaves focus alone', (tester) async {
      await pump(
        tester,
        RaftSettingsPage(
          destinations: destinations(accountBody: tall()),
          anchor: 'two-step',
        ),
      );
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        isNot('settings-anchor'),
      );
    });

    testWidgets('a result opened again is a new jump', (tester) async {
      Widget page(int revision) => RaftSettingsPage(
        destinations: destinations(accountBody: tall()),
        anchor: 'two-step',
        anchorRevision: revision,
      );
      await pump(tester, page(0));
      final scrollable = find.byType(Scrollable).last;
      final controller = tester.state<ScrollableState>(scrollable);
      controller.position.jumpTo(0);
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(body: page(1)),
        ),
      );
      await tester.pumpAndSettle();
      final top = tester
          .getTopLeft(find.byKey(const Key('anchor-two-step')))
          .dy;
      expect(top, lessThan(200));
    });
  });
}

/// A tab as tall as a real one with a section far down it.
class _Tall extends StatefulWidget {
  const _Tall(this.id, this.lateBy);
  final String id;
  final Duration? lateBy;
  @override
  State<_Tall> createState() => _TallState();
}

class _TallState extends State<_Tall> {
  late bool loaded = widget.lateBy == null;

  @override
  void initState() {
    super.initState();
    final lateBy = widget.lateBy;
    if (lateBy != null) {
      Future<void>.delayed(lateBy, () {
        if (mounted) setState(() => loaded = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 1500),
      if (loaded)
        RaftSettingsAnchor(
          id: widget.id,
          child: const SizedBox(
            key: Key('anchor-two-step'),
            height: 80,
            child: Text('Two-step verification'),
          ),
        ),
      const SizedBox(height: 1500),
    ],
  );
}
