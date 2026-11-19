// Sidebar.tsx context menus: channel / DM / agent rows, section headers and the
// sidebar surface, "Move to section", the section dialog and the confirm
// dialogs they open. Presentation is raft_ui (RaftSidebarContextMenu,
// RaftSidebarSectionDialog, RaftConfirmDialog); the actions are the Source
// ones: PATCH /servers/:id/sidebar-order for pins, placements, sections, sort
// and hidden DMs, POST /channels/:id/read-all and /unread, PATCH
// /channels/:id/notification-settings.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/personal_presentation.dart';
import '../data/sidebar_disclosure.dart';
import '../data/workspace_controller.dart';
import 'notification_level_menu.dart' show channelNotificationSubmenu;
import 'sidebar_projection.dart';
import 'sidebar_read_all.dart';
import 'sidebar_reorder.dart' show sidebarSectionOrder;

class WorkspaceSidebarMenus {
  const WorkspaceSidebarMenus({
    required this.context,
    required this.w,
    required this.currentAuthority,
    required this.presentation,
    required this.sidebarDisclosure,
    required this.rowToast,
    required this.setMenuOpenRow,
    required this.closeConversation,
    required this.createChannel,
    required this.createJointChannel,
    required this.sidebarExternalEnabled,
    required this.sidebarCanCreateJoint,
    required this.sidebarCreateJointLabel,
  });

  final BuildContext context;
  final WorkspaceController w;
  final String Function() currentAuthority;
  final PersonalPresentationStore presentation;
  final SidebarDisclosureStore sidebarDisclosure;
  final RaftToastController rowToast;
  final ValueChanged<String?> setMenuOpenRow;
  final VoidCallback closeConversation;
  final Future<void> Function() createChannel, createJointChannel;
  final bool sidebarExternalEnabled, sidebarCanCreateJoint;
  final String sidebarCreateJointLabel;

