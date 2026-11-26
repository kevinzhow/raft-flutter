import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/feature_flag_client_facts.dart';
import '../data/raft_navigation_history.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_draft_index.dart';
import 'management_support.dart';
import 'resource_cards.dart';
import 'saved_sidebar_entry.dart';

const draftsSection = 'drafts';
const _flagKey = RaftFeatureFlags.draftsSection;
final _flags = Expando<({String identity, Future<bool> result})>();

Widget workspaceDraftsPage(
  WorkspaceController w, {
  required VoidCallback onBack,
}) => DraftsPage(
  key: ValueKey(pageIdentity(w)),
  controller: w,
  onBack: onBack,
  onUnavailable: () {
    if (w.section != draftsSection) return;
    w.navigation.selectSection('home', kind: RaftNavigationKind.replace);
    w.notifyListeners();
  },
);

Future<bool> _draftsEnabled(WorkspaceController w) {
  final identity = pageIdentity(w);
  final held = _flags[w.client];
  if (held != null && held.identity == identity) return held.result;
  final server = w.server?.id;
  if (server == null || w.client.user == null) return Future.value(false);
  final result = () async {
    try {
      final response = await w.client.post(
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(keys: const [_flagKey], serverId: server),
      );
      if (pageIdentity(w) != identity || response is! Map) return false;
      final flags = response['evaluations'];
      if (flags is! List) return false;
      final enabled = flags.whereType<Map>().any(
        (row) => row['key'] == _flagKey && row['enabled'] == true,
      );
      rememberServerFlag(w, _flagKey, enabled, identity);
      return enabled;
    } catch (_) {
      return pageIdentity(w) == identity &&
          cachedServerFlag(w, _flagKey) == true;
    }
  }();
  _flags[w.client] = (identity: identity, result: result);
  return result;
}

class WorkspaceHomeShortcuts extends StatelessWidget {
  const WorkspaceHomeShortcuts({
    super.key,
    required this.controller,
    required this.mobileHome,
    required this.onSelect,
  });

  final WorkspaceController controller;
  final bool mobileHome;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    // SidebarCellList's 8px lower inset includes the final cell margin.
    final trailingInset =
        RaftSpace.x2 -
        RaftTokens.of(context)
            .size('space.sidebarEntryMarginBottom', fallback: 1);
    return Column(
      children: [
        SavedSidebarEntry(
          key: const Key('nav-saved'),
          precededByEntry: mobileHome,
          controller: controller,
          onTap: () => onSelect('saved'),
        ),
        DraftsSidebarEntry(
          controller: controller,
          onOpen: () => onSelect(draftsSection),
        ),
        if (mobileHome) SizedBox(height: trailingInset),
      ],
    );
  }
}

class DraftsSidebarEntry extends StatefulWidget {
  const DraftsSidebarEntry({
    super.key,
    required this.controller,
    required this.onOpen,
  });

  final WorkspaceController controller;
  final VoidCallback onOpen;

  @override
  State<DraftsSidebarEntry> createState() => _DraftsSidebarEntryState();
}

class _DraftsSidebarEntryState extends State<DraftsSidebarEntry> {
  (WorkspaceController, String, int, Object, Object)? _request;
  Future<List<_PlacedDraft>?>? _placed;

