import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import 'conversation_presentation_state.dart';
import 'navigation_registry.dart';
import 'raft_location.dart';
import 'user_activity.dart';
import 'workspace_navigation.dart';
import 'workspace_presentation_ports.dart';
import 'workspace_session_context.dart';

/// Receiver-local page state and navigation. Borrowed commands retain their
/// original source dispatch; message windows and directory data stay separate.
class WorkspacePresentation {
  WorkspacePresentation({
    required this.context,
    required this.client,
    required this.directory,
    required this.conversations,
    required this.source,
    required this.mobileNavigation,
  }) : boundSourceAuthority = source?.navigationAuthority;

  final WorkspaceSessionContext context;
  final RaftClient client;
  final WorkspacePresentationDirectoryPort directory;
  final WorkspacePresentationConversationPort conversations;
  final WorkspacePresentationSourcePort? source;
  final String? boundSourceAuthority;
  bool presentationActive = true;
  bool mobileNavigation;
  RaftChannel? channel;
  bool loading = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Existing receiver-local notice, assigned without notification by the ordered domain ports; consumed by WorkspaceView.
  String? error;
  final foregroundChanges = ValueNotifier<bool>(true);

  /// Called at the original foreground notifier disposal stage in the root.
  void dispose() => foregroundChanges.dispose();

  bool get _disposed => context.disposed;
  RaftRecord? get server => context.server;
  bool get hasNewer => conversations.hasNewer;
  String? get threadChannelId => conversations.threadChannelId;
  List<RaftChannel> get channels => directory.channels;
  set channels(List<RaftChannel> value) => directory.channels = value;
  List<RaftChannel> get dms => directory.dms;
  set dms(List<RaftChannel> value) => directory.dms = value;
  bool can(String capability, {RaftChannel? resource}) =>
      context.can(capability, resource: resource);
  WorkspacePresentationSourcePort? get presentationSource => source;

  void assignUnboundSection(String value) => _unboundSection = value;
  void assignMissingConversationChannelId(String? value) =>
      _missingConversationChannelId = value;
  bool get mainPresented => _mainPresented;
  bool get threadPresented => _threadPresented;
  bool get chatTabPresented => _chatTabPresented;
  bool rejectRevokedConversation(String id) => _rejectRevokedConversation(id);

  final _conversationPresentation = ConversationPresentationState();
  bool get _mainPresented => _conversationPresentation.main;
  bool get _threadPresented => _conversationPresentation.thread;
  bool get _chatTabPresented => _conversationPresentation.chat;

  /// Channel tabs and folded panels are independent presentation owners.
  /// Neither loaded data nor an offstage retained editor admits a read receipt.
  void setChatTabPresentation(Object owner, bool visible) {
    _conversationPresentation.setTab(owner, visible);
    if (presentationSource != null) {
      if (presentationActive) {
        presentationSource!.setChatTabPresentation(owner, visible);
      }
    }
  }

  void releaseChatTabPresentation(Object owner) {
    presentationSource?.releaseChatTabPresentation(owner);
    _conversationPresentation.releaseTab(owner);
  }

  /// Mounted layout admission, separate from accepted message windows. This
  /// changes synchronously without notifying/rebuilding the controller tree.
  void setConversationPresentation(
    Object owner, {
    required bool main,
    required bool thread,
  }) {
    _conversationPresentation.setConversation(
      owner,
      main: main,
      thread: thread,
    );
    if (presentationSource != null) {
      if (presentationActive) {
        presentationSource!.setConversationPresentation(
          owner,
          main: main,
          thread: thread,
        );
      }
    }
  }

  void releaseConversationPresentation(Object owner) {
    presentationSource?.releaseConversationPresentation(owner);
    _conversationPresentation.releaseConversation(owner);
  }

  bool foreground = true;
  void setForeground(bool value) {
    foreground = value;
    if (!value) RaftUserActivity.forget();
    foregroundChanges.value = value;
    if (value) {
      if (channel != null && !hasNewer) conversations.markRead(channel!.id);
      if (threadChannelId != null) conversations.markRead(threadChannelId!);
    }
  }

