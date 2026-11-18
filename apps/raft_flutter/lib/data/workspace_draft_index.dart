class WorkspaceDraftEntry {
  const WorkspaceDraftEntry(this.scope, this.text, this.updatedAt);

  final String scope, text;
  final DateTime? updatedAt;
}

abstract interface class WorkspaceDraftIndex {
  Future<List<WorkspaceDraftEntry>> readDrafts(
    String origin,
    String principal,
    String server,
  );
}
