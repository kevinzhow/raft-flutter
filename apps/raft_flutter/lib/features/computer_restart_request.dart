// Web v1.24 useComputerRestart.handleComputerRestart: enter the shared
// progress before the POST, take the request id from its answer, show the
// error when it fails. The rack row and the Computer page both call this.
import '../data/user_error.dart';
import '../data/workspace_controller.dart';

Future<void> requestComputerRestart(
  WorkspaceController w,
  String machineId,
) async {
  final serverId = w.server?.id;
  if (serverId == null) return;
  final progress = w.services.entityDirectory.computerRestartProgress;
  if (progress.progress(machineId) != null) return;
  progress.begin(machineId);
  try {
    final data = await w.command(
      'POST',
      '/servers/$serverId/machines/$machineId/computer/restart',
      data: <String, dynamic>{},
    );
    final requestId = data is Map ? data['requestId'] : null;
    if (requestId is String && requestId.isNotEmpty) {
      progress.accept(machineId, requestId);
    }
  } catch (e) {
    progress.fail(
      machineId,
      userErrorText(
        e,
        fallback: 'Failed to request restart. The Computer must be online.',
        codeText: const {'computer_offline': 'The Computer is offline.'},
        where: 'computer restart',
      ),
    );
  }
}
