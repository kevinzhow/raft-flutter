import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/tool_display.dart';

void main() {
  test('ToolDisplay labels Claude subagent starts and server information', () {
    expect(toolLogLabel('Agent'), 'Starting sub-agent');
    expect(toolLogLabel('Task'), 'Starting sub-agent');
    expect(toolLogLabel('mcp__chat__list_server'), 'Viewing server info');
    expect(toolLogLabel('collab_tool_call'), 'Collaborating');
  });
}
