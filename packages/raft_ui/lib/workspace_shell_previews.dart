import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

@RaftPreviews('Desktop sidebar heading', size: Size(280, 100))
Widget workspaceSidebarHeadingPreview() =>
    const RaftChatSidebarHeading(label: 'Chat');

@RaftPreviews('Desktop rail footer', size: Size(440, 320))
Widget workspaceRailFooterPreview() => const _FooterPreview();

class _FooterPreview extends StatefulWidget {
  const _FooterPreview();
  @override
  State<_FooterPreview> createState() => _FooterPreviewState();
}

class _FooterPreviewState extends State<_FooterPreview> {
  bool unseen = true;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomLeft,
    child: SizedBox(
      width: 64,
      child: RaftWorkspaceRailFooter(
        children: [
          RaftWorkspaceRailAction(
            label: 'Notifications',
            glyph: RaftGlyph.bell,
            onPressed: () {},
          ),
          RaftWorkspaceHelpMenu(
            label: 'Help',
            attention: unseen,
            heading: 'Help & resources',
            entries: [
              RaftMenuEntry(
                label: 'Documentation',
                leading: const RaftIcon(RaftGlyph.bookOpenText, size: 14),
                trailing: const RaftIcon(RaftGlyph.arrowUpRight, size: 14),
                onPressed: () {},
              ),
              RaftMenuEntry(
                label: 'Mobile app',
                leading: const RaftIcon(RaftGlyph.smartphone, size: 14),
                onPressed: () => setState(() => unseen = false),
              ),
              RaftMenuEntry(
                label: 'Feedback',
                leading: const RaftIcon(RaftGlyph.messageSquare, size: 14),
                onPressed: () {},
              ),
            ],
          ),
          RaftWorkspaceRailAction(
            label: 'Exit workspace mode',
            glyph: RaftGlyph.squareSplitHorizontal,
            selected: true,
            depressed: true,
            onPressed: () {},
          ),
          RaftWorkspaceRailAction(
            label: 'Settings',
            glyph: RaftGlyph.settings,
            onPressed: () {},
          ),
        ],
      ),
    ),
  );
}
