import 'package:flutter/material.dart';
import 'package:raft_ui/previews.dart';

import 'resource_search.dart';
import 'search_home.dart';

@RaftPreviews('Page Search home history', size: Size(390, 844))
@RaftPreviews('Page Search home history desktop', size: Size(957, 689))
Widget searchHomeReferencePreview() => const _SearchHomePreview();

/// Public values only. Production Search-home controls retain their callbacks.
class _SearchHomePreview extends StatefulWidget {
  const _SearchHomePreview();
  @override
  State<_SearchHomePreview> createState() => _SearchHomePreviewState();
}

class _SearchHomePreviewState extends State<_SearchHomePreview> {
  List<String> history = ['Android', 'release notes'];
  String? receipt;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ResourceSearchHome(
          history: history,
          frequent: const [
            SearchEntity('channel', 'channel-design', 'design', 'Channel', {}),
            SearchEntity('agent', 'agent-cindy', 'Cindy', 'Agent', {}),
          ],
          origin: 'https://public-visual-fixture.invalid',
          onQuery: (query) => setState(() => receipt = 'Search: $query'),
          onRemove: (query) => setState(
            () => history = history.where((q) => q != query).toList(),
          ),
          onClear: () => setState(() => history = []),
          onEntity: (entity) => setState(() => receipt = 'Open: ${entity.key}'),
        ),
      ),
      if (receipt != null)
        Text(receipt!, key: const Key('search-home-preview-receipt')),
    ],
  );
}
