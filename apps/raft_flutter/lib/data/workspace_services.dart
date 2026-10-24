import 'package:raft_client/raft_client.dart';

import 'announcement_store.dart';
import 'followed_threads_store.dart';
import 'message_translation_store.dart';
import 'panel_caches.dart';
import 'read_receipts.dart';
import 'source_activity_unread_store.dart';
import 'source_channel_files_store.dart';
import 'thread_agent_followers.dart';
import 'thread_search.dart';
import 'workspace_entity_directory.dart';
import 'live_connection_state.dart';

/// Composition inputs; each constructed store sees only its own authority.
abstract interface class WorkspaceServiceAuthority
    implements
        MessageTranslationAuthority,
        ThreadSearchAuthority,
        ThreadAgentFollowersAuthority,
        ReadReceiptsAuthority,
        ActivityUnreadAuthority {
  Future<dynamic> query(String path, {Map<String, dynamic>? query});
  Future<dynamic> command(String method, String path, {dynamic data});
  MessageTranslationStore get translations;
  ThreadSearch get threadSearch;
  ThreadAgentFollowers get threadFollowers;
  ReadReceipts get readReceipts;
  AnnouncementStore get announcements;
  AnnouncementOnboardingGate get announcementGate;
  ServerBoundCache<String, Object> get agentTabCache;
  ServerBoundCache<String, TaskHistorySnapshot> get taskHistoryCache;
  SourceChannelFilesStore channelFilesStore(String channelId);
}

/// Session services and presentation-local repository ownership.
///
/// Lazy services follow the source's public facade, preserving its overrides.
/// Entity and followed-thread repositories keep their existing per-presentation
/// defaults; explicit injections remain owned by their caller.
class WorkspaceServices {
  WorkspaceServices(
    this.authority, {
    this.source,
    required this.isDisposed,
    required WorkspaceEntityScope? Function() entityScope,
    required this._panelIdentity,
    required this._channelFilesAuthority,
    WorkspaceEntityDeviceRead? readEntities,
    WorkspaceEntityDeviceWrite? writeEntities,
    WorkspaceEntityDirectory? entityDirectory,
    FollowedThreadsStore? followedThreads,
  }) : ownsEntityDirectory = entityDirectory == null,
       ownsFollowedThreads = followedThreads == null {
    // Preserve the original subscription and construction order.
    this.followedThreads =
        followedThreads ??
        FollowedThreadsStore(
          scope: entityScope,
          query: (path, {query}) => authority.query(path, query: query),
          command: (path, data) => authority.command('POST', path, data: data),
          authority: authority,
          events: authority.client.events,
          isOpen: (id) => authority.threadChannelId == id,
          readFrontier: (id) {
            final server = authority.client.serverId,
                user = authority.client.user?.id;
            if (server == null || user == null) return null;
            final read = authority.readState.state(
              server,
              user,
              id,
            )?['maxReadSeq'];
            return read is int ? BigInt.from(read) : null;
          },
        );
    this.entityDirectory =
        entityDirectory ??
        WorkspaceEntityDirectory(
          scope: entityScope,
          query: (path) => authority.query(path),
          events: authority.client.events,
          readDevice: readEntities,
          writeDevice: writeEntities,
        );
    liveConnection = source == null
        ? LiveConnectionState(
            client: authority.client,
            scope: entityScope,
            directory: this.entityDirectory,
            disposed: isDisposed,
          )
        : null;
  }

  final WorkspaceServiceAuthority authority;
  final WorkspaceServiceAuthority? source;
  final bool Function() isDisposed;
  final bool ownsEntityDirectory, ownsFollowedThreads;
  final String? Function() _panelIdentity;
  final String? Function(String channelId) _channelFilesAuthority;
  late final WorkspaceEntityDirectory entityDirectory;
  late final FollowedThreadsStore followedThreads;
  late final LiveConnectionState? liveConnection;

  MessageTranslationStore get translations =>
      source?.translations ??
      (_translations ??= MessageTranslationStore(authority));
  MessageTranslationStore? _translations;

  ThreadSearch get threadSearch =>
      source?.threadSearch ?? (_threadSearch ??= ThreadSearch(authority));
  ThreadSearch? _threadSearch;

  ThreadAgentFollowers get threadFollowers =>
      source?.threadFollowers ??
      (_threadFollowers ??= ThreadAgentFollowers(authority));
  ThreadAgentFollowers? _threadFollowers;

