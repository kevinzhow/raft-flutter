import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web v1.21.12 Computer detail: workspace real path, upgrade outcome lines,
/// the ask-an-admin line, agent selection labels and the bulk model tooltip.
Widget _app(Widget child, {Locale? locale}) => MaterialApp(
  theme: raftTheme(RaftFamily.elegant),
  home: Localizations(
    locale: locale ?? const Locale('en'),
    delegates: const [
      DefaultMaterialLocalizations.delegate,
      DefaultWidgetsLocalizations.delegate,
    ],
    child: Scaffold(body: child),
  ),
);

const _commands = RaftComputerCommandSet(
  install: 'install',
  setup: 'setup',
  status: 'raft-computer status',
  doctor: 'doctor',
  restart: 'restart',
  restartService: 'restart-service',
);

RaftComputerDetailData _data({
  bool online = true,
  bool canManage = true,
  RaftComputerService? service,
  RaftComputerUpgradeOutcome requestOutcome = RaftComputerUpgradeOutcome.none,
  RaftComputerVersionKind versionKind = RaftComputerVersionKind.current,
  List<RaftComputerAgent> agents = const [],
}) => RaftComputerDetailData(
  id: 'c1',
  name: 'Studio',
  online: online,
  isComputer: true,
  slug: 'launch',
  runtimes: const [],
  createdLabel: 'today',
  canManage: canManage,
  computerVersion: '1.0.3',
  versionKind: versionKind,
  availableVersion: '1.0.9',
  commands: _commands,
  service: service,
  requestOutcome: requestOutcome,
  agents: agents,
);

RaftComputerDetailActions _actions({
  Future<List<RaftComputerWorkspace>> Function()? scan,
  Future<bool> Function(List<String>)? changeModel,
}) => RaftComputerDetailActions(
  rename: (_) async {},
  describe: (_) async {},
  scanWorkspaces: scan ?? () async => const [],
  deleteWorkspace: (_) async {},
  restart: () async {},
  deleteComputer: () async {},
  bulk: (_, _) async => 0,
  changeModel: changeModel,
);

