import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/managed_agent_launcher.dart';
import 'package:raft_flutter/features/runtime_form_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

/// A server with provider connections on serves the Built-in Pi form with
/// `provider.saved_connection`, `x-connectionOwned` fields and a `revision`
/// (packages/runtime-form README). The fixtures are those wire shapes.
Map<String, dynamic> _fixture(String name) {
  final dir = [
    '../../packages/raft_client/test/fixtures/runtime-form',
    'packages/raft_client/test/fixtures/runtime-form',
  ].firstWhere((path) => File('$path/$name').existsSync());
  return Map<String, dynamic>.from(
    jsonDecode(File('$dir/$name').readAsStringSync()),
  );
}

class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;

  /// The connection renamed by the edit dialog (shown by the next sources).
  String teamName = 'DeepSeek · Team key';
  final patches = <(String, dynamic)>[];
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/provider-connections') {
      return {
        'connections': [
          {
            'id': 'conn-team',
            'name': teamName,
            'providerId': 'deepseek',
            'enabled': true,
            'hasCredential': true,
          },
        ],
        'providerOptions': [
          {'id': 'deepseek', 'label': 'DeepSeek', 'providerKind': 'preset'},
        ],
      };
    }
    throw RaftApiException('Not found: $path', status: 404);
  }

  @override
  Future<dynamic> patch(String path, {dynamic data}) async {
    patches.add((path, data));
    if (data is Map && data['name'] is String) teamName = data['name'];
    return {};
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  bool managesConnections = true;
  final posts = <Map<String, dynamic>>[];

  /// Every form read and option-source read, with its query.
  final reads = <String>[];
  final sourceQueries = <Map<String, dynamic>?>[];

  /// The `Accept-Language` each read carried, in order.
  final languages = <String?>[];
  int formReads = 0;

  /// Option-source reads that answer 409 `form_revision_stale` before serving.
  int staleSources = 0;

  /// `GET /agents/a1/runtime-form` (edit).
  Map<String, dynamic>? editForm;
  String get _team => (client as _Client).teamName;

  @override
  bool can(String capability, {RaftChannel? resource}) =>
      capability == 'manageExternalAuth'
      ? managesConnections
      : super.can(capability, resource: resource);

  Map<String, dynamic> _form() {
    formReads++;
    return {
      ..._fixture('builtin.saved.form.json'),
      'revision': 'rev-$formReads',
    };
  }

  Map<String, dynamic> _provider() {
    final source = _fixture('builtin.saved.option-source.provider.json');
    for (final o in source['options'] as List) {
      if (o['connectionId'] == 'conn-team') o['label'] = _team;
    }
    return source;
  }

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path.contains('/runtime-form')) {
      languages.add(RaftClient.currentRequestHeaders['Accept-Language']);
    }
    if (path == '/servers/s/machines') {
      return {
        'machines': [_machine],
      };
    }
    if (path.endsWith('/runtime-options')) {
      return {
        'options': [
          {'runtimeId': 'builtin', 'canSelectInThisContext': true},
        ],
      };
    }
    if (path.endsWith('/runtime-forms/v2/builtin')) {
      reads.add('form');
      return _form();
    }
    if (path == '/agents/a1/runtime-form') {
      reads.add('edit-form');
      formReads++;
      return {...?editForm, 'revision': 'rev-$formReads'};
    }
    if (path.contains('/runtime-forms/v2/builtin/option-sources/')) {
      reads.add(path.split('/').last);
      sourceQueries.add(query);
      if (staleSources > 0) {
        staleSources--;
        throw RaftApiException.response(
          'Runtime form has changed; refetch it before loading options',
          status: 409,
          body: {
            'error':
                'Runtime form has changed; refetch it before loading options',
            'code': 'form_revision_stale',
            'recovery': 'refetch_form',
          },
        );
      }
      return path.endsWith('/provider')
          ? _provider()
          : _fixture('builtin.saved.option-source.model.json');
    }
    throw RaftApiException('Not found: $path', status: 404);
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    posts.add({'method': method, 'path': path, 'data': data});
    return {'id': 'agent-new', 'name': data['name']};
  }
}

