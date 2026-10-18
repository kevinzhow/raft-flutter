import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import 'cause_notice.dart';
import 'composer_visit_state.dart';
import 'shared_draft_attachment.dart';
import 'upload_mime.dart';
import 'user_error.dart';
import 'workspace_composer.dart';
import 'workspace_domain_ports.dart';
import 'workspace_editor_entrypoints.dart';
import '../platform/device_timezone.dart';
import 'workspace_sends.dart';
import 'workspace_session_context.dart';
import 'workspace_uploads.dart';

/// Receiver-local editor behavior using the existing session composer.
///
/// Public source dispatch is chosen by the composition root. The immediate
/// source here is only for the old private-store aliases and draft admission;
/// sharing a composer does not make two receivers share their visit state.
class WorkspaceEditor implements WorkspaceEditorEntrypoints {
  WorkspaceEditor({
    required this.context,
    required this.transport,
    required this.presentation,
    required this.presentationWrites,
    required this.messages,
    required this.windows,
    required this.conversations,
    required this.threads,
    required this.directory,
    required this.composer,
    this._entrypoints,
    this.presentationSource,
    this.restoreSharedAttachment,
    this.discardSharedScope,
  }) {
    _composerVisits = ComposerVisitState((scope) {
      (presentationSource?.entrypoints.sendWarnings ?? entrypoints.sendWarnings)
          .remove(scope);
    });
  }

  final WorkspaceSessionContext context;
  final WorkspaceTransportPort transport;
  final WorkspacePresentationReadPort presentation;
  final WorkspacePresentationWritePort presentationWrites;
  final WorkspaceMessageRowsPort messages;
  final WorkspaceWindowFactsPort windows;
  final WorkspaceConversationCommandsPort conversations;
  final WorkspaceThreadCreationPort threads;
  final WorkspaceChannelDirectoryPort directory;
  final WorkspaceComposer composer;
  final WorkspaceEditorEntrypoints? _entrypoints;
  WorkspaceEditorEntrypoints get entrypoints => _entrypoints ?? this;
  final WorkspaceEditor? presentationSource;
  final RestoreSharedDraftAttachment? restoreSharedAttachment;
  final Future<void> Function(
    String origin,
    String principal,
    String server,
    String? channel,
  )?
  discardSharedScope;

  RaftClient get client => transport.client;
  RaftRecord? get server => context.server;
  RaftChannel? get channel => presentation.channel;
  bool get _disposed => context.disposed;
  String get navigationAuthority => presentation.navigationAuthority;
  String? get _presentationAuthority => presentation.presentationAuthority;
  String? get threadParentMessageId => windows.threadParentMessageId;
  String? get threadChannelId => windows.threadChannelId;
  int get channelGeneration => windows.windowGeneration(false);
  int get threadGeneration => windows.windowGeneration(true);
  bool get hasNewer => windows.hasNewer;
  List<RaftChannel> get channels => directory.channels;
  List<RaftChannel> get dms => directory.dms;
  Future<void> selectChannel(RaftChannel next, {bool autoRead = true}) =>
      conversations.selectChannel(next, autoRead: autoRead);
  Future<String?> ensureThread() => threads.ensureThread();
  Future<dynamic> query(String path) => transport.query(path);
  Future<dynamic> command(String method, String path, {dynamic data}) =>
      transport.command(method, path, data: data);

  @override
  final Map<String, List<Map<String, dynamic>>> pendingMentionActions = {};
  @override
  final Map<String, ({List<String> unresolved, bool agentStopped})>
  sendWarnings = {};
  final CauseNotices<String> _composerNotices = CauseNotices<String>();
  late final ComposerVisitState _composerVisits;
  static const multipartUploadSafeLimitBytes = 90 * 1024 * 1024;

  @override
  Map<String, String> get drafts =>
      !composer.ownedBy(context.receiverKey) && (server == null || _disposed)
      ? const {}
      : composer.drafts;

