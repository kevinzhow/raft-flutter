// Web components/server/CommunityAgreementDialog.tsx: the agreement a member
// accepts to join a community server. Presentation plus the dialog's own
// submitting / error state; the app performs the join.
import 'card.dart' show RaftCard;

import 'package:flutter/material.dart';

import 'settings_administration.dart' show RaftAgreementBody;
import 'dialog_card.dart';
import 'error_presentation.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart';
import 'theme.dart';

/// Modal (`RaftModalBackdrop`) holding a `max-w-lg p-5` Card: title and
/// "Version {n}" with a close button, the scrollable agreement box
/// (`max-h-[50vh] border-2 p-4 text-sm`), a warning banner after a failed join
/// and the Cancel / "Agree & Continue" buttons.
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
    final bodyStyle = raftCssTextStyle(
      family: t.bodyFont,
      step: RaftTextSteps.sm,
      color: t.semantic.foreground,
    );
    return Material(
      type: MaterialType.transparency,
      child: RaftModalBackdrop(
        child: RaftCard(
          dialog: true,
          key: const ValueKey('community-agreement-card'),
          maxWidth: 512,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              widget.title,
                              style: raftCssTextStyle(
                                family: t.bodyFont,
                                step: RaftTextSteps.lg,
                                weight: FontWeight.w700,
                                color: t.ink,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            raftFormat(context, 'Version {version}', {
                              'version': widget.version,
                            }),
                            style: raftCssTextStyle(
                              family: t.bodyFont,
                              step: RaftTextSteps.xs,
                              color: t.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    RaftCloseButton(onPressed: widget.onClose),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .5,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: t.panel,
                    border: Border.all(color: t.semantic.lineMuted, width: 2),
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
              ),
              if (error.isNotEmpty) ...[
                const SizedBox(height: 16),
                RaftErrorBanner(
                  error,
                  key: const ValueKey('community-agreement-error'),
                  small: true,
                  bold: true,
                ),
              ],
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 8,
                children: [
                  RaftRecipeButton(
                    key: const ValueKey('community-agreement-cancel'),
                    label: 'Cancel',
                    variant: RaftButtonRecipeVariant.outline,
                    size: RaftButtonRecipeSize.sm,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    textStep: RaftTextSteps.xs,
                    disabled: submitting,
                    onPressed: widget.onClose,
                  ),
                  RaftRecipeButton(
                    key: const ValueKey('community-agreement-agree'),
                    label: submitting ? 'Joining…' : 'Agree & Continue',
                    variant: RaftButtonRecipeVariant.accent,
                    size: RaftButtonRecipeSize.sm,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    textStep: RaftTextSteps.xs,
                    disabled: submitting,
                    onPressed: agree,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
