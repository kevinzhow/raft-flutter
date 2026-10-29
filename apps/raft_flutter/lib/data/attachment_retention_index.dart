import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart' show MessageLedger;

import 'attachment_image_repository.dart';

/// One ledger mutation applied without walking the rest of history.
typedef AttachmentLedgerChange = ({
  int revision,
  String channelId,
  String? messageId,
  bool removed,
});

class _Entry {
  _Entry(this.messageId, this.metadata);
  final String messageId;
  final Map<String, dynamic> metadata;
}

/// Receiver-local history metadata for retaining images after their leases end.
/// Reads current admission and ledger facts without subscribing or owning media.
class AttachmentRetentionIndex {
  AttachmentRetentionIndex({
    required this._ledgerRevision,
    required this._stateStamp,
    required this._scope,
    required this._channels,
    required this._dms,
    required this._revokedChannels,
    required this._canView,
    required this._messages,
    this._ledgerChanges,
    this._message,
    this._discardLedgerChanges,
  });

  /// Reads one ledger directly, including its unread change record.
  /// The caller still supplies admission.
  AttachmentRetentionIndex.forLedger({
    required MessageLedger ledger,
    required int Function() stateStamp,
    required AttachmentImageScope Function() scope,
    required List<RaftChannel> Function() channels,
    required List<RaftChannel> Function() dms,
    required Set<String> Function() revokedChannels,
    required bool Function(RaftChannel) canView,
  }) : this(
         ledgerRevision: () => ledger.revision,
         stateStamp: stateStamp,
         scope: scope,
         channels: channels,
         dms: dms,
         revokedChannels: revokedChannels,
         canView: canView,
         messages: ledger.messages,
         ledgerChanges: (since) => _attachmentLedgerChanges(ledger, since),
         message: ledger.message,
         discardLedgerChanges: ledger.discardChangesThrough,
       );

  final int Function() _ledgerRevision, _stateStamp;
  final AttachmentImageScope Function() _scope;
  final List<RaftChannel> Function() _channels, _dms;
  final Set<String> Function() _revokedChannels;
  final bool Function(RaftChannel) _canView;
  final List<Map<String, dynamic>> Function(String) _messages;
  final List<AttachmentLedgerChange>? Function(int since)? _ledgerChanges;
  final Map<String, dynamic>? Function(String channelId, String messageId)?
  _message;
  final void Function(int revision)? _discardLedgerChanges;

  Object? _retainedAdmissionStamp;
  List<String> _retainedChannelIds = const [];
  List<String>? _indexedAdmission;
  AttachmentImageScope? _indexedScope;
  int _appliedRevision = -1;
  bool _hasIndex = false;
  Set<String> _admittedIds = const {};
  final Set<String> _indexedChannels = {};
  final Map<String, Map<String, List<_Entry>>> _index = {};
  final Map<String, Map<String, Set<String>>> _attachmentIds = {};
  final Map<String, Map<String, String>> _threadLinks = {};
  final Map<String, int> _threadRefs = {};
  int _retainedIndexBuilds = 0;

  /// Number of complete history scans, excluding admission-only checks and
  /// updates that touch only the messages in a known ledger delta.
  int get debugBuilds => _retainedIndexBuilds;

  bool retains(AttachmentImageKey key) {
    _sync();
    final candidates =
        _index[key.channelId]?[key.attachmentId] ?? const <_Entry>[];
    for (final entry in candidates) {
      final canonical = AttachmentImageKey.fromMetadata(
        scope: key.scope,
        channelId: key.channelId,
        metadata: entry.metadata,
        rendition: key.rendition,
        target: key.target,
      );
      if (canonical == key) return true;
    }
    return false;
  }

  List<String> _admittedAttachmentChannels() {
    // Keep every former index invalidation boundary. In particular a normal
    // notification still reevaluates can() and revocations before reusing any
    // metadata, even when the channel list has the same identity and length.
    final stamp = (
      _ledgerRevision(),
      _stateStamp(),
      _scope(),
      identityHashCode(_channels()),
      _channels().length,
      identityHashCode(_dms()),
      _dms().length,
      _revokedChannels().length,
    );
    if (stamp == _retainedAdmissionStamp) return _retainedChannelIds;
    final admitted = [
      for (final channel in [..._channels(), ..._dms()])
        if (!_revokedChannels().contains(channel.id) && _canView(channel))
          channel.id,
    ];
    if (!listEquals(admitted, _retainedChannelIds)) {
      _retainedChannelIds = List.unmodifiable(admitted);
    }
    _retainedAdmissionStamp = stamp;
    return _retainedChannelIds;
  }

  void _sync() {
    final admitted = _admittedAttachmentChannels();
    final scope = _scope();
    final revision = _ledgerRevision();
    final admissionSame =
        _hasIndex &&
        identical(admitted, _indexedAdmission) &&
        scope == _indexedScope;
    if (admissionSame && revision == _appliedRevision) return;
    if (admissionSame && _tryApply(revision)) return;
    _rebuild(admitted, scope, revision);
  }

  bool _tryApply(int revision) {
    final readChanges = _ledgerChanges;
    final readMessage = _message;
    if (readChanges == null || readMessage == null) return false;
    final changes = readChanges(_appliedRevision);
    if (changes == null) return false;
    if (changes.isEmpty || changes.last.revision != revision) return false;
    for (final change in changes) {
      _apply(change, readMessage);
    }
    _appliedRevision = revision;
    _discardLedgerChanges?.call(revision);
    return true;
  }

