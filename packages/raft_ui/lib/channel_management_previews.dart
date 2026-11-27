import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Channel details side column', size: Size(1280, 844))
Widget channelDetailsColumnPreview() => const Align(
  alignment: Alignment.centerRight,
  child: SizedBox(width: 400, child: _ChannelPagesPreview(details: true)),
);

@RaftPreviews('Mobile channel details page', size: Size(390, 844))
Widget channelDetailsPagePreview() => const _ChannelPagesPreview(details: true);

@RaftPreviews('Mobile channel settings page', size: Size(390, 844))
Widget channelSettingsPagePreview() => const _ChannelPagesPreview();

@RaftPreviews('Mobile DM current settings', size: Size(390, 844))
Widget dmSettingsPagePreview() => const _ChannelPagesPreview(dm: true);

@RaftPreviews('Mobile channel members page', size: Size(390, 844))
Widget channelMembersPagePreview() => const _ChannelPagesPreview(members: true);

@RaftPreviews('Mobile channel members loading', size: Size(390, 844))
Widget channelMembersLoadingPreview() =>
    const _ChannelPagesPreview(members: true, loading: true);

@RaftPreviews('Mobile channel settings error', size: Size(390, 844))
Widget channelSettingsErrorPreview() =>
    const _ChannelPagesPreview(error: 'Unable to refresh settings. Try again.');

class _ChannelPagesPreview extends StatefulWidget {
  const _ChannelPagesPreview({
    this.members = false,
    this.details = false,
    this.dm = false,
    this.loading = false,
    this.error,
  });
  final bool members, loading, dm, details;
  final String? error;
  @override
  State<_ChannelPagesPreview> createState() => _ChannelPagesPreviewState();
}

class _ChannelPagesPreviewState extends State<_ChannelPagesPreview> {
  late bool members = widget.members;
  bool adding = false, pinned = false;
  final search = TextEditingController();
  final name = TextEditingController(text: 'general');
  final description = TextEditingController(
    text: 'A channel for everyone in the workspace.',
  );
  @override
  void dispose() {
    search.dispose();
    name.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => members
      ? RaftChannelMembersModal(
          page: true,
          channelName: 'general',
          search: search,
          loading: widget.loading,
          error: widget.error,
          onClose: () => setState(() => members = false),
          addView: adding,
          onAdd: () => setState(() => adding = true),
          onBack: () => setState(() => adding = false),
          hasCandidates: true,
          humans: const [
            RaftMemberRowData(
              label: 'Alice',
              avatar: RaftAvatar(name: 'Alice'),
            ),
          ],
          invited: [
            RaftMemberRowData(
              label: 'guest@example.com',
              searchText: 'guest@example.com',
              titleNote: '14 days left',
              avatar: const RaftIconTile(glyph: RaftGlyph.mail),
              actions: [
                RaftMemberRowAction(
                  glyph: RaftGlyph.mail,
                  tooltip: 'Resend invite',
                  semanticLabel: 'Resend the invite to guest@example.com',
                  onPressed: () {},
                ),
                RaftMemberRowAction(
                  glyph: RaftGlyph.x,
                  tooltip: 'Withdraw invite',
                  semanticLabel: 'Withdraw the invite to guest@example.com',
                  onPressed: () {},
                ),
              ],
            ),
          ],
          inviteOutside: (server: 'Acme', onPressed: () {}),
          isChecked: (_) => false,
          onToggle: (_) {},
          onConfirm: () => setState(() => adding = false),
        )
      : Builder(
          builder: (context) {
            final t = RaftTokens.of(context);
            final preferences = raftSheetSection(
              context,
              t,
              RaftSheetSection('Preferences', [
                RaftSheetSwitchRow(
                  title: widget.dm ? 'Pin conversation' : 'Pin channel',
                  description:
                      'Keep this conversation at the top of your sidebar.',
                  value: pinned,
                  onChanged: (value) => setState(() => pinned = value),
                ),
              ]),
              family: t.bodyFont,
            );
            return RaftOverflowSheet(
              page: !widget.details || MediaQuery.sizeOf(context).width < 400,
              details: widget.details,
              title: widget.dm ? 'Alice' : '#general',
              badge: widget.dm ? 'Direct message' : 'Public',
              subtitle: widget.dm
                  ? null
                  : 'A channel for everyone in the workspace.',
              onClose: () {},
              children: [
                if (!widget.dm)
                  RaftMembersStrip(
                    heading: 'Members',
                    summary: '1 human · 0 agents',
                    members: const [
                      RaftStripMember(
                        label: 'Alice',
                        avatar: RaftAvatar(name: 'Alice'),
                      ),
                    ],
                    onOpen: () => setState(() => members = true),
                    onAdd: () => setState(() {
                      members = true;
                      adding = true;
                    }),
                  ),
                if (widget.dm)
                  RaftOverflowDmBody(child: preferences)
                else
                  RaftOverflowPanelBody(
                    children: [
                      if (widget.error != null)
                        RaftOverflowFormError(widget.error!),
                      if (!widget.details) ...[
                        const RaftOverflowGroupHeading(
                          title: 'Info',
                          description:
                              'Name and description shown across the server.',
                        ),
                        RaftChannelInfoForm(
                          nameController: name,
                          descriptionController: description,
                          onSubmitName: (_) {},
                          canCancel: true,
                          canSave: true,
                          onCancel: () {
                            name.text = 'general';
                          },
                          onSave: () {},
                        ),
                      ],
                      preferences,
                    ],
                  ),
              ],
            );
          },
        );
}
