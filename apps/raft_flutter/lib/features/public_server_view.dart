// The Public server page (Web pages/PublicServerPage.tsx): the read-only
// preview of a public server reached from `/s/<slug>` by someone who is not a
// member, signed out (sign in / create account) or signed in (Join as Guest).
// Data lifecycle follows the Web reducer: the server readback loads on mount
// (404 means unavailable), the first public channel (or the linked one) is
// selected, its latest 50 messages load on selection and older pages on
// demand, and a thread opens its own read-only panel.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/message_translation_store.dart';
import '../data/source_time_formatter.dart';
import '../data/workspace_controller.dart';
import '../platform/content_links.dart';
import '../data/server_error_code.dart';
import '../data/user_error.dart';
import 'chinese_community.dart';
import 'community_join.dart'
    show communityAgreementError, communityServerSlug, joinCommunity;
import 'custom_protocol_link.dart';
import 'management_support.dart';
import 'public_attachments.dart';
import 'public_avatar_url.dart';
import 'public_rich_message.dart';
import 'public_translation.dart';
import 'public_server_panels.dart';
import 'public_server_settings.dart';
import 'sender_avatar_projection.dart';

/// A message of the public readback (`PublicMessage`).
@immutable
class PublicServerMessage {
  const PublicServerMessage({
    required this.id,
    required this.senderType,
    required this.author,
    required this.content,
    required this.createdAt,
    required this.messageType,
    this.description,
    this.avatarUrl,
    this.threadId,
    this.replyCount = 0,
    this.attachments = const [],
    this.mentions = const [],
    this.reactions = const [],
    this.lastReplyAt,
    this.latestReplies = const [],
  });

  factory PublicServerMessage.fromJson(Map<String, dynamic> json) {
    final sender = managementMap(json['sender']);
    return PublicServerMessage(
      id: '${json['id']}',
      senderType: '${json['senderType']}',
      author: '${sender['displayName'] ?? ''}',
      description: sender['description'] as String?,
      avatarUrl: sender['avatarUrl'] as String?,
      messageType: '${json['messageType'] ?? 'chat'}',
      content: '${json['content'] ?? ''}',
      createdAt: DateTime.tryParse('${json['createdAt']}'),
      threadId: json['threadId'] as String?,
      replyCount: int.tryParse('${json['replyCount']}') ?? 0,
      // Absent from servers older than the public rich-message projection.
      attachments: [
        for (final a in json['attachments'] as List? ?? const [])
          ?PublicAttachment.tryParse(a),
      ],
      mentions: [
        for (final m in json['mentions'] as List? ?? const [])
          ?PublicMention.tryParse(m),
      ],
      reactions: [
        for (final r in json['reactions'] as List? ?? const [])
          ?PublicReaction.tryParse(r),
      ],
      lastReplyAt: DateTime.tryParse('${json['lastReplyAt']}'),
      latestReplies: [
        for (final r in json['latestReplies'] as List? ?? const [])
          ?PublicThreadReply.tryParse(r),
      ],
    );
  }
  final String id, senderType, author, content, messageType;
  final String? description, avatarUrl, threadId;
  final DateTime? createdAt;
  final int replyCount;

  /// File metadata, `@token` mentions, emoji counts and the newest thread
  /// replies (the inline preview); each empty from an older server.
  final List<PublicAttachment> attachments;
  final List<PublicMention> mentions;
  final List<PublicReaction> reactions;
  final DateTime? lastReplyAt;
  final List<PublicThreadReply> latestReplies;

  /// `toReadOnlyMessage`: a display-local key; the public DTO exposes no
  /// authority-bearing identifier.
  String get senderKey => 'public:$senderType:$author:${avatarUrl ?? ''}';
}

/// What the page needs from the account when the visitor is signed in.
@immutable
class PublicServerAccount {
  const PublicServerAccount({
    required this.servers,
    required this.onSelect,
    this.settings,
  });

  /// The signed-in visitor of [controller]: the workspace's servers for the
  /// rail switcher and the Settings pages a non-member also gets.
  PublicServerAccount.of(
    WorkspaceController controller, {
    required this.onSelect,
    required RaftAppearance appearance,
    required Future<void> Function(RaftAppearance) onAppearance,
    required Future<void> Function() onLogout,
  }) : servers = controller.servers,
       settings = PublicSettingsAccount(
         controller: controller,
         appearance: appearance,
         onAppearance: (next) => unawaited(onAppearance(next)),
         onLogout: onLogout,
       );

  /// The signed-in Settings pages (Account, Language & Region, Appearance,
  /// Feedback, Release Notes) a non-member also gets; null shows only About
  /// and Documentation.
  final PublicSettingsAccount? settings;

  /// The visitor's servers for the rail switcher.
  final List<RaftRecord> servers;

  /// Switch to one of [servers].
  final void Function(RaftRecord server) onSelect;
}

/// What a visitor has already read of a public server, kept for the session
/// so a revisit (or switching back to a channel) paints at once and
/// revalidates quietly. Public pages carry no credentials; the key binds the
/// server address, slug and the visitor's account.
class PublicServerMemory {
  PublicServerMemory._();
  static const _servers = 8, _pages = 64;
  static final _server = <String, Map<String, dynamic>>{};
  static final _messages = <String, List<PublicServerMessage>>{};

  static String key(RaftClient client, String slug) =>
      '${client.origin}|${client.user?.id}|$slug';

  static Map<String, dynamic>? server(String key) => _server[key];
  static void rememberServer(String key, Map<String, dynamic> data) {
    _server.remove(key);
    _server[key] = data;
    while (_server.length > _servers) {
      _server.remove(_server.keys.first);
    }
  }

