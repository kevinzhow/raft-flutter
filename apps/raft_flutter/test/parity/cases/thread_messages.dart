// Official cases owned by this group (default selection):
//   components.thread.message.row
//   components.thread.message-row.deleted-human
//   components.thread.message-menu.default
//   components.thread.message-menu.task
//   components.thread.message-share.selection
//   components.thread.forward-modal
//   components.thread.comment-anchor
//   components.thread.message-row.rich-content
//   components.thread.message-row.long-inline-code
//   components.thread.message-row.md-link-ref
//   components.thread.message-row.md-latest-release
//   components.thread.message-row.md-wrap-slice1
//   components.thread.message-row.md-wrap-clarify
//   components.thread.message-row.md-wrap-adjacent
//   components.thread.message-row.md-wrap-status606
//   components.thread.message-row.md-wrap-task607
//
// Builders render the real Flutter app/raft_ui widgets for each case, laid
// out like the React render host fixture for the same case id. Cases the
// Flutter app cannot show go to [threadMessageUncovered] with an honest reason.
import '../parity_harness.dart';

final Map<String, ParityCase> threadMessageCases = {};

final Map<String, ParityUncovered> threadMessageUncovered = {};
