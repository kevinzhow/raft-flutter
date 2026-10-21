import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web MachineDetailPanel bulk bar: hover tooltips on Start / Stop /
/// Restart-Reset (the first and last say why when the Computer is offline),
/// and a workspace path that is an empty string shows as empty.
Widget _app(Widget child) => MaterialApp(
  theme: raftTheme(RaftFamily.elegant),
  home: Scaffold(body: child),
);

RaftComputerDetailData _data({required bool online}) => RaftComputerDetailData(
  id: 'c1',
  name: 'Studio',
  online: online,
  isComputer: true,
  slug: 'launch',
  runtimes: const [],
  createdLabel: 'today',
  canManage: true,
  agents: const [
    RaftComputerAgent(
      id: 'a1',
      name: 'Ada',
      subtitle: '',
      activity: 'offline',
      activityText: '',
    ),
  ],
);

RaftComputerDetailActions _actions({
  Future<List<RaftComputerWorkspace>> Function()? scan,
}) => RaftComputerDetailActions(
  rename: (_) async {},
  describe: (_) async {},
  scanWorkspaces: scan ?? () async => const [],
  deleteWorkspace: (_) async {},
  restart: () async {},
  deleteComputer: () async {},
  bulk: (_, _) async => 0,
);

Future<void> _selectAgent(
  WidgetTester tester,
  RaftComputerDetailData data,
) async {
  await tester.binding.setSurfaceSize(const Size(900, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _app(RaftComputerDetailView(data: data, actions: _actions())),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('computer-agents-select')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ada'));
  await tester.pumpAndSettle();
}

Finder _tip(String message) =>
    find.byWidgetPredicate((w) => w is RaftTooltip && w.message == message);

void main() {
  testWidgets('an online Computer explains what each bulk button does', (
    tester,
  ) async {
    await _selectAgent(tester, _data(online: true));
    expect(_tip('Start selected offline agents'), findsOneWidget);
    expect(_tip('Stop selected online agents'), findsOneWidget);
    expect(_tip('Restart or reset selected agents'), findsOneWidget);
  });

  testWidgets('an offline Computer says it must be online', (tester) async {
    await _selectAgent(tester, _data(online: false));
    expect(_tip('Computer must be online to start agents'), findsOneWidget);
    expect(_tip('Stop selected online agents'), findsOneWidget);
    expect(
      _tip('Computer must be online to restart or reset agents'),
      findsOneWidget,
    );
    expect(_tip('Start selected offline agents'), findsNothing);
  });

  testWidgets('an empty displayPath is shown as sent, not replaced', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        RaftComputerDetailView(
          data: _data(online: true),
          actions: _actions(
            scan: () async => const [
              RaftComputerWorkspace(
                directoryName: 'bot-1',
                label: 'bot',
                status: 'active',
                sizeLabel: '1 KB',
                filesLabel: '2 files',
                displayPath: '',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('computer-workspaces-scan')));
    await tester.pumpAndSettle();
    expect(find.text('~/.slock/agents/bot-1/'), findsNothing);
    expect(
      find.byKey(const ValueKey('computer-workspace-bot-1')),
      findsOneWidget,
    );
  });
}
