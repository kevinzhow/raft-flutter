import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart';

import 'workspace_session.dart';
import 'workspace_messages.dart';
import 'workspace_message_host.dart';
import 'workspace_message_ports.dart';
import 'workspace_channels.dart';
import 'workspace_message_prefetch.dart';
import 'workspace_session_bindings.dart';
import 'workspace_session_context.dart';
import 'workspace_domain_ports.dart';
import 'workspace_message_ingress.dart';
import 'announcement_store.dart';
import 'message_task_cache.dart';
import 'message_translation_store.dart';
import 'thread_agent_followers.dart';
import 'thread_search.dart';
import 'thread_unread_hint.dart';
import 'workspace_services.dart';
import 'session_scope.dart';
import 'channel_revocation.dart';
import 'channel_repository.dart';
import 'panel_caches.dart';
import 'source_channel_files_store.dart';
import 'source_activity_unread_store.dart';
import 'reaction_repository.dart';
import 'reaction_repository_ports.dart';
import 'workspace_cache.dart';
import 'workspace_device_store.dart';
import 'sidebar_repository.dart';
import 'raft_api_gateway.dart';
import 'workspace_composer.dart';
import 'workspace_uploads.dart';
import 'workspace_editor.dart';
import 'workspace_editor_entrypoints.dart';
import 'conversation_read_repository.dart';
import 'workspace_message_windows.dart';

export 'workspace_uploads.dart' show UploadDraft;
export 'workspace_editor.dart' show normalizePendingMentionActions;
export 'thread_search.dart' show WorkspaceThreadIdentity;
export 'workspace_message_commands.dart' show isThreadAbsentLookupError;
export 'conversation_window.dart' show MessageContextLoadError;
export 'workspace_message_windows.dart' show ReadingAnchor;
import 'resource_snapshot_cache.dart';
import 'workspace_entity_directory.dart';
import 'followed_threads_store.dart';
import 'raft_location.dart';
import 'workspace_navigation.dart';
import 'shared_draft_attachment.dart';
import 'message_history_pages.dart';
import 'message_history_events.dart';
import 'message_history_snapshots.dart';
import 'attachment_image_repository.dart';
import 'cache_clear.dart';
import 'attachment_url_cache.dart';
import 'attachment_media.dart';
import 'attachment_retention_index.dart';
import 'workspace_presentation.dart';
import 'workspace_presentation_ports.dart';

export 'attachment_media.dart' show WorkspaceAttachmentImageLease;
import '../platform/attachment_player_sessions.dart';

