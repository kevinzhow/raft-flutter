// Sidebar.tsx context menus: channel / DM / agent rows, section headers and the
// sidebar surface, "Move to section", the section dialog and the confirm
// dialogs they open. Presentation is raft_ui (RaftSidebarContextMenu,
// RaftSidebarSectionDialog, RaftConfirmDialog); the actions are the Source
// ones: PATCH /servers/:id/sidebar-order for pins, placements, sections, sort
// and hidden DMs, POST /channels/:id/read-all and /unread, PATCH
// /channels/:id/notification-settings.
part of 'workspace_view.dart';

extension _SidebarContextMenus on _WorkspaceViewState {
  Map<String, dynamic> get _order => w.sidebarOrder;

  List<Map<String, dynamic>> _maps(Object? value) => [
    for (final e in (value as List? ?? const []))
      if (e is Map) Map<String, dynamic>.from(e),
  ];

  /// Source `updateSidebarOrder`: the row moves at once, the PATCH follows
  /// (with the `sectionsVersion` section writes need), a failure rolls back.
  Future<void> _patchOrder(Map<String, dynamic> data) =>
      w.updateSidebarOrder(data);

  bool _samePlacement(Map<String, dynamic> p, String kind, String id) =>
      p['kind'] == kind && p['id'] == id;

  bool _isPinned(String kind, String id) =>
      _maps(_order['pinned']).any((p) => _samePlacement(p, kind, id));

  List<Map<String, dynamic>> _placementsWithout(String kind, String id) => [
    for (final p in _maps(_order['sectionPlacements']))
      if (!_samePlacement(p, kind, id)) p,
  ];

  /// Sidebar.tsx `togglePinnedRef`: Pin appends the ref and drops the item's
  /// custom-section placements; `sectionPlacements` is only sent when one was
  /// dropped (a section write needs the sections version, a pin does not).
  Future<void> _togglePinned(
    String kind,
    String id, [
    List<(String, String)> removePlacements = const [],
  ]) {
    final pinned = _isPinned(kind, id);
    final before = _maps(_order['sectionPlacements']);
    var placements = before;
    if (!pinned) {
      for (final (k, i) in removePlacements) {
        placements = [
          for (final p in placements)
            if (!_samePlacement(p, k, i)) p,
        ];
      }
    }
    return _patchOrder({
      'pinned': pinned
          ? [
              for (final p in _maps(_order['pinned']))
                if (!_samePlacement(p, kind, id)) p,
            ]
          : [
              ..._maps(_order['pinned']),
              {'kind': kind, 'id': id},
            ],
      if (!pinned && placements.length != before.length)
        'sectionPlacements': placements,
    });
  }

  /// The pinned ref of a movable item (a human DM pins as `human`, an agent DM
  /// as `agent`, anything else as `channel`).
  (String, String) _pinRefOf(String kind, String id) {
    if (kind == 'agent') return ('agent', id);
    final dm = w.dms.where((d) => d.id == id).firstOrNull;
    if (dm == null) return ('channel', id);
    final peer = dm.string('peerId');
    return dm.string('peerType') == 'agent' ? ('agent', peer) : ('human', peer);
  }

  Future<void> _moveToPinned(String kind, String id) {
    final ref = _pinRefOf(kind, id);
    return _patchOrder({
      'sectionPlacements': _placementsWithout(kind, id),
      'pinned': _isPinned(ref.$1, ref.$2)
          ? _maps(_order['pinned'])
          : [
              ..._maps(_order['pinned']),
              {'kind': ref.$1, 'id': ref.$2},
            ],
    });
  }

  List<Map<String, dynamic>> _placeInSection(
    String kind,
    String id,
    String sectionId,
  ) {
    final rest = _placementsWithout(kind, id);
    final destination = [
      for (final p in rest)
        if (p['sectionId'] == sectionId) p,
    ]..sort((a, b) => (a['position'] as num).compareTo(b['position'] as num));
    destination.add({
      'kind': kind,
      'id': id,
      'sectionId': sectionId,
      'position': destination.length,
    });
    return [
      for (final p in rest)
        if (p['sectionId'] != sectionId) p,
      for (final (i, p) in destination.indexed) {...p, 'position': i},
    ];
  }

