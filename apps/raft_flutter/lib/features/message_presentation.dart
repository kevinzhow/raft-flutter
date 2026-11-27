import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/raft_location.dart';
import '../data/source_time_formatter.dart';
import '../data/user_error.dart';

import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'artifacts/artifact_message_links.dart';
import 'app_link_view.dart';
import 'message_card_read.dart';
import 'web_link_open.dart';
import 'resource_cards.dart' show resourceRelativeTime;

import '../data/workspace_controller.dart';
import '../platform/attachment_files.dart';
import '../platform/raft_deployment_links.dart';
import 'foreign_permalink.dart';
import 'chat_navigation.dart';
import 'message_action_card.dart';
import 'attachment_view.dart';
import 'private_route_guard.dart';
import 'profile_preview.dart';
import 'qualified_task_navigation.dart';
import 'composer_directory.dart' show cachedExternalMembers;
import 'external_mentions.dart';
import 'agent_read_badge.dart';
import 'forwarded_source.dart';

/// Full MessageDTO uses `user`; legacy/native human rows use `human`.
/// Presentation consumers use one identity kind without altering transport data.
String? messageSenderIdentityKind(RaftMessage message) =>
    switch (message.string('senderType')) {
      'user' || 'human' => 'human',
      'agent' => 'agent',
      _ => null,
    };

/// Web `message.externalAuthor?.provider ?? null` for an
/// `external_projection` sender (MessageItem.tsx senderSubtitle); null for any
/// other sender or a missing/blank provider.
String? externalSenderSubtitle(RaftMessage message) {
  if (message.string('senderType') != 'external_projection') return null;
  final author = message.json['externalAuthor'];
  final provider = author is Map ? author['provider'] : null;
  return provider is String && provider.isNotEmpty ? provider : null;
}

final _dmReference = RegExp(
  r'dm:@([\w.-]+(?:~(?:agent|human))?)(?::([a-f0-9]{6,8}))?',
  caseSensitive: false,
);
final _threadReference = RegExp(
  r'#([\p{L}\p{N}_-]+):([a-f0-9]{6,8})',
  unicode: true,
  caseSensitive: false,
);
final _messageReference = RegExp(
  r'#([\p{L}\p{N}_-]+)(?::[a-f0-9]{6,8})?\s+msg=([A-Za-z0-9][A-Za-z0-9-]{1,63})',
  unicode: true,
);

final _referencesMemo = RaftLruCache<_ReferenceInputs, List<RaftTextReference>>(
  1024,
);

// The authority projection replaces its lists on change. Weak indexes avoid
// retaining a retired server's directory beyond the existing bounded memo.
final _directoryTextIndexes = Expando<_ReferenceTextIndex>();
final _channelTextIndexes = Expando<_ReferenceTextIndex>();
final _noWebPreviewChanges = Listenable.merge(const []);

class _ReferenceTextNode {
  final children = <int, _ReferenceTextNode>{};
  final terminals = <int>[];
}

// A prefix tree searches only at a possible reference start, instead of
// scanning a long message once for every person/channel in the directory.
// Every terminal is retained, including overlapping names and duplicate text.
class _ReferenceTextIndex {
  _ReferenceTextIndex(this.sourceLength, this.references) {
    for (var i = 0; i < references.length; i++) {
      var node = root;
      for (final unit in references[i].text.codeUnits) {
        node = node.children.putIfAbsent(unit, _ReferenceTextNode.new);
      }
      node.terminals.add(i);
    }
  }
  final int sourceLength;
  final List<RaftTextReference> references;
  final root = _ReferenceTextNode();

  Iterable<RaftTextReference> matching(String content) sync* {
    final found = <int>{...root.terminals};
    for (final prefix in root.children.keys) {
      final start = String.fromCharCode(prefix);
      var offset = content.indexOf(start);
      while (offset >= 0) {
        var node = root;
        for (var i = offset; i < content.length; i++) {
          final next = node.children[content.codeUnitAt(i)];
          if (next == null) break;
          node = next;
          found.addAll(node.terminals);
        }
        offset = content.indexOf(start, offset + 1);
      }
    }
    // Keep projection order: later duplicate entries win as before.
    for (final i in found.toList()..sort()) {
      yield references[i];
    }
  }
}

