import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  Widget host(
    Widget child,
    Size size, {
    bool dark = false,
    TargetPlatform platform = TargetPlatform.android,
  }) => MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      theme: raftTheme(dark: dark).copyWith(platform: platform),
      home: Scaffold(
        body: SizedBox.fromSize(size: size, child: child),
      ),
    ),
  );

  const sizes = [Size(841, 701), Size(1180, 820), Size(390, 844)];
  const commands = RaftComputerCommandSet(
    install: 'curl -fsSL https://cdn.raft.build/install.sh | sh',
    setup: 'raft-computer setup /studio',
    status: 'raft-computer status',
    doctor: 'raft-computer doctor',
    restart: 'raft-computer restart',
    restartService: 'raft-computer service restart',
  );

  for (final size in sizes) {
    final platform = size.width >= 1000
        ? TargetPlatform.linux
        : TargetPlatform.android;
    for (final dark in raftThemeMatrix([false, true])) {
      final mode = dark ? 'dark' : 'light';
      testWidgets(
        'Wave 3B D1/D2/D3 widgets render without overflow at ${size.width.toInt()}x${size.height.toInt()} ($mode)',
        (t) async {
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1.0;
          addTearDown(() {
            t.view.resetPhysicalSize();
            t.view.resetDevicePixelRatio();
          });

          await t.pumpWidget(
            host(
              RaftAgentChatView(
                channels: [
                  RaftAgentChannelRow(
                    id: 'c1',
                    name: 'general',
                    description: 'Team updates and coordination',
                    onTap: () {},
                  ),
                  RaftAgentChannelRow(
                    id: 'c2',
                    name: 'private-ops',
                    type: 'private',
                    activityMuted: true,
                    muteFromSeq: 42,
                    onTap: () {},
                  ),
                  RaftAgentChannelRow(
                    id: 'c3',
                    name: 'shared-launch',
                    type: 'joint',
                    onTap: () {},
                  ),
                ],
                dms: const [
                  RaftAgentDmRow(
                    id: 'dm1',
                    name: 'Scout',
                    handle: 'scout',
                    avatar: RaftAvatarSlot(
                      name: 'Scout',
                      slot: RaftAvatarSlotContext.previewMini,
                    ),
                    timestamp: '5m ago',
                    preview: 'Finished reviewing the release checklist.',
                  ),
                ],
              ),
              size,
              dark: dark,
              platform: platform,
            ),
          );
          expect(t.takeException(), isNull);

          await t.pumpWidget(
            host(
              const RaftAgentChatView(channels: [], dms: []),
              size,
              dark: dark,
              platform: platform,
            ),
          );
          expect(find.text('No chats yet'), findsOneWidget);
          expect(t.takeException(), isNull);

          await t.pumpWidget(
            host(
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const RaftEnvVarsBlock(
                      vars: {
                        'OPENAI_API_KEY': 'sk-12345678',
                        'NODE_ENV': 'prod',
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 260,
                      child: RaftReminderListView(
                        reminders: [
                          RaftReminderItem(
                            title: 'Follow up on deployment',
                            relative: 'in 2 hours',
                            dateTime: 'Oct 12, 2:00 PM',
                            recurrence: 'Every weekday',
                            msgRef: '#launch:a1b2c3',
                            onOpenMessage: () {},
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(
                      height: 220,
                      child: RaftReminderListView(reminders: []),
                    ),
                  ],
                ),
              ),
              size,
              dark: dark,
              platform: platform,
            ),
          );
          expect(find.text('No reminders yet'), findsOneWidget);
          final reminder = find.ancestor(
            of: find.text('Follow up on deployment'),
            matching: find.byType(RaftCard),
          );
          final chip = find.byKey(const ValueKey('reminder-msg-ref'));
          final list = find.byType(RaftReminderListView).first;
          expect(
            t.getTopLeft(reminder).dx - t.getTopLeft(list).dx,
            platform == TargetPlatform.android ? 20 : 16,
          );
          expect(
            t.getBottomLeft(reminder).dy - t.getBottomLeft(chip).dy,
            platform == TargetPlatform.android ? 16 : 17,
          );
          expect(t.takeException(), isNull);

          await t.pumpWidget(
            host(
              RaftComputerDetailView(
                data: RaftComputerDetailData(
                  id: 'm1',
                  name: 'Studio Mac',
                  online: true,
                  isComputer: true,
                  slug: 'studio',
                  runtimes: const [('Claude Code', true)],
                  createdLabel: 'Oct 1',
                  canManage: true,
                  computerVersion: '1.0.48',
                  versionKind: RaftComputerVersionKind.current,
                  commands: commands,
                  service: const RaftComputerService(
                    kind: RaftComputerServiceKind.upToDate,
                    sentence: 'Computer is up to date.',
                    version: '1.0.48',
                  ),
                  agents: const [
                    RaftComputerAgent(
                      id: 'a1',
                      name: 'Martin',
                      subtitle: 'Claude Code · Sonnet',
                      activity: 'working',
                      activityText: 'Running parity suite checks',
                    ),
                    RaftComputerAgent(
                      id: 'a2',
                      name: 'Cindy',
                      subtitle: 'Codex',
                      activity: 'offline',
                      activityText: 'Offline',
                    ),
                  ],
                  runtimeDetection: const RaftRuntimeDetection(
                    status: RaftRuntimeDetectionStatus.incomplete,
                    unfinishedLabels: ['Codex'],
                  ),
                  canRescanRuntimes: true,
                ),
                actions: RaftComputerDetailActions(
                  rename: (_) async {},
                  describe: (_) async {},
                  scanWorkspaces: () async => const [
                    RaftComputerWorkspace(
                      directoryName: 'martin-1',
                      label: 'Martin',
                      status: 'active',
                      sizeLabel: '12 MB',
                      filesLabel: '42 files',
                      modifiedLabel: 'Oct 10',
                    ),
                    RaftComputerWorkspace(
                      directoryName: 'old-2',
                      label: 'Legacy Bot',
                      status: 'deleted',
                      sizeLabel: '4 MB',
                      filesLabel: '9 files',
                    ),
                    RaftComputerWorkspace(
                      directoryName: 'orphan-3',
                      label: 'unknown-dir',
                      status: 'orphan',
                      sizeLabel: '1 MB',
                      filesLabel: '2 files',
                    ),
                  ],
                  deleteWorkspace: (_) async {},
                  restart: () async {},
                  deleteComputer: () async {},
                  bulk: (_, _) async => 0,
                  rescanRuntimes: () async => true,
                ),
              ),
              size,
              dark: dark,
              platform: platform,
            ),
          );
          await t.pumpAndSettle();
          await t.ensureVisible(
            find.byKey(const ValueKey('computer-workspaces-scan')),
          );
          await t.tap(find.byKey(const ValueKey('computer-workspaces-scan')));
          await t.pumpAndSettle();
          expect(
            find.text('Agent archived. Workspace still on this Computer.'),
            findsOneWidget,
          );
          expect(find.text('No matching agent record'), findsOneWidget);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets('Wave 3B sibling hit targets do not steal taps', (t) async {
    t.view.physicalSize = const Size(390, 960);
    t.view.devicePixelRatio = 1.0;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
    var menuOpened = 0,
        siblingTapped = 0,
        channelTapped = 0,
        deleteTapped = 0,
        agentTapped = 0;
    await t.pumpWidget(
      host(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RaftPanelHeaderBar(
              title: 'Header',
              actions: [
                RaftButton(
                  key: const Key('sibling-action'),
                  uiVariant: RaftButtonVariant.ghost,
                  uiSize: RaftButtonSize.iconMd,
                  glyph: RaftGlyph.play,
                  tooltip: 'Start',
                  semanticLabel: 'Start',
                  onPressed: () => siblingTapped++,
                ),
                RaftOverflowMenuButton(
                  tooltip: 'More Actions',
                  entries: [
                    RaftMenuEntry(
                      label: 'Inspect',
                      onPressed: () => menuOpened++,
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(
              height: 160,
              child: RaftAgentChatView(
                channels: [
                  RaftAgentChannelRow(
                    id: 'ch-1',
                    name: 'general',
                    description: 'General room',
                    onTap: () => channelTapped++,
                  ),
                ],
                dms: const [],
              ),
            ),
            Expanded(
              child: RaftComputerDetailView(
                data: const RaftComputerDetailData(
                  id: 'c-hit',
                  name: 'Hitbox Box',
                  online: true,
                  isComputer: true,
                  slug: 'hitbox',
                  runtimes: [],
                  createdLabel: 'today',
                  canManage: true,
                  commands: commands,
                  agents: [
                    RaftComputerAgent(
                      id: 'a-hit',
                      name: 'Worker',
                      subtitle: 'Claude Code',
                      activity: 'online',
                      activityText: 'Online',
                    ),
                  ],
                ),
                actions: RaftComputerDetailActions(
                  rename: (_) async {},
                  describe: (_) async {},
                  scanWorkspaces: () async => const [
                    RaftComputerWorkspace(
                      directoryName: 'ws-hit',
                      label: 'Worker WS',
                      status: 'deleted',
                      sizeLabel: '1 KB',
                      filesLabel: '1 file',
                    ),
                  ],
                  deleteWorkspace: (_) async => deleteTapped++,
                  restart: () async {},
                  deleteComputer: () async {},
                  bulk: (_, _) async => 0,
                  openAgent: (_) => agentTapped++,
                ),
              ),
            ),
          ],
        ),
        const Size(390, 844),
      ),
    );
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('sibling-action')));
    await t.pump();
    expect(siblingTapped, 1);
    expect(find.text('Inspect'), findsNothing);

    await t.tap(find.byType(RaftOverflowMenuButton));
    await t.pumpAndSettle();
    expect(find.text('Inspect'), findsOneWidget);
    await t.tap(find.text('Inspect'));
    await t.pumpAndSettle();
    expect(menuOpened, 1);

    await t.tap(find.text('general'));
    await t.pump();
    expect(channelTapped, 1);
    expect(agentTapped, 0);

    await t.ensureVisible(find.byKey(const ValueKey('computer-agent-a-hit')));
    await t.tap(find.byKey(const ValueKey('computer-agent-a-hit')));
    await t.pump();
    expect(agentTapped, 1);

    await t.ensureVisible(
      find.byKey(const ValueKey('computer-workspaces-scan')),
    );
    await t.tap(find.byKey(const ValueKey('computer-workspaces-scan')));
    await t.pumpAndSettle();
    await t.ensureVisible(
      find.byKey(const ValueKey('computer-workspace-delete-ws-hit')),
    );
    await t.tap(find.byKey(const ValueKey('computer-workspace-delete-ws-hit')));
    await t.pumpAndSettle();
    expect(deleteTapped, 0); // confirmation modal opens before delete
    await t.pumpWidget(const SizedBox.shrink());
  });
}
