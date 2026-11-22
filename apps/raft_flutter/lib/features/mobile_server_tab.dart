import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../platform/app_services.dart';
import '../platform/app_update.dart';
import 'app_permission_updates.dart';
import 'artifacts/artifact_session.dart';
import 'computers_rack/computer_attention_seen.dart';
import 'feedback_unread.dart';
import 'public_avatar_url.dart';
import 'server_menu_model.dart';

/// The server's own pages the phone's server tab opens (Web v1.24
/// MobileServerTab). Each is a pushed page with Back, not a tab root.
enum ServerPage { artifacts, members, computers, apps, settings }

/// [ServerPage] ids, as the bar's tab ids spell them.
final serverPageNames = {for (final page in ServerPage.values) page.name};

/// The bar's last cell: the current server's avatar and name, and the popover
/// it opens above the bar (the server list, the switcher's footer actions and
/// the server's pages), as Web v1.24 `MobileServerTab`. Never selected.
class MobileServerTab extends StatefulWidget {
  const MobileServerTab({
    super.key,
    required this.controller,
    required this.rows,
    required this.actions,
    required this.onReorder,
    required this.onOpenPage,
    required this.otherServerUnread,
    this.appUpdate,
  });
  final WorkspaceController controller;

  /// The Home switcher's rows, with a selection that keeps the current tab.
  final List<RaftServerMenuRow> rows;
  final ServerMenuActions actions;
  final void Function(int from, int to) onReorder;
  final ValueChanged<ServerPage> onOpenPage;

  /// Another server has unread items: the avatar's dot.
  final bool otherServerUnread;

  /// A newer release the person has not seen: Settings' dot, as the Settings
  /// tab carried before.
  final AppUpdateService? appUpdate;

  @override
  State<MobileServerTab> createState() => _MobileServerTabState();
}

class _MobileServerTabState extends State<MobileServerTab> {
  final focus = FocusNode(debugLabel: 'mobile server tab');

  /// A page was opened from the popover: when it is popped and this bar is
  /// current again the tab takes focus back (Web requestServerTabFocus /
  /// consumeServerTabFocus); any other way of reaching the bar does not.
  bool focusOnReturn = false, wasCurrent = true;

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.isCurrentOf(context) ?? true;
    if (current && !wasCurrent && focusOnReturn) {
      focusOnReturn = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) focus.requestFocus();
      });
    }
    wasCurrent = current;
  }

  void openPage(ServerPage page, VoidCallback close) {
    focusOnReturn = true;
    close();
    widget.onOpenPage(page);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.controller;
    final name = w.server?.name ?? raftText(context, 'Server');
    final url = raftPublicAvatarUrl(
      w.client.origin,
      w.server?.json['avatarUrl'] as String?,
    );
    final tab = RaftMobileNavServerTab(
      key: const Key('mobile-tab-server'),
      label: name,
      semanticLabel: widget.otherServerUnread
          ? raftFormat(context, '{name}, another server has unread items', {
              'name': name,
            })
          : name,
      avatar: ServerMark._tab(name: name, avatarUrl: url),
      attention: widget.otherServerUnread,
      attentionKey: const Key('mobile-tab-server-unread-dot'),
      popoverKey: const Key('mobile-server-tab-popover'),
      focusNode: focus,
      contentBuilder: (context, close) => _ServerPopoverContent(
        tab: widget,
        name: name,
        close: close,
        openPage: (page) => openPage(page, close),
      ),
    );
    return AppPermissionUpdatesHost(workspace: w, child: tab);
  }
}

class _ServerPopoverContent extends StatefulWidget {
  const _ServerPopoverContent({
    required this.tab,
    required this.name,
    required this.close,
    required this.openPage,
  });
  final MobileServerTab tab;
  final String name;
  final VoidCallback close;
  final ValueChanged<ServerPage> openPage;
  @override
  State<_ServerPopoverContent> createState() => _ServerPopoverContentState();
}

