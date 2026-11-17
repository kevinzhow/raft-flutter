import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'artifacts/artifact_models.dart';
import 'artifacts/artifact_text.dart' show artifactRelativeTime;
import 'channel_announcement_host.dart';
import 'channel_announcement_session.dart';
import 'management_support.dart' show pageIdentity;

class ChannelAnnouncementSettings extends StatefulWidget {
  const ChannelAnnouncementSettings({
    super.key,
    required this.controller,
    required this.channel,
    this.details = false,
  });

  final WorkspaceController controller;
  final RaftChannel channel;
  final bool details;

  @override
  State<ChannelAnnouncementSettings> createState() =>
      _ChannelAnnouncementSettingsState();
}

class _ChannelAnnouncementSettingsState
    extends State<ChannelAnnouncementSettings> {
  late final session = ChannelAnnouncementSession.of(widget.controller);
  final anchor = GlobalKey();
  RaftChannel get channel => widget.channel;

  @override
  void initState() {
    super.initState();
    session.addListener(changed);
    changed();
  }

  bool requested = false;
  void changed() {
    if (session.enabled && !requested) {
      requested = true;
      if (!session.store.hasRead(channel.id)) session.load(channel.id);
    } else if (!session.enabled) {
      requested = false;
    }
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = anchor.currentContext;
      if (mounted &&
          context != null &&
          session.takeSettingsTarget(channel.id)) {
        Scrollable.ensureVisible(
          context,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  @override
  void dispose() {
    session.removeListener(changed);
    super.dispose();
  }

  Future<void> pick({String? currentId, String? currentTitle}) async {
    final w = widget.controller;
    final identity = pageIdentity(w);
    final id = channel.id;
    Future<void> apply(String? artifactId) async {
      if (!mounted || pageIdentity(w) != identity) {
        throw const RaftUserError('The channel is no longer available.');
      }
      await session.setAnnouncement(id, artifactId);
    }

    ArtifactCard? replacement;
    final accepted = await showRaftDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AnnouncementPicker(
        controller: w,
        channel: channel,
        currentId: currentId,
        onPick: (card) async {
          if (currentId == null) {
            await apply(card.id);
          } else {
            replacement = card;
          }
        },
      ),
    );
    final next = replacement;
    if (!mounted || accepted != true || next == null) return;
    await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        title: raftText(context, 'Replace announcement?'),
        message: raftFormat(
          context,
          '“{next}” becomes the announcement of #{channel}. “{current}” stays in the channel as an Artifact.',
          {
            'next': next.title,
            'channel': channel.name,
            'current': currentTitle ?? '',
          },
        ),
        confirmLabel: raftText(context, 'Replace'),
        confirmVariant: RaftButtonRecipeVariant.accent,
        initialFocusCancel: true,
        confirmKey: const Key('channel-settings-announcement-replace-confirm'),
        onConfirm: () => apply(next.id),
      ),
    );
  }

  Future<void> remove(String title) async {
    final id = channel.id;
    final identity = pageIdentity(widget.controller);
    await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        title: raftText(context, 'Remove announcement?'),
        message: raftFormat(
          context,
          '#{channel} will have no announcement. “{title}” stays in the channel as an Artifact, and can be set again.',
          {'channel': channel.name, 'title': title},
        ),
        confirmLabel: raftText(context, 'Remove'),
        confirmVariant: RaftButtonRecipeVariant.accent,
        initialFocusCancel: true,
        confirmKey: const Key('channel-settings-announcement-remove-confirm'),
        onConfirm: () {
          if (!mounted || pageIdentity(widget.controller) != identity) {
            throw const RaftUserError('The channel is no longer available.');
          }
          return session.setAnnouncement(id, null);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!session.enabled || !session.store.hasRead(channel.id)) {
      return const SizedBox.shrink();
    }
    final w = widget.controller;
    final canEdit =
        !channel.archived && w.can('editChannelMetadata', resource: channel);
    final announcement = session.store.forChannel(channel.id);
    if (announcement == null && !canEdit) return const SizedBox.shrink();
    final author = announcement == null
        ? null
        : channelAnnouncementAuthor(w, announcement);
    final updated = DateTime.tryParse(announcement?.updatedAt ?? '');
    final options = raftText(context, 'Announcement actions');
    final group = RaftListRowGroup(
      key: const Key('channel-settings-announcement'),
      children: [
        if (announcement == null)
          RaftListRow(
            variant: RaftListRowVariant.plain,
            interactive: false,
            children: [
              const RaftIcon(RaftGlyph.megaphone),
              RaftListRowBody(
                children: [
                  RaftListRowTitle(raftText(context, 'No announcement')),
                  RaftListRowDescription(
                    raftText(
                      context,
                      'Set an Artifact of this channel as its announcement: rules, dates, links everyone should know.',
                    ),
                    wrap: true,
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: RaftButton(
                      label: raftText(context, 'Set announcement'),
                      uiVariant: RaftButtonVariant.outline,
                      onPressed: pick,
                    ),
                  ),
                ],
              ),
            ],
          )
        else
          RaftListRow(
            variant: RaftListRowVariant.plain,
            onPressed: () =>
                openChannelAnnouncement(context, w, channel.id, announcement),
            children: [
              const RaftIcon(RaftGlyph.megaphone),
              RaftListRowBody(
                children: [
                  RaftListRowTitle(announcement.title),
                  RaftListRowMeta(
                    raftFormat(
                      context,
                      'v{version} · Updated by {name} · {time}',
                      {
                        'version': '${announcement.version}',
                        'name': author!.name.isEmpty
                            ? raftText(context, 'Someone')
                            : author.name,
                        'time': updated == null
                            ? ''
                            : artifactRelativeTime(context, updated),
                      },
                    ),
                  ),
                ],
              ),
              if (canEdit)
                RaftDropdownMenu(
                  label: options,
                  kind: RaftMenuKind.dropdownMenu,
                  surfaceKey: const Key('channel-settings-announcement-menu'),
                  align: RaftDropdownAlign.end,
                  entries: [
                    RaftMenuEntry(
                      label: raftText(context, 'Replace'),
                      glyph: RaftGlyph.refreshCw,
                      onPressed: () => pick(
                        currentId: announcement.artifactId,
                        currentTitle: announcement.title,
                      ),
                    ),
                    RaftMenuEntry(
                      label: raftText(context, 'Remove'),
                      glyph: RaftGlyph.x,
                      onPressed: () => remove(announcement.title),
                    ),
                  ],
                  triggerBuilder: (context, focus, open) => RaftButton(
                    key: const Key('channel-settings-announcement-actions'),
                    focusNode: focus,
                    semanticLabel: options,
                    tooltip: options,
                    glyph: RaftGlyph.ellipsisVertical,
                    uiVariant: RaftButtonVariant.ghost,
                    uiSize: RaftButtonSize.iconSm,
                    onPressed: open,
                  ),
                )
              else
                const RaftIcon(RaftGlyph.chevronRight),
            ],
          ),
      ],
    );
    return widget.details
        ? Padding(
            key: anchor,
            padding: const EdgeInsets.only(
              left: RaftSpace.x4,
              top: RaftSpace.x6,
              right: RaftSpace.x4,
            ),
            child: group,
          )
        : group;
  }
}