  @override
  void saveDraft(String text, {bool thread = false}) {
    final source = presentationSource;
    if (source != null) {
      if (_presentationAuthority == source.navigationAuthority) {
        source.savePresentedDraft(entrypoints.draftScope(thread: thread), text);
      }
      return;
    }
    savePresentedDraft(entrypoints.draftScope(thread: thread), text);
  }

  void savePresentedDraft(String? scope, String text) {
    if (scope == null || _disposed || context.isChannelRevoked(scope)) return;
    entrypoints.drafts[scope] = text;
    unawaited(saveDraftScope(scope));
  }

  Future<void> saveDraftScope(String scope, {bool requiredSuccess = false}) =>
      composer.saveScope(scope, requiredSuccess: requiredSuccess);

  Future<void> stageSharedDraft(
    String text,
    List<SharedDraftAttachment> files, {
    String? sourceToken,
  }) {
    final scope = entrypoints.draftScope();
    if (scope == null) throw const RaftApiException('Choose a conversation.');
    return composer.stageSharedDraft(
      scope,
      text,
      files,
      sourceToken: sourceToken,
      persist: saveDraftScope,
    );
  }

  void updateDraftFromShare(String text) {
    final scope = entrypoints.draftScope();
    if (scope == null) return;
    entrypoints.saveDraft(text);
    _draftRevisions[scope] = (_draftRevisions[scope] ?? 0) + 1;
    context.changed();
  }

  Map<String, int> get _draftRevisions => composer.revisions;

  int draftRevision({bool thread = false}) =>
      _draftRevisions[entrypoints.draftScope(thread: thread)] ?? 0;

  ValueListenable<int> draftChanges({bool thread = false}) =>
      composer.changes(entrypoints.draftScope(thread: thread));

  Future<void> restoreDraft(String scope) async {
    final generation = messages.generation;
    await composer.restore(
      scope,
      current: () => generation == messages.generation && !_disposed,
      restoreFiles: (files) async {
        final principal = client.user?.id, origin = client.origin;
        if (restoreSharedAttachment == null || principal == null) return;
        await composer.uploads.restore(
          scope,
          files,
          read: (reference) =>
              restoreSharedAttachment!(reference, origin, principal),
        );
      },
      restored: context.changed,
    );
  }

  Map<String, List<UploadDraft>> get _uploads => composer.uploads.byScope;

  List<Map<String, dynamic>> pendingMentionsFor({bool thread = false}) =>
      (presentationSource?.entrypoints.pendingMentionActions ??
          entrypoints.pendingMentionActions)[entrypoints.draftScope(
        thread: thread,
      )] ??
      const [];

  void dismissPendingMention(String resolutionId, {bool thread = false}) {
    final scope = entrypoints.draftScope(thread: thread);
    final list = entrypoints.pendingMentionActions[scope];
    if (list == null) return;
    entrypoints.pendingMentionActions[scope!] = [
      for (final a in list)
        if (a['resolutionId'] != resolutionId) a,
    ];
    context.changed();
  }

  ({List<String> unresolved, bool agentStopped}) sendWarningsFor({
    bool thread = false,
  }) =>
      (presentationSource?.entrypoints.sendWarnings ??
          entrypoints.sendWarnings)[entrypoints.draftScope(thread: thread)] ??
      (unresolved: const [], agentStopped: false);

  void dismissSendWarnings({bool thread = false}) {
    final scope = entrypoints.draftScope(thread: thread);
    if (scope == null || entrypoints.sendWarnings.remove(scope) == null) return;
    context.changed();
  }

  Future<Set<String>> executeMentionActions(
    String action,
    List<String> resolutionIds,
  ) async =>
      (await entrypoints.executeMentionActionResults(action, resolutionIds))
          .entries
          .where((r) => mentionActionSucceeded(action, r.value))
          .map((r) => r.key)
          .toSet();

