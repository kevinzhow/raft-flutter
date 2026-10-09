// Web AttachmentCommentsPanel data path: GET/POST
// /attachments/:id/comments, comments sorted by anchor order then time, the
// pending anchor chip riding above the compact composer, viewer write gate.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/source_time_formatter.dart';
import '../data/workspace_controller.dart';
import 'private_route_guard.dart';
import 'sender_avatar_projection.dart';

/// `anchorLabel` (attachmentCommentAnchors.ts).
String attachmentAnchorLabel(BuildContext context, Map anchor) {
  final data = anchor['data'] is Map ? anchor['data'] as Map : const {};
  switch (anchor['type']) {
    case 'md-section':
      final title = data['headingTitle'] ?? data['headingId'];
      return '§ ${title is String && title.isNotEmpty ? title : raftText(context, 'section')}';
    case 'lines' || 'csv-rows':
      final start = num.tryParse('${data['start']}');
      final end = num.tryParse('${data['end'] ?? data['start']}') ?? start;
      if (start == null) return '${anchor['type']}';
      if (anchor['type'] == 'lines') {
        return start == end ? 'L$start' : 'L$start–$end';
      }
      return start == end
          ? raftFormat(context, 'Row {n}', {'n': start})
          : raftFormat(context, 'Row {start}–{end}', {
              'start': start,
              'end': end,
            });
    case 'html-region':
      final quote = data['quote'];
      if (quote is String && quote.trim().isNotEmpty) {
        final q = quote.trim();
        return q.length > 36 ? '${q.substring(0, 36)}…' : q;
      }
      return raftText(context, 'HTML region');
    case 'video-timestamp':
      final time = num.tryParse('${data['time']}');
      if (time == null) return raftText(context, 'timestamp');
      final h = time ~/ 3600, m = (time % 3600) ~/ 60, s = (time % 60).floor();
      String two(int v) => v.toString().padLeft(2, '0');
      return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
  }
  return '${anchor['type']}';
}

/// `anchorOrderKey`: section/line/row/time position, null when unanchored.
num? _anchorOrder(Map? anchor) {
  if (anchor == null) return null;
  final data = anchor['data'] is Map ? anchor['data'] as Map : const {};
  final value = switch (anchor['type']) {
    'lines' || 'csv-rows' => data['start'],
    'html-region' => data['y'],
    'video-timestamp' => data['time'],
    // Markdown order requires the live preview heading, not a persisted offset.
    _ => null,
  };
  final number = num.tryParse('$value');
  return number != null && number.isFinite ? number : null;
}

class AttachmentCommentsView extends StatefulWidget {
  const AttachmentCommentsView({
    super.key,
    required this.controller,
    required this.attachmentId,
    required this.filename,
    this.pendingAnchor,
    this.authorized,
  });
  final WorkspaceController controller;
  final String attachmentId, filename;
  final Map<String, dynamic>? pendingAnchor;
  final bool Function()? authorized;
  @override
  State<AttachmentCommentsView> createState() => _AttachmentCommentsViewState();
}

class _AttachmentCommentsViewState extends State<AttachmentCommentsView> {
  WorkspaceController get w => widget.controller;
  List<Map<String, dynamic>>? comments;
  Map<String, dynamic>? viewer;
  String? error;
  bool anchorCleared = false;
  late String authority;
  int binding = 0, request = 0;
  bool revoked = false;

  @override
  void initState() {
    super.initState();
    bind();
  }

  void bind() {
    authority = workspaceAuthority(w);
    revoked = false;
    comments = null;
    viewer = null;
    error = null;
    anchorCleared = false;
    ++binding;
    w.addListener(scopeChanged);
    load();
  }

