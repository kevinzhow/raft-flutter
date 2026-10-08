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
  return num.tryParse(
    '${data['start'] ?? data['time'] ?? data['offset'] ?? data['index'] ?? ''}',
  );
}

class AttachmentCommentsView extends StatefulWidget {
  const AttachmentCommentsView({
    super.key,
    required this.controller,
    required this.attachmentId,
    required this.filename,
    this.pendingAnchor,
  });
  final WorkspaceController controller;
  final String attachmentId, filename;
  final Map<String, dynamic>? pendingAnchor;
  @override
  State<AttachmentCommentsView> createState() => _AttachmentCommentsViewState();
}

class _AttachmentCommentsViewState extends State<AttachmentCommentsView> {
  WorkspaceController get w => widget.controller;
  List<Map<String, dynamic>>? comments;
  Map<String, dynamic>? viewer;
  String? error;
  bool anchorCleared = false;
  late final String authority = workspaceAuthority(w);

  @override
  void initState() {
    super.initState();
    load();
  }

  bool get current => mounted && authority == workspaceAuthority(w);

  Future<void> load() async {
    try {
      final data = await w.query(
        '/attachments/${widget.attachmentId}/comments',
      );
      if (!current) return;
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
      if (current) {
        setState(() => error = raftText(context, 'Failed to load comments'));
      }
    }
  }

  Map<String, dynamic>? get activeAnchor =>
      anchorCleared ? null : widget.pendingAnchor;

  Future<bool> send(String content, List<Map<String, dynamic>> mentions) async {
    final anchor = activeAnchor;
    await w.command(
      'POST',
      '/attachments/${widget.attachmentId}/comments',
      data: {
        'content': content,
        'anchor': ?anchor,
        if (mentions.isNotEmpty) 'mentions': mentions,
      },
    );
    if (!current) return true;
    setState(() => anchorCleared = true);
    await load();
    return true;
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
        onSendWithMentions: send,
        onSend: (text) => send(text, const []),
      ),
    );
  }
}
