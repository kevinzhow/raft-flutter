import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/resource_snapshot_cache.dart' show stableValue;
import '../data/workspace_controller.dart';
import 'channel_conversion_section.dart';
import 'management_support.dart'
    show
        cachedServerFlag,
        pageIdentity,
        readPageSnapshot,
        rememberServerFlag,
        writePageSnapshot;

class ChannelSettings extends StatefulWidget {
  const ChannelSettings({
    super.key,
    required this.controller,
    required this.channel,
    this.leave = true,
    this.collapseLongMessages = true,
    this.isPanel = false,
  });
  final WorkspaceController controller;
  final RaftChannel channel;

  /// Web `onLeaveChannel` / `collapseLongMessages` props: hosts that do not
  /// offer Leave or the collapse preference in this sheet pass false.
  final bool leave, collapseLongMessages;

  /// Source ChannelPreferencesSection: activity mute is a panel-only preference,
  /// omitted in standalone EditChannelDialog and for one-to-one DMs.
  final bool isPanel;
  @override
  State<ChannelSettings> createState() => _ChannelSettingsState();
}

class _ChannelSettingsState extends State<ChannelSettings> {
  WorkspaceController get w => widget.controller;
  RaftChannel get channel =>
      [
        ...w.channels,
        ...w.dms,
      ].where((c) => c.id == widget.channel.id).firstOrNull ??
      widget.channel;
  List<Map<String, dynamic>> members = [];
  Map<String, dynamic> sidebar = {}, notification = {}, display = {};

  /// Parts of [load] accepted for this channel (from its snapshot or a
  /// response). A row whose part is unknown reserves its final geometry.
  final known = <String>{};
  bool busy = false;
  String? error;
  StreamSubscription<RaftEvent>? events;
  Timer? refresh;
  final _queued = <String>{};
  String get snapshotKey => 'channel-settings:${widget.channel.id}';
  static const _parts = {'members', 'sidebar', 'display', 'notification'};
  static const guestFlag = 'server_guest_v0';

  /// Server flags that decide which sections exist. Unknown only on the
  /// first settings visit under this server identity (true cold load).
  bool flagsKnown = false;

  @override
  void initState() {
    super.initState();
    // Revisit: this channel's accepted preferences render at once and
    // revalidate quietly. The pin state is also on the workspace sidebar.
    final snapshot = readPageSnapshot(w, snapshotKey);
    if (snapshot != null) {
      sidebar = snapshot['sidebar'] as Map<String, dynamic>;
      display = snapshot['display'] as Map<String, dynamic>;
      notification = snapshot['notification'] as Map<String, dynamic>;
      known.addAll(snapshot['known'] as Set<String>);
    } else if (w.sidebarOrder.isNotEmpty) {
      sidebar = w.sidebarOrder;
      known.add('sidebar');
    }
    final guest = cachedServerFlag(w, guestFlag);
    flagsKnown =
        guest != null && cachedServerFlag(w, channelConversionFlag) != null;
    guestFeature = guest ?? false;
    load();
    loadFlags();
    events = w.client.events.listen((event) {
      // Each event refreshes only the part it can change, in place.
      final part = switch (event.name) {
        'channel:members-updated' => 'members',
        'notification_prefs:updated' => 'notification',
        'message_display_prefs:updated' => 'display',
        _ => null,
      };
      if (part == null) return;
      final payload = event.payload;
      final id = payload is Map ? payload['channelId'] : null;
      if (part == 'members' && id is String && id != widget.channel.id) {
        return;
      }
      _queued.add(part);
      refresh?.cancel();
      refresh = Timer(const Duration(milliseconds: 150), () {
        final parts = Set.of(_queued);
        _queued.clear();
        if (mounted) load(parts);
      });
    });
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    events?.cancel();
    refresh?.cancel();
    super.dispose();
  }

  final _tickets = <String, int>{};
  int _ticket = 0;

