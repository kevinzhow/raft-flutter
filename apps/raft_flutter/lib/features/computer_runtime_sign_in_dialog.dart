// Web v1.24 features/computer/RuntimeSignInDialog.tsx: sign a Computer's
// runtime (Claude Code, Codex, Kimi, Qoder, Antigravity, Grok, CodeBuddy) in
// from the app. The login runs on the Computer; this dialog shows its link
// or device code and relays the pasted code or page address.
import 'package:flutter/widgets.dart';

import '../data/runtime_auth.dart';
import '../data/workspace_controller.dart';

/// Opens the sign-in dialog for [runtime] (a runtime-auth id) on the
/// Computer [machineId]; [runtimeId] is the Raft runtime id it is shown for.
Future<void> showComputerRuntimeSignInDialog(
  BuildContext context, {
  required WorkspaceController controller,
  required RuntimeAuthClient client,
  required String serverId,
  required String machineId,
  required String runtimeId,
  required String runtime,
}) async {}