class _ServerPopoverContentState extends State<_ServerPopoverContent> {
  WorkspaceController get w => widget.tab.controller;
  late int feedbackUnread = cachedFeedbackUnread(w);

  @override
  void initState() {
    super.initState();
    unawaited(loadFeedback());
  }

  /// Settings' dot is the feedback unread count, read as the popover opens.
  Future<void> loadFeedback() async {
    final count = await fetchFeedbackUnread(w);
    if (mounted && count != null && count != feedbackUnread) {
      setState(() => feedbackUnread = count);
    }
  }

  VoidCallback? afterClose(VoidCallback? action) => action == null
      ? null
      : () {
          widget.close();
          action();
        };

  Widget serverRow(RaftServerMenuRow row) {
    final t = RaftTokens.of(context);
    final count = row.activityUnreadCount ?? 0;
    final label = count > 99 ? '99+' : '$count';
    final muted = raftText(context, 'Notifications muted');
    return RaftMobileNavServerPopoverRow(
      key: Key('mobile-server-tab-server-${row.id}'),
      leading: ServerMark(name: row.name, avatarUrl: row.avatarUrl, size: 20),
      label: row.name,
      description: '/${row.slug}',
      current: row.current,
      trailing: row.current
          ? RaftIcon(RaftGlyph.check, size: 16, color: t.muted)
          : count <= 0
          ? null
          : row.pushMuted
          ? Semantics(
              label: '$label, $muted',
              child: ExcludeSemantics(
                child: RaftTooltip(
                  message: muted,
                  child: Text(label, style: RaftTypography.mono(t)),
                ),
              ),
            )
          : RaftBadge(
              key: Key('server-row-unread-${row.id}'),
              label: label,
              variant: RaftBadgeRecipeVariant.accent,
            ),
      onPressed: afterClose(row.onSelected),
    );
  }

  Widget actionRow(Key key, RaftMenuEntry entry) =>
      RaftMobileNavServerPopoverRow(
        key: key,
        leading: entry.glyph == null ? null : RaftIcon(entry.glyph!),
        label: entry.label ?? '',
        enabled: entry.onPressed != null,
        onPressed: afterClose(entry.onPressed),
      );

  /// What the page's dot says: "{page}, {what}".
  String? attention(String page, String what) => raftFormat(
    context,
    '{page}, {what}',
    {'page': raftText(context, page), 'what': what},
  );

  /// The root service (a covered page keeps this popover's owner mounted and
  /// does not rebuild it from the shell), else the one the host passed.
  AppUpdateService? get appUpdate =>
      AppServicesScope.maybeOf(context)?.appUpdate ?? widget.tab.appUpdate;

