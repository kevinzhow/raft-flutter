import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/computer_runtime_provider_connect_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/runtime_auth_fixture.dart';

/// Web v1.24 RuntimeProviderConnectDialog (+ providerConnectFailure): connect
/// Qwen Code to a model provider with an API key.
void main() {
  late FixtureWorkspace w;
  late FakeComputerApi api;

  Map<String, dynamic> provider(
    String id, {
    String? description,
    bool configured = false,
    Map<String, dynamic> endpoint = const {'kind': 'fixed'},
    bool needsModelIds = false,
    Map<String, String>? group,
  }) => {
    'id': id,
    'label': id.toUpperCase(),
    'description': ?description,
    'group': ?group,
    'configured': configured,
    'endpoint': endpoint,
    'needsModelIds': needsModelIds,
  };

  final providers = [
    provider('alpha', description: 'First provider', configured: true),
    provider(
      'beta',
      group: {'id': 'cloud', 'label': 'Cloud'},
      endpoint: {
        'kind': 'choice',
        'options': [
          {'id': 'eu', 'label': 'Europe', 'url': 'https://eu.example.com/v1'},
          {'id': 'us', 'label': 'US', 'url': 'https://us.example.com/v1'},
        ],
      },
    ),
    provider(
      'gamma',
      group: {'id': 'custom'},
      endpoint: {'kind': 'custom', 'placeholder': 'http://localhost:8000/v1'},
      needsModelIds: true,
    ),
  ];

  Future<void> open(WidgetTester t, {bool touch = false}) async {
    w = await fixtureWorkspace(t);
    addTearDown(api.dispose);
    await t.pumpWidget(
      fixtureHost(
        touch: touch,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showComputerRuntimeProviderConnectDialog(
              context,
              controller: w,
              client: api.auth,
              serverId: 's',
              machineId: 'c',
              runtimeId: 'qwen',
              runtime: 'qwen',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await settle(t, 10);
  }

  Future<void> pick(WidgetTester t, String id) async {
    await t.tap(find.byKey(ValueKey('runtime-provider-choice-$id')));
    await settle(t, 3);
    await t.tap(find.byKey(const ValueKey('runtime-provider-continue')));
    await settle(t, 5);
  }

  Future<void> typeKey(WidgetTester t, String id, String text) async {
    await t.enterText(find.byKey(ValueKey(id)), text);
    await settle(t, 2);
  }

  bool enabled(WidgetTester t, String key) =>
      t.widget<RaftButton>(find.byKey(ValueKey(key))).onPressed != null;

  setUp(() {
    api = FakeComputerApi();
    api.answers['GET /qwen/providers'] = (_) => {
      'kind': 'listed',
      'providers': providers,
    };
  });

  testWidgets('reads the providers the Computer lists, grouped, with their '
      'notes; Continue waits for a choice', (t) async {
    await open(t);
    expect(find.text('Connect Qwen Code to a provider'), findsOneWidget);
    expect(find.text('Choose the provider your API key is from.'), findsOne);
    expect(find.text('Other providers'), findsOneWidget);
    expect(find.text('Cloud'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);
    expect(find.text('First provider'), findsOneWidget);
    expect(find.text('Already configured on this Computer'), findsOneWidget);
    expect(find.byType(RaftInputGroup), findsNothing);
    expect(enabled(t, 'runtime-provider-continue'), isFalse);
    await t.tap(find.byKey(const ValueKey('runtime-provider-choice-alpha')));
    await settle(t, 3);
    expect(enabled(t, 'runtime-provider-continue'), isTrue);
  });

  testWidgets('search narrows the list; no match says so', (t) async {
    api.answers['GET /qwen/providers'] = (_) => {
      'kind': 'listed',
      'providers': [
        ...providers,
        provider('delta'),
        provider('epsilon'),
        provider('zeta'),
      ],
    };
    await open(t);
    await t.enterText(find.byType(EditableText).first, 'cloud');
    await settle(t, 3);
    expect(
      find.byKey(const ValueKey('runtime-provider-choice-beta')),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey('runtime-provider-choice-alpha')),
      findsNothing,
    );
    await t.enterText(find.byType(EditableText).first, 'zzz');
    await settle(t, 3);
    expect(find.text('No matching providers'), findsOneWidget);
  });

  testWidgets('a provider with a fixed endpoint asks only for the key; '
      'Connect saves it, drops the cached view and says it is saved', (
    t,
  ) async {
    api.answers['/qwen/connect-provider'] = (_) => {
      'result': {'kind': 'connected'},
    };
    await open(t);
    await pick(t, 'alpha');
    expect(
      find.byKey(const ValueKey('runtime-provider-base-url')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('runtime-provider-model')), findsNothing);
    expect(
      find.byKey(const ValueKey('runtime-provider-endpoint')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('runtime-provider-scope')),
      findsOneWidget,
    );
    expect(enabled(t, 'runtime-provider-connect'), isFalse);
    await typeKey(t, 'runtime-provider-api-key', '  sk-secret  ');
    expect(enabled(t, 'runtime-provider-connect'), isTrue);
    await api.auth.read('s', 'c');
    final before = api.gets.length;
    await t.tap(find.byKey(const ValueKey('runtime-provider-connect')));
    await settle(t, 10);
    expect(api.bodies.values.single, {
      'providerId': 'alpha',
      'apiKey': 'sk-secret',
    });
    expect(
      find.text(
        'Saved on this Computer. Qwen Code checks the key when an agent runs.',
      ),
      findsOneWidget,
    );
    // The card reads the new status: the cached view is gone.
    await api.auth.read('s', 'c');
    expect(api.gets.length, greaterThan(before));
    // The key is not kept anywhere on screen.
    expect(
      find.byKey(const ValueKey('runtime-provider-api-key')),
      findsNothing,
    );
    await t.tap(find.byKey(const ValueKey('runtime-provider-done')));
    await settle(t);
    expect(find.text('Connect Qwen Code to a provider'), findsNothing);
  });

  testWidgets('a choice of endpoints needs one; a custom URL and a model '
      'name where the provider asks for them', (t) async {
    api.answers['/qwen/connect-provider'] = (_) => {
      'result': {'kind': 'connected'},
    };
    await open(t);
    await pick(t, 'beta');
    expect(find.text('Choose the one your API key belongs to.'), findsOne);
    await typeKey(t, 'runtime-provider-api-key', 'k');
    // The endpoint is not chosen yet.
    expect(enabled(t, 'runtime-provider-connect'), isFalse);
    await t.tap(find.byKey(const ValueKey('runtime-provider-endpoint')));
    await settle(t, 4);
    await t.tap(find.text('Europe').last);
    await settle(t, 4);
    expect(enabled(t, 'runtime-provider-connect'), isTrue);
    await t.tap(find.byKey(const ValueKey('runtime-provider-connect')));
    await settle(t, 8);
    expect(api.bodies.values.single, {
      'providerId': 'beta',
      'apiKey': 'k',
      'baseUrl': 'https://eu.example.com/v1',
    });
  });

  testWidgets('custom endpoint and model: both are required, sent trimmed', (
    t,
  ) async {
    api.answers['/qwen/connect-provider'] = (_) => {
      'result': {'kind': 'connected'},
    };
    await open(t);
    await pick(t, 'gamma');
    await typeKey(t, 'runtime-provider-api-key', 'k');
    expect(enabled(t, 'runtime-provider-connect'), isFalse);
    await typeKey(t, 'runtime-provider-base-url', ' http://localhost:8000/v1 ');
    expect(enabled(t, 'runtime-provider-connect'), isFalse);
    await typeKey(t, 'runtime-provider-model', ' qwen3 ');
    expect(enabled(t, 'runtime-provider-connect'), isTrue);
    await t.tap(find.byKey(const ValueKey('runtime-provider-connect')));
    await settle(t, 8);
    expect(api.bodies.values.single, {
      'providerId': 'gamma',
      'apiKey': 'k',
      'baseUrl': 'http://localhost:8000/v1',
      'modelIds': ['qwen3'],
    });
  });

  testWidgets('Back keeps what was typed for the same provider and starts '
      'over for another', (t) async {
    await open(t);
    await pick(t, 'alpha');
    await typeKey(t, 'runtime-provider-api-key', 'secret');
    await t.tap(find.byKey(const ValueKey('runtime-provider-back')));
    await settle(t, 4);
    expect(find.byKey(const ValueKey('runtime-provider-choose')), findsOne);
    await t.tap(find.byKey(const ValueKey('runtime-provider-continue')));
    await settle(t, 4);
    // The key is a password field, and still there: Connect is enabled.
    expect(
      t
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('runtime-provider-api-key')),
              matching: find.byType(EditableText),
            ),
          )
          .obscureText,
      isTrue,
    );
    expect(enabled(t, 'runtime-provider-connect'), isTrue);
    await t.tap(find.byKey(const ValueKey('runtime-provider-back')));
    await settle(t, 4);
    await t.tap(find.byKey(const ValueKey('runtime-provider-choice-gamma')));
    await t.tap(find.byKey(const ValueKey('runtime-provider-continue')));
    await settle(t, 4);
    expect(enabled(t, 'runtime-provider-connect'), isFalse);
  });

  for (final (answer, text) in [
    (
      {'kind': 'failed', 'reason': 'rejected'},
      'Qwen Code did not accept these settings. Check the key and try again.',
    ),
    (
      {'kind': 'failed', 'reason': 'process_failed'},
      'Qwen Code could not run on this Computer. Try again.',
    ),
    (
      {'kind': 'busy'},
      'Another provider is being connected on this Computer. Try again in a moment.',
    ),
    (
      {'kind': 'unsupported', 'reason': 'version_unsupported'},
      "Qwen Code on this Computer can't be connected from the web.",
    ),
  ]) {
    testWidgets('${answer['kind']} ${answer['reason'] ?? ''}: a warning in '
        'the form; the key stays so Connect can be pressed again', (t) async {
      api.answers['/qwen/connect-provider'] = (_) => {'result': answer};
      await open(t);
      await pick(t, 'alpha');
      await typeKey(t, 'runtime-provider-api-key', 'k');
      await t.tap(find.byKey(const ValueKey('runtime-provider-connect')));
      await settle(t, 8);
      expect(find.text(text), findsOneWidget);
      expect(enabled(t, 'runtime-provider-connect'), isTrue);
      expect(
        find.byKey(const ValueKey('runtime-provider-saved')),
        findsNothing,
      );
    });
  }

  testWidgets('a save that timed out may have happened: the view is dropped', (
    t,
  ) async {
    api.answers['/qwen/connect-provider'] = (_) => {
      'result': {'kind': 'failed', 'reason': 'timed_out'},
    };
    await open(t);
    await pick(t, 'alpha');
    await typeKey(t, 'runtime-provider-api-key', 'k');
    await api.auth.read('s', 'c');
    final before = api.gets.length;
    await t.tap(find.byKey(const ValueKey('runtime-provider-connect')));
    await settle(t, 8);
    expect(
      find.textContaining('The key may or may not be saved'),
      findsOneWidget,
    );
    await api.auth.read('s', 'c');
    expect(api.gets.length, greaterThan(before));
  });

  testWidgets('the server refuses the key: it says so under the key field, '
      'and editing the field clears it', (t) async {
    api.answers['/qwen/connect-provider'] = (_) =>
        throw RaftApiException.response(
          'bad',
          status: 400,
          body: {'error': 'bad', 'code': 'invalid_api_key'},
        );
    await open(t);
    await pick(t, 'alpha');
    await typeKey(t, 'runtime-provider-api-key', 'k k');
    await t.tap(find.byKey(const ValueKey('runtime-provider-connect')));
    await settle(t, 8);
    expect(find.text('Paste the whole API key, with no spaces.'), findsOne);
    await typeKey(t, 'runtime-provider-api-key', 'kk');
    expect(find.text('Paste the whole API key, with no spaces.'), findsNothing);
  });

  testWidgets('the providers cannot be read: the reason; Try again reads '
      'once more when it may help', (t) async {
    var calls = 0;
    api.answers['GET /qwen/providers'] = (_) {
      calls++;
      if (calls == 1) {
        throw RaftApiException.response(
          'x',
          status: 504,
          body: {'error': 'x', 'code': 'computer_timeout'},
        );
      }
      return {'kind': 'listed', 'providers': providers};
    };
    await open(t);
    expect(
      find.text('The Computer did not answer in time. Try again.'),
      findsOneWidget,
    );
    await t.tap(find.byKey(const ValueKey('runtime-provider-retry')));
    await settle(t, 8);
    expect(find.byKey(const ValueKey('runtime-provider-choose')), findsOne);
    expect(calls, 2);
  });

  testWidgets('a refusal that retrying cannot fix has no Try again', (t) async {
    api.answers['GET /qwen/providers'] = (_) =>
        throw const RaftApiException('no', status: 403);
    await open(t);
    expect(
      find.text(
        'Only the person who connected this Computer, or an owner or admin, can connect its runtimes to a provider.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('runtime-provider-retry')), findsNothing);
    expect(find.text('Close'), findsWidgets);
  });

  testWidgets('no providers: it says so', (t) async {
    api.answers['GET /qwen/providers'] = (_) => {
      'kind': 'listed',
      'providers': <Object>[],
    };
    await open(t);
    expect(
      find.text('Qwen Code on this Computer lists no providers.'),
      findsOneWidget,
    );
  });

  testWidgets('Escape closes it; a press outside does not (Web '
      'disablePointerDismissal)', (t) async {
    await open(t);
    await t.tapAt(const Offset(4, 590));
    await settle(t, 4);
    expect(find.text('Connect Qwen Code to a provider'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(t, 6);
    expect(find.text('Connect Qwen Code to a provider'), findsNothing);
  });

  testWidgets('on a phone it is a bottom sheet with the same steps', (t) async {
    t.view.physicalSize = const Size(390, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await open(t, touch: true);
    expect(find.byType(RaftFormSheet), findsOneWidget);
    await pick(t, 'alpha');
    expect(find.byKey(const ValueKey('runtime-provider-api-key')), findsOne);
  });
}
