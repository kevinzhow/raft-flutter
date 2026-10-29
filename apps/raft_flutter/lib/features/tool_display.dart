// Mounted Source `packages/shared/src/toolDisplay.ts`: the activity log's
// humanised tool names (`getToolLogLabel`) and the one tool whose start row
// the log hides. The labels are English in Web too (no i18n ids), so they are
// not catalog entries.

/// `KNOWN_TOOL_ALIASES` -> `ToolSemantic`.
const _aliases = <String, String>{
  'send_message': 'send_message',
  'check_messages': 'check_messages',
  'wait_for_message': 'wait_for_message',
  'receive_message': 'receive_message',
  'read_history': 'read_history',
  'search_messages': 'search_messages',
  'list_server': 'list_server',
  'list_tasks': 'list_tasks',
  'create_tasks': 'create_tasks',
  'claim_tasks': 'claim_tasks',
  'unclaim_task': 'unclaim_task',
  'update_task_status': 'update_task_status',
  'add_channel_member': 'add_channel_member',
  'join_channel': 'join_channel',
  'leave_channel': 'leave_channel',
  'upload_file': 'upload_file',
  'view_file': 'view_file',
  'Read': 'read_file',
  'read_file': 'read_file',
  'ReadFile': 'read_file',
  'file_read': 'read_file',
  'Write': 'write_file',
  'write_file': 'write_file',
  'WriteFile': 'write_file',
  'file_write': 'write_file',
  'Edit': 'edit_file',
  'edit_file': 'edit_file',
  'EditFile': 'edit_file',
  'file_change': 'edit_file',
  'StrReplaceFile': 'edit_file',
  'Bash': 'bash',
  'bash': 'bash',
  'shell': 'bash',
  'Shell': 'bash',
  'command_execution': 'bash',
  'run_shell_command': 'bash',
  'run_terminal_command': 'bash',
  'Glob': 'glob',
  'glob': 'glob',
  'search_files': 'glob',
  'Grep': 'grep',
  'grep': 'grep',
  'WebFetch': 'web_fetch',
  'web_fetch': 'web_fetch',
  'fetch_url': 'web_fetch',
  'FetchURL': 'web_fetch',
  'WebSearch': 'web_search',
  'web_search': 'web_search',
  'SearchWeb': 'web_search',
  'TodoWrite': 'todo_write',
  'SetTodoList': 'todo_write',
  'schedule_reminder': 'schedule_reminder',
  'list_reminders': 'list_reminders',
  'cancel_reminder': 'cancel_reminder',
  'collab_tool_call': 'collab_tool_call',
};

/// `TOOL_DISPLAY_METADATA[semantic].logLabel`.
const _logLabels = <String, String>{
  'send_message': 'Sending message',
  'check_messages': 'Checking messages',
  'wait_for_message': 'Waiting for messages',
  'receive_message': 'Checking messages',
  'read_history': 'Reading history',
  'search_messages': 'Searching messages',
  'list_server': 'Listing server',
  'list_tasks': 'Listing tasks',
  'create_tasks': 'Creating tasks',
  'claim_tasks': 'Claiming tasks',
  'unclaim_task': 'Unclaiming task',
  'update_task_status': 'Updating task status',
  'add_channel_member': 'Adding channel member',
  'join_channel': 'Joining channel',
  'leave_channel': 'Leaving channel',
  'upload_file': 'Uploading file',
  'view_file': 'Viewing file',
  'read_file': 'Reading file',
  'write_file': 'Writing file',
  'edit_file': 'Editing file',
  'bash': 'Running command',
  'glob': 'Searching files',
  'grep': 'Searching code',
  'web_fetch': 'Fetching web',
  'web_search': 'Searching web',
  'todo_write': 'Updating tasks',
  'schedule_reminder': 'Scheduling reminder',
  'list_reminders': 'Listing reminders',
  'cancel_reminder': 'Canceling reminder',
  'collab_tool_call': 'Collaborating',
};

String _normalizeToolLookupName(String name) {
  for (final prefix in const ['mcp__chat__', 'mcp_chat_']) {
    if (name.startsWith(prefix)) return name.substring(prefix.length);
  }
  return name;
}

String _stripToolNamespace(String name) =>
    _normalizeToolLookupName(name).replaceFirst(RegExp(r'^mcp__\w+__'), '');

/// `resolveToolSemantic`.
String? resolveToolSemantic(String toolName) =>
    _aliases[_normalizeToolLookupName(toolName)];

/// `getToolLogLabel`: the humanised label, else the name without its MCP
/// namespace.
String toolLogLabel(String toolName) {
  final semantic = resolveToolSemantic(toolName);
  return semantic == null
      ? _stripToolNamespace(toolName)
      : _logLabels[semantic]!;
}

/// `shouldHideToolStartInActivityLog`: `send_message` is a transient operation
/// whose value is in the resulting message, not in a durable row.
bool hideToolStartInActivityLog(String toolName) =>
    resolveToolSemantic(toolName) == 'send_message';
