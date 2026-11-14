// A gated call's yes from an Artifact page: Raft's own dialog, never the
// page's (Porthole confirm requests; Raft's display gates `openLink`).
//
// Source: packages/web/src/apps/artifacts/{ArtifactFrameConfirm.tsx,
// artifactConfirmWords.ts} at v1.24.0-source.1: the title and accept word
// per capability, "From “title”", the address with its host set apart, and
// Accept ignored for Porthole's ARM_DELAY_MS (500 ms) after the dialog opens
// so a click meant for the page doesn't land on it. No pointer dismissal.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

/// The detail box's height before it scrolls (Web: a ScrollArea, max-h-48).
const _detailMaxHeight = 192.0;

/// Porthole `ARM_DELAY_MS`.
const artifactConfirmArmDelay = Duration(milliseconds: 500);

/// The words of one request (Web `confirmWords`) for the capabilities Raft's
/// Artifact display can gate; anything else asks "Allow this?".
({String title, String accept, String detail}) artifactConfirmWords(
  BuildContext context,
  String capability,
  Object? args,
) {
  String tr(String s) => raftText(context, s);
  final map = args is Map ? args : const {};
  switch (capability) {
    case 'openLink':
      final url = map['url'];
      final uri = url is String ? Uri.tryParse(url) : null;
      return (
        title: tr('Open this link?'),
        accept: tr('Open link'),
        detail: uri?.toString() ?? '${url ?? ''}',
      );
    case 'copyText':
      return (
        title: tr('Copy this text?'),
        accept: tr('Copy'),
        detail: '${map['text'] ?? ''}',
      );
    default:
      String detail;
      try {
        detail = const JsonEncoder.withIndent('  ').convert(args);
      } catch (_) {
        detail = '$args';
      }
      return (title: tr('Allow this?'), accept: tr('Allow'), detail: detail);
  }
}

/// Asks the reader; true only for their explicit yes. Raft's confirmation
/// dialog (X, Escape, Cancel; no outside press), Accept armed after
/// [artifactConfirmArmDelay].
Future<bool> confirmArtifactFrameRequest(
  BuildContext context, {
  required String capability,
  required Object? args,
  required String pageTitle,
}) async {
  final words = artifactConfirmWords(context, capability, args);
  final armed = ValueNotifier(false);
  final arm = Timer(artifactConfirmArmDelay, () => armed.value = true);
  final t = RaftTokens.of(context);
  try {
    final yes = await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: ValueKey('artifact-frame-confirm-$capability'),
        title: words.title,
        confirmLabel: words.accept,
        cancelLabel: raftText(context, 'Cancel'),
        confirmVariant: RaftButtonRecipeVariant.accent,
        confirmKey: const ValueKey('artifact-frame-confirm-accept'),
        confirmEnabled: armed,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: RaftSpace.x2,
          children: [
            Text(
              raftFormat(context, 'From “{title}”', {'title': pageTitle}),
              style: RaftConfirmDialog.messageStyle(t),
            ),
            if (words.detail.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: _detailMaxHeight),
                child: SingleChildScrollView(
                  child: Text(
                    words.detail,
                    key: const ValueKey('artifact-frame-confirm-detail'),
                    style: RaftTypography.mono(t, size: 13, line: 20),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return yes == true;
  } finally {
    arm.cancel();
    armed.dispose();
  }
}