  void _apply(
    AttachmentLedgerChange change,
    Map<String, dynamic>? Function(String channelId, String messageId) read,
  ) {
    final channelId = change.channelId;
    final messageId = change.messageId;
    if (messageId == null) {
      _clearChannel(channelId);
      return;
    }
    if (change.removed) {
      _removeMessage(channelId, messageId);
      return;
    }
    final row = read(channelId, messageId);
    if (row == null) {
      _removeMessage(channelId, messageId);
      return;
    }
    final admitted = _admittedIds.contains(channelId);
    if (!_indexedChannels.contains(channelId)) {
      if (!admitted) return;
      _indexChannel(channelId, recordThreads: true);
      return;
    }
    _strip(channelId, messageId);
    _addAttachments(channelId, messageId, row);
    if (admitted) {
      _linkThread(channelId, messageId, RaftMessage(row).threadId);
    }
  }

  void _rebuild(
    List<String> admitted,
    AttachmentImageScope scope,
    int revision,
  ) {
    ++_retainedIndexBuilds;
    _index.clear();
    _attachmentIds.clear();
    _threadLinks.clear();
    _threadRefs.clear();
    _indexedChannels.clear();
    _admittedIds = Set.of(admitted);
    for (final id in admitted) {
      final channelIds = <String>{id};
      for (final message in _messages(id)) {
        final thread = RaftMessage(message).threadId;
        if (thread == null) continue;
        channelIds.add(thread);
        final messageId = message['id'];
        if (messageId is! String) continue;
        (_threadLinks[id] ??= {})[messageId] = thread;
        _threadRefs[thread] = (_threadRefs[thread] ?? 0) + 1;
      }
      for (final channelId in channelIds) {
        if (_index.containsKey(channelId)) continue;
        _indexedChannels.add(channelId);
        _index[channelId] = {};
        for (final message in _messages(channelId)) {
          final messageId = message['id'];
          if (messageId is! String) continue;
          _addAttachments(channelId, messageId, message);
        }
      }
    }
    _indexedAdmission = admitted;
    _indexedScope = scope;
    _appliedRevision = revision;
    _hasIndex = true;
    _discardLedgerChanges?.call(revision);
  }

  void _indexChannel(String channelId, {required bool recordThreads}) {
    if (_indexedChannels.contains(channelId)) return;
    _indexedChannels.add(channelId);
    _index[channelId] = {};
    for (final message in _messages(channelId)) {
      final messageId = message['id'];
      if (messageId is! String) continue;
      _addAttachments(channelId, messageId, message);
      if (recordThreads) {
        _linkThread(channelId, messageId, RaftMessage(message).threadId);
      }
    }
  }

  void _addAttachments(
    String channelId,
    String messageId,
    Map<String, dynamic> row,
  ) {
    final byAttachment = _index[channelId];
    if (byAttachment == null) return;
    for (final metadata in RaftMessage(row).attachments) {
      final id = metadata['id'];
      if (id is! String) continue;
      (byAttachment[id] ??= []).add(_Entry(messageId, metadata));
      (_attachmentIds[channelId] ??= {})
          .putIfAbsent(messageId, () => {})
          .add(id);
    }
  }

  void _strip(String channelId, String messageId) {
    final ids = _attachmentIds[channelId]?.remove(messageId);
    if (ids == null) return;
    final byAttachment = _index[channelId];
    if (byAttachment == null) return;
    for (final id in ids) {
      final list = byAttachment[id];
      if (list == null) continue;
      list.removeWhere((entry) => entry.messageId == messageId);
      if (list.isEmpty) byAttachment.remove(id);
    }
  }

  void _removeMessage(String channelId, String messageId) {
    _strip(channelId, messageId);
    if (_threadLinks[channelId]?.containsKey(messageId) ?? false) {
      _linkThread(channelId, messageId, null);
    }
  }

  void _linkThread(String channelId, String messageId, String? thread) {
    final current = _threadLinks[channelId]?[messageId];
    if (current == thread) return;
    if (current != null) {
      _threadLinks[channelId]!.remove(messageId);
      if (_threadLinks[channelId]!.isEmpty) _threadLinks.remove(channelId);
      _releaseRef(current);
    }
    if (thread == null) return;
    (_threadLinks[channelId] ??= {})[messageId] = thread;
    final next = (_threadRefs[thread] ?? 0) + 1;
    _threadRefs[thread] = next;
    if (next == 1 && !_indexedChannels.contains(thread)) {
      _indexChannel(thread, recordThreads: _admittedIds.contains(thread));
    }
  }

  void _releaseRef(String thread) {
    final current = _threadRefs[thread];
    if (current == null) return;
    if (current > 1) {
      _threadRefs[thread] = current - 1;
      return;
    }
    _threadRefs.remove(thread);
    if (_admittedIds.contains(thread)) return;
    _clearChannel(thread);
  }

  void _clearChannel(String channelId) {
    final links = _threadLinks.remove(channelId);
    _index.remove(channelId);
    _attachmentIds.remove(channelId);
    _indexedChannels.remove(channelId);
    if (links != null) {
      for (final thread in links.values) {
        _releaseRef(thread);
      }
    }
    if (_admittedIds.contains(channelId) || (_threadRefs[channelId] ?? 0) > 0) {
      _indexedChannels.add(channelId);
      _index[channelId] = {};
    }
  }
}

List<AttachmentLedgerChange>? _attachmentLedgerChanges(
  MessageLedger ledger,
  int since,
) {
  final changes = ledger.changesAfter(since);
  if (changes == null) return null;
  return [
    for (final change in changes)
      (
        revision: change.revision,
        channelId: change.channelId,
        messageId: change.messageId,
        removed: change.removed,
      ),
  ];
}
