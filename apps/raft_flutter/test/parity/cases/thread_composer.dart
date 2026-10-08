// Official cases owned by this group (default selection):
//   components.thread.composer.empty
//   components.thread.composer.states
//   components.thread.composer.pending-mention-actions
//   components.thread.composer.as-task-selected
//   components.thread.composer.member-suggestions
//   components.thread.composer.channel-suggestions
//   components.thread.composer.image-preview
//   components.thread.files.list
//   components.thread.header.states
//
// Builders render the real Flutter app/raft_ui widgets for each case, laid
// out like the React render host fixture for the same case id. Cases the
// Flutter app cannot show go to [threadComposerUncovered] with an honest reason.
import '../parity_harness.dart';

final Map<String, ParityCase> threadComposerCases = {};

final Map<String, ParityUncovered> threadComposerUncovered = {};
