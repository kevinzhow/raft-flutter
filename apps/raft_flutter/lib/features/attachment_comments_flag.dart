import 'dart:async';

import '../data/feature_flag_client_facts.dart';
import '../data/plain_listenable.dart';
import '../data/workspace_controller.dart';
import 'management_support.dart'
    show cachedServerFlag, pageIdentity, rememberServerFlag;

/// Web `ATTACHMENT_COMMENTS_FEATURE_FLAG_KEY` (`useAttachmentCommentsEnabled`):
/// attachment comments (the panel in a preview, the `re:` chip on a comment
/// message) exist only on servers where the flag is on.
const attachmentCommentsFlag = 'attachment_comments_v0';

/// The flag's value for the workspace the controller shows, evaluated once per
/// identity and remembered for the next first frame.
class AttachmentCommentsGate extends PlainListenable {
  AttachmentCommentsGate._(this._w);

  static final _all = Expando<AttachmentCommentsGate>('attachment comments');

  static AttachmentCommentsGate of(WorkspaceController w) =>
      _all[w] ??= AttachmentCommentsGate._(w);

  final WorkspaceController _w;
  String? _evaluatedFor;
  bool? _enabled;

  /// What is known now: this session's answer, else the remembered one, else off.
  bool get enabled =>
      _enabled ?? cachedServerFlag(_w, attachmentCommentsFlag) ?? false;

  /// Asks the server once per identity; listeners hear a change.
  Future<void> ensure() async {
    final server = _w.server?.id;
    if (server == null || _w.client.user == null) return;
    final identity = pageIdentity(_w);
    if (_evaluatedFor == identity) return;
    _evaluatedFor = identity;
    try {
      final result = await _w.client.post(
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(
          keys: [attachmentCommentsFlag],
          serverId: server,
        ),
      );
      final on =
          result is Map &&
          result['evaluations'] is List &&
          (result['evaluations'] as List).whereType<Map>().any(
            (f) => f['key'] == attachmentCommentsFlag && f['enabled'] == true,
          );
      // Judged before it is remembered: the memory feeds [enabled] too.
      final before = enabled;
      rememberServerFlag(_w, attachmentCommentsFlag, on, identity);
      if (identity != pageIdentity(_w)) return;
      _enabled = on;
      if (before != on) notify();
    } catch (_) {
      // An unresolved flag stays off (or as last remembered).
      if (_evaluatedFor == identity) _evaluatedFor = null;
    }
  }
}
