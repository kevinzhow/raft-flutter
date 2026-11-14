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

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

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

/// Asks the reader; true only for their explicit yes.
Future<bool> confirmArtifactFrameRequest(
  BuildContext context, {
  required String capability,
  required Object? args,
  required String pageTitle,
}) async {
  final words = artifactConfirmWords(context, capability, args);
  final yes = await showRaftDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ArtifactFrameConfirmDialog(
      words: words,
      pageTitle: pageTitle,
      capability: capability,
    ),
  );
  return yes == true;
}

class _ArtifactFrameConfirmDialog extends StatefulWidget {
  const _ArtifactFrameConfirmDialog({
    required this.words,
    required this.pageTitle,
    required this.capability,
  });

  final ({String title, String accept, String detail}) words;
  final String pageTitle, capability;

  @override
  State<_ArtifactFrameConfirmDialog> createState() =>
      _ArtifactFrameConfirmDialogState();
}

class _ArtifactFrameConfirmDialogState
    extends State<_ArtifactFrameConfirmDialog> {
  bool armed = false;
  Timer? arm;

  @override
  void initState() {
    super.initState();
    arm = Timer(artifactConfirmArmDelay, () {
      if (mounted) setState(() => armed = true);
    });
  }

  @override
  void dispose() {
    arm?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final words = widget.words;
    return RaftAlertDialog(
      key: ValueKey('artifact-frame-confirm-${widget.capability}'),
      title: words.title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: RaftSpace.x2,
        children: [
          RaftDialogDescription(
            raftFormat(context, 'From “{title}”', {'title': widget.pageTitle}),
          ),
          if (words.detail.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: SelectableText(
                  words.detail,
                  key: const ValueKey('artifact-frame-confirm-detail'),
                  style: RaftTypography.mono(t, size: 13, line: 20),
                ),
              ),
            ),
        ],
      ),
      actions: [
        RaftButton(
          key: const ValueKey('artifact-frame-confirm-cancel'),
          label: raftText(context, 'Cancel'),
          tone: RaftButtonRecipeVariant.outline,
          size: RaftButtonRecipeSize.md,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        RaftButton(
          key: const ValueKey('artifact-frame-confirm-accept'),
          label: words.accept,
          tone: RaftButtonRecipeVariant.accent,
          size: RaftButtonRecipeSize.md,
          onPressed: armed ? () => Navigator.of(context).pop(true) : null,
        ),
      ],
    );
  }
}