  bool get mounted => context.mounted;
  String get mobileAuthority => currentAuthority();
  String tr(String label) => raftText(context, label);
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
    String sectionId, {
    List<Map<String, dynamic>>? previous,
  }) {
    final rest = [
      for (final placement in previous ?? _maps(_order['sectionPlacements']))
        if (!_samePlacement(placement, kind, id)) placement,
    ];
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

  String _createSection(
    String name,
    String? emoji,
    (String, String)? moveItem,
    String? insertBefore,
  ) {
    final id =
        'section-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    final sections = _maps(_order['customSections']);
    final sectionOrder = sidebarSectionOrder(_order).toList();
    final index = sectionOrder.indexOf(insertBefore ?? '');
    sectionOrder.insert(index < 0 ? sectionOrder.length : index, id);
    final ref = moveItem == null ? null : _pinRefOf(moveItem.$1, moveItem.$2);
    unawaited(
      _patchOrder({
        'customSections': [
          ...sections,
          {'id': id, 'name': name, 'emoji': emoji, 'sortMode': 'manual'},
        ],
        'sectionOrder': sectionOrder,
        'sectionPlacements': moveItem == null
            ? _maps(_order['sectionPlacements'])
            : _placeInSection(moveItem.$1, moveItem.$2, id),
        'pinned': ref == null
            ? _maps(_order['pinned'])
            : [
                for (final p in _maps(_order['pinned']))
                  if (!_samePlacement(p, ref.$1, ref.$2)) p,
              ],
      }),
    );
    return id;
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
      return RaftSidebarContextMenu.sidebar(
        entries: entries(close),
        legacyWidth: width,
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
                  ? 'Failed to mute Activity for this conversation.'
                  : 'Failed to unmute Activity for this conversation.',
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
      closeConversation();
    }
    await update;
  }

  /// Sidebar.tsx archive ConfirmDialog: stays open on "Archiving…", closes
  /// when the archive succeeded and shows the error under the message when
  /// it failed.
  Future<void> _confirmArchive(RaftChannel c) {
    final scope = mobileAuthority;
    return RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: const ValueKey('shell-dialog'),
        title: tr('Archive channel'),
        message: raftFormat(
          context,
          'Archive "{name}"? Members keep read access and history, but writes will be frozen and the channel will be hidden from sidebars. You can unarchive it later.',
          {'name': c.name},
        ),
        confirmLabel: tr('Archive'),
        loadingLabel: tr('Archiving…'),
        confirmVariant: RaftButtonRecipeVariant.warning,
        onConfirm: () async {
          if (scope != mobileAuthority ||
              !w.can('archiveChannels', resource: c)) {
            throw const RaftUserError(
              'Server access changed. Reopen this form.',
            );
          }
          final receipt = await w.command('POST', '/channels/${c.id}/archive');
          if (!mounted || scope != mobileAuthority || receipt is! Map) return;
          final current = w.channelById(c.id);
          if (current != null) {
            w.putSharedChannelRow(RaftChannel({...current.json, ...receipt}));
          }
        },
      ),
    );
  }

  Future<void> _confirmLeave(RaftChannel channel) async {
    final scope = mobileAuthority;
    final roster = channel.type == 'private'
        ? w.query('/channels/${channel.id}/members')
        : null;
    await showRaftDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => FutureBuilder(
        future: roster,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final memberCount = data is Map
              ? _maps(data['humans']).length + _maps(data['agents']).length
              : 0;
          final deletes = channel.type == 'private' && memberCount <= 1;
          final description = switch (channel.type) {
            'private' => "You'll stop getting messages from #{name} and can't post there. To come back, a member has to invite you again.",
            'joint' => "You'll stop getting messages from #{name} and can't post there. To come back, an admin has to invite you again.",
            _ => "You'll stop getting messages from #{name} and can't post there. You can rejoin any time. Threads you follow will still notify you until you unfollow them.",
          };
          return RaftConfirmDialog(
            surfaceKey: const ValueKey('sidebar-channel-leave-confirmation'),
            title: tr(deletes ? 'Leave and delete channel?' : 'Leave channel'),
            message: raftFormat(
              context,
              deletes
                  ? 'You are the last member of this private channel. When you leave, the channel and its messages are deleted and cannot be recovered.'
                  : description,
              {'name': channel.name},
            ),
            confirmLabel: tr(deletes ? 'Leave and delete' : 'Leave'),
            confirmVariant: deletes
                ? RaftButtonRecipeVariant.danger
                : RaftButtonRecipeVariant.warning,
            loadingLabel: tr('Leaving…'),
            onConfirm: () async {
              final current = w.channelById(channel.id);
              if (scope != mobileAuthority ||
                  current == null ||
                  !current.joined ||
                  current.archived ||
                  current.name == 'all') {
                throw const RaftUserError(
                  'Server access changed. Reopen this form.',
                );
              }
              await w.command('POST', '/channels/${channel.id}/leave');
              if (!mounted || scope != mobileAuthority) return;
              final row = w.channelById(channel.id);
              if (row != null) {
                w.putSharedChannelRow(
                  RaftChannel({...row.json, 'joined': false}),
                );
              }
            },
          );
        },
      ),
    );
  }

  Future<void> _showSectionDialog({
    Map<String, dynamic>? edit,
    (String, String)? moveItem,
    String? insertBefore,
  }) {
    final scope = mobileAuthority;
    final sectionId = edit?['id'] as String?;
    final candidates = _sectionCandidates();
    final initial = sectionId == null
        ? <String>{}
        : _sectionSelection(sectionId);
    var selected = initial;
    return showRaftSidebarSectionDialog(
      context,
      cardKey: const ValueKey('sidebar-section-dialog'),
      title: edit == null ? 'New section' : 'Edit section',
      submitLabel: edit == null ? 'Create' : 'Save',
      stepLabel: edit == null ? 'Step 1 of 2' : null,
      initialName: '${edit?['name'] ?? ''}',
      initialEmoji: '${edit?['emoji'] ?? ''}',
      conversations: edit == null
          ? null
          : RaftSidebarConversationPicker(
              candidates: candidates,
              initialSelection: initial,
              onChanged: (value) => selected = value,
            ),
      onSubmit: (name, emoji) {
        if (!_sectionAccess(scope, sectionId)) return;
        if (sectionId == null) {
          final created = _createSection(name, emoji, moveItem, insertBefore);
          unawaited(_showAddConversations(created, name, scope));
          return;
        }
        unawaited(
          _patchOrder({
            'customSections': [
              for (final section in _maps(_order['customSections']))
                section['id'] == sectionId
                    ? {...section, 'name': name, 'emoji': emoji}
                    : section,
            ],
            ..._sectionConversationChanges(sectionId, initial, selected),
          }),
        );
      },
    );
  }

  bool _sectionAccess(String scope, String? sectionId) {
    if (!mounted) return false;
    if (scope == mobileAuthority &&
        (sectionId == null ||
            _maps(_order['customSections'])
                .any((section) => section['id'] == sectionId))) {
      return true;
    }
    rowToast.show(tr('This section is no longer available.'));
    return false;
  }

  Map<String, String> _sectionCandidates() {
    final hidden = (_order['hiddenDmIds'] as List? ?? const []).toSet();
    final joinedOnly = sidebarDisclosure.joinedChannelsOnly;
    return {
      for (final channel in w.channels)
        if (!channel.archived &&
            channel.loungeAgentId == null &&
            (sidebarExternalSectionChannel(channel) ||
                !joinedOnly ||
                channel.joined))
          channel.id: channel.name,
      for (final dm in w.dms)
        if (!hidden.contains(dm.id)) dm.id: dm.peerLabel,
    };
  }

  Set<String> _sectionSelection(String sectionId) => {
    for (final placement in _maps(_order['sectionPlacements']))
      if (placement['sectionId'] == sectionId && placement['kind'] == 'channel')
        placement['id'] as String,
  };

  Map<String, dynamic> _sectionConversationChanges(
    String sectionId,
    Set<String> initial,
    Set<String> selected,
  ) {
    final removed = initial.difference(selected);
    final added = selected.difference(initial);
    if (removed.isEmpty && added.isEmpty) return {};
    var placements = [
      for (final placement in _maps(_order['sectionPlacements']))
        if (placement['sectionId'] != sectionId ||
            placement['kind'] != 'channel' ||
            !removed.contains(placement['id']))
          placement,
    ];
    final unpin = <(String, String)>{};
    final candidates = _sectionCandidates();
    for (final id in added.where(candidates.containsKey)) {
      placements = _placeInSection(
        'channel',
        id,
        sectionId,
        previous: placements,
      );
      unpin.add(_pinRefOf('channel', id));
    }
    return {
      'sectionPlacements': placements,
      'pinned': [
        for (final ref in _maps(_order['pinned']))
          if (!unpin.contains((ref['kind'], ref['id']))) ref,
      ],
    };
  }

  Future<void> _showAddConversations(
    String sectionId,
    String name,
    String scope,
  ) async {
    final initial = _sectionSelection(sectionId);
    final picked = await showRaftSidebarAddConversations(
      context,
      name: name,
      candidates: _sectionCandidates(),
      initial: initial,
    );
    if (picked == null || !_sectionAccess(scope, sectionId)) return;
    final changes = _sectionConversationChanges(sectionId, initial, picked);
    if (changes.isNotEmpty) await _patchOrder(changes);
  }

  Future<void> _confirmDeleteSection(Map<String, dynamic> section) async {
    final ok = await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: const ValueKey('shell-dialog'),
        title: tr('Delete Section'),
        message: raftFormat(
          context,
          'Delete "{name}"? Its conversations will return to their default sections.',
          {'name': '${section['name']}'},
        ),
        confirmLabel: tr('Delete Section'),
        cancelLabel: tr('Keep Section'),
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
        label: tr('New Section…'),
        glyph: RaftGlyph.folderPlus,
        onPressed: () {
          close();
          unawaited(_showSectionDialog(moveItem: (kind, id)));
        },
      ),
      if (placement != null)
        RaftSidebarMenuItem(
          label: tr('Remove from Section'),
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
    label: tr('Move to Section'),
    glyph: RaftGlyph.folderInput,
    submenu: true,
  );

  RaftSidebarMenuItem _readItem(
    String? dmOrChannelId,
    VoidCallback close, {
    bool channel = false,
    int summaryUnread = 0,
  }) {
    final toggle = SidebarReadToggle(
      w,
      '$dmOrChannelId',
      channel: channel,
      summaryUnread: summaryUnread,
    );
    return _item(
      toggle.label,
      toggle.unread ? RaftGlyph.messageSquareCheck : RaftGlyph.messageSquareDot,
      close,
      toggle.run,
    );
  }

  Future<void> openChannelMenu(Offset at, RaftChannel c) {
    if (c.type == 'dm') return openDmMenu(at, c);
    final pinned = _isPinned('channel', c.id);
    final canMute = _canMute(c);
    final canArchive =
        w.can('archiveChannels', resource: c) &&
        c.name != 'all' &&
        c.type != 'joint' &&
        !c.archived;
    final canLeave = c.joined && c.name != 'all' && !c.archived;
    return _openSidebarMenu(
      at,
      (close) => [
        _moveItem(),
        const RaftSidebarMenuDivider(),
        _readItem(c.id, close, channel: c.joined),
        _item(
          pinned ? 'Unpin' : 'Pin',
          pinned ? RaftGlyph.pinOff : RaftGlyph.pin,
          close,
          () => _togglePinned('channel', c.id, [('channel', c.id)]),
        ),
        // Web NotificationLevelSubmenu: the level and the Activity mute are
        // one choice, in place of the bare Mute row.
        if (channelNotificationSubmenu(
              context: context,
              workspace: w,
              channel: c,
              canMute: canMute,
              toggleMute: () => _toggleMute(c),
              close: close,
              onFailed: (message) => rowToast.show(tr(message)),
            )
            case final item?)
          item
        else if (canMute)
          _item(
            c.flag('activityMuted') ? 'Unmute' : 'Mute',
            c.flag('activityMuted') ? RaftGlyph.bell : RaftGlyph.bellOff,
            close,
            () => _toggleMute(c),
          ),
        if (canArchive || canLeave) const RaftSidebarMenuDivider(),
        if (canArchive)
          _item(
            'Archive channel',
            RaftGlyph.archive,
            close,
            () => _confirmArchive(c),
            key: 'sidebar-menu-archive',
          ),
        if (canLeave)
          _item(
            'Leave channel',
            switch (c.type) {
              'private' => RaftGlyph.leavePrivateChannel,
              'joint' => RaftGlyph.leaveJointChannel,
              _ => RaftGlyph.leaveChannel,
            },
            close,
            () => _confirmLeave(c),
            key: 'sidebar-menu-leave',
          ),
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
        _item('Close chat', RaftGlyph.x, close, () => _closeDm(dm.id)),
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
          _item('Close chat', RaftGlyph.x, close, () => _closeDm(dm.id)),
        ],
      ],
      submenu: _moveSubmenu(movable.$1, movable.$2),
      row: 'a:$id',
    );
  }

  Future<void> openLoungeMenu(Offset at, SidebarEntry entry) {
    final channel = entry.channel!;
    final id = channel.id;
    final pinned = _isPinned('channel', id);
    return _openSidebarMenu(
      at,
      (close) => [
        _readItem(
          id,
          close,
          channel: channel.joined,
          summaryUnread: entry.loungeUnread,
        ),
        _item(
          pinned ? 'Unpin' : 'Pin',
          pinned ? RaftGlyph.pinOff : RaftGlyph.pin,
          close,
          () => _togglePinned('channel', id, [('channel', id)]),
        ),
        if (_canMute(channel))
          _item(
            channel.flag('activityMuted') ? 'Unmute' : 'Mute',
            channel.flag('activityMuted') ? RaftGlyph.bell : RaftGlyph.bellOff,
            close,
            () => _toggleMute(channel),
          ),
        const RaftSidebarMenuDivider(),
        _item('Close chat', RaftGlyph.x, close, () => _closeDm(id)),
      ],
      row: 'c:$id',
    );
  }

  static const _sortKeys = {
    'system:pinned': 'pinnedSortMode',
    'system:joint': 'jointChannelSortMode',
    'system:channels': 'channelSortMode',
    'system:dms': 'dmSortMode',
  };

  Future<void> openSectionMenu(Offset at, SidebarGroup group) {
    final presentationKey = presentation.key;
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
    final canCreateJoint = group.id == 'system:joint' && sidebarCanCreateJoint;
    return _openSidebarMenu(
      at,
      (close) => [
        if (canCreate) ...[
          _item('Create Channel', RaftGlyph.plus, close, createChannel),
          const RaftSidebarMenuDivider(),
        ],
        if (canCreateJoint) ...[
          _item(
            sidebarCreateJointLabel,
            sidebarExternalEnabled ? RaftGlyph.globe : RaftGlyph.gitBranch,
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
            label: tr('Show Joined Channels Only'),
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
          label: tr('Hide Empty Sections'),
          checked: presentation.value.hideEmptySections,
          onPressed: () {
            close();
            presentation.update(
              presentationKey,
              hideEmptySections: !presentation.value.hideEmptySections,
            );
          },
        ),
        const RaftSidebarMenuDivider(),
        if (custom != null)
          RaftSidebarMenuItem(
            itemKey: const ValueKey('sidebar-menu-rename-section'),
            label: tr('Edit section'),
            glyph: RaftGlyph.pencil,
            onPressed: () {
              close();
              unawaited(_showSectionDialog(edit: custom));
            },
          ),
        RaftSidebarMenuItem(
          itemKey: const ValueKey('sidebar-menu-new-section'),
          label: tr('New Section…'),
          glyph: RaftGlyph.folderPlus,
          onPressed: () {
            close();
            unawaited(_showSectionDialog(insertBefore: group.id));
          },
        ),
        if (custom != null) ...[
          const RaftSidebarMenuDivider(),
          RaftSidebarMenuItem(
            itemKey: const ValueKey('sidebar-menu-delete-section'),
            label: tr('Delete Section'),
            glyph: RaftGlyph.trash2,
            onPressed: () {
              close();
              unawaited(_confirmDeleteSection(custom));
            },
          ),
        ],
      ],
      width: 256,
      label: 'Section Options',
    );
  }

  Future<void> openSurfaceMenu(Offset at) => _openSidebarMenu(
    at,
    (close) => [
      if (w.can('editServerSettings'))
        _item('Create Channel', RaftGlyph.plus, close, createChannel),
      if (sidebarCanCreateJoint)
        _item(
          sidebarCreateJointLabel,
          sidebarExternalEnabled ? RaftGlyph.globe : RaftGlyph.gitBranch,
          close,
          createJointChannel,
        ),
      if (w.can('editServerSettings') || sidebarCanCreateJoint)
        const RaftSidebarMenuDivider(),
      RaftSidebarMenuItem(
        itemKey: const ValueKey('sidebar-menu-new-section'),
        label: tr('New Section…'),
        glyph: RaftGlyph.folderPlus,
        onPressed: () {
          close();
          unawaited(_showSectionDialog());
        },
      ),
    ],
    width: 256,
    label: 'Sidebar Options',
  );
}
