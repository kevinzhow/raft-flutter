// Source: packages/web/src/components/notifications/NotificationLevelMenu.tsx
// at v1.24.0-source.1 (1d689caf). The notification level picker (design
// §4.3, contract §1.1), as in Slack: a server's level lives in Settings ›
// Notifications; a channel can override it (All new messages / Only what
// involves me / Mute) from its ⋯ sheet and the sidebar menu. Threads have no
// level, only Follow / Unfollow; DMs only Mute. Every write goes through PUT
// /notification-levels (NotificationSettingsStore.setLevel); what `default`
// inherits is computed with the shared resolver, so the label says exactly
// what the server's policy applies.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/notification_levels.dart';
import '../data/notification_settings_store.dart';
import '../data/workspace_controller.dart';

/// What a picker offers: a level, or (channels) Mute.
enum NotificationLevelChoice {
  all,
  mentions,
  none,
  mute;

  static NotificationLevelChoice of(NotificationLevel level) => switch (level) {
    NotificationLevel.all => all,
    NotificationLevel.mentions => mentions,
    NotificationLevel.none => none,
  };

  NotificationLevel? get level => switch (this) {
    all => NotificationLevel.all,
    mentions => NotificationLevel.mentions,
    none => NotificationLevel.none,
    mute => null,
  };

  String get label => level?.label ?? 'Mute';
}

/// A channel's Activity mute, shown as the picker's third choice: muting
/// silences the channel entirely, so it is one of the channel's levels to
/// the person, not a second switch.
class NotificationMuteControl {
  const NotificationMuteControl({required this.muted, required this.setMuted});
  final bool muted;

  /// Resolves false when the change failed (the caller has said so).
  final Future<bool> Function(bool next) setMuted;
}

const levelSaveFailed = 'Couldn’t change the notification setting. Try again.';
const levelMuteNote = 'Muted: nothing here notifies you, not even @mentions.';

/// `useNotificationLevelModel` for a server or a channel.
class NotificationLevelModel {
  NotificationLevelModel._({
    required this.store,
    required this.serverId,
    required this.channelId,
    required this.mute,
    required this.value,
    required this.inherited,
    required this.effective,
    required this.options,
    required this.level,
  });

  factory NotificationLevelModel({
    required NotificationSettingsStore store,
    required String serverId,
    String? channelId,
    NotificationMuteControl? mute,
    RaftRecord? serverRow,
  }) {
    final server = store.serverLevel(serverId, row: serverRow);
    final channelSetting = channelId == null
        ? null
        : store.explicitLevel(serverId, 'channel', channelId);
    final muted = mute?.muted == true;
    final inherited = server;
    final level = channelId == null ? server : channelSetting ?? inherited;
    final value = muted
        ? NotificationLevelChoice.mute
        : NotificationLevelChoice.of(level);
    final effective = channelId == null
        ? server
        : muted
        ? NotificationLevel.none
        : resolveEffectiveLevel(server: server, channel: channelSetting);
    final List<NotificationLevelChoice> options;
    if (mute == null) {
      options = const [
        NotificationLevelChoice.all,
        NotificationLevelChoice.mentions,
        NotificationLevelChoice.none,
      ];
    } else {
      options = [
        NotificationLevelChoice.all,
        NotificationLevelChoice.mentions,
        // A channel set to Nothing before Mute took its place keeps showing it.
        if (level == NotificationLevel.none && !muted)
          NotificationLevelChoice.none,
        NotificationLevelChoice.mute,
      ];
    }
    return NotificationLevelModel._(
      store: store,
      serverId: serverId,
      channelId: channelId,
      mute: mute,
      value: value,
      inherited: inherited,
      effective: effective,
      options: options,
      level: level,
    );
  }

  final NotificationSettingsStore store;
  final String serverId;
  final String? channelId;
  final NotificationMuteControl? mute;

  /// The choice shown as chosen: a channel with nothing set shows the
  /// server's level it inherits (there is no "Default" option).
  final NotificationLevelChoice value;
  final NotificationLevel inherited, effective, level;
  final List<NotificationLevelChoice> options;

  bool get muted => mute?.muted == true;

  /// Applies [choice]; false when the write failed.
  Future<bool> set(NotificationLevelChoice choice) async {
    if (choice == NotificationLevelChoice.mute) {
      await mute?.setMuted(true);
      return true;
    }
    // Unmute first; a failed unmute (it reports itself) leaves the level.
    if (muted && mute != null && !await mute!.setMuted(false)) return false;
    final next = choice.level!;
    if (next == level) return true;
    // Choosing the server's own level in a channel goes back to following
    // the server, so a later server change still reaches the channel.
    final id = channelId;
    return store.setLevel(
      scope: id == null ? 'server' : 'channel',
      id: id ?? serverId,
      serverId: serverId,
      level: id != null && next == inherited ? null : next,
    );
  }
}

/// The level's icon. "Nothing" is BellMinus, not BellOff: BellOff means the
/// Activity mute.
RaftGlyph notificationLevelGlyph(NotificationLevel level) => switch (level) {
  NotificationLevel.all => RaftGlyph.bellRing,
  // Web BellMinus: not in the pinned glyph set (lucide imports of v1.21.12).
  NotificationLevel.none => RaftGlyph.bell,
  NotificationLevel.mentions => RaftGlyph.bell,
};