  static List<PublicServerMessage>? messages(String key, String page) =>
      _messages['$key|$page'];
  static void rememberMessages(
    String key,
    String page,
    List<PublicServerMessage> rows,
  ) {
    final id = '$key|$page';
    _messages.remove(id);
    _messages[id] = List.unmodifiable(rows);
    while (_messages.length > _pages) {
      _messages.remove(_messages.keys.first);
    }
  }

  /// The server is no longer public (or the visitor lost access).
  static void forget(String key) {
    _server.remove(key);
    _messages.removeWhere((id, _) => id.startsWith('$key|'));
  }

  @visibleForTesting
  static void clear() {
    _server.clear();
    _messages.clear();
  }
}

void _ignore() {}

class PublicServerView extends StatefulWidget {
  const PublicServerView({
    super.key,
    required this.client,
    required this.slug,
    required this.onUnavailable,
    this.onSignIn = _ignore,
    this.onRegister = _ignore,
    this.initialChannelId,
    this.account,
    this.onJoined,
    this.appVersion = const String.fromEnvironment('RAFT_APP_VERSION'),
    this.documentationUrl = 'https://docs.raft.build',
  });
  final RaftClient client;
  final String slug;

  /// Channel from a `/s/<slug>/channel/<id>` link; ignored unless public.
  final String? initialChannelId;
  final VoidCallback onSignIn, onRegister, onUnavailable;

  /// Set when signed in: Join as Guest replaces Sign in / Create account.
  final PublicServerAccount? account;

  /// After a guest join: reload the server list and open the server. A
  /// failure here never reads as a failed join (membership is durable).
  final Future<void> Function()? onJoined;
  final String? appVersion;
  final String documentationUrl;
  @override
  State<PublicServerView> createState() => _PublicServerViewState();
}

class _PublicServerViewState extends State<PublicServerView> {
  bool get authenticated => widget.account != null;
  Map<String, dynamic>? server;
  List<Map<String, dynamic>> channels = [];
  bool canJoin = false;
  String? selectedId;
  List<PublicServerMessage> messages = [];
  bool loadingMessages = false, hasOlder = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Page load error: cleared at the start of every server/messages/older load and on a server reload.
  String error = '';
  int serverRequest = 0, messageRequest = 0;

  bool settings = false;

  /// Phones show one column at a time (Web `phoneView`): the channel list
  /// first, then the channel full width with a Back to channels. A link to a
  /// channel opens it.
  late bool phoneChannel = widget.initialChannelId != null;

  /// Message translation of this page (Web `useTranslationBatch`): the
  /// signed-in visitor's own store, else one with the preferences kept on
  /// this device.
  MessageTranslationStore? translations;
  PublicLocalPreferences? localPrefs;
  bool ownsTranslations = false;

  /// The selected Settings tab (`useState(authenticated ? "account" : "about")`).
  late String settingsTab = widget.account?.settings != null
      ? 'account'
      : 'about';
  PublicPanelWidths? panels;
  // ignore: raft_lints/avoid_imperative_notice_state -- Anonymous rail prompt (Web keeps it sticky): shown only while the visitor is signed out.
  bool selectionNotice = false;
  final menu = RaftMenuController();

  // Scroll controllers: older pages load when their view reaches its start.
  final timelineScroll = ScrollController(), threadScroll = ScrollController();

  // Thread panel.
  String? threadChannelId, threadParentId;
  List<PublicServerMessage> threadMessages = [];
  bool threadLoading = false, threadHasOlder = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Thread panel error: cleared when a thread is opened (it replaces the thread body, as in Web).
  String threadError = '';
  int threadRequest = 0;

  // Join flow.
  bool joining = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Join failure banner: cleared when a join starts and when the server (slug/client) reloads; kept after cancelling the dialog as in Web.
  String joinError = '';

  String get base => '/public/servers/${Uri.encodeComponent(widget.slug)}';
  String tr(String s) => raftText(context, s);

  @override
  void initState() {
    super.initState();
    menu.addListener(menuChanged);
    setUpTranslations();
    unawaited(loadServer());
  }

  void setUpTranslations() {
    final workspace = widget.account?.settings?.controller;
    if (workspace != null) {
      translations = workspace.services.translations;
    } else {
      ownsTranslations = true;
      if (widget.account == null) {
        localPrefs = PublicLocalPreferences()
          ..addListener(() => translations?.publicPreferencesChanged());
        unawaited(localPrefs!.load());
      }
      translations = MessageTranslationStore(
        PublicTranslationAuthority(widget.client),
      );
    }
    translations!.addListener(panelsChanged);
  }

  Map<String, dynamic> localPreferenceJson() => localPrefs!.json;

  /// The page's gate for translation: `server.translationEnabled` with the
  /// deployment's provider (Web `loadSettings(serverId, publicServerProjection)`).
  bool get translationEnabled => server?['translationEnabled'] == true;

  void bindTranslation(Map<String, dynamic> data) {
    final id = server?['id'];
    if (id is! String) return;
    translations?.usePublicServer(
      PublicTranslationScope(
        serverId: id,
        slug: widget.slug,
        enabled: translationEnabled,
        available: data['translationAvailable'] == true,
        preferences: localPrefs == null ? null : localPreferenceJson,
      ),
    );
  }

  @override
  void didUpdateWidget(PublicServerView old) {
    super.didUpdateWidget(old);
    if (old.slug != widget.slug || old.client != widget.client) {
      unawaited(loadServer());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The thread column's max is 60% of the viewport (panelBounds.ts).
    panels ??= PublicPanelWidths(viewport: MediaQuery.sizeOf(context).width)
      ..addListener(panelsChanged)
      ..load();
  }

  void panelsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    menu.removeListener(menuChanged);
    menu.dispose();
    translations?.removeListener(panelsChanged);
    if (ownsTranslations) {
      translations?.dispose();
    } else {
      translations?.clearPublicServer();
    }
    localPrefs?.dispose();
    panels?.dispose();
    timelineScroll.dispose();
    threadScroll.dispose();
    super.dispose();
  }

