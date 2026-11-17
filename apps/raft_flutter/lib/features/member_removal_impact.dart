// What removing a member, or leaving, takes offline (Web v1.24.0
// components/member/useMemberRemovalImpact.ts and MemberRemovalImpactNote.tsx):
// read from `GET /servers/:id/members/:memberId/removal-impact`. Only the part
// Administration's "Add owner/admin" row needs is here: the read and
// OwnComputersTransferNote.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'agent_activity_summaries.dart' show joinConjunction;
import 'icu_message.dart';
import 'management_support.dart' show managementMap, pageIdentity;

/// `MemberRemovalImpact`: the Computers the member attached (the route names
/// at most three) and the agents of other people on them.
class MemberRemovalImpact {
  const MemberRemovalImpact({
    required this.computers,
    required this.computerNames,
    required this.othersAgents,
  });
  final int computers, othersAgents;
  final List<String> computerNames;

  static MemberRemovalImpact parse(Object? value) {
    final map = managementMap(value);
    int count(Object? n) => n is num ? n.toInt() : 0;
    return MemberRemovalImpact(
      computers: count(map['computers']),
      othersAgents: count(map['othersAgents']),
      computerNames: [
        for (final name in (map['computerNames'] as List? ?? const []))
          if (name is String) name,
      ],
    );
  }
}

enum MemberRemovalImpactKind { none, loading, ready, failed }

/// `useMemberRemovalImpact`: one read per path; a path of null reads nothing,
/// and the answer of an earlier path is never shown for a later one.
class MemberRemovalImpactRead {
  MemberRemovalImpactRead(this.w, this.onChange);
  final WorkspaceController w;
  final VoidCallback onChange;

  /// A read that hangs must not hold anything back: after this it counts as
  /// failed (`IMPACT_READ_TIMEOUT_MS`).
  static const timeout = Duration(seconds: 10);

  String? _path;
  MemberRemovalImpactKind kind = MemberRemovalImpactKind.none;
  MemberRemovalImpact? impact;

  /// Reads `/servers/:serverId/members/:memberId/removal-impact`; a null
  /// [memberId] asks nothing.
  void sync(String? serverId, String? memberId) {
    final path = memberId == null || serverId == null
        ? null
        : '/servers/$serverId/members/$memberId/removal-impact';
    if (path == _path) return;
    _path = path;
    impact = null;
    if (path == null) {
      kind = MemberRemovalImpactKind.none;
      return;
    }
    kind = MemberRemovalImpactKind.loading;
    unawaited(_read(path));
  }

  Future<void> _read(String path) async {
    final identity = pageIdentity(w);
    try {
      final data = await w.query(path).timeout(timeout);
      if (path != _path || identity != pageIdentity(w)) return;
      impact = MemberRemovalImpact.parse(data);
      kind = MemberRemovalImpactKind.ready;
    } catch (_) {
      if (path != _path || identity != pageIdentity(w)) return;
      kind = MemberRemovalImpactKind.failed;
    }
    onChange();
  }
}

/// `OwnComputersTransferNote`: the note under the "Add owner/admin" row when
/// the viewer, an owner, makes someone else an owner and attached Computers
/// here; nothing while the read runs, failed or finds none.
Widget? ownComputersTransferNote(
  BuildContext context,
  MemberRemovalImpactRead read,
) {
  final impact = read.impact;
  if (read.kind != MemberRemovalImpactKind.ready ||
      impact == null ||
      impact.computers <= 0) {
    return null;
  }
  final chinese = Localizations.localeOf(context).languageCode == 'zh';
  final names = joinConjunction([
    ...impact.computerNames,
    if (impact.computerNames.length < impact.computers)
      raftText(context, 'others'),
  ], chinese: chinese);
  return RaftOwnComputersTransferNote(
    icuText(
      context,
      "You attached {computers, plural, one {# Computer} other {# Computers}} here: {names}. {computers, plural, one {It stays} other {They stay}} online while you're a member. If you leave this server later, {computers, plural, one {it goes} other {they go}} offline until someone in the server sets up that machine again.",
      {'computers': impact.computers, 'names': names},
    ),
  );
}
