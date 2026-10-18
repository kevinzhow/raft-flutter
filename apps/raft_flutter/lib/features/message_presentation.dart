import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/raft_location.dart';
import '../data/raft_permalink.dart';
import '../data/source_time_formatter.dart';
import '../data/user_error.dart';

import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'management_support.dart'
    show cachedServerFlag, pageIdentity, rememberServerFlag;
import '../platform/attachment_files.dart';
import '../platform/content_links.dart';
import 'quoted_message_preview.dart';
import 'message_action_card.dart';
import 'attachment_view.dart';
import 'fleet_views.dart';
import 'private_route_guard.dart';
import 'profile_preview.dart';
import 'composer_directory.dart' show cachedExternalMembers;
import 'external_mentions.dart';
import '../data/feature_flag_client_facts.dart';

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

const _resourceReferencesFlag = 'composer_resource_references_v0';

/// Evaluates whether `computer:` / `app:` references open on this server and
/// remembers the answer under [identity] for the next open.
Future<bool> _evaluateResourceReferences(
  BuildContext context,
  WorkspaceController w,
  String identity,
) async {
  final flag = await w.client.post(
    '/feature-flags/evaluate',
    data: featureFlagEvaluateBody(
      keys: [_resourceReferencesFlag],
      serverId: w.server!.id,
      platform: Theme.of(context).platform,
    ),
  );
  final enabled =
      flag is Map &&
      flag['evaluations'] is List &&
      (flag['evaluations'] as List).whereType<Map>().any(
        (f) => f['key'] == _resourceReferencesFlag && f['enabled'] == true,
      );
  rememberServerFlag(w, _resourceReferencesFlag, enabled, identity);
  return enabled;
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
    RaftChannel? dm(String token) {
      final parts = token.split('~');
      if (parts.length > 2 ||
          (parts.length == 2 && !['agent', 'human'].contains(parts[1]))) {
        return null;
      }
      final type = parts.length == 2
          ? parts[1] == 'human'
                ? 'user'
                : 'agent'
          : null;
      final matches = controller.dms
          .where(
            (c) =>
                (c.string('peerName', c.string('name')) == parts[0]) &&
                (type == null || c.string('peerType') == type),
          )
          .toList();
      return matches.length == 1 ? matches.single : null;
    }

    for (final m
        in content.contains('dm:@')
            ? _dmReference.allMatches(content)
            : const <RegExpMatch>[]) {
      final c = dm(m[1]!);
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
          (['agent', 'user'].contains(m['type']) ||
              m['type'] == 'external' &&
                  externalMember('${m['id']}') != null)) {
        refs['@${m['name']}'] = RaftTextReference(
          text: '@${m['name']}',
          identityBacked: true,
          href: href('mention', ['${m['type']}', '${m['id']}']),
        );
      }
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

  Future<void> open(BuildContext context, String href) async {
    final uri = Uri.tryParse(href);
    if (uri != null && ['computer', 'app'].contains(uri.scheme)) {
      if (!localAuthority || exportMode) return;
      final w = controller, authority = workspaceAuthority(controller);
      bool current() => context.mounted && authority == workspaceAuthority(w);
      try {
        // A flag this device has already seen enabled opens the reference at
        // once and is revalidated behind it; only a flag never seen (or seen
        // disabled) is evaluated before opening.
        final identity = pageIdentity(w);
        if (cachedServerFlag(w, _resourceReferencesFlag) == true) {
          unawaited(
            _evaluateResourceReferences(
              context,
              w,
              identity,
            ).catchError((_) => false),
          );
        } else if (!await _evaluateResourceReferences(context, w, identity) ||
            !current()) {
          return;
        }
        if (uri.scheme == 'computer' && w.can('viewMachines')) {
          // The workspace directory already holds the machines read.
          final directory = w.services.entityDirectory;
          final known = directory.state(WorkspaceEntityKind.computers).loaded
              ? directory.computer(uri.path)
              : null;
          Map<String, dynamic>? machine = known?['isComputer'] == true
              ? known
              : null;
          if (machine == null) {
            final out = await w.query('/servers/${w.server!.id}/machines');
            if (!current() || !context.mounted) return;
            final rows = out is List ? out : out['machines'] as List? ?? [];
            final fetched = rows
                .whereType<Map>()
                .where((r) => r['id'] == uri.path && r['isComputer'] == true)
                .firstOrNull;
            if (fetched != null) machine = Map<String, dynamic>.from(fetched);
          }
          if (machine == null) {
            throw const RaftApiException(
              'The referenced resource is unavailable.',
            );
          }
          final initial = machine;
          if (!context.mounted) return;
          await showDialog(
            context: context,
            builder: (_) => FleetDetail(
              controller: w,
              computers: true,
              initial: Map<String, dynamic>.from(initial),
            ),
          );
        } else if (uri.scheme == 'app' && w.canVisitSection('integrations')) {
          // The Integrations page opens at once; the installed-apps read only
          // vouches for the reference behind it.
          w.setSection('integrations');
          final out = await w.query('/servers/${w.server!.id}/apps');
          if (authority != workspaceAuthority(w)) return;
          final rows = out is Map ? out['apps'] as List? ?? [] : const [];
          if (!rows.whereType<Map>().any((r) => r['appId'] == uri.path)) {
            throw const RaftApiException(
              'The referenced resource is unavailable.',
            );
          }
        } else {
          throw const RaftApiException(
            'The referenced resource is unavailable.',
          );
        }
      } catch (e) {
        // Web MessageItem: `toast.error(sourceUnavailable)`.
        if (current() && context.mounted) {
          showRaftToast(
            context,
            userErrorText(
              e,
              fallback:
                  'Unable to open source. It may be unavailable or deleted.',
              where: 'open resource reference',
            ),
          );
        }
      }
      return;
    }
    if (uri?.scheme != 'raft-ref') {
      // Web handleOpenPermalink: a message link of this server opens in the
      // app, any other link opens externally.
      final link = parseRaftPermalink(href, hostnames: [permalinkHostname]);
      if (link != null &&
          localAuthority &&
          !exportMode &&
          link.serverSlug == controller.server?.string('slug')) {
        await openRaftPermalink(controller, link);
        return;
      }
      onExternalLink(href);
      return;
    }
    if (!localAuthority) return;
    final w = controller, authority = workspaceAuthority(controller);
    bool current() => context.mounted && authority == workspaceAuthority(w);
    try {
      final parts = uri!.pathSegments;
      if (uri.host == 'channel' && parts.length == 1) {
        final channel = [
          ...w.channels,
          ...w.dms,
        ].where((c) => c.id == parts[0]).firstOrNull;
        if (channel != null) await w.selectChannel(channel);
        return;
      }
      if (uri.host == 'message' && parts.length == 2) {
        await w.jumpToMessage(parts[0], parts[1]);
        return;
      }
      if (uri.host == 'mention' &&
          parts.length == 2 &&
          parts[0] == 'external') {
        final member = externalMember(parts[1]);
        if (member != null) {
          w.openProfile(
            RaftProfileKind.external,
            message.id,
            channelId: message.channelId,
            externalAuthor: {...member, 'projectionId': member['id']},
          );
        }
        return;
      }
      // Web MentionLink: the mention opens the member / agent profile panel.
      if (uri.host == 'mention' &&
          parts.length == 2 &&
          ['agent', 'user'].contains(parts[0])) {
        w.openProfile(
          parts[0] == 'agent' ? RaftProfileKind.agent : RaftProfileKind.human,
          parts[1],
        );
        return;
      }
      if (uri.host == 'thread' && parts.length == 2) {
        // A message this device already holds in that channel is its own
        // canonical target: jump at once instead of resolving it first.
        if (w.visibleIds[parts[0]]?.contains(parts[1]) == true &&
            w.ledger.messages(parts[0]).any((row) => row['id'] == parts[1])) {
          await w.jumpToMessage(parts[0], parts[1]);
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
          await w.jumpToMessage(
            target is Map ? target['channelId'] ?? parts[0] : parts[0],
            id,
          );
        } else {
          throw const RaftApiException('This thread is no longer available.');
        }
        return;
      }
      if (uri.host != 'task' ||
          parts.length != 1 ||
          message.channelId.isEmpty) {
        return;
      }
      final number = int.tryParse(parts[0]);
      if (number == null) return;
      final carrier = messageParentChannelId(message.json) ?? w.channel?.id;
      if (carrier == null) return;
      // The loaded channel tasks already know this task: open it from them
      // (the task surface revalidates its own copy).
      final local = taskByNumber?.call(number);
      if (local != null && onOpenTask != null) {
        onOpenTask!(Map<String, dynamic>.from(local));
        return;
      }
      Future<Map<String, dynamic>> fetch() async {
        final out = await w.query('/tasks/channel/$carrier/number/$number');
        return Map<String, dynamic>.from(out['task']);
      }

      if (onOpenTask != null) {
        // No task row to open the task surface with yet.
        final task = await fetch();
        if (context.mounted && current()) onOpenTask!(task);
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
      final shown = showDialog<void>(
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

  Widget mentionDialog(
    BuildContext ctx,
    String title,
    Map<String, dynamic> data,
    bool Function() current, {
    bool loading = false,
  }) {
    final w = controller;
    return AlertDialog(
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
                      raftTaskStatuses.contains(data['status'])
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
                  label: 'Open message',
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (current()) {
                      await w.jumpToMessage(
                        data['channelId'],
                        data['messageId'],
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
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
        ...w.messages,
        ...w.replies,
        if (w.threadParent != null) w.threadParent!,
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
      return RaftForwardedBundle(
        key: ValueKey('forwarded-${message.id}'),
        metadata: Map<String, dynamic>.from(message.json['actionMetadata']),
        exportMode: exportMode,
        // Web ForwardedBundleCard: useTimeFormatter().formatShortDateTime
        // ("Jun 22, 10:30 AM") in the account's zone and hour cycle.
        formatTimestamp: forwardedTimestamp(context),
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
    }
    return RaftMessageBody(
      mountedMessage: true,
      // A compact timeline row already announces this text in its label.
      compactSemantics: RaftMessageSemanticsScope.maybeOf(context) != null,
      content: text,
      foregroundColor: foregroundColor,
      searchHighlight: searchHighlight,
      exportMode: exportMode,
      fontSize: fontSize,
      onExportDiagram: exportMode
          ? null
          : (extension, bytes) => saveDiagram(context, extension, bytes),
      references: references,
      taskHref: localAuthority
          ? (n) => Uri(
              scheme: 'raft-ref',
              host: 'task',
              pathSegments: ['$n'],
            ).toString()
          : null,
      onLink: exportMode ? null : (href) => open(context, href),
      knownTaskNumber:
          knownTaskNumber ??
          (taskByNumber == null ? null : (n) => taskByNumber!(n) != null),
      referenceAppearance: appearance,
      permalinkAppearance: (href) => permalinkAppearance(context, href),
      permalinkKey: Object.hash(
        unavailablePermalink,
        controller.channels.length,
        controller.dms.length,
      ),
    );
  }

  String get permalinkHostname =>
      ContentLinks.originFor(controller.client.origin).host;

  /// Web MessageItem markdown `a` renderer for Raft permalinks: a Link chip
  /// labelled with the channel (or "linked message"), inert once unavailable.
  RaftReferenceAppearance? permalinkAppearance(
    BuildContext context,
    String href,
  ) {
    if (exportMode || !localAuthority) return null;
    final link = parseRaftPermalink(
      href.replaceAll('&amp;', '&'),
      hostnames: [permalinkHostname],
    );
    if (link == null) return null;
    final raw = unavailablePermalink == null
        ? null
        : parseRaftPermalink(
            unavailablePermalink!,
            hostnames: [permalinkHostname],
          );
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
          final member = externalMember(parts[1]);
          return member == null
              ? null
              : RaftReferenceAppearance(
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
        return RaftReferenceAppearance(
          parts[0] == 'user' && parts[1] == controller.client.user?.id
              ? RaftReferenceKind.selfMention
              : RaftReferenceKind.mention,
          // Web MentionLink PreviewCard; export renders no popups.
          hoverCard: exportMode
              ? null
              : (_) => ProfilePreviewContent(
                  controller: controller,
                  agent: parts[0] == 'agent',
                  id: parts[1],
                  fallbackLabel: handle,
                  onOpenActivity: parts[0] == 'agent'
                      ? (id) => controller.openProfile(
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
    }
    return null;
  }
}
