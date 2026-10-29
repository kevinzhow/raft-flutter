import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/task_selection_filter.dart';
import 'package:raft_ui/raft_ui.dart';

class _DirectoryWorkspace extends WorkspaceController {
  _DirectoryWorkspace(super.client);

  @override
  Future<void> refreshUnread() async {}

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/members')) {
      return [
        {'userId': 'self', 'name': 'viewer', 'displayName': 'Viewer'},
        {'userId': 'suffix', 'name': 'call-me', 'displayName': 'Call me'},
        {
          'userId': 'designer',
          'name': 'designer',
          'displayName': 'Designer',
          'email': ' Designer@Example.Invalid ',
        },
        {
          'userId': 'uploaded',
          'name': 'uploaded',
          'displayName': 'Uploaded human',
          'avatarUrl': '/api/avatars/users/abcd.webp',
          'gravatarHash': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        },
        {
          'userId': 'provider',
          'name': 'provider',
          'displayName': 'Provider',
          'avatarUrl': 'https://provider.invalid/default.png',
          'email': 'provider@example.invalid',
        },
      ];
    }
    if (path == '/agents') {
      return [
        {
          'id': 'cindy',
          'name': 'Cindy',
          'displayName': 'Cindy',
          'avatarUrl': 'pixel:robot',
        },
        {
          'id': 'product',
          'name': 'ProductUX',
          'displayName': 'Product UX Designer',
          'avatarUrl': 'https://cdn.invalid/product-ux.webp',
        },
      ];
    }
    if (path == '/tasks/server') return {'tasks': [], 'next_cursor': null};
    return {};
  }
}

Future<_DirectoryWorkspace> _open(
  WidgetTester tester, {
  String field = 'Assignee',
  bool chinese = false,
}) async {
  final client =
      RaftClient(
          origin: 'https://task-avatar-fixture.invalid',
          sessionStore: MemorySessionStore(),
        )
        ..user = RaftRecord({
          'id': 'self',
          'name': 'viewer',
          'displayName': 'Viewer',
        });
  client.selectServer('s');
  final workspace = _DirectoryWorkspace(client)
    ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'});
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(platform: TargetPlatform.linux),
      locale: Locale(chinese ? 'zh' : 'en'),
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(
        body: ResourceView(
          controller: workspace,
          section: 'tasks',
          onMessage: (_, _) async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final filter = find.byWidgetPredicate(
    (w) => w is TaskSelectionFilter && w.field == field,
  );
  expect(filter, findsOneWidget);
  await tester.tap(
    find.descendant(of: filter, matching: find.byType(RaftPickerTriggerButton)),
  );
  await tester.pumpAndSettle();
  return workspace;
}

RaftSelectionOption _option(WidgetTester tester, String field, String key) {
  final popup = tester.widget<RaftSelectionPopover>(
    find.byKey(ValueKey('task-selection-${field.toLowerCase()}-popover')),
  );
  return popup.options.singleWhere(
    (o) => o.rowKey == ValueKey('task-filter-$field-$key'),
  );
}

Future<void> _retire(
  WidgetTester tester,
  _DirectoryWorkspace? workspace,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  if (workspace != null) {
    workspace.dispose();
    await workspace.client.dispose();
  }
}

void main() {
  for (final field in ['Creator', 'Assignee']) {
    for (final chinese in [false, true]) {
      testWidgets(
        'real $field self is explicit empty italic sentinel; zh=$chinese',
        (tester) async {
          _DirectoryWorkspace? workspace;
          try {
            workspace = await _open(tester, field: field, chinese: chinese);
            final self = _option(tester, field, 'user:self');
            expect(self.italic, isTrue);
            expect(self.leading, isNull);
            expect(self.reserveLeadingSlot, isTrue);
            expect(
              self.label,
              chinese
                  ? (field == 'Creator' ? '我创建的' : '分配给我的')
                  : (field == 'Creator' ? 'Created by me' : 'Assigned to me'),
            );
            await tester.tap(
              find.byKey(ValueKey('task-filter-$field-user:self')),
            );
            await tester.pumpAndSettle();
            final dynamic state = tester.state(find.byType(ResourceView));
            final Set<String> selection = field == 'Creator'
                ? state.taskAdvanced.creators
                : state.taskAdvanced.assignees;
            expect(selection, {'user:self'});
            expect(_option(tester, field, 'user:self').checked, isTrue);
          } finally {
            await _retire(tester, workspace);
          }
        },
      );
    }
  }

  testWidgets('ordinary member named Call me never becomes a sentinel', (
    tester,
  ) async {
    _DirectoryWorkspace? workspace;
    try {
      workspace = await _open(tester);
      final ordinary = _option(tester, 'Assignee', 'user:suffix');
      expect(ordinary.italic, isFalse);
      expect(ordinary.leading, isNotNull);
      final row = find.byKey(
        const ValueKey('task-filter-Assignee-user:suffix'),
      );
      expect(
        find.descendant(of: row, matching: find.byType(RaftAvatar)),
        findsOneWidget,
      );
    } finally {
      await _retire(tester, workspace);
    }
  });

  testWidgets(
    'real directory identities reach canonical avatar content without losing sources',
    (tester) async {
      _DirectoryWorkspace? workspace;
      try {
        workspace = await _open(tester);
        RaftAvatarContent content(String key) =>
            tester.widget<RaftAvatarContent>(
              find.descendant(
                of: find.byKey(ValueKey('task-filter-Assignee-$key')),
                matching: find.byType(RaftAvatarContent),
              ),
            );
        final cindy = content('agent:cindy');
        expect(cindy.kind, RaftAvatarContentKind.agent);
        expect(cindy.pixelKey, 'robot');
        final product = content('agent:product');
        expect(product.uploadedUrl, 'https://cdn.invalid/product-ux.webp');
        expect(product.kind, RaftAvatarContentKind.agent);
        final designer = content('user:designer');
        expect(designer.uploadedUrl, isNull);
        expect(Uri.parse(designer.gravatarUrl!).host, 'www.gravatar.com');
        expect(Uri.parse(designer.gravatarUrl!).queryParameters, {
          's': '16',
          'd': '404',
        });
        final uploaded = content('user:uploaded');
        expect(
          uploaded.uploadedUrl,
          'https://task-avatar-fixture.invalid/api/avatars/users/abcd.webp',
        );
        final provider = content('user:provider');
        expect(provider.uploadedUrl, isNull);
        expect(provider.gravatarUrl, isNotNull);
        final row = find.byKey(
          const ValueKey('task-filter-Assignee-agent:product'),
        );
        final leaf = tester.widget<RaftSizedImage>(
          find.descendant(of: row, matching: find.byType(RaftSizedImage)),
        );
        expect(leaf.image, isA<RaftAvatarImageProvider>());
        expect(
          (leaf.image as RaftAvatarImageProvider).url,
          product.uploadedUrl,
        );
      } finally {
        await _retire(tester, workspace);
      }
    },
  );
}
