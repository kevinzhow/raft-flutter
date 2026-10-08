import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart'
    show RaftButtonRecipeVariant, RaftButtonRecipeSize;

import '../data/workspace_controller.dart';
import 'channel_conversion_section.dart';
import 'channel_form_fields.dart';

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

  /// One `py-3` preference row: title `text-sm font-medium`, description
  /// `mt-1 text-xs text-foreground-muted`, trailing `Switch size="md"`.
  Widget _switchRow(
    RaftTokens t,
    String title,
    String body,
    bool value,
    ValueChanged<bool>? onChanged,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                raftText(context, title),
                style: raftCssTextStyle(
                  family: t.headingFont,
                  step: RaftTextSteps.sm,
                  weight: FontWeight.w500,
                  color: t.strong,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                raftText(context, body),
                style: raftCssTextStyle(
                  family: t.headingFont,
                  step: RaftTextSteps.xs,
                  color: t.colors['foreground-muted'],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        RaftSwitch(
          value: value,
          size: RaftSwitchSize.md,
          semanticLabel: raftText(context, title),
          // The row keeps CSS geometry; the switch is its own tap target.
          minimumTargetSize: 0,
          onChanged: busy ? null : onChanged,
        ),
      ],
    ),
  );

  /// `<section className="mt-5">` + `h3 text-base font-bold` + `mt-2
  /// divide-y divide-black/10` rows.
  Widget _section(RaftTokens t, String title, List<Widget> rows) {
    final divider = t.brutal
        ? Colors.black.withValues(alpha: .1)
        : t.colors['line-muted']!;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            raftText(context, title),
            style: raftCssTextStyle(
              family: t.headingFont,
              step: RaftTextSteps.base,
              weight: FontWeight.w700,
              color: t.strong,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == 0 ? null : Border(top: BorderSide(color: divider)),
              ),
              child: rows[i],
            ),
        ],
      ),
    );
  }

  /// Sheet action: `Button size="sm"` with `flex w-full items-center
  /// justify-center gap-1.5 px-4 py-2 text-sm`.
  Widget _action(
    String label,
    RaftGlyph glyph,
    RaftButtonRecipeVariant variant,
    VoidCallback? onPressed,
  ) => RaftRecipeButton(
    label: label,
    glyph: glyph,
    variant: variant,
    size: RaftButtonRecipeSize.sm,
    expand: true,
    gap: 6,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    textStep: RaftTextSteps.sm,
    disabled: busy,
    onPressed: onPressed,
  );

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
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
    // theme-brutal:bg-brutal-cream / bg-layer-canvas-muted.
    final paper = t.brutal
        ? t.colors['color-brutal-cream']!
        : t.colors['layer-canvas-muted']!;
    final strongEdge = t.brutal ? Colors.black : t.colors['line-muted']!;
    final edgeWidth = t.brutal ? 2.0 : 1.0;
    final muted = t.colors['foreground-muted']!;
    final hairline = t.brutal
        ? Colors.black.withValues(alpha: .1)
        : t.colors['line-muted']!;
    final width = MediaQuery.sizeOf(context).width;

    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: t.brutal
            ? t.colors['color-soft-signal']
            : t.colors['primary-soft'],
        border: Border(
          bottom: BorderSide(color: strongEdge, width: edgeWidth),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // text-[10px] font-bold tracking-wide (inherited 1.5 leading).
                Text(
                  raftText(context, 'Channel'),
                  style: raftCssTextStyle(
                    family: t.headingFont,
                    step: (10, 15),
                    weight: FontWeight.w700,
                    color: t.brutal
                        ? Colors.black.withValues(alpha: .55)
                        : muted,
                    trackingEm: .025,
                  ),
                ),
                Semantics(
                  header: true,
                  child: Text(
                    raftText(
                      context,
                      dm ? 'Conversation settings' : 'Settings',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: raftCssTextStyle(
                      family: t.headingFont,
                      step: RaftTextSteps.xl,
                      weight: FontWeight.w700,
                      color: t.brutal ? Colors.black : t.strong,
                    ),
                  ),
                ),
                Text(
                  '#${widget.channel.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: raftCssTextStyle(
                    family: t.monoFont,
                    step: RaftTextSteps.xs,
                    color: t.brutal
                        ? Colors.black.withValues(alpha: .6)
                        : muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          RaftRecipeButton(
            glyph: RaftGlyph.x,
            variant: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.sm,
            padding: const EdgeInsets.all(4), // p-1
            tooltip: raftText(context, 'Close channel settings'),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );

    final body = <Widget>[
      if (error != null) ...[
        ChannelFormBanner(error!),
        const SizedBox(height: 20),
      ],
      if (!dm && canEdit) ...[
        // ChannelConversionSection hides itself unless conversion applies.
        ChannelConversionSection(
          key: ValueKey('conversion-${w.server?.id}-${c.id}'),
          controller: w,
          channelId: c.id,
        ),
        // section space-y-3 border-b border-line-muted pb-5.
        Container(
          padding: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: hairline)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RaftProductFormField(
                label: 'Name',
                uppercase: false,
                required: true,
                labelWeight: FontWeight.w500,
                hint: all ? 'The #all channel cannot be renamed.' : null,
                child: ChannelTextInput(
                  controller: name,
                  placeholder: 'e.g. ai-research',
                  autofocus: true,
                  enabled: !all && !archived && !busy,
                  onSubmitted: (_) => save(),
                ),
              ),
              const SizedBox(height: 12),
              RaftProductFormField(
                label: 'Description',
                uppercase: false,
                optional: true,
                labelWeight: FontWeight.w500,
                child: ChannelTextInput(
                  controller: description,
                  placeholder: 'What is this channel about?',
                  multiline: true,
                  enabled: !archived && !busy,
                ),
              ),
            ],
          ),
        ),
      ],
      if (guestFeature && cap('manageGuestAccess') && !archived && !dm)
        _section(t, 'Guest access', [
          _switchRow(
            t,
            'Guests can see this channel',
            'Guests in this server can find and read this channel.',
            c.flag('guestVisible'),
            (v) => run(() async {
              await w.command(
                'PATCH',
                '/channels/${c.id}',
                data: {'guestVisible': v},
              );
            }),
          ),
          _switchRow(
            t,
            'Guests can join this channel',
            'Guests can join and post in this channel.',
            c.flag('guestJoinable'),
            (v) => run(() async {
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
      _section(t, 'Preferences', [
        _switchRow(
          t,
          'Pin channel',
          'Keep this channel pinned to the top of your sidebar.',
          pinned,
          pin,
        ),
        if (widget.collapseLongMessages &&
            display.containsKey('collapseLongMessages'))
          _switchRow(
            t,
            'Collapse long messages',
            'Fold messages taller than the preview height behind a Show more toggle. Turn off to always show full messages in this channel.',
            display['collapseLongMessages'] != false,
            (v) => run(() async {
              await w.command(
                'PATCH',
                '/channels/${c.id}/message-display-settings',
                data: {'collapseLongMessages': v},
              );
            }),
          ),
      ]),
      if (!dm &&
          (showLeave || showManage || (archived && cap('archiveChannels'))))
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                raftText(context, 'Channel actions'),
                style: raftCssTextStyle(
                  family: t.headingFont,
                  step: RaftTextSteps.xs,
                  weight: FontWeight.w700,
                  color: muted,
                  trackingEm: .025,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                raftText(
                  context,
                  'Membership, visibility, conversion, archive, and destructive controls.',
                ),
                style: raftCssTextStyle(
                  family: t.headingFont,
                  step: RaftTextSteps.xs,
                  color: muted,
                ),
              ),
              for (final action in [
                if (showLeave)
                  _action(
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
                  _action(
                    private ? 'Make Public' : 'Make Private',
                    private ? RaftGlyph.hash : RaftGlyph.lock,
                    RaftButtonRecipeVariant.warning,
                    () => confirm(
                      private
                          ? 'Make channel public?'
                          : 'Make channel private?',
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
                      ? _action(
                          'Unarchive Channel',
                          RaftGlyph.archiveRestore,
                          RaftButtonRecipeVariant.success,
                          () => run(() async {
                            await w.command(
                              'POST',
                              '/channels/${c.id}/unarchive',
                            );
                          }),
                        )
                      : _action(
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
                  _action(
                    'Delete Channel',
                    RaftGlyph.trash2,
                    RaftButtonRecipeVariant.danger,
                    deleteChannel,
                  ),
              ]) ...[const SizedBox(height: 12), action],
            ],
          ),
        ),
    ];

    final footer = Container(
      // `safe-bottom` = 1rem + inset bottom; py-3 elsewhere.
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: paper,
        border: Border(
          top: BorderSide(color: strongEdge, width: edgeWidth),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          RaftRecipeButton(
            label: 'Cancel',
            variant: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.sm,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            textStep: RaftTextSteps.sm,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          if (canEdit && !dm) ...[
            const SizedBox(width: 12),
            RaftRecipeButton(
              label: busy ? 'Saving…' : 'Save',
              variant: RaftButtonRecipeVariant.accent,
              size: RaftButtonRecipeSize.sm,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStep: RaftTextSteps.sm,
              disabled: busy || archived,
              onPressed: save,
            ),
          ],
        ],
      ),
    );

    // DrawerContent: right sheet, `w-full max-w-[min(100vw,34rem)] h-dvh`,
    // `theme-brutal:border-l-2 border-line-strong`.
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: width < 544 ? width : 544,
        height: double.infinity,
        child: Material(
          color: paper,
          // Container (not DecoratedBox) so the border-l insets the content
          // like the CSS border box.
          child: Container(
            decoration: BoxDecoration(
              border: t.brutal
                  ? Border(
                      left: BorderSide(
                        color: t.colors['line-strong']!,
                        width: 2,
                      ),
                    )
                  : null,
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(fontFamily: t.headingFont, color: t.strong),
              child: Column(
                children: [
                  header,
                  Expanded(
                    child: loading
                        ? const Center(child: RaftSpinner())
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: body,
                            ),
                          ),
                  ),
                  footer,
                ],
              ),
            ),
          ),
        ),
      ),
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