  @override
  void didUpdateWidget(covariant AttachmentCommentsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, w) ||
        oldWidget.attachmentId != widget.attachmentId) {
      oldWidget.controller.removeListener(scopeChanged);
      bind();
    } else {
      scopeChanged();
    }
  }

  @override
  void dispose() {
    ++binding;
    ++request;
    w.removeListener(scopeChanged);
    super.dispose();
  }

  bool get current =>
      mounted &&
      !revoked &&
      authority == workspaceAuthority(w) &&
      (widget.authorized?.call() ?? true);

  void scopeChanged() {
    if (current || !mounted || revoked) return;
    ++binding;
    ++request;
    setState(() {
      revoked = true;
      comments = null;
      viewer = null;
      error = null;
    });
  }

  bool accepts(WorkspaceController owner, String id, int revision) =>
      current &&
      identical(owner, w) &&
      id == widget.attachmentId &&
      revision == binding;

  Future<void> load() async {
    if (!current) return;
    final owner = w, id = widget.attachmentId, revision = binding;
    final ticket = ++request;
    try {
      final data = await owner.query('/attachments/$id/comments');
      if (!accepts(owner, id, revision) || ticket != request) return;
      setState(() {
        comments = [
          for (final c
              in (data is Map ? data['comments'] as List? : null) ?? [])
            if (c is Map) Map<String, dynamic>.from(c),
        ];
        viewer = data is Map && data['viewer'] is Map
            ? Map<String, dynamic>.from(data['viewer'])
            : null;
        error = null;
      });
    } catch (_) {
      if (accepts(owner, id, revision) && ticket == request) {
        setState(() => error = raftText(context, 'Failed to load comments'));
      }
    }
  }

  Map<String, dynamic>? get activeAnchor =>
      anchorCleared ? null : widget.pendingAnchor;

  Future<bool> send(
    WorkspaceController owner,
    String id,
    int revision,
    String content,
    List<Map<String, dynamic>> mentions,
  ) async {
    if (!accepts(owner, id, revision) || viewer?['canComment'] == false) {
      return false;
    }
    final anchor = activeAnchor;
    await owner.client.post(
      '/attachments/$id/comments',
      data: {
        'content': content,
        'anchor': ?anchor,
        if (mentions.isNotEmpty) 'mentions': mentions,
      },
    );
    // Do not refresh a newly adopted principal after an old mutation finishes.
    if (!accepts(owner, id, revision)) return false;
    await owner.refreshUnread();
    if (!accepts(owner, id, revision)) return false;
    setState(() => anchorCleared = true);
    await load();
    return accepts(owner, id, revision);
  }

  String? get blocked {
    if (viewer == null || viewer!['canComment'] != false) return null;
    return raftText(context, switch (viewer!['reason']) {
      'archived' => 'Channel archived',
      'not_member' => 'Join channel to comment',
      'read_only' =>
        'This channel is read-only on your current plan. Upgrade to continue.',
      _ => 'Comments unavailable',
    });
  }

  Widget avatar(Map c) {
    final agent = c['senderType'] == 'agent';
    final source = projectSenderAvatar(
      origin: w.client.origin,
      senderId: '${c['senderId']}',
      senderType: agent ? 'agent' : 'user',
      agents: agent
          ? [
              {'id': c['senderId'], 'avatarUrl': c['senderAvatarUrl']},
            ]
          : const [],
      members: agent
          ? const []
          : [
              {
                'userId': c['senderId'],
                'avatarUrl': c['senderAvatarUrl'],
                'gravatarHash': c['senderGravatarHash'],
              },
            ],
    );
    return RaftAvatar(
      name: '${c['senderName']}',
      size: 20,
      kind: agent ? RaftAvatarKind.agent : RaftAvatarKind.human,
      mountedContext: RaftMountedAvatarContext.compactList,
      content: RaftAvatarContent(
        name: '${c['senderName']}',
        kind: agent ? RaftAvatarContentKind.agent : RaftAvatarContentKind.human,
        uploadedUrl: source.uploadedUrl,
        gravatarUrl: source.gravatarUrl,
        pixelKey: source.pixelKey,
        fallback: RaftMountedAvatarFallback(
          avatarContext: RaftMountedAvatarContext.compactList,
          gravatar: source.gravatarUrl != null,
          identity: agent
              ? RaftMountedAvatarIdentity.agent
              : RaftMountedAvatarIdentity.human,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!current) return const SizedBox.shrink();
    final owner = w, id = widget.attachmentId, revision = binding;
    final time = SourceTimeFormatter(
      locale: Localizations.localeOf(context).toLanguageTag(),
      preferredTimezone:
          w.client.user?.string('preferredTimezone') ??
          w.client.user?.string('timezone'),
      preferredTimeFormat: sourceTimeFormatPreference(
        w.client.user?.string('preferredTimeFormat') ??
            w.client.user?.string('timeFormat'),
      ),
      systemTimeFormat: MediaQuery.alwaysUse24HourFormatOf(context)
          ? SourceTimeFormat.twentyFourHour
          : null,
      todayLabel: raftText(context, 'Today'),
      yesterdayLabel: raftText(context, 'Yesterday'),
    );
    final sorted = comments == null
        ? null
        : ([...comments!]..sort((a, b) {
            final ka =
                _anchorOrder(a['anchor'] as Map?) ?? double.negativeInfinity;
            final kb =
                _anchorOrder(b['anchor'] as Map?) ?? double.negativeInfinity;
            if (ka != kb) return ka.compareTo(kb);
            return '${a['createdAt']}'.compareTo('${b['createdAt']}');
          }));
    final anchor = activeAnchor;
    return RaftAttachmentCommentsPanel(
      filename: widget.filename,
      error: error,
      blockedMessage: blocked,
      comments: sorted == null
          ? null
          : [
              for (final c in sorted)
                RaftAttachmentCommentView(
                  id: '${c['id']}',
                  senderName: '${c['senderName']}',
                  content: '${c['content'] ?? ''}',
                  timestamp: time.messageTime(c['createdAt']),
                  avatar: avatar(c),
                  anchorLabel: c['anchor'] is Map
                      ? attachmentAnchorLabel(context, c['anchor'] as Map)
                      : null,
                  quote:
                      c['anchor'] is Map &&
                          (c['anchor'] as Map)['data'] is Map &&
                          ((c['anchor'] as Map)['data'] as Map)['quote']
                              is String
                      ? ((c['anchor'] as Map)['data'] as Map)['quote'] as String
                      : null,
                ),
            ],
      composer: RaftComposer(
        variant: RaftComposerVariant.compact,
        hint: raftFormat(context, 'Comment on {filename}…', {
          'filename': widget.filename,
        }),
        accessoryRow: anchor == null
            ? null
            : Align(
                alignment: Alignment.centerLeft,
                child: RaftCommentAnchorChip(
                  label: attachmentAnchorLabel(context, anchor),
                  removeLabel: raftText(context, 'Remove anchor'),
                  onRemove: () => setState(() => anchorCleared = true),
                ),
              ),
        onSendWithMentions: (text, mentions) =>
            send(owner, id, revision, text, mentions),
        onSend: (text) => send(owner, id, revision, text, const []),
      ),
    );
  }
}
