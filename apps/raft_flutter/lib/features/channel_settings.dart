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
  });
  final WorkspaceController controller;
  final RaftChannel channel;
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

  Future<void> edit() async {
    await showDialog(
      context: context,
      builder: (_) => RaftFormDialog(
        title: 'Edit channel',
        fields: [
          RaftFormField(
            'name',
            'Channel name',
            initial: channel.name,
            required: true,
          ),
          RaftFormField(
            'description',
            'Description',
            initial: channel.description,
            multiline: true,
          ),
        ],
        onSubmit: (values) async {
          await w.command('PATCH', '/channels/${channel.id}', data: values);
          await w.refreshChannels();
        },
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> addMembers() async {
    await run(() async {
      final sources = await Future.wait([
        w.query('/servers/${w.server!.id}/members'),
        w.query('/agents'),
      ]);
      if (!mounted) return;
      final existing = members
          .map((m) => '${m['actorType']}:${m['id']}')
          .toSet();
      final candidates =
          <Map<String, dynamic>>[
                for (final p in sources[0] as List)
                  {
                    ...Map<String, dynamic>.from(p),
                    'id': p['userId'] ?? p['id'],
                    'actorType': 'user',
                  },
                for (final p in sources[1] as List)
                  {...Map<String, dynamic>.from(p), 'actorType': 'agent'},
              ]
              .where((p) => !existing.contains('${p['actorType']}:${p['id']}'))
              .toList();
      final selected = <String>{};
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text(raftText(context, 'Add members')),
            content: SizedBox(
              width: 480,
              height: 360,
              child: ListView(
                children: [
                  for (final p in candidates)
                    CheckboxListTile(
                      value: selected.contains('${p['actorType']}:${p['id']}'),
                      title: Text('${p['displayName'] ?? p['name']}'),
                      subtitle: Text('${p['actorType']}'),
                      onChanged: (v) => update(() {
                        final id = '${p['actorType']}:${p['id']}';
                        if (v == true) {
                          selected.add(id);
                        } else {
                          selected.remove(id);
                        }
                      }),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(raftText(context, 'Cancel')),
              ),
              RaftButton(
                label: 'Add',
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
      );
      if (accepted == true) {
        await w.command(
          'POST',
          '/channels/${channel.id}/members/batch',
          data: {
            'userIds': [
              for (final p in candidates.where(
                (p) =>
                    p['actorType'] == 'user' &&
                    selected.contains('user:${p['id']}'),
              ))
                p['id'],
            ],
            'agentIds': [
              for (final p in candidates.where(
                (p) =>
                    p['actorType'] == 'agent' &&
                    selected.contains('agent:${p['id']}'),
              ))
                p['id'],
            ],
          },
        );
      }
    });
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
  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    channel.type == 'dm'
                        ? 'Conversation settings'
                        : '#${channel.name}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: raftText(context, 'Close channel settings'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: loading
                ? Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(24),
                    children: [
                      if (error != null)
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (channel.type != 'dm') ...[
                        ChannelConversionSection(
                          key: ValueKey(
                            'conversion-${w.server?.id}-${channel.id}',
                          ),
                          controller: w,
                          channelId: channel.id,
                        ),
                        SelectableText(
                          channel.description.isEmpty
                              ? 'No description'
                              : channel.description,
                        ),
                        if (w.can('editChannelMetadata', resource: channel) &&
                            !channel.archived)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: busy ? null : edit,
                              icon: const Icon(Icons.edit_outlined),
                              label: Text(raftText(context, 'Edit channel')),
                            ),
                          ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        raftText(context, 'Preferences'),
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(raftText(context, 'Pin conversation')),
                        value: (sidebar['pinned'] as List? ?? []).any(
                          (p) =>
                              p is Map &&
                              p['kind'] == 'channel' &&
                              p['id'] == channel.id,
                        ),
                        onChanged: busy ? null : pin,
                      ),
                      if (channel.flag('activityMuteSupported'))
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(raftText(context, 'Mute activity')),
                          subtitle: Text(
                            raftText(
                              context,
                              'Personal mentions still appear.',
                            ),
                          ),
                          value: notification['activityMuted'] == true,
                          onChanged: busy
                              ? null
                              : (v) => run(() async {
                                  await w.command(
                                    'PATCH',
                                    '/channels/${channel.id}/notification-settings',
                                    data: {'activityMuted': v},
                                  );
                                }),
                        ),
                      if (display.containsKey('collapseLongMessages'))
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            raftText(context, 'Collapse long messages'),
                          ),
                          value: display['collapseLongMessages'] != false,
                          onChanged: busy
                              ? null
                              : (v) => run(() async {
                                  await w.command(
                                    'PATCH',
                                    '/channels/${channel.id}/message-display-settings',
                                    data: {'collapseLongMessages': v},
                                  );
                                }),
                        ),
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              raftText(context, 'Members'),
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (w.can('addChannelMembers', resource: channel) &&
                              !channel.archived)
                            TextButton.icon(
                              onPressed: busy ? null : addMembers,
                              icon: const Icon(Icons.person_add_outlined),
                              label: Text(raftText(context, 'Add members')),
                            ),
                        ],
                      ),
                      for (final person in members)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: RaftAvatar(
                            name: '${person['displayName'] ?? person['name']}',
                          ),
                          title: Text(
                            '${person['displayName'] ?? person['name']}',
                          ),
                          subtitle: Text(
                            '${person['actorType']} · ${person['effectiveChannelRole'] ?? person['channelRole'] ?? 'member'}',
                          ),
                          trailing:
                              (person['canChangeChannelRole'] == true ||
                                      w.can(
                                        'removeChannelMembers',
                                        resource: channel,
                                      )) &&
                                  !channel.archived
                              ? PopupMenuButton<String>(
                                  onSelected: (action) => run(() async {
                                    if (action == 'remove') {
                                      await w.command(
                                        'DELETE',
                                        '/channels/${channel.id}/members/${person['actorType']}/${person['id']}',
                                      );
                                    } else {
                                      await w.command(
                                        'PATCH',
                                        '/channels/${channel.id}/members/${person['actorType']}/${person['id']}/role',
                                        data: {'role': action},
                                      );
                                    }
                                  }),
                                  itemBuilder: (_) => [
                                    if (person['canChangeChannelRole'] ==
                                            true &&
                                        !channel.archived) ...[
                                      PopupMenuItem(
                                        value: 'admin',
                                        child: Text(
                                          raftText(
                                            context,
                                            'Make channel admin',
                                          ),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'member',
                                        child: Text(
                                          raftText(context, 'Make member'),
                                        ),
                                      ),
                                    ],
                                    if (w.can(
                                          'removeChannelMembers',
                                          resource: channel,
                                        ) &&
                                        !channel.archived)
                                      PopupMenuItem(
                                        value: 'remove',
                                        child: Text(
                                          raftText(
                                            context,
                                            'Remove from channel',
                                          ),
                                        ),
                                      ),
                                  ],
                                )
                              : null,
                        ),
                      if (channel.type != 'dm' && channel.name != 'all') ...[
                        const Divider(),
                        Text(
                          raftText(context, 'Channel'),
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (!channel.archived &&
                            w.can('changeChannelVisibility', resource: channel))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              raftText(
                                context,
                                channel.type == 'private'
                                    ? 'Make public'
                                    : 'Make private',
                              ),
                            ),
                            onTap: () => confirm(
                              'Change visibility?',
                              channel.type == 'private'
                                  ? 'Everyone in this workspace can read this channel.'
                                  : 'Only channel members can read this channel.',
                              'PATCH',
                              '/channels/${channel.id}',
                              data: {
                                'visibility': channel.type == 'private'
                                    ? 'public'
                                    : 'private',
                              },
                            ),
                          ),
                        if (w.can('manageGuestAccess', resource: channel) &&
                            !channel.archived) ...[
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              raftText(context, 'Guests can see this channel'),
                            ),
                            value: channel.flag('guestVisible'),
                            onChanged: busy
                                ? null
                                : (v) => run(() async {
                                    await w.command(
                                      'PATCH',
                                      '/channels/${channel.id}',
                                      data: {'guestVisible': v},
                                    );
                                  }),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              raftText(context, 'Guests can join this channel'),
                            ),
                            value: channel.flag('guestJoinable'),
                            onChanged: busy
                                ? null
                                : (v) => run(() async {
                                    await w.command(
                                      'PATCH',
                                      '/channels/${channel.id}',
                                      data: {'guestJoinable': v},
                                    );
                                  }),
                          ),
                        ],
                        if (w.can('archiveChannels', resource: channel))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              raftText(
                                context,
                                channel.archived
                                    ? 'Unarchive channel'
                                    : 'Archive channel',
                              ),
                            ),
                            leading: const Icon(Icons.archive_outlined),
                            onTap: () => confirm(
                              channel.archived
                                  ? 'Unarchive channel?'
                                  : 'Archive channel?',
                              'Archived channels retain history and stop new messages.',
                              'POST',
                              '/channels/${channel.id}/${channel.archived ? 'unarchive' : 'archive'}',
                            ),
                          ),
                        if (channel.joined && !channel.archived)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(raftText(context, 'Leave channel')),
                            leading: const Icon(Icons.logout),
                            onTap: () => confirm(
                              'Leave channel?',
                              'You can rejoin a public channel later.',
                              'POST',
                              '/channels/${channel.id}/leave',
                            ),
                          ),
                        if (w.can('deleteChannels', resource: channel))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(raftText(context, 'Delete channel')),
                            leading: const Icon(Icons.delete_outline),
                            onTap: () async {
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
                                    await w.command(
                                      'DELETE',
                                      '/channels/${channel.id}',
                                    );
                                    await w.refreshChannels();
                                  },
                                ),
                              );
                              if (!mounted) return;
                              if (accepted == true) Navigator.pop(this.context);
                            },
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}
