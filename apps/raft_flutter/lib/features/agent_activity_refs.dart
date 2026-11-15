import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import '../data/workspace_controller.dart';

/// Web `AgentActivityLog` `RefText` (components/agent/RefText.tsx): the
/// `#channel`, `#channel:shortid`, `#channel:#7`, `dm:@peer`,
/// `dm:@peer:shortid` and `dm:@peer:#7` tokens of a raw activity string become
/// reference pills (channel / DM pink, thread and task cyan). Unresolvable
/// tokens stay verbatim, never a dead link.
///
/// The alternation order is Web's (longest form first, so `#c:#7` and
/// `#c:shortid` are not shadowed by `#c`): channel-task, dm-task,
/// channel-thread, dm-thread, channel, dm. The grammar is raft-shared's
/// `raftRefs` (the task separator is `:#`).
const _channelName = r'[\p{L}\p{N}_-]+';
const _dmPeer = r'[\w.-]+(?:~(?:agent|human))?(?![\w.~-])';
const _shortId = r'[\da-f]{6,8}';
const _taskNumber = r'[1-9]\d*';
const _taskEnd = r'(?![\p{L}\p{N}_/-]|:#)';
final _scan = RegExp(
  '#($_channelName):#($_taskNumber)$_taskEnd'
  '|dm:@($_dmPeer):#($_taskNumber)$_taskEnd'
  '|#($_channelName):($_shortId)'
  '|dm:@($_dmPeer):($_shortId)'
  '|#($_channelName)'
  '|dm:@($_dmPeer)',
  unicode: true,
  caseSensitive: false,
);

/// A scanned token: what it names and how it opens.
class _Ref {
  const _Ref({this.channelName, this.dmPeer, this.shortId, this.taskNumber});
  final String? channelName, dmPeer, shortId;
  final int? taskNumber;
}

_Ref _partsOf(RegExpMatch m) {
  if (m[1] != null) {
    return _Ref(channelName: m[1], taskNumber: int.parse(m[2]!));
  }
  if (m[3] != null) return _Ref(dmPeer: m[3], taskNumber: int.parse(m[4]!));
  if (m[5] != null) return _Ref(channelName: m[5], shortId: m[6]);
  if (m[7] != null) return _Ref(dmPeer: m[7], shortId: m[8]);
  if (m[9] != null) return _Ref(channelName: m[9]);
  return _Ref(dmPeer: m[10]);
}

/// Web `findChannelByName`: channel / private / joint, case-insensitive.
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

/// Web `findDmByPeer`: `name~agent` / `name~human` pins the peer's kind; an
/// unknown kind matches nothing. The name is a handle, matched case-sensitively.
RaftChannel? _dmOf(WorkspaceController w, String? peer) {
  if (peer == null || peer.isEmpty) return null;
  final split = peer.indexOf('~');
  final name = split < 0 ? peer : peer.substring(0, split);
  final kind = split < 0 ? null : peer.substring(split + 1);
  if (name.isEmpty || (kind != null && kind != 'agent' && kind != 'human')) {
    return null;
  }
  final want = kind == null ? null : (kind == 'human' ? 'user' : 'agent');
  return w.dms
      .where(
        (c) =>
            (c.string('peerName') == name || c.string('name') == name) &&
            (want == null || c.string('peerType') == want),
      )
      .firstOrNull;
}

/// The conversation a ref names, in the reader's local lists.
RaftChannel? _conversationOf(WorkspaceController w, _Ref ref) =>
    ref.dmPeer != null ? _dmOf(w, ref.dmPeer) : _channelOf(w, ref.channelName);

/// Whether [text] holds a ref that resolves for this reader (a pill, not
/// plain text).
bool activityTextHasRefs(
  WorkspaceController w,
  String text, {
  bool canOpenTask = false,
}) => _scan.allMatches(text).any((m) {
  final ref = _partsOf(m);
  if (ref.taskNumber != null && !canOpenTask) return false;
  return _conversationOf(w, ref) != null;
});

/// Extra height of the lines of [text] that carry a resolvable pill (a 16.41px
/// inline chip in a 16px line, Web `leading-[1.2em]` + border).
double activityRefLineExtra(
  WorkspaceController w,
  String text, {
  bool canOpenTask = false,
}) {
  var lines = 0;
  for (final line in text.split('\n')) {
    if (activityTextHasRefs(w, line, canOpenTask: canOpenTask)) lines++;
  }
  return lines * 0.41;
}

/// Web `useRefNavigation().openTask`: opens task [taskNumber] of the
/// conversation [channelId]. Absent: task refs read as plain text.
typedef ActivityOpenTask = Future<void> Function(
  String channelId,
  int taskNumber,
);

/// The pills of [text] spliced between its plain runs. [base] is the style of
/// the surrounding text.
List<InlineSpan> linkifyActivityRefs(
  BuildContext context,
  WorkspaceController w,
  String text,
  TextStyle base, {
  ActivityOpenTask? onOpenTask,
}) {
  if (text.isEmpty) return [TextSpan(text: text, style: base)];
  final out = <InlineSpan>[];
  var last = 0;
  for (final m in _scan.allMatches(text)) {
    if (m.start > last) {
      out.add(TextSpan(text: text.substring(last, m.start), style: base));
    }
    last = m.end;
    final ref = _partsOf(m);
    final conversation = _conversationOf(w, ref);
    // Web: no `openTask` (or no such channel) reads as plain text.
    if (conversation == null ||
        (ref.taskNumber != null && onOpenTask == null)) {
      out.add(TextSpan(text: m[0], style: base));
      continue;
    }
    final isThread = ref.shortId != null || ref.taskNumber != null;
    final pill = raftReferenceSpan(
      context,
      label: m[0]!,
      href:
          'raft-ref://${ref.taskNumber != null
              ? 'task'
              : isThread
              ? 'thread'
              : 'channel'}/${conversation.id}',
      base: base,
      appearance: RaftReferenceAppearance(
        isThread ? RaftReferenceKind.thread : RaftReferenceKind.channel,
      ),
      onTap: () => unawaited(
        _open(context, w, conversation, ref, onOpenTask: onOpenTask),
      ),
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
  _Ref ref, {
  ActivityOpenTask? onOpenTask,
}) async {
  final shortId = ref.shortId;
  try {
    if (ref.taskNumber != null) {
      await onOpenTask?.call(channel.id, ref.taskNumber!);
      return;
    }
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