  /// The anonymous rail logo answers with the sign-in notice instead of the
  /// server menu (`onAnonymousServerSelection`).
  void menuChanged() {
    if (menu.isOpen && !authenticated) {
      menu.close();
      setState(() => selectionNotice = true);
    }
  }

  /// Adopts the server answer [data]. [revalidating] keeps the channel the
  /// visitor is already reading when it is still public.
  void applyServer(Map<String, dynamic> data, {bool revalidating = false}) {
    final list = managementRows(data['channels']);
    final linked = list
        .where((c) => c['id'] == widget.initialChannelId)
        .firstOrNull;
    final keep = revalidating && list.any((c) => c['id'] == selectedId)
        ? selectedId
        : null;
    server = managementMap(data['server']);
    channels = list;
    canJoin = data['canJoinAsGuest'] == true;
    bindTranslation(data);
    final next = keep ?? '${(linked ?? list.firstOrNull)?['id'] ?? ''}';
    selectedId = next.isEmpty ? null : next;
    if (keep == null) {
      final seen = selectedId == null
          ? null
          : PublicServerMemory.messages(memoryKey, 'channel:$selectedId');
      messages = [...?seen];
      hasOlder = seen != null && seen.length == 50;
    }
  }

  String get memoryKey => PublicServerMemory.key(widget.client, widget.slug);

  Future<void> loadServer() async {
    final request = ++serverRequest;
    final key = memoryKey;
    final seen = PublicServerMemory.server(key);
    setState(() {
      server = null;
      channels = [];
      selectedId = null;
      messages = [];
      loadingMessages = false;
      hasOlder = false;
      error = '';
      // A join failure belongs to the server (and visitor) it was raised for.
      joinError = '';
      threadChannelId = null;
      if (seen != null) applyServer(seen);
    });
    if (seen != null) unawaited(loadMessages());
    try {
      final data = managementMap(await widget.client.get(base));
      if (!mounted || request != serverRequest) return;
      PublicServerMemory.rememberServer(key, data);
      final reading = selectedId;
      setState(() => applyServer(data, revalidating: seen != null));
      if (seen == null || selectedId != reading) unawaited(loadMessages());
    } on RaftApiException catch (e) {
      if (!mounted || request != serverRequest) return;
      if (e.status == 404) {
        PublicServerMemory.forget(key);
        widget.onUnavailable();
        return;
      }
      // A failed revalidation keeps what the visitor is reading.
      if (seen != null) return;
      setState(
        () => error = tr(
          userErrorText(
            e,
            fallback: 'Failed to load this public server',
            where: 'public server',
          ),
        ),
      );
    } catch (_) {
      if (mounted && request == serverRequest && seen == null) {
        setState(() => error = tr('Failed to load this public server'));
      }
    }
  }

  /// PublicServerPage: 404 says the page is no longer public, otherwise the
  /// server's text, else the localized fallback.
  String messageFailure(Object e) => tr(
    userErrorText(
      e,
      fallback: 'Failed to load public messages',
      statusText: const {404: 'This server or channel is no longer public.'},
      where: 'public messages',
    ),
  );

  Future<void> loadMessages() async {
    final id = selectedId;
    if (id == null) return;
    final request = ++messageRequest;
    setState(() {
      loadingMessages = true;
      error = '';
    });
    try {
      final data = managementMap(
        await widget.client.get('$base/channels/$id/messages'),
      );
      if (!mounted || request != messageRequest) return;
      final rows = managementRows(data['messages'])
          .map(PublicServerMessage.fromJson)
          .toList();
      PublicServerMemory.rememberMessages(memoryKey, 'channel:$id', rows);
      setState(() {
        loadingMessages = false;
        messages = rows;
        hasOlder = rows.length == 50;
      });
    } catch (e) {
      if (mounted && request == messageRequest) {
        setState(() {
          loadingMessages = false;
          error = messageFailure(e);
        });
      }
    }
  }

