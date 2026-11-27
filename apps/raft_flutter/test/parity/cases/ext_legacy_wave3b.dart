import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_channel_files_store.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/features/source_channel_files_actions.dart';
import 'package:raft_flutter/features/source_channel_files_view.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';

final _fixture = jsonDecode(
  File('../../tool/parity-ext/fixtures/legacy-wave3b.json').readAsStringSync(),
) as Map<String, dynamic>;

Widget _stage(Widget child) => Builder(
  builder: (context) {
    final t = RaftTokens.of(context);
    return ColoredBox(
      color: t.ui.layerCanvas,
      child: Material(type: MaterialType.transparency, child: child),
    );
  },
);

String _relativeTimeEn(String iso, {required bool shortUnit, DateTime? now}) {
  final target = DateTime.parse(iso).toUtc();
  final diff = target.difference((now ?? DateTime.now()).toUtc());
  final absMs = diff.inMilliseconds.abs();
  const minute = 60000;
  const hour = 60 * minute;
  const day = 24 * hour;
  int value;
  String unit;
  if (absMs < hour) {
    value = (diff.inMilliseconds / minute).round();
    unit = shortUnit ? 'm' : 'minute';
  } else if (absMs < day) {
    value = (diff.inMilliseconds / hour).round();
    unit = shortUnit ? 'h' : 'hour';
  } else {
    value = (diff.inMilliseconds / day).round();
    unit = shortUnit ? 'd' : 'day';
  }
  if (shortUnit) {
    if (value == 0) return 'now';
    return value > 0 ? 'in $value$unit' : '${value.abs()}$unit ago';
  }
  final plural = value.abs() == 1 ? unit : '${unit}s';
  if (value > 0) return 'in $value $plural';
  return '${value.abs()} $plural ago';
}

DateTime _fixtureNow(ParityContext ctx) => DateTime.fromMillisecondsSinceEpoch(
  (ctx.fixtureData['locale']?['nowEpochMillis'] as num?)?.toInt() ??
      DateTime.now().millisecondsSinceEpoch,
  isUtc: true,
);

SourceTimeFormatter _timeFmt(ParityContext ctx) => SourceTimeFormatter(
  locale: 'en',
  preferredTimezone:
      (ctx.fixtureData['locale']?['timezone'] as String?) ?? 'Asia/Shanghai',
  preferredTimeFormat: SourceTimeFormat.twentyFourHour,
);

ParityCase _agentChat({required bool mobile, required bool empty}) =>
    ParityCase(
      widgets: const [
        'raft_ui:RaftAgentChatView',
        'raft_ui:RaftListRowGroup',
        'raft_ui:RaftListRow',
        'raft_ui:RaftProductEmptyState',
        'raft_ui:RaftCard',
      ],
      settle: const Duration(milliseconds: 300),
      build: (ctx) {
        final channels = empty
            ? const <RaftAgentChannelRow>[]
            : [
                for (final ch in (_fixture['channels'] as List).cast<Map>())
                  RaftAgentChannelRow(
                    id: ch['id'] as String,
                    name: ch['name'] as String,
                    description: ch['description'] as String?,
                    type: ch['type'] as String,
                    activityMuted: ch['activityMuted'] == true,
                    muteFromSeq: ch['muteFromSeq'],
                    onTap: () {},
                  ),
              ];
        final dms = empty
            ? const <RaftAgentDmRow>[]
            : [
                for (final dm in (_fixture['agentDms'] as List).cast<Map>())
                  RaftAgentDmRow(
                    id: dm['id'] as String,
                    name:
                        (dm['peerDisplayName'] as String?) ??
                        (dm['peerName'] as String),
                    handle: dm['peerName'] as String,
                    avatar: RaftAvatarSlot(
                      name:
                          (dm['peerDisplayName'] as String?) ??
                          (dm['peerName'] as String),
                      avatarUrl: dm['peerAvatarUrl'] as String?,
                      slot: RaftAvatarSlotContext.previewMini,
                    ),
                    timestamp: _relativeTimeEn(
                      (dm['lastMessageAt'] as String?) ??
                          (dm['createdAt'] as String),
                      shortUnit: true,
                      now: _fixtureNow(ctx),
                    ),
                    preview: dm['lastMessagePreview'] as String?,
                  ),
              ];
        return _stage(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              key: const ValueKey('wave3b-frame'),
              width: mobile ? 390 : 540,
              height: empty ? 480 : 680,
              child: RaftAgentChatView(channels: channels, dms: dms),
            ),
          ),
        );
      },
    );