  Future<void> _moveToSection(String kind, String id, String sectionId) {
    final ref = _pinRefOf(kind, id);
    return _patchOrder({
      'sectionPlacements': _placeInSection(kind, id, sectionId),
      'pinned': [
        for (final p in _maps(_order['pinned']))
          if (!_samePlacement(p, ref.$1, ref.$2)) p,
      ],
    });
  }

  Future<void> _createSection(
    String name,
    String? emoji,
    (String, String)? moveItem,
  ) {
    final id =
        'section-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    final sections = _maps(_order['customSections']);
    final sectionOrder = [
      for (final e in (_order['sectionOrder'] as List? ?? const [])) '$e',
    ];
    final ref = moveItem == null ? null : _pinRefOf(moveItem.$1, moveItem.$2);
    return _patchOrder({
      'customSections': [
        ...sections,
        {'id': id, 'name': name, 'emoji': emoji, 'sortMode': 'manual'},
      ],
      'sectionOrder': [
        if (sectionOrder.isEmpty) ...[
          'system:pinned',
          'system:joint',
          'system:channels',
          'system:dms',
        ] else
          ...sectionOrder,
        id,
      ],
      'sectionPlacements': moveItem == null
          ? _maps(_order['sectionPlacements'])
          : _placeInSection(moveItem.$1, moveItem.$2, id),
      'pinned': ref == null
          ? _maps(_order['pinned'])
          : [
              for (final p in _maps(_order['pinned']))
                if (!_samePlacement(p, ref.$1, ref.$2)) p,
            ],
    });
  }

  // ---- presentation ------------------------------------------------------

  Future<void> _openSidebarMenu(
    Offset at,
    List<RaftSidebarMenuEntry> Function(VoidCallback close) entries, {
    double width = 192,
    List<RaftSidebarMenuEntry> Function(VoidCallback close)? submenu,
    String? label,
    String? row,
  }) {
    setMenuOpenRow(row);
    return _showSidebarMenu(
      at,
      entries,
      width: width,
      submenu: submenu,
      label: label,
    ).whenComplete(() => setMenuOpenRow(null));
  }

  Future<void> _showSidebarMenu(
    Offset at,
    List<RaftSidebarMenuEntry> Function(VoidCallback close) entries, {
    required double width,
    List<RaftSidebarMenuEntry> Function(VoidCallback close)? submenu,
    String? label,
  }) => showRaftMessageContextMenu<void>(
    context: context,
    anchor: at,
    builder: (menuContext) {
      void close() => Navigator.of(menuContext).pop();
      return RaftSidebarContextMenu(
        entries: entries(close),
        width: width,
        label: label,
        submenuEntries: submenu?.call(close),
        onDismiss: close,
      );
    },
  );

  RaftSidebarMenuItem _item(
    String label,
    RaftGlyph glyph,
    VoidCallback close,
    FutureOr<void> Function() action, {
    String? key,
    bool checked = false,
  }) => RaftSidebarMenuItem(
    itemKey: key == null ? null : ValueKey(key),
    label: tr(label),
    glyph: glyph,
    checked: checked,
    onPressed: () {
      close();
      unawaited(Future.sync(action));
    },
  );

  /// Sidebar.tsx `renderReadToggleAction`: Mark as Read posts read-all and
  /// clears the count; Mark as Unread shows the dot first. A failure only
  /// reloads the unread counts (no message).
  Future<void> _toggleRead(String id) async {
    final unread = (w.conversationReads.unread[id] ?? 0) > 0;
    if (!unread) w.markUnreadLocally(id);
    try {
      final receipt = await w.command(
        'POST',
        '/channels/$id/${unread ? 'read-all' : 'unread'}',
      );
      if (!mounted) return;
      final principal = w.client.user?.id, serverId = w.client.serverId;
      if (unread && principal != null && serverId != null) {
        w.conversationReads.acceptReadAllAck(
          id,
          receipt,
          serverId: serverId,
          principalId: principal,
        );
      }
    } catch (_) {
      if (mounted) unawaited(w.refreshUnread());
    }
  }

