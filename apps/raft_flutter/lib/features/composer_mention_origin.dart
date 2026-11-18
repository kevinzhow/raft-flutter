({bool external, List<String> servers}) composerMentionOrigin(
  Map<String, dynamic> row,
  String? viewer,
) {
  final home = row['serverId'];
  final external =
      viewer != null &&
      (row['inViewerServer'] is bool
          ? row['inViewerServer'] == false
          : home is String && home != viewer);
  if (!external) return (external: false, servers: const []);
  final listed = row['servers'];
  final servers = <String, String>{};
  for (final server
      in listed is List
          ? listed.whereType<Map>()
          : [
              {
                'id': home,
                'name': row['serverName'],
                'slug': row['serverSlug'],
              },
            ]) {
    final id = server['id'];
    final name = [
      server['name'],
      server['slug'],
    ].whereType<String>().where((value) => value.isNotEmpty).firstOrNull;
    if (id is String && id != viewer && name != null) {
      servers.putIfAbsent(id, () => name);
    }
  }
  return (external: true, servers: servers.values.toList());
}
