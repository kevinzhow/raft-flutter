import 'package:flutter/material.dart';

import 'raft_ui.dart';

/// Source-controlled Meet Cindy presentation; no API claims or setup writes.
Widget cindySetupScreenPreview({bool dark = false}) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Scaffold(
    body: SingleChildScrollView(
      child: RaftCindySetupScreen(
        fields: const RaftStableField(
          label: 'Runtime',
          required: true,
          hint: 'The runtime your agents run on.',
          child: Text('Select…'),
        ),
        onCreate: null,
        sessionActions: RaftCindySessionLink(onPressed: () {}),
      ),
    ),
  ),
);
