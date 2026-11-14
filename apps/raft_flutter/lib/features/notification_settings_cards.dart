// Source: packages/web/src/components/settings/notifications/
// PauseAndScheduleCard.tsx, ContentCard.tsx and ServersCard.tsx at
// v1.24.0-source.1 (1d689caf). Settings › Notifications' account-wide cards:
// pause and quiet hours, the content every device shows, and every server's
// level with its customized channels. Data and writes: the account's
// NotificationSettingsStore.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/notification_levels.dart';
import '../data/notification_settings_api.dart';
import '../data/notification_settings_store.dart';
import '../data/workspace_controller.dart';
import '../platform/device_timezone.dart';
import 'icu_message.dart';
import 'notification_level_menu.dart';

/// `max-w-60` (the custom pause time) and `w-36` (a quiet-hours time).
const double _customInputWidth = 240, _timeInputWidth = 144;

const settingsSaveFailed = 'Couldn’t save notification settings. Try again.';
const settingsSaveConflict =
    'These settings were just changed on another device. The latest values are shown; try again.';

String? patchProblem(PatchAccountSettingsResult result) => switch (result) {
  PatchAccountOk() => null,
  PatchAccountConflict() => settingsSaveConflict,
  PatchAccountError() => settingsSaveFailed,
};

/// Rebuilds [builder] whenever [store] changes.
class NotificationStoreBuilder extends StatelessWidget {
  const NotificationStoreBuilder({
    super.key,
    required this.store,
    required this.builder,
  });
  final NotificationSettingsStore store;
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => builder(context),
  );
}

/// Short weekday, date and time in the display locale (Web
/// `formatShortDateTime`).
String formatPauseTime(BuildContext context, DateTime at) {
  final local = at.toLocal();
  final time = TimeOfDay.fromDateTime(local).format(context);
  final date = MaterialLocalizations.of(context).formatShortMonthDay(local);
  return '$date $time';
}

// ---------------------------------------------------------------------------
// Pause and schedule
// ---------------------------------------------------------------------------

/// Settings › Notifications › Pause and schedule: pause for a while, and daily
/// quiet hours in this device's time zone. Account-wide.
class PauseScheduleCard extends StatefulWidget {
  const PauseScheduleCard({
    super.key,
    required this.store,
    this.now = DateTime.now,
    this.timeZone,
  });
  final NotificationSettingsStore store;
  final DateTime Function() now;

  /// This device's IANA zone (tests pin it); the default reads the OS.
  final Future<String?> Function()? timeZone;

  @override
  State<PauseScheduleCard> createState() => _PauseScheduleCardState();
}

class _PauseScheduleCardState extends State<PauseScheduleCard> {
  bool saving = false, custom = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Web PauseAndScheduleCard: cleared by the next save (setError("") before each PATCH).
  String? error;
  String zone = 'UTC';
  Timer? pauseEnd;
  late final customText = TextEditingController();
  ({NotificationQuietHours base, NotificationQuietHours value})? pendingQuiet;

  NotificationSettingsStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.addListener(changed);
    unawaited(
      (widget.timeZone ?? readDeviceTimezone)().then((value) {
        if (mounted && value != null) setState(() => zone = value);
      }),
    );
    final start = widget.now().add(const Duration(hours: 1));
    customText.text =
        '${start.year}-${'${start.month}'.padLeft(2, '0')}-${'${start.day}'.padLeft(2, '0')} ${minutesToTime(start.hour * 60 + start.minute)}';
    schedulePauseEnd();
  }

  @override
  void dispose() {
    store.removeListener(changed);
    pauseEnd?.cancel();
    customText.dispose();
    super.dispose();
  }

  void changed() {
    if (!mounted) return;
    schedulePauseEnd();
    setState(() {});
  }

  DateTime? get pausedUntil {
    final until = store.account?.pausedUntil;
    return isPausedNow(until, widget.now()) ? until : null;
  }

  /// Re-renders when the pause ends, so "Paused until" leaves on time.
  void schedulePauseEnd() {
    pauseEnd?.cancel();
    final until = pausedUntil;
    if (until == null) return;
    final wait =
        until.difference(widget.now()) + const Duration(milliseconds: 50);
    pauseEnd = Timer(wait.isNegative ? Duration.zero : wait, changed);
  }

  Future<bool> save(Map<String, dynamic> patch) async {
    setState(() {
      saving = true;
      error = null;
    });
    final result = await store.patchAccount(patch);
    if (!mounted) return false;
    setState(() {
      error = patchProblem(result);
      saving = false;
    });
    return result is PatchAccountOk;
  }

  void choosePause(Object? value) {
    if (value == 'custom') {
      setState(() => custom = true);
      return;
    }
    if (value is! PausePreset) return;
    setState(() => custom = false);
    unawaited(
      save({
        'pausedUntil': pausedUntilForPreset(
          value,
          widget.now(),
        ).toUtc().toIso8601String(),
      }),
    );
  }

  DateTime? get customDate {
    final at = DateTime.tryParse(customText.text.trim().replaceFirst(' ', 'T'));
    return at != null && at.isAfter(widget.now()) ? at : null;
  }

  void saveQuiet(NotificationQuietHours Function(NotificationQuietHours) edit) {
    final quiet = store.account?.quietHours;
    if (quiet == null) return;
    // Edits made while an earlier one is saving build on it.
    final from = identical(pendingQuiet?.base, quiet)
        ? pendingQuiet!.value
        : quiet;
    final value = edit(from).copyWith(timeZone: zone);
    pendingQuiet = (base: quiet, value: value);
    unawaited(save({'quietHours': value.toJson()}));
  }

  @override
  Widget build(BuildContext context) {
    final account = store.account;
    final disabled = account == null || saving;
    final paused = pausedUntil;
    final quiet = account?.quietHours;
    return RaftGapColumn(
      key: const ValueKey('notification-pause-card'),
      gap: 0,
      children: [
        const RaftSettingsSectionHeader(
          label: 'Pause and schedule',
          glyph: RaftGlyph.moon,
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: RaftSpace.x3),
            child: RaftBanner(
              key: const ValueKey('notification-pause-error'),
              status: RaftBannerRecipeStatus.warning,
              size: RaftBannerRecipeSize.sm,
              description: error!,
            ),
          ),
        RaftSettingsRowGroup(
          rows: [
            RaftSettingsRowSpec(
              key: const ValueKey('pause-notifications'),
              title: 'Pause notifications',
              description: paused == null
                  ? null
                  : raftFormat(
                      context,
                      'Paused on all your devices until {until}.',
                      {'until': formatPauseTime(context, paused)},
                    ),
              control: paused == null
                  ? RaftSettingsSelect<Object>(
                      key: const ValueKey('notification-pause-select'),
                      label: raftText(context, 'Pause notifications'),
                      placeholder: 'Off',
                      value: custom ? 'custom' : null,
                      items: [
                        for (final preset in PausePreset.values)
                          RaftSelectItem<Object>(
                            value: preset,
                            label: raftText(context, preset.label),
                            labelKey: ValueKey(
                              'notification-pause-${preset.name}',
                            ),
                          ),
                        RaftSelectItem<Object>(
                          value: 'custom',
                          label: raftText(context, 'Custom'),
                          labelKey: const ValueKey('notification-pause-custom'),
                        ),
                      ],
                      onChanged: disabled ? null : choosePause,
                    )
                  : RaftButton(
                      key: const ValueKey('notification-pause-resume'),
                      label: 'Resume',
                      tone: RaftButtonRecipeVariant.outline,
                      size: RaftButtonRecipeSize.md,
                      onPressed: disabled
                          ? null
                          : () => unawaited(save({'pausedUntil': null})),
                    ),
              wrapNarrow: paused == null,
            ),
            if (paused == null && custom)
              RaftSettingsRowSpec(
                key: const ValueKey('notification-pause-custom-row'),
                attached: true,
                body: [
                  Wrap(
                    spacing: RaftSpace.x2,
                    runSpacing: RaftSpace.x2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _customInputWidth,
                        ),
                        child: RaftTextInput(
                          key: const ValueKey(
                            'notification-pause-custom-input',
                          ),
                          controller: customText,
                          semanticLabel: raftText(context, 'Pause until'),
                          hintText: 'YYYY-MM-DD HH:MM',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      RaftButton(
                        key: const ValueKey('notification-pause-custom-apply'),
                        label: 'Pause',
                        tone: RaftButtonRecipeVariant.outline,
                        size: RaftButtonRecipeSize.md,
                        onPressed: disabled || customDate == null
                            ? null
                            : () => unawaited(
                                save({
                                  'pausedUntil': customDate!
                                      .toUtc()
                                      .toIso8601String(),
                                }).then((ok) {
                                  if (ok && mounted) {
                                    setState(() => custom = false);
                                  }
                                }),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            RaftSettingsRowSpec(
              key: const ValueKey('quiet-hours'),
              title: 'Quiet hours',
              description: raftFormat(
                context,
                'Every day between these times, nothing alerts on any of your devices; badges still update. Time zone: {timeZone}.',
                {'timeZone': zone},
              ),
              wrapNarrow: false,
              control: RaftSwitch(
                key: const ValueKey('notification-quiet-hours-switch'),
                value: quiet?.enabled == true,
                semanticLabel: raftText(context, 'Quiet hours'),
                onChanged: disabled
                    ? null
                    : (on) => saveQuiet((q) => q.copyWith(enabled: on)),
              ),
            ),
            if (quiet != null && quiet.enabled)
              RaftSettingsRowSpec(
                key: const ValueKey('notification-quiet-hours-times'),
                attached: true,
                body: [
                  Wrap(
                    spacing: RaftSpace.x3,
                    runSpacing: RaftSpace.x2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _QuietTime(
                        key: const ValueKey('notification-quiet-hours-start'),
                        label: 'Start time',
                        minutes: quiet.startMinute,
                        enabled: account != null,
                        onCommit: (m) =>
                            saveQuiet((q) => q.copyWith(startMinute: m)),
                      ),
                      _QuietTime(
                        key: const ValueKey('notification-quiet-hours-end'),
                        label: 'End time',
                        minutes: quiet.endMinute,
                        enabled: account != null,
                        onCommit: (m) =>
                            saveQuiet((q) => q.copyWith(endMinute: m)),
                      ),
                    ],
                  ),
                  if (quiet.timeZone != zone)
                    RaftListRowDescription(
                      raftFormat(
                        context,
                        'Saved for {timeZone}. Changing a time saves it for this browser’s time zone.',
                        {'timeZone': quiet.timeZone},
                      ),
                      wrap: true,
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// A quiet-hours time: typed into a local draft and saved once, on blur or
/// Enter; while not being edited it follows the saved value.
class _QuietTime extends StatefulWidget {
  const _QuietTime({
    super.key,
    required this.label,
    required this.minutes,
    required this.enabled,
    required this.onCommit,
  });
  final String label;
  final int minutes;
  final bool enabled;
  final ValueChanged<int> onCommit;
  @override
  State<_QuietTime> createState() => _QuietTimeState();
}

class _QuietTimeState extends State<_QuietTime> {
  late final text = TextEditingController(text: minutesToTime(widget.minutes));
  final focus = FocusNode();

  @override
  void initState() {
    super.initState();
    focus.addListener(() {
      if (!focus.hasFocus) commit();
    });
  }

  @override
  void didUpdateWidget(_QuietTime old) {
    super.didUpdateWidget(old);
    if (!focus.hasFocus && old.minutes != widget.minutes) {
      text.text = minutesToTime(widget.minutes);
    }
  }

  @override
  void dispose() {
    text.dispose();
    focus.dispose();
    super.dispose();
  }

  void commit() {
    final next = timeToMinutes(text.text);
    if (next == null) {
      text.text = minutesToTime(widget.minutes);
      return;
    }
    if (next != widget.minutes) widget.onCommit(next);
  }

  @override
  Widget build(BuildContext context) => RaftGapRow(
    shrinkWrap: true,
    children: [
      RaftListRowDescription(widget.label),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _timeInputWidth),
        child: RaftTextInput(
          controller: text,
          focusNode: focus,
          enabled: widget.enabled,
          semanticLabel: raftText(context, widget.label),
          hintText: 'HH:MM',
          keyboardType: TextInputType.datetime,
          onSubmitted: (_) => commit(),
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Content ("All devices")
// ---------------------------------------------------------------------------

/// Settings › Notifications › All devices: one account-wide preview, phone
/// alerts while a computer is in use, the sound switch and "Replies in
/// threads I follow"; the server applies them on every device.
class NotificationContentCard extends StatelessWidget {
  const NotificationContentCard({super.key, required this.store});
  final NotificationSettingsStore store;

  void save(BuildContext context, Map<String, dynamic> patch) {
    unawaited(
      store.patchAccount(patch).then((result) {
        final problem = patchProblem(result);
        if (problem != null && context.mounted) showRaftToast(context, problem);
      }),
    );
  }

  @override
  Widget build(BuildContext context) => NotificationStoreBuilder(
    store: store,
    builder: (context) {
      final account = store.account;
      final disabled = account == null;
      return Column(
        key: const ValueKey('notification-content-card'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RaftSettingsSectionHeader(
            label: 'All devices',
            glyph: RaftGlyph.eye,
          ),
          RaftSettingsRowGroup(
            rows: [
              RaftSettingsRowSpec(
                key: const ValueKey('notification-preview'),
                title: 'Notification preview',
                control: RaftSettingsSelect<NotificationPreviewMode>(
                  key: const ValueKey('notification-preview-select'),
                  label: raftText(context, 'Notification preview'),
                  value: account?.previewMode ?? NotificationPreviewMode.full,
                  items: [
                    for (final mode in NotificationPreviewMode.values)
                      RaftSelectItem(
                        value: mode,
                        label: raftText(context, mode.label),
                        labelKey: ValueKey('notification-preview-${mode.wire}'),
                      ),
                  ],
                  onChanged: disabled
                      ? null
                      : (mode) {
                          if (mode != null && mode != account.previewMode) {
                            save(context, {'previewMode': mode.wire});
                          }
                        },
                ),
              ),
              RaftSettingsRowSpec(
                key: const ValueKey('notification-mobile-delay'),
                title: 'Phone alerts',
                description: 'Active means you used Raft on a computer in the last 3 minutes.',
                controlBelow: true,
                control: RaftSettingsSelect<NotificationMobileDelay>(
                  key: const ValueKey('notification-mobile-delay-select'),
                  label: raftText(context, 'Phone alerts'),
                  value:
                      account?.mobileDelay ?? NotificationMobileDelay.inactive,
                  items: [
                    for (final delay in NotificationMobileDelay.order)
                      RaftSelectItem(
                        value: delay,
                        label: raftText(context, delay.label),
                        labelKey: ValueKey(
                          'notification-mobile-delay-${delay.wire}',
                        ),
                      ),
                  ],
                  onChanged: disabled
                      ? null
                      : (delay) {
                          if (delay != null && delay != account.mobileDelay) {
                            save(context, {'mobileDelay': delay.wire});
                          }
                        },
                ),
              ),
              RaftSettingsRowSpec(
                key: const ValueKey('notification-sound'),
                title: 'Sound',
                wrapNarrow: false,
                control: RaftSwitch(
                  key: const ValueKey('notification-sound-switch'),
                  value: account?.sound != false,
                  semanticLabel: raftText(context, 'Sound'),
                  onChanged: disabled
                      ? null
                      : (on) => save(context, {'sound': on}),
                ),
              ),
              RaftSettingsRowSpec(
                key: const ValueKey('notification-followed-thread-replies'),
                title: 'Replies in threads I follow',
                description: 'Off: a reply in a thread or task you follow notifies you only when it @mentions you. The thread stays in Activity.',
                wrapNarrow: false,
                control: RaftSwitch(
                  key: const ValueKey(
                    'notification-followed-thread-replies-switch',
                  ),
                  value: account?.followedThreadReplies != false,
                  semanticLabel: raftText(
                    context,
                    'Replies in threads I follow',
                  ),
                  onChanged: disabled
                      ? null
                      : (on) => save(context, {'followedThreadReplies': on}),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Servers
// ---------------------------------------------------------------------------

String _channelLabel(Map json) {
  if (json['type'] == 'dm') {
    return '${json['peerDisplayName'] ?? json['peerName'] ?? json['name'] ?? ''}';
  }
  return '#${json['name'] ?? ''}';
}

/// Names of a server's channels: the workspace's for the current server,
/// else fetched once when its customized channels are opened.
Future<Map<String, String>> _fetchChannelNames(
  RaftClient client,
  String serverId,
) async {
  final names = <String, String>{};
  for (final path in ['/channels', '/channels/dm']) {
    try {
      final rows = await client.getForServer(serverId, path);
      if (rows is! List) continue;
      for (final row in rows) {
        if (row is Map && row['id'] is String) {
          names[row['id'] as String] = _channelLabel(row);
        }
      }
    } catch (_) {
      // A name that cannot be read says so ("A channel you can no longer see").
    }
  }
  return names;
}

/// One server's level row, its "N channels customized" link and, once open,
/// the customized channels attached under it, each resettable to default.
List<RaftSettingsRowSpec> serverLevelRows({
  required BuildContext context,
  required WorkspaceController controller,
  required NotificationSettingsStore store,
  required RaftRecord server,
  required bool isCurrent,
  required bool open,
  required VoidCallback onToggle,
  required Map<String, String>? names,
  required Set<String> resetting,
  required void Function(String channelId) onReset,
}) {
  final customized = store.explicit[server.id]?.channels ?? const {};
  final ids = customized.keys.toList();
  final name = server.name;
  return [
    RaftSettingsRowSpec(
      key: ValueKey('notification-server-row-${server.id}'),
      title: isCurrent
          ? raftFormat(context, '{serverName} (current)', {'serverName': name})
          : name,
      control: NotificationLevelSelect(
        client: controller.client,
        serverId: server.id,
        serverRow: server,
        showNotes: false,
        label: name,
        onFailed: (message) => showRaftToast(context, message),
      ),
      body: [
        if (ids.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: RaftTextLink(
              key: ValueKey('notification-server-customized-${server.id}'),
              label: icuText(
                context,
                '{count, plural, one {# channel customized} other {# channels customized}}',
                {'count': ids.length},
              ),
              onPressed: onToggle,
            ),
          ),
      ],
    ),
    if (open)
      for (final id in ids)
        RaftSettingsRowSpec(
          key: ValueKey('customized-channel-$id'),
          attached: true,
          title:
              names?[id] ??
              raftText(context, 'A channel you can no longer see'),
          description: raftText(context, customized[id]!.label),
          wrapNarrow: false,
          control: RaftButton(
            key: ValueKey('customized-channel-reset-$id'),
            label: 'Reset to default',
            tone: RaftButtonRecipeVariant.ghost,
            size: RaftButtonRecipeSize.md,
            onPressed: resetting.contains(id) ? null : () => onReset(id),
          ),
        ),
  ];
}

/// Settings › Notifications › Servers: every server's level, the current
/// server first. [only] shows the current server alone (Settings › On
/// {server} › Notifications).
class NotificationServersCard extends StatefulWidget {
  const NotificationServersCard({
    super.key,
    required this.controller,
    required this.store,
    this.only = false,
  });
  final WorkspaceController controller;
  final NotificationSettingsStore store;
  final bool only;
  @override
  State<NotificationServersCard> createState() =>
      _NotificationServersCardState();
}

class _NotificationServersCardState extends State<NotificationServersCard> {
  final open = <String>{}, resetting = <String>{};
  final fetched = <String, Map<String, String>>{};
  final fetching = <String>{};

  WorkspaceController get w => widget.controller;

  List<RaftRecord> get ordered {
    final currentId = w.server?.id;
    final current = w.server;
    if (widget.only) return current == null ? const [] : [current];
    final rest = [
      for (final s in w.servers)
        if (s.id != currentId) s,
    ];
    return [?current, ...rest];
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(NotificationServersCard old) {
    super.didUpdateWidget(old);
    load();
  }

  /// Each server's levels once per page visit (a failed read is not
  /// repeated on every rebuild).
  final requested = <String>{};
  void load() {
    for (final server in ordered) {
      if (!widget.store.levelsLoaded(server.id) && requested.add(server.id)) {
        unawaited(widget.store.loadServerLevels(server.id));
      }
    }
  }

  Map<String, String>? namesFor(RaftRecord server) {
    if (server.id == w.server?.id) {
      return {
        for (final c in [...w.channels, ...w.dms]) c.id: _channelLabel(c.json),
      };
    }
    return fetched[server.id];
  }

  void toggle(RaftRecord server) {
    setState(() {
      if (!open.remove(server.id)) open.add(server.id);
    });
    if (server.id != w.server?.id &&
        !fetched.containsKey(server.id) &&
        fetching.add(server.id)) {
      unawaited(
        _fetchChannelNames(w.client, server.id).then((names) {
          if (mounted) setState(() => fetched[server.id] = names);
        }),
      );
    }
  }

  void reset(String serverId, String channelId) {
    setState(() => resetting.add(channelId));
    unawaited(
      widget.store
          .setLevel(
            scope: 'channel',
            id: channelId,
            serverId: serverId,
            level: null,
          )
          .whenComplete(() {
            if (mounted) setState(() => resetting.remove(channelId));
          }),
    );
  }

  @override
  Widget build(BuildContext context) => NotificationStoreBuilder(
    store: widget.store,
    builder: (context) {
      final servers = ordered;
      if (servers.isEmpty) return const SizedBox.shrink();
      final group = RaftSettingsRowGroup(
        key: ValueKey(
          widget.only
              ? 'server-notification-level-card'
              : 'notification-servers-card',
        ),
        rows: [
          for (final server in servers)
            ...serverLevelRows(
              context: context,
              controller: w,
              store: widget.store,
              server: server,
              isCurrent: server.id == w.server?.id,
              open: open.contains(server.id),
              onToggle: () => toggle(server),
              names: namesFor(server),
              resetting: resetting,
              onReset: (id) => reset(server.id, id),
            ),
        ],
      );
      if (widget.only) return group;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RaftSettingsSectionHeader(
            label: 'Servers',
            glyph: RaftGlyph.building2,
          ),
          group,
        ],
      );
    },
  );
}
