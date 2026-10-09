import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

@RaftPreviews('Product surfaces and progress', size: Size(380, 320))
Widget surfaceProgressPreview() => Padding(
  padding: const EdgeInsets.all(24),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      RaftSurfaceListItem(
        onTap: () {},
        child: const Text('Interactive surface'),
      ),
      const SizedBox(height: 16),
      const RaftSurfaceListItem(
        selected: true,
        child: Text('Selected surface'),
      ),
      const SizedBox(height: 16),
      const RaftProgressBar(
        value: 64,
        label: 'Downloading update',
        showPercent: true,
      ),
      const SizedBox(height: 16),
      const RaftTextInput(autofocus: true, hintText: 'Editable focus ring'),
    ],
  ),
);