/// `NotificationLevelSelect` (settings rows, the channel ⋯ sheet): the
/// select and, under it, what Mute means while it is the choice.
class NotificationLevelSelect extends StatefulWidget {
  const NotificationLevelSelect({
    super.key,
    required this.client,
    required this.serverId,
    this.channelId,
    this.mute,
    this.serverRow,
    this.disabled = false,
    this.showNotes = true,
    this.label,
    this.onFailed,
  });
  final RaftClient client;
  final String serverId;
  final String? channelId;
  final NotificationMuteControl? mute;
  final RaftRecord? serverRow;
  final bool disabled, showNotes;
  final String? label;

  /// Says that a write failed (Web `toast.error(notifications.level.saveFailed)`).
  final ValueChanged<String>? onFailed;

  @override
  State<NotificationLevelSelect> createState() =>
      _NotificationLevelSelectState();
}

class _NotificationLevelSelectState extends State<NotificationLevelSelect> {
  bool busy = false;
  late NotificationSettingsStore store = NotificationSettingsStore.of(
    widget.client,
  );

  // The levels come from the account's store: loaded on every connect
  // (NotificationSettingsStore) and seeded from the channel payloads'
  // `notificationLevel` (NativeContentCoordinator), so a picker never waits.
  @override
  void initState() {
    super.initState();
    store.addListener(changed);
  }

  @override
  void didUpdateWidget(NotificationLevelSelect old) {
    super.didUpdateWidget(old);
    if (old.client != widget.client) {
      store.removeListener(changed);
      store = NotificationSettingsStore.of(widget.client)..addListener(changed);
    }
  }

  @override
  void dispose() {
    store.removeListener(changed);
    super.dispose();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final model = NotificationLevelModel(
      store: store,
      serverId: widget.serverId,
      channelId: widget.channelId,
      mute: widget.mute,
      serverRow: widget.serverRow,
    );
    final keyBase = widget.channelId == null
        ? 'notification-server-level-${widget.serverId}'
        : 'channel-settings-notification-level-select';
    final select = RaftSettingsSelect<NotificationLevelChoice>(
      key: ValueKey(keyBase),
      label: widget.label,
      value: model.value,
      items: [
        for (final option in model.options)
          RaftSelectItem(
            value: option,
            label: raftText(context, option.label),
            labelKey: ValueKey('$keyBase-${option.name}'),
          ),
      ],
      onChanged: widget.disabled || busy
          ? null
          : (next) {
              if (next == null || next == model.value) return;
              setState(() => busy = true);
              unawaited(
                model
                    .set(next)
                    .then((ok) {
                      if (!ok) widget.onFailed?.call(levelSaveFailed);
                    })
                    .whenComplete(() {
                      if (mounted) setState(() => busy = false);
                    }),
              );
            },
    );
    if (!widget.showNotes || !model.muted) return select;
    return RaftGapColumn(
      gap: RaftSpace.x1_5,
      children: [select, RaftListRowDescription(levelMuteNote, wrap: true)],
    );
  }
}

/// "Notifications ▸" in the sidebar's row menu: the trigger row and its
/// submenu with the levels (and the Mute note while muted). `onFailed` says a
/// failed write.
RaftSidebarMenuItem notificationLevelSubmenuItem({
  required BuildContext context,
  required NotificationLevelModel model,
  required VoidCallback close,
  required ValueChanged<String> onFailed,
}) => RaftSidebarMenuItem(
  itemKey: const ValueKey('sidebar-ctx-notification-level'),
  label: raftText(context, 'Notifications'),
  glyph: notificationLevelGlyph(model.effective),
  submenu: true,
  submenuLabel: raftText(context, 'Notifications'),
  submenuWidth: 288,
  submenuEntries: [
    for (final option in model.options)
      RaftSidebarMenuItem(
        itemKey: ValueKey('sidebar-ctx-notification-level-${option.name}'),
        label: raftText(context, option.label),
        checked: option == model.value,
        onPressed: () {
          close();
          if (option == model.value) return;
          unawaited(
            model.set(option).then((ok) {
              if (!ok) onFailed(levelSaveFailed);
            }),
          );
        },
      ),
    if (model.muted) RaftSidebarMenuNote(raftText(context, levelMuteNote)),
  ],
);

/// The sidebar channel row's "Notifications ▸" (Web
/// `contextNotificationLevelTarget`: a channel row of a server, not a DM or a
/// thread; its Mute is the Activity mute when the row can toggle it). Null
/// outside a server.
RaftSidebarMenuItem? channelNotificationSubmenu({
  required BuildContext context,
  required WorkspaceController workspace,
  required RaftChannel channel,
  required bool canMute,
  required Future<void> Function() toggleMute,
  required VoidCallback close,
  required ValueChanged<String> onFailed,
}) {
  final serverId = workspace.server?.id;
  if (serverId == null || channel.type == 'dm') return null;
  return notificationLevelSubmenuItem(
    context: context,
    close: close,
    onFailed: onFailed,
    model: NotificationLevelModel(
      store: NotificationSettingsStore.of(workspace.client),
      serverId: serverId,
      channelId: channel.id,
      serverRow: workspace.server,
      mute: canMute
          ? NotificationMuteControl(
              muted: channel.flag('activityMuted'),
              setMuted: (next) async {
                if (next == channel.flag('activityMuted')) return true;
                await toggleMute();
                return workspace
                        .channelById(channel.id)
                        ?.flag('activityMuted') ==
                    next;
              },
            )
          : null,
    ),
  );
}