  static bool mentionActionSucceeded(String action, Map? result) =>
      result?['status'] == (action == 'notify' ? 'queued' : 'delivered');

  @override
  Future<Map<String, Map<String, dynamic>>> executeMentionActionResults(
    String action,
    List<String> resolutionIds,
  ) async {
    final value = await command(
      'POST',
      '/messages/mention-actions/execute',
      data: {'action': action, 'resolutionIds': resolutionIds},
    );
    return {
      if (value is Map && value['results'] is List)
        for (final r in (value['results'] as List).whereType<Map>())
          if (r['resolutionId'] is String)
            r['resolutionId'] as String: Map<String, dynamic>.from(r),
    };
  }

  @override
  String? draftScope({bool thread = false}) => thread
      ? (threadParentMessageId == null ? null : 'thread:$threadParentMessageId')
      : channel?.id;

  @override
  bool get conversationPaused =>
      channel != null && channelConversionBlocksSending(channel!.json);

  @override
  List<UploadDraft> uploads({bool thread = false}) =>
      (presentationSource?._uploads ?? _uploads)[entrypoints.draftScope(
        thread: thread,
      )] ??
      [];

  bool uploadsReady({bool thread = false}) =>
      !composer.sends.queued(entrypoints.draftScope(thread: thread)) &&
      entrypoints
          .uploads(thread: thread)
          .every((u) => u.id != null || u.queued && u.error == null);

  String? composerErrorFor({bool thread = false}) {
    final scope = entrypoints.draftScope(thread: thread);
    return scope == null
        ? null
        : (presentationSource?._composerNotices ?? _composerNotices).messageFor(
            scope,
          );
  }

  void setComposerError(
    String? message, {
    bool thread = false,
    bool Function()? whileTrue,
  }) {
    final scope = entrypoints.draftScope(thread: thread);
    if (scope == null) return;
    if (_raiseComposerNotice(scope, message, whileTrue: whileTrue)) {
      context.changed();
    }
  }

  bool _raiseComposerNotice(
    String scope,
    String? message, {
    bool Function()? whileTrue,
  }) {
    final visit = _visitOf(scope);
    return (presentationSource?._composerNotices ?? _composerNotices).raise(
      scope,
      message,
      whileTrue: () => visit == _visitOf(scope) && (whileTrue?.call() ?? true),
    );
  }

  int _visitOf(String scope) {
    synchronizeVisits();
    return _composerVisits.visitOf(scope);
  }

  void synchronizeVisits() {
    final channelScope = entrypoints.draftScope(),
        threadScope = entrypoints.draftScope(thread: true);
    _composerVisits.synchronize(channelScope, threadScope);
  }

  Map<String, String?> get _shareHolds => composer.uploads.holds;

  @override
  Map<String, String?> get shareHolds =>
      presentationSource?.entrypoints.shareHolds ?? _shareHolds;

  @override
  bool sharedBlocked({bool thread = false}) =>
      !thread && entrypoints.shareHolds.containsKey(entrypoints.draftScope());

  String? shareNoticeFor({bool thread = false}) =>
      thread ? null : entrypoints.shareHolds[entrypoints.draftScope()];

  void holdShared(String scope) {
    if (_shareHolds.containsKey(scope)) return;
    _shareHolds[scope] = null;
    context.changed();
  }

  void releaseShared(String scope) {
    if (!_shareHolds.containsKey(scope) || _shareHolds[scope] != null) return;
    _shareHolds.remove(scope);
    context.changed();
  }

  void blockShared(String scope, String notice) {
    if (_disposed || _shareHolds[scope] == notice) return;
    _shareHolds[scope] = notice;
    context.changed();
  }

  Future<void> adoptResolvedDm(String pendingId, RaftChannel real) async {
    if (_disposed) return;
    final wasOpen = channel?.id == pendingId;
    composer.adoptScope(pendingId, real.id);
    directory.recordRowWrite(real.id);
    if (wasOpen) presentationWrites.setSelectedChannel(real);
    directory.putRow(real);
    context.changed();
    if (wasOpen) {
      await selectChannel(
        [
          ...channels,
          ...dms,
        ].firstWhere((c) => c.id == real.id, orElse: () => real),
        autoRead: false,
      );
    }
  }

