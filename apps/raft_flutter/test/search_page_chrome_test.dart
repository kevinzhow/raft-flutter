import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_search.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/search_filter_bar.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/screens/screen_fixture.dart' show ScreenFixtureClient;
import 'support/search_text.dart';

class _SearchWorkspace extends WorkspaceController {
  _SearchWorkspace()
    : super(
        ScreenFixtureClient(
          (method, path, _) =>
              method == 'POST' && path == '/feature-flags/evaluate'
              ? {
                  'evaluations': [
                    {'key': 'workspace_artifacts_v0', 'enabled': true},
                  ],
                }
              : null,
          user: {'id': 'owner', 'name': 'Owner'},
          server: 'search-chrome-fixture',
        ),
      ) {
    server = RaftRecord({'id': 'search-chrome-fixture', 'role': 'owner'});
    channels = [
      RaftChannel({
        'id': 'private-notes',
        'name': 'private-notes',
        'description': 'A private place to review notes',
        'type': 'private',
        'joined': true,
      }),
    ];
  }

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      switch (path) {
        '/messages/search' => {
          'results': [
            {
              'id': 'message',
              'channelId': 'private-notes',
              'channelName': 'private-notes',
              'channelType': 'private',
              'senderId': 'owner',
              'senderType': 'user',
              'senderName': 'Owner',
              'content': 'A private Android result.',
              'createdAt': '2026-06-19T10:00:00.000Z',
            },
          ],
          'hasMore': false,
        },
        '/search' => {
          'groups': [
            {
              'app': 'artifacts',
              'items': [
                {
                  'card': {
                    'id': 'pt_00000000-0000-4000-8000-000000000001',
                    'title': 'Private notes',
                    'kind': 'markdown',
                    'updatedAt': '2026-06-19T10:00:00.000Z',
                    'home': {
                      'kind': 'conversation',
                      'conversation': {
                        'id': 'private-notes',
                        'type': 'private',
                        'name': 'private-notes',
                      },
                    },
                  },
                  'matches': [],
                },
              ],
            },
          ],
        },
        _ => [],
      };
}

Future<void> _search(
  WidgetTester tester,
  Size size,
  TargetPlatform platform, {
  bool dark = false,
  bool scoped = false,
}) async {
  final workspace = _SearchWorkspace();
  addTearDown(() async {
    workspace.dispose();
    await workspace.client.dispose();
  });
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark).copyWith(platform: platform),
      home: Scaffold(
        body: ResourceView(
          controller: workspace,
          section: 'search',
          mobileRoot: platform == TargetPlatform.android && !scoped,
          restoreSearchState: false,
          initialSearchChannelId: scoped ? 'private-notes' : null,
          clock: () => DateTime.utc(2026, 6, 19, 12),
          onMessage: (_, _) async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(EditableText).first, 'private');
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

void main() {
  for (final (platform, size) in [
    (TargetPlatform.linux, const Size(1280, 900)),
    (TargetPlatform.linux, const Size(390, 844)),
    (TargetPlatform.android, const Size(390, 844)),
    (TargetPlatform.android, const Size(856, 944)),
    (TargetPlatform.android, const Size(944, 856)),
  ]) {
    testWidgets('Search field shortcuts on $platform at $size', (tester) async {
      await _search(tester, size, platform);
      final field = find.byType(RaftSearchInput);
      final escape = find.descendant(
        of: field,
        matching: find.widgetWithText(RaftKbd, 'Esc'),
      );
      final clear = find.descendant(
        of: field,
        matching: find.bySemanticsLabel('Clear Search'),
      );
      expect(clear, findsOneWidget);
      if (platform == TargetPlatform.linux) {
        expect(escape, findsOneWidget);
        expect(
          tester.getRect(escape).right,
          lessThan(tester.getRect(clear).left),
        );
      } else {
        expect(escape, findsNothing);
      }
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .controller
            .text,
        isEmpty,
      );
      expect(clear, findsNothing);
    });
  }

  testWidgets('Search labels a private channel with a lock', (tester) async {
    await _search(tester, const Size(1280, 900), TargetPlatform.linux);
    final result = find.ancestor(
      of: find.byWidgetPredicate(
        (widget) => widget is RaftBadge && widget.label == 'Channel',
      ),
      matching: find.byType(RaftSearchResultSurface),
    );
    expect(result, findsOneWidget);
    expect(
      find.descendant(
        of: result,
        matching: find.byWidgetPredicate(
          (widget) => widget is RaftIcon && widget.glyph == RaftGlyph.lock,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Search shows the channel prefix in an Artifact subtitle', (
    tester,
  ) async {
    await _search(tester, const Size(1280, 900), TargetPlatform.linux);
    final row = find.byKey(
      const ValueKey('app:artifacts:pt_00000000-0000-4000-8000-000000000001'),
    );
    expect(row, findsOneWidget);
    expect(
      find.descendant(
        of: row,
        matching: find.text('#private-notes · 2 hours ago'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Desktop Search uses the pointer panel and filter insets', (
    tester,
  ) async {
    await _search(tester, const Size(1280, 900), TargetPlatform.linux);
    final field = tester.getRect(find.byType(RaftSearchInput));
    final filters = tester.getRect(find.byType(SearchFilterBar));
    expect(field.left, 16);
    expect(field.right, 1264);
    expect(filters.left, 16);
    expect(filters.right, 1264);
    expect(tester.getTopLeft(find.byType(ResourceSearchResults)).dy, 88);
  });

  testWidgets('Desktop Search uses the same row rhythm for each result kind', (
    tester,
  ) async {
    await _search(tester, const Size(1280, 900), TargetPlatform.linux);
    final message = find.byType(RaftQuickSwitcherHit);
    final artifact = find.byKey(
      const ValueKey('app:artifacts:pt_00000000-0000-4000-8000-000000000001'),
    );
    expect(tester.getSize(message).height, 62);
    expect(tester.getSize(artifact).height, 62);
    expect(
      tester.getTopLeft(message).dy - tester.getBottomLeft(artifact).dy,
      46,
    );
    expect(findSearchText('A private place to review notes'), findsOneWidget);
  });

  testWidgets('Scoped phone Search keeps a full trailing field inset', (
    tester,
  ) async {
    await _search(
      tester,
      const Size(390, 844),
      TargetPlatform.android,
      scoped: true,
    );
    final field = tester.getRect(find.byType(RaftSearchInput));
    expect(field.left, 61);
    expect(field.right, 370);
  });

  testWidgets('Dark Search paints the active result on the dark canvas', (
    tester,
  ) async {
    await _search(
      tester,
      const Size(1280, 900),
      TargetPlatform.linux,
      dark: true,
    );
    final selected = find.byWidgetPredicate(
      (widget) => widget is RaftSearchResultSurface && widget.selected,
    );
    final fill = find.descendant(
      of: selected,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color ==
                const Color(0xff302b1a),
      ),
    );
    expect(fill, findsOneWidget);
  });
}