const _machine = {
  'id': 'mbp',
  'name': 'Studio',
  'status': 'online',
  'runtimes': ['builtin'],
};

Finder _key(String key) => find.byKey(ValueKey(key));

/// Whether the text input behind [key] accepts typing.
bool _enabled(WidgetTester t, String key) => t
    .widget<TextField>(
      find.descendant(of: _key(key), matching: find.byType(TextField)),
    )
    .enabled!;

void main() {
  late _Client c;
  late _Workspace w;
  setUp(() {
    c = _Client()..user = RaftRecord({'id': 'alice'});
    c.selectServer('s');
    w = _Workspace(c)..server = RaftRecord({'id': 's', 'role': 'owner'});
  });
  tearDown(() async {
    w.dispose();
    await c.stream.close();
    await c.dispose();
  });

  Widget app({
    Locale? locale,
    void Function(Future<Map<String, dynamic>?>)? opened,
  }) => MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: raftTheme(RaftFamily.brutal),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => opened?.call(
            showManagedAgentForm(context, w, initialName: 'Pi-Agent'),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );

  Future<Future<Map<String, dynamic>?>> open(
    WidgetTester t, {
    Locale? locale,
  }) async {
    late Future<Map<String, dynamic>?> result;
    t.view.physicalSize = const Size(900, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    w.server = RaftRecord({'id': 's', 'role': 'owner'});
    await t.pumpWidget(app(locale: locale, opened: (r) => result = r));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    return result;
  }

  Future<void> pickProvider(WidgetTester t, String label) async {
    await t.tap(_key('runtime-providerId'));
    await t.pumpAndSettle();
    await t.tap(find.text(label).last);
    await t.pumpAndSettle();
  }

  Finder createButton() =>
      find.widgetWithText(RaftAgentDialogButton, 'Create Agent');
  bool createEnabled(WidgetTester t) =>
      t.widget<RaftAgentDialogButton>(createButton()).onPressed != null;

  testWidgets('the Built-in Pi form with saved providers is usable', (t) async {
    await open(t);
    expect(
      find.text('Runtime configuration is unavailable. Refresh and try again.'),
      findsNothing,
    );
    expect(_key('runtime-providerId'), findsOneWidget);
    expect(createEnabled(t), false); // the direct provider needs its API key
    // Option sources carry the form's revision.
    expect(w.sourceQueries, isNotEmpty);
    for (final q in w.sourceQueries) {
      expect(q, {'formRevision': 'rev-1'});
    }
  });

  testWidgets(
    'providers are grouped: saved first, then direct; an unavailable one is disabled',
    (t) async {
      await open(t);
      await t.tap(_key('runtime-providerId'));
      await t.pumpAndSettle();
      expect(find.text('Saved providers'), findsOneWidget);
      expect(find.text('Direct setup'), findsOneWidget);
      double top(String text) => t.getTopLeft(find.text(text).last).dy;
      expect(top('Saved providers'), lessThan(top('DeepSeek · Team key')));
      expect(top('DeepSeek · Retired key'), lessThan(top('Direct setup')));
      expect(top('Direct setup'), lessThan(top('OpenAI-compatible')));
      // The unavailable connection is listed but cannot be picked.
      await t.tap(find.text('DeepSeek · Retired key'));
      await t.pumpAndSettle();
      expect(
        find.text('Direct setup'),
        findsOneWidget,
        reason: 'menu stays open',
      );
      await t.tap(find.text('DeepSeek · Team key'));
      await t.pumpAndSettle();
      expect(find.text('Direct setup'), findsNothing);
    },
  );

  testWidgets(
    'a saved provider owns the key: disabled "Provided by", not submitted',
    (t) async {
      final result = await open(t);
      expect(_enabled(t, 'runtime-apiKey'), true);
      await pickProvider(t, 'DeepSeek · Team key');
      expect(_enabled(t, 'runtime-apiKey'), false);
      expect(find.text('Provided by “DeepSeek · Team key”'), findsWidgets);
      expect(createEnabled(t), true);
      await t.tap(createButton());
      await t.pumpAndSettle();
      final data = w.posts.single['data'] as Map;
      expect(data['formValues'], {
        'providerId': 'connection:conn-team',
        'model': 'deepseek-v4-pro',
        'loadLocalPlugins': false,
        'envVars': <String, String>{},
      });
      expect(await result, isNotNull);
    },
  );

  testWidgets(
    'a gateway connection shows its endpoint fields disabled and submits neither',
    (t) async {
      await open(t);
      await pickProvider(t, 'OpenAI-compatible · Office gateway');
      expect(_enabled(t, 'runtime-apiKey'), false);
      expect(_enabled(t, 'runtime-baseUrl'), false);
      expect(
        find.text('Provided by “OpenAI-compatible · Office gateway”'),
        findsWidgets,
      );
      await t.enterText(
        find.descendant(
          of: _key('runtime-model'),
          matching: find.byType(TextField),
        ),
        'office-model',
      );
      await t.pump();
      await t.tap(createButton());
      await t.pumpAndSettle();
      expect((w.posts.single['data'] as Map)['formValues'], {
        'providerId': 'connection:conn-gateway',
        'model': 'office-model',
        'loadLocalPlugins': false,
        'envVars': <String, String>{},
      });
    },
  );

  testWidgets(
    'moving off a saved provider gives the key field back, empty and required',
    (t) async {
      await open(t);
      await pickProvider(t, 'DeepSeek · Team key');
      expect(createEnabled(t), true);
      await pickProvider(t, 'DeepSeek');
      expect(_enabled(t, 'runtime-apiKey'), true);
      expect(find.textContaining('Provided by'), findsNothing);
      expect(createEnabled(t), false);
    },
  );

  testWidgets(
    'the edit-saved-provider pencil edits the connection and refreshes the list',
    (t) async {
      await open(t);
      final pencil = _key('runtime-providerId-edit-provider');
      expect(
        pencil,
        findsNothing,
        reason: 'a direct provider has no connection',
      );
      await pickProvider(t, 'DeepSeek · Team key');
      expect(pencil, findsOneWidget);
      final before = w.sourceQueries.length;
      await t.tap(pencil);
      await t.pumpAndSettle();
      expect(
        find.text('Edit DeepSeek · Team key'.toUpperCase()),
        findsOneWidget,
      );
      await t.enterText(_key('provider-edit-name'), 'DeepSeek · Renamed');
      await t.pump();
      await t.tap(_key('provider-edit-save'));
      await t.pumpAndSettle();
      expect(c.patches.single.$1, '/provider-connections/conn-team');
      expect((c.patches.single.$2 as Map)['name'], 'DeepSeek · Renamed');
      // The sources are read again, so the field shows the new name.
      expect(w.sourceQueries.length, before + 2);
      expect(find.text('DeepSeek · Renamed'), findsWidgets);
      expect(find.text('DeepSeek · Team key'), findsNothing);
    },
  );

  testWidgets(
    'the pencil is for operators who manage provider connections only',
    (t) async {
      w.managesConnections = false;
      await open(t);
      await pickProvider(t, 'DeepSeek · Team key');
      expect(_key('runtime-providerId-edit-provider'), findsNothing);
    },
  );

  group('form revision', () {
    testWidgets('a stale option source refetches the whole form once', (
      t,
    ) async {
      w.staleSources = 1;
      await open(t);
      expect(w.formReads, 2);
      expect(_key('runtime-providerId'), findsOneWidget);
      // The second pass echoes the second form's revision, never the first.
      expect(w.sourceQueries.last, {'formRevision': 'rev-2'});
      expect(w.sourceQueries.skip(w.sourceQueries.length - 2).toList(), [
        {'formRevision': 'rev-2'},
        {'formRevision': 'rev-2'},
      ]);
    });

    testWidgets(
      'a second stale answer is a form-level error, nothing editable',
      (t) async {
        w.staleSources = 4;
        await open(t);
        expect(w.formReads, 2, reason: 'refetched once, not again');
        expect(
          find.textContaining(
            'Runtime configuration is unavailable. Refresh and try again.',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(_key('runtime-providerId'), findsNothing);
        expect(createEnabled(t), false);
      },
    );

    test('a source retry that goes stale drops the form, refetches once, keeps the draft', () async {
      final form = RuntimeFormController(
        w,
        machineId: 'mbp',
        runtimeId: 'builtin',
        valid: () => true,
      );
      addTearDown(form.dispose);
      final shown = <(bool, bool)>[];
      form.addListener(
        () => shown.add((form.loading, form.definition == null)),
      );
      await form.load();
      form.change(
        form.definition!.fields.firstWhere((f) => f.key == 'providerId'),
        'connection:conn-team',
      );
      expect(form.definition!.revision, 'rev-1');
      shown.clear();
      w.staleSources = 1;
      await form.refreshSources();
      // Dropped to loading (not editable) before the new form arrived.
      expect(shown, contains((true, true)));
      expect(form.definition!.revision, 'rev-2');
      expect(form.values['providerId'], 'connection:conn-team');
      expect(form.error, isNull);
      // A second stale answer in the same session is an error, not a loop.
      w.staleSources = 1;
      await form.refreshSources();
      expect(form.definition, isNull);
      expect(form.loading, false);
      expect(
        form.error,
        'Runtime configuration is unavailable. Refresh and try again.',
      );
      expect(w.formReads, 2);
    });
  });

  testWidgets(
    'a stored value that is no longer listed stays selected, marked',
    (t) async {
      w.editForm = {
        ..._fixture('builtin.saved.edit.json'),
        'values': {
          'providerId': 'deepseek',
          'model': 'retired-model',
          'loadLocalPlugins': false,
          'envVars': <String, String>{},
        },
      };
      final form = RuntimeFormController(
        w,
        machineId: 'mbp',
        runtimeId: 'builtin',
        agentId: 'a1',
        valid: () => true,
      );
      addTearDown(form.dispose);
      t.view.physicalSize = const Size(900, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: form,
                builder: (_, _) => form.definition == null
                    ? const SizedBox.shrink()
                    : RuntimeFormFields(form: form),
              ),
            ),
          ),
        ),
      );
      await form.load();
      await t.pumpAndSettle();
      expect(form.values['model'], 'retired-model');
      expect(
        find.descendant(
          of: _key('runtime-model'),
          matching: find.text('retired-model'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'The saved value retired-model is not in the current list. It stays selected until you pick another.',
        ),
        findsOneWidget,
      );
      // It is not a valid pick: the save is blocked until another is chosen.
      expect(form.validate()['model'], 'not_a_choice');
    },
  );

  testWidgets('an agent bound to a saved provider edits without owned fields', (
    t,
  ) async {
    w.editForm = _fixture('builtin.saved.edit.json');
    final form = RuntimeFormController(
      w,
      machineId: 'mbp',
      runtimeId: 'builtin',
      agentId: 'a1',
      valid: () => true,
    );
    addTearDown(form.dispose);
    await form.load();
    expect(form.values['providerId'], 'connection:conn-team');
    expect(form.validate(), isEmpty);
    expect(form.submission['formValues'], {
      'providerId': 'connection:conn-team',
      'model': 'deepseek-v4-pro',
      'loadLocalPlugins': false,
      'envVars': <String, String>{},
    });
    // The edit form's option sources echo the edit form's revision.
    expect(w.sourceQueries, everyElement({'formRevision': 'rev-1'}));
  });

  group('display language', () {
    testWidgets(
      'every form read asks in the app language, not the system one',
      (t) async {
        await open(t, locale: const Locale('zh', 'CN'));
        // The form and both option sources.
        expect(w.languages, ['zh-CN', 'zh-CN', 'zh-CN']);
        expect(find.text('Provider'), findsNothing); // the UI itself is Chinese
      },
    );

    testWidgets('English is sent as en', (t) async {
      await open(t, locale: const Locale('en'));
      expect(w.languages, ['en', 'en', 'en']);
    });

    testWidgets(
      'switching the language reloads the form and keeps the values',
      (t) async {
        await open(t, locale: const Locale('en'));
        await pickProvider(t, 'DeepSeek · Team key');
        w.languages.clear();
        await t.pumpWidget(app(locale: const Locale('zh', 'CN')));
        await t.pumpAndSettle();
        expect(w.languages, ['zh-CN', 'zh-CN', 'zh-CN']);
        expect(w.formReads, 2);
        // Still on the saved provider: the owned key field is disabled.
        expect(_enabled(t, 'runtime-apiKey'), false);
      },
    );
  });

  group('re-entering the API key', () {
    late RuntimeFormController form;
    setUp(() {
      w.editForm = _fixture('builtin.edit.json');
      form = RuntimeFormController(
        w,
        machineId: 'mbp',
        runtimeId: 'builtin',
        agentId: 'a1',
        valid: () => true,
      );
    });
    tearDown(() => form.dispose());

    Future<void> show(WidgetTester t) async {
      t.view.physicalSize = const Size(900, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: form,
                builder: (_, _) => form.definition == null
                    ? const SizedBox.shrink()
                    : RuntimeFormFields(form: form),
              ),
            ),
          ),
        ),
      );
      await form.load();
      await t.pumpAndSettle();
    }

    const tied =
        'The API key is tied to the saved settings you changed. Enter a new one.';
    const kept = 'Leave blank to keep the saved value.';

    testWidgets(
      'a blank key keeps the stored one until a bound field changes',
      (t) async {
        await show(t);
        expect(find.text(kept), findsOneWidget);
        expect(find.text(tied), findsNothing);
        expect(form.reentryBlocked, false);
        await t.enterText(
          find.descendant(
            of: _key('runtime-baseUrl'),
            matching: find.byType(TextField),
          ),
          'https://other.example.test/v1',
        );
        await t.pumpAndSettle();
        // Said at once, not after a Save attempt; no "leave blank" promise.
        expect(find.text(tied), findsOneWidget);
        expect(find.text(kept), findsNothing);
        expect(form.reentryBlocked, true);
        await t.enterText(
          find.descendant(
            of: _key('runtime-apiKey'),
            matching: find.byType(TextField),
          ),
          'sk-new',
        );
        await t.pumpAndSettle();
        expect(find.text(tied), findsNothing);
        expect(form.reentryBlocked, false);
        expect(form.validate(), isEmpty);
      },
    );

    testWidgets('a same address with a trailing slash does not ask again', (
      t,
    ) async {
      await show(t);
      await t.enterText(
        find.descendant(
          of: _key('runtime-baseUrl'),
          matching: find.byType(TextField),
        ),
        'https://gateway.example.test/v1/',
      );
      await t.pumpAndSettle();
      expect(form.reentryBlocked, false);
      expect(find.text(tied), findsNothing);
    });

    testWidgets('Save stays disabled while a new key is required', (t) async {
      t.view.physicalSize = const Size(900, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RuntimeFormDialog(
                controller: w,
                machineId: 'mbp',
                runtimeId: 'builtin',
                agentId: 'a1',
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      Finder save() => find.widgetWithText(RaftAgentDialogButton, 'Save');
      bool saveEnabled() =>
          t.widget<RaftAgentDialogButton>(save()).onPressed != null;
      expect(saveEnabled(), true);
      await t.enterText(
        find.descendant(
          of: _key('runtime-baseUrl'),
          matching: find.byType(TextField),
        ),
        'https://other.example.test/v1',
      );
      await t.pumpAndSettle();
      expect(saveEnabled(), false);
      await t.enterText(
        find.descendant(
          of: _key('runtime-apiKey'),
          matching: find.byType(TextField),
        ),
        'sk-new',
      );
      await t.pumpAndSettle();
      expect(saveEnabled(), true);
    });
  });
}
