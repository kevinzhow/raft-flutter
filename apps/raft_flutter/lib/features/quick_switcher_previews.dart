import 'package:flutter/material.dart';
import 'package:raft_ui/previews.dart';
import 'package:raft_ui/raft_ui.dart';

import 'quick_switcher.dart';
import 'quick_switcher_model.dart';

@RaftPreviews('Quick switcher recent conversations', size: Size(1280, 800))
Widget quickSwitcherRecentPreview() => const _QuickSwitcherPreview();

/// Public values only; the production host supplies live workspace data.
class _QuickSwitcherPreview extends StatelessWidget {
  const _QuickSwitcherPreview();
  @override
  Widget build(BuildContext context) => RaftQuickSwitcherLayer(
    child: QuickSwitcher(
      listenable: ValueNotifier(0),
      data: () => QuickSwitcherData(
        catalog: QuickSwitcherCatalog(
          channels: const [
            {'id': 'c-design', 'name': 'design', 'type': 'channel'},
            {'id': 'c-ops', 'name': 'ops', 'type': 'private'},
          ],
          dms: const [
            {
              'id': 'dm-cindy',
              'type': 'dm',
              'peerId': 'a-cindy',
              'peerType': 'agent',
            },
          ],
          computers: const [],
          agents: const [
            {'id': 'a-cindy', 'name': 'cindy', 'displayName': 'Cindy'},
          ],
          people: const [],
        ),
        visited: const ['c-ops', 'dm-cindy', 'c-design'],
        agents: const [],
        members: const [],
        origin: 'https://public-visual-fixture.invalid',
      ),
      onClose: () {},
      onOpenEntity: (_, _) {},
      onOpenMessage: (_, _) {},
      onSearchAll: (_) {},
    ),
  );
}
