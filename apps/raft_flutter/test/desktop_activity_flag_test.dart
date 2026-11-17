import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/desktop_activity_flag.dart';

void main() {
  test('the split-preview threshold is 768; nothing is evaluated (no variant flag)', () {
    final w = WorkspaceController(
      RaftClient(origin: 'https://flag.invalid', sessionStore: MemorySessionStore()),
    )..server = RaftRecord({'id': 's', 'role': 'member'});
    final flag = DesktopActivityFlag(w);
    addTearDown(() {
      flag.dispose();
      w.dispose();
    });
    expect(flag.masterDetail(900), true);
    expect(flag.masterDetail(768), true);
    expect(flag.masterDetail(767), false);
  });
}