  final navigation = WorkspaceNavigation();
  String _unboundSection = 'chat';
  String? _navigationAuthority;
  String get navigationAuthority => jsonEncode([
    client.origin,
    client.generation,
    client.user?.id,
    server?.id,
    client.serverId,
    server?.string('role'),
  ]);
  void bindNavigation() {
    if (server == null) return;
    final authority = navigationAuthority;
    if (_navigationAuthority == authority) return;
    final slug =
        [
          server!.string('slug'),
          server!.id,
          client.serverId,
        ].whereType<String>().where((value) => value.isNotEmpty).firstOrNull ??
        '_';
    final initial = _navigationAuthority == null
        ? WorkspaceNavigation.locationForSection(
            slug,
            _unboundSection,
            channelId: channel?.id,
            dm: channel?.type == 'dm',
          )
        : navigation.location.serverSlug == slug
        ? navigation.location
        : WorkspaceNavigation.locationForSection(
            slug,
            mobileNavigation ? 'home' : _unboundSection,
            channelId: null,
          );
    _navigationAuthority = authority;
    navigation.bind(authority, initial);
  }

  RaftLocation get location {
    bindNavigation();
    return navigation.location;
  }

  int get navigationRevision {
    bindNavigation();
    return navigation.revision;
  }

  String get section {
    bindNavigation();
    if (server == null) return _unboundSection;
    final projected = navigation.section;
    // SettingsPanel.tsx:7882–7894 retains the requested URL while a denied
    // tab resolves to Account. It does not redirect the entire workspace.
    return navigation.location.route == RaftRoute.settings &&
            !canVisitSection(projected)
        ? 'settings'
        : projected;
  }

  set section(String value) {
    _unboundSection = value;
    final firstBind = _navigationAuthority == null && server != null;
    bindNavigation();
    if (server != null && !firstBind) {
      navigation.selectSection(
        value,
        channelId: channel?.id,
        dm: channel?.type == 'dm',
      );
    }
  }

  bool canVisitSection(String name) {
    final capability = const {
      'agents': 'viewAgents',
      'computers': 'viewMachines',
      'members': 'viewMembers',
      'providers': 'manageExternalAuth',
      'integrations': 'manageIntegrations',
      'im-bridges': 'manageIntegrations',
      'administration': 'viewServerSettings',
      'billing': 'viewBilling',
      'workspace-settings': 'viewServerSettings',
    }[name];
    if (capability != null) return can(capability);
    return const {
      'home',
      'chat',
      'activity',
      'search',
      'saved',
      'tasks',
      'settings',
    }.contains(name);
  }

  bool _rejectRevokedConversation(String id) {
    if (_disposed || !context.isChannelRevoked(id)) return false;
    if (location.entityId == id) {
      _missingConversationChannelId = id;
      _resolvingConversationChannelId = null;
      context.changed();
    }
    return true;
  }

  String? _resolvingConversationChannelId, _missingConversationChannelId;
  int _conversationResolutionRequest = 0;
  String? get missingConversationChannelId => _missingConversationChannelId;

