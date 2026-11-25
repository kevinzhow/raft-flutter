// Web components/server/CommunityAgreementDialog.tsx: the agreement a member
// accepts to join a community server. Presentation plus the dialog's own
// submitting / error state; the app performs the join.
import 'card.dart' show RaftCard;

import 'package:flutter/material.dart';

import 'dialog_card.dart';
import 'error_presentation.dart';
import 'form_presentation.dart' show RaftFormFrame, RaftFormSheet;
import 'icons.dart' show RaftGlyph;
import 'localization.dart';
import 'overlays/dialog.dart';
import 'panel_layout.dart' show RaftCssText, RaftPanelAction;
import 'raft/button.dart' show RaftButton, RaftButtonSize, RaftButtonVariant;
import 'raft/ui_tokens.dart';
import 'settings_administration.dart' show RaftAgreementBody;
import 'theme.dart';
import 'tokens/tokens.dart' show RaftTypeScale;

/// Modal (`RaftModalBackdrop`) holding a `Dialog` (`max-w-lg`) with
/// `DialogHeader` (title + mono `Version {n}` + close), `DialogBody` (the
/// scrollable agreement `Card` `max-h-[50vh]` and warning banner after a
/// failed join) and `DialogFooter` (Cancel / "Agree & continue").
class RaftCommunityAgreementDialog extends StatefulWidget {
  const RaftCommunityAgreementDialog({
    super.key,
    required this.title,
    required this.version,
    required this.bodyMarkdown,
    required this.onClose,
    required this.onAgree,
    required this.errorMessage,
  });
  final String title, bodyMarkdown;
  final int version;
  final VoidCallback onClose;

  /// Joins with the agreement; throwing keeps the dialog open with the
  /// message [errorMessage] returns.
  final Future<void> Function() onAgree;

  /// `agreement_changed` -> "Agreement updated…", anything else -> "Failed to
  /// join community server".
  final String Function(BuildContext context, Object error) errorMessage;

  @override
  State<RaftCommunityAgreementDialog> createState() =>
      _RaftCommunityAgreementDialogState();
}

class _RaftCommunityAgreementDialogState
    extends State<RaftCommunityAgreementDialog> {
  bool submitting = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next agree attempt starts; the dialog state is dropped when it closes.
  String error = '';

  Future<void> agree() async {
    setState(() {
      submitting = true;
      error = '';
    });
    try {
      await widget.onAgree();
    } catch (e) {
      if (mounted) setState(() => error = widget.errorMessage(context, e));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final bodyStyle = t.scale(
      RaftTypeScale.callout,
      color: t.ui.foregroundMuted,
    );
    final versionLabel = raftFormat(context, 'Version {version}', {
      'version': widget.version,
    });
    final versionText = RaftCssText(
      versionLabel,
      style: t.scale(
        RaftTypeScale.monoMeta,
        mono: true,
        color: t.ui.foregroundHint,
      ),
    );
    final agreementCard = RaftCard(
      clip: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .5,
        ),
        child: SingleChildScrollView(
          primary: false,
          padding: const EdgeInsets.all(16),
          child: RaftAgreementBody(
            source: widget.bodyMarkdown,
            style: bodyStyle,
          ),
        ),
      ),
    );
    final inSheet = RaftFormFrame.sheetOf(context);
    final agreeButton = RaftButton(
      key: const ValueKey('community-agreement-agree'),
      label: raftText(context, submitting ? 'Joining…' : 'Agree & continue'),
      uiVariant: RaftButtonVariant.primary,
      uiSize: inSheet ? RaftButtonSize.md : RaftButtonSize.lg,
      disabled: submitting,
      onPressed: agree,
    );
    if (inSheet) {
      return RaftFormSheet(
        title: raftText(context, widget.title),
        onClose: submitting ? null : widget.onClose,
        showHandle: false,
        closeButton: RaftPanelAction(
          glyph: RaftGlyph.x,
          tooltip: raftText(context, 'Close'),
          onPressed: submitting ? null : widget.onClose,
        ),
        commit: agreeButton,
        body: KeyedSubtree(
          key: const ValueKey('community-agreement-card'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: versionText,
              ),
              agreementCard,
              if (error.isNotEmpty) ...[
                const SizedBox(height: 16),
                RaftErrorBanner(
                  error,
                  key: const ValueKey('community-agreement-error'),
                  small: true,
                  bold: true,
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Material(
      type: MaterialType.transparency,
      child: RaftModalBackdrop(
        child: RaftDialog(
          size: RaftDialogSize.lg,
          maxWidth: 512,
          contentKey: const ValueKey('community-agreement-card'),
          semanticLabel: widget.title,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RaftDialogHeader(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RaftDialogTitle(widget.title),
                    const SizedBox(height: 4),
                    versionText,
                  ],
                ),
                onClose: widget.onClose,
                closeEnabled: !submitting,
              ),
              Flexible(
                child: RaftDialogBody(
                  scrollable: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Flexible(child: agreementCard),
                      if (error.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        RaftErrorBanner(
                          error,
                          key: const ValueKey('community-agreement-error'),
                          small: true,
                          bold: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              RaftDialogFooter(
                children: [
                  RaftButton(
                    key: const ValueKey('community-agreement-cancel'),
                    label: raftText(context, 'Cancel'),
                    uiVariant: RaftButtonVariant.ghost,
                    uiSize: RaftButtonSize.lg,
                    disabled: submitting,
                    onPressed: widget.onClose,
                  ),
                  agreeButton,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
