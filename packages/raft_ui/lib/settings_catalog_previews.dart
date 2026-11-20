import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Settings: long application catalog', size: Size(1000, 650))
Widget longApplicationCatalogPreview() => const _AppsPreview();

@RaftPreviews('Settings: long MCP catalog', size: Size(1000, 650))
Widget longMcpCatalogPreview() => RaftMcpServersSection(
  scrollable: true,
  servers: [
    for (var i = 0; i < 1000; i++)
      RaftMcpServerRow(
        id: '$i',
        name: 'MCP connection $i',
        provider: 'custom',
        endpointUrl: 'https://fixture.invalid/mcp/$i',
        tools: const [
          RaftMcpTool('List records', 'Read the selected records.'),
        ],
      ),
  ],
);

class _AppsPreview extends StatefulWidget {
  const _AppsPreview();
  @override
  State<_AppsPreview> createState() => _AppsPreviewState();
}

class _AppsPreviewState extends State<_AppsPreview> {
  final search = TextEditingController();
  var layout = RaftConnectedAppsLayout.grid;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RaftConnectedAppsSection(
    scrollable: true,
    tab: RaftConnectedAppsTab.myApps,
    counts: (marketplace: 0, installed: 0, myApps: 1000),
    onTab: (_) {},
    searchController: search,
    onSearch: (_) => setState(() {}),
    category: 'all',
    categories: const [('all', 'All categories')],
    onCategory: (_) {},
    layout: layout,
    onLayout: (value) => setState(() => layout = value),
    rows: [
      for (var i = 0; i < 1000; i++)
        if ('Application $i'.toLowerCase().contains(search.text.toLowerCase()))
          RaftConnectedAppRow(
            id: '$i',
            name: 'Application $i',
            initials: 'AP',
            meta: 'Workspace application',
            description: i.isEven ? 'One short description.' : 'A longer description that wraps at narrow widths and keeps each grid pair the same height.',
          ),
    ],
  );
}