/// Everything [MessagePresentation.references] reads. Lists compare by
/// identity (the controller and directory replace them on change) and by
/// length, which also catches an in-place removal.
@immutable
class _ReferenceInputs {
  _ReferenceInputs(MessagePresentation p)
    : messageId = p.message.id,
      content = p.text,
      mentions = p.message.json['mentions'],
      localAuthority = p.localAuthority,
      externals = p.externalMembers,
      directory = p.directoryReferences,
      channels = p.controller.channels,
      channelCount = p.controller.channels.length,
      dms = p.controller.dms,
      dmCount = p.controller.dms.length;
  final String messageId, content;
  final Object? mentions;
  final List<Map<String, dynamic>> externals;
  final bool localAuthority;
  final List<RaftTextReference> directory;
  final List<RaftChannel> channels, dms;
  final int channelCount, dmCount;
  @override
  bool operator ==(Object other) =>
      other is _ReferenceInputs &&
      other.messageId == messageId &&
      other.content == content &&
      identical(other.mentions, mentions) &&
      other.localAuthority == localAuthority &&
      identical(other.externals, externals) &&
      identical(other.directory, directory) &&
      identical(other.channels, channels) &&
      other.channelCount == channelCount &&
      identical(other.dms, dms) &&
      other.dmCount == dmCount;
  @override
  int get hashCode => Object.hash(
    messageId,
    content,
    identityHashCode(mentions),
    localAuthority,
    identityHashCode(externals),
    identityHashCode(directory),
    identityHashCode(channels),
    channelCount,
    identityHashCode(dms),
    dmCount,
  );
}

/// Resolves message references only in the current authority. Structured
/// mention IDs survive renamed handles; unknown references preserve raw text.
class MessagePresentation extends StatelessWidget {
  const MessagePresentation({
    super.key,
    required this.controller,
    required this.message,
    required this.onExternalLink,
    this.fontSize = 14,
    this.directoryReferences = const [],
    this.exportMode = false,
    this.exportAttachmentBuilder,
    this.taskByNumber,
    this.knownTaskNumber,
    this.content,
    this.foregroundColor,
    this.searchHighlight,
    this.unavailablePermalink,
    this.onOpenTask,
    this.navigation,
  });

  /// Web `onOpenTaskRef`: an in-body `#N` / `task #N` reference opens the task
  /// slot (the same surface as the footer task chip). A host with no task slot
  /// (the exported image, previews) falls back to a read-only summary dialog.
  final ValueChanged<Map<String, dynamic>>? onOpenTask;

  /// The raw URL of the message permalink whose preview could not be read
  /// (Web `unavailableQuotedPermalinkUrl`): its chip reads "Unavailable linked
  /// message" and is inert.
  final String? unavailablePermalink;

  /// Web `threadSearchHighlightQuery`: the in-thread search query marked in
  /// the active match's text.
  final String? searchHighlight;

  /// Markdown shown instead of the message's own content (a translation, or
  /// the bilingual view's original under it).
  final String? content;
  final Color? foregroundColor;
  String get text => content ?? message.content;

  /// Loaded task for an in-body `#N` reference (Web `taskByNumber`); null
  /// when unknown.
  final Map<String, dynamic>? Function(int number)? taskByNumber;

  /// A linked task can supply a status without entering Web's known bare-task
  /// directory. Explicit `task #N` still resolves through [taskByNumber].
  final bool Function(int number)? knownTaskNumber;
  final WorkspaceController controller;
  final ChatNavigation? navigation;
  final RaftMessage message;
  final ValueChanged<String> onExternalLink;
  final double fontSize;
  final bool exportMode;
  final Widget Function(Map<String, dynamic>)? exportAttachmentBuilder;
  final List<RaftTextReference> directoryReferences;
  bool get localAuthority =>
      message.string('senderType') != 'external_projection' &&
      (message.json['sourceServerId'] == null ||
          message.json['sourceServerId'] == controller.server?.id);

  /// Memoised per message text and the identity of every projection it
  /// reads, so scrolling a row back into view or rebuilding it for an
  /// unrelated change does not rescan the directories.
  List<RaftTextReference> get references =>
      _referencesMemo.putIfAbsent(_ReferenceInputs(this), () => _references);

  static final _possibleProseLink = RegExp(
    r'[@#:<\[\uE000]|www\.',
    caseSensitive: false,
  );

  List<List<RaftMessageSemanticsLink>> get proseSemanticsLinks =>
      _possibleProseLink.hasMatch(text)
      ? RaftMessageBody.semanticsLinkGroups(
          text,
          references: references,
          taskHref: taskReferenceHref,
          knownTaskNumber: knowsTaskNumber,
        )
      : const [];

  String Function(int)? get taskReferenceHref => localAuthority
      ? (number) => Uri(
          scheme: 'raft-ref',
          host: 'task',
          pathSegments: ['$number'],
        ).toString()
      : null;

