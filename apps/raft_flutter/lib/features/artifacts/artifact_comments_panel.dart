import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:raft_ui/raft_ui.dart';

import '../icu_message.dart';
import 'artifact_comment_composer.dart';
import 'artifact_comment_models.dart';
import 'artifact_comment_store.dart';
import 'artifact_models.dart';
import 'artifact_review_store.dart';
import 'artifact_text.dart' show artifactRelativeTime;

class ArtifactCommentsPanel extends StatefulWidget {
  const ArtifactCommentsPanel({
    super.key,
    required this.store,
    required this.data,
    required this.onClose,
    this.initialComment,
    this.filePath,
    this.review,
    this.insert,
    this.clock,
    this.onReviewComposerChanged,
  });

  final ArtifactCommentStore store;
  final ArtifactViewerData data;
  final VoidCallback onClose;
  final String? initialComment, filePath;
  final ArtifactReviewStore? review;
  final ArtifactCommentInsert? insert;
  final DateTime Function()? clock;
  final void Function(Object, ArtifactReviewComposerState?)?
  onReviewComposerChanged;

  @override
  State<ArtifactCommentsPanel> createState() => _ArtifactCommentsPanelState();
}

class _ArtifactCommentsPanelState extends State<ArtifactCommentsPanel> {
  final _scroll = ScrollController();
  final _landing = GlobalKey();
  final _resolvedDisclosure = GlobalKey();
  String? _activeThread;
  bool _resolvedOpen = false, _landed = false;
  ArtifactComment? _reply, _edit;
  ArtifactReviewDraft? _editDraft;

  ArtifactCommentStore get store => widget.store;

  ScrollController get _discussionScroll =>
      (widget.insert == null
          ? null
          : RaftSheetScope.maybeOf(context)?.scrollController) ??
      _scroll;
  bool get _canComment => widget.data.capabilities.comment;
  bool get _regularSheet =>
      widget.insert == null && RaftSheetScope.maybeOf(context) != null;
  bool _own(ArtifactComment comment) =>
      comment.author.type == 'user' &&
      comment.author.id == store.workspace.client.user?.id;
  bool _canResolve(ArtifactComment comment) =>
      _canComment && (_own(comment) || widget.data.capabilities.delete);

  @override
  void initState() {
    super.initState();
    store.addListener(_storeChanged);
    _storeChanged();
  }

