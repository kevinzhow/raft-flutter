import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/previews.dart';

import '../data/workspace_controller.dart';
import 'page_alignment_fixtures.dart';
import 'resource_view.dart';

@RaftPreviews('Page Tasks reference phone', size: Size(390, 844))
@RaftPreviews('Page Tasks reference desktop', size: Size(957, 689))
Widget pageTasksReferencePreview() =>
    const _ResourcePagePreview(section: 'tasks');

@RaftPreviews('Page Saved reference', size: Size(342, 620))
Widget pageSavedReferencePreview() =>
    const _ResourcePagePreview(section: 'saved');

@RaftPreviews('Page Activity reference', size: Size(342, 620))
Widget pageActivityReferencePreview() =>
    const _ResourcePagePreview(section: 'activity');

/// Exercises the production resource page with the source's public JSON fixtures.
/// Network and authentication are absent; controls retain their actual UI path.
class _ResourcePagePreview extends StatefulWidget {
  const _ResourcePagePreview({required this.section});
  final String section;
  @override
  State<_ResourcePagePreview> createState() => _ResourcePagePreviewState();
}

class _ResourcePagePreviewState extends State<_ResourcePagePreview> {
  late final RaftClient client = RaftClient(
    origin: 'https://public-visual-fixture.invalid',
    sessionStore: MemorySessionStore(),
  )..user = RaftRecord({'id': 'visual-user', 'displayName': 'artin'});
  late final _FixtureWorkspace workspace = _FixtureWorkspace(client)
    ..server = RaftRecord({
      'id': 'server-visual',
      'name': 'Visual workspace',
      'role': 'owner',
    })
    ..channels = [
      RaftChannel({'id': 'channel-design', 'name': 'design', 'joined': true}),
    ]
    ..section = widget.section;
  String? receipt;
  @override
  void dispose() {
    workspace.dispose();
    client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ResourceView(
          controller: workspace,
          section: widget.section,
          onMessage: (channel, message) async =>
              setState(() => receipt = '$channel:$message'),
        ),
      ),
      if (receipt != null)
        Text(receipt!, key: const Key('page-preview-navigation-receipt')),
    ],
  );
}

class _FixtureWorkspace extends WorkspaceController {
  _FixtureWorkspace(super.client);
  @override
  Future<void> refreshUnread() async {}
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/tasks/server') {
      final tasks = (pageTasksFixture['tasks'] as List)
          .where(
            (task) =>
                query?['status'] == null || task['status'] == query?['status'],
          )
          .toList();
      return {'tasks': tasks, 'next_cursor': null};
    }
    if (path == '/channels/saved') return pageSavedFixture;
    if (path.startsWith('/channels/inbox')) return pageActivityFixture;
    if (path.endsWith('/members')) {
      return [
        {'userId': 'visual-user', 'displayName': 'artin'},
      ];
    }
    if (path == '/agents') {
      return [
        {'id': 'agent-cindy', 'displayName': 'Cindy'},
        {'id': 'agent-product-ux', 'displayName': 'Product UX Designer'},
      ];
    }
    return {};
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async =>
      throw const RaftApiException(
        'This public visual fixture does not execute server mutations.',
      );
}