class _AnnouncementPicker extends StatefulWidget {
  const _AnnouncementPicker({
    required this.controller,
    required this.channel,
    required this.currentId,
    required this.onPick,
  });

  final WorkspaceController controller;
  final RaftChannel channel;
  final String? currentId;
  final Future<void> Function(ArtifactCard) onPick;

  @override
  State<_AnnouncementPicker> createState() => _AnnouncementPickerState();
}

class _AnnouncementPickerState extends State<_AnnouncementPicker> {
  final search = TextEditingController();
  final confirmEnabled = ValueNotifier(false);
  final cards = <String, ArtifactCard>{};
  ArtifactCard? selected;
  String? cursor;
  bool loading = true, failed = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({String? after}) async {
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final response = await widget.controller.query(
        '/artifacts/conversations/${widget.channel.id}',
        query: {'cursor': ?after},
      );
      if (response is! Map || response['rows'] is! List) {
        throw const FormatException('Invalid Artifact list');
      }
      if (!mounted) return;
      setState(() {
        for (final row in (response['rows'] as List).whereType<Map>()) {
          final card = ArtifactCard.fromJson(row['card']);
          if (card != null && card.id != widget.currentId) {
            cards[card.id] = card;
          }
        }
        cursor = response['nextCursor'] as String?;
      });
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    search.dispose();
    confirmEnabled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final replacing = widget.currentId != null;
    return RaftConfirmDialog(
      title: raftText(
        context,
        replacing ? 'Replace announcement' : 'Set announcement',
      ),
      size: RaftDialogSize.md,
      plainMessage: true,
      confirmLabel: raftText(context, replacing ? 'Next' : 'Set announcement'),
      confirmVariant: RaftButtonRecipeVariant.accent,
      confirmEnabled: confirmEnabled,
      confirmKey: const Key('channel-settings-announcement-picker-confirm'),
      onConfirm: () => widget.onPick(selected!),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: RaftSpace.x3,
        children: [
          Text(
            raftFormat(
              context,
              'Everyone in #{channel} sees it at the top of the channel. When it’s updated, it shows as new until they open it.',
              {'channel': widget.channel.name},
            ),
          ),
          if (loading && cards.isEmpty)
            Text(raftText(context, 'Loading Artifacts…'))
          else if (failed && cards.isEmpty)
            Text(raftText(context, 'Couldn’t load this channel’s Artifacts.'))
          else ...[
            RaftDialogTextInput(
              controller: search,
              placeholder: 'Search Artifacts',
            ),
            ListenableBuilder(
              listenable: search,
              builder: (context, _) {
                final matches = cards.values.where(
                  (card) => card.title.toLowerCase().contains(
                    search.text.trim().toLowerCase(),
                  ),
                );
                if (cards.isEmpty) {
                  return Text(
                    raftFormat(
                      context,
                      '#{channel} has no Artifacts yet. Push one there, then set it as the announcement.',
                      {'channel': widget.channel.name},
                    ),
                  );
                }
                if (matches.isEmpty) {
                  return Text(raftText(context, 'No Artifacts match'));
                }
                final listHeight = MediaQuery.sizeOf(context).height / 4;
                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: listHeight),
                  child: SingleChildScrollView(
                    child: RaftListRowGroup(
                      children: [
                        for (final card in matches)
                          RaftListRow(
                            variant: RaftListRowVariant.plain,
                            selected: selected?.id == card.id,
                            onPressed: () {
                              setState(() => selected = card);
                              confirmEnabled.value = true;
                            },
                            children: [
                              RaftListRowBody(
                                children: [RaftListRowTitle(card.title)],
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          if (failed || cursor != null)
            RaftButton(
              label: raftText(context, failed ? 'Try again' : 'Show more'),
              uiVariant: RaftButtonVariant.outline,
              onPressed: loading ? null : () => load(after: cursor),
            ),
        ],
      ),
    );
  }
}
