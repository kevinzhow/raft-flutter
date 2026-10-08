import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/previews.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/personal_presentation.dart';
import '../data/search_memory.dart';
import 'appearance_section.dart';
import 'page_alignment_fixtures.dart';
import 'resource_view.dart';
import 'account_settings.dart';

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

@RaftPreviews('Page Search filtered results', size: Size(390, 844))
Widget pageSearchReferencePreview() =>
    const _ResourcePagePreview(section: 'search');

@RaftPreviews('Page Account profile', size: Size(390, 844))
Widget pageAccountReferencePreview() => const _AccountPagePreview();

@RaftPreviews('Page Appearance two axes', size: Size(957, 689))
Widget pageAppearanceReferencePreview() => const _AppearancePagePreview();

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
      'plan': 'free',
    })
    ..channels = [
      RaftChannel({'id': 'channel-design', 'name': 'design', 'joined': true}),
      if (widget.section == 'search')
        RaftChannel({
          'id': 'channel-android',
          'name': 'android-artifacts',
          'description': 'Builds and screenshots',
          'type': 'channel',
          'joined': true,
        }),
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
          initialQuery: widget.section == 'search' ? 'Android' : null,
          onSearchEntity: (entity) async =>
              setState(() => receipt = entity.key),
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
    if (path == '/messages/search') return pageSearchFixture;
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

class _AccountPagePreview extends StatefulWidget {
  const _AccountPagePreview();
  @override
  State<_AccountPagePreview> createState() => _AccountPagePreviewState();
}

class _AccountPagePreviewState extends State<_AccountPagePreview> {
  late final client = _AccountProfileFixtureClient()
    ..user = RaftRecord({
      'id': 'visual-user',
      'name': 'artin',
      'displayName': 'artin',
      'email': 'artin@slock.ai',
      'emailVerified': true,
    });
  late final workspace = _FixtureWorkspace(client);
  @override
  void dispose() {
    workspace.dispose();
    client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    primary: false,
    padding: const EdgeInsets.all(16),
    child: AccountSettings(controller: workspace),
  );
}

class _AppearancePagePreview extends StatefulWidget {
  const _AppearancePagePreview();
  @override
  State<_AppearancePagePreview> createState() => _AppearancePagePreviewState();
}

class _AppearancePagePreviewState extends State<_AppearancePagePreview> {
  RaftAppearance? value;
  final presentation = PersonalPresentationStore(
    storage: _VisualPresentationStorage(),
  );
  @override
  void initState() {
    super.initState();
    presentation.bind(
      'https://public-visual-fixture.invalid',
      'visual-user',
      profileFont: 'md',
    );
  }

  @override
  void dispose() {
    presentation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return SingleChildScrollView(
      primary: false,
      padding: const EdgeInsets.all(16),
      child: RaftAppearanceSection(
        appearance:
            value ??
            RaftAppearance(
              mode: t.dark ? ThemeMode.dark : ThemeMode.light,
              light: t.family,
            ),
        onAppearance: (next) => setState(() => value = next),
        presentation: presentation,
      ),
    );
  }
}

class _AccountProfileFixtureClient extends RaftClient {
  _AccountProfileFixtureClient()
    : super(
        origin: 'https://public-visual-fixture.invalid',
        sessionStore: MemorySessionStore(),
      );
  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    if (method == 'GET' && path == '/auth/identities') {
      return {'identities': [], 'passwordConfigured': true};
    }
    if (method == 'GET' && path == '/auth/providers') return {'providers': []};
    throw const RaftApiException(
      'This public account fixture does not execute mutations.',
    );
  }
}

class _VisualPresentationStorage implements SearchMemoryStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
