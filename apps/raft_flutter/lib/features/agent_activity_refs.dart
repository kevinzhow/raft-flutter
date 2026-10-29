import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import '../data/workspace_controller.dart';

/// Web `AgentActivityLog` `RefText` (components/agent/RefText.tsx): the
/// `#channel`, `#channel:shortid`, `dm:@peer` and `dm:@peer:shortid` tokens of
/// a raw activity string become reference pills (channel pink, thread cyan).
/// Unresolvable tokens stay verbatim, never a dead link.
///
/// Like Web's `useRefNavigation`, tokens resolve against the channels list
/// only (`channelStore.channels`: channel / private / joint, case-insensitive);
/// DM tokens never resolve there, so they stay plain text here too.
final _scan = RegExp(
  r'#([\p{L}\p{N}_-]+):([\da-f]{6,8})'
  r'|dm:@([\w.-]+(?:~(?:agent|human))?(?![\w.~-])):([\da-f]{6,8})'
  r'|#([\p{L}\p{N}_-]+)'
  r'|dm:@([\w.-]+(?:~(?:agent|human))?(?![\w.~-]))',
  unicode: true,
  caseSensitive: false,
);

/// Resolved reference tokens of [text] per line: the lines a pill sits on grow
/// by the chip's 0.41px (`activityRefLineExtra`).
RaftChannel? _channelOf(WorkspaceController w, String? name) => name == null
    ? null
    : w.channels
          .where(
            (c) =>
                const {
                  'channel',
                  'private',
                  'joint',
                }.contains(c.string('type')) &&
                c.string('name').toLowerCase() == name.toLowerCase(),
          )
          .firstOrNull;

/// Extra height of the lines of [text] that carry a resolvable pill (a 16.41px
/// inline chip in a 16px line, Web `leading-[1.2em]` + border).
double activityRefLineExtra(WorkspaceController w, String text) {
  var lines = 0;
  for (final line in text.split('\n')) {
    if (_scan
        .allMatches(line)
        .any((m) => _channelOf(w, m[1] ?? m[5]) != null)) {
      lines++;
    }
  }
  return lines * 0.41;
}

/// The pills of [text] spliced between its plain runs. [base] is the style of
/// the surrounding text.
List<InlineSpan> linkifyActivityRefs(
  BuildContext context,
  WorkspaceController w,
  String text,
  TextStyle base,
) {
  if (text.isEmpty) return [TextSpan(text: text, style: base)];
  final out = <InlineSpan>[];
  var last = 0;
  for (final m in _scan.allMatches(text)) {
    if (m.start > last) {
      out.add(TextSpan(text: text.substring(last, m.start), style: base));
    }
    last = m.end;
    final name = m[1] ?? m[5];
    final channel = _channelOf(w, name);
    if (channel == null) {
      out.add(TextSpan(text: m[0], style: base));
      continue;
    }
    final shortId = m[2];
    final pill = raftReferenceSpan(
      context,
      label: m[0]!,
      href:
          'raft-ref://${shortId == null ? 'channel' : 'thread'}/${channel.id}',
      base: base,
      appearance: RaftReferenceAppearance(
        shortId == null ? RaftReferenceKind.channel : RaftReferenceKind.thread,
      ),
      onTap: () => unawaited(_open(context, w, channel, shortId)),
    );
    // Blink snaps the pill's edges to whole pixels.
    out.add(
      pill is WidgetSpan
          ? WidgetSpan(
              alignment: pill.alignment,
              baseline: pill.baseline,
              // The 16.41px chip tops its line (the strut sits 0.41 lower).
              child: Transform.translate(
                offset: const Offset(0, -.5),
                child: RaftCssPixelSnap(child: pill.child),
              ),
            )
          : pill,
    );
  }
  if (last < text.length) {
    out.add(TextSpan(text: text.substring(last), style: base));
  }
  return out;
}

Future<void> _open(
  BuildContext context,
  WorkspaceController w,
  RaftChannel channel,
  String? shortId,
) async {
  try {
    if (shortId == null) {
      await w.selectChannel(channel);
      return;
    }
    // Web `navigateThread`: the parent resolves through the message context.
    final resolved = await w.query(
      '/messages/context/$shortId',
      query: {'channelId': channel.id},
    );
    final target = resolved['canonicalTarget'];
    final id =
        resolved['targetMessageId'] ??
        (target is Map
            ? target['messageId'] ?? target['threadParentMessageId']
            : null);
    if (id is! String) {
      throw const RaftApiException('This thread is no longer available.');
    }
    await w.jumpToMessage(
      target is Map ? '${target['channelId'] ?? channel.id}' : channel.id,
      id,
    );
  } catch (e) {
    if (context.mounted) {
      showRaftToast(
        context,
        userErrorText(
          e,
          fallback: 'Unable to open thread. It may be unavailable or deleted.',
          where: 'open activity reference',
        ),
      );
    }
  }
}