  /// Sidebar.tsx `toggleChannelActivityMute`: optimistic, PATCH, adopt the
  /// reply; a failure restores the row (when still untouched) and toasts.
  Future<void> _toggleMute(RaftChannel c) async {
    if (!_canMute(c)) return;
    final previous = {
      'activityMuted': c.flag('activityMuted'),
      'muteFromSeq': c.json['muteFromSeq'],
      'prefsVersion': c.json['prefsVersion'],
    };
    final next = !(previous['activityMuted'] as bool);
    final optimistic = {...previous, 'activityMuted': next};
    w.setActivityMuteState(c.id, optimistic);
    try {
      final reply = await w.command(
        'PATCH',
        '/channels/${c.id}/notification-settings',
        data: {'activityMuted': next},
      );
      if (!mounted || reply is! Map) return;
      w.setActivityMuteState(c.id, {
        'activityMuted': reply['activityMuted'] == true,
        'muteFromSeq': reply['muteFromSeq'],
        'prefsVersion': reply['prefsVersion'],
      });
    } catch (_) {
      final held = w.channelById(c.id);
      if (held != null &&
          held.flag('activityMuted') == next &&
          held.json['prefsVersion'] == previous['prefsVersion']) {
        w.setActivityMuteState(c.id, previous);
        if (mounted) {
          rowToast.show(
            tr(
              next
                  ? 'Failed to mute Activity for this channel.'
                  : 'Failed to unmute Activity for this channel.',
            ),
          );
        }
      }
    }
  }

  /// Source `canToggleActivityMute`: channel / private / joint rows the user
  /// has joined (never DMs or threads).
  bool _canMute(RaftChannel c) =>
      c.joined && const {'channel', 'private', 'joint'}.contains(c.type);

  /// Sidebar.tsx `closeDm`: hides the DM (server-synced) and leaves it when
  /// it is the open conversation.
  Future<void> _closeDm(String id) async {
    final hidden = [
      for (final e in (_order['hiddenDmIds'] as List? ?? const [])) '$e',
    ];
    if (hidden.contains(id)) return;
    final open = w.section == 'chat' && w.channel?.id == id;
    final update = _patchOrder({
      'hiddenDmIds': [...hidden, id],
    });
    if (open) {
      // Sidebar.tsx closeDm `navigate('/s/<slug>')`: wide layouts close the
      // detail pane, a phone returns to the Home list.
      if (wide) {
        dismissPanel();
      } else {
        select('home');
      }
    }
    await update;
  }

  /// Sidebar.tsx archive ConfirmDialog: stays open on "Archiving…", closes
  /// when the archive succeeded and shows the error under the message when
  /// it failed.
  Future<void> _confirmArchive(RaftChannel c) => RaftConfirmDialog.show(
    context,
    RaftConfirmDialog(
      surfaceKey: const ValueKey('shell-dialog'),
      title: tr('Archive Channel'),
      message: raftFormat(
        context,
        'Archive "{name}"? Members keep read access and history, but writes will be frozen and the channel will be hidden from sidebars. You can unarchive it later.',
        {'name': c.name},
      ),
      confirmLabel: tr('Archive Channel'),
      loadingLabel: tr('Archiving…'),
      confirmVariant: RaftButtonRecipeVariant.warning,
      onConfirm: () async {
        await w.command('POST', '/channels/${c.id}/archive');
        if (mounted) await w.refreshChannels();
      },
    ),
  );

  Future<void> _showSectionDialog({
    Map<String, dynamic>? edit,
    (String, String)? moveItem,
  }) => showRaftSidebarSectionDialog(
    context,
    cardKey: const ValueKey('sidebar-section-dialog'),
    title: edit == null ? 'New section' : 'Edit section',
    submitLabel: edit == null ? 'Create section' : 'Save',
    initialName: '${edit?['name'] ?? ''}',
    initialEmoji: '${edit?['emoji'] ?? ''}',
    onSubmit: (name, emoji) {
      if (edit == null) {
        unawaited(_createSection(name, emoji, moveItem));
      } else {
        unawaited(
          _patchOrder({
            'customSections': [
              for (final s in _maps(_order['customSections']))
                s['id'] == edit['id']
                    ? {...s, 'name': name, 'emoji': emoji}
                    : s,
            ],
          }),
        );
      }
    },
  );