ParityCase _agentEnvVars() => ParityCase(
  widgets: const [
    'raft_ui:RaftEnvVarsBlock',
    'raft_ui:RaftEnvVarChips',
    'raft_ui:RaftSectionEyebrow',
  ],
  settle: const Duration(milliseconds: 200),
  build: (ctx) {
    final agent = _fixture['agent'] as Map<String, dynamic>;
    final envVars = Map<String, String>.from(agent['envVars'] as Map);
    return _stage(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          key: const ValueKey('wave3b-frame'),
          width: 520,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: RaftEnvVarsBlock(vars: envVars),
          ),
        ),
      ),
    );
  },
);

ParityCase _agentReminders({required bool empty}) => ParityCase(
  widgets: const [
    'raft_ui:RaftReminderListView',
    'raft_ui:RaftProductEmptyState',
    'raft_ui:RaftCard',
    'raft_ui:RaftBadge',
  ],
  settle: const Duration(milliseconds: 200),
  build: (ctx) {
    final now = _fixtureNow(ctx);
    final fmt = _timeFmt(ctx);
    final reminders = empty
        ? const <RaftReminderItem>[]
        : [
            for (final r in (_fixture['reminders'] as List).cast<Map>())
              RaftReminderItem(
                title: r['title'] as String,
                relative: _relativeTimeEn(
                  r['fireAt'] as String,
                  shortUnit: false,
                  now: now,
                ),
                dateTime: fmt.shortDateTime(r['fireAt'] as String),
                recurrence:
                    (r['recurrence'] as Map?)?['description'] as String?,
                msgRef: r['msgRef'] as String?,
                onOpenMessage: r['msgPermalink'] != null ? () {} : null,
              ),
          ];
    return _stage(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          key: const ValueKey('wave3b-frame'),
          width: 520,
          height: 420,
          child: RaftReminderListView(reminders: reminders),
        ),
      ),
    );
  },
);

RaftComputerDetailData _computerData({required bool canManage}) {
  const runtimeLabels = {'claude': 'Claude Code', 'codex': 'Codex CLI'};
  const modelLabels = {'gpt-5-codex': 'GPT-5 Codex'};
  final m = _fixture['machine'] as Map<String, dynamic>;
  final agents = [
    for (final a in (_fixture['computerAgents'] as List).cast<Map>())
      RaftComputerAgent(
        id: a['id'] as String,
        name: (a['displayName'] as String?) ?? (a['name'] as String),
        subtitle: [
          runtimeLabels[a['runtime']] ?? (a['runtime'] as String),
          if (a['model'] != null)
            modelLabels[a['model']] ?? (a['model'] as String),
        ].join(' · '),
        activity: a['activity'] as String,
        activityText:
            (a['activityDetail'] as String?) ??
            ((a['activity'] == 'online') ? 'Online' : 'Offline'),
        avatarUrl: a['avatarUrl'] as String?,
      ),
  ];
  return RaftComputerDetailData(
    id: m['id'] as String,
    name: m['name'] as String,
    online: true,
    isComputer: true,
    slug: 'launch',
    runtimes: const [('Claude Code', true), ('Codex', true)],
    createdLabel: 'Jun 1',
    canManage: canManage,
    computerVersion: m['daemonVersion'] as String,
    versionKind: RaftComputerVersionKind.current,
    commands: const RaftComputerCommandSet(
      install: 'curl -fsSL https://cdn.raft.build/install.sh | sh',
      setup: 'raft-computer setup /launch',
      status: 'raft-computer status',
      doctor: 'raft-computer doctor',
      restart: 'raft-computer restart',
      restartService: 'raft-computer service restart',
    ),
    service: const RaftComputerService(
      kind: RaftComputerServiceKind.upToDate,
      sentence: 'Up to date.',
      version: '1.0.58',
    ),
    agents: agents,
  );
}

List<RaftComputerWorkspace> _workspaces() => [
  for (final w in (_fixture['workspaces'] as List).cast<Map>())
    RaftComputerWorkspace(
      directoryName: w['directoryName'] as String,
      label: (w['agentName'] as String?) ?? (w['directoryName'] as String),
      status: w['status'] as String,
      sizeLabel:
          '${((w['totalSizeBytes'] as num).toDouble() / (1024 * 1024)).toStringAsFixed(1)} MB',
      filesLabel: '${w['fileCount']} files',
      displayPath: w['displayPath'] as String?,
      modifiedLabel: w['directoryName'] == 'martin-ws'
          ? 'Modified Oct 10'
          : w['directoryName'] == 'archived-bot'
          ? 'Modified Sep 18'
          : 'Modified Aug 5',
    ),
];