  @override
  Widget build(BuildContext context) {
    final w = widget.controller;
    final identity = pageIdentity(w);
    return FutureBuilder<bool>(
      key: ValueKey(identity),
      initialData: cachedServerFlag(w, _flagKey),
      future: _draftsEnabled(w),
      builder: (context, flag) {
        if (flag.data != true) return const SizedBox.shrink();
        return ValueListenableBuilder<int>(
          valueListenable: w.composer.draftMembership,
          builder: (context, revision, _) {
            final request = (w, identity, revision, w.channels, w.dms);
            if (request != _request) {
              _request = request;
              _placed = _readPlacedDrafts(
                w,
                () =>
                    mounted &&
                    request == _request &&
                    identity == pageIdentity(w),
              );
            }
            return FutureBuilder<List<_PlacedDraft>?>(
              future: _placed,
              builder: (context, snapshot) => RaftNavItem(
                key: const ValueKey('nav-drafts'),
                label: raftText(context, 'Drafts'),
                glyph: RaftGlyph.pencil,
                role: RaftNavItemRole.saved,
                precededByEntry: true,
                viewportHeight: MediaQuery.sizeOf(context).height,
                selected:
                    !RaftAdaptiveWorkspace.compactOf(context) &&
                    w.section == draftsSection,
                accentSelection: true,
                count: snapshot.data?.length,
                onTap: widget.onOpen,
              ),
            );
          },
        );
      },
    );
  }
}

class DraftsPage extends StatefulWidget {
  const DraftsPage({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onUnavailable,
  });

  final WorkspaceController controller;
  final VoidCallback onBack, onUnavailable;

  @override
  State<DraftsPage> createState() => _DraftsPageState();
}

class _DraftsPageState extends State<DraftsPage> {
  WorkspaceController get w => widget.controller;
  late final identity = pageIdentity(w);
  late final _places = _load();

  Future<List<_PlacedDraft>?> _load() async {
    if (!await _draftsEnabled(w)) {
      if (mounted && identity == pageIdentity(w)) widget.onUnavailable();
      return null;
    }
    return _readPlacedDrafts(w, () => mounted && identity == pageIdentity(w));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<_PlacedDraft>?>(
    future: _places,
    builder: (context, snapshot) {
      if (identity != pageIdentity(w)) return const SizedBox.shrink();
      final rows = snapshot.data ?? const [];
      final count = rows.length;
      final compact = RaftAdaptiveWorkspace.compactOf(context);
      return ColoredBox(
        color: RaftTokens.of(context).canvas,
        child: Column(
          children: [
            RaftPanelHeaderBar(
              title: raftText(context, 'Drafts'),
              subtitle: raftFormat(
                context,
                count == 1 ? '{count} draft' : '{count} drafts',
                {'count': count},
              ),
              onBack: compact ? widget.onBack : null,
            ),
            Expanded(
              child: switch (snapshot.connectionState) {
                ConnectionState.done when snapshot.hasError => Center(
                  child: RaftEmptyState(
                    title: raftText(context, "Couldn't load your drafts."),
                    detail: '',
                  ),
                ),
                ConnectionState.done when count == 0 => Center(
                  child: RaftEmptyState(
                    glyph: RaftGlyph.pencil,
                    title: raftText(context, 'No drafts'),
                    detail: raftText(
                      context,
                      "A message you start and don't send waits here, from any conversation.",
                    ),
                  ),
                ),
                ConnectionState.done => ListView.separated(
                  key: const ValueKey('drafts-list-scroller'),
                  padding: raftScrollPadding(
                    context,
                    const EdgeInsets.only(
                      left: RaftSpace.x2,
                      top: RaftSpace.x2,
                      right: RaftSpace.x2,
                    ),
                  ),
                  itemCount: count,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: RaftSpace.half),
                  itemBuilder: (context, index) => _row(context, rows[index]),
                ),
                _ => const SizedBox.shrink(),
              },
            ),
          ],
        ),
      );
    },
  );

