import 'package:flutter/material.dart';

import 'raft_ui.dart';
import 'previews.dart';

@RaftPreviews('Agent avatar editor', size: Size(390, 650))
Widget agentAvatarEditorPreview() => _AvatarPreview();

/// Controlled avatar editor: public artwork, no API or credentials.
Widget agentAvatarPickerPreview({
  RaftFamily family = RaftFamily.brutal,
  bool dark = false,
}) => MaterialApp(
  theme: raftTheme(family, dark: dark),
  home: Scaffold(body: _AvatarPreview()),
);

class _AvatarPreview extends StatefulWidget {
  @override
  State<_AvatarPreview> createState() => _AvatarPreviewState();
}

class _AvatarPreviewState extends State<_AvatarPreview> {
  String selected = 'robot';
  @override
  Widget build(BuildContext context) => RaftAgentAvatarPicker(
    name: 'Cindy',
    selectedKey: selected,
    dirty: selected != 'robot',
    preview: RaftAvatarSlot(
      name: 'Cindy',
      avatarUrl: 'pixel:$selected',
      slot: RaftAvatarSlotContext.profileTile,
    ),
    onChoice: (key) => setState(() => selected = key),
    onUpload: null,
    onClose: () {},
    onSave: () {},
  );
}
