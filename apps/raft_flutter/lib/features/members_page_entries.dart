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

Widget usageAgentAvatar(
  MemberPageEntry agent,
  String origin,
  double size, {
  Widget? badge,
}) {
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
    corner: badge,
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
    this.statusDot,
    this.computerDot,
  });

  final List<String> labels;
  final Widget? name;
  final Widget? subtitle;
  final bool header;
  final RaftStatusDot? statusDot, computerDot;

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    Widget cell(int index) {
      final label = labels[index];
      if (header) {
        return RaftCssText(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tokens.scale(
            RaftTypeScale.footnote,
            color: tokens.ui.foregroundHint,
            weight: FontWeight.w700,
          ),
        );
      }
      final dot = switch (index) {
        0 => statusDot,
        3 => computerDot,
        _ => null,
      };
      final content = index == 0
          ? RaftCssText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.scale(
                RaftTypeScale.caption,
                color: tokens.ui.foregroundMuted,
              ),
            )
          : RaftListRowMeta(label);
      return dot == null
          ? content
          : Row(
              spacing: RaftSpace.x2,
              children: [
                dot,
                Flexible(child: content),
              ],
            );
    }

    return Padding(
      padding: header
          ? const EdgeInsets.fromLTRB(
              RaftSpace.x5 + RaftSpace.hairline,
              RaftSpace.x4,
              RaftSpace.x5 + RaftSpace.x4 + RaftSpace.hairline,
              RaftSpace.x2,
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
              for (final (index, _) in labels.indexed)
                if (index == 0 || expanded)
                  SizedBox(
                    width: const [102.0, 104.0, 176.0, 136.0][index],
                    child: cell(index),
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
    this.statusDot,
    this.computerDot,
    this.activity,
  });

  final MembersEntryLayout layout;
  final MemberPageEntry entry;
  final Widget avatar;
  final VoidCallback onOpen;
  final ValueChanged<Offset>? onMenu;
  final VoidCallback? onMessage;
  final bool selected, self, menuOpen;
  final List<String> facts;
  final RaftStatusDot? statusDot, computerDot;
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
        tag: role == null
            ? null
            : RaftCssText(
                role,
                maxLines: 1,
                style: tokens.scale(
                  RaftTypeScale.caption,
                  weight: FontWeight.w500,
                  color: tokens.ui.foregroundHint,
                ),
              ),
        conversationKind: RaftConversationNavKind.memberRoster,
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
                baseline: true,
                children: [
                  Flexible(
                    child: layout == MembersEntryLayout.cards
                        ? RaftCssText(
                            entry.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tokens.scale(
                              RaftTypeScale.body,
                              weight: FontWeight.w600,
                            ),
                          )
                        : RaftListRowTitle(entry.name),
                  ),
                  if (self)
                    RaftCssText(
                      raftText(context, '(you)'),
                      style: tokens.scale(
                        RaftTypeScale.body,
                        color: tokens.ui.foregroundHint,
                      ),
                    ),
                  if (role != null)
                    RaftCssText(
                      role,
                      style: tokens.scale(
                        RaftTypeScale.caption,
                        weight: FontWeight.w500,
                        color: tokens.ui.foregroundMuted,
                      ),
                    ),
                ],
              ),
              if (description != null)
                if (layout == MembersEntryLayout.cards)
                  RaftCssText(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.scale(
                      RaftTypeScale.footnote,
                      color: tokens.ui.foreground,
                    ),
                  )
                else
                  RaftListRowSubtitle(description),
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
              selected: selected,
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
            selected: selected,
            semanticLabel: label,
            interactive: true,
            onPressed: onOpen,
            children: [
              Expanded(
                child: MembersAgentColumns(
                  labels: facts,
                  statusDot: statusDot,
                  computerDot: computerDot,
                  name: identity(),
                  subtitle: identity(folded: true),
                ),
              ),
            ],
          );
    final touch = RaftInteraction.of(context).touch;
    return GestureDetector(
      onSecondaryTapDown: !touch && onMenu != null
          ? (event) => onMenu!(event.globalPosition)
          : null,
      onLongPressStart: touch && onMenu != null
          ? (event) => onMenu!(event.globalPosition)
          : null,
      child: RaftMouseDoubleClick(onDoubleClick: onMessage, child: surface),
    );
  }
}
