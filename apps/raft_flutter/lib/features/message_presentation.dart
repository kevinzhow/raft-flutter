import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import '../platform/attachment_files.dart';
import 'message_action_card.dart';
import 'attachment_view.dart';
import 'fleet_views.dart';
import 'private_route_guard.dart';

/// Full MessageDTO uses `user`; legacy/native human rows use `human`.
/// Presentation consumers use one identity kind without altering transport data.
String? messageSenderIdentityKind(RaftMessage message) =>
    switch (message.string('senderType')) {
      'user' || 'human' => 'human',
      'agent' => 'agent',
      _ => null,
    };

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
      directory = p.directoryReferences,
      channels = p.controller.channels,
      channelCount = p.controller.channels.length,
      dms = p.controller.dms,
      dmCount = p.controller.dms.length;
  final String messageId, content;
  final Object? mentions;
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
  });

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
    final refs = {
      for (final ref in directoryReferences)
        if (content.contains(ref.text)) ref.text: ref,
    };
    final channels = controller.channels.where((c) => !c.archived).toList();
    String href(String kind, List<String> parts) =>
        Uri(scheme: 'raft-ref', host: kind, pathSegments: parts).toString();
    if (content.contains('#')) {
      for (final c in channels) {
        final text = '#${c.string('name')}';
        if (!content.contains(text)) continue;
        refs[text] = RaftTextReference(
          text: text,
          href: href('channel', [c.id]),
        );
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

    for (final m in _dmReference.allMatches(content)) {
      final c = dm(m[1]!);
      if (c == null) continue;
      refs[m[0]!] = RaftTextReference(
        text: m[0]!,
        href: m[2] == null
            ? href('channel', [c.id])
            : href('thread', [c.id, m[2]!]),
      );
    }
    for (final m in _threadReference.allMatches(content)) {
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
    for (final m in _messageReference.allMatches(content)) {
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
          ['agent', 'user'].contains(m['type'])) {
        refs['@${m['name']}'] = RaftTextReference(
          text: '@${m['name']}',
          identityBacked: true,
          href: href('mention', ['${m['type']}', '${m['id']}']),
        );
      }
    }
    return refs.values.toList();
  }

  Future<void> open(BuildContext context, String href) async {
    final uri = Uri.tryParse(href);
    if (uri != null && ['computer', 'app'].contains(uri.scheme)) {
      if (!localAuthority || exportMode) return;
      final w = controller, authority = workspaceAuthority(controller);
      bool current() => context.mounted && authority == workspaceAuthority(w);
      try {
        final flag = await w.client.post(
          '/feature-flags/evaluate',
          data: {
            'keys': ['composer_resource_references_v0'],
            'serverId': w.server!.id,
            'platform': Theme.of(context).platform == TargetPlatform.android
                ? 'mobile'
                : 'web',
          },
        );
        if (!current() ||
            flag is! Map ||
            flag['evaluations'] is! List ||
            !(flag['evaluations'] as List).whereType<Map>().any(
              (f) =>
                  f['key'] == 'composer_resource_references_v0' &&
                  f['enabled'] == true,
            )) {
          return;
        }
        if (uri.scheme == 'computer' && w.can('viewMachines')) {
          final out = await w.query('/servers/${w.server!.id}/machines');
          if (!current() || !context.mounted) return;
          final rows = out is List ? out : out['machines'] as List? ?? [];
          final machine = rows
              .whereType<Map>()
              .where((r) => r['id'] == uri.path && r['isComputer'] == true)
              .firstOrNull;
          if (machine == null) {
            throw const RaftApiException(
              'The referenced resource is unavailable.',
            );
          }
          await showDialog(
            context: context,
            builder: (_) => FleetDetail(
              controller: w,
              computers: true,
              initial: Map<String, dynamic>.from(machine),
            ),
          );
        } else if (uri.scheme == 'app' && w.canVisitSection('integrations')) {
          final out = await w.query('/servers/${w.server!.id}/apps');
          if (!current()) return;
          final rows = out is Map ? out['apps'] as List? ?? [] : const [];
          if (!rows.whereType<Map>().any((r) => r['appId'] == uri.path)) {
            throw const RaftApiException(
              'The referenced resource is unavailable.',
            );
          }
          w.setSection('integrations');
        } else {
          throw const RaftApiException(
            'The referenced resource is unavailable.',
          );
        }
      } catch (e) {
        if (current()) w.setError('$e');
      }
      return;
    }
    if (uri?.scheme != 'raft-ref') {
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
      if (uri.host == 'thread' && parts.length == 2) {
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
      Map<String, dynamic> data;
      String heading;
      // A mention reads the shared, server-scoped directory: the dialog opens
      // at once and follows in-place directory updates. Only an entity the
      // directory does not hold (remote agent, unsettled list) is fetched.
      Map<String, dynamic>? Function()? live;
      if (uri.host == 'task' &&
          parts.length == 1 &&
          message.channelId.isNotEmpty) {
        final number = int.tryParse(parts[0]);
        if (number == null) return;
        final carrier = message.json['parentChannelId'] ?? w.channel?.id;
        if (carrier == null) return;
        final out = await w.query('/tasks/channel/$carrier/number/$number');
        data = Map<String, dynamic>.from(out['task']);
        heading = 'task #$number · ${data['title'] ?? ''}';
      } else if (uri.host == 'mention' &&
          parts.length == 2 &&
          ['agent', 'user'].contains(parts[0])) {
        // The selected entity supplies its ID; no directory guess changes it.
        final directory = w.entityDirectory, id = parts[1];
        if (parts[0] == 'agent') {
          if (!w.can('viewAgents')) return;
          live = () => directory.agent(id);
          final cached = live();
          if (cached != null) {
            data = cached;
          } else {
            final out = await w.query('/agents/$id');
            data = Map<String, dynamic>.from(
              out['agent'] is Map ? out['agent'] : out,
            );
          }
        } else {
          if (!w.can('viewMembers')) return;
          live = () => directory.member(id);
          var cached = live();
          if (cached == null &&
              !directory.state(WorkspaceEntityKind.members).loaded) {
            await directory.refresh(WorkspaceEntityKind.members);
            if (!context.mounted || !current()) return;
            cached = live();
          }
          if (cached == null) {
            throw const RaftApiException('This member is no longer available.');
          }
          data = cached;
        }
        heading = '${data['displayName'] ?? data['name'] ?? ''}';
      } else {
        return;
      }
      if (!context.mounted || !current()) return;
      final opened = directoryAuthority(w), initial = data;
      await showDialog<void>(
        context: context,
        builder: (ctx) => ListenableBuilder(
          // The live entity row follows directory updates in place.
          listenable: Listenable.merge([w, w.entityDirectory]),
          builder: (ctx, _) {
            if (live != null && directoryAuthority(w) != opened) {
              // A server-level identity change revokes the projection.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (ctx.mounted) Navigator.of(ctx).maybePop();
              });
              return const SizedBox.shrink();
            }
            final data = live?.call() ?? initial;
            final title = live == null
                ? heading
                : '${data['displayName'] ?? data['name'] ?? ''}';
            return mentionDialog(ctx, title, data, current);
          },
        ),
      );
    } catch (e) {
      if (current()) w.setError('$e');
    }
  }

  Widget mentionDialog(
    BuildContext ctx,
    String title,
    Map<String, dynamic> data,
    bool Function() current,
  ) {
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
      if (current()) w.setError('Could not export diagram.');
    }
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
    );
  }

  /// Web MessageItem markdown `a` renderer → reference treatment.
  RaftReferenceAppearance? appearance(String href) {
    final uri = Uri.tryParse(href);
    if (uri == null || uri.scheme != 'raft-ref') return null;
    final parts = uri.pathSegments;
    switch (uri.host) {
      case 'mention' when parts.length == 2:
        return RaftReferenceAppearance(
          parts[0] == 'user' && parts[1] == controller.client.user?.id
              ? RaftReferenceKind.selfMention
              : RaftReferenceKind.mention,
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
