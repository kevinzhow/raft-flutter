part of 'workspace_cache.dart';

Future<List<WorkspaceDraftEntry>> _readWorkspaceDrafts(
  DriftWorkspaceCache db,
  String origin,
  String principal,
  String server,
) async {
  final rows = await db
      .customSelect(
        '''SELECT draft.id, json_extract(draft.payload, '\$.text') AS text,
      CAST(stamp.payload AS INTEGER) AS updated_at
      FROM workspace_cache AS draft
      LEFT JOIN workspace_cache AS stamp ON stamp.kind='draft-updated'
        AND stamp.origin=draft.origin AND stamp.principal=draft.principal
        AND stamp.server=draft.server AND stamp.id=draft.id
      WHERE draft.origin=? AND draft.principal=? AND draft.server=?
      AND draft.kind='draft' AND draft.id NOT LIKE 'desktop-window:%'
      AND json_valid(draft.payload) AND json_type(draft.payload, '\$.text')='text'
      ORDER BY updated_at DESC, draft.id''',
        variables: [Variable(origin), Variable(principal), Variable(server)],
      )
      .get();
  return [
    for (final row in rows)
      if (row.read<String>('text').trim().isNotEmpty)
        WorkspaceDraftEntry(
          row.read<String>('id'),
          row.read<String>('text'),
          switch (row.data['updated_at']) {
            final int time => DateTime.fromMillisecondsSinceEpoch(time),
            _ => null,
          },
        ),
  ];
}

Future<void> _updateWorkspaceDraftTime(
  DriftWorkspaceCache db,
  String origin,
  String principal,
  String server,
  String id,
  dynamic value,
) async {
  final text = value is Map ? value['text'] : null;
  if (text is! String || text.trim().isEmpty) {
    await db.customStatement(
      '''DELETE FROM workspace_cache WHERE origin=? AND principal=? AND server=?
         AND kind='draft-updated' AND id=?''',
      [origin, principal, server, id],
    );
    return;
  }
  final previous = await db
      .customSelect(
        '''SELECT json_extract(payload, '\$.text') AS text FROM workspace_cache
       WHERE origin=? AND principal=? AND server=? AND kind='draft' AND id=?
       AND json_valid(payload)''',
        variables: [
          Variable(origin),
          Variable(principal),
          Variable(server),
          Variable(id),
        ],
      )
      .getSingleOrNull();
  if (previous?.data['text'] == text) return;
  await db.customStatement(
    '''INSERT OR REPLACE INTO workspace_cache (origin,principal,server,kind,id,payload)
       VALUES (?,?,?,'draft-updated',?,?)''',
    [
      origin,
      principal,
      server,
      id,
      DateTime.now().millisecondsSinceEpoch.toString(),
    ],
  );
}
