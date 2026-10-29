import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Published dropdown menu role', size: Size(390, 600))
Widget dropdownMenuRolePreview() => const _DropdownMenuRolePreview();

enum _MenuAction { openDetails, export }

class _DropdownMenuRolePreview extends StatefulWidget {
  const _DropdownMenuRolePreview();

  @override
  State<_DropdownMenuRolePreview> createState() =>
      _DropdownMenuRolePreviewState();
}

class _DropdownMenuRolePreviewState extends State<_DropdownMenuRolePreview> {
  _MenuAction? lastAction;

  void record(_MenuAction action) => setState(() => lastAction = action);

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Callback menu'),
        const SizedBox(height: 12),
        RaftDropdownMenu(
          label: 'Open published menu',
          kind: RaftMenuKind.dropdownMenu,
          entries: [
            RaftMenuEntry(
              label: 'Open details',
              glyph: RaftGlyph.info,
              onPressed: () => record(_MenuAction.openDetails),
            ),
            const RaftMenuEntry(
              label: 'Unavailable action',
              glyph: RaftGlyph.lock,
            ),
            const RaftMenuEntry.separator(),
            RaftMenuEntry(
              label: 'Export',
              glyph: RaftGlyph.download,
              onPressed: () => record(_MenuAction.export),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Last callback: ${lastAction?.name ?? 'none'}'),
        const SizedBox(height: 24),
        const Text('Item state samples'),
        const SizedBox(height: 12),
        // These public item adapters expose the published selected state.
        // RaftMenuEntry has no selected value; the callback menu above does
        // not claim to provide a controlled choice or selected popup item.
        RaftMenuPanel(
          kind: RaftMenuKind.dropdownMenu,
          children: [
            RaftMenuItem(
              label: 'Normal item',
              kind: RaftMenuKind.dropdownMenu,
              onPressed: () {},
            ),
            RaftMenuItem(
              label: 'Selected item',
              kind: RaftMenuKind.dropdownMenu,
              selected: true,
              onPressed: () {},
            ),
            const RaftMenuItem(
              label: 'Disabled item',
              kind: RaftMenuKind.dropdownMenu,
            ),
          ],
        ),
      ],
    ),
  );
}