  Future<void> loadOlder() async {
    final id = selectedId;
    // The scroll view asks on every notification at its start: one at a time.
    if (id == null || messages.isEmpty || loadingMessages || !hasOlder) return;
    setState(() {
      loadingMessages = true;
      error = '';
    });
    try {
      final data = managementMap(
        await widget.client.get(
          '$base/channels/$id/messages',
          query: {'beforeMessageId': messages.first.id},
        ),
      );
      if (!mounted || selectedId != id) return;
      final rows = managementRows(data['messages'])
          .map(PublicServerMessage.fromJson)
          .toList();
      setState(() {
        loadingMessages = false;
        messages = [...rows, ...messages];
        hasOlder = rows.length == 50;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loadingMessages = false;
          error = messageFailure(e);
        });
      }
    }
  }

  void selectChannel(String id) {
    if (id == selectedId && !settings) {
      if (!phoneChannel) setState(() => phoneChannel = true);
      return;
    }
    final seen = PublicServerMemory.messages(memoryKey, 'channel:$id');
    setState(() {
      selectedId = id;
      messages = [...?seen];
      hasOlder = seen != null && seen.length == 50;
      threadChannelId = null;
      settings = false;
      phoneChannel = true;
    });
    unawaited(loadMessages());
  }

  Future<void> openThread(PublicServerMessage parent) async {
    final id = parent.threadId;
    if (id == null) return;
    final request = ++threadRequest;
    final seen = PublicServerMemory.messages(memoryKey, 'thread:$id');
    setState(() {
      threadChannelId = id;
      threadParentId = parent.id;
      threadMessages = [...?seen];
      threadError = '';
      threadHasOlder = seen != null && seen.length == 50;
      threadLoading = true;
    });
    try {
      final data = managementMap(
        await widget.client.get(
          '$base/threads/${Uri.encodeComponent(id)}/messages',
          query: {'limit': 50},
        ),
      );
      if (!mounted || request != threadRequest) return;
      final rows = managementRows(data['messages'])
          .map(PublicServerMessage.fromJson)
          .toList();
      PublicServerMemory.rememberMessages(memoryKey, 'thread:$id', rows);
      setState(() {
        threadMessages = rows;
        threadHasOlder = rows.length == 50;
      });
    } catch (e) {
      if (mounted && request == threadRequest) {
        setState(() => threadError = threadFailure(e));
      }
    } finally {
      if (mounted && request == threadRequest) {
        setState(() => threadLoading = false);
      }
    }
  }

  String threadFailure(Object e) => tr(
    userErrorText(
      e,
      fallback: "Couldn't load this thread",
      statusText: const {404: 'This server or channel is no longer public.'},
      where: 'public thread',
    ),
  );

  Future<void> loadOlderThread() async {
    final id = threadChannelId;
    if (id == null || threadLoading || threadMessages.isEmpty) return;
    final request = threadRequest;
    setState(() => threadLoading = true);
    try {
      final data = managementMap(
        await widget.client.get(
          '$base/threads/${Uri.encodeComponent(id)}/messages',
          query: {'limit': 50, 'beforeMessageId': threadMessages.first.id},
        ),
      );
      if (!mounted || request != threadRequest) return;
      final rows = managementRows(data['messages'])
          .map(PublicServerMessage.fromJson)
          .toList();
      setState(() {
        threadMessages = [...rows, ...threadMessages];
        threadHasOlder = rows.length == 50;
      });
    } catch (e) {
      if (mounted && request == threadRequest) {
        setState(() => threadError = threadFailure(e));
      }
    } finally {
      if (mounted && request == threadRequest) {
        setState(() => threadLoading = false);
      }
    }
  }

  void closeThread() {
    threadRequest++;
    setState(() => threadChannelId = null);
  }

  /// Phones: Back to channels (`showPhoneChannelList`).
  void showChannelList() {
    threadRequest++;
    setState(() {
      phoneChannel = false;
      threadChannelId = null;
    });
  }

  /// `joinAsGuest`: the confirm and agreement dialogs both end here. Returns
  /// the agreement the server asks to accept first (`agreement_required` /
  /// `agreement_changed`), null once joined; a failure rethrows.
  Future<Map<String, dynamic>?> joinAsGuest([String? agreementId]) async {
    setState(() {
      joining = true;
      joinError = '';
    });
    try {
      await widget.client.post(
        '$base/join-as-guest',
        data: {'agreementId': agreementId},
      );
    } on RaftApiException catch (e) {
      final body = e.details['agreement'];
      if (mounted) {
        final asked =
            (serverErrorIs(e, 'agreement_required') ||
                serverErrorIs(e, 'agreement_changed') ||
                serverErrorCode(e) == 'agreement_required' ||
                serverErrorCode(e) == 'agreement_changed') &&
            body is Map;
        setState(() {
          joining = false;
          if (!asked) {
            joinError = tr(
              userErrorText(
                e,
                fallback: 'Failed to join this public server',
                where: 'public join',
              ),
            );
          }
        });
        if (asked) return Map<String, dynamic>.from(body);
      }
      rethrow;
    }
    try {
      await widget.onJoined?.call();
    } catch (_) {
      // Membership is already durable: never invite an unsafe retry because
      // the local refresh or route transition failed.
      if (mounted) {
        setState(
          () => joinError = tr(
            'You joined this server. Refresh the page to open it.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => joining = false);
    }
    return null;
  }

  /// The Join as Guest confirm; an agreement answer continues in its dialog.
  Future<void> startJoin() async {
    Map<String, dynamic>? asked;
    await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        title: tr('Join this server?'),
        message: raftFormat(
          context,
          'You will join {server} as a Guest. You can keep reading without joining by cancelling.',
          {'server': '${server?['name'] ?? widget.slug}'},
        ),
        confirmLabel: tr('Join as Guest'),
        loadingLabel: tr('Joining…'),
        confirmVariant: RaftButtonRecipeVariant.accent,
        confirmKey: const ValueKey('public-join-confirm'),
        onConfirm: () async => asked = await joinAsGuest(),
      ),
    );
    if (asked != null && mounted) await showAgreement(asked!);
  }

  /// The shared community agreement dialog (CommunityAgreementDialog.tsx).
  /// Agreeing joins with the agreement id; a changed agreement
  /// (`agreement_changed`) replaces the one shown, any other failure keeps the
  /// dialog open with its error line.
  Future<void> showAgreement(Map<String, dynamic> first) async {
    var current = first;
    await showRaftDialog<void>(
      context: context,
      modal: true,
      builder: (modal) => StatefulBuilder(
        builder: (modal, update) => RaftCommunityAgreementDialog(
          title: '${current['title']}',
          version: (current['version'] as num?)?.toInt() ?? 1,
          bodyMarkdown: '${current['bodyMarkdown'] ?? ''}',
          errorMessage: communityAgreementError,
          onClose: () => Navigator.of(modal).pop(),
          onAgree: () async {
            final next = await joinAsGuest('${current['id']}');
            if (!modal.mounted) return;
            if (next == null) {
              Navigator.of(modal).pop();
            } else {
              update(() => current = next);
            }
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- build

  /// Account time preferences apply to every appearance. A signed-out visitor
  /// uses the browser/system defaults, as in Web useTimeFormatter.
  SourceTimeFormatter get timeFormatter {
    final user = authenticated ? widget.client.user : null;
    return SourceTimeFormatter(
      locale: Localizations.localeOf(context).toLanguageTag(),
      preferredTimezone:
          user?.string('preferredTimezone') ?? user?.string('timezone'),
      preferredTimeFormat: sourceTimeFormatPreference(
        user?.string('preferredTimeFormat') ?? user?.string('timeFormat'),
      ),
      systemTimeFormat: MediaQuery.alwaysUse24HourFormatOf(context)
          ? SourceTimeFormat.twentyFourHour
          : null,
      todayLabel: tr('Today'),
      yesterdayLabel: tr('Yesterday'),
    );
  }

  /// `#channel` mentions of the public channels chip like Web's MessageItem
  /// (`channels={displayChannels}`); users and agents are not linkable here.
  List<RaftTextReference> get channelReferences => [
    for (final c in channels)
      RaftTextReference(
        text: '#${c['name']}',
        href: Uri(
          scheme: 'raft-ref',
          host: 'channel',
          pathSegments: ['${c['id']}'],
        ).toString(),
        identityBacked: true,
      ),
  ];

  /// The `@token` mentions of [m]: Web's display-local mention map
  /// (`public:<type>:<name>`), so the renderer marks the token; the public
  /// projection carries no principal to link to.
  List<RaftTextReference> mentionReferences(PublicServerMessage m) => [
    for (final mention in m.mentions)
      RaftTextReference(
        text: '@${mention.name}',
        href: Uri(
          scheme: 'raft-ref',
          host: 'mention',
          pathSegments: [mention.type, mention.key],
        ).toString(),
        identityBacked: true,
      ),
  ];

  /// Where the attachment bytes of this page live.
  PublicAttachmentUrls get attachmentUrls => PublicAttachmentUrls(
    api: '${widget.client.origin}/api',
    slug: widget.slug,
  );

  /// The same inline reply preview a member sees (Web
  /// `readOnlyReplyScope`); null when the server sent no latest replies.
  Widget? inlineReplies(PublicServerMessage m, VoidCallback? onOpen) {
    if (m.threadId == null || m.replyCount <= 0 || m.latestReplies.isEmpty) {
      return null;
    }
    final formatter = timeFormatter;
    final count = raftFormat(context, '{count} replies', {
      'count': m.replyCount,
    });
    return RaftInlineThreadSurface(
      key: ValueKey('public-inline-thread-${m.id}'),
      replies: [
        for (final r in m.latestReplies)
          RaftInlineReply(
            id: r.messageId,
            author: r.senderName,
            preview: r.preview,
            senderType: r.senderType,
            timestamp: r.createdAt == null ? '' : formatter.clock(r.createdAt),
            avatar: avatarOf(
              author: r.senderName,
              senderType: r.senderType,
              avatarUrl: r.senderAvatarUrl,
              // Public replies carry no sender id: a display-local key.
              senderKey:
                  'public:${r.senderType}:${r.senderName}:${r.senderAvatarUrl ?? ''}',
              avatarContext: RaftMountedAvatarContext.compactList,
            ),
          ),
      ],
      replyCount: m.replyCount,
      semanticLabel: count,
      summary: Text('$count ›'),
      onOpen: onOpen,
    );
  }

  /// `onReadOnlyNavigateChannel`: a channel chip selects that public channel.
  void openReference(String href) {
    final uri = Uri.tryParse(href);
    if (uri != null &&
        uri.scheme == 'raft-ref' &&
        uri.host == 'channel' &&
        uri.pathSegments.length == 1) {
      selectChannel(uri.pathSegments.single);
      return;
    }
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      unawaited(managementLaunch(href));
    } else if (uri != null && isAllowedCustomProtocol(uri)) {
      // Web `MarkdownLink`: an `obsidian://` link asks before it leaves.
      unawaited(openMessageLink(context, href));
    }
  }

  Widget avatar(PublicServerMessage m) => avatarOf(
    author: m.author,
    senderType: m.senderType,
    avatarUrl: m.avatarUrl,
    senderKey: m.senderKey,
  );

  /// A sender's avatar from what the public projection carries (a message, or
  /// a reply of the inline thread preview).
  Widget avatarOf({
    required String author,
    required String senderType,
    required String? avatarUrl,
    required String senderKey,
    RaftMountedAvatarContext avatarContext =
        RaftMountedAvatarContext.panelHeader,
  }) {
    final source = projectSenderAvatar(
      origin: widget.client.origin,
      senderId: senderKey,
      senderType: senderType,
      agents: const [],
      members: const [],
      carriedAvatarUrl: avatarUrl,
    );
    final kind = switch (source.kind) {
      'agent' => RaftAvatarKind.agent,
      'app' => RaftAvatarKind.app,
      _ => RaftAvatarKind.human,
    };
    final identity = switch (kind) {
      RaftAvatarKind.agent => RaftMountedAvatarIdentity.agent,
      RaftAvatarKind.app => RaftMountedAvatarIdentity.app,
      _ => RaftMountedAvatarIdentity.human,
    };
    return RaftAvatar(
      name: author,
      kind: kind,
      mountedContext: avatarContext,
      // Public agents carry no live state: the offline dot Web draws.
      presence: kind == RaftAvatarKind.agent
          ? const RaftAvatarPresence(activity: RaftAvatarActivity.offline)
          : null,
      content: RaftAvatarContent(
        name: author,
        kind: switch (kind) {
          RaftAvatarKind.agent => RaftAvatarContentKind.agent,
          RaftAvatarKind.app => RaftAvatarContentKind.app,
          _ => RaftAvatarContentKind.human,
        },
        uploadedUrl: source.uploadedUrl,
        gravatarUrl: source.gravatarUrl,
        pixelKey: source.pixelKey,
        fallback: RaftMountedAvatarFallback(
          avatarContext: avatarContext,
          gravatar: source.gravatarUrl != null,
          identity: identity,
        ),
      ),
    );
  }

  Widget row(
    PublicServerMessage m, {
    bool thread = false,
    bool parent = false,
    VoidCallback? onThread,
  }) {
    // A main-timeline row with replies draws the badge: its caller must open
    // the thread, or the badge is a dead tap.
    assert(
      parent ||
          thread ||
          m.threadId == null ||
          m.replyCount <= 0 ||
          onThread != null,
      'public row ${m.id} has replies but no onThread',
    );
    final formatter = timeFormatter;
    if (m.messageType == 'system') {
      return RaftSystemMessage(
        key: ValueKey('public-message-${m.id}'),
        content: m.content,
        timestamp: m.createdAt == null
            ? ''
            : formatter.messageTime(m.createdAt),
      );
    }
    // Web useTranslationBatch: auto mode asks for the rows built.
    final store = translations;
    final row = RaftMessage({
      'id': m.id,
      'channelId': thread ? '$threadChannelId' : '$selectedId',
      'content': m.content,
      'senderType': m.senderType,
      'messageType': m.messageType,
    });
    final translation =
        store?.present(row) ?? MessageTranslationPresentation.none;
    if (store != null && translation.needsRequest) store.want(row);
    Widget text(String content) => RaftMessageBody(
      mountedMessage: true,
      messagePipeline: true,
      content: content,
      references: [...channelReferences, ...mentionReferences(m)],
      onLink: openReference,
    );
    return RaftMessageTile(
      key: ValueKey('public-message-${m.id}'),
      rowContext: thread
          ? RaftMessageRowContext.thread
          : RaftMessageRowContext.main,
      author: m.author,
      avatar: avatar(m),
      subtitle: m.description,
      content: translation.translatedContent ?? m.content,
      translation: store == null
          ? null
          : publicTranslationStatus(context, store, row, translation),
      body: translation.skeleton
          ? RaftMessageTranslationSkeleton(
              key: ValueKey('message-translation-placeholder-${m.id}'),
            )
          : !translation.bilingual
          ? text(translation.translatedContent ?? m.content)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                text(translation.translatedContent!),
                RaftMessageTranslationOriginal(
                  key: ValueKey(
                    'message-translation-bilingual-original-${m.id}',
                  ),
                  label: tr('Original'),
                  child: text(m.content),
                ),
              ],
            ),
      attachments: [
        for (final a in m.attachments)
          {'id': a.id, 'filename': a.filename, 'mimeType': a.mimeType},
      ],
      attachmentGallery: m.attachments.isEmpty
          ? null
          : PublicAttachments(attachments: m.attachments, urls: attachmentUrls),
      reactions: [for (final r in m.reactions) r.toRow()],
      threadPreview: !parent && !thread ? inlineReplies(m, onThread) : null,
      timestamp: m.createdAt == null ? '' : formatter.messageTime(m.createdAt),
      threadRepliesBadge:
          !parent &&
              !thread &&
              m.threadId != null &&
              m.replyCount > 0 &&
              inlineReplies(m, onThread) == null
          ? RaftThreadRepliesBadge(
              key: ValueKey('public-thread-open-${m.id}'),
              replyCount: m.replyCount,
              onPressed: onThread,
            )
          : null,
    );
  }

  Widget? get threadPanel {
    final id = threadChannelId;
    if (id == null) return null;
    final parent = messages.where((m) => m.id == threadParentId).firstOrNull;
    if (parent == null) return null;
    final channel = channels.where((c) => c['id'] == selectedId).firstOrNull;
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    // Web ThreadPanel: Escape closes it. Below the panel's own X breakpoint
    // the system back gesture does too (the thread is not a route here).
    return RaftBackDismiss(
      onDismiss: closeThread,
      child: RaftDismissScope(
        onDismiss: closeThread,
        child: RaftPublicThreadPanel(
          title: tr('Thread'),
          channelContext: raftFormat(context, '— #{name}', {
            'name': channel?['name'],
          }),
          closeLabel: tr('Close Thread'),
          onClose: closeThread,
          showClose: wide || RaftInteraction.of(context).pointer,
          parent: row(parent, parent: true),
          replies: [for (final m in threadMessages) row(m, thread: true)],
          loading: threadLoading,
          error: threadError.isEmpty ? null : threadError,
          emptyTitle: tr('No replies yet'),
          scrollController: threadScroll,
          onLoadOlder: threadHasOlder ? loadOlderThread : null,
        ),
      ),
    );
  }

  Widget channelPanel({VoidCallback? onBack}) {
    final channel = channels.where((c) => c['id'] == selectedId).firstOrNull;
    if (channel == null) {
      return RaftPublicEmptyMessage(
        'This server has no public channels right now.',
        hint: false,
        glyph: RaftGlyph.hash,
      );
    }
    final description = channel['description'] as String?;
    return RaftPublicConversationSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftPublicChannelHeader(
            name: '${channel['name']}',
            description: description ?? '',
            onBack: onBack,
            backLabel: tr('Back to channels'),
          ),
          if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(RaftSpace.x3),
              // `<Banner intent="warning" className="m-3 shrink-0">`
              child: RaftErrorBanner(error),
            ),
          Expanded(
            child: messages.isEmpty
                ? loadingMessages
                      ? const RaftPublicLoadingSpinner(label: 'Loading…')
                      : RaftPublicEmptyMessage(
                          'No messages have been posted here yet.',
                          glyph: RaftGlyph.messageSquare,
                        )
                // MessageTimeline sparseAnchor="bottom": a short history sits
                // at the bottom of the panel and the view opens on the latest;
                // older pages load when the top is reached (no button).
                : RaftPublicAutoLoadOlder(
                    reverse: true,
                    controller: timelineScroll,
                    enabled: hasOlder && !loadingMessages,
                    onLoadOlder: loadOlder,
                    child: SingleChildScrollView(
                      key: const ValueKey('public-server-message-timeline'),
                      controller: timelineScroll,
                      reverse: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final m in messages)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: RaftSpace.x3,
                              ),
                              child: RaftPublicMessageRow(
                                child: row(m, onThread: () => openThread(m)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// About (`SettingsPanel` About with `showAboutWorkspace={false}`): the
  /// version and the mobile app, never a workspace.
  Widget about(BuildContext context) {
    final api = widget.client.origin;
    final web = ContentLinks.originFor(api);
    return RaftSettingsAbout(
      version: (widget.appVersion ?? '').isEmpty
          ? 'development'
          : widget.appVersion!,
      mobileApp: RaftAboutMobileApp(
        onAndroid: () => unawaited(
          managementLaunch('$api/api/mobile-download?platform=android'),
        ),
        onIos: () => unawaited(
          managementLaunch('$api/api/mobile-download?platform=ios'),
        ),
        qrUrl: '${web.origin}/download',
      ),
    );
  }

  bool joiningCommunity = false;

  /// Help > Join Community (LeftRail `openCommunity`): joins the default
  /// community server unless already a member (an agreement opens its dialog),
  /// reloads the server list and switches to it. A failure shows in the join
  /// error banner (Web alerts).
  Future<void> openCommunity() async {
    final account = widget.account;
    final settings = account?.settings;
    if (account == null || joiningCommunity) return;
    RaftRecord? community(Iterable<RaftRecord> servers) => servers
        .where((s) => s.string('slug') == communityServerSlug)
        .firstOrNull;
    setState(() {
      joiningCommunity = true;
      joinError = '';
    });
    try {
      var joined = community(account.servers);
      if (joined == null) {
        final accepted = await joinCommunity(
          () => context,
          widget.client,
          communityServerSlug,
        );
        if (!accepted || !mounted) return;
        // The server list the account holds now includes the community.
        if (settings == null ||
            !await settings.controller.loadServerDirectory()) {
          throw const RaftApiException('The server list is unavailable.');
        }
        joined = community(settings.controller.servers);
        if (joined == null) {
          throw const RaftApiException(
            "Joined community server but it's missing from the list",
          );
        }
      }
      if (mounted) account.onSelect(joined);
    } catch (e) {
      if (mounted) {
        setState(
          () => joinError = tr(
            userErrorText(
              e,
              fallback: 'Failed to join community server',
              where: 'community from help',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => joiningCommunity = false);
    }
  }

  /// Opens Settings on [tab] (the rail Help menu's Mobile App / Feedback).
  void openSettingsTab(String tab) => setState(() {
    settingsTab = tab;
    settings = true;
  });

  /// Widths apply only where the columns sit side by side (sm and up).
  bool get sideBySide => raftBreakpointWidth(context) >= 640;

  Widget settingsSurface(Widget banner) {
    final widths = panels;
    return PublicServerSettings(
      tab: settingsTab,
      onTab: (tab) => setState(() => settingsTab = tab),
      about: about,
      documentationUrl: widget.documentationUrl,
      account: widget.account?.settings,
      translationEnabled: translationEnabled,
      localPreferences: localPrefs,
      translations: translations,
      banner: banner,
      sidebarWidth: sideBySide ? widths?.settingsSidebar : null,
      onSidebarResize: widths?.setSettingsSidebar,
      onSidebarResizeEnd: () =>
          unawaited(widths?.persist(PublicPanelWidths.settingsSidebarKey)),
    );
  }

  Widget rail() {
    final name = '${server?['name'] ?? widget.slug}';
    final account = widget.account;
    return RaftPublicRail(
      chatLabel: tr('Chat'),
      settingsLabel: tr('Settings'),
      chatSelected: !settings,
      settingsSelected: settings,
      onChat: () => setState(() => settings = false),
      onSettings: () => setState(() => settings = true),
      header: RaftServerSwitcher(
        controller: menu,
        workspaceName: name,
        label: tr('Switch Server'),
        workspaceAvatarUrl: raftPublicAvatarUrl(
          widget.client.origin,
          server?['avatarUrl'] as String?,
        ),
        rows: [
          if (account != null)
            for (final s in account.servers)
              RaftServerMenuRow(
                id: s.id,
                name: s.name,
                slug: s.string('slug'),
                avatarUrl: s.json['avatarUrl'] as String?,
                onSelected: () => account.onSelect(s),
              ),
        ],
        actions: const [],
      ),
      help: account == null
          ? null
          : RaftWorkspaceHelpMenu(
              key: const ValueKey('public-rail-help'),
              label: tr('Help'),
              heading: tr('Help & resources'),
              entries: [
                RaftMenuEntry(
                  label: tr('Raft Documentation'),
                  leading: const RaftIcon(RaftGlyph.bookOpenText, size: 14),
                  trailing: const RaftIcon(RaftGlyph.arrowUpRight, size: 14),
                  onPressed: () =>
                      unawaited(managementLaunch(widget.documentationUrl)),
                ),
                RaftMenuEntry(
                  label: tr('Mobile App'),
                  glyph: RaftGlyph.smartphone,
                  onPressed: () => openSettingsTab('about'),
                ),
                if (account.settings != null)
                  RaftMenuEntry(
                    label: tr('Feedback'),
                    glyph: RaftGlyph.messageSquare,
                    onPressed: () => openSettingsTab('feedback'),
                  ),
                communityHelpEntry(
                  context,
                  apiOrigin: widget.client.origin,
                  joining: joiningCommunity,
                  join: () => unawaited(openCommunity()),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (server == null && error.isEmpty) {
      return RaftPublicServerLoading(label: tr('Loading server…'));
    }
    final name = '${server?['name'] ?? widget.slug}';
    final band = raftBreakpointWidth(context);
    final thread = settings ? null : threadPanel;
    final message = authenticated
        ? canJoin
              ? 'Join {server} as a Guest to be part of the discussion.'
              : "{server} is view only. You can read its public channels, but can't send messages here."
        : canJoin
        ? 'Sign in to join {server} and be part of the discussion.'
        : '{server} is view only. Create a Raft account to build a server of your own.';
    final actions = authenticated
        ? [
            if (canJoin)
              RaftPublicActionButton(
                key: const ValueKey('public-join-guest'),
                label: tr('Join as Guest'),
                glyph: RaftGlyph.userPlus,
                accent: true,
                onPressed: joining ? null : startJoin,
              ),
          ]
        : [
            RaftPublicActionButton(
              label: tr('Sign In'),
              glyph: RaftGlyph.logIn,
              accent: canJoin,
              onPressed: widget.onSignIn,
            ),
            RaftPublicActionButton(
              label: tr('Create Account'),
              glyph: RaftGlyph.userPlus,
              accent: !canJoin,
              onPressed: widget.onRegister,
            ),
          ];
    final widths = panels;
    final sm = band >= 640;
    final bottom = RaftPublicBottomBanner(
      message: raftFormat(context, message, {'server': name}),
      actions: actions,
    );
    final phoneList = !sm && !phoneChannel;
    final sidebar = RaftPublicChannelSidebar(
      serverName: name,
      channels: [
        for (final c in channels)
          RaftPublicServerChannel(id: '${c['id']}', name: '${c['name']}'),
      ],
      selectedId: selectedId,
      onSelect: selectChannel,
      label: tr('Public channels'),
      width: widths?.channelSidebar,
      fill: phoneList,
    );
    // The banner sits under the conversation (and the thread) only, so the
    // channel column runs the full height beside it (Web v1.21.23 grid); on
    // phones it spans the page and the thread panel stops above it.
    final main = RaftPublicSurface(
      child: channelPanel(onBack: sm ? null : showChannelList),
    );
    final Widget columns;
    if (settings) {
      columns = settingsSurface(bottom);
    } else if (!sm) {
      columns = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [phoneList ? sidebar : main, ?thread],
            ),
          ),
          bottom,
        ],
      );
    } else {
      columns = Stack(
        fit: StackFit.expand,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              sidebar,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: main),
                              if (thread != null)
                                RaftPublicThreadColumn(
                                  width: widths?.thread,
                                  child: thread,
                                ),
                            ],
                          ),
                          // PanelResizeHandle: an 8px strip centred on the
                          // thread's left edge (`-left-1`).
                          if (widths != null && thread != null)
                            Positioned(
                              right:
                                  widths.thread -
                                  RaftPanelResizeHandle.hitExtent / 2,
                              top: 0,
                              bottom: 0,
                              width: RaftPanelResizeHandle.hitExtent,
                              child: RaftPanelResizeHandle(
                                key: const ValueKey(
                                  'public-server-thread-panel-resize-handle',
                                ),
                                label: tr('Resize thread'),
                                value: widths.thread,
                                reversed: true,
                                hairline: true,
                                onChangeStart: () => widths.beginThreadResize(
                                  MediaQuery.sizeOf(context).width,
                                ),
                                onChanged: widths.setThread,
                                onChangeEnd: () => unawaited(
                                  widths.persist(PublicPanelWidths.threadKey),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    bottom,
                  ],
                ),
              ),
            ],
          ),
          // The channel column's handle: an 8px strip centred on its right
          // edge (`-right-1`), over the full height.
          if (widths != null)
            Positioned(
              left: widths.channelSidebar - RaftPanelResizeHandle.hitExtent / 2,
              top: 0,
              bottom: 0,
              width: RaftPanelResizeHandle.hitExtent,
              child: RaftPanelResizeHandle(
                key: const ValueKey(
                  'public-server-channel-sidebar-resize-handle',
                ),
                label: tr('Resize sidebar'),
                value: widths.channelSidebar,
                hairline: true,
                onChanged: widths.setChannelSidebar,
                onChangeEnd: () => unawaited(
                  widths.persist(PublicPanelWidths.channelSidebarKey),
                ),
              ),
            ),
        ],
      );
    }
    // Phones show one column at a time: system back leaves a channel for the
    // channel list (an open thread closes first, through its own back entry).
    return PopScope(
      canPop: sm || settings || !phoneChannel || thread != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) showChannelList();
      },
      child: RaftPublicServerLayout(
        rail: band >= 768 && server != null ? rail() : null,
        columns: columns,
        overlays: [
          // The sign-in prompt is only true for a visitor who is not signed in.
          if (selectionNotice && !authenticated)
            RaftPublicFloatingBanner(
              key: const ValueKey('public-server-selection-notice'),
              top: true,
              message: tr(
                'You are viewing public channels without signing in. Sign in or create an account to continue in Raft.',
              ),
              action: RaftSettingsRecipeButton(
                label: tr('Sign In'),
                size: RaftButtonRecipeSize.xs,
                onPressed: widget.onSignIn,
              ),
            ),
          if (joinError.isNotEmpty)
            RaftPublicFloatingBanner(
              key: const ValueKey('public-server-join-error'),
              top: false,
              warning: true,
              message: joinError,
            ),
        ],
      ),
    );
  }
}
