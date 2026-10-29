import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/mcp_views.dart';
import 'package:raft_ui/raft_ui.dart';

// Web v1.21.12-source.1 / a98ae003, AgentMcpTab scope="server" and
// managedMcpCredentials: one editable draft owns all headers and its test.
Map<String, dynamic> _server() => {
  'id': 'mcp1',
  'name': 'Fixture MCP',
  'description': 'Fixture tools',
  'provider': 'custom',
  'authMode': 'headers',
  'endpointUrl': 'https://tools.example.invalid/mcp',
  'enabled': true,
  'hasCredentials': true,
  'credentialHeaderNames': ['Authorization', 'X-Old', 'X-Removed'],
  'toolCatalog': [
    {'name': 'search', 'title': 'Search', 'description': 'Search fixture data'},
  ],
};

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      );
  final calls = <(String, String, Map<String, dynamic>)>[];
  List<Map<String, dynamic>> catalogServers = [_server()];
  bool failTest = false;
  bool denySave = false;
  Completer<int>? testGate;
  Completer<void>? saveGate;

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
    final payload = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
    calls.add((method, path, payload));
    if (method == 'GET' && path == '/mcp/servers') {
      return {'servers': catalogServers, 'recommendations': []};
    }
    if (path == '/mcp/servers/test-configuration') {
      if (testGate case final gate?) {
        final count = await gate.future;
        return {
          'tools': [
            for (var i = 0; i < count; i++) {'name': 'tool$i'},
          ],
        };
      }
      if (failTest) {
        throw RaftApiException.response(
          'Fixture MCP is temporarily unavailable',
          status: 502,
          body: {'error': 'Fixture MCP is temporarily unavailable'},
        );
      }
      return {
        'tools': [
          {'name': 'search'},
          {'name': 'read'},
        ],
      };
    }
    if (method == 'POST' && path == '/mcp/servers') {
      if (denySave) {
        throw RaftApiException.response(
          'Permission changed',
          status: 403,
          body: {'error': 'Permission changed'},
        );
      }
      if (saveGate case final gate?) await gate.future;
      catalogServers = [
        ...catalogServers,
        {
          ...payload,
          'id': 'created',
          'headers': null,
          'hasCredentials': payload['headers'] is Map,
          'credentialHeaderNames': [
            if (payload['headers'] case final Map values) ...values.keys,
          ],
          'toolCatalog': [],
        },
      ];
      return {'id': 'created'};
    }
    if (method == 'PATCH' && path == '/mcp/servers/mcp1') {
      catalogServers = [
        {
          ...catalogServers.first,
          for (final key in [
            'name',
            'description',
            'endpointUrl',
            'provider',
            'authMode',
          ])
            if (payload.containsKey(key)) key: payload[key],
        },
      ];
      return catalogServers.first;
    }
    return <String, dynamic>{};
  }
}

Finder _key(String name) => find.byKey(ValueKey(name));
Finder _fields(String prefix) => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith(prefix);
});

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.pump();
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String key, String label) async {
  await _tap(tester, _key(key));
  await _tap(tester, find.text(label).last);
}

void _widgetTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}