  bool Function(int)? get knowsTaskNumber =>
      knownTaskNumber ??
      (taskByNumber == null ? null : (number) => taskByNumber!(number) != null);

  List<RaftTextReference> get _references {
    if (!localAuthority) return [];
    final content = text;
    // Only references whose text occurs in this message can match; building
    // one per channel/member for every row made each new row cost ~1ms.
    var directoryIndex = _directoryTextIndexes[directoryReferences];
    if (directoryIndex == null ||
        directoryIndex.sourceLength != directoryReferences.length) {
      directoryIndex = _ReferenceTextIndex(
        directoryReferences.length,
        directoryReferences,
      );
      _directoryTextIndexes[directoryReferences] = directoryIndex;
    }
    final refs = {
      for (final ref in directoryIndex.matching(content)) ref.text: ref,
    };
    final hasHash = content.contains('#');
    final channels = hasHash
        ? controller.channels.where((c) => !c.archived).toList()
        : const <RaftChannel>[];
    String href(String kind, List<String> parts) =>
        Uri(scheme: 'raft-ref', host: kind, pathSegments: parts).toString();
    if (hasHash) {
      var channelIndex = _channelTextIndexes[controller.channels];
      if (channelIndex == null ||
          channelIndex.sourceLength != controller.channels.length) {
        channelIndex = _ReferenceTextIndex(controller.channels.length, [
          for (final c in channels)
            RaftTextReference(
              text: '#${c.string('name')}',
              href: href('channel', [c.id]),
            ),
        ]);
        _channelTextIndexes[controller.channels] = channelIndex;
      }
      for (final ref in channelIndex.matching(content)) {
        refs[ref.text] = ref;
      }
    }
    for (final m
        in content.contains('dm:@')
            ? _dmReference.allMatches(content)
            : const <RegExpMatch>[]) {
      final c = resolveMessageDmReference(controller.dms, m[1]!);
      if (c == null) continue;
      refs[m[0]!] = RaftTextReference(
        text: m[0]!,
        href: m[2] == null
            ? href('channel', [c.id])
            : href('thread', [c.id, m[2]!]),
      );
    }
    for (final m
        in hasHash
            ? _threadReference.allMatches(content)
            : const <RegExpMatch>[]) {
      final c = channels
          .where((c) => c.string('name').toLowerCase() == m[1]!.toLowerCase())
          .firstOrNull;
      if (c != null) {
        refs[m[0]!] = RaftTextReference(
          text: m[0]!,
          href: href('thread', [c.id, m[2]!]),
        );
      }
    }
    for (final m
        in hasHash && content.contains('msg=')
            ? _messageReference.allMatches(content)
            : const <RegExpMatch>[]) {
      final c = channels.where((c) => c.string('name') == m[1]).firstOrNull;
      if (c != null) {
        refs[m[0]!] = RaftTextReference(
          text: m[0]!,
          href: href('message', [c.id, m[2]!]),
        );
      }
    }
    for (final m
        in (message.json['mentions'] as List? ?? []).whereType<Map>()) {
      if (m['name'] is String &&
          m['id'] is String &&
          ['agent', 'user', 'external'].contains(m['type'])) {
        final mention = href('mention', ['${m['type']}', '${m['id']}']);
        refs['@${m['name']}'] = RaftTextReference(
          text: '@${m['name']}',
          identityBacked: true,
          href: mention,
          label: directoryReferences
              .where((r) => r.href == mention)
              .firstOrNull
              ?.label,
        );
      }
    }
    for (final task in qualifiedTaskLinks(controller, content)) {
      refs[task.text] = task;
    }
    return refs.values.toList();
  }

  List<Map<String, dynamic>> get externalMembers =>
      (message.json['mentions'] as List? ?? const []).whereType<Map>().any(
        (m) => m['type'] == 'external',
      )
      ? cachedExternalMembers(controller, message.channelId)
      : const [];

  Map<String, dynamic>? externalMember(String id) =>
      externalMembers.where((member) => member['id'] == id).firstOrNull;

  /// Prepares this message's text using only accepted local projections.
  void prepareCache(RaftTokens tokens) => RaftMessageBody.prepareCache(
    content: text,
    tokens: tokens,
    messagePipeline: true,
    references: references,
    fontSize: fontSize,
    taskHref: localAuthority
        ? (n) => Uri(
            scheme: 'raft-ref',
            host: 'task',
            pathSegments: ['$n'],
          ).toString()
        : null,
    knownTaskNumber:
        knownTaskNumber ??
        (taskByNumber == null ? null : (n) => taskByNumber!(n) != null),
  );