  Widget _row(BuildContext context, _PlacedDraft row) {
    final dm = row.channel.type == 'dm';
    final name = dm
        ? row.channel.string(
            'peerDisplayName',
            row.channel.string('peerName', row.channel.name),
          )
        : row.channel.name;
    final title = row.parentMessage == null
        ? name
        : raftFormat(context, 'Thread in {conversation}', {
            'conversation': dm ? name : '#$name',
          });
    final text = row.entry.text;
    final time = resourceRelativeTime(
      row.entry.updatedAt?.toIso8601String(),
      locale: Localizations.localeOf(context).toLanguageTag(),
    );
    return RaftInboxItem(
      key: ValueKey('draft-${row.entry.scope}'),
      semanticLabel: '$title, ${raftText(context, 'Draft:')} $text, $time',
      title: Text(title),
      leading: RaftConversationAvatarTile(
        channelGlyph: switch (row.channel.type) {
          'private' => RaftGlyph.lock,
          'joint' => RaftGlyph.gitBranch,
          _ => RaftGlyph.hash,
        },
        kind: row.parentMessage != null
            ? RaftConversationAvatarKind.thread
            : dm
            ? RaftConversationAvatarKind.dm
            : RaftConversationAvatarKind.channel,
      ),
      body: Row(
        children: [
          const RaftIcon(RaftGlyph.pencil, size: 14),
          const SizedBox(width: RaftSpace.x1),
          Expanded(
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      timestamp: time.isEmpty ? null : Text(time),
      timestampAtRest: true,
      onOpen: () {
        if (identity != pageIdentity(w) ||
            !w.can('viewChannel', resource: row.channel)) {
          return;
        }
        if (row.parentMessage case final message?) {
          unawaited(
            w.openThreadIdentity(
              parentChannelId: row.channel.id,
              parentMessageId: message,
            ),
          );
        } else {
          unawaited(w.selectChannel(row.channel));
        }
      },
    );
  }
}

Future<List<_PlacedDraft>?> _readPlacedDrafts(
  WorkspaceController w,
  bool Function() current,
) async {
  final principal = w.client.user?.id, server = w.server?.id;
  if (!current() || principal == null || server == null) {
    return null;
  }
  final cache = w.cache;
  await w.composer.flushed;
  if (!current()) return null;
  final drafts = cache is WorkspaceDraftIndex
      ? await (cache as WorkspaceDraftIndex).readDrafts(
          w.client.origin,
          principal,
          server,
        )
      : [
          for (final entry in w.drafts.entries)
            if (entry.value.trim().isNotEmpty)
              WorkspaceDraftEntry(entry.key, entry.value, null),
        ];
  final placed = <_PlacedDraft>[];
  for (var i = 0; i < drafts.length; i += 3) {
    if (!current()) return null;
    final rows = await Future.wait(
      drafts.skip(i).take(3).map((entry) => _placeDraft(w, entry, current)),
    );
    placed.addAll(rows.nonNulls);
  }
  return current() ? placed : null;
}

Future<_PlacedDraft?> _placeDraft(
  WorkspaceController w,
  WorkspaceDraftEntry entry,
  bool Function() current,
) async {
  final thread = entry.scope.startsWith('thread:');
  final parentMessage = thread ? entry.scope.substring('thread:'.length) : null;
  try {
    var channelId = entry.scope;
    if (parentMessage != null) {
      final result = await w.query(
        '/messages/context/${Uri.encodeComponent(parentMessage)}',
        query: {'before': 0, 'after': 0},
      );
      final messages = result is Map ? result['messages'] : null;
      final row = messages is List
          ? messages
                .whereType<Map>()
                .where((m) => m['id'] == parentMessage)
                .firstOrNull
          : null;
      if (row?['channelId'] case final String id) {
        channelId = id;
      } else {
        return null;
      }
    }
    if (!current()) return null;
    var channel = w.channelById(channelId);
    if (channel == null) {
      final result = await w.query(
        '/channels/${Uri.encodeComponent(channelId)}',
      );
      if (result is! Map<String, dynamic> || result['id'] != channelId) {
        return null;
      }
      channel = RaftChannel(result);
    }
    if (!current() ||
        channel.type == 'thread' ||
        channel.type == 'task' ||
        !w.can('viewChannel', resource: channel)) {
      return null;
    }
    return (entry: entry, channel: channel, parentMessage: parentMessage);
  } on RaftApiException {
    return null;
  }
}

typedef _PlacedDraft = ({
  WorkspaceDraftEntry entry,
  RaftChannel channel,
  String? parentMessage,
});
