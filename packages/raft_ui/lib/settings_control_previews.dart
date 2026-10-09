import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Settings buttons keyboard focus and disabled')
Widget settingsControlsPreview() => const _SettingsControls();

class _SettingsControls extends StatefulWidget {
  const _SettingsControls();
  @override
  State<_SettingsControls> createState() => _SettingsControlsState();
}

class _SettingsControlsState extends State<_SettingsControls> {
  int saves = 0;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RaftSettingsRecipeButton(
          label: 'Save',
          onPressed: () => setState(() => saves++),
        ),
        const SizedBox(height: 12),
        const RaftSettingsRecipeButton(label: 'Saving', disabledOpacity: .8),
        const SizedBox(height: 12),
        Text('Saved $saves times'),
      ],
    ),
  );
}
