// raft-flutter parity EXTENSION suite builders (tool/parity-ext): the desktop
// search overlay (rail Search / Cmd+K quick switcher) at 1280x800. NOT
// official cases; ids are `components.search-overlay.<extCase>.<theme>`,
// dispatched on props.extCase like tool/parity-ext/host/SearchOverlayCases.tsx.
//
// Data: tool/parity-ext/fixtures/search-overlay.json (fixtures['ext:search-overlay']),
// the same file the React render host imports. The switcher is opened through
// the real QuickSwitcherHost over a WorkspaceController filled from it.
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/recent_conversations.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/quick_switcher_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../parity_harness.dart';
import 'screens/screen_fixture.dart';

Map<String, dynamic> _fx(ParityContext ctx) =>
    ctx.fixtures['ext:search-overlay'] as Map<String, dynamic>;

List<Map<String, dynamic>> _rows(dynamic list) => [
  for (final row in list as List) Map<String, dynamic>.from(row as Map),
];

Object? _search(ParityContext ctx, Map<String, dynamic>? query) {
  final mode = ctx.props['searchMode'];
  if (mode == 'pending') return ScreenFixtureClient.pending;
  if (mode == 'error') {
    throw const RaftApiException('Search failed', status: 500);
  }
  final search = _fx(ctx)['search'] as Map<String, dynamic>;
  final q = '${query?['q'] ?? ''}'.trim().toLowerCase();
  final sender = query?['senderId'];
  for (final rule in search['responses'] as List) {
    final r = rule as Map;
    if (r['q'] == q && (r['senderId'] == null || r['senderId'] == sender)) {
      if (r['senderId'] == null && sender != null) continue;
      return r['body'];
    }
  }
  return search['fallback'];
}

class _Mounted {
  _Mounted(this.w, this.host);
  final WorkspaceController w;
  final QuickSwitcherHost host;
}

_Mounted _mount(ParityContext ctx) {
  SharedPreferences.setMockInitialValues({});
  final fx = _fx(ctx);
  final wire = ScreenWire(ctx.fixtureData);
  final serverId = fx['serverId'] as String;
  final user = {
    ...wire.me(),
    'id': fx['userId'],
    'name': 'artin',
    'displayName': 'artin',
  };
  final recents =
      (fx['recentScenarios'] as Map)[ctx.props['recents'] ?? 'default'] as Map;
  final activity = Map<String, dynamic>.from(recents['activity'] as Map);
  List<Map<String, dynamic>> withActivity(List<Map<String, dynamic>> rows) => [
    for (final row in rows)
      {
        ...row,
        'joined': true,
        if (activity[row['id']] != null) 'lastMessageAt': activity[row['id']],
      },
  ];
  final channels = withActivity(_rows(fx['channels']));
  final dms = withActivity(_rows(fx['dmChannels']));
  final members = _rows(fx['members']);
  final agents = [
    for (final a in _rows(fx['agents']))
      {...a, 'serverId': serverId, 'status': 'active'},
  ];
  final client = ScreenFixtureClient(
    (method, path, query) {
      if (path == '/messages/search') return _search(ctx, query);
      if (path == '/servers/$serverId/members') return members;
      if (path == '/agents') return agents;
      if (path == '/servers/$serverId/machines') {
        return {'machines': _rows(fx['machines'])};
      }
      return wire.common(method, path, query);
    },
    user: user,
    server: serverId,
  );
  final w = WorkspaceController(client);
  final server = RaftRecord({
    ...wire.server(),
    'id': serverId,
    'slug': fx['slug'],
  });
  w
    ..servers = [server]
    ..server = server
    ..channels = [for (final c in channels) RaftChannel(c)]
    ..dms = [for (final c in dms) RaftChannel(c)];
  w.messageDomain.ledger.switchServer(serverId);
  final store = RecentConversationStore();
  final scope = RecentConversationScope(
    client.origin,
    serverId,
    '${fx['userId']}',
  );
  for (final id in (recents['channelIds'] as List).reversed) {
    store.recordVisit(scope, id as String);
  }
  final memory = SearchMemoryStore();
  final now = DateTime.fromMillisecondsSinceEpoch(
    (ctx.fixtureData['locale'] as Map)['nowEpochMillis'] as int,
    isUtc: true,
  );
  final host = QuickSwitcherHost(
    controller: w,
    clock: () => now,
    recents: store,
    searchMemory: memory,
    actions: QuickSwitcherActions(
      openConversation: (_) async {},
      openDirectory: (_, _) {},
      openThread:
          ({
            required parentChannelId,
            required parentMessageId,
            required messageId,
            required threadChannelId,
          }) async {},
      openMessage: (_, _) async {},
      searchAll: (_) {},
    ),
  );
  final sender = ctx.props['senderId'];
  final memoryScope = host.memoryScope;
  if (sender != null && memoryScope != null) {
    memory.saveState(
      memoryScope,
      SearchStateSnapshot(senderKey: 'user:$sender'),
    );
  }
  return _Mounted(w, host);
}

class _Opener extends StatefulWidget {
  const _Opener({required this.ctx});
  final ParityContext ctx;
  @override
  State<_Opener> createState() => _OpenerState();
}

class _OpenerState extends State<_Opener> {
  late final _Mounted mount = _mount(widget.ctx);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) mount.host.open(context);
    });
  }

  @override
  void dispose() {
    mount.host.dispose();
    mount.w.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Colors.white, child: SizedBox.expand());
}

Widget _overlay(ParityContext ctx) => _Opener(ctx: ctx);

ParityCase _case() => ParityCase(
  widgets: const [
    'raft_flutter:QuickSwitcher',
    'raft_flutter:SearchFilterBar',
    'raft_ui:RaftQuickSwitcherFrame',
    'raft_ui:RaftQuickSwitcherHit',
  ],
  notes: 'Extension suite (not official).',
  settle: const Duration(milliseconds: 600),
  build: _overlay,
);

/// Every extension search-overlay case, keyed by id (3 themes each).
final Map<String, ParityCase> extSearchOverlayCases = {
  for (final key in _extCaseKeys)
    for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
      'components.search-overlay.$key.$theme': _case(),
};

const _extCaseKeys = [
  'home',
  'home-empty',
  'query',
  'query-exact',
  'query-selected',
  'query-no-results',
  'query-loading',
  'query-error',
  'query-thread-group',
  'filters-sender',
];
