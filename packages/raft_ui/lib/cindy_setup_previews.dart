import 'package:flutter/material.dart';

import 'raft_ui.dart';

/// Source-controlled Meet Cindy presentation; no API claims or setup writes.
Widget cindySetupScreenPreview({
  RaftFamily family = RaftFamily.brutal,
  bool dark = false,
}) => MaterialApp(
  theme: raftTheme(family, dark: dark),
  home: Scaffold(
    body: SingleChildScrollView(
      child: RaftCindySetupScreen(
        fields: const RaftStableField(
          label: 'Runtime',
          required: true,
          hint: 'The AI agent runtime your agents run on.',
          child: Text('Select…'),
        ),
        onCreate: null,
        sessionActions: RaftCindySessionLink(onPressed: () {}),
      ),
    ),
  ),
);
