import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/resource_snapshot_cache.dart' show stableValue;
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import 'channel_conversion_section.dart';
import 'channel_form_fields.dart';
import 'channel_members.dart';
import 'channel_settings_strip.dart';
import 'channel_sos.dart';
import 'composer_directory.dart'
    show cachedChannelRoster, cachedChannelRosterExternals;
import 'create_channel_dialog.dart' show ChannelMemberCandidate;
import 'management_support.dart'
    show
        cachedServerFlag,
        pageIdentity,
        readPageSnapshot,
        rememberServerFlag,
        writePageSnapshot;
import '../data/feature_flag_client_facts.dart';

/// Web `canToggleActivityMute` (channelDomain.ts): channel / private / joint
/// rows the member joined. The wire flag `activityMuteSupported` is not read.
bool channelCanToggleActivityMute(RaftChannel channel) =>
    channel.joined &&
    const {'channel', 'private', 'joint'}.contains(channel.type);

class ChannelSettings extends StatefulWidget {
  const ChannelSettings({
    super.key,
    required this.controller,
    required this.channel,
    this.leave = true,
    this.collapseLongMessages = true,
    this.isPanel = false,
    this.page = false,
    this.onClose,
    this.onMembers,
    this.dmName,
  });
  final WorkspaceController controller;
  final RaftChannel channel;

  /// A DM's sheet title: the peer's plain name (ChatPanel `displayName`).
  final String? dmName;

  /// The settings drawer as the product shows it: Web mounts only
  /// `ChannelOverflowMenu` (OverflowSheet + EditChannelDialog
  /// `presentation="panel"`). `isPanel: false` is the legacy sheet
  /// presentation, kept for the official parity case.
  static Future<void> show(
    BuildContext context, {
    required WorkspaceController controller,
    required RaftChannel channel,
    String? dmName,
  }) => showRaftOverflowSheet<void>(
    context,
    // Dismissal goes through the unsaved-draft guard inside the drawer.
    builder: (_) => ChannelSettings(
      controller: controller,
      channel: channel,
      isPanel: true,
      dmName: dmName,
    ),
  );

  /// Web `onLeaveChannel` / `collapseLongMessages` props: hosts that do not
  /// offer Leave or the collapse preference in this sheet pass false.
  final bool leave, collapseLongMessages;

  /// Source ChannelPreferencesSection: activity mute is a panel-only preference,
  /// omitted in standalone EditChannelDialog and for one-to-one DMs.
  final bool isPanel;
  final bool page;
  final VoidCallback? onClose, onMembers;
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

  /// Slack bridge participants (`externalMembers`): display-only, counted in
  /// the members strip beside the humans and agents.
  List<Map<String, dynamic>> externalMembers = [];
  Map<String, dynamic> sidebar = {}, notification = {}, display = {};

