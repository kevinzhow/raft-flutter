part of 'workspace_view.dart';

extension _SidebarWorkspaceGroups on _WorkspaceViewState {
  WorkspaceSidebarMenus get sidebarMenus => WorkspaceSidebarMenus(
    context: context,
    w: w,
    currentAuthority: () => mobileAuthority,
    presentation: presentation,
    sidebarDisclosure: sidebarDisclosure,
    rowToast: rowToast,
    setMenuOpenRow: setMenuOpenRow,
    closeConversation: () {
      if (wide) {
        dismissPanel();
      } else {
        select('home');
      }
    },
    createChannel: createChannel,
    createJointChannel: createJointChannel,
    sidebarExternalEnabled: sidebarExternalEnabled,
    sidebarCanCreateJoint: sidebarCanCreateJoint,
    sidebarCreateJointLabel: sidebarCreateJointLabel,
  );

  Widget? sidebarChannelLeading(RaftChannel channel) {
    if (!sidebarExternalSectionChannel(channel)) {
      return channelPublicLeading(context, w, channel);
    }
    final tokens = RaftTokens.of(context);
    final selected = w.section == 'chat' && w.channel?.id == channel.id;
    return RaftTooltip(
      message: tr('External channel'),
      child: RaftExternalChannelMark(
        size: 16,
        color:
            tokens.colors[selected
                ? 'foreground-sidebar-item-icon-active'
                : channel.joined
                ? 'foreground-sidebar-item-icon'
                : 'foreground-placeholder'],
      ),
    );
  }

  bool get sidebarExternalEnabled => SidebarGroupFacts.of(w).externalEnabled;

  bool get sidebarCanCreateExternal =>
      const {'owner', 'admin'}.contains(w.server?.string('role'));

  bool get sidebarCanCreateJoint => sidebarExternalEnabled
      ? sidebarCanCreateExternal
      : w.can('federateChannels');

  String get sidebarCreateJointLabel => sidebarExternalEnabled
      ? 'Create external channel'
      : 'Create joint channel';

  Future<void> createJointChannel() {
    if (sidebarExternalEnabled) {
      return CreateChannelDialog.show(
        context,
        controller: w,
        prefilledVisibility: 'external',
        onCreated: chooseChannel,
      );
    }
    return CreateJointChannelDialog.show(
      context,
      controller: w,
      onCreated: chooseChannel,
    );
  }

  List<Widget> conversationSlivers() => [
    for (final group in sidebarGroups)
      if (group.custom)
        sidebarCustomGroupSliver(
          group: group,
          w: w,
          header: sectionLabel(group.label, group: group),
          expanded: sidebarDisclosure.collapsed[group.id] != true,
          hideEmpty: presentation.value.hideEmptySections,
          emptyLabel: tr('No conversations'),
          row: (entry, reorderable) =>
              sidebarEntry(entry, custom: true, reorderable: reorderable),
        )
      else
        sidebarGroupSliver(group),
  ];

  Widget? groupAttention(SidebarGroup group, Iterable<SidebarEntry> entries) {
    final unread = w.conversationReads.unread;
    final hasUnread = entries.any((entry) {
      final channel = entry.channel;
      return channel != null &&
          !channel.flag('activityMuted') &&
          (unread[channel.id] ?? entry.loungeUnread) > 0;
    });
    return sidebarDisclosure.collapsed[group.id] == true && hasUnread
        ? const RaftAttentionDot(key: ValueKey('sidebar-section-unread-dot'))
        : null;
  }

  Widget sidebarGroupSliver(SidebarGroup group) {
    final joinedOnly = sidebarDisclosure.joinedChannelsOnly;
    final entries = sidebarShownEntries(group, joinedOnly);
    final externalGroup = group.id == 'system:joint' && sidebarExternalEnabled;
    return sidebarSystemGroupSliver(
      group: group,
      entries: entries,
      w: w,
      label: tr(group.label),
      kind: switch (group.id) {
        'system:pinned' => RaftChatSidebarGroupKind.pinned,
        'system:joint' => RaftChatSidebarGroupKind.joint,
        'system:dms' => RaftChatSidebarGroupKind.directMessages,
        _ => RaftChatSidebarGroupKind.channels,
      },
      expanded: sidebarDisclosure.collapsed[group.id] != true,
      hideEmpty:
          externalGroup ||
          (presentation.value.hideEmptySections &&
              !(group.id == 'system:joint' && sidebarCanCreateJoint)),
      revealEmptyDropTarget: !externalGroup,
      loading: w.loading,
      emptyLabel: switch (group.id) {
        'system:pinned' => tr('Drag channels or DMs here to pin'),
        'system:joint' => tr(
          group.label == 'External'
              ? 'No external channels yet'
              : 'No joint channels yet',
        ),
        'system:channels' => tr(
          joinedOnly ? 'No joined channels' : 'No channels yet',
        ),
        _ => '',
      },
      onExpandedChanged: (expanded) =>
          sidebarDisclosure.setExpanded(mobileAuthority, group.id, expanded),
      attention: groupAttention(group, entries),
      actions: sidebarGroupActions(group),
      onOpenMenu: (at) => sidebarMenus.openSectionMenu(at, group),
      row: (entry, reorderable) => sidebarEntry(
        entry,
        pinned: group.id == 'system:pinned',
        reorderable: reorderable,
      ),
    );
  }

  RaftNavItem sidebarLoungeRow(SidebarEntry entry) {
    final channel = entry.channel!;
    final agentId = channel.loungeAgentId!;
    final name = loungeAgentName(w, channel);
    final agent = w.services.entityDirectory.agent(agentId);
    final face = projectSenderAvatar(
      origin: w.client.origin,
      senderId: agentId,
      senderType: 'agent',
      agents: [?agent],
      members: const [],
    );
    final liveUnread = w.conversationReads.unread[channel.id];
    final scope = mobileAuthority;
    return RaftNavItem(
      key: ValueKey('sidebar-channel-${channel.id}'),
      label: entry.label,
      conversationKind: RaftConversationNavKind.directMessage,
      leading: RaftLoungeAvatar(
        name: name,
        avatarContext: RaftMountedAvatarContext.sidebarList,
        content: RaftAvatarContent(
          name: name,
          kind: RaftAvatarContentKind.agent,
          uploadedUrl: face.uploadedUrl,
          pixelKey: face.pixelKey,
          fallback: const RaftMountedAvatarFallback(
            avatarContext: RaftMountedAvatarContext.sidebarList,
            identity: RaftMountedAvatarIdentity.agent,
          ),
        ),
      ),
      menuOpen: menuOpenRow == 'c:${channel.id}',
      onContextMenu: (at) => sidebarMenus.openLoungeMenu(at, entry),
      selected: w.section == 'chat' && w.channel?.id == channel.id,
      unread: liveUnread ?? entry.loungeUnread,
      markedUnread: w.conversationReads.marks.contains(channel.id),
      mention:
          SidebarRowReads.of(w, channel).mention ||
          (liveUnread == null && entry.loungeMentioned),
      activityMuted: channel.flag('activityMuted'),
      onTap: () {
        if (scope != mobileAuthority) return;
        if (w.channelById(channel.id) != null) {
          unawaited(chooseChannel(channel, expectedScope: scope));
        } else {
          unawaited(w.jumpToMessage(channel.id, null));
        }
      },
    );
  }
}
