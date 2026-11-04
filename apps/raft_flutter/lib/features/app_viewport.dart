import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import '../platform/desktop_title_bar.dart';
import '../platform/keyboard_inset_guard.dart';
import '../platform/system_bars.dart';
import 'private_app_invite.dart';

/// Shared application viewport scopes. Navigation, account and update-service
/// ownership stay above this presentation-only composition in the app root.
Widget buildAppViewport({
  required GlobalKey screenshotKey,
  required WorkspaceController? workspace,
  required bool integrated,
  required String coordinator,
  required Future<void> Function(Uri) openLocation,
  required Widget child,
}) => RaftTextScaling(
  child: RepaintBoundary(
    key: screenshotKey,
    child: DesktopTitleBar(
      integrated: integrated,
      workspace: workspace,
      child: RaftTooltipProvider(
        delay: const Duration(milliseconds: 600),
        child: RaftViewportBreakpointScope(
          // Resolves the theme's font combinations once the app is idle.
          child: RaftFontWarmUpScope(
            child: RaftSystemBars(
              child: RaftErrorScope(
                format: raftAppErrorFormatter,
                child: RaftToastHost(
                  child: KeyboardInsetGuard(
                    imeVisible: platformImeVisibility,
                    child: PrivateAppInviteScope(
                      coordinator: coordinator,
                      onOpen: openLocation,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);