  List<Widget> pages() {
    final guest = w.server?.string('role') == 'guest';
    final computersDot = !guest && computerAttentionDotFor(w);
    final counts = computerAttentionCounts(w);
    final settingsFeedback = feedbackUnread > 0;
    final settingsDot = settingsFeedback || (appUpdate?.hasUnseen ?? false);
    Widget page({
      required ServerPage id,
      required String key,
      required RaftGlyph glyph,
      required String label,
      bool dot = false,
      String? dotKey,
      String? what,
    }) => RaftMobileNavServerPopoverDestination(
      key: Key('mobile-server-tab-$key'),
      glyph: glyph,
      label: label,
      attention: dot,
      attentionKey: dotKey == null ? null : Key(dotKey),
      semanticLabel: dot && what != null ? attention(label, what) : null,
      onPressed: () => widget.openPage(id),
    );
    return [
      if (ArtifactSession.of(w).enabled)
        page(
          id: ServerPage.artifacts,
          key: 'artifacts',
          glyph: RaftGlyph.artifact,
          label: 'Artifacts',
        ),
      if (!guest && w.can('viewMembers'))
        page(
          id: ServerPage.members,
          key: 'members',
          glyph: RaftGlyph.users,
          label: 'Members',
        ),
      if (!guest && w.can('viewMachines'))
        page(
          id: ServerPage.computers,
          key: 'computers',
          glyph: RaftGlyph.monitor,
          label: 'Computers',
          dot: computersDot,
          dotKey: 'computers-attention-dot',
          what: raftFormat(context, '{count} of {total} needs attention', {
            'count': counts.count,
            'total': counts.total,
          }),
        ),
      if (!guest)
        ListenableBuilder(
          listenable: AppPermissionUpdates.of(w),
          builder: (context, _) => page(
            id: ServerPage.apps,
            key: 'apps',
            glyph: RaftGlyph.blocks,
            label: 'Apps',
            dot: AppPermissionUpdates.of(w).summary.needsAdminReview,
            dotKey: 'apps-attention-dot',
            what: raftText(context, 'App permissions need review'),
          ),
        ),
      page(
        id: ServerPage.settings,
        key: 'settings',
        glyph: RaftGlyph.settings,
        label: 'Settings',
        dot: settingsDot,
        dotKey: 'settings-attention-dot',
        what: raftText(
          context,
          settingsFeedback ? 'Feedback has new replies' : 'Update available',
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final actions = widget.tab.actions;
    final inner = ListenableBuilder(
      listenable: Listenable.merge([w, ?appUpdate]),
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftMobileNavServerPopoverList(
            key: const Key('mobile-server-tab-list'),
            onReorder: widget.tab.onReorder,
            children: [for (final row in widget.tab.rows) serverRow(row)],
          ),
          const RaftMobileNavServerPopoverSeparator(),
          RaftMobileNavServerPopoverGroup(
            key: const Key('mobile-server-tab-actions'),
            children: [
              if (actions.join != null)
                actionRow(
                  const Key('mobile-server-tab-join-community'),
                  actions.join!,
                ),
              actionRow(
                const Key('mobile-server-tab-switch-or-create'),
                actions.choose,
              ),
              if (actions.invite != null)
                actionRow(
                  const Key('mobile-server-tab-invite'),
                  actions.invite!,
                ),
            ],
          ),
          const RaftMobileNavServerPopoverSeparator(),
          ListenableBuilder(
            listenable: ArtifactSession.of(w),
            builder: (_, _) => RaftMobileNavServerPopoverDestinations(
              key: const Key('mobile-server-tab-pages'),
              semanticLabel: widget.name,
              children: pages(),
            ),
          ),
        ],
      ),
    );
    return inner;
  }
}

/// The server's avatar (Web `AvatarSlot type="server"`): its image, else its
/// initial.
class ServerMark extends StatelessWidget {
  const ServerMark({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.size,
  }) : _tab = false;

  const ServerMark._tab({required this.name, required this.avatarUrl})
    : size = 22,
      _tab = true;

  final String name;
  final String? avatarUrl;
  final double size;
  final bool _tab;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final docked =
        _tab && t.option('mobileNav.style', or: 'docked') == 'docked';
    final letter = raftAvatarInitials(name, max: 1);
    final text = letter.isEmpty ? 'S' : letter;
    final slot = docked
        ? RaftAvatarSlotContext.mobileNavServer
        : RaftAvatarSlotContext.compactList;
    final initial = docked
        ? RaftAvatarInitials.server(
            text,
            size: RaftAvatarSize.nearest(slot.size),
          )
        : Center(
            child: Text(
              text,
              textScaler: RaftChrome.boundedScalerOf(context),
              style: RaftTypography.body(
                t,
                size: size >= 22 ? 11 : 10,
                line: 14,
                weight: FontWeight.w700,
                color: t.colors['foreground-avatar-server'] ?? t.strong,
              ),
            ),
          );
    return RaftAvatarSlot(
      name: name,
      slot: slot,
      agent: false,
      server: true,
      sizeOverride: docked ? null : size,
      content: avatarUrl == null
          ? initial
          : RaftSizedImage.avatar(
              avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => initial,
            ),
    );
  }
}
