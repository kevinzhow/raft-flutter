import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/thread_search.dart';
import '../data/workspace_controller.dart';

Widget? threadFindBar(
  BuildContext context,
  WorkspaceController workspace,
  ThreadSearch? search,
  TextEditingController input,
  FocusNode focus,
) {
  if (search == null || !search.isOpen) return null;
  return RaftThreadSearchBar(
    task: workspace.threadIdentity?.taskId != null,
    controller: input,
    focusNode: focus,
    countLabel: search.countLabel(raftText(context, 'Loading')),
    canStep: search.matches.isNotEmpty,
    onChanged: search.setQuery,
    onStep: search.step,
    onClose: search.close,
  );
}
