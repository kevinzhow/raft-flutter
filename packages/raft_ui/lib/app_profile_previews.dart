import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('App profile', size: Size(680, 600))
Widget appProfilePreview() => const _AppProfilePreview();

class _AppProfilePreview extends StatefulWidget {
  const _AppProfilePreview();

  @override
  State<_AppProfilePreview> createState() => _AppProfilePreviewState();
}

class _AppProfilePreviewState extends State<_AppProfilePreview> {
  final name = TextEditingController(text: 'Internal Wiki');
  final whenToUse = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    whenToUse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: RaftAppEditorStack(
      children: [
        RaftAppProfileGrid(
          logo: const RaftAppEditorField(
            label: 'Logo',
            compact: true,
            hint: 'Create the app first, then upload a logo from Edit.',
            child: RaftAppProfileLogo(initials: 'NE'),
          ),
          fields: RaftAppEditorField(
            label: 'App name',
            required: true,
            compact: true,
            child: RaftRecipeInput(controller: name),
          ),
        ),
        RaftAppWhenToUseField(
          controller: whenToUse,
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
  );
}