  /// Parts of [load] accepted for this channel (from its snapshot or a
  /// response). A row whose part is unknown reserves its final geometry.
  final known = <String>{};
  bool busy = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when an action starts, a load succeeds, the draft is reset or the name or description is edited; the drawer state is dropped on close.
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
    // The channel roster the composer read on opening shows at the first
    // frame (Source ChatPanel prefetches it); the load below revalidates it.
    final roster = drawer ? cachedChannelRoster(w, widget.channel.id) : null;
    if (roster != null) {
      members = rosterRows(roster.humans, roster.agents);
      externalMembers = cachedChannelRosterExternals(w, widget.channel.id);
      known.add('members');
    }
    _draftName = name.text;
    _draftDescription = description.text;
    name.addListener(draftChanged);
    description.addListener(draftChanged);
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
    name.removeListener(draftChanged);
    description.removeListener(draftChanged);
    name.dispose();
    description.dispose();
    events?.cancel();
    refresh?.cancel();
    savedTimer?.cancel();
    super.dispose();
  }

  final _tickets = <String, int>{};
  int _ticket = 0;

  static List<Map<String, dynamic>> rosterRows(
    List<Map<String, dynamic>> humans,
    List<Map<String, dynamic>> agents,
  ) => [
    for (final row in humans) {...row, 'actorType': 'user'},
    for (final row in agents) {...row, 'actorType': 'agent'},
  ];

  String? _draftName, _draftDescription;

  /// EditChannelDialog: typing in the name or description drops the error and
  /// the "Changes saved" label, which both describe the text as it was.
  void draftChanged() {
    if (!mounted) return;
    final edited =
        _draftName != name.text || _draftDescription != description.text;
    _draftName = name.text;
    _draftDescription = description.text;
    setState(() {
      if (edited) {
        error = null;
        clearSaved();
      }
    });
  }

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
        if ((part != 'notification' || channelCanToggleActivityMute(channel)) &&
            // A 1:1 DM sheet has no members section (ChatPanel #1281).
            !(part == 'members' && drawer && channel.type == 'dm'))
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
      // Each part settles on its own: one failed read never holds the others
      // back (a failed roster shows the accepted or empty roster, as
      // useChannelMembers does; a failed preference keeps its accepted value).
      Object? failure;
      final failed = <String>{};
      final values = await Future.wait([
        for (final part in wanted)
          Future<dynamic>.sync(() => fetch(part)).catchError((Object e) {
            failure ??= e;
            failed.add(part);
            return null;
          }),
      ]);
      if (!mounted || generation != w.client.generation) return;
      T stable<T>(T old, T next) => stableValue(old, next) as T;
      setState(() {
        for (var i = 0; i < wanted.length; i++) {
          final part = wanted[i], value = values[i];
          if (_tickets[part] != tickets[part]) continue;
          if (failed.contains(part)) {
            if (part == 'members') known.add(part);
            continue;
          }
          switch (part) {
            case 'members':
              members = stable(
                members,
                rosterRows(
                  [
                    for (final row in value['humans'] as List)
                      Map<String, dynamic>.from(row),
                  ],
                  [
                    for (final row in value['agents'] as List)
                      Map<String, dynamic>.from(row),
                  ],
                ),
              );
              externalMembers = stable(externalMembers, [
                for (final row in value['externalMembers'] as List? ?? [])
                  Map<String, dynamic>.from(row as Map),
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
        error = failure == null
            ? null
            : failText(failure!, raftGenericErrorText);
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
        setState(() => error = failText(e, raftGenericErrorText));
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
      if (mounted) {
        setState(() => error = failText(e, 'Failed to update channel'));
      }
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
      barrierDismissible: false,
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
        data: featureFlagEvaluateBody(
          keys: [guestFlag, channelConversionFlag],
          serverId: serverId,
        ),
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
        setState(() => error = failText(e, 'Failed to update channel'));
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

  Future<void> editMetadata() async {
    final c = channel, identity = pageIdentity(w);
    if (c.archived || !cap('editChannelMetadata')) return;
    await showRaftForm<void>(
      context,
      builder: (_) => RaftFormDialog(
        title: 'Edit channel',
        fields: [
          if (c.name != 'all')
            RaftFormField('name', 'Name', initial: c.name, required: true),
          RaftFormField(
            'description',
            'Description',
            initial: c.description,
            multiline: true,
          ),
        ],
        onSubmit: (values) async {
          if (!mounted ||
              identity != pageIdentity(w) ||
              channel.archived ||
              !cap('editChannelMetadata')) {
            throw RaftUserError('Channel editing is no longer available.');
          }
          await w.command('PATCH', '/channels/${c.id}', data: values);
          if (identity != pageIdentity(w)) return;
          await w.refreshChannels();
        },
      ),
    );
    if (mounted && identity == pageIdentity(w)) setState(() {});
  }

  /// Page and drawer hosts share the mounted product's settings content.
  bool get drawer => widget.isPanel;

  @override
  Widget build(BuildContext context) =>
      drawer ? panel(context) : sheet(context);

  Widget sheet(BuildContext context) {
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
      channelName: c.name,
      channelLabel: dm
          ? [
              c.string('peerDisplayName'),
              c.string('peerName'),
              c.name,
            ].where((name) => name.isNotEmpty).firstOrNull
          : null,
      channelDescription: c.description,
      page: widget.page,
      onEdit: widget.page && !dm && !archived && cap('editChannelMetadata')
          ? editMetadata
          : null,
      onMembers: widget.page ? widget.onMembers : null,
      title: dm ? 'Conversation settings' : 'Settings',
      onClose: widget.onClose ?? () => Navigator.of(context).maybePop(),
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
      nameController: info && !widget.page ? name : null,
      descriptionController: info && !widget.page ? description : null,
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
              channelCanToggleActivityMute(c) &&
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
                    !channelCanToggleActivityMute(fresh) ||
                    !w.can('viewChannel', resource: fresh)) {
                  throw RaftUserError(
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
      onSave: canEdit && !dm && !widget.page ? save : null,
      saveDisabled: archived,
    );
  }

  // ---------------------------------------------------------------------
  // The drawer panel (Web ChannelOverflowMenu + EditChannelDialog panel).
  // ---------------------------------------------------------------------

  static final _nameRegex = RegExp(r'^\p{L}[\p{L}\p{N}_-]*$', unicode: true);

  /// `validateNameReason` + `formatNameValidationError` for the channel name.
  String? nameError(BuildContext context, String value) {
    final label = raftText(context, 'Channel name');
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return raftFormat(context, '{label} is required', {'label': label});
    }
    if (trimmed.runes.length > 32) {
      return raftFormat(context, '{label} must be at most {max} characters', {
        'label': label,
        'max': 32,
      });
    }
    if (!_nameRegex.hasMatch(trimmed)) {
      return raftText(
        context,
        'Start with a letter, then letters, numbers, - or _',
      );
    }
    return null;
  }

  bool saving = false, visibilityBusy = false, guestBusy = false;
  bool archiveBusy = false, unsavedBusy = false;
  String? savedLabel;
  Timer? savedTimer;

  bool get nameDescDirty =>
      name.text != channel.name || description.text != channel.description;

  /// Mirrors `isDirty`: the host drawer guards every dismissal while true.
  bool get dirty => nameDescDirty;

  void resetDraft() {
    name.text = channel.name;
    description.text = channel.description;
    clearSaved();
    setState(() => error = null);
  }

  void clearSaved() {
    savedTimer?.cancel();
    savedTimer = null;
    if (savedLabel != null) savedLabel = null;
  }

  /// EditChannelDialog `saveChanges`: validates, PATCHes only the changed
  /// fields and reports `true` when the draft is clean afterwards. Never
  /// closes; callers decide what happens next.
  Future<bool> saveChanges() async {
    final c = channel;
    final canEdit =
        cap('editChannelMetadata') ||
        cap('changeChannelVisibility') ||
        cap('archiveChannels') ||
        cap('deleteChannels') ||
        cap('federateChannels');
    setState(() => error = null);
    clearSaved();
    if (!canEdit) return true;
    final all = c.name == 'all';
    if (!all) {
      final invalid = nameError(context, name.text);
      if (invalid != null) {
        setState(() => error = invalid);
        return false;
      }
    }
    setState(() => saving = true);
    try {
      final updates = <String, dynamic>{
        if (!all && name.text.trim() != c.name) 'name': name.text.trim(),
        if (description.text.trim() != c.description)
          'description': description.text.trim(),
      };
      if (updates.isNotEmpty) {
        await w.command('PATCH', '/channels/${c.id}', data: updates);
        await w.refreshChannels();
      }
      if (!mounted) return true;
      name.text = channel.name;
      description.text = channel.description;
      setState(() => savedLabel = raftText(context, 'Changes saved'));
      savedTimer = Timer(const Duration(milliseconds: 1500), () {
        savedTimer = null;
        if (mounted) setState(() => savedLabel = null);
      });
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => error = failText(e, 'Failed to update channel'));
      }
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  /// Enter in the name field submits the form: save, then close the drawer.
  Future<void> saveAndClose() async {
    if (await saveChanges() && mounted) closeSheet();
  }

  /// Pops the drawer route itself: every caller has already decided to close
  /// (a clean draft, a discard, a finished action), so PopScope must not ask.
  void closeSheet() {
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  /// OverflowSheet `closeGuardRef`: with an unsaved name / description draft
  /// every dismissal (back, outside press, Escape) asks first.
  Future<void> guardedClose() => guardedTransition(closeSheet);

  Future<void> guardedTransition(VoidCallback transition) async {
    if (!dirty) return transition();
    var busy = false;
    await showRaftModal<void>(
      context,
      builder: (dialogContext) => StatefulBuilder(
        // Web `Modal onClose`: Escape does nothing while the save runs.
        builder: (dialogContext, setDialog) => PopScope(
          canPop: !busy,
          child: RaftUnsavedChangesPrompt(
            message: 'The channel name or description has unsaved edits. Save them before closing?',
            busy: busy,
            onKeepEditing: () => Navigator.of(dialogContext).pop(),
            onDiscard: () {
              Navigator.of(dialogContext).pop();
              resetDraft();
              transition();
            },
            onSaveAndClose: () async {
              setDialog(() => busy = true);
              final saved = await saveChanges();
              if (!dialogContext.mounted) return;
              setDialog(() => busy = false);
              if (!saved) return;
              Navigator.of(dialogContext).pop();
              transition();
            },
          ),
        ),
      ),
    );
  }

  /// ConfirmDialog: the dialog owns the in-flight state and shows a thrown
  /// error under the copy; [action] returns normally to close it.
  Future<bool> confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
    required String loadingLabel,
    required Future<void> Function() action,
    RaftButtonRecipeVariant variant = RaftButtonRecipeVariant.warning,
    Key? confirmKey,
  }) async =>
      await RaftConfirmDialog.show(
        context,
        RaftConfirmDialog(
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          loadingLabel: loadingLabel,
          confirmVariant: variant,
          confirmKey: confirmKey,
          surfaceKey: const ValueKey('channel-settings-confirm-dialog'),
          onConfirm: action,
        ),
      ) ==
      true;

  RaftChannel? get fallbackChannel => [
    ...w.channels.where((c) => c.id != channel.id && c.name == 'all'),
    ...w.channels.where((c) => c.id != channel.id),
  ].firstOrNull;

  /// Web `err.response?.data?.error || formatMessage(fallback)`, localized.
  String failText(Object e, String fallback) => raftText(
    context,
    userErrorText(e, fallback: fallback, where: 'channel settings'),
  );

  Future<void> failWith(Object e, String fallback) async {
    if (!mounted) return;
    setState(() => error = failText(e, fallback));
  }

  Future<void> archive() async {
    final c = channel;
    var failed = false;
    final ok = await confirmAction(
      title: 'Archive Channel',
      message: raftFormat(
        context,
        'Members keep read access to "{name}" and its history, but posting will stop and the channel will be hidden from sidebars. You can unarchive it later.',
        {'name': c.name},
      ),
      confirmLabel: 'Archive',
      loadingLabel: 'Archiving…',
      action: () async {
        try {
          await w.command('POST', '/channels/${c.id}/archive');
          await w.refreshChannels();
        } catch (e) {
          // The drawer, not the dialog, reports an archive failure.
          failed = true;
          await failWith(e, 'Failed to archive channel');
        }
      },
    );
    if (ok && !failed && mounted) closeSheet();
  }

  Future<void> unarchive() async {
    if (archiveBusy) return;
    setState(() {
      archiveBusy = true;
      error = null;
    });
    try {
      await w.command('POST', '/channels/${channel.id}/unarchive');
      await w.refreshChannels();
      await load();
    } catch (e) {
      await failWith(e, 'Failed to unarchive channel');
    } finally {
      if (mounted) setState(() => archiveBusy = false);
    }
  }

  Future<void> changeVisibility() async {
    final c = channel;
    final all = c.name == 'all';
    final toPublic = c.type == 'private';
    var failed = false;
    final label = all
        ? (toPublic ? 'Restore #all' : 'Hide #all')
        : (toPublic ? 'Make Channel Public' : 'Make Channel Private');
    final ok = await confirmAction(
      title: label,
      message: all
          ? (toPublic
                ? '#all will reappear as the server-wide channel for server members and active agents.'
                : '#all will disappear from channel lists, and server members and agents will no longer be able to read or post there — including you. Existing history is preserved. To bring it back, go to Settings → Server → System Channels and turn off "Hide #all channel".')
          : raftFormat(
              context,
              toPublic
                  ? 'All server members will regain read access to "{name}". Existing joined humans and agents keep their joined state.'
                  : 'Existing joined humans and agents keep access to "{name}". Non-joined server members and historical thread followers will lose access to the channel and its threads.',
              {'name': c.name},
            ),
      confirmLabel: all
          ? (toPublic ? 'Restore #all' : 'Hide #all')
          : (toPublic ? 'Public' : 'Private'),
      loadingLabel: 'Updating…',
      action: () async {
        setState(() {
          visibilityBusy = true;
          error = null;
        });
        try {
          // #all travels through its dedicated, id-free endpoints.
          if (all) {
            await w.command(
              'POST',
              '/channels/system/all/${toPublic ? 'restore' : 'hide'}',
            );
          } else {
            await w.command(
              'PATCH',
              '/channels/${c.id}',
              data: {'visibility': toPublic ? 'public' : 'private'},
            );
          }
          await w.refreshChannels();
        } catch (e) {
          failed = true;
          await failWith(e, 'Failed to update channel visibility');
        } finally {
          if (mounted) setState(() => visibilityBusy = false);
        }
      },
    );
    if (!ok || failed || !mounted) return;
    closeSheet();
    if (all && !toPublic) {
      final next = fallbackChannel;
      if (next != null) unawaited(w.selectChannel(next));
    }
  }

  Future<void> leave() async {
    final c = channel;
    final ok = await confirmAction(
      title: 'Leave Channel',
      message: raftFormat(
        context,
        'You will stop receiving ordinary delivery from #{name} and cannot send messages until you rejoin. Existing followed threads are not automatically unfollowed; followed public threads can still notify you until you unfollow or manage those threads. Private content remains gated by current access.',
        {'name': c.name},
      ),
      confirmLabel: 'Leave',
      loadingLabel: 'Leaving…',
      confirmKey: const ValueKey('channel-overflow-leave-confirm'),
      action: () async {
        await w.command('POST', '/channels/${c.id}/leave');
        await w.refreshChannels();
      },
    );
    if (ok && mounted) closeSheet();
  }

  Future<void> deleteFromPanel() async {
    final c = channel;
    final ok = await confirmAction(
      title: 'Delete Channel',
      message: raftFormat(
        context,
        '"{name}" and all of its messages will be permanently deleted. This cannot be undone.',
        {'name': c.name},
      ),
      confirmLabel: 'Delete',
      loadingLabel: 'Deleting…',
      variant: RaftButtonRecipeVariant.danger,
      action: () async {
        await w.command('DELETE', '/channels/${c.id}');
        await w.refreshChannels();
      },
    );
    if (!ok || !mounted) return;
    closeSheet();
    final next = fallbackChannel;
    if (next != null) unawaited(w.selectChannel(next));
  }

  Future<void> updateGuestPolicy(Map<String, dynamic> updates) async {
    if (guestBusy) return;
    setState(() {
      guestBusy = true;
      error = null;
    });
    try {
      await w.command('PATCH', '/channels/${channel.id}', data: updates);
      await w.refreshChannels();
    } catch (e) {
      await failWith(e, 'Failed to update Guest access');
    } finally {
      if (mounted) setState(() => guestBusy = false);
    }
  }

  /// Web `view: "root" | "members"` of the desktop drawer: the members page
  /// replaces the drawer content (`OverflowSheet bare`) while the root view
  /// stays mounted underneath, so an unsaved name/description draft survives.
  bool membersOpen = false, membersAdd = false;

  void closeMembers() {
    if (!membersOpen) return;
    setState(() => membersOpen = false);
    unawaited(load({'members'}));
  }

  Future<void> openMembers({bool add = false}) async {
    if (widget.page && !add && widget.onMembers != null) {
      await guardedTransition(widget.onMembers!);
      return;
    }
    if (drawer && !widget.page) {
      setState(() {
        membersOpen = true;
        membersAdd = add;
      });
      return;
    }
    await ChannelMembers.show(
      context,
      controller: w,
      channel: channel,
      startInAdd: add,
    );
    if (mounted) unawaited(load({'members'}));
  }

  Widget membersStrip(BuildContext context, RaftChannel c) {
    final origin = w.client.origin;
    RaftStripMember tile(Map<String, dynamic> m) {
      final agent = m['actorType'] == 'agent';
      final candidate = ChannelMemberCandidate(
        kind: agent ? 'agent' : 'human',
        id: '${agent ? m['id'] : (m['userId'] ?? m['id'])}',
        name: '${m['name'] ?? ''}',
        displayName: m['displayName'] as String?,
        avatarUrl: agent
            ? agentAvatarWithDirectory(
                w.services.entityDirectory.agent('${m['id']}'),
                m['avatarUrl'] as String?,
              )
            : m['avatarUrl'] as String?,
      );
      return RaftStripMember(
        label: candidate.label,
        avatar: ChannelCandidateAvatar(
          candidate: candidate,
          avatarContext: RaftMountedAvatarContext.panelHeader,
          origin: origin,
          presence: agent
              ? channelMemberPresence(
                  m,
                  directory: w.services.entityDirectory.agent('${m['id']}'),
                )
              : null,
        ),
      );
    }

    final humans = members.where((m) => m['actorType'] != 'agent').toList();
    final agents = members.where((m) => m['actorType'] == 'agent').toList();
    final canAdd = cap('addChannelMembers') && !c.archived;
    final loadingMembers = !known.contains('members');
    return RaftMembersStrip(
      heading: 'Members',
      summary: loadingMembers
          ? raftText(context, 'Loading members…')
          : channelMembersSummary(
              context,
              humans: humans.length,
              agents: agents.length,
              slack: externalMembers.length,
            ),
      loading: loadingMembers,
      members: [
        for (final m in humans) tile(m),
        for (final m in agents) tile(m),
        for (final m in externalMembers)
          slackStripMember(context, m, origin: origin),
      ],
      onOpen: openMembers,
      onAdd: canAdd ? () => openMembers(add: true) : null,
    );
  }

  Widget panel(BuildContext context) {
    final c = channel;
    final t = RaftTokens.of(context);
    final dm = c.type == 'dm';
    final all = c.name == 'all';
    final archived = c.archived;
    final canEdit =
        cap('editChannelMetadata') ||
        cap('changeChannelVisibility') ||
        cap('archiveChannels') ||
        cap('deleteChannels') ||
        cap('federateChannels');
    // ChatPanel `canManageChannels`: every management capability, including
    // the member ones the edit form itself does not need.
    final canManage =
        canEdit ||
        cap('addChannelMembers') ||
        cap('removeChannelMembers') ||
        cap('changeChannelMemberRoles');
    // ChatPanel `settings`: joined && (canManageChannels || canLeaveChannel).
    final settingsPresent = !dm && c.joined && (canManage || !all);
    final showManage = canEdit && !archived;
    final showLeave = settingsPresent && widget.leave && !all && !archived;
    final showVisibility =
        showManage && cap('changeChannelVisibility') && c.type != 'joint';
    final archiveRow = !all && cap('archiveChannels');
    final deleteRow = !all && cap('deleteChannels') && showManage;
    final showStopAgents =
        settingsPresent && !archived && w.can('controlAgentRuntime');
    final private = c.type == 'private';
    final pinned = (sidebar['pinned'] as List? ?? []).any(
      (p) => p is Map && p['kind'] == 'channel' && p['id'] == c.id,
    );
    final guestSection =
        guestFeature &&
        cap('manageGuestAccess') &&
        !archived &&
        (c.type == 'channel' || c.type == 'private') &&
        // A private channel has no guest policy; #all keeps its switch.
        !(private && !all);
    final generation = w.client.generation, serverId = w.server?.id;

    final preferences = RaftSheetSection('Preferences', [
      RaftSheetSwitchRow(
        key: const ValueKey('channel-settings-pin-switch'),
        title: 'Pin channel',
        description: 'Keep this channel pinned to the top of your sidebar.',
        value: pinned,
        pending: !known.contains('sidebar'),
        onChanged: pin,
      ),
      if (!dm &&
          c.joined &&
          channelCanToggleActivityMute(c) &&
          (!known.contains('notification') ||
              notification['activityMuted'] is bool))
        RaftSheetSwitchRow(
          key: const ValueKey('channel-overflow-mute-switch'),
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
                !channelCanToggleActivityMute(fresh) ||
                !w.can('viewChannel', resource: fresh)) {
              throw RaftUserError(
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
          key: const ValueKey('channel-settings-collapse-switch'),
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
    ]);

    final actions = [
      if (showManage && showVisibility)
        RaftOverflowAction(
          id: 'channel-settings-visibility-action',
          label: visibilityBusy
              ? 'Updating…'
              : all
              ? (private ? 'Restore #all' : 'Hide #all')
              : (private ? 'Make Public' : 'Make Private'),
          glyph: all
              ? (private ? RaftGlyph.eye : RaftGlyph.eyeOff)
              : (private ? RaftGlyph.hash : RaftGlyph.lock),
          disabled: archived || visibilityBusy,
          onPressed: changeVisibility,
        ),
      if ((showManage || archived) && archiveRow)
        if (archived)
          RaftOverflowAction(
            id: 'channel-settings-archive-action',
            label: archiveBusy ? 'Unarchiving…' : 'Unarchive Channel',
            glyph: RaftGlyph.archiveRestore,
            disabled: archiveBusy,
            onPressed: unarchive,
          )
        else
          RaftOverflowAction(
            id: 'channel-settings-archive-action',
            label: 'Archive Channel',
            glyph: RaftGlyph.archive,
            onPressed: archive,
          ),
      if (showLeave)
        RaftOverflowAction(
          id: 'channel-overflow-leave',
          label: 'Leave Channel',
          glyph: RaftGlyph.logOut,
          onPressed: leave,
        ),
      if (showStopAgents)
        RaftOverflowAction(
          id: 'channel-overflow-stop-agents',
          label: 'Stop Agents',
          semanticLabel: 'Stop all agents in this channel',
          glyph: RaftGlyph.circleStop,
          onPressed: stopAgents,
        ),
      if (deleteRow)
        RaftOverflowAction(
          id: 'channel-settings-delete-action',
          label: 'Delete Channel',
          glyph: RaftGlyph.trash2,
          danger: true,
          onPressed: deleteFromPanel,
        ),
    ];

    final hidesMembers =
        all &&
        w.server?.string('role') == 'member' &&
        w.server?.flag('hideHumansFromMembers') == true;
    final stripShown = !dm && !hidesMembers;
    final info = canEdit && !dm;

    final Widget body = dm
        ? RaftOverflowDmBody(
            child: raftSheetSection(
              context,
              t,
              preferences,
              busy: busy,
              family: t.bodyFont,
            ),
          )
        : settingsPresent
        ? (!flagsKnown
              ? const RaftOverflowLoading()
              : RaftOverflowPanelBody(
                  children: [
                    if (info)
                      ChannelConversionSection(
                        key: ValueKey('conversion-${w.server?.id}-${c.id}'),
                        controller: w,
                        channelId: c.id,
                      ),
                    if (showManage && info)
                      const RaftOverflowGroupHeading(
                        key: ValueKey('channel-settings-manage-group'),
                        title: 'Info',
                        description:
                            'Name and description shown across the workspace.',
                      ),
                    if (error != null) RaftOverflowFormError(error!),
                    if (info)
                      RaftChannelInfoForm(
                        nameController: name,
                        descriptionController: description,
                        nameEnabled: !all && !archived,
                        descriptionEnabled: !archived,
                        nameHint: all
                            ? 'The #all channel cannot be renamed'
                            : null,
                        onSubmitName: (_) => saveAndClose(),
                        canCancel: nameDescDirty,
                        canSave: nameDescDirty && !archived,
                        saving: saving,
                        savedLabel: savedLabel,
                        onCancel: resetDraft,
                        onSave: saveChanges,
                      ),
                    if (guestSection)
                      raftSheetSection(
                        context,
                        t,
                        RaftSheetSection(
                          'Guest access',
                          description: 'Choose whether Guests can discover this channel and join it themselves.',
                          [
                            RaftSheetSwitchRow(
                              key: const ValueKey(
                                'channel-settings-guest-visible-switch',
                              ),
                              title: 'Visible to Guests',
                              description: 'Guests can discover and read this channel without joining.',
                              value: c.flag('guestVisible'),
                              onChanged: (v) => updateGuestPolicy(
                                v
                                    ? {'guestVisible': true}
                                    : {
                                        'guestVisible': false,
                                        'guestJoinable': false,
                                      },
                              ),
                            ),
                            if (!all)
                              RaftSheetSwitchRow(
                                key: const ValueKey(
                                  'channel-settings-guest-joinable-switch',
                                ),
                                title: 'Guests can join',
                                description: 'Guests can join to keep this channel in their sidebar and follow updates. Guest access remains read-only.',
                                value: c.flag('guestJoinable'),
                                onChanged: (v) => updateGuestPolicy(
                                  v
                                      ? {
                                          'guestVisible': true,
                                          'guestJoinable': true,
                                        }
                                      : {'guestJoinable': false},
                                ),
                              ),
                          ],
                        ),
                        busy: busy || guestBusy,
                        family: t.bodyFont,
                      ),
                    raftSheetSection(
                      context,
                      t,
                      preferences,
                      busy: busy,
                      family: t.bodyFont,
                    ),
                    if (actions.isNotEmpty)
                      RaftOverflowActions(
                        title: 'Actions',
                        actions: [
                          for (final a in actions)
                            RaftOverflowAction(
                              id: a.id,
                              label: raftText(context, a.label),
                              glyph: a.glyph,
                              danger: a.danger,
                              disabled: a.disabled || busy,
                              semanticLabel: a.semanticLabel == null
                                  ? null
                                  : raftText(context, a.semanticLabel!),
                              onPressed: a.onPressed,
                            ),
                        ],
                      ),
                  ],
                ))
        : const SizedBox.shrink();

    final sheet = RaftOverflowSheet(
      page: widget.page,
      title: dm ? (widget.dmName ?? c.name) : '#${c.name}',
      badge: dm
          ? 'Direct message'
          : private
          ? 'Private'
          : c.type == 'joint'
          ? 'Joint channel'
          : 'Public',
      badgeTone: dm
          ? RaftBadgeRecipeVariant.muted
          : RaftBadgeRecipeVariant.success,
      subtitle: settingsPresent ? c.description : null,
      onClose: guardedClose,
      children: [
        if (stripShown) membersStrip(context, c),
        // Without the settings panel (a DM, a left channel) the failure of a
        // preference write still has to be visible.
        if (error != null && (dm || !settingsPresent || !flagsKnown))
          RaftOverflowNotice(error!),
        body,
      ],
    );
    // The barrier is the area outside the drawer: a press there is a close
    // attempt like any other (Escape goes through RaftDismissScope, back
    // through PopScope).
    final root = widget.page
        ? sheet
        : Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('channel-overflow-scrim'),
                  behavior: HitTestBehavior.opaque,
                  onTap: guardedClose,
                ),
              ),
              // Web OverflowSheet `swipeDirection="right"`: a fling to the right
              // dismisses the drawer (through the same unsaved-draft guard).
              GestureDetector(
                key: const ValueKey('channel-overflow-swipe'),
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (details) {
                  if ((details.primaryVelocity ?? 0) > 400) guardedClose();
                },
                child: sheet,
              ),
            ],
          );
    return RaftDismissScope(
      // Web OverflowSheet: Escape closes the drawer through the same
      // unsaved-draft guard as the scrim and the X.
      enabled: !widget.page,
      onDismiss: guardedClose,
      child: PopScope(
        // The members page owns back while it is open (it returns to the root
        // view, or from its add view to the roster).
        canPop: !dirty && !membersOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !membersOpen) guardedClose();
        },
        child: widget.page
            ? root
            : Stack(
                children: [
                  Offstage(
                    offstage: membersOpen,
                    child: ExcludeFocus(excluding: membersOpen, child: root),
                  ),
                  if (membersOpen)
                    Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: guardedClose,
                          ),
                        ),
                        RaftOverflowBareSheet(
                          child: ChannelMembers(
                            key: ValueKey('channel-members-page-${c.id}'),
                            controller: w,
                            channel: channel,
                            page: true,
                            embedded: true,
                            startInAdd: membersAdd,
                            onClose: closeMembers,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> stopAgents() => showChannelSos(
    context,
    w,
    channel,
    agentName: (id) =>
        members.where((row) => row['id'] == id).firstOrNull?['name']
            as String? ??
        id,
  );

  Future<void> deleteChannel() async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
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