class WorkspaceController extends ChangeNotifier
    implements WorkspaceServiceAuthority, SessionScopeBinding, WorkspaceMessageHost, WorkspacePresentationSourcePort, WorkspaceReactionSourcePort {
  /// High-frequency socket events that never change workspace state.
  static const presenceEvents = WorkspaceSession.presenceEvents;

  WorkspaceController(
    this.client, {
    WorkspaceCache? cache,
    this.presentationSource,
    bool mobileNavigation = false,
    bool ownsClient = true,
    RestoreSharedDraftAttachment? restoreSharedAttachment,
    Future<void> Function(String, String, String, String?)? discardSharedScope,
    WorkspaceEntityDirectory? entityDirectory,
    FollowedThreadsStore? followedThreads,
    AttachmentImageByteStore? attachmentImageStore,
    AttachmentUrlCache? attachmentUrls,
    WorkspaceComposer? composer,
  }) {
    final bindings = _WorkspaceMessageBindings(this);
    _presentation = WorkspacePresentation(
      context: bindings,
      client: client,
      directory: bindings,
      conversations: bindings,
      source: presentationSource,
      mobileNavigation: mobileNavigation,
    );
    reactions = ReactionRepository(
      context: bindings,
      client: client,
      presentation: bindings,
      rows: bindings,
      hydration: bindings,
      source: presentationSource,
    );
    _session = WorkspaceSession(
      context: bindings,
      transport: bindings,
      device: bindings,
      entries: bindings,
      directory: bindings,
      presentation: bindings,
      messages: bindings,
      drafts: bindings,
      entities: bindings,
      revocations: bindings,
      quietFailure: _quietFailure,
      staleScope: _staleScope,
      ownsClient: ownsClient,
    );
    final conversationReads = ConversationReadRepository(
      client,
      readState: () => readState,
      revokedChannels: () => _revokedChannels,
      channelId: () => channel?.id,
      threadChannelId: () => threadChannelId,
      mobileNavigation: () => this.mobileNavigation,
      mayMarkRead: _mayMarkRead,
      markRead: (id) => markRead(id),
      channelRows: () => [...channels, ...dms],
      messages: (id) => _messages.ledger.messages(id),
      isContext: (id) => messageWindows.isContext(id),
      hasNewer: () => _messages.state.hasNewer,
      save: (kind, id, value) => _save(kind, id, value),
      changed: notifyListeners,
      prefetch: () => prefetchLikelyChannels(),
      isDiskOnly: (id) => messageWindows.isDiskOnly(id),
      visibleIds: (id) => _messages.visibleIds[id],
      generation: () => _messages.ledger.generation,
      windowGeneration: (thread) =>
          thread ? _messages.threadGeneration : _messages.channelGeneration,
      isDisposed: () => _disposed,
      refreshUnread: () => refreshUnread(),
    );
    sessionScope = SessionScope(this, ownsMedia: presentationSource == null);
    final channelRepository = ChannelRepository(
      client,
      channels: () => channels,
      dms: () => dms,
      generation: () => _messages.ledger.generation,
      identity: _syncIdentity,
      isDisposed: () => _disposed,
      revokedChannels: () => _revokedChannels,
      acceptLists: _acceptChannelLists,
      saveDirectory: (record) {
        _save('channels', '', record);
      },
      acceptSelection: (accessible) => _messages.adoptAcceptedChannelSelection(accessible),
      patchSelected: (patch) {
        if (channel != null) channel = patch(channel!);
      },
      reloadLists: () => refreshChannels(),
      reloadRow: (id) => refreshChannel(id),
      revokeChannel: _revokeChannel,
      closeDeniedThread: (id) {
        if (_messages.state.threadIdentity?.parentChannelId == id) closeThread();
      },
      changed: notifyListeners,
      setError: setError,
      quietFailure: _quietFailure,
    );
    apiGateway =
        presentationSource?.apiGateway ??
        RaftApiGateway(
          client,
          savedChanged: () => _channels.savedChanged(),
          refreshUnread: () => refreshUnread(),
        );
    deviceStore = WorkspaceDeviceStore(
      client,
      cache: cache,
      isDisposed: () => _disposed,
      isChannelRevoked: (id) => _revokedChannels.contains(id),
      isServerRevoked: (id) => _revokedServers.contains(id),
      historyTicket: messageHistoryTicket,
      readFailed: () {
        if (!_disposed) error ??= 'Local workspace history is unavailable.';
      },
      writeFailed: (message) {
        if (!_disposed) {
          error ??= message;
          notifyListeners();
        }
      },
      purgeFailed: () {
        if (!_disposed) {
          // ignore: raft_lints/avoid_imperative_notice_state -- Cache-purge device failures raise the existing one-shot notice; the device service reports failure without owning UI state.
          setError(
            'Revoked workspace data could not be removed from this device.',
          );
        }
      },
    );
    final sidebarRepository =
        presentationSource?.sidebarRepository ??
        SidebarRepository(
          client,
          order: () => sidebarOrder,
          setOrder: (value) => sidebarOrder = value,
          serverId: () => server?.id,
          loadAuthority: () =>
              jsonEncode([client.user?.id, server?.id, server?.string('role')]),
          isDisposed: () => _disposed,
          readDevice: () => _cached('sidebar-order', ''),
          saveDevice: (value) => _save('sidebar-order', '', value),
          changed: notifyListeners,
          reload: () => loadSidebar(),
        );
    _channels = WorkspaceChannels(
      context: bindings,
      transport: bindings,
      presentation: bindings,
      messages: bindings,
      windows: bindings,
      messagePrefetch: bindings,
      sessionEffects: _session,
      directory: channelRepository,
      reads: conversationReads,
      sidebar: sidebarRepository,
      effectiveReadState: () =>
          presentationSource?.readState ?? _channels.localReadState,
      refreshUnread: () => refreshUnread(),
    );
    this.composer =
        composer ??
        presentationSource?.composer ??
        WorkspaceComposer(
          owner: this,
          read: _cached,
          write: _save,
          authority: () => (
            client.origin,
            client.generation,
            client.user?.id,
            client.serverId,
            server?.string('role'),
            jsonEncode(server?.json['permissions']),
          ),
        );
    _editor = WorkspaceEditor(
      context: bindings,
      transport: bindings,
      presentation: bindings,
      presentationWrites: bindings,
      messages: bindings,
      windows: bindings,
      conversations: bindings,
      threads: bindings,
      directory: bindings,
      composer: this.composer,
      entrypoints: bindings,
      presentationSource: presentationSource?._editor,
      restoreSharedAttachment: restoreSharedAttachment,
      discardSharedScope: discardSharedScope,
    );
    attachmentMedia =
        presentationSource?.attachmentMedia ??
        AttachmentMedia(
          scope: () => attachmentImageScope,
          get: (path, {query}) => client.get(path, query: query),
          post: (path, {data}) => client.post(path, data: data),
          isDisposed: () => _disposed,
          admitsImages: () =>
              client.user != null && server?.id == client.serverId,
          isRevoked: (id) => _revokedChannels.contains(id),
          retainedByHistory: _retainsAttachmentByHistory,
          imageStore: attachmentImageStore ?? AttachmentDiskCache.installed,
          urls: attachmentUrls,
        );
    _messages = WorkspaceMessages(
      context: bindings,
      transport: bindings,
      device: deviceStore,
      presentation: bindings,
      entries: bindings,
      channels: _channels,
      session: _session,
      drafts: bindings,
      notifications: bindings,
      resolveSource: () => presentationSource?._messages,
      staleScope: _staleScope,
    );
    MessageHistoryPages.attach(this);
    services = WorkspaceServices(
      this,
      source: presentationSource,
      isDisposed: () => _disposed,
      entityScope: _entityScope,
      panelIdentity: _panelCacheIdentity,
      channelFilesAuthority: _channelFilesAuthority,
      readEntities: cache == null ? null : _readEntities,
      writeEntities: cache == null ? null : _writeEntities,
      entityDirectory: entityDirectory,
      followedThreads: followedThreads,
    );
    // Directory changes are not forwarded to this notifier: agent heartbeats,
    // last-seen and machine status patches would rebuild every workspace
    // listener. Surfaces that render entities listen to [entityDirectory]
    // (or a [WorkspaceEntitySelection] of it) directly.
    if (services.ownsEntityDirectory) addListener(_entityAuthorityChanged);
    if (presentationSource == null) {
      this.composer.sends.attach(this, _messages.sendChanged);
    }
    _session.attachSubscription(services.withServiceEvents(_session.event));
    // A route-local presentation shares its source's layers, which register.
    if (presentationSource == null) {
      _removeCacheClear = CacheClear.instance.register(
        'workspace-memory',
        clearRebuildableMemory,
      );
    }
  }

  late final WorkspaceSession _session;
  late final WorkspaceMessages _messages;
  @override
  WorkspaceMessages get messageDomain => _messages;
  late final WorkspaceChannels _channels;
  late final WorkspaceEditor _editor;

  VoidCallback? _removeCacheClear;
  late final SessionScope sessionScope;
  @override
  late final WorkspaceComposer composer;
  SidebarRepository get sidebarRepository => _channels.sidebar;
  ChannelRepository get channelRepository => _channels.directory;
  @override
  WorkspaceMessageWindows get messageWindows => _messages.messageWindows;


  /// "Clear cache": lets go of what this workspace keeps in memory and can
  /// rebuild: decoded attachment pictures nobody shows, signed attachment URLs
  /// already resolved, and the kept still pictures of videos. Pictures a
  /// widget holds, requests in flight and playing or held players stay.
  @visibleForTesting
  void clearRebuildableMemory() {
    attachmentMedia.trimRebuildable();
  }

  /// Borrowed editor controllers project messages but never own the session,
  /// membership recovery, server selection, socket resume, or client teardown.
  bool get ownsClient => _session.ownsClient;
  @override
  final RaftClient client;
  late final RaftApiGateway apiGateway;
  @override
  late final WorkspaceDeviceStore deviceStore;
  @override
  WorkspaceCache? get cache => deviceStore.cache;

  /// Route-local presentation borrows the session and accepted stores. Only
  /// the source reduces socket events and owns server/bootstrap lifecycle.
  final WorkspaceController? presentationSource;
  late final WorkspacePresentation _presentation;
  bool get presentationActive => _presentation.presentationActive;
  set presentationActive(bool value) => _presentation.presentationActive = value;
  RestoreSharedDraftAttachment? get restoreSharedAttachment =>
      _editor.restoreSharedAttachment;
  @override
  Future<void> Function(String, String, String, String?)?
  get discardSharedScope => _editor.discardSharedScope;
  late final WorkspaceServices services;
  @override
  WorkspaceEntityDirectory get entityDirectory => services.entityDirectory;

  /// Server-scoped followed threads, shared with borrowed controllers.
  @override
  FollowedThreadsStore get followedThreads => services.followedThreads;

  /// Web `useTranslationStore`: translation settings and the in-memory
  /// translation cache, created on first use.
  @override
  MessageTranslationStore get translations => services.translations;

  /// Web ThreadPanel in-thread search state (bar, query, matches), created on
  /// first use; a presentation mirror shares its source's.
  @override
  ThreadSearch get threadSearch => services.threadSearch;

  /// Web `useThreadAgentFollowerStore`: the agents following each thread.
  @override
  ThreadAgentFollowers get threadFollowers => services.threadFollowers;

  /// Web `useAnnouncementStore`: the account-level announcement queue,
  /// living as long as this account session.
  @override
  AnnouncementStore get announcements => services.announcements;

  /// Web `useOnboardingAnnouncementGateStore` (session memory per account).
  @override
  AnnouncementOnboardingGate get announcementGate => services.announcementGate;
  WorkspaceEntityScope? _entityScope() => _session.entityScope();

  Future<dynamic> _readEntities(
    WorkspaceEntityScope scope,
    WorkspaceEntityKind kind,
  ) => deviceStore.readEntities(scope, kind);

  void _writeEntities(
    WorkspaceEntityScope scope,
    WorkspaceEntityKind kind,
    Map<String, dynamic>? record,
  ) => deviceStore.writeEntities(scope, kind, record);

  @override
  Future<List<Map<String, dynamic>>> readDeviceTranslations(String serverId) =>
      deviceStore.readDeviceTranslations(serverId);

  @override
  void writeDeviceTranslations(
    String serverId,
    List<Map<String, dynamic>> entries,
  ) => deviceStore.writeDeviceTranslations(serverId, entries);

  @override
  Future<dynamic> readTranslationGate(String serverId) =>
      deviceStore.readTranslationGate(serverId);

  @override
  void saveTranslationGate(String serverId, Map<String, dynamic>? gate) =>
      deviceStore.saveTranslationGate(serverId, gate);

  void _entityAuthorityChanged() => _session.entityAuthorityChanged();

  /// One media owner for the session and all borrowed presentations.
  @override
  late final AttachmentMedia attachmentMedia;

  AttachmentImageScope get attachmentImageScope =>
      _session.attachmentImageScope;

  /// Server-identity key for panel caches (account, origin, server, role and
  /// authentication generation). Channel switches, threads and tab changes do
  /// not change it; null while no signed-in server is selected.
  String? _panelCacheIdentity() => _session.panelCacheIdentity();

  @override
  ServerBoundCache<String, Object> get agentTabCache => services.agentTabCache;
  @override
  ServerBoundCache<String, TaskHistorySnapshot> get taskHistoryCache =>
      services.taskHistoryCache;

  String? _channelFilesAuthority(String id) => _channels.channelFilesAuthority(id);

  /// The controller-owned Files projection of [channelId]. The same store is
  /// returned on every visit, so a revisit paints the last list immediately
  /// and a refresh replaces it in place.
  @override
  SourceChannelFilesStore channelFilesStore(String channelId) =>
      services.channelFilesStore(channelId);

  // Per receiver, even when its media owner is borrowed from another page.
  late final AttachmentRetentionIndex attachmentRetentionIndex =
      AttachmentRetentionIndex.forLedger(
        ledger: _messages.ledger,
        stateStamp: () => _stateStamp,
        scope: () => attachmentImageScope,
        channels: () => channels,
        dms: () => dms,
        revokedChannels: () => _revokedChannels,
        canView: (row) => can('viewChannel', resource: row),
      );

  bool _retainsAttachmentByHistory(AttachmentImageKey key) =>
      attachmentRetentionIndex.retains(key);

  /// Number of complete history scans used for attachment retention.
  @visibleForTesting
  int get debugRetainedAttachmentIndexBuilds =>
      attachmentRetentionIndex.debugBuilds;

  /// Set by the host from its actual logical width before bootstrap. Home
  /// retains selection/drafts, but is not an open conversation/read surface.
  bool get mobileNavigation => _presentation.mobileNavigation;
  set mobileNavigation(bool value) => _presentation.mobileNavigation = value;
  @override
  MessageSync get messageSync => _messages.state.messageSync;
  @override
  ThreadRepliesSync get threadRepliesSync => _messages.state.threadRepliesSync;
  @override
  NotificationPrefsSync get notificationPrefsSync =>
      _channels.notificationPrefsSync;
  bool get syncCoreNotificationPrefsEnabled =>
      _session.syncCoreNotificationPrefsEnabled;
  set syncCoreNotificationPrefsEnabled(bool value) =>
      _session.syncCoreNotificationPrefsEnabled = value;

  String _syncIdentity() => _session.syncIdentity();

  void _ensureSyncIdentity() => _session.ensureSyncIdentity();


  void _consumeNotificationPrefs(dynamic payload) => _channels.consumeNotificationPrefs(payload);

  /// Source socketBridge `readMessageDisplayPrefsUpdate`: null unless the
  /// frame carries a string `serverId`/`scopeId` and a boolean
  /// `prefs.collapseLongMessages`.
  static ({String serverId, String channelId, bool collapse, int? version})?
  readMessageDisplayPrefsUpdate(dynamic payload) =>
      ChannelRepository.readMessageDisplayPrefsUpdate(payload);

  /// Source `applyMessageDisplayPrefsState` for one row: a patch older than
  /// the row's `displayPrefsVersion` is ignored.
  static RaftChannel applyMessageDisplayPrefsToChannel(
    RaftChannel value, {
    required bool collapse,
    int? version,
  }) => ChannelRepository.applyMessageDisplayPrefsToChannel(
    value,
    collapse: collapse,
    version: version,
  );

  /// Source socketBridge `message_display_prefs:updated`: written onto the
  /// channel row so chat folding follows another device's toggle.
  void _consumeMessageDisplayPrefs(dynamic payload) =>
      _channels.consumeMessageDisplayPrefs(payload);

  /// Web serverFeatureFlags `remote_computer_upgrade_v2`: whether the
  /// Computer detail may offer the one-click upgrade (fail-closed).
  static const remoteComputerUpgradeFlag =
      WorkspaceSession.remoteComputerUpgradeFlag;
  bool get remoteComputerUpgradeEnabled =>
      _session.remoteComputerUpgradeEnabled;
  set remoteComputerUpgradeEnabled(bool value) =>
      _session.remoteComputerUpgradeEnabled = value;

  /// Web `AGENT_MIGRATION_FEATURE_FLAG_KEY` (`useAgentMigrationUiEnabled`):
  /// the "Move to another computer" action exists only while it is on.
  static const agentMigrationFlag = WorkspaceSession.agentMigrationFlag;

  /// Web `RUNTIME_FORM_V2_WEB_FLAG_KEY` (default off): the agent runtime
  /// editor presents the protocol-v2 server form only while it is on.
  static const runtimeFormV2WebFlag = WorkspaceSession.runtimeFormV2WebFlag;

  /// Both fail closed and ride the same evaluation as the sync flags (no
  /// request of their own).
  bool get agentMigrationEnabled => _session.agentMigrationEnabled;
  set agentMigrationEnabled(bool value) =>
      _session.agentMigrationEnabled = value;
  bool get runtimeFormV2WebEnabled => _session.runtimeFormV2WebEnabled;
  set runtimeFormV2WebEnabled(bool value) =>
      _session.runtimeFormV2WebEnabled = value;

  @override
  Future<void> refreshMessageSyncFlag() => _session.refreshMessageSyncFlag();

  /// Writes every pending (debounced) change and completes once all queued
  /// device writes have landed.
  Future<void> flushCache() async {
    await MessageHistorySnapshots.flush(this);
    await MessageHistoryPages.storage(cache)?.receiver.settled;
    await MessageHistoryPages.storage(cache)?.positionsSettled;
    services.flushDevice();
    await Future.wait([deviceStore.settled, composer.flushed]);
  }

  /// Stops all further device writes of this workspace and completes once
  /// the writes already queued have landed. The caller then clears the
  /// account's device data.
  Future<void> retireCache() {
    return Future.wait([deviceStore.retire(), composer.flushed]);
  }

  Map<String, String> get drafts => _editor.drafts;
  Set<String> get _revokedChannels => _session.revokedChannels;
  Set<String> get _revokedServers => _session.revokedServers;
  bool get _mainPresented => _presentation.mainPresented;
  bool get _threadPresented => _presentation.threadPresented;
  bool get _chatTabPresented => _presentation.chatTabPresented;
  @override
  void setChatTabPresentation(Object owner, bool visible) =>
      _presentation.setChatTabPresentation(owner, visible);
  @override
  void releaseChatTabPresentation(Object owner) =>
      _presentation.releaseChatTabPresentation(owner);
  @override
  void setConversationPresentation(Object owner, {required bool main, required bool thread}) =>
      _presentation.setConversationPresentation(owner, main: main, thread: thread);
  @override
  void releaseConversationPresentation(Object owner) =>
      _presentation.releaseConversationPresentation(owner);

  /// This session owns one window; pages and platform adapters only borrow it.
  /// Server selection creates it before UI; standalone views can borrow a
  /// passive projection before selection. Neither path starts work by reading.
  @override
  SourceActivityUnreadStore get activityUnread => services.activityUnread;

  /// The existing session projection; reading it never constructs or starts it.
  @override
  SourceActivityUnreadStore? get activityUnreadIfBound =>
      services.activityUnreadIfBound;

  ValueNotifier<bool> get foregroundChanges => _presentation.foregroundChanges;

  /// Counts returns to the foreground that reached [resumeLiveSession]; views
  /// that own live summaries (the server menu's Activity count) refresh on it.
  ValueNotifier<int> get resumes => _session.resumes;
  bool get foreground => _presentation.foreground;
  set foreground(bool value) => _presentation.foreground = value;
  void setForeground(bool value) => _presentation.setForeground(value);

  @override
  void resetServerProjection() => _session.resetServerProjection();

  @override
  void clearSessionPrefetch() => _channels.clearSessionPrefetch();

  void revokeServer(String id) => _session.revokeServer(id);

  @override
  void closeRevokedServerProjection() =>
      _session.closeRevokedServerProjection();

  Future<dynamic> _cached(String kind, String id, {String? server}) =>
      deviceStore.read(kind, id, server: server);

  Future<void> _save(
    String kind,
    String id,
    dynamic value, {
    String? server,
    bool requiredSuccess = false,
  }) => deviceStore.write(
    kind,
    id,
    value,
    server: server,
    requiredSuccess: requiredSuccess,
  );

  void saveDraft(String text, {bool thread = false}) =>
      _editor.saveDraft(text, thread: thread);

  Future<void> stageSharedDraft(
    String text,
    List<SharedDraftAttachment> files, {
    String? sourceToken,
  }) => _editor.stageSharedDraft(text, files, sourceToken: sourceToken);

  void updateDraftFromShare(String text) => _editor.updateDraftFromShare(text);

  int draftRevision({bool thread = false}) =>
      _editor.draftRevision(thread: thread);
  ValueListenable<int> draftChanges({bool thread = false}) =>
      _editor.draftChanges(thread: thread);

  /// Device writes stop before logout purges are queued.
  bool get cacheWritable => deviceStore.writable;
  Object messageHistoryTicket(String id) => _messages.messageHistoryTicket(id);

  StreamSubscription<RaftEvent> get subscription => _session.subscription;
  late final ReactionRepository reactions;
  @override
  ReactionViewerLedger get reactionViewer => reactions.reactionViewer;

  bool _disposed = false;
  int _stateStamp = 0;
  @override
  void notifyListeners() {
    _stateStamp++;
    if (presentationSource == null) messageWindows.synchronize();
    if (!_disposed) {
      _editor.synchronizeVisits();
      _ensureSyncIdentity();
      if (presentationSource == null) attachmentMedia.synchronize();
      super.notifyListeners();
    }
  }

  /// Outside-channel mention actions from the latest send per draft scope.
  Map<String, List<Map<String, dynamic>>> get pendingMentionActions =>
      _editor.pendingMentionActions;

  List<Map<String, dynamic>> pendingMentionsFor({bool thread = false}) =>
      _editor.pendingMentionsFor(thread: thread);

  void dismissPendingMention(String resolutionId, {bool thread = false}) {
    if (presentationSource != null) {
      presentationSource!.dismissPendingMention(resolutionId, thread: thread);
      return;
    }
    _editor.dismissPendingMention(resolutionId, thread: thread);
  }

  /// Warnings from the latest send per draft scope.
  Map<String, ({List<String> unresolved, bool agentStopped})>
  get sendWarnings => _editor.sendWarnings;

  ({List<String> unresolved, bool agentStopped}) sendWarningsFor({
    bool thread = false,
  }) => _editor.sendWarningsFor(thread: thread);

  void dismissSendWarnings({bool thread = false}) {
    if (presentationSource != null) {
      presentationSource!.dismissSendWarnings(thread: thread);
      return;
    }
    _editor.dismissSendWarnings(thread: thread);
  }

  Future<Set<String>> executeMentionActions(
    String action,
    List<String> resolutionIds,
  ) => _editor.executeMentionActions(action, resolutionIds);

  static bool mentionActionSucceeded(String action, Map? result) =>
      WorkspaceEditor.mentionActionSucceeded(action, result);

  Future<Map<String, Map<String, dynamic>>> executeMentionActionResults(
    String action,
    List<String> resolutionIds,
  ) => _editor.executeMentionActionResults(action, resolutionIds);

  String? draftScope({bool thread = false}) =>
      _editor.draftScope(thread: thread);
  bool get conversationPaused => _editor.conversationPaused;
  List<UploadDraft> uploads({bool thread = false}) =>
      _editor.uploads(thread: thread);
  bool uploadsReady({bool thread = false}) =>
      _editor.uploadsReady(thread: thread);

  String? composerErrorFor({bool thread = false}) =>
      _editor.composerErrorFor(thread: thread);

  void setComposerError(
    String? message, {
    bool thread = false,
    bool Function()? whileTrue,
  }) {
    // ignore: raft_lints/avoid_imperative_notice_state -- Compatibility entry forwards to the editor's visit-bound CauseNotices; the root stores no error value.
    _editor.setComposerError(message, thread: thread, whileTrue: whileTrue);
  }

  Map<String, String?> get shareHolds => _editor.shareHolds;
  bool sharedBlocked({bool thread = false}) =>
      _editor.sharedBlocked(thread: thread);
  String? shareNoticeFor({bool thread = false}) =>
      _editor.shareNoticeFor(thread: thread);

  void holdShared(String scope) {
    final source = presentationSource;
    if (source != null) return source.holdShared(scope);
    _editor.holdShared(scope);
  }

  void releaseShared(String scope) {
    final source = presentationSource;
    if (source != null) return source.releaseShared(scope);
    _editor.releaseShared(scope);
  }

  void blockShared(String scope, String notice) {
    final source = presentationSource;
    if (source != null) return source.blockShared(scope, notice);
    _editor.blockShared(scope, notice);
  }

  /// A destination that does not exist on the server yet (a new DM): the
  /// composer opens on this local row; [adoptResolvedDm] swaps in the real one.
  static RaftChannel pendingDm({
    required String key,
    required String serverId,
    required String name,
  }) => WorkspaceMessages.pendingDm(key: key, serverId: serverId, name: name);
  static bool isPendingDm(RaftChannel? c) => WorkspaceMessages.isPendingDm(c);

  /// The new DM exists now: its draft, staged files and hold move from the
  /// local row to [real], which takes its place in the lists and, when open,
  /// as the selection.
  Future<void> adoptResolvedDm(String pendingId, RaftChannel real) async {
    final source = presentationSource;
    if (source != null) return source.adoptResolvedDm(pendingId, real);
    return _editor.adoptResolvedDm(pendingId, real);
  }

  /// A joined copy of a public channel's row while its join is in flight; the
  /// original goes back when [joined] is false.
  void putSharedChannelRow(RaftChannel row) {
    final source = presentationSource;
    if (source != null) return source.putSharedChannelRow(row);
    _channels.recordRowWrite(row.id);
    _putChannelRow(row);
  }

  static const multipartUploadSafeLimitBytes =
      WorkspaceEditor.multipartUploadSafeLimitBytes;

  static int? uploadLimitFromCapabilities(dynamic value) =>
      WorkspaceEditor.uploadLimitFromCapabilities(value);

  Future<int?> uploadLimitBytes() => _editor.uploadLimitBytes();

  Future<void> attachSelection(
    List<({String name, Uint8List bytes})> files, {
    bool thread = false,
    required String Function(String key, Map<String, Object> args) text,
  }) {
    final source = presentationSource;
    if (source != null) {
      return source.attachSelection(files, thread: thread, text: text);
    }
    return _editor.attachSelection(files, thread: thread, text: text);
  }

  @visibleForTesting
  static String uploadErrorText(Object failure) =>
      WorkspaceEditor.uploadErrorText(failure);

  Future<void> attachUpload(
    String name,
    Uint8List bytes, {
    bool thread = false,
  }) async {
    final source = presentationSource;
    if (source != null) return source.attachUpload(name, bytes, thread: thread);
    return _editor.attachUpload(name, bytes, thread: thread);
  }

  Future<void> retryUpload(UploadDraft draft, {bool thread = false}) async {
    final source = presentationSource;
    if (source != null) return source.retryUpload(draft, thread: thread);
    return _editor.retryUpload(draft, thread: thread);
  }

  void removeUpload(UploadDraft draft, {bool thread = false}) {
    final source = presentationSource;
    if (source != null) return source.removeUpload(draft, thread: thread);
    _editor.removeUpload(draft, thread: thread);
  }

  ConversationReadRepository get conversationReads => _channels.reads;
  ReadStateLedger get _readState => _channels.localReadState;
  @override
  ReadStateLedger get readState => presentationSource?.readState ?? _readState;

  @override
  ResourceSnapshotCache get resourceSnapshots => _messages.resourceSnapshots;
  @override
  bool get threadHasMore => _messages.state.threadHasMore;
  set threadHasMore(bool value) => _messages.state.threadHasMore = value;

  @override
  List<RaftRecord> get servers => _session.servers;
  set servers(List<RaftRecord> value) => _session.servers = value;
  @override
  List<RaftChannel> get channels => _channels.channels;
  set channels(List<RaftChannel> value) => _channels.channels = value;
  @override
  List<RaftChannel> get dms => _channels.dms;
  set dms(List<RaftChannel> value) => _channels.dms = value;
  Map<String, int> get unread => _channels.unread;
  set unread(Map<String, int> value) => _channels.unread = value;

  /// Source messageStore `mentionFlags`: conversations whose unread messages
  /// mention the member (unread snapshot `hasMention`, a live `message:new`
  /// that mentions the member). Cleared with the unread count.
  Set<String> get mentions => _channels.mentions;
  set mentions(Set<String> value) => _channels.mentions = value;

  /// Unread summary `hasNew`: non-joined public channels with messages past
  /// the cursor (no exact count). Lights the quiet dot of a non-joined row;
  /// cleared with the unread count (Web `newFlags`).
  Set<String> get newFlags => _channels.newFlags;
  set newFlags(Set<String> value) => _channels.newFlags = value;
  Map<String, dynamic> get sidebarOrder => _channels.sidebarOrder;
  set sidebarOrder(Map<String, dynamic> value) => _channels.sidebarOrder = value;
  @override
  RaftRecord? get server => _session.server;
  set server(RaftRecord? value) => _session.server = value;
  bool can(String capability, {RaftChannel? resource}) =>
      _session.can(capability, resource: resource);
  RaftChannel? get channel => _presentation.channel;
  set channel(RaftChannel? value) => _presentation.channel = value;

  @override
  WorkspaceThreadIdentity? get threadIdentity => _messages.threadIdentity;
  @override
  RaftMessage? get presentedThreadParent => _messages.presentedThreadParent;


  @override
  String? get threadChannelId => _messages.state.threadChannelId;
  set threadChannelId(String? value) => _messages.state.threadChannelId = value;
  bool get loading => _presentation.loading;
  set loading(bool value) => _presentation.loading = value;
  bool get connected => _session.connected;
  set connected(bool value) => _session.connected = value;
  // ignore: raft_lints/avoid_imperative_notice_state -- One-shot toast consumed by WorkspaceView; cleared on channel open, jump, send start, server switch and server revoke.
  String? get error => _presentation.error;
  set error(String? value) => _presentation.error = value;



  WorkspaceNavigation get navigation => _presentation.navigation;
  @override
  String get navigationAuthority => _presentation.navigationAuthority;
  void bindNavigation() => _presentation.bindNavigation();
  RaftLocation get location => _presentation.location;
  int get navigationRevision => _presentation.navigationRevision;
  String get section => _presentation.section;
  set section(String value) => _presentation.section = value;







  @override
  List<RaftMessage> get replies => _messages.replies;



  /// Whether [message] is an optimistic row still waiting for the server.
  static bool isPendingSend(RaftMessage message) => WorkspaceMessages.isPendingSend(message);

  static bool _rateLimited(Object e) => e is RaftApiException && e.rateLimited;

  /// A background refresh that failed is only an error worth showing when its
  /// scope is still the open one: a rate limit, or a fence tripped because the
  /// account or workspace changed (a deleted or left server), is not.
  static bool _quietFailure(Object e) => _rateLimited(e) || _staleScope(e);

  /// A request fenced by an account or workspace change: its owner moved on,
  /// so it reports nothing (also for the user's own actions, which are
  /// otherwise reported, rate limits included).
  static bool _staleScope(Object e) => e is RaftApiException && e.staleScope;

  @override
  // ignore: raft_lints/avoid_imperative_notice_state -- Compatibility command delegates the existing scoped notice to its presentation owner; notification and source dispatch are unchanged.
  void setError(String? value) => _presentation.setError(value);

  /// Hydrates the account's real server directory without selecting a server.
  /// The app root uses this before exposing the global chooser. Offline rows
  /// retain the existing account-scoped cache contract; fresh authority and
  /// cache writes share the membership reducer's request/revocation fences.
  ///
  /// With [cachedFirst] (cold start) an accepted on-device directory is
  /// adopted at once, so the remembered server and its cached channels paint
  /// without waiting for the network; [revalidateServerDirectory] then
  /// replaces it in the background.
  Future<bool> loadServerDirectory({
    bool cachedFirst = false,
    void Function()? onCacheMiss,
  }) => _session.loadServerDirectory(
    cachedFirst: cachedFirst,
    onCacheMiss: onCacheMiss,
  );

  /// Channel and DM rows saved on this device for [serverId], or null. A
  /// display seed (for example the share picker) and never an authorization
  /// grant: callers revalidate before acting on a row.
  Future<List<RaftChannel>?> cachedChannelDirectory(String serverId) =>
      _session.cachedChannelDirectory(serverId);

  /// Background replacement of a cache-first directory once the restored
  /// session is validated. A server missing from the fresh directory is
  /// revoked (its on-device data is purged and, when selected, its workspace
  /// closes); a changed role replaces the selected server's authority, which
  /// retires role-bound windows and revalidates the open channel. A failure
  /// keeps the accepted directory (offline).
  Future<void> revalidateServerDirectory() =>
      _session.revalidateServerDirectory();

  Future<void> bootstrap() => _session.bootstrap();

  @override
  void beginServerSelectionProjection(RaftRecord next) =>
      _session.beginServerSelectionProjection(next);

  @override
  void resetServerSelectionState() => _session.resetServerSelectionState();

  /// [onHydrated] runs once the on-device channels, selection window and
  /// unread counts of [next] are painted, before any network response; it
  /// does not run when nothing is cached. The returned future still settles
  /// only after the fresh channel lists (and the selected page) are applied.
  Future<void> selectServer(
    RaftRecord next, {
    void Function()? onHydrated,
    void Function()? onCacheMiss,
  }) => _session.selectServer(
    next,
    onHydrated: onHydrated,
    onCacheMiss: onCacheMiss,
  );

  void _persistReadState() => _channels.persistReadState();

  /// Latest activity seq per scope from the last unread snapshot; live
  /// messages raise it. Lets a read receipt clear a count without a GET.

  /// Source messageStore `message:new`: +1 for a conversation the member is
  /// not reading, never for the member's own message. Counts only what the
  /// unread snapshot counts (joined channels, DMs, tracked threads).
  void _receiveUnread(Map<String, dynamic> row) =>
      _channels.receiveUnread(row);

  /// Source `applyAcceptedReadStateProjection`: an accepted read frontier
  /// recounts the scope from held messages when they cover it, and clears
  /// it when it reaches the latest known activity. Otherwise the count
  /// waits for the next reconcile.
  void _projectReadState(String id) => _channels.projectReadState(id);

  Future<void> refreshUnread() async {
    final source = presentationSource;
    if (source != null) {
      return source.refreshUnread();
    }
    return _channels.refreshUnread();
  }

  Future<void> prefetchLikelyChannels({int limit = 6}) =>
      _channels.prefetchLikelyChannels(limit: limit);

  void _revokeChannel(String id) => _session.revokeChannel(id);

  @override
  ChannelRevocationPlan planChannelRevocation(String id) =>
      _session.planChannelRevocation(id);

  @override
  void clearRevokedChannelProjection(String scope) => _messages.clearRevokedChannelProjection(scope);

  @override
  void removeRevokedParentSummary(dynamic messageId) => _messages.removeRevokedParentSummary(messageId);

  @override
  void closeRevokedChannelProjection(ChannelRevocation event) {
    final id = event.plan.channelId;
    if (channel?.id == id && !event.keepShared) {
      channel = null;
      _presentation.assignMissingConversationChannelId(id);
      messageWindows.channelGeneration++;
    }
    if (_messages.state.threadParent?.channelId == id ||
        _messages.state.threadIdentity?.parentChannelId == id ||
        event.plan.threadIds.contains(threadChannelId) ||
        threadChannelId == id) {
      closeThread();
    }
  }

  @override
  void persistSessionReadState() => _persistReadState();

  @override
  Future<void> loadSidebar() async {
    if (presentationSource != null) return presentationSource!.loadSidebar();
    return _channels.loadSidebar();
  }

  // ---- sidebar-order writes (Source serverStore.updateSidebarOrder) -------

  /// Applies [updates] to [sidebarOrder] at once (the row moves before the
  /// request returns), then PATCHes `/servers/:id/sidebar-order`. A request
  /// that touches sections carries the `sectionsVersion` the server demands
  /// (409 otherwise) and is queued behind the previous section write; a
  /// failure restores the previous order, a 409 reloads it. Never throws.
  Future<void> updateSidebarOrder(Map<String, dynamic> updates) async {
    final source = presentationSource;
    if (source != null) return source.updateSidebarOrder(updates);
    return _channels.updateSidebarOrder(updates);
  }

  /// Source channelStore.setActivityMuteState: patches the mute fields of one
  /// row in place (channels, DMs and the open channel).
  void setActivityMuteState(String id, Map<String, dynamic> state) {
    final source = presentationSource;
    if (source != null) return source.setActivityMuteState(id, state);
    _channels.setActivityMuteState(id, state);
  }

  RaftChannel? channelById(String id) => _channels.channelById(id);

  /// Optimistic local unread for Mark as Unread (Source markUnread).
  void markUnreadLocally(String id) {
    final source = presentationSource;
    if (source != null) return source.markUnreadLocally(id);
    _channels.markUnreadLocally(id);
  }

  /// Full channel and DM list reload (Source `loadChannels` +
  /// `loadDMChannels`): server selection, `rooms:joined`, a role change, or a
  /// channel event without an id. Unchanged rows keep their objects.
  Future<void> refreshChannels() async {
    final source = presentationSource;
    if (source != null) {
      return source.refreshChannels();
    }
    return _channels.refreshChannels();
  }

  /// The one place channel lists change after selection. A row missing from
  /// the next lists lost access and is revoked; [readmit] are rows the
  /// server just confirmed readable.
  void _acceptChannelLists(
    List<RaftChannel> nextChannels,
    List<RaftChannel> nextDms, {
    required Set<String> readmit,
  }) => _channels.acceptChannelLists(nextChannels, nextDms, readmit: readmit);

  /// Replaces [next]'s row in place, or adds it (a new DM goes first, as the
  /// server's recency-ordered DM list would place it).
  void _putChannelRow(RaftChannel next) => _channels.putRow(next);

  /// Source channelRealtimeSync: a channel event changes one row. A carried
  /// row is patched in place; an id re-reads that one channel; only an event
  /// without an id reloads both lists.
  void _channelRealtime(String name, dynamic payload) =>
      _channels.consumeRealtime(name, payload);

  /// Web `patchChannel` `hiddenAllChannel`: an admin hiding `#all` turns it
  /// into a private channel named `all`, which leaves the list.
  static bool isHiddenAllChannelRow(Map<String, dynamic> row) =>
      ChannelRepository.isHiddenAllChannelRow(row);

  /// Source `ensureChannel(id, {refresh: true})`: reads one channel and
  /// upserts its row. Lost access (403/404, or a private row the lists would
  /// not carry) revokes that channel through the list revocation path.
  Future<void> refreshChannel(String id) =>
      _channels.refreshChannel(id);

  /// Source socketBridge `roomsJoined`: the server joined this socket's
  /// rooms, so missed messages can be resumed and the lists re-read.

  /// Server reads started by events and by returning to the foreground (not
  /// by the person asking) are skipped while the last one is this fresh.

  /// Source `recordHeartbeat`: a server seq past the ledger watermark means
  /// a push was missed; the visible scopes read their gap.

  /// Source `recoverLiveSession` on return to the foreground: reconnect a
  /// dropped or silent socket (its `rooms:joined` resumes and gap-syncs), or
  /// resume and gap-sync on the live one; then refresh live counts.
  void resumeLiveSession() => _session.resumeLiveSession();


  bool canVisitSection(String name) => _presentation.canVisitSection(name);

  /// Apply the mounted receiver's own authoritative role event synchronously.
  /// Any earlier HTTP membership snapshot loses its request revision fence.
  void applyMembershipRole(dynamic payload) =>
      _session.applyMembershipRole(payload);

  /// Bumped by every `server:plan-updated`. Views that hold billing / usage
  /// reads (Web `loadBilling` + `loadUsage`) reload when it changes.
  int get planRevision => _session.planRevision;
  set planRevision(int value) => _session.planRevision = value;

  /// Web socketBridge `server:plan-updated`: patch the server row's plan, or
  /// re-read the servers when the payload is incomplete; billing and usage
  /// are then reloaded by [planRevision] observers.

  /// Web serverStore `uploadServerAvatar`: the upload response's avatar URL is
  /// upserted into the server row everywhere (rail, switcher, settings) with
  /// no re-read. A mirrored presentation source re-reads instead.
  void applyServerAvatar(String serverId, String? avatarUrl) =>
      _session.applyServerAvatar(serverId, avatarUrl);

  /// With [coalesce] (a refresh nobody asked for), a directory read already in
  /// flight stands in for it: starting another would retire that read.
  Future<void> recoverMembership({bool coalesce = false}) =>
      _session.recoverMembership(coalesce: coalesce);

  bool _rejectRevokedConversation(String id) => _presentation.rejectRevokedConversation(id);
  String? get missingConversationChannelId => _presentation.missingConversationChannelId;
  @override
  Future<void> resolveConversationChannel(String id, {bool preserveThread = false}) =>
      _presentation.resolveConversationChannel(id, preserveThread: preserveThread);

  Future<void> selectChannel(
    RaftChannel next, {
    bool autoRead = true,
    bool navigate = true,
    bool retainContextUntilAccepted = false,
    bool preserveThread = false,
    VoidCallback? onDraftRestored,
  }) => _messages.selectChannel(next, autoRead: autoRead, navigate: navigate, retainContextUntilAccepted: retainContextUntilAccepted, preserveThread: preserveThread, onDraftRestored: onDraftRestored);



  bool _mayMarkRead(String id) => _channels.mayMarkRead(id);

  /// Open conversations whose timeline is scrolled above the latest end
  /// (reported by the chat view on the edge only, never per frame).

  void setTimelineAtBottom(String id, bool atBottom) =>
      _channels.setTimelineAtBottom(id, atBottom);



  Future<void> markRead(String id) => _messages.windowReceiver.channels.markRead(id);

  /// Windows painted from disk whose first fresh page has not arrived yet.
  /// Their tail may be stale, so they never send a read receipt (nor clear
  /// the unread count) until revalidated.

  /// Source acceptActivityReadAllAck: an Activity row's persisted read-all
  /// receipt is a read-state fact for [scopeId]. Folding it into the ledger is
  /// what keeps a stale inbox response from re-presenting the row as unread.
  /// Returns false for an invalid receipt or a changed identity.
  bool acceptReadAllAck(
    String scopeId,
    dynamic receipt, {
    required String serverId,
    required String principalId,
  }) => _channels.acceptReadAllAck(
    scopeId,
    receipt,
    serverId: serverId,
    principalId: principalId,
  );

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
    final source = presentationSource;
    if (source != null) {
      return source.send(
        text,
        thread: thread,
        attachments: attachments,
        mentions: mentions,
        randomId: randomId,
        asTask: asTask,
        attachmentsOnlyBody: attachmentsOnlyBody,
        onWindowRefreshed: onWindowRefreshed,
      );
    }
    return _editor.send(
      text,
      thread: thread,
      attachments: attachments,
      mentions: mentions,
      randomId: randomId,
      asTask: asTask,
      attachmentsOnlyBody: attachmentsOnlyBody,
      onWindowRefreshed: onWindowRefreshed,
    );
  }



  /// Opens a real thread identity independently of its parent metadata.
  /// [initialThreadChannelId] is the accepted inbox row's existing channel;
  /// Source opens that channel immediately without a resolution lookup.
  @override
  Future<void> openThreadIdentity({
    required String parentChannelId,
    required String parentMessageId,
    String? focusedMessageId,
    String? initialThreadChannelId,
    bool navigate = true,
  }) => _messages.threads.openThreadIdentity(parentChannelId: parentChannelId, parentMessageId: parentMessageId, focusedMessageId: focusedMessageId, initialThreadChannelId: initialThreadChannelId, navigate: navigate);



  /// [replaceEntry] makes the destination take over the current history
  /// entry instead of pushing (Web openThreadParentMessageRoute, mobile).
  Future<void> jumpToMessage(
    String channelId,
    String? messageId, {
    bool navigate = true,
    bool replaceEntry = false,
  }) => _messages.jumpToMessage(channelId, messageId, navigate: navigate, replaceEntry: replaceEntry);



  @override
  Map<String, dynamic>? externalProfile(String messageId) => _presentation.externalProfile(messageId);
  @override
  void openProfile(RaftProfileKind kind, String id, {String? agentTab, String? channelId, Map<String, dynamic>? externalAuthor}) =>
      _presentation.openProfile(kind, id, agentTab: agentTab, channelId: channelId, externalAuthor: externalAuthor);
  @override
  void closeProfile() => _presentation.closeProfile();

  void closeThread({bool navigate = true}) => _messages.threads.closeThread(navigate: navigate);

  @override
  void setSection(String next) => _presentation.setSection(next);

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) =>
      presentationSource?.sharedQuery(path, query: query) ??
      apiGateway.query(path, query: query);

  /// Compatibility facade; all presentations share [attachmentMedia].
  PlayerSessions get playerSessions => attachmentMedia.playerSessions;

  @visibleForTesting
  AttachmentUrlCache get debugAttachmentUrls => attachmentMedia.debugUrls;

  Future<String> attachmentUrl(
    String id, {
    String? disposition = 'inline',
    String? channelId,
    bool refresh = false,
    bool coalesce = false,
  }) => attachmentMedia.url(
    id,
    disposition: disposition,
    channelId: channelId,
    refresh: refresh,
    coalesce: coalesce,
  );

  Future<bool> attachmentPreviewEnabled() => attachmentMedia.previewEnabled();

  /// Coalesce identical concurrent reads, retaining this facade's query
  /// override and giving each caller its own copy of the decoded response.
  @override
  Future<dynamic> sharedQuery(String path, {Map<String, dynamic>? query}) =>
      apiGateway.sharedQuery(
        path,
        query: query,
        readerKey: this,
        scopeClient: client,
        read: this.query,
      );

  /// A deep copy of a decoded response, so consumers never share its maps.
  static dynamic copyDecoded(dynamic value) =>
      RaftApiGateway.copyDecoded(value);

  int get savedRevision => _channels.savedRevision;
  set savedRevision(int value) => _channels.savedRevision = value;
  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    if (presentationSource != null) {
      return presentationSource!.command(method, path, data: data);
    }
    return apiGateway.command(method, path, data: data);
  }

  @override
  Future<void> hydrateReactionViewer(RaftMessage message) =>
      reactions.hydrateReactionViewer(message);

  @override
  Map<String, bool>? pendingReactionTargets(String messageId) =>
      reactions.pendingReactionTargets(messageId);

  void _overlayPendingReactions(Map<String, dynamic> row) =>
      reactions.overlayMessageReactions(row);

  @override
  Future<void> toggleReaction(RaftMessage message, String emoji) =>
      reactions.toggleReaction(message, emoji);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    sessionScope.dispose();
    MessageHistoryPages.detach(this);
    if (presentationSource == null) messageWindows.dispose();
    composer.sends.detach(this);
    composer.disposeOwnedBy(this);
    if (services.ownsEntityDirectory) {
      removeListener(_entityAuthorityChanged);
    }
    services.disposeOwnedStores();
    _removeCacheClear?.call();
    _removeCacheClear = null;
    if (presentationSource == null) attachmentMedia.dispose();
    services.retireChannelFiles();
    subscription.cancel();
    services.disposeActivityUnread();
    _presentation.dispose();
    resumes.dispose();
    if (ownsClient) client.dispose();
    super.dispose();
  }
}