void main() {
  for (final width in [390.0, 1200.0]) {
    late _Client client;
    late WorkspaceController workspace;
    setUp(() {
      client = _Client()..user = RaftRecord({'id': 'alice'});
      client.selectServer('s1');
      workspace = WorkspaceController(client)
        ..server = RaftRecord({'id': 's1', 'role': 'owner'});
    });
    tearDown(() async {
      workspace.dispose();
      await client.dispose();
    });

    Future<void> mount(WidgetTester tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(body: AgentMcpView(controller: workspace)),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> add(WidgetTester tester) async {
      await _tap(tester, _key('mcp-add-server'));
      expect(_key('mcp-server-editor'), findsOneWidget);
      if (width >= 768) {
        expect(tester.getSize(_key('mcp-server-editor')).width, 672);
      }
      expect(
        find.descendant(
          of: _key('mcp-server-editor'),
          matching: find.textContaining(
            RegExp(r'^Add MCP server$', caseSensitive: false),
          ),
        ),
        findsOneWidget,
      );
    }

    Future<void> nameAndUrl(WidgetTester tester) async {
      await tester.enterText(_key('mcp-name'), 'New fixture MCP');
      await tester.enterText(
        _key('mcp-endpoint'),
        'https://new.example.invalid/mcp',
      );
    }

    Future<void> header(WidgetTester tester, String name, String value) async {
      await _tap(tester, _key('mcp-add-header'));
      await tester.enterText(_fields('mcp-header-name-').last, name);
      await tester.enterText(_fields('mcp-header-value-').last, value);
    }

    _widgetTest('$width create saves every credential header in one draft', (
      tester,
    ) async {
      await mount(tester);
      await add(tester);
      await nameAndUrl(tester);
      await _choose(tester, 'mcp-auth-mode', 'Credential headers');
      await header(tester, 'Authorization', 'Bearer fixture-one');
      await header(tester, 'X-Key', 'fixture-two');
      await _tap(tester, _key('mcp-editor-save'));
      final creates = client.calls.where(
        (call) => call.$1 == 'POST' && call.$2 == '/mcp/servers',
      );
      expect(creates, hasLength(1));
      expect(
        creates.single.$3,
        containsPair('headers', {
          'Authorization': 'Bearer fixture-one',
          'X-Key': 'fixture-two',
        }),
      );
      expect(creates.single.$3, isNot(contains('credentialPatch')));
      expect(_key('mcp-server-editor'), findsNothing);
      expect(find.text('New fixture MCP'), findsOneWidget);
    });

    _widgetTest(
      '$width editing preserves unchanged secrets and patches only explicit changes',
      (tester) async {
        await mount(tester);
        await _tap(tester, find.byTooltip('Edit server'));
        expect(_key('mcp-server-editor'), findsOneWidget);
        expect(_fields('mcp-header-name-'), findsNWidgets(3));
        expect(_fields('mcp-header-value-'), findsNWidgets(3));
        for (final element in _fields('mcp-header-value-').evaluate()) {
          final editable = find.descendant(
            of: find.byWidget(element.widget),
            matching: find.byType(EditableText),
          );
          expect(
            tester.widget<EditableText>(editable).controller.text,
            isEmpty,
          );
        }
        await tester.enterText(_fields('mcp-header-name-').at(1), 'X-Renamed');
        await tester.enterText(
          _fields('mcp-header-value-').at(1),
          'fixture-renamed',
        );
        await _tap(tester, _fields('mcp-remove-header-').at(2));
        await header(tester, 'X-New', 'fixture-new');
        await _tap(tester, _key('mcp-editor-save'));
        final payload = client.calls
            .singleWhere((call) => call.$1 == 'PATCH')
            .$3;
        expect(payload, isNot(contains('headers')));
        expect(payload['credentialPatch'], {
          'upsertHeaders': {
            'X-Renamed': 'fixture-renamed',
            'X-New': 'fixture-new',
          },
          'removeHeaderNames': ['X-Old', 'X-Removed'],
        });
        expect(_key('mcp-server-editor'), findsNothing);
      },
    );

    _widgetTest('$width duplicate or renamed empty headers cannot be saved', (
      tester,
    ) async {
      await mount(tester);
      await _tap(tester, find.byTooltip('Edit server'));
      expect(_key('mcp-server-editor'), findsOneWidget);
      await tester.enterText(
        _fields('mcp-header-name-').at(1),
        'authorization',
      );
      await _tap(tester, _key('mcp-editor-save'));
      expect(
        find.text(
          'Credential header names must be unique, and new or renamed headers need a value.',
        ),
        findsOneWidget,
      );
      expect(client.calls.where((call) => call.$1 == 'PATCH'), isEmpty);
      await tester.enterText(_fields('mcp-header-name-').at(1), 'X-Renamed');
      await _tap(tester, _key('mcp-editor-save'));
      expect(client.calls.where((call) => call.$1 == 'PATCH'), isEmpty);
      await tester.enterText(
        _fields('mcp-header-value-').at(1),
        'fixture-replacement',
      );
      await _tap(tester, _key('mcp-editor-save'));
      expect(client.calls.where((call) => call.$1 == 'PATCH'), hasLength(1));
      expect(_key('mcp-server-editor'), findsNothing);
    });

    _widgetTest(
      '$width provider selection fills and locks OAuth configuration',
      (tester) async {
        await mount(tester);
        await add(tester);
        await _choose(tester, 'mcp-provider', 'Notion');
        expect(find.text('https://mcp.notion.com/mcp'), findsOneWidget);
        expect(find.text('OAuth'), findsOneWidget);
        expect(_key('mcp-editor-test'), findsNothing);
        final endpoint = tester.widget<EditableText>(
          find.descendant(
            of: _key('mcp-endpoint'),
            matching: find.byType(EditableText),
          ),
        );
        expect(endpoint.readOnly, isTrue);
        await tester.enterText(_key('mcp-name'), 'Notion fixture');
        await _tap(tester, _key('mcp-editor-save'));
        final payload = client.calls
            .singleWhere((call) => call.$1 == 'POST')
            .$3;
        expect(payload, containsPair('provider', 'notion'));
        expect(payload, containsPair('authMode', 'oauth'));
        expect(
          payload,
          containsPair('endpointUrl', 'https://mcp.notion.com/mcp'),
        );
        expect(payload, isNot(contains('headers')));
      },
    );

    _widgetTest(
      '$width test connection uses current unsaved draft and retry resolves error',
      (tester) async {
        await mount(tester);
        await add(tester);
        await nameAndUrl(tester);
        await _choose(tester, 'mcp-auth-mode', 'Credential headers');
        await header(tester, 'Authorization', 'Bearer fixture-draft');
        client.failTest = true;
        await _tap(tester, _key('mcp-editor-test'));
        expect(
          find.text('Fixture MCP is temporarily unavailable'),
          findsOneWidget,
        );
        expect(_key('mcp-server-editor'), findsOneWidget);
        client.failTest = false;
        await _tap(tester, _key('mcp-editor-test'));
        expect(
          find.text('Fixture MCP is temporarily unavailable'),
          findsNothing,
        );
        expect(
          find.text('Connection succeeded. Found 2 tools.'),
          findsOneWidget,
        );
        final tests = client.calls.where(
          (call) => call.$2 == '/mcp/servers/test-configuration',
        );
        expect(tests, hasLength(2));
        expect(tests.last.$3, {
          'endpointUrl': 'https://new.example.invalid/mcp',
          'authMode': 'headers',
          'headers': {'Authorization': 'Bearer fixture-draft'},
        });
        expect(
          client.calls.where(
            (call) => call.$1 == 'POST' && call.$2 == '/mcp/servers',
          ),
          isEmpty,
        );
        await tester.enterText(
          _key('mcp-endpoint'),
          'https://changed.example.invalid/mcp',
        );
        await tester.pump();
        expect(find.text('Connection succeeded. Found 2 tools.'), findsNothing);
        await _tap(tester, _key('mcp-editor-save'));
        expect(_key('mcp-server-editor'), findsNothing);
      },
    );

    _widgetTest(
      '$width an old connection test cannot approve an edited draft',
      (tester) async {
        await mount(tester);
        await add(tester);
        await nameAndUrl(tester);
        final gate = Completer<int>();
        client.testGate = gate;
        try {
          await _tap(tester, _key('mcp-editor-test'));
          expect(
            client.calls.where((c) => c.$2.endsWith('/test-configuration')),
            hasLength(1),
          );
          await tester.enterText(
            _key('mcp-endpoint'),
            'https://changed.example.invalid/mcp',
          );
        } finally {
          gate.complete(2);
          client.testGate = null;
          await tester.pumpAndSettle();
        }
        expect(find.text('Connection succeeded. Found 2 tools.'), findsNothing);
        await _tap(tester, _key('mcp-editor-test'));
        expect(
          find.text('Connection succeeded. Found 2 tools.'),
          findsOneWidget,
        );
        expect(
          client.calls.last.$3['endpointUrl'],
          'https://changed.example.invalid/mcp',
        );
      },
    );

    _widgetTest(
      '$width authority change dismisses editor and retires a late save',
      (tester) async {
        await mount(tester);
        await add(tester);
        await nameAndUrl(tester);
        final gate = Completer<void>();
        client.saveGate = gate;
        var reads = 0;
        try {
          await _tap(tester, _key('mcp-editor-save'));
          expect(client.calls.where((c) => c.$1 == 'POST'), hasLength(1));
          workspace.server = RaftRecord({'id': 's1', 'role': 'member'});
          workspace.notifyListeners();
          await tester.pumpAndSettle();
          expect(_key('mcp-server-editor'), findsNothing);
          reads = client.calls.where((c) => c.$1 == 'GET').length;
        } finally {
          gate.complete();
          client.saveGate = null;
          await tester.pumpAndSettle();
        }
        expect(client.calls.where((c) => c.$1 == 'GET'), hasLength(reads));
        expect(find.text('New fixture MCP'), findsNothing);
        expect(_key('mcp-add-server'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    _widgetTest(
      '$width rejected permission clears private catalog and editor',
      (tester) async {
        await mount(tester);
        await add(tester);
        await nameAndUrl(tester);
        client.denySave = true;
        await _tap(tester, _key('mcp-editor-save'));
        expect(_key('mcp-server-editor'), findsNothing);
        expect(find.text('Fixture MCP'), findsNothing);
        expect(find.text('Permission changed'), findsOneWidget);
        client.denySave = false;
        await add(tester);
        await nameAndUrl(tester);
        await _tap(tester, _key('mcp-editor-save'));
        expect(find.text('Permission changed'), findsNothing);
        expect(find.text('New fixture MCP'), findsOneWidget);
      },
    );

    _widgetTest('$width resuming after OAuth refreshes connection actions', (
      tester,
    ) async {
      client.catalogServers = [
        {
          ..._server(),
          'authMode': 'oauth',
          'provider': 'notion',
          'oauthStatus': 'disconnected',
        },
      ];
      await mount(tester);
      expect(find.byTooltip('Connect Fixture MCP'), findsOneWidget);
      expect(find.byTooltip('Disconnect Fixture MCP'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      client.catalogServers = [
        {...client.catalogServers.single, 'oauthStatus': 'connected'},
      ];
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Connect Fixture MCP'), findsNothing);
      expect(find.byTooltip('Disconnect Fixture MCP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // These controls also exercise the already shipped list and role policy.
    _widgetTest(
      '$width control: MCP catalog uses the mounted server endpoint',
      (tester) async {
        await mount(tester);
        expect(_key('mcp-server-mcp1'), findsOneWidget);
        expect(find.text('Fixture MCP'), findsOneWidget);
        expect(_key('mcp-add-server'), findsOneWidget);
        expect(
          client.calls.where((call) => call.$2 == '/mcp/servers'),
          hasLength(1),
        );
        expect(
          client.calls.where((call) => call.$2.startsWith('/mcp/agents/')),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );

    _widgetTest(
      '$width control: members can view MCP without management actions',
      (tester) async {
        workspace.server = RaftRecord({'id': 's1', 'role': 'member'});
        await mount(tester);
        expect(find.text('Fixture MCP'), findsOneWidget);
        expect(_key('mcp-add-server'), findsNothing);
        expect(find.byTooltip('Edit server'), findsNothing);
        expect(find.byTooltip('Delete Server'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