ParityCase _computerSection({required String surface, required bool mobile}) =>
    ParityCase(
      widgets: const [
        'raft_ui:RaftComputerDetailView',
        'raft_ui:RaftListRowGroup',
        'raft_ui:RaftListRow',
        'raft_ui:RaftCard',
        'raft_ui:RaftBanner',
        'raft_ui:RaftBadge',
      ],
      settle: const Duration(milliseconds: 250),
      build: (ctx) {
        final width = mobile ? 390.0 : 640.0;
        final view = RaftComputerDetailView(
          data: _computerData(
            canManage:
                surface == 'computer-workspaces' ||
                surface == 'computer-service',
          ),
          actions: RaftComputerDetailActions(
            rename: (_) async {},
            describe: (_) async {},
            scanWorkspaces: () async => _workspaces(),
            deleteWorkspace: (_) async {},
            restart: () async {},
            deleteComputer: () async {},
            bulk: (_, _) async => 0,
          ),
        );
        return _stage(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: 1600,
              child: surface == 'computer-agent-rows'
                  ? SingleChildScrollView(
                      child: KeyedSubtree(
                        key: const ValueKey('wave3b-frame'),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Builder(builder: _agentRowsPreview),
                        ),
                      ),
                    )
                  : view,
            ),
          ),
        );
      },
      interact: switch (surface) {
        'computer-workspaces' => (t, ctx) async {
          await t.ensureVisible(
            find.byKey(const ValueKey('computer-workspaces-scan')),
          );
          await t.tap(find.byKey(const ValueKey('computer-workspaces-scan')));
          await t.pumpAndSettle();
        },
        'computer-service' => (t, ctx) async {
          await t.ensureVisible(
            find.byKey(const ValueKey('computer-section-service')),
          );
          await t.pumpAndSettle();
        },
        _ => null,
      },
    );