/// Composition-only wrapper: domains receive no binding or handler maps.
class _WorkspaceTransitions implements WorkspaceTransitionPort {
  const _WorkspaceTransitions(this.scope);
  final SessionScope scope;
  @override
  ServerSelection selectServer(RaftRecord next) => scope.selectServer(next);
  @override
  void resetServer(String? id) => scope.resetServer(id);
  @override
  void revokeServer(String id) => scope.revokeServer(id);
  @override
  void revokeChannel(String id) => scope.revokeChannel(id);
}

/// Temporary composition adapter. It preserves the original facade dispatch
/// without adding generic member names to WorkspaceController's public API.
class _WorkspaceSessionBindings
    implements
        WorkspaceSessionContext,
        WorkspaceTransportPort,
        WorkspaceDevicePort,
        WorkspaceSessionEntries,
        WorkspaceSessionRevocations,
        WorkspaceSessionChannels,
        WorkspaceSessionPresentation,
        WorkspaceSessionMessages,
        WorkspaceSessionDrafts,
        WorkspaceSessionEntities,
        WorkspaceMessageIngressPort,
        WorkspaceMessageRowsPort,
        WorkspaceWindowFactsPort,
        WorkspaceMessagePrefetchPort,
        WorkspacePrefetchPagesPort,
        WorkspaceTaskMetadataPort,
        WorkspacePresentationDirectoryPort {
  _WorkspaceSessionBindings(this.w);
  final WorkspaceController w;
  late final WorkspaceTransitionPort _transitions = _WorkspaceTransitions(
    w.sessionScope,
  );
  @override
  Object get receiverKey => w;
  @override
  Set<String> get revokedChannels => w.sessionScope.revokedChannels;
  @override
  Set<String> get revokedServers => w.sessionScope.revokedServers;
  @override
  bool get disposed => w._disposed;
  @override
  WorkspaceSessionIdentity get identity => (
    origin: w.client.origin,
    generation: w.client.generation,
    principalId: w.client.user?.id,
    serverId: w.client.serverId,
    role: w.server?.string('role'),
  );
  @override
  bool isChannelRevoked(String id) => w._revokedChannels.contains(id);
  @override
  bool isServerRevoked(String id) => w._revokedServers.contains(id);
  @override
  String syncIdentity() => w._syncIdentity();
  @override
  String? panelIdentity() => w._panelCacheIdentity();
  @override
  WorkspaceTransitionPort get transitions => _transitions;
  @override
  void changed() => w.notifyListeners();
  @override
  WorkspaceSessionEntries? get sessionSource =>
      w.presentationSource?._session.entries;
  @override
  bool get writable => w.deviceStore.writable;
  @override
  Future<dynamic> read(String kind, String id, {String? server}) =>
      w._cached(kind, id, server: server);
  @override
  Future<void> save(
    String kind,
    String id,
    dynamic value, {
    String? server,
    bool requiredSuccess = false,
  }) => w._save(
    kind,
    id,
    value,
    server: server,
    requiredSuccess: requiredSuccess,
  );

  @override
  void recordRowWrite(String id) => w._channels.recordRowWrite(id);
  @override
  void putRow(RaftChannel row) => w._putChannelRow(row);
  @override
  void assignChannels(List<RaftChannel> value) => w.channels = value;
  @override
  void assignDms(List<RaftChannel> value) => w.dms = value;
  @override
  void assignUnread(Map<String, int> value) => w.unread = value;
  @override
  void assignSidebarOrder(Map<String, dynamic> value) => w.sidebarOrder = value;
  @override
  void resetDirectoryAndUnreadProjection() =>
      w._channels.resetDirectoryAndUnreadProjection();

  @override
  void resetRowAuthority() => w.channelRepository.resetRowAuthority();
  @override
  void removeChannelRows(String id) {
    w.channels.removeWhere((c) => c.id == id);
    w.dms.removeWhere((c) => c.id == id);
  }

  @override
  void channelRealtime(String name, dynamic payload) =>
      w._channelRealtime(name, payload);
  @override
  void consumeNotificationPrefs(dynamic payload) =>
      w._consumeNotificationPrefs(payload);
  @override
  void consumeMessageDisplayPrefs(dynamic payload) =>
      w._consumeMessageDisplayPrefs(payload);
  @override
  void projectReadState(String id) => w._projectReadState(id);
  @override
  void persistReadState() => w._persistReadState();

  @override
  bool get mainPresented => w._mainPresented;
  @override
  bool get threadPresented => w._threadPresented;
  @override
  bool get chatTabPresented => w._chatTabPresented;
  @override
  bool get borrowed => w.presentationSource != null;
  @override
  String? get presentationAuthority => w._presentation.boundSourceAuthority;
  @override
  String? get sourceNavigationAuthority =>
      w.presentationSource?.navigationAuthority;
  @override
  void assignError(String? value) => w.error = value;
  @override
  void assignSection(String value) => w.section = value;
  @override
  void assignUnboundSection(String value) => w._presentation.assignUnboundSection(value);
  @override
  void assignLoading(bool value) => w.loading = value;
  @override
  void assignMissingConversationChannelId(String? value) =>
      w._presentation.assignMissingConversationChannelId(value);
  @override
  void setSelectedChannel(RaftChannel? value) => w.channel = value;
  @override
  void patchSelectedChannel(RaftChannel Function(RaftChannel) patch) {
    if (w.channel != null) w.channel = patch(w.channel!);
  }

  @override
  String? get replyIdentity => w._messages.state.replyIdentity;
  @override
  void assignReplyIdentity(String value) =>
      w._messages.state.replyIdentity = value;
  @override
  void clearReplySummaries() => w._messages.summariesByChannel.clear();
  @override
  void resetHistoryLimits() =>
      w.messageDomain.state.historyLimited = w.messageDomain.state.threadHistoryLimited = false;
  @override
  void resetThreadProjection() {
    w.messageDomain.state.threadParent = null;
    w.threadChannelId = null;
    w._messages.summariesByChannel.clear();
    w.messageDomain.state.highlightedMessageId = null;
  }

  @override
  void closeServerLoading() {
    w.messageDomain.state.channelLoading = false;
    w.messageDomain.state.threadLoading = false;
  }

  @override
  void resetNewer() => w.messageDomain.state.hasNewer = false;
  @override
  void invalidateAllReplyAuthority() => w._messages.state.replyAuthority.invalidateAll();
  @override
  void invalidateAllChannelReplies() => w._messages.invalidateAllChannelReplies();
  @override
  void invalidateChannelReplies(String id) => w._messages.invalidateChannelReplies(id);
  @override
  String replyToken(String? id) => w._messages.replyToken(id);
  @override
  String windowAuthority() => w._messages.windowAuthority();
  @override
  MessageWindowRequest hydrationRequest({required bool Function() allowed}) =>
      w.messageWindows.request(allowed: allowed);
  @override
  bool restoreCachedTail(
    String id,
    dynamic page,
    MessageWindowRequest request, {
    required String replyAuthority,
    required bool replace,
  }) => w._messages.restoreCachedTail(
    id,
    page,
    request,
    replyAuthority: replyAuthority,
    replace: replace,
  );
  @override
  Future<void> restoreDraft(String id) => w._editor.restoreDraft(id);
  @override
  Future<void> resumeHistory() => MessageHistoryEvents.resume(w);
  @override
  void consumeThreadUpdate(Map<String, dynamic> payload) =>
      w._messages.consumeThreadUpdate(payload);
  @override
  Future<void> resumeResponse(
    Map payload, {
    required VoidCallback refreshUnread,
  }) => MessageHistoryEvents.resumeResponse(
    w,
    payload,
    refreshUnread: refreshUnread,
  );
  @override
  void applyReadStateHint(Map fact) =>
      applyReadStateUnreadHint(w._messages.summariesByChannel, fact);
  @override
  void acceptReactionViewer(dynamic payload, {required String serverId}) =>
      w.reactionViewer.accept(payload, serverId: serverId);
  @override
  ChannelRevocationPlan discoverRevocation(String id) =>
      ChannelRevocationPlan.discover(
        channelId: id,
        messages: w.messageDomain.ledger.messages(id),
        parentMessageIds: w.threadRepliesSync.parentMessageIdsForChannel(id),
        summaries: w._messages.summariesByChannel,
        identity: w._messages.state.threadIdentity,
        parent: w.messageDomain.state.threadParent,
        threadChannelId: w.threadChannelId,
      );
  @override
  bool get ownsEntityDirectory => w.services.ownsEntityDirectory;

  @override
  bool consumeMessageEvent(RaftEvent event) => consumeWorkspaceMessageEvent(
    event,
    context: this,
    presentation: this,
    ledger: w.messageDomain.ledger,
    windows: w.messageWindows,
  );
  @override
  void confirmMessageSend(Map<String, dynamic> row) =>
      w.composer.sends.confirm(row);
  @override
  void storeMessage(Map<String, dynamic> row, {bool updateOnly = false}) =>
      MessageHistoryEvents.store(w, row, updateOnly: updateOnly);
  @override
  void overlayMessageReactions(Map<String, dynamic> row) =>
      w._overlayPendingReactions(row);
  @override
  void receiveMessageUnread(Map<String, dynamic> row) => w._receiveUnread(row);
  @override
  Future<void> revalidateMessageTail(String id) => w._messages.revalidateTail(id);
  @override
  Future<void> saveMessageWindow(
    String id, {
    bool thread = false,
    bool coalesce = false,
  }) => w._messages.saveWindow(id, thread: thread, coalesce: coalesce);

  @override
  RaftClient get client => w.client;
  @override
  RaftRecord? get server => w.server;
  @override
  bool can(String capability, {RaftChannel? resource}) =>
      w.can(capability, resource: resource);
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) =>
      w.query(path, query: query);
  @override
  Future<dynamic> sharedQuery(String path, {Map<String, dynamic>? query}) =>
      w.sharedQuery(path, query: query);
  @override
  Future<dynamic> command(String method, String path, {dynamic data}) =>
      w.command(method, path, data: data);
  @override
  Future<void> bootstrap() => w.bootstrap();
  @override
  Future<void> selectServer(
    RaftRecord next, {
    VoidCallback? onHydrated,
    VoidCallback? onCacheMiss,
  }) => w.selectServer(next, onHydrated: onHydrated, onCacheMiss: onCacheMiss);
  @override
  Future<void> recoverMembership({bool coalesce = false}) =>
      w.recoverMembership(coalesce: coalesce);
  @override
  Future<void> revalidateServerDirectory() => w.revalidateServerDirectory();
  @override
  Future<void> refreshMessageSyncFlag() => w.refreshMessageSyncFlag();
  @override
  void applyMembershipRole(dynamic payload) => w.applyMembershipRole(payload);
  @override
  void revokeServer(String id) => w.revokeServer(id);
  @override
  Future<void> flushCache() => w.flushCache();
  @override
  List<RaftChannel> get channels => w.channels;
  @override
  set channels(List<RaftChannel> value) => w.channels = value;
  @override
  List<RaftChannel> get dms => w.dms;
  @override
  set dms(List<RaftChannel> value) => w.dms = value;
  @override
  RaftChannel? channelById(String id) => w.channelById(id);
  @override
  Future<void> refreshChannels() => w.refreshChannels();
  @override
  Future<void> refreshChannel(String id) => w.refreshChannel(id);
  @override
  ReadStateLedger get readState => w.readState;
  @override
  NotificationPrefsSync get notificationPrefsSync => w.notificationPrefsSync;
  @override
  Future<void> refreshUnread() => w.refreshUnread();
  @override
  Future<void> loadSidebar() => w.loadSidebar();
  @override
  bool get loading => w.loading;
  @override
  RaftChannel? get channel => w.channel;
  @override
  RaftLocation get location => w.location;
  @override
  int get navigationRevision => w.navigationRevision;
  @override
  String get navigationAuthority => w.navigationAuthority;
  @override
  bool get foreground => w.foreground;
  @override
  bool get mobileNavigation => w.mobileNavigation;
  @override
  bool get presentationActive => w.presentationActive;
  @override
  String get section => w.section;
  @override
  bool canVisitSection(String section) => w.canVisitSection(section);
  @override
  // ignore: raft_lints/avoid_imperative_notice_state -- Forward only; the original public command and its channel/server reset clearing remain on the receiver.
  void setError(String? value) => w.setError(value);
  @override
  MessageLedger get ledger => w.messageDomain.ledger;
  @override
  MessageSync get messageSync => w.messageSync;
  @override
  ThreadRepliesSync get threadRepliesSync => w.threadRepliesSync;
  @override
  int get channelGeneration => w.messageDomain.channelGeneration;
  @override
  int get threadGeneration => w.messageDomain.threadGeneration;
  @override
  Future<void> selectChannel(
    RaftChannel next, {
    bool autoRead = true,
    bool navigate = true,
    bool retainContextUntilAccepted = false,
    bool preserveThread = false,
    VoidCallback? onDraftRestored,
  }) => w.selectChannel(
    next,
    autoRead: autoRead,
    navigate: navigate,
    retainContextUntilAccepted: retainContextUntilAccepted,
    preserveThread: preserveThread,
    onDraftRestored: onDraftRestored,
  );
  @override
  void closeThread({bool navigate = true}) => w.closeThread(navigate: navigate);
  @override
  Future<void> syncVisibleScopes({BigInt? through}) =>
      w.messageDomain.navigation.syncVisibleScopes(through: through);
  @override
  WorkspaceEntityDirectory get entityDirectory => w.entityDirectory;
  @override
  SourceActivityUnreadStore get activityUnread => w.activityUnread;
  @override
  SourceActivityUnreadStore? get activityUnreadIfBound =>
      w.activityUnreadIfBound;
  @override
  void addListener(VoidCallback listener) => w.addListener(listener);
  @override
  void removeListener(VoidCallback listener) => w.removeListener(listener);
  @override
  String? get threadChannelId => w.threadChannelId;
  @override
  bool get hasNewer => w.messageDomain.state.hasNewer;

  @override
  BigInt get watermark => w.messageDomain.ledger.watermark;
  @override
  int get generation => w.messageDomain.ledger.generation;
  @override
  List<Map<String, dynamic>> rows(String id) => w.messageDomain.ledger.messages(id);
  @override
  Map<String, dynamic>? message(String id, String messageId) =>
      w.messageDomain.ledger.message(id, messageId);
  @override
  Set<String>? visibleIds(String id) => w.messageDomain.visibleIds[id];
  @override
  bool isContext(String id) => w.messageWindows.isContext(id);
  @override
  bool isDiskOnly(String? id) => w.messageWindows.isDiskOnly(id);
  @override
  bool contextHasNewer(String? id) => w.messageWindows.contextHasNewer(id);
  @override
  bool hasAcceptedWindow(String id) => w.messageWindows.accepted[id] != null;
  @override
  int windowGeneration(bool thread) =>
      thread ? w.messageDomain.threadGeneration : w.messageDomain.channelGeneration;
  @override
  bool get channelLoading => w.messageDomain.state.channelLoading;
  @override
  String? get threadParentChannelId => w.messageDomain.threadParentChannelId;
  @override
  String? get threadParentMessageId => w.messageDomain.threadParentMessageId;
  @override
  WorkspaceThreadIdentity? get threadIdentity => w.threadIdentity;
  @override
  RaftMessage? get threadParent => w.messageDomain.state.threadParent;
  @override
  Object historyTicket(String id) => w.messageHistoryTicket(id);
  @override
  Future<void> warm(String id) => MessageTaskCache.of(w.client).warm(w, id);
  @override
  Future<Map<String, dynamic>> readPrefetchPage(
    MessageWindowRequest request,
    String id,
  ) => MessageHistoryPages.read(w, request, id);
  @override
  Future<bool> recordPrefetchPage(
    MessageWindowRequest request,
    Map<String, dynamic> page,
  ) => MessageHistoryPages.record(w, request, page);
  @override
  void mergeThreadSummaries(String id, dynamic rows) =>
      w.messageDomain.mergeThreadSummaries(id, rows);
  @override
  Future<void> prefetchAcceptedTail(
    RaftChannel candidate, {
    required bool Function() stillCurrent,
  }) => prefetchWorkspaceMessageTail(
    candidate,
    stillCurrent: stillCurrent,
    context: this,
    presentation: this,
    windows: w.messageWindows,
    pages: this,
    tasks: this,
  );
}

