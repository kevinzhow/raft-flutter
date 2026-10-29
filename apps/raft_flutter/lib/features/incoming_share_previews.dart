import 'package:flutter/material.dart';
import 'package:raft_ui/previews.dart';
import 'package:raft_ui/forward_composer_previews.dart' as sharing;
import 'package:raft_ui/share_progress_previews.dart' as progress;

@RaftPreviews('Incoming share targets', size: Size(390, 844))
Widget incomingShareTargetsPreview() => sharing.incomingShareTargetsPreview();

// Waiting for the copy of the shared files (docs/parity.md): the
// recommended option B, Continue pressed early, and a file that cannot be added.
@RaftPreviews('Incoming share copying', size: Size(390, 700))
Widget incomingShareCopyingPreview() => progress.incomingShareWaitPreview(
  option: progress.RaftShareWaitOption.card,
  scenario: progress.RaftShareWaitScenario.copying,
);

@RaftPreviews('Incoming share Continue waiting', size: Size(390, 700))
Widget incomingShareContinuedPreview() => progress.incomingShareWaitPreview(
  option: progress.RaftShareWaitOption.card,
  scenario: progress.RaftShareWaitScenario.continued,
);

@RaftPreviews('Incoming share file failed', size: Size(390, 700))
Widget incomingShareFailedPreview() => progress.incomingShareWaitPreview(
  option: progress.RaftShareWaitOption.card,
  scenario: progress.RaftShareWaitScenario.failed,
);