  @override
  void didUpdateWidget(covariant ArtifactCommentsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.data.card.version != widget.data.card.version ||
        widget.insert != null && oldWidget.insert != widget.insert) {
      _activeThread = null;
      _reply = null;
      _edit = null;
      _editDraft = null;
    }
  }

  void _storeChanged() {
    if (_landed || widget.initialComment == null) return;
    for (final thread in store.threads) {
      if (thread.id != widget.initialComment &&
          !thread.replies.any((reply) => reply.id == widget.initialComment)) {
        continue;
      }
      _landed = true;
      _resolvedOpen = thread.resolved;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _landing.currentContext;
        if (mounted && target != null) {
          unawaited(Scrollable.ensureVisible(target));
        }
      });
      break;
    }
  }

  @override
  void dispose() {
    store.removeListener(_storeChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _done() {
    setState(() {
      _reply = null;
      _edit = null;
      _editDraft = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scroll = _discussionScroll;
      if (scroll.hasClients) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _delete(ArtifactComment comment) async {
    final yes = await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        title: raftText(context, 'Delete this comment?'),
        message: raftText(context, 'The comment is deleted for everyone.'),
        confirmLabel: raftText(context, 'Delete comment'),
        surfaceKey: const ValueKey('artifact-comment-delete-dialog'),
      ),
    );
    if (!mounted || yes != true) return;
    try {
      await store.delete(comment.id);
    } catch (_) {
      if (mounted) {
        showRaftToast(
          context,
          raftText(context, "Couldn't delete the comment. Try again."),
        );
      }
    }
  }

  Future<void> _resolve(ArtifactComment root) async {
    try {
      await store.changeThread(root, root.resolvedAt == null);
    } catch (_) {
      if (mounted) {
        showRaftToast(
          context,
          raftText(context, "Couldn't update the comment. Try again."),
        );
      }
    }
  }

  Widget _entry(ArtifactComment comment) {
    final t = RaftTokens.of(context);
    if (comment.deleted) {
      return Text(
        raftText(context, 'Comment deleted'),
        style: t
            .scale(RaftTypeScale.callout, color: t.ui.foregroundHint)
            .copyWith(fontStyle: FontStyle.italic),
      );
    }
    final name = artifactCommentActorName(context, comment.author);
    final time = artifactRelativeTime(
      context,
      DateTime.tryParse(comment.createdAt),
      now: widget.clock?.call(),
    );
    final agent = comment.author.type == 'agent';
    final avatarUrl = comment.author.avatarUrl;
    final initials = raftAvatarInitials(name, max: 1);
    final editing = _edit?.id == comment.id;
    final showActions = _canComment && _own(comment);
    final scaled = RaftScaled.grows(context);
    final authorStyle = t.scale(RaftTypeScale.subhead, weight: FontWeight.w700);
    final author = Text(
      name,
      style: authorStyle,
      maxLines: scaled ? null : 1,
      overflow: scaled ? null : TextOverflow.ellipsis,
    );
    const headerGap = RaftSpace.x1_5;
    final details = Wrap(
      spacing: headerGap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (scaled) author,
        if (agent)
          RaftBadge(
            label: raftText(context, 'Agent'),
            appearance: RaftBadgeRecipeAppearance.outline,
          ),
        if (time.isNotEmpty)
          Text(
            time,
            style: t.scale(
              RaftTypeScale.monoMeta,
              mono: true,
              color: t.ui.foregroundHint,
            ),
          ),
        if (comment.edited)
          Text(
            raftText(context, 'edited'),
            style: t.scale(RaftTypeScale.caption, color: t.ui.foregroundHint),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x1,
      children: [
        Row(
          spacing: headerGap,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: RaftSpace.half),
              child: ExcludeSemantics(
                child: RaftAvatar(
                  name: name,
                  uiSize: RaftAvatarSize.xs,
                  imageUrl: avatarUrl,
                  content:
                      !agent &&
                          (avatarUrl?.isEmpty ?? true) &&
                          initials.isNotEmpty
                      ? RaftAvatarInitials(initials, size: RaftAvatarSize.xs)
                      : null,
                  kind: agent ? RaftAvatarKind.agent : RaftAvatarKind.human,
                ),
              ),
            ),
            Expanded(
              child: scaled
                  ? details
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final minimumAuthorWidth = authorStyle.fontSize ?? 0;
                        final detailsWidth =
                            (constraints.maxWidth -
                                    headerGap -
                                    minimumAuthorWidth)
                                .clamp(0, double.infinity)
                                .toDouble();
                        return Row(
                          spacing: headerGap,
                          children: [
                            Flexible(child: author),
                            if (details.children.isNotEmpty)
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: detailsWidth,
                                ),
                                child: details,
                              ),
                          ],
                        );
                      },
                    ),
            ),
            if (showActions) _commentActions(comment, name),
          ],
        ),
        if (!editing)
          ArtifactCommentBody(body: comment.body, viewer: widget.data.viewer),
        if (comment.images.isNotEmpty)
          Wrap(
            spacing: RaftSpace.x1,
            runSpacing: RaftSpace.x1,
            children: [
              for (final id in comment.images)
                _ArtifactCommentImage(key: ValueKey(id), store: store, id: id),
            ],
          ),
        if (editing) _composer(edit: comment),
      ],
    );
  }

  Widget _cardMeta(String label, {RaftGlyph? glyph}) {
    final t = RaftTokens.of(context);
    final color = t.ui.foregroundHint;
    return Row(
      spacing: RaftSpace.x1,
      children: [
        if (glyph != null) RaftIcon(glyph, size: 14, color: color),
        Flexible(
          child: Text(
            label,
            style: t.scale(RaftTypeScale.caption, color: color),
          ),
        ),
      ],
    );
  }

  Widget _commentActions(ArtifactComment comment, String name) {
    final label = raftFormat(context, "More actions for {name}'s comment", {
      'name': name,
    });
    return RaftDropdownMenu(
      label: label,
      kind: RaftMenuKind.dropdownMenu,
      align: RaftDropdownAlign.end,
      entries: [
        RaftMenuEntry(
          label: raftText(context, 'Edit'),
          glyph: RaftGlyph.pencil,
          onPressed: () => setState(() {
            _reply = null;
            _editDraft = null;
            _edit = comment;
          }),
        ),
        RaftMenuEntry(
          label: raftText(context, 'Delete'),
          glyph: RaftGlyph.trash2,
          onPressed: () => unawaited(_delete(comment)),
        ),
      ],
      triggerBuilder: (context, focus, pressed) => RaftButton(
        key: ValueKey('artifact-comment-more-${comment.id}'),
        glyph: RaftGlyph.ellipsisVertical,
        tone: RaftButtonRecipeVariant.ghost,
        tooltip: label,
        semanticLabel: label,
        focusNode: focus,
        size: RaftButtonRecipeSize.iconSm,
        onPressed: pressed,
      ),
    );
  }

  void _revealNearestEdge(BuildContext targetContext) {
    if (!targetContext.mounted) return;
    final position = Scrollable.maybeOf(targetContext)?.position;
    final target = targetContext.findRenderObject();
    if (position == null ||
        !_scroll.positions.contains(position) ||
        !position.hasContentDimensions ||
        position.isScrollingNotifier.value ||
        target == null ||
        !target.attached) {
      return;
    }
    final viewport = RenderAbstractViewport.maybeOf(target);
    if (viewport == null) return;

    final start = viewport.getOffsetToReveal(target, 0).offset;
    final end = viewport.getOffsetToReveal(target, 1).offset;
    // Keep the reading position when both edges of a tall target are clipped.
    final offset = position.pixels
        .clamp(math.min(start, end), math.max(start, end))
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (offset != position.pixels) position.jumpTo(offset.toDouble());
  }

  void _activateThread(String id, BuildContext cardContext) {
    if (_activeThread == id) return;
    setState(() => _activeThread = id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeThread != id) return;
      _revealNearestEdge(cardContext);
    });
  }

  void _toggleResolved() {
    setState(() => _resolvedOpen = !_resolvedOpen);
    if (!_resolvedOpen || !_regularSheet) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_resolvedOpen || !_regularSheet) return;
      if (_resolvedDisclosure.currentContext case final disclosure?) {
        _revealNearestEdge(disclosure);
      }
    });
  }

  Widget _thread(BuildContext cardContext, ArtifactCommentThread thread) {
    final t = RaftTokens.of(context);
    final root = thread.root;
    final landing =
        thread.id == widget.initialComment ||
        thread.replies.any((reply) => reply.id == widget.initialComment);
    final resolutionLabel = raftText(
      context,
      thread.resolved ? 'Reopen' : 'Resolve',
    );
    return RaftCommentCard(
      key: landing ? _landing : ValueKey(thread.id),
      active: _activeThread == null ? landing : _activeThread == thread.id,
      onActivate: () => _activateThread(thread.id, cardContext),
      children: [
        if (root == null)
          Text(
            raftText(context, 'Reply to an earlier comment'),
            style: t
                .scale(RaftTypeScale.callout, color: t.ui.foregroundHint)
                .copyWith(fontStyle: FontStyle.italic),
          )
        else
          _entry(root),
        for (final reply in thread.replies)
          Padding(
            padding: const EdgeInsets.only(top: RaftSpace.x1),
            child: _entry(reply),
          ),
        if ((root?.resolvedBy, root?.resolvedAt) case (
          final resolver?,
          final resolvedAt?,
        ))
          _cardMeta(
            raftFormat(context, 'Resolved by {name} · {time}', {
              'name': artifactCommentActorName(context, resolver),
              'time': artifactRelativeTime(
                context,
                DateTime.tryParse(resolvedAt),
                now: widget.clock?.call(),
              ),
            }),
            glyph: RaftGlyph.squareCheckBig,
          ),
        if (_reply?.id == root?.id && root != null)
          _composer(reply: root)
        else if (root != null && _canComment)
          Wrap(
            spacing: RaftSpace.x1,
            children: [
              if (!root.deleted)
                RaftButton(
                  label: raftText(context, 'Reply'),
                  glyph: RaftGlyph.reply,
                  tone: RaftButtonRecipeVariant.ghost,
                  size: RaftButtonRecipeSize.md,
                  onPressed: () => setState(() {
                    _edit = null;
                    _editDraft = null;
                    _reply = root;
                  }),
                ),
              if (_canResolve(root))
                RaftButton(
                  label: resolutionLabel,
                  glyph: thread.resolved
                      ? RaftGlyph.reopenTask
                      : RaftGlyph.squareCheckBig,
                  tone: RaftButtonRecipeVariant.ghost,
                  size: RaftButtonRecipeSize.md,
                  busy: store.changing(root.id),
                  loadingLabel: resolutionLabel,
                  onPressed: () => unawaited(_resolve(root)),
                ),
            ],
          ),
      ],
    );
  }

  Widget _composer({
    ArtifactComment? reply,
    ArtifactComment? edit,
    ArtifactReviewDraft? draft,
  }) {
    final place =
        draft?.place ??
        edit?.place ??
        reply?.place ??
        ArtifactCommentPlace(widget.filePath);
    final footer = reply == null && edit == null && draft == null;
    return ArtifactCommentComposer(
      key: ValueKey((
        widget.data.card.version,
        place.path,
        reply?.id,
        edit?.id,
        draft?.id,
      )),
      store: store,
      place: place,
      version: draft?.version ?? widget.data.card.version,
      reply: reply,
      edit: edit,
      review: widget.review,
      draft: draft,
      autofocus: !footer,
      standing: footer && widget.insert == null,
      insert: footer ? widget.insert : null,
      onReviewComposerChanged: widget.onReviewComposerChanged,
      onCancel: footer
          ? null
          : () {
              setState(() {
                _reply = null;
                _edit = null;
                _editDraft = null;
              });
            },
      onDone: _done,
    );
  }

  Widget _groupHeading(String label) {
    final t = RaftTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x1),
      child: Text(
        label,
        style: t.scale(
          RaftTypeScale.footnote,
          weight: FontWeight.w700,
          color: t.ui.foregroundHint,
        ),
      ),
    );
  }

  Iterable<Widget> _groups(List<ArtifactCommentThread> threads) sync* {
    final regularSheet = _regularSheet;
    final groups = <String?, List<ArtifactCommentThread>>{null: []};
    for (final thread in threads) {
      (groups[thread.first.place.path] ??= []).add(thread);
    }
    final populatedGroups = groups.entries.where(
      (group) => group.value.isNotEmpty,
    );
    for (final (index, group) in populatedGroups.indexed) {
      if (regularSheet && index > 0) yield const SizedBox(height: RaftSpace.x4);
      final heading = _groupHeading(
        group.key ?? raftText(context, 'Whole Artifact'),
      );
      yield regularSheet
          ? heading
          : Padding(
              padding: const EdgeInsets.only(bottom: RaftSpace.x2),
              child: heading,
            );
      for (final thread in group.value) {
        yield Padding(
          key: ValueKey(('artifact-comment-thread', thread.id)),
          padding: regularSheet
              ? const EdgeInsets.only(top: RaftSpace.x2)
              : const EdgeInsets.only(bottom: RaftSpace.x2),
          child: Builder(builder: (context) => _thread(context, thread)),
        );
      }
    }
  }

  List<Widget> _drafts(ArtifactReviewStore review) {
    final t = RaftTokens.of(context);
    return [
      if (review.failed)
        RaftButton(
          label: raftText(context, "Drafts didn't load · Retry"),
          onPressed: review.load,
        ),
      if (review.problem.message case final problem?)
        Semantics(
          liveRegion: true,
          child: Text(
            raftText(context, problem),
            style: t.scale(
              RaftTypeScale.footnote,
              color: t.semantic.dangerStrong,
            ),
          ),
        ),
      if (review.drafts.isNotEmpty) ...[
        _groupHeading(raftText(context, 'Your drafts')),
        for (final draft in review.drafts)
          Padding(
            padding: const EdgeInsets.only(top: RaftSpace.x2),
            child: RaftCommentCard(
              key: ValueKey(draft.id),
              privateDraft: true,
              children: [
                _cardMeta(
                  draft.place.path ?? raftText(context, 'Whole Artifact'),
                ),
                if (_editDraft?.id == draft.id)
                  _composer(draft: draft)
                else
                  ArtifactCommentBody(
                    body: draft.body,
                    viewer: widget.data.viewer,
                    // DraftCard uses Text.Sans body in both viewport tiers.
                    style: RaftTypography.sans(t, color: t.ui.foreground)
                        .copyWith(
                          leadingDistribution:
                              raftCssTextHeightBehavior.leadingDistribution,
                        ),
                  ),
                for (final id in draft.images)
                  _ArtifactCommentImage(
                    key: ValueKey(id),
                    store: store,
                    id: id,
                  ),
                if (_editDraft?.id != draft.id)
                  Wrap(
                    spacing: RaftSpace.x1,
                    children: [
                      RaftButton(
                        label: raftText(context, 'Edit'),
                        glyph: RaftGlyph.pencil,
                        tone: RaftButtonRecipeVariant.ghost,
                        onPressed: review.busy
                            ? null
                            : () => setState(() {
                                _reply = null;
                                _edit = null;
                                _editDraft = draft;
                              }),
                      ),
                      RaftButton(
                        label: raftText(context, 'Delete'),
                        glyph: RaftGlyph.trash2,
                        tone: RaftButtonRecipeVariant.ghost,
                        onPressed: review.busy
                            ? null
                            : () => _discard(review, draft.id),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        if (widget.insert != null || store.reviewId != null)
          Wrap(
            alignment: WrapAlignment.end,
            spacing: RaftSpace.x2,
            children: [
              RaftButton(
                label: raftText(context, 'Discard all'),
                tone: RaftButtonRecipeVariant.ghost,
                onPressed: review.busy ? null : () => _discard(review, null),
              ),
              RaftButton(
                key: const ValueKey('artifact-review-submit'),
                label: raftFormat(context, 'Send {count}', {
                  'count': review.drafts.length,
                }),
                onPressed: review.busy || _editDraft != null
                    ? null
                    : () => review.submit(widget.data.card.version),
              ),
            ],
          )
        else
          const SizedBox(height: RaftSpace.x4),
      ],
    ];
  }

  Future<void> _discard(ArtifactReviewStore review, String? id) async {
    final yes = await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: const ValueKey('artifact-review-discard-dialog'),
        title: id == null
            ? icuText(
                context,
                'Discard {count, plural, one {# draft} other {# drafts}}?',
                {'count': review.drafts.length},
              )
            : raftText(context, 'Delete this draft?'),
        message: raftText(context, "This can't be undone."),
        confirmLabel: raftText(
          context,
          id == null ? 'Discard drafts' : 'Delete draft',
        ),
      ),
    );
    if (!mounted || yes != true) return;
    try {
      await review.delete(id);
      if (mounted && (id == null || _editDraft?.id == id)) {
        setState(() => _editDraft = null);
      }
    } catch (_) {
      if (mounted) {
        showRaftToast(
          context,
          raftText(context, "Couldn't delete the draft. Try again."),
        );
      }
    }
  }

  Widget _discussion(BuildContext context) {
    if (!store.current) return const SizedBox.shrink();
    if (store.failed) {
      return Column(
        children: [
          Text(raftText(context, "Couldn't load the comments.")),
          RaftButton(
            label: raftText(context, 'Try again'),
            onPressed: store.refresh,
          ),
        ],
      );
    }
    if (!store.loaded) {
      return Center(child: Text(raftText(context, 'Loading comments')));
    }
    final threads = store.threads;
    final unresolved = threads.where((thread) => !thread.resolved).toList();
    final resolved = threads.where((thread) => thread.resolved).toList();
    return ListView(
      // The report sheet's handle needs its scroll position to move detents.
      controller: _discussionScroll,
      padding: const EdgeInsets.all(RaftSpace.x3),
      children: [
        if (store.reviewId != null) ...[
          if (store.review case final review?)
            ArtifactCommentBody(
              body: readCommentBody(review['body']),
              viewer: widget.data.viewer,
            )
          else
            Text(raftText(context, "This review isn't on this Artifact.")),
          RaftButton(
            label: raftText(context, 'Show all comments'),
            onPressed: store.showAll,
          ),
        ],
        if (store.cursor != null) ...[
          if (store.earlierFailed)
            Text(raftText(context, "Couldn't load earlier comments.")),
          RaftButton(
            label: raftText(
              context,
              store.earlierFailed ? 'Try again' : 'Load earlier comments',
            ),
            onPressed: store.loadingEarlier ? null : store.earlier,
          ),
        ],
        if (widget.review case final review?) ..._drafts(review),
        if (threads.isEmpty)
          if (widget.insert == null)
            Text(raftText(context, 'No comments yet'))
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x1),
              child: Text(
                raftText(context, 'No comments yet'),
                style: RaftTokens.of(context).scale(
                  RaftTypeScale.footnote,
                  color: RaftTokens.of(context).muted,
                ),
              ),
            ),
        ..._groups(unresolved),
        if (resolved.isNotEmpty) ...[
          if (unresolved.isNotEmpty)
            SizedBox(height: _regularSheet ? RaftSpace.x4 : RaftSpace.x2),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: RaftButton(
              key: _resolvedDisclosure,
              glyph: _resolvedOpen
                  ? RaftGlyph.chevronDown
                  : RaftGlyph.chevronRight,
              tone: RaftButtonRecipeVariant.ghost,
              size: RaftButtonRecipeSize.md,
              label: raftFormat(context, 'Resolved ({count})', {
                'count': resolved.length,
              }),
              onPressed: _toggleResolved,
            ),
          ),
          if (_resolvedOpen) ...[
            const SizedBox(height: RaftSpace.x2),
            ..._groups(resolved),
          ],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final compactReport =
        widget.insert != null && RaftAdaptiveWorkspace.compactOf(context);
    final regularSheet = _regularSheet;
    final sheetChrome = compactReport || regularSheet;
    final footerBorder = Border(
      top: BorderSide(color: sheetChrome ? t.ui.lineSeam : t.ui.lineHairline),
    );
    final closeLabel = raftText(context, 'Close comments');
    return ColoredBox(
      key: const ValueKey('artifact-comments-panel'),
      color: t.ui.layerCard,
      child: ListenableBuilder(
        listenable: Listenable.merge([store, widget.review]),
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RaftPanelHeaderBar(
              title: raftText(context, 'Comments'),
              subtitle: widget.filePath,
              columnMargin: compactReport ? RaftSpace.x4 : null,
              actions: [
                if (sheetChrome)
                  RaftPanelAction(
                    key: const ValueKey('artifact-comments-close'),
                    responsiveRecipe: true,
                    glyph: RaftGlyph.x,
                    tooltip: closeLabel,
                    minHitExtent: RaftMetrics.touchTarget,
                    onPressed: widget.onClose,
                  )
                else
                  RaftButton(
                    key: const ValueKey('artifact-comments-close'),
                    glyph: RaftGlyph.x,
                    tooltip: closeLabel,
                    semanticLabel: closeLabel,
                    tone: RaftButtonRecipeVariant.ghost,
                    size: RaftButtonRecipeSize.iconSm,
                    onPressed: widget.onClose,
                  ),
              ],
            ),
            Expanded(child: _discussion(context)),
            if (store.current &&
                _canComment &&
                store.reviewId == null &&
                _reply == null &&
                _edit == null &&
                _editDraft == null)
              SafeArea(
                top: false,
                bottom: !regularSheet,
                child: DecoratedBox(
                  decoration: BoxDecoration(border: footerBorder),
                  child: Padding(
                    padding: sheetChrome || widget.insert == null
                        ? EdgeInsets.fromLTRB(
                            RaftSpace.x3,
                            RaftSpace.x2 + footerBorder.top.width,
                            RaftSpace.x3,
                            RaftSpace.x3,
                          )
                        : const EdgeInsets.all(RaftSpace.x3),
                    child: _composer(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ArtifactCommentBody extends StatelessWidget {
  const ArtifactCommentBody({
    super.key,
    required this.body,
    required this.viewer,
    this.style,
  });

  final List<ArtifactCommentPart> body;
  final ArtifactViewerActor? viewer;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final base =
        style ?? t.scale(RaftTypeScale.callout, color: t.ui.foreground);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (final part in body)
            if (part.actor case final actor?)
              raftMentionTextSpan(
                context,
                label:
                    '@${actor.displayName.trim().isEmpty ? artifactCommentActorName(context, actor) : actor.displayName}',
                base: base,
                useSourceTypography: true,
                own:
                    actor.gone == null &&
                    viewer?.type == actor.type &&
                    viewer?.id == actor.id,
              )
            else
              TextSpan(text: part.text),
        ],
      ),
    );
  }
}

class _ArtifactCommentImage extends StatefulWidget {
  const _ArtifactCommentImage({
    super.key,
    required this.store,
    required this.id,
  });

  final ArtifactCommentStore store;
  final String id;

  @override
  State<_ArtifactCommentImage> createState() => _ArtifactCommentImageState();
}

class _ArtifactCommentImageState extends State<_ArtifactCommentImage> {
  static const _thumbnailSize = Size(120, 90);
  late Future<Uint8List> _bytes = widget.store.api.image(widget.id);

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _bytes,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return RaftButton(
          label: raftText(context, "Couldn't load"),
          onPressed: () =>
              setState(() => _bytes = widget.store.api.image(widget.id)),
        );
      }
      if (snapshot.data case final bytes?) {
        return RaftSizedImage.memory(
          bytes,
          width: _thumbnailSize.width,
          height: _thumbnailSize.height,
          fit: BoxFit.contain,
          semanticLabel: raftText(context, 'Image'),
          evictOnDispose: true,
        );
      }
      return SizedBox(
        width: _thumbnailSize.width,
        height: _thumbnailSize.height,
        child: Center(child: Text(raftText(context, 'Loading…'))),
      );
    },
  );
}