/// D4's temporary composition binding. Each operation preserves the original
/// public dispatch or assignment; domains retain only their typed ports.
class _WorkspaceMessageBindings extends _WorkspaceSessionBindings
    implements
        WorkspaceMessagePresentationPort,
        WorkspaceMessageEntryPort,
        WorkspaceMessageDraftPort,
        WorkspacePresentationConversationPort,
        WorkspaceMessageNotificationPort,
        WorkspaceConversationCommandsPort,
        WorkspaceThreadCreationPort,
        WorkspaceEditorEntrypoints,
        WorkspaceReactionMessagesPort,
        WorkspaceReactionHydrationPort {
  _WorkspaceMessageBindings(super.w);

  @override
  void acceptReactionResponse(Map<String, dynamic> row, {required int generation}) =>
      w.messageDomain.ledger.ingest([row], expectedGeneration: generation);
  @override
  set threadParent(RaftMessage? value) => w.messageDomain.state.threadParent = value;
  @override
  bool setMessageReactions(String channelId, String messageId, List<Map<String, dynamic>> reactions) =>
      w._messages.setMessageReactions(channelId, messageId, reactions);
  @override
  Future<void> saveWindow(String channelId, {bool thread = false, bool coalesce = false}) =>
      w._messages.saveWindow(channelId, thread: thread, coalesce: coalesce);
  @override
  Future<void> hydrateReactionViewer(RaftMessage message) => w.hydrateReactionViewer(message);


  @override
  Map<String, List<Map<String, dynamic>>> get pendingMentionActions =>
      w.pendingMentionActions;
  @override
  Map<String, ({List<String> unresolved, bool agentStopped})>
  get sendWarnings => w.sendWarnings;
  @override
  Map<String, String?> get shareHolds => w.shareHolds;
  @override
  bool get conversationPaused => w.conversationPaused;
  @override
  void saveDraft(String text, {bool thread = false}) =>
      w.saveDraft(text, thread: thread);
  @override
  List<UploadDraft> uploads({bool thread = false}) => w.uploads(thread: thread);
  @override
  bool sharedBlocked({bool thread = false}) => w.sharedBlocked(thread: thread);
  @override
  Future<int?> uploadLimitBytes() => w.uploadLimitBytes();
  @override
  Future<Map<String, Map<String, dynamic>>> executeMentionActionResults(
    String action,
    List<String> resolutionIds,
  ) => w.executeMentionActionResults(action, resolutionIds);

  @override
  Future<void> openThread(
    RaftMessage parent, {
    String? focusedMessageId,
    bool navigate = true,
  }) => w.messageDomain.threads.openThread(
    parent,
    focusedMessageId: focusedMessageId,
    navigate: navigate,
  );
  @override
  void closeDeniedThread(String parentChannelId) {
    if (w.threadIdentity?.parentChannelId == parentChannelId) w.closeThread();
  }

  @override
  void adoptAccessibleSelection(Set<String> accessible) =>
      w._messages.adoptAcceptedChannelSelection(accessible);
  @override
  Future<void> returnToLatest({bool navigate = true, bool thread = false}) =>
      w.messageDomain.returnToLatest(navigate: navigate, thread: thread);

  @override
  Future<void> syncVisibleScopes({BigInt? through}) =>
      w.messageDomain.navigation.syncVisibleScopes(through: through);

  @override
  Future<String?> ensureThread() => w.messageDomain.threads.ensureThread();

  @override
  void setSection(String value) => w.setSection(value);

  @override
  String? get error => w.error;
  @override
  WorkspaceNavigation get navigation => w.navigation;
  @override
  void bindNavigation() => w.bindNavigation();
  @override
  bool rejectRevokedConversation(String id) => w._rejectRevokedConversation(id);
  @override
  WorkspaceComposer get composer => w.composer;
  @override
  Map<String, String> get drafts => w.drafts;
  @override
  String? draftScope({bool thread = false}) => w.draftScope(thread: thread);
  @override
  Listenable get changes => w;
  @override
  Future<void> markRead(String id) => w.markRead(id);
  @override
  Future<void> jumpToMessage(
    String channelId,
    String? messageId, {
    bool navigate = true,
    bool replaceEntry = false,
  }) => w.jumpToMessage(
    channelId,
    messageId,
    navigate: navigate,
    replaceEntry: replaceEntry,
  );
  @override
  Future<void> openThreadIdentity({
    required String parentChannelId,
    required String parentMessageId,
    String? focusedMessageId,
    String? initialThreadChannelId,
    bool navigate = true,
  }) => w.openThreadIdentity(
    parentChannelId: parentChannelId,
    parentMessageId: parentMessageId,
    focusedMessageId: focusedMessageId,
    initialThreadChannelId: initialThreadChannelId,
    navigate: navigate,
  );
  @override
  void clearHighlightedMessage(
    String? expectedId, {
    int? expectedNavigationRevision,
  }) => w.messageDomain.clearHighlightedMessage(
    expectedId,
    expectedNavigationRevision: expectedNavigationRevision,
  );
}
