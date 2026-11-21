import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../icu_message.dart';
import 'artifact_comment_composer.dart';
import 'artifact_review_store.dart';

class ArtifactReviewBatchBar extends StatefulWidget {
  const ArtifactReviewBatchBar({
    super.key,
    required this.review,
    required this.version,
    required this.onSent,
    required this.onDiscarded,
    required this.commentsOpen,
    required this.composerState,
  });

  final ArtifactReviewStore review;
  final int version;
  final VoidCallback onSent, onDiscarded;
  final bool commentsOpen;
  final ValueListenable<ArtifactReviewComposerState> composerState;

  @override
  State<ArtifactReviewBatchBar> createState() => _ArtifactReviewBatchBarState();
}

class _ArtifactReviewBatchBarState extends State<ArtifactReviewBatchBar> {
  static const _confirmationWidth = 320.0;
  final _menu = MenuController();
  final _anchor = GlobalKey();
  final _discardFocus = FocusNode();
  final _cancelFocus = FocusNode();
  final _toastAvoid = GlobalKey();
  RaftToastController? _toastHost;
  RaftToastHandle? _submitNotice;
  bool _discardFailed = false;

  @override
  void initState() {
    super.initState();
    _toastHost = RaftToastHost.maybeOf(context)
      ?..avoid(_toastAvoid, () => mounted && !widget.commentsOpen);
  }

  @override
  void dispose() {
    _toastHost?.unavoid(_toastAvoid);
    _discardFocus.dispose();
    _cancelFocus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final review = widget.review;
    _submitNotice?.dismiss();
    _submitNotice = null;
    await review.submit(widget.version);
    if (!mounted || !identical(review, widget.review)) return;
    final problem = review.problem.message;
    if (problem != null) {
      if (!widget.commentsOpen) {
        _submitNotice = showRaftToastHandle(context, problem);
      }
    } else if (review.drafts.isEmpty) {
      widget.onSent();
    }
  }

  Future<void> _discard() async {
    final review = widget.review;
    setState(() => _discardFailed = false);
    try {
      await review.delete(null);
    } catch (_) {
      if (mounted && _menu.isOpen && identical(review, widget.review)) {
        setState(() => _discardFailed = true);
      }
      return;
    }
    if (!mounted || !identical(review, widget.review)) return;
    _menu.close();
    widget.onDiscarded();
  }

  void _cancel() {
    _menu.close();
    _discardFocus.requestFocus();
  }

  Widget _confirmation(BuildContext context, int count) {
    final theme = RaftTokens.of(context);
    final tokens = theme.recipeTokens;
    final slots = RaftPopoverRecipe.resolve(
      tokens: tokens,
      states: theme.recipeStates(),
    );
    final title = icuText(
      context,
      'Discard {count, plural, one {# draft} other {# drafts}}?',
      {'count': count},
    );
    return RaftDismissScope(
      onDismiss: _cancel,
      child: Semantics(
        container: true,
        label: title,
        child: RaftPopoverSurface(
          key: const ValueKey('artifact-review-discard-popover'),
          surfaceStyle: slots.content,
          child: SizedBox(
            width: _confirmationWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RaftRecipeBox(
                  style: slots.header,
                  tokens: tokens,
                  child: RaftRecipeBox(
                    style: slots.title,
                    tokens: tokens,
                    child: Text(title),
                  ),
                ),
                RaftRecipeBox(
                  style: slots.body,
                  tokens: tokens,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: RaftSpace.x3,
                    children: [
                      RaftBanner(
                        description: raftText(context, "This can't be undone."),
                        status: RaftBannerRecipeStatus.destructive,
                        size: RaftBannerRecipeSize.sm,
                      ),
                      if (_discardFailed)
                        RaftBanner(
                          description: raftText(
                            context,
                            'Something went wrong. Try again.',
                          ),
                          size: RaftBannerRecipeSize.sm,
                        ),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: RaftSpace.x2,
                        runSpacing: RaftSpace.x2,
                        children: [
                          RaftButton(
                            key: const ValueKey(
                              'artifact-review-discard-cancel',
                            ),
                            label: raftText(context, 'Cancel'),
                            focusNode: _cancelFocus,
                            tone: RaftButtonRecipeVariant.ghost,
                            size: RaftButtonRecipeSize.md,
                            onPressed: _cancel,
                          ),
                          RaftButton(
                            label: raftText(context, 'Discard drafts'),
                            tone: RaftButtonRecipeVariant.danger,
                            size: RaftButtonRecipeSize.md,
                            onPressed: widget.review.busy ? null : _discard,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.review, widget.composerState]),
    builder: (context, _) {
      final review = widget.review;
      final count = review.drafts.length;
      if (count == 0) return const SizedBox.shrink();
      final (engaged: composing, editingDraft: editing) =
          widget.composerState.value;
      return Semantics(
        container: true,
        label: raftTextZh(context, 'Comment tools', '评论工具'),
        child: RaftPopoverSurface(
          key: const ValueKey('artifact-review-batch-bar'),
          child: Padding(
            key: _toastAvoid,
            padding: const EdgeInsets.all(RaftSpace.x1),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: RaftSpace.x1,
              runSpacing: RaftSpace.x1,
              children: [
                RaftPopoverAnchor(
                  controller: _menu,
                  anchorKey: _anchor,
                  childFocusNode: _discardFocus,
                  gap: RaftSpace.x2,
                  alignRight: true,
                  onOpen: () {
                    setState(() => _discardFailed = false);
                    _cancelFocus.requestFocus();
                  },
                  builder: (context, controller, _) => KeyedSubtree(
                    key: _anchor,
                    child: RaftButton(
                      key: const ValueKey('artifact-review-discard-all'),
                      label: raftText(context, 'Discard all'),
                      focusNode: _discardFocus,
                      tone: RaftButtonRecipeVariant.ghost,
                      size: RaftButtonRecipeSize.md,
                      onPressed: review.busy ? null : controller.open,
                    ),
                  ),
                  popup: _confirmation(context, count),
                ),
                RaftButton(
                  key: const ValueKey('artifact-review-submit'),
                  label: raftFormat(context, 'Send {count}', {'count': count}),
                  tone: composing
                      ? RaftButtonRecipeVariant.outline
                      : RaftButtonRecipeVariant.primary,
                  size: RaftButtonRecipeSize.md,
                  onPressed: review.busy || editing ? null : _send,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