Future<void> _mount(
  WidgetTester tester,
  RaftComputerDetailData data,
  RaftComputerDetailActions actions, {
  Locale? locale,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _app(
      RaftComputerDetailView(data: data, actions: actions),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

String _plain(Finder f, WidgetTester tester) {
  final w = tester.widget(f);
  if (w is RaftCssText) return w.span?.toPlainText() ?? w.data ?? '';
  throw StateError('not a RaftCssText');
}

void main() {
  testWidgets('a workspace shows the real path the daemon reports', (
    tester,
  ) async {
    await _mount(
      tester,
      _data(),
      _actions(
        scan: () async => const [
          RaftComputerWorkspace(
            directoryName: 'bot-1',
            label: 'bot',
            status: 'active',
            sizeLabel: '1 KB',
            filesLabel: '2 files',
            displayPath: '/mnt/work/bot-1',
          ),
          RaftComputerWorkspace(
            directoryName: 'old-2',
            label: 'old',
            status: 'active',
            sizeLabel: '1 KB',
            filesLabel: '2 files',
          ),
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('computer-workspaces-scan')));
    await tester.pumpAndSettle();
    expect(find.text('/mnt/work/bot-1'), findsOneWidget);
    expect(find.text('~/.slock/agents/bot-1/'), findsNothing);
    // A daemon before 1.0.46 sends none: the old fixed location.
    expect(find.text('~/.slock/agents/old-2/'), findsOneWidget);
  });

  group('upgrade outcome', () {
    const failed = RaftComputerUpgradeOutcome.failed;
    const noResponse = RaftComputerUpgradeOutcome.noResponse;
    RaftComputerService card(RaftComputerUpgradeOutcome outcome) =>
        RaftComputerService(
          kind: RaftComputerServiceKind.commands,
          sentence:
              'v1.0.9 is available. Run these two commands on that '
              'machine to upgrade:',
          version: '1.0.9',
          outcome: outcome,
        );
    final outcomeKey = find.byKey(
      const ValueKey('computer-upgrade-request-outcome'),
    );

    testWidgets('failed request says what happened on the online card', (
      tester,
    ) async {
      await _mount(tester, _data(service: card(failed)), _actions());
      expect(
        _plain(outcomeKey, tester),
        "The upgrade didn't complete; still on v1.0.3. Run "
        'raft-computer status on that machine to check.',
      );
    });

    testWidgets('no response has its own line', (tester) async {
      await _mount(tester, _data(service: card(noResponse)), _actions());
      expect(
        _plain(outcomeKey, tester),
        'The last upgrade got no response from the Computer. Run '
        'raft-computer status on that machine to check.',
      );
    });

    testWidgets('a refused click that is unknown says try again later', (
      tester,
    ) async {
      await _mount(
        tester,
        _data(
          service: const RaftComputerService(
            kind: RaftComputerServiceKind.oneClick,
            sentence: 'v1.0.9 is available.',
            version: '1.0.9',
            webUpgradeOn: true,
            outcome: RaftComputerUpgradeOutcome.refusedUnknown,
          ),
        ),
        _actions(),
      );
      expect(
        _plain(outcomeKey, tester),
        "Can't upgrade right now. Try again later.",
      );
    });

    testWidgets('no outcome, no line', (tester) async {
      await _mount(
        tester,
        _data(service: card(RaftComputerUpgradeOutcome.none)),
        _actions(),
      );
      expect(outcomeKey, findsNothing);
    });

    testWidgets('the offline recovery card repeats the failed line', (
      tester,
    ) async {
      await _mount(
        tester,
        _data(online: false, requestOutcome: failed),
        _actions(),
      );
      expect(
        _plain(outcomeKey, tester),
        "The upgrade didn't complete; still on v1.0.3. Run "
        'raft-computer status on that machine to check.',
      );
    });

    testWidgets('the line follows the language', (tester) async {
      await _mount(
        tester,
        _data(online: false, requestOutcome: noResponse),
        _actions(),
        locale: const Locale('zh'),
      );
      expect(
        _plain(outcomeKey, tester),
        '上次升级没有收到 Computer 的回应。请在那台机器上运行 '
        'raft-computer status 查看。',
      );
    });
  });

  group('ask an admin', () {
    final line = find.byKey(const ValueKey('computer-upgrade-ask-admin'));
    testWidgets('a non-manager sees who can upgrade', (tester) async {
      await _mount(
        tester,
        _data(canManage: false, versionKind: RaftComputerVersionKind.outdated),
        _actions(),
      );
      expect(
        _plain(line, tester),
        'v1.0.9 is available. Ask an admin to upgrade.',
      );
    });

    testWidgets('a manager does not', (tester) async {
      await _mount(
        tester,
        _data(versionKind: RaftComputerVersionKind.outdated),
        _actions(),
      );
      expect(line, findsNothing);
    });
  });

  group('agent selection', () {
    List<RaftComputerAgent> agents() => const [
      RaftComputerAgent(
        id: 'a1',
        name: 'Ada',
        subtitle: '',
        activity: 'offline',
        activityText: '',
      ),
    ];

    testWidgets('rows are named buttons and toggle with Select/Deselect', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _mount(tester, _data(agents: agents()), _actions());
      await tester.tap(find.byKey(const ValueKey('computer-agents-select')));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Select Ada'), findsOneWidget);
      expect(find.bySemanticsLabel('Deselect Ada'), findsNothing);
      await tester.tap(find.text('Ada'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Deselect Ada'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('hover says what a click does', (tester) async {
      await _mount(tester, _data(agents: agents()), _actions());
      await tester.tap(find.byKey(const ValueKey('computer-agents-select')));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is RaftTooltip && w.message == 'Select agent',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Ada'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is RaftTooltip && w.message == 'Deselect agent',
        ),
        findsOneWidget,
      );
    });

    testWidgets('outside selection mode the row is a plain row', (
      tester,
    ) async {
      await _mount(tester, _data(agents: agents()), _actions());
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RaftTooltip &&
              (w.message == 'Select agent' || w.message == 'Deselect agent'),
        ),
        findsNothing,
      );
    });
  });

  testWidgets('Change model explains itself on hover', (tester) async {
    await _mount(
      tester,
      _data(
        agents: const [
          RaftComputerAgent(
            id: 'a1',
            name: 'Ada',
            subtitle: '',
            activity: 'offline',
            activityText: '',
          ),
        ],
      ),
      _actions(changeModel: (_) async => false),
    );
    await tester.tap(find.byKey(const ValueKey('computer-agents-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ada'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is RaftTooltip &&
            w.message == 'Change runtime and model for the selected agents',
      ),
      findsOneWidget,
    );
  });
}