  ReadReceipts get readReceipts =>
      source?.readReceipts ?? (_readReceipts ??= ReadReceipts(authority));
  ReadReceipts? _readReceipts;

  /// Extends the owner's existing session ingress without subscribing or
  /// constructing unused repositories. Borrowed presentations have no ingress.
  void Function(RaftEvent) withServiceEvents(void Function(RaftEvent) next) =>
      (event) {
        if (isDisposed()) return;
        if (event.name == 'thread:followers-updated') {
          _threadFollowers?.consumeEvent(event);
        }
        if (event.name == 'scope_read:updated') {
          _readReceipts?.consumeEvent(event);
        }
        next(event);
      };

  AnnouncementStore get announcements =>
      source?.announcements ??
      (_announcements ??= AnnouncementStore(
        get: (path, {query}) => authority.client.get(path, query: query),
        post: (path, {query}) =>
            authority.client.request('POST', path, query: query),
        principal: () => authority.client.user?.id,
        serverId: () => authority.client.serverId,
      ));
  AnnouncementStore? _announcements;

  AnnouncementOnboardingGate get announcementGate =>
      source?.announcementGate ??
      (_announcementGate ??= AnnouncementOnboardingGate());
  AnnouncementOnboardingGate? _announcementGate;

  ServerBoundCache<String, Object> get agentTabCache =>
      source?.agentTabCache ?? _agentTabCache;
  late final _agentTabCache = ServerBoundCache<String, Object>(_panelIdentity);

  ServerBoundCache<String, TaskHistorySnapshot> get taskHistoryCache =>
      source?.taskHistoryCache ?? _taskHistoryCache;
  late final _taskHistoryCache = ServerBoundCache<String, TaskHistorySnapshot>(
    _panelIdentity,
    limit: 128,
  );
  late final _channelFilesStores =
      ServerBoundCache<String, SourceChannelFilesStore>(
        _panelIdentity,
        limit: 24,
        onEvict: (store) => store.retire(),
      );

  SourceChannelFilesStore channelFilesStore(String channelId) {
    final owner = source;
    if (owner != null) return owner.channelFilesStore(channelId);
    final store = _channelFilesStores.putIfAbsent(
      channelId,
      () => SourceChannelFilesStore(
        channelId: channelId,
        authority: () => _channelFilesAuthority(channelId),
        get: (path, {query}) async {
          try {
            return await authority.client.get(path, query: query);
          } on RaftApiException catch (error) {
            throw ChannelFilesRequestFailure(
              [401, 403].contains(error.status)
                  ? ChannelFilesFailure.unauthorized
                  : ChannelFilesFailure.unavailable,
            );
          }
        },
      ),
    );
    store.syncAuthority();
    return store;
  }

  SourceActivityUnreadStore get activityUnread => isDisposed()
      ? throw StateError('Workspace session is disposed.')
      : source?.activityUnread ??
            (_activityUnread ??= SourceActivityUnreadStore(authority));
  SourceActivityUnreadStore? _activityUnread;

  SourceActivityUnreadStore? get activityUnreadIfBound =>
      isDisposed() ? null : source?.activityUnreadIfBound ?? _activityUnread;

  /// Flush only this presentation's already-created, owned repositories.
  void flushDevice() {
    if (ownsEntityDirectory) entityDirectory.flushDevice();
    _translations?.flushDevice();
  }

  // Teardown stays in its existing phases around media and socket cleanup.
  // None of these methods constructs a lazy notifier or disposes source stores.
  void disposeOwnedStores() {
    liveConnection?.dispose();
    if (ownsEntityDirectory) entityDirectory.dispose();
    if (ownsFollowedThreads) followedThreads.dispose();
    _translations?.dispose();
    _threadSearch?.dispose();
    _threadFollowers?.dispose();
    _readReceipts?.dispose();
    _announcements?.dispose();
    _announcementGate?.dispose();
    for (final dispose in _disposers.reversed) {
      dispose();
    }
    _disposers.clear();
  }

  final _disposers = <void Function()>[];

  /// Presentation-owned notifiers that live as long as this session (the
  /// unread flags and roll-ups, which are created on first use) are disposed
  /// with it.
  void disposeWithSession(void Function() dispose) => _disposers.add(dispose);

  void retireChannelFiles() => _channelFilesStores.clear();

  void disposeActivityUnread() {
    _activityUnread?.dispose();
    _activityUnread = null;
  }
}
