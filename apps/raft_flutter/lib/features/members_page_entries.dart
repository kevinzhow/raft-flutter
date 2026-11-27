import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'desktop_navigation_policy.dart';
import 'sender_avatar_projection.dart';

enum MembersEntryLayout { list, table, cards }

typedef MemberPageEntry = ({
  DesktopContentTarget target,
  Map<String, dynamic> record,
  String name,
  String handle,
  bool Function(String) matches,
});

Widget usageAgentAvatar(MemberPageEntry agent, String origin, double size) {
  final avatar = projectSenderAvatar(
    origin: origin,
    senderId: agent.target.id,
    senderType: 'agent',
    agents: [agent.record],
    members: const [],
  );
  return RaftAvatar(
    name: agent.name,
    size: size,
    kind: RaftAvatarKind.agent,
    content: RaftAvatarContent(
      name: agent.name,
      kind: RaftAvatarContentKind.agent,
      uploadedUrl: avatar.uploadedUrl,
      pixelKey: avatar.pixelKey,
    ),
  );
}

List<MemberPageEntry> memberPageEntries(
  List<Map<String, dynamic>> rows,
  DesktopContentKind kind,
) {
  final entries = <MemberPageEntry>[];
  for (final row in rows) {
    final id = kind == DesktopContentKind.human
        ? row['userId'] ?? row['id']
        : row['id'];
    if (id is! String) continue;
    final handle = row['name'] as String? ?? '';
    final display = row['displayName'];
    final name = display is String && display.isNotEmpty ? display : handle;
    final searchableName = name.toLowerCase();
    final searchableHandle = handle.toLowerCase();
    entries.add((
      target: DesktopContentTarget(kind, id),
      record: row,
      name: name,
      handle: handle,
      matches: (query) {
        final term = query.toLowerCase();
        return searchableName.contains(term) || searchableHandle.contains(term);
      },
    ));
  }
  return entries..sort((first, second) {
    final byName = first.name.toLowerCase().compareTo(
      second.name.toLowerCase(),
    );
    return byName != 0 ? byName : first.handle.compareTo(second.handle);
  });
}

class MembersAgentColumns extends StatelessWidget {
  const MembersAgentColumns({
    super.key,
    required this.labels,
    this.name,
    this.subtitle,
    this.header = false,
  });

  final List<String> labels;
  final Widget? name;
  final Widget? subtitle;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    return Padding(
      padding: header
          ? const EdgeInsets.symmetric(
              horizontal: RaftSpace.x5 + RaftSpace.x3 + RaftSpace.half,
              vertical: RaftSpace.x1_5,
            )
          : EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, bounds) {
          final expanded = bounds.maxWidth >= 690;
          return RaftGapRow(
            gap: 12,
            children: [
              Expanded(
                child: expanded
                    ? name ?? const SizedBox.shrink()
                    : subtitle ?? name ?? const SizedBox.shrink(),
              ),
              for (final (index, width) in const [
                102.0,
                104.0,
                176.0,
                136.0,
              ].indexed)
                if (index == 0 || expanded)
                  SizedBox(
                    width: width,
                    child: header || index == 0
                        ? Text(
                            labels[index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RaftPanelText.caption(tokens).copyWith(
                              color: header
                                  ? tokens.ui.foregroundHint
                                  : tokens.ui.foregroundMuted,
                            ),
                          )
                        : RaftListRowMeta(labels[index]),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class MemberDirectoryEntry extends StatelessWidget {
  static const _cardIdentityMinHeight = RaftSpace.x5 * 2;

  const MemberDirectoryEntry({
    super.key,
    required this.layout,
    required this.entry,
    required this.avatar,
    required this.onOpen,
    required this.selected,
    this.onMenu,
    this.onMessage,
    this.menuOpen = false,
    this.self = false,
    this.facts = const [],
    this.activity,
  });

  final MembersEntryLayout layout;
  final MemberPageEntry entry;
  final Widget avatar;
  final VoidCallback onOpen;
  final ValueChanged<Offset>? onMenu;
  final VoidCallback? onMessage;
  final bool selected, menuOpen, self;
  final List<String> facts;
  final ValueListenable<String?>? activity;

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    final role = switch (entry.record['role'] ?? entry.record['serverRole']) {
      'owner' => raftText(context, 'Owner'),
      'admin' => raftText(context, 'Admin'),
      'guest' => raftText(context, 'Guest'),
      _ => null,
    };
    final rawDescription = entry.record['description'];
    final description = rawDescription is String && rawDescription.isNotEmpty
        ? rawDescription
        : null;
    if (layout == MembersEntryLayout.list) {
      return RaftNavItem(
        label: entry.name,
        labelSuffix: self ? raftText(context, '(you)') : null,
        tag: role == null ? null : RaftSidebarTag(role),
        conversationKind: RaftConversationNavKind.directory,
        selected: selected,
        menuOpen: menuOpen,
        onContextMenu: onMenu,
        onDoubleClick: onMessage,
        onTap: onOpen,
        leading: avatar,
        activityText: activity,
        description: description,
        wrap: description != null,
      );
    }
    final label = raftFormat(context, "Open {name}'s profile", {
      'name': entry.name,
    });
    Widget identity({bool folded = false}) => RaftGapRow(
      gap: 12,
      children: [
        avatar,
        Expanded(
          child: RaftGapColumn(
            gap: 2,
            children: [
              RaftGapRow(
                gap: 8,
                children: [
                  Flexible(child: RaftListRowTitle(entry.name)),
                  if (self)
                    Text(
                      raftText(context, '(you)'),
                      style: RaftPanelText.caption(tokens),
                    ),
                  if (role != null)
                    Text(role, style: RaftPanelText.caption(tokens)),
                ],
              ),
              if (description != null) RaftListRowSubtitle(description),
              if (folded)
                RaftListRowMeta(
                  facts.skip(1).where((fact) => fact != '—').join(' · '),
                ),
            ],
          ),
        ),
      ],
    );
    final surface = layout == MembersEntryLayout.cards
        ? Semantics(
            label: label,
            child: RaftCard.item(
              selected: selected || menuOpen,
              onTap: onOpen,
              padding: EdgeInsets.symmetric(
                horizontal: RaftSpace.x4,
                vertical: RaftInteraction.of(context).touch
                    ? RaftSpace.x2
                    : RaftSpace.x3,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: _cardIdentityMinHeight,
                ),
                child: identity(),
              ),
            ),
          )
        : RaftListRow(
            selected: selected || menuOpen,
            semanticLabel: label,
            interactive: true,
            onPressed: onOpen,
            children: [
              Expanded(
                child: MembersAgentColumns(
                  labels: facts,
                  name: identity(),
                  subtitle: identity(folded: true),
                ),
              ),
            ],
          );
    final touch = RaftInteraction.of(context).touch;
    return GestureDetector(
      onDoubleTap: touch ? null : onMessage,
      onSecondaryTapDown: !touch && onMenu != null
          ? (event) => onMenu!(event.globalPosition)
          : null,
      onLongPressStart: touch && onMenu != null
          ? (event) => onMenu!(event.globalPosition)
          : null,
      child: surface,
    );
  }
}