  /// Resolves local references before sending pure parser inputs to a worker.
  RaftMessageBodyRequest bodyRequest(RaftTokens tokens) =>
      RaftMessageBodyRequest(
        content: text,
        tokens: tokens,
        references: references,
        fontSize: fontSize,
        taskHref: localAuthority
            ? (n) => Uri(
                scheme: 'raft-ref',
                host: 'task',
                pathSegments: ['$n'],
              ).toString()
            : null,
        knownTaskNumber:
            knownTaskNumber ??
            (taskByNumber == null ? null : (n) => taskByNumber!(n) != null),
      );

  /// [plain]: a card button that isn't `beside` (Web: a plain new tab), which
  /// the web-link choice (Settings › How web links open) doesn't apply to.
  Future<void> open(
    BuildContext context,
    String href, {
    bool plain = false,
  }) async {
    if (navigation?.current() == false) return;
    final uri = Uri.tryParse(href);
    if (uri?.scheme != 'raft-ref') {
      // Web handleOpenPermalink: a message link of this server opens in the
      // app, any other link opens externally.
      final link = permalinkDeployment.parse(href);
      if (link != null &&
          localAuthority &&
          !exportMode &&
          await openPermalinkInApp(
            context,
            controller,
            link,
            openLocal: navigation?.openPermalink,
          )) {
        return;
      }
      // Web openArtifactOnPlainClick: an Artifact of this server opens in
      // the viewer (workspace_artifacts_v0).
      if (localAuthority &&
          !exportMode &&
          context.mounted &&
          openArtifactMessageLink(context, controller, href)) {
        return;
      }
      if (!plain &&
          localAuthority &&
          !exportMode &&
          context.mounted &&
          await openWebLinkByPreference(
            context,
            controller,
            href,
            conversationId: message.channelId,
            openExternal: onExternalLink,
          )) {
        return;
      }
      onExternalLink(href);
      return;
    }
    if (!localAuthority) return;
    final w = controller, authority = workspaceAuthority(controller);
    bool current() =>
        context.mounted &&
        authority == workspaceAuthority(w) &&
        (navigation?.current() ?? true);
    try {
      final parts = uri!.pathSegments;
      if (uri.host == 'channel' && parts.length == 1) {
        final channel = [
          ...w.channels,
          ...w.dms,
        ].where((c) => c.id == parts[0]).firstOrNull;
        if (channel != null) {
          await (navigation?.navigate(
                (host) => host.jumpToMessage(channel.id, null),
              ) ??
              w.selectChannel(channel));
        }
        return;
      }
      if (uri.host == 'message' && parts.length == 2) {
        await navigate((host) => host.jumpToMessage(parts[0], parts[1]));
        return;
      }
      if (uri.host == 'mention' &&
          parts.length == 2 &&
          parts[0] == 'external') {
        final member = externalMember(parts[1]);
        if (member != null) {
          openProfile(
            RaftProfileKind.external,
            '${member['id']}',
            channelId: externalMentionChannelId(w, message.channelId),
            externalAuthor: externalMentionAuthor(member),
          );
        }
        return;
      }
      // Web MentionLink: the mention opens the member / agent profile panel.
      if (uri.host == 'mention' &&
          parts.length == 2 &&
          ['agent', 'user'].contains(parts[0])) {
        openProfile(
          parts[0] == 'agent' ? RaftProfileKind.agent : RaftProfileKind.human,
          parts[1],
        );
        return;
      }
      if (uri.host == 'thread' && parts.length == 2) {
        // A message this device already holds in that channel is its own
        // canonical target: jump at once instead of resolving it first.
        if (w.messageDomain.visibleIds[parts[0]]?.contains(parts[1]) == true &&
            w.messageDomain.ledger
                .messages(parts[0])
                .any((row) => row['id'] == parts[1])) {
          await navigate((host) => host.jumpToMessage(parts[0], parts[1]));
          return;
        }
        final resolved = await w.query(
          '/messages/context/${parts[1]}',
          query: {'channelId': parts[0]},
        );
        if (!context.mounted || !current()) return;
        final target = resolved['canonicalTarget'];
        final id =
            resolved['targetMessageId'] ??
            (target is Map
                ? target['messageId'] ?? target['threadParentMessageId']
                : null);
        if (id is String) {
          await navigate(
            (host) => host.jumpToMessage(
              target is Map ? target['channelId'] ?? parts[0] : parts[0],
              id,
            ),
          );
        } else {
          throw const RaftApiException('This thread is no longer available.');
        }
        return;
      }
      if (uri.host != 'task' ||
          (parts.length != 1 && parts.length != 2) ||
          message.channelId.isEmpty) {
        return;
      }
      final qualified = parts.length == 2;
      final number = int.tryParse(parts.last);
      if (number == null) return;
      final carrier = qualified
          ? w.channelById(parts.first)?.id
          : messageParentChannelId(message.json) ?? w.channel?.id;
      if (carrier == null) return;
      // The loaded channel tasks already know this task: open it from them
      // (the task surface revalidates its own copy).
      final local = qualified ? null : taskByNumber?.call(number);
      if (local != null && onOpenTask != null) {
        onOpenTask!(Map<String, dynamic>.from(local));
        return;
      }
      Future<Map<String, dynamic>> fetch() =>
          readTaskReference(w, carrier, number);

      if (onOpenTask != null) {
        // No task row to open the task surface with yet.
        final task = await fetch();
        if (current()) {
          if (qualified) {
            openQualifiedTaskSurface(
              w,
              task,
              onOpenTask!,
              navigation: navigation,
            );
          } else {
            onOpenTask!(task);
          }
        }
        return;
      }
      // The dialog opens at once with what is loaded (or a skeleton) and fills
      // in when the task arrives.
      final data = ValueNotifier<Map<String, dynamic>?>(
        local == null ? null : Map<String, dynamic>.from(local),
      );
      String headingOf(Map<String, dynamic>? task) => task == null
          ? 'task #$number'
          : 'task #$number · ${task['title'] ?? ''}';
      if (!context.mounted) return;
      final navigator = Navigator.of(context);
      final shown = showRaftDialog<void>(
        context: context,
        builder: (ctx) => ValueListenableBuilder<Map<String, dynamic>?>(
          valueListenable: data,
          builder: (ctx, task, _) => mentionDialog(
            ctx,
            headingOf(task),
            task ?? const {},
            current,
            loading: task == null,
          ),
        ),
      );
      var closed = false;
      unawaited(shown.whenComplete(() => closed = true));
      try {
        data.value = await fetch();
      } catch (e) {
        if (!closed && data.value == null && navigator.canPop()) {
          navigator.pop();
        }
        if (current() && context.mounted) {
          showRaftToast(
            context,
            userErrorText(
              e,
              fallback:
                  'Unable to open source. It may be unavailable or deleted.',
              where: 'open task reference',
            ),
          );
        }
      }
      await shown;
      data.dispose();
    } catch (e) {
      // Web MessageItem `showThreadRefNotice`: `toast.error(threadUnavailable)`.
      if (current() && context.mounted) {
        showRaftToast(
          context,
          userErrorText(
            e,
            fallback:
                'Unable to open thread. It may be unavailable or deleted.',
            where: 'open reference',
          ),
        );
      }
    }
  }

