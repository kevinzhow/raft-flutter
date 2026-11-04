import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

import 'workspace_browser.dart';

import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import '../data/user_error.dart';
import '../platform/app_services.dart';

Future<void> openDesktopServerWindow(
  BuildContext context,
  WorkspaceController workspace,
  RaftRecord server,
) async {
  final windows = AppServicesScope.maybeReadOf(context)?.desktopWindows;
  final principal = workspace.client.user?.id;
  try {
    await windows?.openServer(server);
  } catch (error) {
    if (staleWorkspaceFailure(error)) return;
    if (context.mounted && workspace.client.user?.id == principal) {
      // ignore: raft_lints/avoid_imperative_notice_state -- One-shot current-account native window failure; no error is retained across navigation.
      workspace.setError(
        userErrorText(
          error,
          fallback: 'Could not open the server window. Try again.',
        ),
      );
    }
  }
}

VoidCallback? serverWindowAction(
  BuildContext context,
  WorkspaceController workspace,
  RaftRecord server,
) {
  if (AppServicesScope.maybeOf(context)?.desktopWindows != null) {
    return () => unawaited(openDesktopServerWindow(context, workspace, server));
  }
  if (defaultTargetPlatform == TargetPlatform.linux &&
      workspaceBrowserOrigin(workspace.client.origin) != null) {
    return () => unawaited(openWorkspaceInBrowser(context, workspace, server));
  }
  return null;
}

VoidCallback? nativeServerWindowAction(
  BuildContext context,
  WorkspaceController workspace,
  RaftRecord server,
) => AppServicesScope.maybeOf(context)?.desktopWindows == null
    ? null
    : () => unawaited(openDesktopServerWindow(context, workspace, server));
