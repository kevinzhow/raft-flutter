import 'dart:async';
import 'dart:convert';

import 'package:raft_client/raft_client.dart';

import '../../data/device_preferences.dart';
import 'artifact_models.dart';

enum ArtifactDashboardSort { opened, updated }

enum ArtifactDashboardColumn {
  author(200),
  updated(124),
  comments(84),
  visibility(196);

  const ArtifactDashboardColumn(this.defaultWidth);
  final double defaultWidth;
  static const double minWidth = 64, maxWidth = 480;
}

class ArtifactDashboardPreferences {
  const ArtifactDashboardPreferences({
    this.grid = true,
    this.sort = ArtifactDashboardSort.opened,
    this.widths = const {},
  });

  static const key = 'raft:artifacts:dashboard:v1';
  final bool grid;
  final ArtifactDashboardSort sort;
  final Map<ArtifactDashboardColumn, double> widths;

  double width(ArtifactDashboardColumn column) =>
      widths[column] ?? column.defaultWidth;

  ArtifactDashboardPreferences copyWith({
    bool? grid,
    ArtifactDashboardSort? sort,
    Map<ArtifactDashboardColumn, double>? widths,
  }) => ArtifactDashboardPreferences(
    grid: grid ?? this.grid,
    sort: sort ?? this.sort,
    widths: widths ?? this.widths,
  );

  static ArtifactDashboardPreferences read() {
    try {
      final raw = DevicePreferences.current?.getString(key);
      final data = raw == null ? null : jsonDecode(raw);
      if (data is Map) {
        final stored = data['widths'];
        return ArtifactDashboardPreferences(
          grid: data['view'] != 'list',
          sort: data['listSort'] == 'updated'
              ? ArtifactDashboardSort.updated
              : ArtifactDashboardSort.opened,
          widths: {
            if (stored is Map)
              for (final column in ArtifactDashboardColumn.values)
                if (stored[column.name] case final num value
                    when value.isFinite)
                  column: value
                      .clamp(
                        ArtifactDashboardColumn.minWidth,
                        ArtifactDashboardColumn.maxWidth,
                      )
                      .toDouble(),
          },
        );
      }
    } on FormatException {
      return const ArtifactDashboardPreferences();
    }
    return const ArtifactDashboardPreferences();
  }

  Future<void> write() async {
    await DevicePreferences.current?.setString(
      key,
      jsonEncode({
        'view': grid ? 'grid' : 'list',
        'listSort': sort.name,
        'widths': {
          for (final entry in widths.entries) entry.key.name: entry.value,
        },
      }),
    );
  }

  void remember() => unawaited(write().catchError((Object _) {}));
}

typedef ArtifactDashboardPlace = ({String id, String label, bool home});

class ArtifactDashboardQuery {
  const ArtifactDashboardQuery({
    this.home,
    this.conversation,
    this.author,
    this.search = '',
    this.sort = ArtifactDashboardSort.opened,
    this.relevant = false,
  });

  final String? home, conversation, author;
  final String search;
  final ArtifactDashboardSort sort;
  final bool relevant;

  bool get narrowed =>
      home != null ||
      conversation != null ||
      author != null ||
      search.isNotEmpty ||
      relevant;
}

typedef ArtifactDashboardNews = ({bool mentioned, bool updated, int comments});
typedef ArtifactDashboardRow = ({
  ArtifactCard card,
  DateTime? openedAt,
  ArtifactDashboardNews news,
});
typedef ArtifactDashboardCounts = ({int total, int filtered, int relevant});
typedef ArtifactDashboardChoice = ({
  String id,
  String label,
  String name,
  String peerDisplayName,
  String? kind,
  ArtifactActor? actor,
});

class ArtifactDashboardPage {
  const ArtifactDashboardPage(this.rows, this.nextCursor, this.counts);

  final List<ArtifactDashboardRow> rows;
  final String? nextCursor;
  final ArtifactDashboardCounts? counts;
}

class ArtifactDashboardApi {
  ArtifactDashboardApi(this.client);

  final RaftClient client;

  Future<ArtifactDashboardPage> read(
    ArtifactDashboardQuery query, {
    String? cursor,
  }) async {
    final body = await client.get(
      _path('all', {
        'home': ?query.home,
        'conversation': ?query.conversation,
        'author': ?query.author,
        if (query.search.isNotEmpty) 'q': query.search,
        if (!query.relevant && query.sort == ArtifactDashboardSort.opened)
          'sort': 'opened',
        if (query.relevant) 'relevant': '1',
        'cursor': ?cursor,
      }),
    );
    if (body is! Map || body['rows'] is! List) {
      throw const FormatException('Invalid Artifacts dashboard response.');
    }
    final rows = <ArtifactDashboardRow>[];
    for (final row in (body['rows'] as List).whereType<Map>()) {
      final card = ArtifactCard.fromJson(row['card']);
      if (card == null) continue;
      final opened = row['openedAt'];
      final news = row['news'] is Map ? row['news'] as Map : const {};
      rows.add((
        card: card,
        openedAt: opened is String ? DateTime.tryParse(opened) : null,
        news: (
          mentioned:
              (news['mentions'] is int ? news['mentions'] as int : 0) > 0,
          updated: (news['versions'] is int ? news['versions'] as int : 0) > 0,
          comments: news['comments'] is int ? news['comments'] as int : 0,
        ),
      ));
    }
    final counts = body['counts'];
    return ArtifactDashboardPage(
      rows,
      body['nextCursor'] is String ? body['nextCursor'] as String : null,
      counts is Map
          ? (
              total: (counts['total'] as int?) ?? 0,
              filtered: (counts['filtered'] as int?) ?? 0,
              relevant: (counts['relevant'] as int?) ?? 0,
            )
          : null,
    );
  }

  Future<List<ArtifactDashboardChoice>> choices(
    String search, {
    required bool authors,
  }) async {
    final section = authors ? 'authors' : 'conversations';
    final body = await client.get(
      _path(section, {if (search.isNotEmpty) 'q': search}),
    );
    if (body is! Map || body[section] is! List) {
      throw const FormatException('Invalid Artifacts filter response.');
    }
    return [
      for (final item in (body[section] as List).whereType<Map>())
        if (item['id'] is String)
          (
            id: authors
                ? '${item['type'] == 'agent' ? 'agent' : 'user'}:${item['id']}'
                : item['id'] as String,
            label:
                (item['displayName'] ??
                        item['peerDisplayName'] ??
                        item['name'] ??
                        '')
                    .toString(),
            name: (item['name'] ?? '').toString(),
            peerDisplayName: (item['peerDisplayName'] ?? '').toString(),
            kind: switch (item['type']) {
              final String value => value,
              _ => null,
            },
            actor: authors
                ? ArtifactActor.fromJson(item)
                : switch (item['peer']) {
                    final Map peer when item['type'] == 'dm' =>
                      ArtifactActor.fromJson(peer),
                    _ => null,
                  },
          ),
    ];
  }

  String _path(String section, Map<String, String> params) {
    final path = '/artifacts/dashboard/$section';
    return Uri(
      path: path,
      queryParameters: params.isEmpty ? null : params,
    ).toString();
  }
}
