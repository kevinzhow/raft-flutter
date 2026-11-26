import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'notification_level_menu.dart';

import '../data/channel_roster_invalidations.dart';
import '../data/resource_snapshot_cache.dart' show stableValue;
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import 'channel_activity_session.dart';
import 'channel_announcement_settings.dart';
import 'channel_conversion_section.dart';
import 'channel_details_slack.dart';
import 'channel_form_fields.dart';
import 'channel_joint_section.dart';
import 'channel_joint_section_actions.dart' show jointHostExternal;
import 'channel_members.dart';
import 'channel_settings_strip.dart';
import 'channel_section_select.dart';
import 'channel_sos.dart';
import 'slack_channel_pairing.dart';
import 'composer_directory.dart'
    show cachedChannelRoster, cachedChannelRosterExternals;
import 'create_channel_dialog.dart'
    show
        ArchivedChannelNameCollision,
        ChannelMemberCandidate,
        channelNameError,
        parseArchivedChannelNameCollision;
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
    this.details = false,
    this.headerWrapper,
    this.onClose,
    this.onMembers,
    this.dmName,
  });
  final WorkspaceController controller;
  final RaftChannel channel;

  /// A DM's sheet title: the peer's plain name (ChatPanel `displayName`).
  final String? dmName;

  /// Standalone drawer used by legacy parity fixtures. The workspace mounts
  /// Details in ChannelDetailsHost on wide layouts and in a page on phones.
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
  final bool details;
  final Widget Function(BuildContext, Widget)? headerWrapper;
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

  /// The reads Web reports by name; any other part keeps its accepted value
  /// and says nothing, as Web does.
  static const _loadFailureText = {
    'display': 'Failed to load message display settings.',
    'notification': 'Failed to load Activity mute setting.',
  };

  /// The named reads behind the current [error]; its Retry reloads only these.
  List<String> _retryParts = const [];

  /// Web gives each failed preference read its own retry; a plain list keeps
  /// this off any collection `load` is still writing to.
  VoidCallback? get retryLoad => _retryParts.isEmpty
      ? null
      : () => unawaited(load({..._retryParts}));
  late final activity = ChannelActivitySession.of(w);

  /// The Slack channel this channel is paired with (Web
  /// `useChannelSlackBridgeEditor`): a section only while the bridge is ready.
  late final SlackChannelPairing slack = SlackChannelPairing(
    w,
    channelId: widget.channel.id,
  )..addListener(_slackChanged);
  void _slackChanged() {
    if (mounted) setState(() {});
  }

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
    flagsKnown = cachedServerFlag(w, channelConversionFlag) != null;
    if (widget.details) activity.addListener(activityChanged);
    load();
    loadFlags();
    ChannelRosterInvalidations.of(w.client).addListener(rosterInvalidated);
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

  void activityChanged() {
    if (mounted) setState(() {});
  }

  void rosterInvalidated() {
    if (ChannelRosterInvalidations.of(w.client).value.$2 == widget.channel.id) {
      unawaited(load({'members'}));
    }
  }

  @override
  void dispose() {
    ChannelRosterInvalidations.of(w.client).removeListener(rosterInvalidated);
    if (widget.details) activity.removeListener(activityChanged);
    name.removeListener(draftChanged);
    description.removeListener(draftChanged);
    editFocus.dispose();
    name.dispose();
    description.dispose();
    slack.dispose();
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
        renameCollision = null;
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
        if ((part != 'notification' ||
                channelCanToggleActivityMute(channel) ||
                widget.details &&
                    channel.type == 'dm' &&
                    (channel.flag('activityMuteSupported') ||
                        channel.flag('activityMuted'))) &&
            // A 1:1 DM sheet has no members section (ChatPanel #1281).
            !(part == 'members' && drawer && channel.type == 'dm'))
          part,
    ];
    final tickets = {
      for (final part in wanted) part: _tickets[part] = ++_ticket,
    };
    Future<dynamic> readMembers() => w.query('/channels/$id/members');
    Future<dynamic> fetch(String part) => switch (part) {
      'members' =>
        parts != _parts || known.contains('members')
            ? RaftClient.runRevalidating(readMembers)
            : readMembers(),
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
      final failures = <String, Object>{};
      final values = await Future.wait([
        for (final part in wanted)
          Future<dynamic>.sync(() => fetch(part)).catchError((Object e) {
            failure ??= e;
            failed.add(part);
            failures[part] = e;
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
        // Name the read that failed and keep just that read retryable. Web
        // reports only these two; a failed roster or sidebar order keeps its
        // accepted value and says nothing (useChannelMembers.ts:187-190,
        // serverStore.ts:826-835), so neither does this.
        final displayFailed = failed.contains('display');
        final notificationFailed = failed.contains('notification');
        _retryParts = [
          if (displayFailed) 'display',
          if (notificationFailed) 'notification',
        ];
        final named = displayFailed
            ? 'display'
            : notificationFailed
            ? 'notification'
            : '';
        error = named.isEmpty
            ? null
            : failText(failures[named]!, _loadFailureText[named]!);
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

  /// The channel's Notifications select (Web NotificationLevelSelect with
  /// the Activity mute as its third choice).
  RaftSheetSwitchRow notificationLevelRow(
    RaftChannel c,
    String serverId,
    int generation,
  ) {
    final canMute =
        channelCanToggleActivityMute(c) &&
        (!known.contains('notification') ||
            notification['activityMuted'] is bool);
    return RaftSheetSwitchRow.control(
      key: const ValueKey('channel-settings-notification-level'),
      title: 'Notifications',
      control: NotificationLevelSelect(
        client: w.client,
        serverId: serverId,
        channelId: c.id,
        serverRow: w.server,
        disabled: busy || canMute && !known.contains('notification'),
        label: raftText(context, 'Notifications'),
        onFailed: (message) => showRaftToast(context, message),
        mute: canMute
            ? NotificationMuteControl(
                muted: notification['activityMuted'] == true,
                setMuted: (value) async {
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
                    setState(
                      () => error =
                          'Channel activity preference is no longer available.',
                    );
                    return false;
                  }
                  if (widget.details) {
                    return writePreference(
                      c,
                      'notification-settings',
                      'activityMuted',
                      value,
                    );
                  }
                  var ok = true;
                  await run(() async {
                    try {
                      await w.command(
                        'PATCH',
                        '/channels/${c.id}/notification-settings',
                        data: {'activityMuted': value},
                      );
                    } catch (_) {
                      ok = false;
                      rethrow;
                    }
                  });
                  return ok;
                },
              )
            : null,
      ),
    );
  }

  Future<bool> writePreference(
    RaftChannel c,
    String endpoint,
    String key,
    bool next,
  ) async {
    if (busy || !mounted || !w.can('viewChannel', resource: channel)) {
      return false;
    }
    final identity = pageIdentity(w);
    final target = key == 'activityMuted' ? notification : display;
    final before = Map<String, dynamic>.of(target);
    void project(Map<String, dynamic> fields) {
      if (key == 'activityMuted') {
        w.setActivityMuteState(c.id, fields);
      } else {
        w.channelRepository.consumeMessageDisplayPrefs({
          'serverId': w.server!.id,
          'scopeId': c.id,
          'prefs': {key: fields[key] == true},
          'prefsVersion': fields['prefsVersion'],
        });
        w.notifyListeners();
      }
    }

    setState(() {
      busy = true;
      error = null;
      target[key] = next;
    });
    project(target);
    try {
      final result = await w.command(
        'PATCH',
        '/channels/${c.id}/$endpoint',
        data: {key: next},
      );
      if (identity != pageIdentity(w)) return false;
      if (result is! Map) {
        throw const FormatException('Invalid channel preference response');
      }
      target.addAll(Map<String, dynamic>.from(result));
      project(target);
      return true;
    } catch (e) {
      if (identity == pageIdentity(w)) {
        target
          ..clear()
          ..addAll(before);
        project(before);
        if (mounted) {
          setState(
            () => error = failText(
              e,
              key == 'activityMuted'
                  ? next
                        ? 'Failed to mute Activity for this conversation.'
                        : 'Failed to unmute Activity for this conversation.'
                  : 'Failed to update message display settings.',
            ),
          );
        }
      }
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
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
    required String submit,
    String cancel = 'Cancel',
    dynamic data,
    bool destructive = false,
  }) async {
    await showRaftDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RaftFormDialog(
        title: title,
        description: description,
        fields: [],
        submitLabel: submit,
        cancelLabel: cancel,
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
  bool visitorShown = false;

  /// The Slack and joint-conversion flags in one evaluation, remembered for
  /// this server identity so later visits render their sections at once.
  Future<void> loadFlags() async {
    final serverId = w.server?.id, identity = pageIdentity(w);
    if (serverId == null) return;
    try {
      final result = await w.command(
        'POST',
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(
          keys: [channelConversionFlag, SlackChannelPairing.flag],
          serverId: serverId,
        ),
      );
      bool enabled(String key) =>
          result is Map &&
          (result['evaluations'] as List? ?? []).whereType<Map>().any(
            (f) => f['key'] == key && f['enabled'] == true,
          );
      rememberServerFlag(
        w,
        channelConversionFlag,
        enabled(channelConversionFlag),
        identity,
      );
      if (mounted && identity == pageIdentity(w)) {
        setState(() {
          flagsKnown = true;
        });
        unawaited(
          slack.load(
            canManage: canEditChannel,
            flagEnabled: enabled(SlackChannelPairing.flag),
          ),
        );
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

  /// Web `canEditChannel`: any management capability the edit form needs.
  bool get canEditChannel =>
      cap('editChannelMetadata') ||
      cap('changeChannelVisibility') ||
      cap('archiveChannels') ||
      cap('deleteChannels') ||
      cap('federateChannels');

  bool _readingMetadata = false;
  RaftChannel? _metadataSeed;

  Future<RaftChannel?> _readMetadataForEdit() async {
    final current = channel, identity = pageIdentity(w);
    if (_readingMetadata || current.archived || !cap('editChannelMetadata')) {
      return null;
    }
    _readingMetadata = true;
    bool accepts() =>
        mounted && identity == pageIdentity(w) && channel.id == current.id;
    try {
      final result = await RaftClient.runFresh(
        () => w.query('/channels/${Uri.encodeComponent(current.id)}'),
      );
      if (!accepts() || !cap('editChannelMetadata')) return null;
      if (result is! Map ||
          result['id'] != current.id ||
          result['name'] is! String) {
        throw const FormatException('Invalid channel response');
      }
      final fresh = RaftChannel(Map<String, dynamic>.from(result));
      if (fresh.archived || !w.can('editChannelMetadata', resource: fresh)) {
        throw RaftUserError('Channel editing is no longer available.');
      }
      return fresh;
    } catch (failure) {
      if (accepts()) await failWith(failure, 'Failed to load channel');
      return null;
    } finally {
      _readingMetadata = false;
    }
  }

  Future<void> editMetadata() async {
    final identity = pageIdentity(w);
    final c = await _readMetadataForEdit();
    if (!mounted || c == null || identity != pageIdentity(w)) return;
    await showRaftForm<void>(
      context,
      builder: (_) => RaftFormDialog(
        title: 'Edit channel',
        fields: [
          if (c.name != 'all')
            RaftFormField(
              'name',
              'Name',
              initial: c.name,
              required: true,
              validator: (value) => channelNameError(context, value.trim()),
            ),
          RaftFormField(
            'description',
            'Description',
            initial: c.description,
            multiline: true,
          ),
        ],
        errorContent: (dialogContext, failure) {
          final collision = parseArchivedChannelNameCollision(failure);
          if (collision == null) return null;
          void open() {
            if (!mounted || identity != pageIdentity(w)) return;
            Navigator.of(dialogContext).pop();
            closeSheet();
            unawaited(w.jumpToMessage(collision.id, null));
          }

          return raftArchivedNameBanner(
            dialogContext,
            name: collision.name,
            canUnarchive: collision.canUnarchive,
            showHint: false,
            onOpen: open,
            onUnarchive: () async {
              if (!mounted || identity != pageIdentity(w)) return;
              try {
                await w.command('POST', '/channels/${collision.id}/unarchive');
                if (dialogContext.mounted) open();
              } catch (error) {
                if (dialogContext.mounted) {
                  showRaftToast(
                    dialogContext,
                    userErrorText(
                      error,
                      fallback: 'Failed to unarchive channel',
                    ),
                  );
                }
              }
            },
          );
        },
        onSubmit: (values) async {
          if (!mounted ||
              identity != pageIdentity(w) ||
              channel.archived ||
              !cap('editChannelMetadata')) {
            throw RaftUserError('Channel editing is no longer available.');
          }
          final updates = {
            if (values['name'] case final String name when name != c.name)
              'name': name,
            if (values['description'] case final String description
                when description != c.description.trim())
              'description': description,
          };
          if (updates.isNotEmpty) await patchChannel(c, updates);
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
      title: dm ? 'Conversation Settings' : 'Settings',
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
        if (visitorVisibleOffered(c))
          RaftSheetSection('Channel settings', [visitorVisibleRow(c)]),
        RaftSheetSection('Preferences', [
          RaftSheetSwitchRow(
            title: 'Pin channel',
            description: 'Keep this channel pinned to the top of your sidebar.',
            value: pinned,
            pending: !known.contains('sidebar'),
            onChanged: pin,
          ),
          // ChannelPreferencesSection: the channel's level and its mute are
          // one choice (All / Only what involves me / Mute).
          if (widget.isPanel && !dm && c.joined && serverId != null)
            notificationLevelRow(c, serverId, generation),
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
            'Leave channel',
            RaftGlyph.logOut,
            RaftButtonRecipeVariant.warning,
            () => confirm(
              'Leave channel',
              'You can rejoin a public channel later.',
              'POST',
              '/channels/${c.id}/leave',
              submit: 'Leave channel',
              cancel: 'Stay in Channel',
            ),
          ),
        if (showVisibility)
          RaftSheetAction(
            private ? 'Make public' : 'Make private',
            private ? RaftGlyph.hash : RaftGlyph.lock,
            RaftButtonRecipeVariant.warning,
            () => confirm(
              private ? 'Make public' : 'Make private',
              private
                  ? 'Everyone in this server can read this channel.'
                  : 'Only channel members can read this channel.',
              'PATCH',
              '/channels/${c.id}',
              submit: private ? 'Make public' : 'Make private',
              data: {'visibility': private ? 'public' : 'private'},
            ),
          ),
        if (!all && cap('archiveChannels'))
          archived
              ? RaftSheetAction(
                  'Unarchive channel',
                  RaftGlyph.archiveRestore,
                  RaftButtonRecipeVariant.success,
                  () => run(() async {
                    await w.command('POST', '/channels/${c.id}/unarchive');
                  }),
                )
              : RaftSheetAction(
                  'Archive channel',
                  RaftGlyph.archive,
                  RaftButtonRecipeVariant.warning,
                  () => confirm(
                    'Archive channel',
                    'Archived channels retain history and stop new messages.',
                    'POST',
                    '/channels/${c.id}/archive',
                    submit: 'Archive channel',
                    cancel: 'Keep Channel',
                  ),
                ),
        if (showStopAgents)
          RaftSheetAction(
            'Stop all agents',
            RaftGlyph.circleStop,
            RaftButtonRecipeVariant.outline,
            stopAgents,
          ),
        if (!all &&
            !archived &&
            cap('deleteChannels') &&
            !jointHostExternal(w, c))
          // A joint channel cannot be deleted (the server answers 400): the
          // action is Disconnect (Web `showCompletedJointSettings`).
          if (joint)
            RaftSheetAction(
              'Disconnect channel',
              RaftGlyph.unplug,
              RaftButtonRecipeVariant.danger,
              disconnectFromPanel,
            )
          else
            RaftSheetAction(
              'Delete channel',
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

  RaftChannel get _metadataBase => _metadataSeed ?? channel;
  bool get nameDescDirty =>
      name.text != _metadataBase.name ||
      description.text != _metadataBase.description;

  /// Mirrors `isDirty`: the host drawer guards every dismissal while true.
  bool get dirty =>
      ((!widget.details || metadataEditing) && nameDescDirty) ||
      (!widget.details && slack.dirty) ||
      jointDraft;

  bool metadataEditing = false;
  ArchivedChannelNameCollision? renameCollision;
  bool renameUnarchiving = false;
  final editFocus = FocusNode(debugLabel: 'channel details edit');

  Future<void> startMetadataEdit() async {
    final fresh = await _readMetadataForEdit();
    if (!mounted || fresh == null) return;
    _metadataSeed = fresh;
    resetDraft();
    setState(() => metadataEditing = true);
  }

  void finishMetadataEdit() {
    setState(() {
      metadataEditing = false;
      _metadataSeed = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) editFocus.requestFocus();
    });
  }

  Future<void> saveMetadataEdit() async {
    if (await saveChanges() && mounted) finishMetadataEdit();
  }

  void openArchivedName(ArchivedChannelNameCollision collision) {
    closeSheet();
    unawaited(w.jumpToMessage(collision.id, null));
  }

  Future<void> unarchiveName(ArchivedChannelNameCollision collision) async {
    if (renameUnarchiving) return;
    final identity = pageIdentity(w);
    setState(() => renameUnarchiving = true);
    try {
      await w.command('POST', '/channels/${collision.id}/unarchive');
      if (mounted && identity == pageIdentity(w)) openArchivedName(collision);
    } catch (e) {
      await failWith(e, 'Failed to unarchive channel');
    } finally {
      if (mounted) setState(() => renameUnarchiving = false);
    }
  }

  Widget metadataForm(RaftChannel c) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (renameCollision case final collision?)
        raftArchivedNameBanner(
          context,
          key: const Key('channel-settings-rename-collision'),
          name: collision.name,
          canUnarchive: collision.canUnarchive,
          busy: renameUnarchiving,
          showHint: false,
          onOpen: () => openArchivedName(collision),
          onUnarchive: () => unarchiveName(collision),
        ),
      RaftChannelInfoForm(
        nameController: name,
        descriptionController: description,
        nameEnabled: c.name != 'all' && !c.archived,
        descriptionEnabled: !c.archived,
        nameHint: c.name == 'all' ? 'The #all channel cannot be renamed' : null,
        descriptionHint: c.type == 'joint' || c.hasExternalRelation == true
            ? raftText(
                context,
                'Name and description show on every server in this channel.',
              )
            : c.type == 'private'
            ? raftText(context, "Shown to the channel's members.")
            : raftFormat(context, 'Shown to everyone in {server}.', {
                'server': w.server?.name ?? '',
              }),
        onSubmitName: (_) => saveMetadataEdit(),
        canCancel: true,
        canSave: nameDescDirty && !c.archived,
        saving: saving,
        savedLabel: savedLabel,
        onCancel: () {
          resetDraft();
          finishMetadataEdit();
        },
        onSave: saveMetadataEdit,
      ),
    ],
  );

  /// An invitation typed into the joint section and not sent (Web
  /// `hasInviteDraft`): it blocks Save and close, whose save cannot send it.
  bool jointDraft = false;
  final jointKey = GlobalKey<ChannelJointSectionState>();

  void resetDraft() {
    name.text = _metadataBase.name;
    description.text = _metadataBase.description;
    slack.reset();
    clearSaved();
    setState(() {
      error = null;
      renameCollision = null;
    });
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
    final c = _metadataBase;
    final canEdit =
        cap('editChannelMetadata') ||
        cap('changeChannelVisibility') ||
        cap('archiveChannels') ||
        cap('deleteChannels') ||
        cap('federateChannels');
    setState(() => error = null);
    clearSaved();
    if (widget.details && !metadataEditing) return true;
    if (widget.details && (channel.archived || !cap('editChannelMetadata'))) {
      setState(
        () => error = raftText(
          context,
          'Channel editing is no longer available.',
        ),
      );
      return false;
    }
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
        if (description.text.trim() != c.description.trim())
          'description': description.text.trim(),
      };
      if (updates.isNotEmpty) {
        if (widget.details) {
          await patchChannel(c, updates);
        } else {
          await w.command('PATCH', '/channels/${c.id}', data: updates);
          await w.refreshChannels();
        }
      }
      // The Slack pairing is applied with the channel; its failure leaves the
      // channel saved and says so (Web `channel.bridge.partialFailure`).
      try {
        if (!widget.details) await slack.apply(c.id);
      } catch (_) {
        if (mounted) {
          setState(
            () => error = raftText(
              context,
              'The channel was saved, but its Slack bridge was not enabled. Retry to finish the bridge setup.',
            ),
          );
        }
        return false;
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
        setState(() {
          renameCollision = widget.details
              ? parseArchivedChannelNameCollision(e)
              : null;
          error = renameCollision == null
              ? failText(e, 'Failed to update channel')
              : null;
        });
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
    await showRaftDialog<void>(
      context: context,
      modal: true,
      builder: (dialogContext) => StatefulBuilder(
        // Web `Modal onClose`: Escape does nothing while the save runs.
        builder: (dialogContext, setDialog) => PopScope(
          canPop: !busy,
          child: RaftUnsavedChangesPrompt(
            message: jointDraft
                ? 'A Joint invitation has not been sent. Keep editing to send it, or discard all unsaved changes before closing.'
                : 'The channel name or description has unsaved edits. Save them before closing?',
            busy: busy,
            onKeepEditing: () => Navigator.of(dialogContext).pop(),
            onDiscard: () {
              Navigator.of(dialogContext).pop();
              jointKey.currentState?.discardDraft();
              resetDraft();
              transition();
            },
            onSaveAndClose: jointDraft
                ? null
                : () async {
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
    String cancelLabel = 'Cancel',
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
          cancelLabel: cancelLabel,
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
      title: 'Archive channel',
      message: raftFormat(
        context,
        'Members keep read access to "{name}" and its history, but posting will stop and the channel will be hidden from sidebars. You can unarchive it later.',
        {'name': c.name},
      ),
      confirmLabel: 'Archive channel',
      cancelLabel: 'Keep Channel',
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
        : (toPublic ? 'Make public' : 'Make private');
    final ok = await confirmAction(
      title: label,
      message: all
          ? (toPublic
                ? '#all will reappear as the server-wide channel for server members and active agents.'
                : '#all will disappear from channel lists, and server members and agents will no longer be able to read or post there — including you. Existing history is preserved. To bring it back, go to Settings → Administration → System Channels and turn off "Hide #all channel".')
          : raftFormat(
              context,
              toPublic
                  ? 'All server members will regain read access to "{name}". Existing joined humans and agents keep their joined state.'
                  : 'Existing joined humans and agents keep access to "{name}". Non-joined server members and historical thread followers will lose access to the channel and its threads.',
              {'name': c.name},
            ),
      confirmLabel: all
          ? (widget.details ? (toPublic ? 'Restore' : 'Hide') : label)
          : (toPublic ? 'Make public' : 'Make private'),
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

  Widget visibilitySetting(RaftChannel c) {
    final all = c.name == 'all', isPrivate = c.type == 'private';
    return raftDetailsActionRow(
      key: const Key('channel-settings-visibility'),
      title: raftText(
        context,
        all && isPrivate
            ? 'Hidden'
            : isPrivate
            ? 'Private'
            : 'Public',
      ),
      description: isPrivate
          ? raftText(
              context,
              all
                  ? 'No one can read or post in it. Its history is kept.'
                  : 'Only its members can find and read it.',
            )
          : raftFormat(context, 'Everyone in {server} can find and read it.', {
              'server': w.server?.name ?? '',
            }),
      action: RaftButton(
        key: const Key('channel-settings-visibility-action'),
        label: raftText(
          context,
          visibilityBusy
              ? 'Updating…'
              : all
              ? isPrivate
                    ? 'Restore #all'
                    : 'Hide #all'
              : isPrivate
              ? 'Make public'
              : 'Make private',
        ),
        uiVariant: RaftButtonVariant.outline,
        onPressed: visibilityBusy || saving ? null : changeVisibility,
      ),
    );
  }

  Future<void> leave() async {
    final c = channel;
    final deletes =
        widget.details && c.type == 'private' && members.length <= 1;
    final message = widget.details
        ? switch (c.type) {
            'private' => "You'll stop getting messages from #{name} and can't post there. To come back, a member has to invite you again.",
            'joint' => "You'll stop getting messages from #{name} and can't post there. To come back, an admin has to invite you again.",
            _ => "You'll stop getting messages from #{name} and can't post there. You can rejoin any time. Threads you follow will still notify you until you unfollow them.",
          }
        : "You'll stop getting messages from #{name} and can't post there. You can rejoin any time. Threads you follow will still notify you until you unfollow them.";
    final ok = await confirmAction(
      title: deletes ? 'Leave and delete channel?' : 'Leave channel',
      message: raftFormat(
        context,
        deletes
            ? 'You are the last member of this private channel. When you leave, the channel and its messages are deleted and cannot be recovered.'
            : message,
        {'name': c.name},
      ),
      confirmLabel: deletes
          ? 'Leave and delete'
          : widget.details
          ? 'Leave'
          : 'Leave channel',
      cancelLabel: widget.details ? 'Cancel' : 'Stay in Channel',
      variant: deletes
          ? RaftButtonRecipeVariant.danger
          : RaftButtonRecipeVariant.warning,
      loadingLabel: 'Leaving…',
      confirmKey: const ValueKey('channel-overflow-leave-confirm'),
      action: () async {
        await w.command('POST', '/channels/${c.id}/leave');
        await w.refreshChannels();
      },
    );
    if (ok && mounted) closeSheet();
  }

  bool get joint => channel.type == 'joint';

  /// A joint channel is never deleted (`DELETE` answers 400 "Joint channels
  /// cannot be deleted; disconnect this server instead"): Web's delete row
  /// becomes Disconnect, which removes this server from it.
  Future<void> disconnectFromPanel() async {
    final c = channel;
    final ok = await confirmAction(
      title: 'Disconnect joint channel',
      message: raftFormat(
        context,
        'Your members and agents will leave #{name}, and it will be removed from this server. The other servers keep the channel and its history.',
        {'name': c.name},
      ),
      confirmLabel: 'Disconnect',
      loadingLabel: 'Disconnecting…',
      variant: RaftButtonRecipeVariant.danger,
      action: () async {
        await w.command('POST', '/channels/${c.id}/disconnect');
        await w.refreshChannels();
      },
    );
    if (!ok || !mounted) return;
    closeSheet();
    final next = fallbackChannel;
    if (next != null) unawaited(w.selectChannel(next));
  }

  Future<void> deleteFromPanel() async {
    final c = channel;
    final ok = await confirmAction(
      title: 'Delete channel',
      message: raftFormat(
        context,
        '"{name}" and all of its messages will be permanently deleted. This cannot be undone.',
        {'name': c.name},
      ),
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
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

  Future<void> patchChannel(RaftChannel c, Map<String, dynamic> fields) async {
    final identity = pageIdentity(w);
    final result = await w.command('PATCH', '/channels/${c.id}', data: fields);
    if (identity != pageIdentity(w)) return;
    if (result is! Map) throw const FormatException('Invalid channel response');
    w.channelRepository.consumeRealtime('channel:updated', {
      'id': c.id,
      'name': c.name,
      ...fields,
      ...Map<String, dynamic>.from(result),
    });
    if (mounted) setState(() {});
  }

  bool orderSaving = false;
  bool? pendingActivityOrder;
  Future<void> changeThreadSort(RaftChannel c, bool enabled) async {
    if (orderSaving) return;
    setState(() {
      orderSaving = true;
      pendingActivityOrder = enabled;
      error = null;
    });
    try {
      await patchChannel(c, {'threadSort': enabled ? 'activity' : 'time'});
    } catch (e) {
      await failWith(e, "Couldn't change the message order.");
    } finally {
      if (mounted) {
        setState(() {
          orderSaving = false;
          pendingActivityOrder = null;
        });
      }
    }
  }

  bool visitorVisibleOffered(RaftChannel c) {
    final caps = c.json['channelCapabilities'];
    if (caps is! Map ||
        caps['manageVisitorAccess'] != true ||
        c.archived ||
        (c.type != 'channel' && c.type != 'private')) {
      return false;
    }
    final canTurnOn =
        c.type == 'channel' &&
        c.name != 'all' &&
        w.server?.json['publicPageLive'] != false &&
        c.hasExternalRelation != true;
    if (c.visitorVisible || canTurnOn) visitorShown = true;
    return visitorShown;
  }

  RaftSheetSwitchRow visitorVisibleRow(RaftChannel c) => RaftSheetSwitchRow(
    key: const ValueKey('channel-settings-visitor-visible-switch'),
    title: 'Visible to visitors',
    description: "Anyone can read its messages and replies on this server's public page, without signing in.",
    value: c.visitorVisible,
    onChanged: (v) => updateVisitorVisibility(v),
  );

  Future<void> updateVisitorVisibility(bool visible) async {
    if (guestBusy) return;
    final identity = pageIdentity(w);
    setState(() {
      guestBusy = true;
      error = null;
    });
    try {
      await patchChannel(channel, {'visitorVisible': visible});
    } catch (e) {
      if (mounted && identity == pageIdentity(w)) {
        setState(
          () => error = raftText(
            context,
            userErrorText(
              e,
              fallback:
                  "Couldn't change whether visitors can see this channel.",
              codeText: const {
                'visitor_visibility_forbidden':
                    'Only server owners and admins can change this.',
                'visitor_visibility_requires_public_server':
                    'Make this server public first.',
                'visitor_visibility_requires_public_channel':
                    'Only a public channel can be visible to visitors.',
                'visitor_visibility_unsupported_channel': "This channel can't be visible to visitors: only an ordinary channel with no people or invites from outside this server can be.",
              },
            ),
          ),
        );
      }
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
    final extent = widget.details
        ? RaftMembersStrip.detailsTile(context)
        : null;
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
          extent: extent,
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
      details: widget.details,
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
          slackStripMember(context, m, origin: origin, extent: extent),
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
        showManage &&
        cap('changeChannelVisibility') &&
        c.type != 'joint' &&
        (!widget.details ||
            all ||
            c.type != 'private' ||
            c.hasExternalRelation != true);
    final archiveRow = !all && cap('archiveChannels');
    final deleteRow = !all && cap('deleteChannels') && showManage;
    final showStopAgents =
        settingsPresent && !archived && w.can('controlAgentRuntime');
    final private = c.type == 'private';
    final pinned = (sidebar['pinned'] as List? ?? []).any(
      (p) => p is Map && p['kind'] == 'channel' && p['id'] == c.id,
    );
    final guestSection = visitorVisibleOffered(c);
    final threadSort =
        widget.details &&
        activity.enabled &&
        cap('editChannelMetadata') &&
        !archived &&
        const {'channel', 'private'}.contains(c.type);
    final generation = w.client.generation, serverId = w.server?.id;

    final preferences = RaftSheetSection(
      widget.details ? 'Your preferences' : 'Preferences',
      [
        if (!widget.details)
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
            serverId != null &&
            (!widget.details || c.loungeAgentId == null))
          notificationLevelRow(c, serverId, generation),
        if (widget.details &&
            (dm || c.loungeAgentId != null) &&
            (c.flag('activityMuteSupported') ||
                c.flag('activityMuted') ||
                c.loungeAgentId != null))
          RaftSheetSwitchRow(
            key: const Key('channel-overflow-mute-switch'),
            title: 'Mute',
            description: 'Nothing in this conversation notifies you, not even @mentions.',
            value: notification['activityMuted'] == true,
            pending: !known.contains('notification'),
            onChanged: (value) => writePreference(
              c,
              'notification-settings',
              'activityMuted',
              value,
            ),
          ),
        if (widget.details && c.loungeAgentId == null)
          RaftSheetSwitchRow.control(
            title: 'Sidebar section',
            key: const ValueKey('channel-settings-section'),
            control: ChannelSectionSelect(controller: w, channel: c),
          ),
        if (widget.collapseLongMessages &&
            (!known.contains('display') ||
                display.containsKey('collapseLongMessages')))
          RaftSheetSwitchRow(
            key: const ValueKey('channel-settings-collapse-switch'),
            title: 'Collapse long messages',
            description: widget.details ? '' : 'Fold messages taller than the preview height behind a Show more toggle. Turn off to always show full messages in this channel.',
            value: display['collapseLongMessages'] != false,
            pending: !known.contains('display'),
            onChanged: (v) => widget.details
                ? writePreference(
                    c,
                    'message-display-settings',
                    'collapseLongMessages',
                    v,
                  )
                : run(() async {
                    await w.command(
                      'PATCH',
                      '/channels/${c.id}/message-display-settings',
                      data: {'collapseLongMessages': v},
                    );
                  }),
          ),
      ],
    );

    final actions = [
      if (!widget.details && showManage && showVisibility)
        RaftOverflowAction(
          id: 'channel-settings-visibility-action',
          label: visibilityBusy
              ? 'Updating…'
              : all
              ? (private ? 'Restore #all' : 'Hide #all')
              : (private ? 'Make public' : 'Make private'),
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
            label: archiveBusy ? 'Unarchiving…' : 'Unarchive channel',
            glyph: RaftGlyph.archiveRestore,
            disabled: archiveBusy,
            onPressed: unarchive,
          )
        else
          RaftOverflowAction(
            id: 'channel-settings-archive-action',
            label: 'Archive channel',
            glyph: RaftGlyph.archive,
            warning: true,
            onPressed: archive,
          ),
      if (showLeave)
        RaftOverflowAction(
          id: 'channel-overflow-leave',
          label: 'Leave channel',
          glyph: RaftGlyph.logOut,
          warning: true,
          onPressed: leave,
        ),
      if (showStopAgents)
        RaftOverflowAction(
          id: 'channel-overflow-stop-agents',
          label: 'Stop all agents',
          semanticLabel: 'Stop All Agents in This Channel',
          glyph: RaftGlyph.circleStop,
          warning: true,
          onPressed: stopAgents,
        ),
      if (deleteRow && !jointHostExternal(w, c))
        RaftOverflowAction(
          id: 'channel-settings-delete-action',
          label: joint ? 'Disconnect channel' : 'Delete channel',
          glyph: joint ? RaftGlyph.unplug : RaftGlyph.trash2,
          danger: true,
          onPressed: joint ? disconnectFromPanel : deleteFromPanel,
        ),
    ];

    final hidesMembers =
        all &&
        w.server?.string('role') == 'member' &&
        w.server?.flag('hideHumansFromMembers') == true;
    final stripShown = !dm && !hidesMembers;
    final info = canEdit && !dm;

    final channelRows = [
      if (threadSort)
        RaftSheetSwitchRow(
          key: const Key('channel-settings-thread-sort-switch'),
          title: 'Sort by latest activity',
          description: 'Messages with the newest reply move to the bottom, next to the message box. Everyone in this channel sees the same order.',
          value: pendingActivityOrder ?? c.string('threadSort') == 'activity',
          onChanged: orderSaving ? null : (value) => changeThreadSort(c, value),
        ),
      if (guestSection) visitorVisibleRow(c),
    ];
    final showSlack = canEdit && !archived && (c.type == 'channel' || private);
    final preferenceGroup = widget.details
        ? raftDetailsSettingsGroup(
            context,
            preferences.title,
            RaftGlyph.userRound,
            [
              for (final row in preferences.rows)
                raftDetailsPreferenceRow(context, row, busy: busy),
            ],
            key: const Key('channel-settings-preferences'),
          )
        : raftSheetSection(
            context,
            t,
            preferences,
            busy: busy,
            family: t.bodyFont,
          );

    final Widget body = dm
        ? RaftOverflowDmBody(child: preferenceGroup)
        : settingsPresent
        ? (!flagsKnown
              ? const RaftOverflowLoading()
              : RaftOverflowPanelBody(
                  children: [
                    if (c.type == 'joint' || c.type == 'private')
                      ChannelJointSection(
                        key: jointKey,
                        controller: w,
                        channelId: c.id,
                        onDraftChanged: (draft) {
                          if (mounted) setState(() => jointDraft = draft);
                        },
                      ),
                    if (info)
                      ChannelConversionSection(
                        key: ValueKey('conversion-${w.server?.id}-${c.id}'),
                        controller: w,
                        channelId: c.id,
                      ),
                    if (!widget.details && showManage && info)
                      const RaftOverflowGroupHeading(
                        key: ValueKey('channel-settings-manage-group'),
                        title: 'Info',
                        description:
                            'Name and description shown across the server.',
                      ),
                    if (error != null)
                      RaftOverflowFormError(error!, onRetry: retryLoad),
                    if (!widget.details && info)
                      RaftChannelInfoForm(
                        nameController: name,
                        descriptionController: description,
                        nameEnabled: !all && !archived,
                        descriptionEnabled: !archived,
                        nameHint: all
                            ? 'The #all channel cannot be renamed'
                            : null,
                        onSubmitName: (_) => saveAndClose(),
                        canCancel: nameDescDirty || slack.dirty,
                        canSave: (nameDescDirty || slack.dirty) && !archived,
                        saving: saving,
                        savedLabel: savedLabel,
                        onCancel: resetDraft,
                        onSave: saveChanges,
                      ),
                    if (!widget.details && showSlack)
                      SlackChannelPairingField(
                        pairing: slack,
                        privacy: private ? 'private' : 'public',
                        enabled: !saving,
                      ),
                    if (widget.details &&
                        (showVisibility ||
                            channelRows.isNotEmpty ||
                            showSlack && slack.available))
                      raftDetailsSettingsGroup(
                        context,
                        'Channel settings',
                        RaftGlyph.slidersHorizontal,
                        [
                          if (showVisibility) visibilitySetting(c),
                          for (final row in channelRows)
                            raftDetailsPreferenceRow(
                              context,
                              row,
                              busy: busy || guestBusy || saving,
                            ),
                          if (showSlack && slack.available)
                            ChannelDetailsSlack(
                              channel: c,
                              pairing: slack,
                              enabled: !saving,
                            ),
                        ],
                        key: const Key('channel-settings-manage-group'),
                      )
                    else if (channelRows.isNotEmpty)
                      raftSheetSection(
                        context,
                        t,
                        RaftSheetSection('Channel settings', channelRows),
                        busy: busy || guestBusy,
                        family: t.bodyFont,
                      ),
                    preferenceGroup,
                    if (actions.isNotEmpty)
                      RaftOverflowActions(
                        title: 'Actions',
                        details: widget.details,
                        actions: [
                          for (final a in actions)
                            RaftOverflowAction(
                              id: a.id,
                              label: raftText(context, a.label),
                              glyph: a.glyph,
                              danger: a.danger,
                              warning: a.warning,
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
      details: widget.details,
      headerWrapper: membersOpen ? null : widget.headerWrapper,
      archived: c.archived,
      title: dm
          ? (widget.dmName ?? c.name)
          : widget.details
          ? c.name
          : '#${c.name}',
      badge: dm
          ? 'Direct message'
          : private
          ? 'Private'
          : c.type == 'joint'
          ? 'External'
          : 'Public',
      badgeTone: dm
          ? RaftBadgeRecipeVariant.muted
          : RaftBadgeRecipeVariant.success,
      subtitle: settingsPresent ? c.description : null,
      onClose: guardedClose,
      identityContent: widget.details && metadataEditing
          ? metadataForm(_metadataBase)
          : null,
      identityAction:
          widget.details && !dm && !archived && cap('editChannelMetadata')
          ? RaftButton(
              key: const Key('channel-details-edit'),
              label: raftText(context, 'Edit'),
              focusNode: editFocus,
              glyph: RaftGlyph.pencil,
              uiVariant: RaftButtonVariant.ghost,
              onPressed: startMetadataEdit,
            )
          : null,
      children: [
        if (stripShown) membersStrip(context, c),
        if (widget.details &&
            const {'channel', 'private', 'joint'}.contains(c.type))
          ChannelAnnouncementSettings(
            key: ValueKey('announcement-${w.server?.id}-${c.id}'),
            controller: w,
            channel: c,
            details: true,
          ),
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
    final root = (widget.page || widget.details)
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
      enabled: widget.details || !widget.page,
      onDismiss: () {
        if (widget.details && metadataEditing && !dirty && !saving) {
          finishMetadataEdit();
        } else if (!saving) {
          unawaited(guardedClose());
        }
      },
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
                          child: widget.details
                              ? const SizedBox.shrink()
                              : GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: guardedClose,
                                ),
                        ),
                        RaftOverflowBareSheet(
                          page: widget.page,
                          details: widget.details,
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

  Future<void> stopAgents() => showChannelSos(context, w, channel);

  Future<void> deleteChannel() async {
    final accepted = await showRaftDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RaftFormDialog(
        title: 'Delete channel',
        description:
            'Delete #${channel.name} and its messages. This cannot be undone.',
        fields: [],
        submitLabel: 'Delete channel',
        cancelLabel: 'Keep Channel',
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
