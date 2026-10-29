// Web ChatPanel footer states (components/message/ChatPanel.tsx, the
// `ConversationPanelFooter` chain): which of composer / archived notice /
// joint-locked banner / guest read-only banner / Join CTA the channel shows,
// and the joint over-limit grace banner above it (the footer widgets live in
// raft_ui: RaftChannel*Footer, RaftChannelGraceBanner).
//
// The read-only quota branch (`isReadOnlyByQuota`) is absent on purpose:
// shared PLAN_CONFIG maxChannels is -1 for every plan, so Web never reaches it.
import '../data/source_time_formatter.dart';
import '../data/workspace_controller.dart';

enum ChannelFooterKind { composer, archived, jointLocked, guestReadOnly, join }

/// Source isJointChannelReadOnly: the server flag, or the grace deadline passed.
bool jointChannelReadOnly(Map<String, dynamic> channel, DateTime now) {
  if (channel['type'] != 'joint') return false;
  if (channel['jointBillingLocked'] == true) return true;
  final deadline = DateTime.tryParse('${channel['jointOverLimitGraceEndsAt']}');
  return deadline != null && !now.isBefore(deadline);
}

/// Source jointChannelGraceEndsAt: the deadline while over the limit and not
/// yet read-only; null otherwise.
String? jointChannelGraceEndsAt(Map<String, dynamic> channel, DateTime now) {
  if (channel['type'] != 'joint') return null;
  final ends = channel['jointOverLimitGraceEndsAt'];
  if (ends is! String || ends.isEmpty) return null;
  return jointChannelReadOnly(channel, now) ? null : ends;
}

/// The footer a regular (non-thread) channel conversation shows, or null when
/// membership is not hydrated or the viewer may not join (Web renders nothing).
ChannelFooterKind? channelFooterKind(WorkspaceController w, DateTime now) {
  final channel = w.channel;
  if (channel == null) return null;
  final json = channel.json;
  if (channel.archived) return ChannelFooterKind.archived;
  if (jointChannelReadOnly(json, now)) return ChannelFooterKind.jointLocked;
  final guest = w.server?.string('role') == 'guest';
  final implicitlyJoined = const ['dm', 'thread'].contains(channel.type);
  final joined = implicitlyJoined ? true : channel.joined;
  final guestJoinable = json['guestJoinable'] == true;
  if (guest && (joined || !guestJoinable)) {
    return ChannelFooterKind.guestReadOnly;
  }
  if (joined) return ChannelFooterKind.composer;
  return ChannelFooterKind.join;
}

/// Formats [ends] for the grace banner copy.
String channelGraceDeadlineLabel(SourceTimeFormatter formatter, String ends) =>
    formatter.mediumDateTime(ends, followPreference: false);
