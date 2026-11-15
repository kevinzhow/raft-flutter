// Web v1.24 features/computer/PiSignInDialog.tsx: sign a per-provider
// runtime (Pi, OpenCode) in, one provider at a time (an account or a key)
// from its own provider list. The login runs on the Computer.
import 'package:flutter/widgets.dart';

import '../data/runtime_auth.dart';
import '../data/workspace_controller.dart';

/// Opens the sign-in dialog for [runtime] (a runtime-auth id) on the
/// Computer [machineId]; [runtimeId] is the Raft runtime id it is shown for.
Future<void> showComputerRuntimePiSignInDialog(
  BuildContext context, {
  required WorkspaceController controller,
  required RuntimeAuthClient client,
  required String serverId,
  required String machineId,
  required String runtimeId,
  required String runtime,
}) async {}