  /// Fetch [parts] (all by default) and replace them in place. Older
  /// responses for a part never overwrite a newer one; failures keep the
  /// accepted values.
  Future<void> load([Set<String> parts = _parts]) async {
    final generation = w.client.generation,
        serverId = w.server?.id,
        identity = pageIdentity(w);
    if (serverId == null) return;
    final id = widget.channel.id;
    final wanted = [
      for (final part in parts)
        if (part != 'notification' || channel.flag('activityMuteSupported'))
          part,
    ];
    final tickets = {
      for (final part in wanted) part: _tickets[part] = ++_ticket,
    };
    Future<dynamic> fetch(String part) => switch (part) {
      'members' => w.query('/channels/$id/members'),
      'sidebar' => w.query('/servers/$serverId/sidebar-order'),
      'display' => w.query('/channels/$id/message-display-settings'),
      _ => w.query('/channels/$id/notification-settings'),
    };
    try {
      final values = await Future.wait(wanted.map(fetch));
      if (!mounted || generation != w.client.generation) return;
      T stable<T>(T old, T next) => stableValue(old, next) as T;
      setState(() {
        for (var i = 0; i < wanted.length; i++) {
          final part = wanted[i], value = values[i];
          if (_tickets[part] != tickets[part]) continue;
          switch (part) {
            case 'members':
              members = stable(members, [
                for (final row in value['humans'] as List)
                  {...Map<String, dynamic>.from(row), 'actorType': 'user'},
                for (final row in value['agents'] as List)
                  {...Map<String, dynamic>.from(row), 'actorType': 'agent'},
              ]);
            case 'sidebar':
              sidebar = stable(sidebar, Map<String, dynamic>.from(value));
            case 'display':
              display = stable(display, Map<String, dynamic>.from(value));
            case 'notification':
              notification = stable(
                notification,
                Map<String, dynamic>.from(value),
              );
          }
          known.add(part);
        }
        error = null;
      });
      // The member roster is not shown here and is never cached.
      writePageSnapshot(w, snapshotKey, identity, {
        'sidebar': sidebar,
        'display': display,
        'notification': notification,
        'known': Set<String>.unmodifiable(known.difference({'members'})),
      });
    } catch (e) {
      if (mounted && generation == w.client.generation) {
        setState(() => error = '$e');
      }
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      await w.refreshChannels();
      await load();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> confirm(
    String title,
    String description,
    String method,
    String path, {
    dynamic data,
    bool destructive = false,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => RaftFormDialog(
        title: title,
        description: description,
        fields: [],
        submitLabel: destructive ? 'Delete' : 'Confirm',
        destructive: destructive,
        onSubmit: (_) async {
          await w.command(method, path, data: data);
          await w.refreshChannels();
        },
      ),
    );
    if (mounted) await load();
  }

  late final name = TextEditingController(text: widget.channel.name);
  late final description = TextEditingController(
    text: widget.channel.description,
  );
  bool guestFeature = false;

  /// The guest and joint-conversion flags in one evaluation, remembered for
  /// this server identity so later visits render their sections at once.
  Future<void> loadFlags() async {
    final serverId = w.server?.id, identity = pageIdentity(w);
    if (serverId == null) return;
    try {
      // useServerFeatureFlag(SERVER_GUEST_FEATURE_FLAG_KEY).
      final result = await w.command(
        'POST',
        '/feature-flags/evaluate',
        data: {
          'keys': [guestFlag, channelConversionFlag],
          'serverId': serverId,
          'platform': 'web',
        },
      );
      bool enabled(String key) =>
          result is Map &&
          (result['evaluations'] as List? ?? []).whereType<Map>().any(
            (f) => f['key'] == key && f['enabled'] == true,
          );
      rememberServerFlag(w, guestFlag, enabled(guestFlag), identity);
      rememberServerFlag(
        w,
        channelConversionFlag,
        enabled(channelConversionFlag),
        identity,
      );
      if (mounted && identity == pageIdentity(w)) {
        setState(() {
          guestFeature = enabled(guestFlag);
          flagsKnown = true;
        });
      }
    } catch (_) {
      // Unknown flags never enable a section; the page still opens.
      if (mounted) setState(() => flagsKnown = true);
    }
  }

  Future<void> save() async {
    if (busy) return;
    final trimmed = name.text.trim();
    if (trimmed.isEmpty) {
      setState(() => error = raftText(context, 'Channel name is required.'));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await w.command(
        'PATCH',
        '/channels/${channel.id}',
        data: {
          if (channel.name != 'all') 'name': trimmed,
          'description': description.text.trim(),
        },
      );
      await w.refreshChannels();
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is RaftApiException
              ? e.message
              : raftText(context, 'Failed to update channel'),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pin(bool value) async => run(() async {
    final pins = (sidebar['pinned'] as List? ?? [])
        .whereType<Map>()
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
    pins.removeWhere((p) => p['kind'] == 'channel' && p['id'] == channel.id);
    if (value) {
      pins.add({'kind': 'channel', 'id': channel.id});
    }
    await w.command(
      'PATCH',
      '/servers/${w.server!.id}/sidebar-order',
      data: {'pinned': pins},
    );
    await w.loadSidebar();
  });
  bool cap(String name) => w.can(name, resource: channel);

  @override
  Widget build(BuildContext context) {
    final c = channel;
    final generation = w.client.generation, serverId = w.server?.id;
    final dm = c.type == 'dm';
    final all = c.name == 'all';
    final archived = c.archived;
    final canEdit =
        cap('editChannelMetadata') ||
        cap('changeChannelVisibility') ||
        cap('archiveChannels') ||
        cap('deleteChannels') ||
        cap('federateChannels');
    final showLeave = widget.leave && c.joined && !all && !archived && !dm;
    final showManage = canEdit && !archived && !dm;
    final showVisibility = showManage && !all && cap('changeChannelVisibility');
    final private = c.type == 'private';
    final pinned = (sidebar['pinned'] as List? ?? []).any(
      (p) => p is Map && p['kind'] == 'channel' && p['id'] == c.id,
    );
    final info = !dm && canEdit;
    // Web ChatPanel `onStopAllAgents={joined && canManageAgents}` inside the
    // settings sheet (`joined && (canManageChannels || canLeaveChannel)`),
    // hidden for archived channels (EditChannelDialog `!isArchived`).
    final showStopAgents =
        !dm &&
        c.type != 'thread' &&
        c.joined &&
        !archived &&
        (canEdit || !all) &&
        w.can('controlAgentRuntime');
    return RaftChannelSettingsSheet(
      channelName: widget.channel.name,
      title: dm ? 'Conversation settings' : 'Settings',
      onClose: () => Navigator.of(context).maybePop(),
      // Only a true cold load (no flags for this server yet) waits; otherwise
      // the panel opens final, reserving rows whose values are in flight.
      loading: !flagsKnown,
      busy: busy,
      error: error,
      // ChannelConversionSection hides itself unless conversion applies.
      lead: info
          ? ChannelConversionSection(
              key: ValueKey('conversion-${w.server?.id}-${c.id}'),
              controller: w,
              channelId: c.id,
            )
          : null,
      nameController: info ? name : null,
      descriptionController: info ? description : null,
      nameEnabled: !all && !archived,
      descriptionEnabled: !archived,
      nameHint: all ? 'The #all channel cannot be renamed.' : null,
      onSubmitName: (_) => save(),
      sections: [
        if (guestFeature && cap('manageGuestAccess') && !archived && !dm)
          RaftSheetSection('Guest access', [
            RaftSheetSwitchRow(
              title: 'Guests can see this channel',
              description:
                  'Guests in this server can find and read this channel.',
              value: c.flag('guestVisible'),
              onChanged: (v) => run(() async {
                await w.command(
                  'PATCH',
                  '/channels/${c.id}',
                  data: {'guestVisible': v},
                );
              }),
            ),
            RaftSheetSwitchRow(
              title: 'Guests can join this channel',
              description: 'Guests can join and post in this channel.',
              value: c.flag('guestJoinable'),
              onChanged: (v) => run(() async {
                await w.command(
                  'PATCH',
                  '/channels/${c.id}',
                  data: v
                      ? {'guestVisible': true, 'guestJoinable': true}
                      : {'guestJoinable': false},
                );
              }),
            ),
          ]),
        RaftSheetSection('Preferences', [
          RaftSheetSwitchRow(
            title: 'Pin channel',
            description: 'Keep this channel pinned to the top of your sidebar.',
            value: pinned,
            pending: !known.contains('sidebar'),
            onChanged: pin,
          ),
          if (widget.isPanel &&
              !dm &&
              c.joined &&
              c.flag('activityMuteSupported') &&
              (!known.contains('notification') ||
                  notification['activityMuted'] is bool))
            RaftSheetSwitchRow(
              title: 'Mute activity',
              description:
                  'Mute ordinary activity from this channel. Only affects you.',
              value: notification['activityMuted'] == true,
              pending: !known.contains('notification'),
              onChanged: (value) => run(() async {
                final fresh = [
                  ...w.channels,
                  ...w.dms,
                ].where((next) => next.id == c.id).firstOrNull;
                if (w.client.generation != generation ||
                    w.server?.id != serverId ||
                    fresh == null ||
                    !fresh.joined ||
                    !fresh.flag('activityMuteSupported') ||
                    !w.can('viewChannel', resource: fresh)) {
                  throw StateError(
                    'Channel activity preference is no longer available.',
                  );
                }
                await w.command(
                  'PATCH',
                  '/channels/${c.id}/notification-settings',
                  data: {'activityMuted': value},
                );
              }),
            ),
          if (widget.collapseLongMessages &&
              (!known.contains('display') ||
                  display.containsKey('collapseLongMessages')))
            RaftSheetSwitchRow(
              title: 'Collapse long messages',
              description: 'Fold messages taller than the preview height behind a Show more toggle. Turn off to always show full messages in this channel.',
              value: display['collapseLongMessages'] != false,
              pending: !known.contains('display'),
              onChanged: (v) => run(() async {
                await w.command(
                  'PATCH',
                  '/channels/${c.id}/message-display-settings',
                  data: {'collapseLongMessages': v},
                );
              }),
            ),
        ]),
      ],
      showActions:
          !dm &&
          (showLeave ||
              showManage ||
              showStopAgents ||
              (archived && cap('archiveChannels'))),
      actions: [
        if (showLeave)
          RaftSheetAction(
            'Leave Channel',
            RaftGlyph.logOut,
            RaftButtonRecipeVariant.warning,
            () => confirm(
              'Leave channel?',
              'You can rejoin a public channel later.',
              'POST',
              '/channels/${c.id}/leave',
            ),
          ),
        if (showVisibility)
          RaftSheetAction(
            private ? 'Make Public' : 'Make Private',
            private ? RaftGlyph.hash : RaftGlyph.lock,
            RaftButtonRecipeVariant.warning,
            () => confirm(
              private ? 'Make channel public?' : 'Make channel private?',
              private
                  ? 'Everyone in this workspace can read this channel.'
                  : 'Only channel members can read this channel.',
              'PATCH',
              '/channels/${c.id}',
              data: {'visibility': private ? 'public' : 'private'},
            ),
          ),
        if (!all && cap('archiveChannels'))
          archived
              ? RaftSheetAction(
                  'Unarchive Channel',
                  RaftGlyph.archiveRestore,
                  RaftButtonRecipeVariant.success,
                  () => run(() async {
                    await w.command('POST', '/channels/${c.id}/unarchive');
                  }),
                )
              : RaftSheetAction(
                  'Archive Channel',
                  RaftGlyph.archive,
                  RaftButtonRecipeVariant.warning,
                  () => confirm(
                    'Archive channel?',
                    'Archived channels retain history and stop new messages.',
                    'POST',
                    '/channels/${c.id}/archive',
                  ),
                ),
        if (showStopAgents)
          RaftSheetAction(
            'Stop Agents',
            RaftGlyph.circleStop,
            RaftButtonRecipeVariant.outline,
            stopAgents,
          ),
        if (!all && !archived && cap('deleteChannels'))
          RaftSheetAction(
            'Delete Channel',
            RaftGlyph.trash2,
            RaftButtonRecipeVariant.danger,
            deleteChannel,
          ),
      ],
      onSave: canEdit && !dm ? save : null,
      saveDisabled: archived,
    );
  }

  /// Web SOSDialog: `POST /channels/:id/stop-all-agents`, then the guidance
  /// prompt through `POST /channels/:id/resume-all-agents`. Both re-check
  /// that this account may still control agent runtime in the same session.
  Future<void> stopAgents() async {
    final c = channel, identity = pageIdentity(w);
    String? refused() =>
        identity != pageIdentity(w) || !w.can('controlAgentRuntime')
        ? 'You no longer have permission to control agents here.'
        : null;
    String failure(Object error, String fallback) =>
        error is RaftApiException ? error.message : fallback;
    await showRaftDialog<void>(
      context: context,
      builder: (dialogContext) {
        String tr(String text) => raftText(dialogContext, text);
        return Center(
          child: RaftSosDialog(
            key: const ValueKey('channel-sos-dialog'),
            channelName: c.name,
            onClose: () => Navigator.of(dialogContext).pop(),
            onStop: () async {
              final denied = refused();
              if (denied != null) return tr(denied);
              try {
                await w.command('POST', '/channels/${c.id}/stop-all-agents');
                return null;
              } catch (e) {
                return failure(
                  e,
                  tr('Agents could not be stopped. Try again.'),
                );
              }
            },
            onResume: (guidance) async {
              final denied = refused();
              if (denied != null) return tr(denied);
              final prompt =
                  '[SOS] The user has emergency-stopped all agents in #${c.name} because they were going off-track. Here is the user\'s correction and new guidance:\n\n$guidance\n\nRead this carefully, acknowledge the correction, and adjust your approach accordingly. Use check_messages and read_history to understand the current state before taking any action.';
              try {
                await w.command(
                  'POST',
                  '/channels/${c.id}/resume-all-agents',
                  data: {'prompt': prompt},
                );
                return null;
              } catch (e) {
                return failure(
                  e,
                  tr('Agents could not be resumed. Try again.'),
                );
              }
            },
          ),
        );
      },
    );
  }

  Future<void> deleteChannel() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => RaftFormDialog(
        title: 'Delete channel?',
        description:
            'Delete #${channel.name} and its messages. This cannot be undone.',
        fields: [],
        submitLabel: 'Delete',
        destructive: true,
        onSubmit: (_) async {
          await w.command('DELETE', '/channels/${channel.id}');
          await w.refreshChannels();
        },
      ),
    );
    if (!mounted) return;
    if (accepted == true) Navigator.pop(context);
  }
}
