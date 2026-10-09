import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'channel_conversion_section.dart';

class ChannelSettings extends StatefulWidget {
  const ChannelSettings({
    super.key,
    required this.controller,
    required this.channel,
    this.leave = true,
    this.collapseLongMessages = true,
  });
  final WorkspaceController controller;
  final RaftChannel channel;

  /// Web `onLeaveChannel` / `collapseLongMessages` props: hosts that do not
  /// offer Leave or the collapse preference in this sheet pass false.
  final bool leave, collapseLongMessages;
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
  bool loading = true, busy = false;
  String? error;
  StreamSubscription<RaftEvent>? events;
  Timer? refresh;
  @override
  void initState() {
    super.initState();
    load();
    loadGuestFlag();
    events = w.client.events.listen((event) {
      if (event.name == 'channel:members-updated' ||
          event.name == 'notification_prefs:updated' ||
          event.name == 'message_display_prefs:updated') {
        refresh?.cancel();
        refresh = Timer(const Duration(milliseconds: 150), () {
          if (mounted) load();
        });
      }
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

  int request = 0;
  Future<void> load() async {
    final ticket = ++request,
        generation = w.client.generation,
        serverId = w.server?.id;
    if (serverId == null) return;
    try {
      final values = await Future.wait([
        w.query('/channels/${widget.channel.id}/members'),
        w.query('/servers/$serverId/sidebar-order'),
        w.query('/channels/${widget.channel.id}/message-display-settings'),
        if (channel.flag('activityMuteSupported'))
          w.query('/channels/${widget.channel.id}/notification-settings'),
      ]);
      if (!mounted || ticket != request || generation != w.client.generation) {
        return;
      }
      final roster = values[0];
      setState(() {
        members = [
          for (final row in roster['humans'] as List)
            {...Map<String, dynamic>.from(row), 'actorType': 'user'},
          for (final row in roster['agents'] as List)
            {...Map<String, dynamic>.from(row), 'actorType': 'agent'},
        ];
        sidebar = Map<String, dynamic>.from(values[1]);
        display = Map<String, dynamic>.from(values[2]);
        notification = values.length > 3
            ? Map<String, dynamic>.from(values[3])
            : {};
        error = null;
      });
    } catch (e) {
      if (mounted && ticket == request && generation == w.client.generation) {
        setState(() => error = '$e');
      }
    } finally {
      if (mounted && ticket == request) setState(() => loading = false);
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

  Future<void> loadGuestFlag() async {
    final serverId = w.server?.id;
    if (serverId == null) return;
    try {
      // useServerFeatureFlag(SERVER_GUEST_FEATURE_FLAG_KEY).
      final result = await w.command(
        'POST',
        '/feature-flags/evaluate',
        data: {
          'keys': ['server_guest_v0'],
          'serverId': serverId,
        },
      );
      final enabled =
          result is Map &&
          (result['evaluations'] as List? ?? []).whereType<Map>().any(
            (f) => f['key'] == 'server_guest_v0' && f['enabled'] == true,
          );
      if (mounted) setState(() => guestFeature = enabled);
    } catch (_) {}
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
    return RaftChannelSettingsSheet(
      channelName: widget.channel.name,
      title: dm ? 'Conversation settings' : 'Settings',
      onClose: () => Navigator.of(context).maybePop(),
      loading: loading,
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
            onChanged: pin,
          ),
          if (widget.collapseLongMessages &&
              display.containsKey('collapseLongMessages'))
            RaftSheetSwitchRow(
              title: 'Collapse long messages',
              description:
                  'Fold messages taller than the preview height behind a Show more toggle. Turn off to always show full messages in this channel.',
              value: display['collapseLongMessages'] != false,
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
          (showLeave || showManage || (archived && cap('archiveChannels'))),
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
