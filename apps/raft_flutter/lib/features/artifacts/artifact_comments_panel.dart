import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../icu_message.dart';
import 'artifact_comment_composer.dart';
import 'artifact_comment_models.dart';
import 'artifact_comment_store.dart';
import 'artifact_models.dart';
import 'artifact_review_store.dart';

class ArtifactCommentsPanel extends StatefulWidget {
  const ArtifactCommentsPanel({
    super.key,
    required this.store,
    required this.data,
    required this.onClose,
    this.initialComment,
    this.path,
    this.review,
  });

  final ArtifactCommentStore store;
  final ArtifactViewerData data;
  final VoidCallback onClose;
  final String? initialComment, path;
  final ArtifactReviewStore? review;

  @override
  State<ArtifactCommentsPanel> createState() => _ArtifactCommentsPanelState();
}

class _ArtifactCommentsPanelState extends State<ArtifactCommentsPanel> {
  final _scroll = ScrollController();
  final _landing = GlobalKey();
  bool _resolvedOpen = false, _landed = false, _file = false;
  ArtifactComment? _reply, _edit;
  ArtifactReviewDraft? _editDraft;

  ArtifactCommentStore get store => widget.store;
  bool get _canComment => widget.data.capabilities.comment;
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
    if (oldWidget.path != widget.path ||
        oldWidget.data.card.version != widget.data.card.version) {
      _file = false;
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
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
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
    final name = artifactCommentActorName(context, comment.author);
    final time = DateTime.tryParse(comment.createdAt)?.toLocal();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: RaftSpace.x2,
      children: [
        RaftAvatar(
          name: name,
          size: 24,
          imageUrl: comment.author.avatarUrl,
          kind: comment.author.type == 'agent'
              ? RaftAvatarKind.agent
              : RaftAvatarKind.human,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: RaftSpace.x1,
            children: [
              Wrap(
                spacing: RaftSpace.x1_5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(name, style: t.scale(RaftTypeScale.caption)),
                  if (time != null)
                    Text(
                      MaterialLocalizations.of(context).formatCompactDate(time),
                      style: t.scale(RaftTypeScale.footnote, color: t.muted),
                    ),
                  if (comment.edited)
                    Text(
                      raftText(context, 'edited'),
                      style: t.scale(RaftTypeScale.footnote, color: t.muted),
                    ),
                ],
              ),
              if (comment.deleted)
                Text(
                  raftText(context, 'Comment deleted'),
                  style: t.scale(RaftTypeScale.footnote, color: t.muted),
                )
              else if (_edit?.id != comment.id)
                ArtifactCommentBody(body: comment.body),
              if (comment.images.isNotEmpty)
                Wrap(
                  spacing: RaftSpace.x1,
                  runSpacing: RaftSpace.x1,
                  children: [
                    for (final id in comment.images)
                      _ArtifactCommentImage(
                        key: ValueKey(id),
                        store: store,
                        id: id,
                      ),
                  ],
                ),
              if (_edit?.id == comment.id) _composer(edit: comment),
            ],
          ),
        ),
        if (_canComment && _own(comment) && !comment.deleted)
          _commentActions(comment, name),
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