  static int? uploadLimitFromCapabilities(dynamic value) {
    final max = value is Map ? value['maxBytes'] : null;
    if (max is! num || !max.isFinite || max <= 0) return null;
    final bytes = max.toInt();
    return value['directUploadEnabled'] == true &&
            bytes > multipartUploadSafeLimitBytes
        ? multipartUploadSafeLimitBytes
        : bytes;
  }

  @override
  Future<int?> uploadLimitBytes() async {
    try {
      return uploadLimitFromCapabilities(
        await query('/attachments/upload-capabilities'),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> attachSelection(
    List<({String name, Uint8List bytes})> files, {
    bool thread = false,
    required String Function(String key, Map<String, Object> args) text,
  }) {
    if (entrypoints.draftScope(thread: thread) == null || _disposed) {
      return Future<void>.value();
    }
    return composer.uploads.select(files, _uploadVisit(thread), text: text);
  }

  String _uploadAuthority() => jsonEncode([
    client.generation,
    client.user?.id,
    client.serverId,
    server?.id,
    server?.string('role'),
    channel?.joined,
    channel?.archived,
    channel?.json['channelCapabilities'],
  ]);

  static String uploadErrorText(Object failure) =>
      WorkspaceUploads.uploadErrorText(failure);

  ComposerUploadVisit _uploadVisit(bool thread) {
    final scope = entrypoints.draftScope(thread: thread)!;
    final generation = messages.generation, authority = _uploadAuthority();
    return ComposerUploadVisit(
      scope: scope,
      channelId: channel?.id,
      thread: thread,
      selectionCurrent: () =>
          !_disposed &&
          generation == messages.generation &&
          scope == entrypoints.draftScope(thread: thread) &&
          authority == _uploadAuthority(),
      resolveThread: ensureThread,
      limit: entrypoints.uploadLimitBytes,
      upload: (id, draft, progress) => draft.local != null
          ? client.uploadStream(
              id,
              draft.local!.openRead,
              draft.sizeBytes,
              draft.filename,
              cancellation: draft.cancel,
              onProgress: progress,
              mimeType: composerMimeType(draft.filename),
            )
          : client.upload(
              id,
              draft.bytes,
              draft.filename,
              cancellation: draft.cancel,
              onProgress: progress,
              mimeType: composerMimeType(draft.filename),
            ),
      persist: saveDraftScope,
      notice: (message) => _raiseComposerNotice(scope, message),
    );
  }

  Future<void> attachUpload(
    String name,
    Uint8List bytes, {
    bool thread = false,
  }) async {
    if (entrypoints.draftScope(thread: thread) == null || _disposed) return;
    await composer.uploads.attach(name, bytes, _uploadVisit(thread));
  }

  Future<void> retryUpload(UploadDraft draft, {bool thread = false}) async {
    if (entrypoints.draftScope(thread: thread) == null || _disposed) return;
    await composer.uploads.retry(draft, _uploadVisit(thread));
  }

  Future<void> _transferUpload(
    UploadDraft draft, {
    required bool thread,
  }) async {
    if (entrypoints.draftScope(thread: thread) == null || _disposed) return;
    await composer.uploads.transfer(draft, _uploadVisit(thread));
  }

  void removeUpload(UploadDraft draft, {bool thread = false}) {
    composer.uploads.remove(draft, saveDraftScope);
  }

  Future<bool> send(
    String text, {
    bool thread = false,
    List<String>? attachments,
    List<Map<String, dynamic>>? mentions,
    String? randomId,
    bool asTask = false,
    String Function(int count)? attachmentsOnlyBody,
    void Function(int window)? onWindowRefreshed,
  }) async {
    if (entrypoints.conversationPaused) {
      presentationWrites.assignError('Channel conversion in progress');
      context.changed();
      return false;
    }
    // Shared content whose destination is not confirmed yet is never sent.
    if (entrypoints.sharedBlocked(thread: thread)) return false;
    presentationWrites.assignError(null);
    final intendedScope = entrypoints.draftScope(thread: thread);
    if (intendedScope == null) return false;
    final scope = intendedScope, intendedChannel = channel?.id;
    final intendedParent = threadParentMessageId, role = server?.string('role');
    var window = thread ? threadGeneration : channelGeneration;
    bool current() =>
        !_disposed &&
        scope == entrypoints.draftScope(thread: thread) &&
        intendedChannel == channel?.id &&
        (!thread || intendedParent == threadParentMessageId) &&
        window == (thread ? threadGeneration : channelGeneration) &&
        role == server?.string('role') &&
        !entrypoints.conversationPaused;
    final selectedMentions = [
      for (final mention in mentions ?? <Map<String, dynamic>>[])
        Map<String, dynamic>.unmodifiable({
          'type': mention['type'],
          'id': mention['id'],
          'name': mention['name'],
        }),
    ];
    return composer.sends.send(
      text,
      client: client,
      attachments: attachments,
      mentions: selectedMentions,
      randomId: randomId,
      asTask: asTask,
      readTimezone: thread ? null : readDeviceTimezone,
      attachmentsOnlyBody:
          attachmentsOnlyBody ??
          (count) => count == 1 ? '[1 attachment]' : '[$count attachments]',
      visit: ComposerSendVisit(
        scope: scope,
        channelId: thread ? threadChannelId : intendedChannel,
        parentChannelId: intendedChannel,
        displaySeq: messages.watermark,
        author: {
          'senderId': client.user?.id ?? '',
          'senderType': 'user',
          'senderName':
              client.user?.firstNonEmpty(const ['displayName', 'name']) ?? '',
        },
        current: current,
        prepare: () async {
          if (!thread && hasNewer && channel != null) {
            final refreshing = selectChannel(channel!);
            window = channelGeneration;
            await refreshing;
            if (!current()) return null;
            onWindowRefreshed?.call(window);
          }
          if (!current()) return null;
          return thread ? await ensureThread() : intendedChannel;
        },
        limit: entrypoints.uploadLimitBytes,
        transfer: (file) => _transferUpload(file, thread: thread),
        started: () {
          _composerNotices.clear(scope);
          entrypoints.sendWarnings.remove(scope);
        },
        failed: (cause) {
          presentationWrites.assignError(
            userErrorText(
              cause,
              fallback: 'Failed to send message',
              where: 'send message',
            ),
          );
          context.changed();
        },
        received: (sent) {
          entrypoints.pendingMentionActions[scope] =
              normalizePendingMentionActions(
                sent.receipt['pendingMentionActions'],
              );
          entrypoints.sendWarnings[scope] = (
            unresolved: [
              for (final handle
                  in (sent.receipt['unresolvedMentionHandles'] as List? ??
                      const []))
                if (handle is String) handle,
            ],
            agentStopped:
                (sent.receipt['deliveryWarnings'] as List? ?? const []).any(
                  (w) =>
                      w is Map &&
                      w['targetType'] == 'agent' &&
                      w['reason'] == 'agent_stopped' &&
                      w['targetId'] is String &&
                      (w['targetId'] as String).isNotEmpty,
                ),
          );
        },
      ),
    );
  }
}

/// Web `normalizePendingMentionActions`: keep well-formed rows only.
List<Map<String, dynamic>> normalizePendingMentionActions(dynamic value) => [
  if (value is List)
    for (final row in value.whereType<Map>())
      if (row['resolutionId'] is String &&
          row['targetType'] is String &&
          row['availableActions'] is List)
        Map<String, dynamic>.from(row),
];