Widget _agentRowsPreview(BuildContext context) {
  final t = RaftTokens.of(context);
  final agents = _computerData(canManage: false).agents;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      RaftSectionHeader(
        label: raftText(context, 'Agents on this computer'),
        count: agents.length,
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 448;
          return RaftListRowGroup(
            children: [
              for (final a in agents)
                () {
                  final plainPresence =
                      a.activityText == 'Online' ||
                      a.activityText == 'Offline' ||
                      a.activityText == 'Likely online';
                  return RaftListRow(
                    key: ValueKey('computer-agent-${a.id}'),
                    variant: RaftListRowVariant.standard,
                    onPressed: () {},
                    children: [
                      RaftAvatarSlot(
                        name: a.name,
                        avatarUrl: a.avatarUrl,
                        slot: RaftAvatarSlotContext.listRow,
                      ),
                      RaftListRowBody(
                        children: [
                          RaftListRowTitle(a.name),
                          if (a.subtitle.isNotEmpty)
                            RaftListRowMeta(a.subtitle),
                          if (!wide &&
                              !plainPresence &&
                              a.activityText.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    height: 16,
                                    child: Center(
                                      child: RaftStatus(
                                        color: raftActivityDotColor(
                                          t,
                                          a.activity,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: RaftCssText(
                                      a.activityText,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: t.scale(
                                        RaftTypeScale.monoMeta,
                                        mono: true,
                                        color: t.ui.foregroundMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (wide || plainPresence)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RaftStatus(
                              color: raftActivityDotColor(t, a.activity),
                            ),
                            if (wide && a.activityText.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth * .42,
                                ),
                                child: RaftCssText(
                                  a.activityText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.scale(
                                    RaftTypeScale.monoMeta,
                                    mono: true,
                                    color: t.ui.foregroundHint,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  );
                }(),
            ],
          );
        },
      ),
    ],
  );
}

/// The raster thumbnail the fixture serves at `design.heic`'s `thumbnailUrl`.
final _rasterThumbnail = MemoryImage(
  File('../../tool/parity-ext/fixtures/announcement-picture.png')
      .readAsBytesSync(),
);

/// The fixture serves only raster thumbnail URLs; any other image read fails,
/// as in the Web host, and the row keeps its file glyph.
Future<SourceChannelImageLease?> _acquireRasterThumbnail(
  SourceChannelFileEntry file,
  bool Function() authorized,
  SourceChannelImageRendition rendition,
) async => file.metadata['thumbnailUrl'] == null
    ? null
    : SourceChannelImageLease(provider: _rasterThumbnail, release: () async {});

ParityCase _channelFiles({
  required bool mobile,
  required bool empty,
  bool raster = false,
}) => ParityCase(
  widgets: [
    'raft_flutter:SourceChannelFilesProjectionView',
    'raft_flutter:SourceChannelFileRow',
    if (raster) 'raft_flutter:SourceChannelFileThumbnail',
    'raft_flutter:ChannelFileGlyph',
    'raft_ui:RaftCard',
    'raft_ui:RaftProductEmptyState',
    'raft_ui:RaftButton',
  ],
  settle: const Duration(milliseconds: 300),
  interact: raster
      ? (t, ctx) async {
          final thumbnail = find.byType(SourceChannelFileThumbnail);
          await t.runAsync(
            () => precacheImage(_rasterThumbnail, t.element(thumbnail.first)),
          );
          await t.pump();
          final painted = t
              .widgetList<RawImage>(
                find.descendant(of: thumbnail, matching: find.byType(RawImage)),
              )
              .where((image) => image.image != null);
          expect(painted, hasLength(1), reason: 'design.heic thumbnail');
        }
      : null,
  build: (ctx) {
    final ch = _fixture['channel'] as Map<String, dynamic>;
    final chId = ch['id'] as String;
    final files = empty
        ? const []
        : (_fixture[raster ? 'rasterFiles' : 'channelFiles'] as List);
    final store = SourceChannelFilesStore(
      channelId: chId,
      authority: () => 'wave3b',
      get: (_, {query}) async => {'files': files, 'nextCursor': null},
    );
    ctx.onDispose(store.dispose);
    unawaited(store.load());
    return _stage(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          key: const ValueKey('wave3b-frame'),
          width: mobile ? 390 : 640,
          height: 360,
          child: SourceChannelFilesProjectionView(
            store: store,
            compact: raster,
            thumbnailBuilder: raster
                ? (file, authorized) => SourceChannelFileThumbnail(
                    file: file,
                    authorized: authorized,
                    acquireImage: _acquireRasterThumbnail,
                  )
                : null,
            formatCreatedAt: _timeFmt(ctx).shortDateTime,
            formatCompactDate: _timeFmt(ctx).compactDate,
            onPreview: (_) async {},
            onDownload: (_) async {},
            onOpenSource: (_) async {},
          ),
        ),
      ),
    );
  },
);

final Map<String, ParityCase> extLegacyWave3bCases = {
  for (final theme in const ['brutal', 'elegant-dark']) ...{
    for (final mobile in const [false, true]) ...{
      'components.legacy-wave3b.agent-chat.${mobile ? 'phone' : 'desktop'}.$theme':
          _agentChat(mobile: mobile, empty: false),
      'components.legacy-wave3b.agent-chat-empty.${mobile ? 'phone' : 'desktop'}.$theme':
          _agentChat(mobile: mobile, empty: true),
      'components.legacy-wave3b.computer-agent-rows.${mobile ? 'phone' : 'desktop'}.$theme':
          _computerSection(surface: 'computer-agent-rows', mobile: mobile),
      'components.legacy-wave3b.channel-files.${mobile ? 'phone' : 'desktop'}.$theme':
          _channelFiles(mobile: mobile, empty: false),
      'components.legacy-wave3b.channel-files-raster.${mobile ? 'phone' : 'desktop'}.$theme':
          _channelFiles(mobile: mobile, empty: false, raster: true),
    },
    'components.legacy-wave3b.agent-env-vars.desktop.$theme': _agentEnvVars(),
    'components.legacy-wave3b.agent-reminders.desktop.$theme': _agentReminders(
      empty: false,
    ),
    'components.legacy-wave3b.agent-reminders-empty.desktop.$theme':
        _agentReminders(empty: true),
    'components.legacy-wave3b.computer-workspaces.desktop.$theme':
        _computerSection(surface: 'computer-workspaces', mobile: false),
    'components.legacy-wave3b.computer-service.desktop.$theme':
        _computerSection(surface: 'computer-service', mobile: false),
    'components.legacy-wave3b.channel-files-empty.desktop.$theme':
        _channelFiles(mobile: false, empty: true),
  },
};
