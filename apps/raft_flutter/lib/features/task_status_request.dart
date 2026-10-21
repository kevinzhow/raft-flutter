/// The request that moves [task] to [status]. Source taskStore
/// `updateTaskStatus`: `todo -> in_progress` on a task nobody holds is the
/// user's claim/start intent, so it goes through `PATCH /tasks/:id/claim`
/// (assigns the caller and starts the work). The server refuses an unassigned
/// task moving to `in_progress` through `/status`, because that would leave
/// ownerless active work; the admin force-status path is not used to bypass it.
/// Every other change is `PATCH /tasks/:id/status`.
({String path, Map<String, dynamic>? data}) taskStatusRequest(
  Map<String, dynamic> task,
  String status,
) {
  final id = task['id'];
  final unclaimed = switch (task['claimedById']) {
    null => true,
    final String value => value.isEmpty,
    _ => false,
  };
  if (status == 'in_progress' && task['status'] == 'todo' && unclaimed) {
    return (path: '/tasks/$id/claim', data: null);
  }
  return (path: '/tasks/$id/status', data: {'status': status});
}

/// Sends the request of [taskStatusRequest] through a page's `command`.
Future<void> moveTaskStatus(
  Future<void> Function(
    String method,
    String path, {
    dynamic data,
    String? sourceScope,
  })
  command,
  Map<String, dynamic> task,
  String status,
  String scope,
) {
  final move = taskStatusRequest(task, status);
  return command('PATCH', move.path, data: move.data, sourceScope: scope);
}