  Future<void> navigate(Future<void> Function(WorkspaceController) action) =>
      navigation?.navigate(action) ?? action(controller);

  ChatProfileOpener get openProfile =>
      navigation?.openProfile ?? controller.openProfile;

  Widget mentionDialog(
    BuildContext ctx,
    String title,
    Map<String, dynamic> data,
    bool Function() current, {
    bool loading = false,
  }) {
    return RaftAlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) const RaftSkeletonRow(),
              if (data['description'] is String)
                RaftMessageBody(
                  content: data['description'],
                  onLink: onExternalLink,
                ),
              if (data['status'] is String)
                Text(
                  raftFormat(ctx, 'Status: {status}', {
                    'status': raftText(
                      ctx,
                      raftTaskStatusVocabulary.contains(data['status'])
                          ? raftTaskStatusLabel(data['status'])
                          : data['status'],
                    ),
                  }),
                ),
              if (data['claimedByName'] is String)
                Text(
                  raftFormat(ctx, 'Assignee: {name}', {
                    'name': data['claimedByName'],
                  }),
                ),
              if (data['role'] is String)
                Text(raftText(ctx, '${data['role']}')),
              if (data['taskNumber'] != null && data['messageId'] is String)
                RaftButton(
                  label: 'Open Message',
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (current()) {
                      await navigate(
                        (host) => host.jumpToMessage(
                          data['channelId'],
                          data['messageId'],
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        RaftButton.text(
          onPressed: () => Navigator.pop(ctx),
          child: Text(raftText(ctx, 'Close')),
        ),
      ],
    );
  }

  Future<void> saveDiagram(
    BuildContext context,
    String extension,
    Uint8List bytes,
  ) async {
    final w = controller;
    final authority = workspaceAuthority(w);
    final originalContent = message.content;
    bool current() {
      if (!context.mounted ||
          workspaceAuthority(w) != authority ||
          w.server?.id != w.client.serverId) {
        return false;
      }
      final visible = <RaftMessage>[
        ...w.messageDomain.messages,
        ...w.replies,
        if (w.messageDomain.state.threadParent != null)
          w.messageDomain.state.threadParent!,
      ];
      return visible.any(
        (m) => m.id == message.id && m.content == originalContent,
      );
    }

    if (!current() || !['mmd', 'png', 'svg'].contains(extension)) return;
    try {
      await AttachmentFiles().saveBytes(
        bytes: bytes,
        filename: 'diagram.$extension',
        mimeType: switch (extension) {
          'png' => 'image/png',
          'svg' => 'image/svg+xml',
          _ => 'text/plain',
        },
        authorized: current,
      );
    } catch (_) {
      // ignore: raft_lints/avoid_imperative_notice_state -- Workspace-level w.error is shown once as a toast by workspace_view.syncWorkspaceError and cleared there (self-dismissing).
      if (current()) w.setError('Could not export diagram.');
    }
  }

  String Function(DateTime) forwardedTimestamp(BuildContext context) {
    final user = controller.client.user;
    final formatter = SourceTimeFormatter(
      locale: Localizations.localeOf(context).toLanguageTag(),
      preferredTimezone:
          user?.string('preferredTimezone') ?? user?.string('timezone'),
      preferredTimeFormat: sourceTimeFormatPreference(
        user?.string('preferredTimeFormat') ?? user?.string('timeFormat'),
      ),
      systemTimeFormat: MediaQuery.alwaysUse24HourFormatOf(context)
          ? SourceTimeFormat.twentyFourHour
          : null,
    );
    return formatter.shortDateTime;
  }

  @override
  Widget build(BuildContext context) {
    // RFC 077: a retracted message keeps its place; its body is the muted
    // placeholder, never body text.
    if (message.retracted) {
      final t = RaftTokens.of(context);
      return Text(
        raftText(context, 'This message was retracted.'),
        key: ValueKey('message-retracted-${message.id}'),
        style: DefaultTextStyle.of(context).style
            .copyWith(color: t.ui.foregroundHint),
      );
    }
    final card = readMessageCard(message.json['actionMetadata']);
    if (card != null) return messageCard(context, card);
    if (message.json['actionMetadata'] is Map &&
        message.json['actionMetadata']['kind'] == 'action-card') {
      return MessageActionCard(
        controller: controller,
        message: message,
        exportMode: exportMode,
      );
    }
    if (message.json['actionMetadata'] is Map &&
        message.json['actionMetadata']['kind'] == 'forwarded-bundle') {
      final host = navigation?.workspace ?? controller;
      final card = RaftForwardedBundle(
        key: ValueKey('forwarded-${message.id}'),
        metadata: Map<String, dynamic>.from(message.json['actionMetadata']),
        exportMode: exportMode,
        // Web ForwardedBundleCard: useTimeFormatter().formatShortDateTime
        // ("Jun 22, 10:30 AM") in the account's zone and hour cycle.
        formatTimestamp: forwardedTimestamp(context),
        canOpenSource: (item) => ForwardedSource.read(host, item) != null,
        onOpenSource: exportMode || !localAuthority
            ? null
            : (item) {
                final source = ForwardedSource.read(host, item);
                if (source != null) {
                  unawaited(
                    navigate(
                      (owner) => openForwardedSource(context, owner, source),
                    ),
                  );
                }
              },
        attachmentBuilder:
            exportAttachmentBuilder ??
            (metadata) => AttachmentView(
              key: ValueKey(
                'forwarded-attachment-${message.id}-${metadata['id']}',
              ),
              controller: controller,
              metadata: metadata,
              messageId: message.id,
              exportMode: exportMode,
            ),
      );
      final note = forwardedNote(message.json['actionMetadata'], text);
      if (note.isEmpty) return card;
      // Web MessageItem: the forwarding note is the message body, above the card.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          body(context, content: note),
          card,
        ],
      );
    }
    return body(context);
  }

  /// A card message (RFC 082): the card instead of its fallback text.
  Widget messageCard(BuildContext context, ReadMessageCard card) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    String relative(DateTime at) =>
        resourceRelativeTime(at.toIso8601String(), locale: locale);
    final updatedAt = card.updatedAt;
    Widget cardOf({bool interactive = false}) => RaftMessageCard(
      key: ValueKey('message-card-${message.id}'),
      header: card.header,
      root: card.root,
      updated: card.revision > 1 && updatedAt != null
          ? raftFormat(context, 'Updated {time}', {'time': relative(updatedAt)})
          : null,
      relativeTime: relative,
      duration: (start, end) {
        final seconds = ((end ?? DateTime.now()).difference(start).inSeconds)
            .clamp(0, 1 << 31);
        final minutes = seconds ~/ 60;
        if (seconds < 60) {
          return raftFormat(context, '{seconds}s', {'seconds': seconds});
        }
        if (minutes < 60) {
          return raftFormat(context, '{minutes}m {seconds}s', {
            'minutes': minutes,
            'seconds': seconds % 60,
          });
        }
        return raftFormat(context, '{hours}h {minutes}m', {
          'hours': minutes ~/ 60,
          'minutes': minutes % 60,
        });
      },
      onOpen: exportMode ? null : (href) => open(context, href),
      onOpenButton: exportMode || !localAuthority
          ? null
          : (button) {
              if (!openCardButtonBeside(
                controller,
                button,
                conversationId: message.channelId,
              )) {
                unawaited(open(context, button.url, plain: true));
              }
            },
      opensBeside: interactive
          ? (button) => cardButtonOpensBeside(controller, button)
          : null,
      onExternalButtonFor: interactive
          ? (button) => _externalWebLink(button.url)
          : null,
    );
    final buttons = exportMode || !localAuthority
        ? const <RaftCardButton>[]
        : raftCardButtons(card.root);
    final availability = buttons.isEmpty
        ? null
        : webPreviewAvailability(
            controller,
            evaluate: buttons.any((button) => button.beside),
          );
    return ListenableBuilder(
      listenable: availability ?? _noWebPreviewChanges,
      builder: (_, _) => cardOf(interactive: availability != null),
    );
  }

  Widget body(BuildContext context, {String? content}) {
    final shown = content ?? text;
    final body =
        !exportMode &&
            localAuthority &&
            mayReadAppLinks(message.content, controller)
        ? AppLinkMessageView(
            workspace: controller,
            message: message,
            visibleContent: shown,
            openBrowser: onExternalLink,
            body: (inline, afterBlock, revision) => _body(
              context,
              content: content,
              inline: inline,
              afterBlock: afterBlock,
              revision: revision,
            ),
          )
        : _body(context, content: content);
    // Web ArtifactMessageRefs in the embedded slot: the cards for the
    // Artifacts the text links to.
    if (exportMode || !localAuthority || !mayLinkArtifacts(shown)) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        body,
        ArtifactLinkCards(controller: controller, content: shown),
      ],
    );
  }

  Widget _body(
    BuildContext context, {
    String? content,
    Widget? Function(BuildContext, String)? inline,
    Widget? Function(BuildContext, String)? afterBlock,
    Object? revision,
  }) {
    Widget body({bool browserLinks = false}) => RaftMessageBody(
      mountedMessage: true,
      messagePipeline: true,
      // A compact timeline row already announces this text in its label.
      compactSemantics: RaftMessageSemanticsScope.maybeOf(context) != null,
      content: content ?? text,
      foregroundColor: foregroundColor,
      searchHighlight: searchHighlight,
      exportMode: exportMode,
      fontSize: fontSize,
      onExportDiagram: exportMode
          ? null
          : (extension, bytes) => saveDiagram(context, extension, bytes),
      references: references,
      taskHref: taskReferenceHref,
      onLink: exportMode ? null : (href) => open(context, href),
      webLinkActions: !browserLinks
          ? null
          : (href) {
              final external = _externalWebLink(href);
              return external == null
                  ? null
                  : (
                      openExternal: external,
                      openMenu: (position) => unawaited(
                        showDesktopWebLinkMenu(
                          context,
                          controller,
                          href,
                          message.channelId,
                          position,
                          external,
                        ),
                      ),
                    );
            },
      knownTaskNumber: knowsTaskNumber,
      referenceAppearance: appearance,
      permalinkAppearance: (href) => permalinkAppearance(context, href),
      inlineLinkBuilder: inline,
      afterLinkBlockBuilder: afterBlock,
      permalinkKey: Object.hash(
        revision,
        unavailablePermalink,
        controller.channels.length,
        controller.dms.length,
        browserLinks,
        // The read markers on agent mentions follow the channel's frontiers.
        controller.readReceipts.scope(message.channelId),
      ),
    );
    final changes = exportMode || !localAuthority
        ? null
        : desktopBrowserLinkChanges(controller, message.channelId);
    return ListenableBuilder(
      listenable: changes ?? _noWebPreviewChanges,
      builder: (_, _) => body(
        browserLinks: changes != null && desktopBrowserLinksEnabled(controller),
      ),
    );
  }

  VoidCallback? _externalWebLink(String href) =>
      !exportMode &&
          localAuthority &&
          desktopBrowserLinkAvailable(controller, href, message.channelId)
      ? () {
          if (navigation?.current() != false) onExternalLink(href);
        }
      : null;

  RaftDeploymentLinks get permalinkDeployment =>
      RaftDeploymentLinks.of(controller.client);

  /// Web MessageItem markdown `a` renderer for Raft permalinks: a Link chip
  /// labelled with the channel (or "linked message"), inert once unavailable.
  RaftReferenceAppearance? permalinkAppearance(
    BuildContext context,
    String href,
  ) {
    if (exportMode || !localAuthority) return null;
    final link = permalinkDeployment.parse(href);
    if (link == null) return null;
    final raw = unavailablePermalink == null
        ? null
        : permalinkDeployment.parse(unavailablePermalink!);
    if (raw != null && raw == link) {
      return RaftReferenceAppearance(
        RaftReferenceKind.permalinkUnavailable,
        label: raftText(context, 'Unavailable linked message'),
      );
    }
    final channel = [
      ...controller.channels,
      ...controller.dms,
    ].where((c) => c.id == link.channelId).firstOrNull;
    return RaftReferenceAppearance(
      RaftReferenceKind.permalink,
      label: channel == null
          ? raftText(context, 'linked message')
          : channel.type == 'dm'
          ? '@${channel.string('peerDisplayName', channel.string('peerName', channel.name))}'
          : '#${channel.name}',
    );
  }

  /// Web MessageItem markdown `a` renderer → reference treatment.
  RaftReferenceAppearance? appearance(String href) {
    final uri = Uri.tryParse(href);
    if (uri == null || uri.scheme != 'raft-ref') return null;
    final parts = uri.pathSegments;
    switch (uri.host) {
      case 'mention' when parts.length == 2:
        if (parts[0] == 'external') {
          // Web MentionLink: a mention renders styled before the roster
          // loads (and for guests); the hover card falls back to the handle.
          final member =
              externalMember(parts[1]) ??
              externalMentionFallback(message, parts[1]);
          return RaftReferenceAppearance(
            RaftReferenceKind.mention,
            hoverCard: exportMode
                ? null
                : (ctx) => externalMentionPreview(
                    ctx,
                    controller.client.origin,
                    member,
                  ),
          );
        }

        String? handle;
        for (final m
            in (message.json['mentions'] as List? ?? []).whereType<Map>()) {
          if (m['id'] == parts[1] && m['name'] is String) handle = m['name'];
        }
        final agentRead = parts[0] == 'agent' && !exportMode
            ? agentMentionRead(controller, message, parts[1])
            : null;
        return RaftReferenceAppearance(
          parts[0] == 'user' && parts[1] == controller.client.user?.id
              ? RaftReferenceKind.selfMention
              : RaftReferenceKind.mention,
          agentRead: agentRead,
          // Web MentionLink PreviewCard; export renders no popups.
          hoverCard: exportMode
              ? null
              : (_) => ProfilePreviewContent(
                  controller: controller,
                  agent: parts[0] == 'agent',
                  id: parts[1],
                  fallbackLabel: handle,
                  readReceipt: agentRead,
                  onOpenActivity: parts[0] == 'agent'
                      ? (id) => openProfile(
                          RaftProfileKind.agent,
                          id,
                          agentTab: 'activity',
                        )
                      : null,
                ),
        );
      case 'channel':
        return const RaftReferenceAppearance(RaftReferenceKind.channel);
      case 'thread':
        return const RaftReferenceAppearance(RaftReferenceKind.thread);
      case 'message':
        return const RaftReferenceAppearance(RaftReferenceKind.message);
      case 'task' when parts.length == 1:
        final task = taskByNumber?.call(int.tryParse(parts[0]) ?? 0);
        final status = switch (task?['status']) {
          // Web v1.24 taskStatusUi: backlog is a status of its own.
          'backlog' => RaftMessageTaskStatus.backlog,
          'todo' => RaftMessageTaskStatus.todo,
          'in_progress' => RaftMessageTaskStatus.inProgress,
          'in_review' => RaftMessageTaskStatus.inReview,
          'done' => RaftMessageTaskStatus.done,
          'closed' => RaftMessageTaskStatus.closed,
          _ => null,
        };
        return status == null
            ? const RaftReferenceAppearance(RaftReferenceKind.unknownTask)
            : RaftReferenceAppearance(
                RaftReferenceKind.task,
                taskStatus: status,
              );
      case 'task' when parts.length == 2:
        return const RaftReferenceAppearance(RaftReferenceKind.unknownTask);
    }
    return null;
  }
}