  Future<void> _confirmDeleteSection(Map<String, dynamic> section) async {
    final ok = await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: const ValueKey('shell-dialog'),
        title: tr('Delete section'),
        message: raftFormat(
          context,
          'Delete "{name}"? Its conversations will return to their default sections.',
          {'name': '${section['name']}'},
        ),
        confirmLabel: tr('Delete section'),
      ),
    );
    if (ok != true || !mounted) return;
    await _patchOrder({
      'customSections': [
        for (final s in _maps(_order['customSections']))
          if (s['id'] != section['id']) s,
      ],
      'sectionOrder': [
        for (final e in (_order['sectionOrder'] as List? ?? const []))
          if (e != section['id']) '$e',
      ],
      'sectionPlacements': [
        for (final p in _maps(_order['sectionPlacements']))
          if (p['sectionId'] != section['id']) p,
      ],
    });
  }

  // ---- menus -------------------------------------------------------------

  List<RaftSidebarMenuEntry> Function(VoidCallback) _moveSubmenu(
    String kind,
    String id,
  ) => (close) {
    final ref = _pinRefOf(kind, id);
    final pinned = _isPinned(ref.$1, ref.$2);
    final placement = _maps(_order['sectionPlacements'])
        .where((p) => _samePlacement(p, kind, id))
        .firstOrNull;
    return [
      RaftSidebarMenuItem(
        itemKey: const ValueKey('sidebar-menu-move-pinned'),
        label: tr('Pinned'),
        glyph: RaftGlyph.pin,
        checked: pinned,
        onPressed: pinned
            ? null
            : () {
                close();
                unawaited(_moveToPinned(kind, id));
              },
      ),
      for (final s in _maps(_order['customSections']))
        RaftSidebarMenuItem(
          label: '${s['emoji'] ?? ''} ${s['name']}'.trim(),
          glyph: RaftGlyph.folderInput,
          checked: placement?['sectionId'] == s['id'],
          onPressed: () {
            close();
            unawaited(_moveToSection(kind, id, '${s['id']}'));
          },
        ),
      const RaftSidebarMenuDivider(),
      RaftSidebarMenuItem(
        label: tr('New section…'),
        glyph: RaftGlyph.folderPlus,
        onPressed: () {
          close();
          unawaited(_showSectionDialog(moveItem: (kind, id)));
        },
      ),
      if (placement != null)
        RaftSidebarMenuItem(
          label: tr('Remove from section'),
          glyph: RaftGlyph.x,
          onPressed: () {
            close();
            unawaited(
              _patchOrder({'sectionPlacements': _placementsWithout(kind, id)}),
            );
          },
        ),
    ];
  };

  RaftSidebarMenuItem _moveItem() => RaftSidebarMenuItem(
    itemKey: const ValueKey('sidebar-menu-move-to-section'),
    label: tr('Move to section'),
    glyph: RaftGlyph.folderInput,
    submenu: true,
  );

  RaftSidebarMenuItem _readItem(String? dmOrChannelId, VoidCallback close) =>
      _item(
        (w.conversationReads.unread[dmOrChannelId] ?? 0) > 0
            ? 'Mark as Read'
            : 'Mark as Unread',
        (w.conversationReads.unread[dmOrChannelId] ?? 0) > 0
            ? RaftGlyph.messageSquareCheck
            : RaftGlyph.messageSquareDot,
        close,
        () => _toggleRead(dmOrChannelId!),
      );

  Future<void> openChannelMenu(Offset at, RaftChannel c) {
    if (c.type == 'dm') return openDmMenu(at, c);
    final pinned = _isPinned('channel', c.id);
    final canMute = _canMute(c);
    final canArchive =
        w.can('archiveChannels', resource: c) &&
        c.name != 'all' &&
        c.type != 'joint' &&
        !c.archived;
    return _openSidebarMenu(
      at,
      (close) => [
        _moveItem(),
        const RaftSidebarMenuDivider(),
        _readItem(c.id, close),
        _item(
          pinned ? 'Unpin' : 'Pin',
          pinned ? RaftGlyph.pinOff : RaftGlyph.pin,
          close,
          () => _togglePinned('channel', c.id, [('channel', c.id)]),
        ),
        if (canMute)
          _item(
            c.flag('activityMuted') ? 'Unmute' : 'Mute',
            c.flag('activityMuted') ? RaftGlyph.bell : RaftGlyph.bellOff,
            close,
            () => _toggleMute(c),
          ),
        if (canArchive) ...[
          const RaftSidebarMenuDivider(),
          _item(
            'Archive',
            RaftGlyph.archive,
            close,
            () => _confirmArchive(c),
            key: 'sidebar-menu-archive',
          ),
        ],
      ],
      submenu: _moveSubmenu('channel', c.id),
      row: 'c:${c.id}',
    );
  }

  Future<void> openDmMenu(Offset at, RaftChannel dm) {
    final agent = dm.string('peerType') == 'agent';
    final ref = _pinRefOf('channel', dm.id);
    final pinned = _isPinned(ref.$1, ref.$2);
    return _openSidebarMenu(
      at,
      (close) => [
        _moveItem(),
        const RaftSidebarMenuDivider(),
        _readItem(dm.id, close),
        _item(
          pinned ? 'Unpin' : 'Pin',
          pinned ? RaftGlyph.pinOff : RaftGlyph.pin,
          close,
          () => _togglePinned(ref.$1, ref.$2, [
            ('channel', dm.id),
            if (agent) ('agent', ref.$2),
          ]),
        ),
        const RaftSidebarMenuDivider(),
        _item('Close Chat', RaftGlyph.x, close, () => _closeDm(dm.id)),
      ],
      submenu: _moveSubmenu('channel', dm.id),
      row: 'c:${dm.id}',
    );
  }

  Future<void> openAgentMenu(
    Offset at,
    Map<String, dynamic> agent,
    RaftChannel? dm,
  ) {
    final id = '${agent['id']}';
    final pinned = _isPinned('agent', id);
    // Sidebar.tsx `contextMovableItem` (agent): the agent itself while it is
    // pinned or placed as an agent, else its DM channel.
    final movable =
        pinned ||
            _maps(_order['sectionPlacements'])
                .any((p) => _samePlacement(p, 'agent', id)) ||
            dm == null
        ? ('agent', id)
        : ('channel', dm.id);
    return _openSidebarMenu(
      at,
      (close) => [
        _moveItem(),
        const RaftSidebarMenuDivider(),
        if (dm != null) _readItem(dm.id, close),
        _item(
          pinned ? 'Unpin' : 'Pin',
          pinned ? RaftGlyph.pinOff : RaftGlyph.pin,
          close,
          () => _togglePinned('agent', id, [
            ('agent', id),
            if (dm != null) ('channel', dm.id),
          ]),
        ),
        if (dm != null) ...[
          const RaftSidebarMenuDivider(),
          _item('Close Chat', RaftGlyph.x, close, () => _closeDm(dm.id)),
        ],
      ],
      submenu: _moveSubmenu(movable.$1, movable.$2),
      row: 'a:$id',
    );
  }

  static const _sortKeys = {
    'system:pinned': 'pinnedSortMode',
    'system:joint': 'jointChannelSortMode',
    'system:channels': 'channelSortMode',
    'system:dms': 'dmSortMode',
  };

  Future<void> openSectionMenu(Offset at, SidebarGroup group) {
    final custom = group.custom
        ? _maps(_order['customSections'])
              .where((s) => s['id'] == group.id)
              .firstOrNull
        : null;
    final sortKey = _sortKeys[group.id];
    final current = custom != null
        ? '${custom['sortMode'] ?? 'manual'}'
        : '${_order[sortKey] ?? 'manual'}';
    final canCreate = group.id == 'system:channels' && w.can('createChannels');
    final canCreateJoint =
        group.id == 'system:joint' && w.can('federateChannels');
    return _openSidebarMenu(
      at,
      (close) => [
        if (canCreate) ...[
          _item('Create Channel', RaftGlyph.plus, close, createChannel),
          const RaftSidebarMenuDivider(),
        ],
        if (canCreateJoint) ...[
          _item(
            'Create Joint Channel',
            RaftGlyph.gitBranch,
            close,
            createJointChannel,
          ),
          const RaftSidebarMenuDivider(),
        ],
        RaftSidebarMenuHeading(tr('Sort')),
        for (final (mode, label) in const [
          ('manual', 'Manual'),
          ('recent', 'Recent'),
          ('az', 'A-Z'),
        ])
          RaftSidebarMenuItem(
            label: tr(label),
            checked: mode == current,
            onPressed: () {
              close();
              if (custom != null) {
                unawaited(
                  _patchOrder({
                    'customSections': [
                      for (final s in _maps(_order['customSections']))
                        s['id'] == custom['id'] ? {...s, 'sortMode': mode} : s,
                    ],
                  }),
                );
              } else if (sortKey != null) {
                unawaited(_patchOrder({sortKey: mode}));
              }
            },
          ),
        const RaftSidebarMenuDivider(),
        RaftSidebarMenuHeading(tr('Display')),
        if (group.id == 'system:channels')
          RaftSidebarMenuItem(
            label: tr('Show joined channels only'),
            checked: sidebarDisclosure.joinedChannelsOnly,
            onPressed: () {
              close();
              sidebarDisclosure.setJoinedChannelsOnly(
                mobileAuthority,
                !sidebarDisclosure.joinedChannelsOnly,
              );
            },
          ),
        RaftSidebarMenuItem(
          label: tr('Hide empty sections'),
          checked: presentation.value.hideEmptySections,
          onPressed: () {
            close();
            presentation.update(
              mobileAuthority,
              hideEmptySections: !presentation.value.hideEmptySections,
            );
          },
        ),
        const RaftSidebarMenuDivider(),
        if (custom != null)
          RaftSidebarMenuItem(
            itemKey: const ValueKey('sidebar-menu-rename-section'),
            label: tr('Rename / change icon…'),
            glyph: RaftGlyph.pencil,
            onPressed: () {
              close();
              unawaited(_showSectionDialog(edit: custom));
            },
          ),
        RaftSidebarMenuItem(
          itemKey: const ValueKey('sidebar-menu-new-section'),
          label: tr('New section…'),
          glyph: RaftGlyph.folderPlus,
          onPressed: () {
            close();
            unawaited(_showSectionDialog());
          },
        ),
        if (custom != null) ...[
          const RaftSidebarMenuDivider(),
          RaftSidebarMenuItem(
            itemKey: const ValueKey('sidebar-menu-delete-section'),
            label: tr('Delete section'),
            glyph: RaftGlyph.trash2,
            onPressed: () {
              close();
              unawaited(_confirmDeleteSection(custom));
            },
          ),
        ],
      ],
      width: 256,
      label: 'Section options',
    );
  }

  Future<void> openSurfaceMenu(Offset at) => _openSidebarMenu(
    at,
    (close) => [
      if (w.can('editServerSettings'))
        _item('Create Channel', RaftGlyph.plus, close, createChannel),
      if (w.can('federateChannels'))
        _item(
          'Create Joint Channel',
          RaftGlyph.gitBranch,
          close,
          createJointChannel,
        ),
      if (w.can('editServerSettings') || w.can('federateChannels'))
        const RaftSidebarMenuDivider(),
      RaftSidebarMenuItem(
        itemKey: const ValueKey('sidebar-menu-new-section'),
        label: tr('New section…'),
        glyph: RaftGlyph.folderPlus,
        onPressed: () {
          close();
          unawaited(_showSectionDialog());
        },
      ),
    ],
    width: 256,
    label: 'Sidebar options',
  );
}