  /// MainLayout ChannelById/ensureChannel: hydrate a real channel without
  /// treating the thread's focused reply as a message in its parent channel.
  /// URI, principal/server epoch and request ownership fence late arrival.
  Future<void> resolveConversationChannel(
    String id, {
    bool preserveThread = false,
  }) async {
    final source = presentationSource;
    if (source != null) {
      return source.resolveConversationChannel(
        id,
        preserveThread: preserveThread,
      );
    }
    final request = ++_conversationResolutionRequest,
        revision = navigationRevision,
        scope = navigationAuthority,
        reply = conversations.replyToken(id),
        generation = conversations.generation;
    bool current() =>
        !_disposed &&
        request == _conversationResolutionRequest &&
        revision == navigationRevision &&
        scope == navigationAuthority &&
        reply == conversations.replyToken(id) &&
        generation == conversations.generation &&
        !context.isChannelRevoked(id);
    if (_disposed ||
        _rejectRevokedConversation(id) ||
        id.isEmpty ||
        !can('viewChannel')) {
      return;
    }
    _resolvingConversationChannelId = id;
    _missingConversationChannelId = null;
    context.changed();
    try {
      var real = [...channels, ...dms].where((c) => c.id == id).firstOrNull;
      if (real == null) {
        final data = await client.get('/channels/$id');
        if (!current()) return;
        if (data is! Map ||
            data['id'] != id ||
            data['serverId'] != null && data['serverId'] != server?.id) {
          throw const RaftApiException('This channel is not available.');
        }
        real = RaftChannel(Map<String, dynamic>.from(data));
        if (!can('viewChannel', resource: real)) return;
        if (real.type == 'dm') {
          dms = [...dms.where((c) => c.id != id), real];
        } else {
          channels = [...channels.where((c) => c.id != id), real];
        }
      }
      if (!current() || !can('viewChannel', resource: real)) return;
      await conversations.selectChannel(
        real,
        navigate: false,
        preserveThread: preserveThread,
      );
    } catch (_) {
      if (current()) _missingConversationChannelId = id;
    } finally {
      if (current() && _resolvingConversationChannelId == id) {
        _resolvingConversationChannelId = null;
        context.changed();
      }
    }
  }

  // Web profileStore: the profile side panel is a URL slot (`profile=`); an
  // external author's frozen attribution payload lives beside it.
  final Map<String, Map<String, dynamic>> _externalProfiles = {};

  /// The provider attribution frozen when an external author's panel opened.
  Map<String, dynamic>? externalProfile(String messageId) =>
      presentationSource?.externalProfile(messageId) ??
      _externalProfiles[messageId];

  /// Web `openProfile` / `openExternalProfile`: a human or agent (optionally
  /// landing on an agent [agentTab]) or an external message author
  /// ([id] = message id, [channelId] its channel, [externalAuthor] the
  /// attribution). Adding a panel pushes history; retargeting replaces.
  void openProfile(
    RaftProfileKind kind,
    String id, {
    String? agentTab,
    String? channelId,
    Map<String, dynamic>? externalAuthor,
  }) {
    final source = presentationSource;
    if (source != null) {
      source.openProfile(
        kind,
        id,
        agentTab: agentTab,
        channelId: channelId,
        externalAuthor: externalAuthor,
      );
      return;
    }
    if (id.trim().isEmpty ||
        kind == RaftProfileKind.external && (channelId?.isEmpty ?? true)) {
      return;
    }
    if (externalAuthor != null) _externalProfiles[id] = externalAuthor;
    final next = location.withQuery({
      'profile': RaftProfileLocation.query(kind, id, channelId, externalAuthor),
      'agentTab': kind == RaftProfileKind.agent ? agentTab : null,
    });
    if (next.uri == location.uri) return;
    navigation.navigateProfile(
      next,
      kind: location.panelNavigationKindTo(next),
    );
    context.changed();
  }

  /// Web `closeProfile`: removing a slot replaces the history entry.
  void closeProfile() {
    final source = presentationSource;
    if (source != null) {
      source.closeProfile();
      return;
    }
    if (location.profile == null) return;
    final next = location.withQuery({'profile': null, 'agentTab': null});
    navigation.navigateProfile(
      next,
      kind: location.panelNavigationKindTo(next),
    );
    context.changed();
  }

  void setSection(String next) {
    if (!NavigationRegistry.knowsSection(next)) {
      NavigationRegistry.reportFallback(
        'section',
        next,
        NavigationRegistry.unsupportedSections[next],
      );
      return;
    }
    final source = presentationSource;
    if (source != null) {
      source.setSection(next);
      return;
    }
    if (!canVisitSection(next)) return;
    section = next;
    context.changed();
  }

  void setError(String? value) {
    final source = presentationSource;
    if (source != null) {
      // ignore: raft_lints/avoid_imperative_notice_state -- Delegates to the session source.
      source.setError(value);
      return;
    }
    error = value;
    context.changed();
  }
}