  Widget _thread(ArtifactCommentThread thread) {
    final t = RaftTokens.of(context);
    final root = thread.root;
    final landing =
        thread.id == widget.initialComment ||
        thread.replies.any((reply) => reply.id == widget.initialComment);
    return Container(
      key: landing ? _landing : ValueKey(thread.id),
      padding: const EdgeInsets.all(RaftSpace.x3),
      decoration: BoxDecoration(
        color: t.panel,
        border: Border.all(color: t.ui.lineHairline),
        borderRadius: BorderRadius.circular(t.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: RaftSpace.x2,
        children: [
          if (root == null)
            Text(raftText(context, 'Reply to an earlier comment'))
          else
            _entry(root),
          if (root?.resolvedBy case final resolver?)
            Text(
              raftFormat(context, 'Resolved by {name} · {time}', {
                'name': artifactCommentActorName(context, resolver),
                'time': root!.resolvedAt?.split('T').first ?? '',
              }),
              style: t.scale(RaftTypeScale.footnote, color: t.muted),
            ),
          for (final reply in thread.replies)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: RaftSpace.x3),
              child: _entry(reply),
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
                    tone: RaftButtonRecipeVariant.ghost,
                    size: RaftButtonRecipeSize.sm,
                    onPressed: () => setState(() {
                      _edit = null;
                      _editDraft = null;
                      _reply = root;
                    }),
                  ),
                if (_canResolve(root))
                  RaftButton(
                    label: raftText(
                      context,
                      thread.resolved ? 'Reopen' : 'Resolve',
                    ),
                    tone: RaftButtonRecipeVariant.ghost,
                    size: RaftButtonRecipeSize.sm,
                    onPressed: store.changing(root.id)
                        ? null
                        : () => unawaited(_resolve(root)),
                  ),
              ],
            ),
        ],
      ),
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
        ArtifactCommentPlace(_file ? widget.path : null);
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
      autofocus: reply != null || edit != null || draft != null,
      onCancel: reply == null && edit == null && draft == null
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

  List<Widget> _groups(List<ArtifactCommentThread> threads) {
    final t = RaftTokens.of(context);
    final groups = <String?, List<ArtifactCommentThread>>{};
    for (final thread in threads) {
      (groups[thread.first.place.path] ??= []).add(thread);
    }
    return [
      for (final path in {null, ...groups.keys})
        if (groups[path] case final group?) ...[
          Text(
            path ?? raftText(context, 'Whole Artifact'),
            style: t.scale(RaftTypeScale.caption),
          ),
          for (final thread in group) _thread(thread),
        ],
    ];
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
        Text(
          raftText(context, 'Your drafts'),
          style: t.scale(RaftTypeScale.caption),
        ),
        for (final draft in review.drafts)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: t.ui.lineHairline),
              borderRadius: BorderRadius.circular(t.radius),
            ),
            child: Padding(
              padding: const EdgeInsets.all(RaftSpace.x3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: RaftSpace.x1,
                children: [
                  Text(draft.place.path ?? raftText(context, 'Whole Artifact')),
                  if (_editDraft?.id == draft.id)
                    _composer(draft: draft)
                  else
                    ArtifactCommentBody(body: draft.body),
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
          ),
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
        ),
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
      controller: _scroll,
      padding: const EdgeInsets.all(RaftSpace.x3),
      children: [
        if (store.reviewId != null) ...[
          if (store.review case final review?)
            ArtifactCommentBody(body: readCommentBody(review['body']))
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
        if (threads.isEmpty) Text(raftText(context, 'No comments yet')),
        for (final child in _groups(unresolved))
          Padding(
            padding: const EdgeInsets.only(bottom: RaftSpace.x2),
            child: child,
          ),
        if (resolved.isNotEmpty)
          RaftButton(
            glyph: _resolvedOpen
                ? RaftGlyph.chevronDown
                : RaftGlyph.chevronRight,
            tone: RaftButtonRecipeVariant.ghost,
            label: raftFormat(context, 'Resolved ({count})', {
              'count': resolved.length,
            }),
            onPressed: () => setState(() => _resolvedOpen = !_resolvedOpen),
          ),
        if (_resolvedOpen)
          for (final child in _groups(resolved))
            Padding(
              padding: const EdgeInsets.only(bottom: RaftSpace.x2),
              child: child,
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return ColoredBox(
      key: const ValueKey('artifact-comments-panel'),
      color: t.panel,
      child: ListenableBuilder(
        listenable: Listenable.merge([store, widget.review]),
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RaftPanelHeaderBar(
              title: raftText(context, 'Comments'),
              actions: [
                RaftButton(
                  key: const ValueKey('artifact-comments-close'),
                  glyph: RaftGlyph.x,
                  tooltip: raftText(context, 'Close comments'),
                  semanticLabel: raftText(context, 'Close comments'),
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
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: t.ui.lineHairline)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(RaftSpace.x3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.path case final path?)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: RaftButton(
                              label: _file
                                  ? path
                                  : raftText(context, 'Whole Artifact'),
                              glyph: RaftGlyph.chevronDown,
                              tone: RaftButtonRecipeVariant.ghost,
                              size: RaftButtonRecipeSize.sm,
                              onPressed: () => setState(() => _file = !_file),
                            ),
                          ),
                        _composer(),
                      ],
                    ),
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
  const ArtifactCommentBody({super.key, required this.body});

  final List<ArtifactCommentPart> body;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Text.rich(
      TextSpan(
        children: [
          for (final part in body)
            TextSpan(
              text: part.display,
              style: part.actor == null ? null : t.scale(RaftTypeScale.caption),
            ),
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
