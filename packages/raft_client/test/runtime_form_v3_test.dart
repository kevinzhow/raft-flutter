// Runtime form protocol v3 and the v1.24 option-source states.
//
// Source: raft-source packages/runtime-form (src/v2.ts, v2State.ts, v3Rules.ts,
// v2State.test.ts, v3State.test.ts, contract.test.ts) at tag
// v1.24.0-source.1 (public source mirror). The fixtures are copied unchanged
// to test/fixtures/runtime_form/.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

Directory fixtureDir() => Directory(
  [
    'test/fixtures/runtime_form',
    'packages/raft_client/test/fixtures/runtime_form',
    '../../packages/raft_client/test/fixtures/runtime_form',
  ].firstWhere((path) => Directory(path).existsSync()),
);

Map<String, dynamic> fixture(String name) => Map<String, dynamic>.from(
  jsonDecode(File('${fixtureDir().path}/$name').readAsStringSync()) as Map,
);

Map<String, Map<String, dynamic>> sourcesOf(Map<String, String> files) => {
  for (final e in files.entries) e.key: fixture(e.value),
};

Map<String, dynamic> deep(Object value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

RuntimeField field(RuntimeForm form, String key) =>
    form.fields.firstWhere((f) => f.key == key);

// A v3 form shaped like the server's Built-in and Codex output: a provider
// select with saved connections, owned fields hidden by rule, a model and a
// reasoning effort dependent_select keyed by model.
Map<String, dynamic> v3Json() => deep({
  'protocolVersion': 3,
  'runtimeId': 'example',
  'schemaVersion': 'example.create.v1',
  'revision': 'rev-3',
  'dataSchema': {
    'type': 'object',
    'required': ['providerId', 'model'],
    'properties': {
      'providerId': {
        'type': 'string',
        'title': 'Provider',
        'x-optionSource': 'provider',
      },
      'apiKey': {'type': 'string', 'title': 'API key', 'writeOnly': true},
      'baseUrl': {'type': 'string', 'title': 'Base URL', 'format': 'uri'},
      'contextWindow': {'type': 'string', 'title': 'Context window'},
      'model': {'type': 'string', 'title': 'Model', 'x-optionSource': 'model'},
      'reasoningEffort': {
        'type': 'string',
        'title': 'Reasoning',
        'x-optionSource': 'reasoningEffort',
      },
    },
    'allOf': [
      {
        'if': {
          'properties': {
            'providerId': {'pattern': '^connection:'},
          },
        },
        'else': {
          'required': ['apiKey'],
        },
      },
    ],
  },
  'uiSchema': {
    'order': [
      'providerId',
      'apiKey',
      'baseUrl',
      'contextWindow',
      'model',
      'reasoningEffort',
    ],
    'rules': [
      {
        'scope': '#/properties/apiKey',
        'effect': 'HIDE',
        'condition': {
          'scope': '#/properties/providerId',
          'schema': {'pattern': '^connection:'},
        },
      },
      {
        'scope': '#/properties/baseUrl',
        'effect': 'SHOW',
        'condition': {
          'scope': '#/properties/providerId',
          'schema': {
            'enum': ['gateway'],
          },
        },
      },
      {
        'scope': '#/properties/contextWindow',
        'effect': 'SHOW',
        'condition': {
          'scope': '#/properties/providerId',
          'schema': {
            'enum': ['gateway', 'connection:gw'],
          },
        },
      },
    ],
  },
  'optionSources': {
    'provider': {
      'sourceId': 'provider',
      'kind': 'select',
      'pointer': '/providerId',
    },
    'model': {'sourceId': 'model', 'kind': 'select', 'pointer': '/model'},
    'reasoningEffort': {
      'sourceId': 'reasoningEffort',
      'kind': 'dependent_select',
      'pointer': '/reasoningEffort',
      'dependsOn': '/model',
    },
  },
});

Map<String, Map<String, dynamic>> v3Sources({
  Map<String, Map<String, dynamic>> overrides = const {},
}) => {
  ...deep({
    'provider': {
      'sourceId': 'provider',
      'kind': 'select',
      'pointer': '/providerId',
      'options': [
        {
          'value': 'connection:ok',
          'label': 'DeepSeek · Team',
          'connectionId': 'ok',
          'underlyingProviderId': 'deepseek',
          'group': 'saved',
        },
        {
          'value': 'connection:gw',
          'label': 'Gateway · Team',
          'connectionId': 'gw',
          'underlyingProviderId': 'gateway',
          'group': 'saved',
        },
        {'value': 'deepseek', 'label': 'DeepSeek', 'group': 'direct'},
        {'value': 'gateway', 'label': 'Gateway', 'group': 'direct'},
      ],
      'defaultValue': 'deepseek',
      'unavailableOptions': [
        {
          'value': 'connection:off',
          'label': 'DeepSeek · Old',
          'reason': 'This saved provider is disabled.',
          'connectionId': 'off',
          'group': 'saved',
        },
      ],
    },
    'model': {
      'sourceId': 'model',
      'kind': 'select',
      'pointer': '/model',
      'options': [
        {'value': 'm-effort', 'label': 'With effort'},
        {'value': 'm-plain', 'label': 'No effort'},
      ],
      'defaultValue': 'm-effort',
      'customValueAllowed': true,
      'unavailableOptions': [
        {'value': 'm-disabled', 'label': 'Disabled model'},
      ],
    },
    'reasoningEffort': {
      'sourceId': 'reasoningEffort',
      'kind': 'dependent_select',
      'pointer': '/reasoningEffort',
      'dependsOn': '/model',
      'optionsByValue': {
        'm-effort': [
          {'value': '', 'label': 'Default'},
          {'value': 'low', 'label': 'low'},
          {'value': 'high', 'label': 'high'},
        ],
      },
      'defaultValueByValue': {'m-effort': 'high'},
    },
  }).map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map))),
  ...overrides,
};

class _Wire implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    requests.add(o);
    return ResponseBody.fromString(
      jsonEncode(
        o.path == '/auth/login'
            ? {
                'accessToken': 'fixture-only',
                'refreshToken': 'fixture-only',
                'user': {'id': 'alice'},
              }
            : {'ok': true},
      ),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('advertised capabilities', () {
    test('are exactly what Web advertises', () {
      expect(
        runtimeFormClientCapabilitiesParam,
        'dependent_select.custom_value_with_options,runtime_form.v3',
      );
    });

    test('definition, edit-form, option-source and create/save requests carry them; nothing else does', () async {
      final wire = _Wire();
      final client = RaftClient(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = wire,
      );
      await client.login('a', 'b');
      client.selectServer('s1');
      const base = '/servers/s1/machines/m1/runtime-forms/v2/codex';
      await client.get(base);
      await client.get('/agents/a1/runtime-form');
      await client.get(
        '$base/option-sources/model',
        query: {'refresh': 1, 'formRevision': 'r'},
      );
      await client.post(
        '/agents',
        data: {
          'name': 'x',
          'formDefinitionRef': {'protocolVersion': 3, 'runtimeId': 'codex'},
        },
      );
      await client.patch(
        '/agents/a1',
        data: {
          'formDefinitionRef': {'protocolVersion': 2, 'runtimeId': 'codex'},
        },
      );
      // Not runtime-form requests.
      await client.post('/agents', data: {'name': 'no form'});
      await client.patch('/agents/a1', data: {'name': 'renamed'});
      await client.get('/agents/a1');
      await client.get('/servers/s1/machines');

      String? caps(String method, String path, [int nth = 0]) =>
          wire.requests
                  .where((r) => r.method == method && r.path == path)
                  .elementAt(nth)
                  .queryParameters['clientCapabilities']
              as String?;
      const want = 'dependent_select.custom_value_with_options,runtime_form.v3';
      expect(caps('GET', base), want);
      expect(caps('GET', '/agents/a1/runtime-form'), want);
      expect(caps('GET', '$base/option-sources/model'), want);
      expect(
        wire.requests
            .firstWhere((r) => r.path.endsWith('option-sources/model'))
            .queryParameters,
        {'refresh': 1, 'formRevision': 'r', 'clientCapabilities': want},
      );
      expect(caps('POST', '/agents', 0), want);
      expect(caps('PATCH', '/agents/a1', 0), want);
      expect(caps('POST', '/agents', 1), isNull);
      expect(caps('PATCH', '/agents/a1', 1), isNull);
      expect(caps('GET', '/agents/a1'), isNull);
      expect(caps('GET', '/servers/s1/machines'), isNull);
      await client.dispose();
    });
  });

  group('protocol v3 parse', () {
    test(
      'protocolVersion 2 and 3 parse and echo; anything else is not a form',
      () {
        expect(RuntimeForm.parse(v3Json())!.protocolVersion, 3);
        expect(
          RuntimeForm.parse({...v3Json(), 'protocolVersion': 2})!
              .protocolVersion,
          2,
        );
        expect(RuntimeForm.parse({...v3Json(), 'protocolVersion': 4}), isNull);
        expect(RuntimeForm.parse({...v3Json(), 'protocolVersion': 1}), isNull);
      },
    );

    test(
      'rules and conditional required land on the fields; no capabilities',
      () {
        final form = RuntimeForm.parse(v3Json())!;
        expect(form.supported, isTrue);
        expect(form.revision, 'rev-3');
        expect(form.capabilities, isEmpty);
        final apiKey = field(form, 'apiKey');
        expect(apiKey.rule!.show, isFalse);
        expect(apiKey.rule!.condition.key, 'providerId');
        expect(apiKey.requiredWhen, hasLength(1));
        expect(apiKey.requiredWhen.single.when, isFalse);
        expect(apiKey.required, isFalse);
        expect(field(form, 'reasoningEffort').kind, 'dependent_select');
        expect(field(form, 'reasoningEffort').parent, 'model');
      },
    );

    test(
      'an unknown effect, scope or keyword makes the whole form unavailable',
      () {
        final mutations = <void Function(Map<String, dynamic>)>[
          (j) => j['uiSchema']['rules'][0]['effect'] = 'DISABLE',
          (j) => j['uiSchema']['rules'][0]['condition']['schema'] = {
            'minLength': 1,
          },
          (j) => j['uiSchema']['rules'][0]['scope'] = '#/properties/a/b',
          (j) =>
              (j['uiSchema']['rules'] as List).add(j['uiSchema']['rules'][0]),
          (j) => j['dataSchema']['allOf'][0]['if'] = {'type': 'string'},
        ];
        for (final mutate in mutations) {
          final json = v3Json();
          mutate(json);
          final form = RuntimeForm.parse(json)!;
          expect(form.capabilities, [RuntimeForm.unsupportedRuleMarker]);
          expect(form.supported, isFalse);
          expect(form.validate(v3Sources(), {}), {
            'form': 'unsupported_capabilities',
          });
        }
        // A v2 body never reads rules: they are ignored there, as any unknown key.
        final v2 = {...v3Json(), 'protocolVersion': 2};
        v2['uiSchema']['rules'][0]['condition']['schema'] = {'minLength': 1};
        expect(RuntimeForm.parse(v2)!.capabilities, isEmpty);
      },
    );

    test('every released v3 form fixture parses as protocol 3 with nothing unsupported', () {
      const forms = [
        'builtin.form.v3.json',
        'builtin.form.saved-connections.v3.json',
        'builtin.edit.connection-unavailable.v3.json',
        'codex.form.v3.json',
        'codex.edit.v3.json',
        'grok.form.v3.json',
        'claude.form.v3.json',
        'claude.edit.v3.json',
        'copilot.edit.v3.json',
        'kimi-sdk.form.v3.json',
        'kimi-sdk.edit.v3.json',
        'pi.form.v3.json',
        'pi.edit.v3.json',
        'antigravity.edit.v3.json',
      ];
      for (final name in forms) {
        final form = RuntimeForm.parse(fixture(name));
        expect(form, isNotNull, reason: name);
        expect(form!.protocolVersion, 3, reason: name);
        expect(form.supported, isTrue, reason: name);
        expect(form.capabilities, isEmpty, reason: name);
        expect(
          form.fields.where((f) => f.kind == 'unsupported' && f.required),
          isEmpty,
          reason: name,
        );
        expect(
          form.fields.where((f) => f.kind == 'derived_select'),
          isEmpty,
          reason: '$name: no derived_select on v3',
        );
      }
    });

    test('every v2 fixture still parses', () {
      for (final f in fixtureDir().listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        if (!name.contains('.form.') && !name.contains('.edit.')) continue;
        if (name.contains('v3')) continue;
        final raw = fixture(name);
        if (raw['protocolVersion'] != 2) continue;
        expect(RuntimeForm.parse(raw), isNotNull, reason: name);
      }
    });

    test("v3 effort sources list the server's Default first", () {
      for (final name in [
        'codex.option-source.reasoning-effort.v3.json',
        'claude.option-source.reasoning-effort.v3.json',
        'kimi-sdk.option-source.reasoning-effort.v3.json',
        'pi.option-source.reasoning-effort.v3.json',
        'pi.option-source.provider-reasoning-effort.v3.json',
        'antigravity.option-source.reasoning-effort.v3.json',
      ]) {
        final body = fixture(name);
        for (final options in (body['optionsByValue'] as Map).values) {
          expect((options as List).first, {'value': '', 'label': 'Default'});
        }
      }
    });
  });

  group('protocol v3 state', () {
    final form = RuntimeForm.parse(v3Json())!;

    test("the server's Default option comes first, the model's default is preselected, a model change re-defaults", () {
      final src = v3Sources();
      final values = form.initial(src);
      expect(values['reasoningEffort'], 'high');
      final choices = form.choices(field(form, 'reasoningEffort'), src, values);
      expect(
        [
          for (final c in choices) [c['value'], c['label']],
        ],
        [
          ['', 'Default'],
          ['low', 'low'],
          ['high', 'high'],
        ],
      );
      final defaulted = {...values, 'reasoningEffort': '', 'apiKey': 'sk'};
      expect(form.validate(src, defaulted), isEmpty);
      expect(form.submission(defaulted, src)['reasoningEffort'], '');
    });

    test("edit: a stored null or absent effort stays Default; create and a model change take the model's default", () {
      final effortList = [
        {'value': '', 'label': 'Default'},
        {'value': 'low', 'label': 'low'},
        {'value': 'high', 'label': 'high'},
      ];
      final src = v3Sources(
        overrides: {
          'reasoningEffort': deep({
            'sourceId': 'reasoningEffort',
            'kind': 'dependent_select',
            'pointer': '/reasoningEffort',
            'dependsOn': '/model',
            'optionsByValue': {'m-effort': effortList, 'm-other': effortList},
            'defaultValueByValue': {'m-effort': 'high', 'm-other': 'low'},
          }),
        },
      );
      expect(form.initial(src)['reasoningEffort'], 'high');
      for (final storedEffort in [
        <String, dynamic>{'reasoningEffort': null},
        <String, dynamic>{},
      ]) {
        final edit = RuntimeForm.parse({
          ...v3Json(),
          'values': {
            'providerId': 'deepseek',
            'model': 'm-effort',
            ...storedEffort,
          },
        })!;
        final values = edit.initial(src);
        expect(
          values['reasoningEffort'],
          '',
          reason: 'Default, not the model default',
        );
        expect(
          edit.visible(field(edit, 'reasoningEffort'), values, src),
          isTrue,
        );
        expect(edit.validate(src, values, editing: true), isEmpty);
        expect(
          edit.submission(values, src)['reasoningEffort'],
          '',
          reason: 'saved untouched: still Default',
        );
        expect(
          edit.change(src, values, 'model', 'm-other')['reasoningEffort'],
          'low',
          reason: "a model change takes the new model's default",
        );
      }
      final explicit = RuntimeForm.parse({
        ...v3Json(),
        'values': {
          'providerId': 'deepseek',
          'model': 'm-effort',
          'reasoningEffort': 'low',
        },
      })!;
      expect(explicit.initial(src)['reasoningEffort'], 'low');
      // A branch the saved agent is not on (no stored model): starts as on create.
      final offBranch = RuntimeForm.parse({
        ...v3Json(),
        'values': {'providerId': 'deepseek'},
      })!;
      expect(
        offBranch.initial(src)['reasoningEffort'],
        form.initial(src)['reasoningEffort'],
      );
    });

    test('a model with no key hides the optional effort and keeps its value (edit submits the stored one)', () {
      final src = v3Sources();
      final edit = RuntimeForm.parse({
        ...v3Json(),
        'values': {
          'providerId': 'deepseek',
          'model': 'my/typed',
          'reasoningEffort': 'high',
        },
      })!;
      final values = edit.initial(src);
      expect(values['reasoningEffort'], 'high');
      expect(
        edit.visible(field(edit, 'reasoningEffort'), values, src),
        isFalse,
      );
      expect(edit.validate(src, values, editing: true), isEmpty);
      expect(edit.submission(values, src)['reasoningEffort'], 'high');
      // On create there is no stored value: the field is left out.
      final created = form.change(
        src,
        {...form.initial(src), 'apiKey': 'sk'},
        'model',
        'm-plain',
      );
      expect(
        form.visible(field(form, 'reasoningEffort'), created, src),
        isFalse,
      );
      expect(
        form.submission(created, src).containsKey('reasoningEffort'),
        isFalse,
      );
      expect(form.validate(src, created), isEmpty);
    });

    test('a connection hides the owned fields, lifts their required rule, and they are not submitted', () {
      final src = v3Sources();
      final direct = {...form.initial(src), 'apiKey': ''};
      expect(form.isRequired(field(form, 'apiKey'), direct), isTrue);
      expect(form.validate(src, direct), {'apiKey': 'required'});
      final viaConnection = form.change(
        src,
        {...direct, 'apiKey': 'sk-direct'},
        'providerId',
        'connection:ok',
      );
      expect(form.visible(field(form, 'apiKey'), viaConnection, src), isFalse);
      expect(form.isRequired(field(form, 'apiKey'), viaConnection), isFalse);
      expect(form.validate(src, viaConnection), isEmpty);
      final body = form.submission(viaConnection, src);
      expect(body.containsKey('apiKey'), isFalse);
      expect(body.containsKey('baseUrl'), isFalse);
      expect(body['providerId'], 'connection:ok');
    });

    test('a gateway connection listed in the SHOW condition keeps the limit fields; others hide them', () {
      final src = v3Sources();
      final base = form.initial(src);
      bool shown(String key, String provider) => form.visible(
        field(form, key),
        {...base, 'providerId': provider},
        src,
      );
      expect(shown('contextWindow', 'connection:gw'), isTrue);
      expect(shown('baseUrl', 'connection:gw'), isFalse);
      expect(shown('contextWindow', 'connection:ok'), isFalse);
      expect(shown('contextWindow', 'gateway'), isTrue);
    });

    test('a value equal to an unavailableOptions entry blocks (option_unavailable), except on a typed-values source', () {
      final src = v3Sources();
      final edit = RuntimeForm.parse({
        ...v3Json(),
        'values': {'providerId': 'connection:off', 'model': 'm-disabled'},
      })!;
      final values = edit.initial(src);
      expect(values['providerId'], 'connection:off', reason: 'binding kept');
      expect(
        edit.unavailableSelection(
          field(edit, 'providerId'),
          src,
          values,
        )!['reason'],
        'This saved provider is disabled.',
      );
      expect(edit.validate(src, values, editing: true), {
        'providerId': 'option_unavailable',
      });
      // The model source takes typed values: a stored disabled model is accepted as typed.
      final direct = {...values, 'providerId': 'deepseek', 'apiKey': 'sk'};
      expect(edit.validate(src, direct, editing: true), isEmpty);
      // Without customValueAllowed the same model blocks.
      final strict = v3Sources(
        overrides: {
          'model': {...src['model']!, 'customValueAllowed': false},
        },
      );
      expect(edit.validate(strict, direct, editing: true), {
        'model': 'option_unavailable',
      });
    });

    test('the unavailable-connection fixture keeps the binding and blocks the save', () {
      final edit = RuntimeForm.parse(
        fixture('builtin.edit.connection-unavailable.v3.json'),
      )!;
      final src = sourcesOf({
        'provider': 'builtin.option-source.provider.saved-connections.v3.json',
      });
      final values = edit.initial(src);
      final binding = edit.stored['providerId'];
      expect(values['providerId'], binding);
      expect(edit.validate(src, values, editing: true), isNotEmpty);
    });
  });

  group('option source states', () {
    final codex = RuntimeForm.parse(fixture('codex.form.json'))!;

    test(
      'a stale list is a usable fallback that names when it was fetched',
      () {
        final fallback = sourcesOf({
          'model': 'codex.option-source.fallback.json',
        });
        expect(
          codex.sourceStatus(field(codex, 'model'), fallback)!.stale,
          isFalse,
        );
        final stale = {
          'model': {
            ...fallback['model']!,
            'reason': 'probe_timeout',
            'retryable': true,
            'state': 'stale',
            'fetchedAt': '2026-10-21T08:00:00.000Z',
          },
        };
        final status = codex.sourceStatus(field(codex, 'model'), stale)!;
        expect(status.status, 'fallback');
        expect(status.reason, 'probe_timeout');
        expect(status.retryable, isTrue);
        expect(status.stale, isTrue);
        expect(status.fetchedAt, '2026-10-21T08:00:00.000Z');
        expect(codex.validate(stale, codex.initial(stale)), isEmpty);
        // Any other state, an unknown one included, adds nothing.
        for (final state in ['ok', 'unavailable', 'brand_new_state']) {
          final other = {
            'model': {...stale['model']!, 'state': state},
          };
          expect(
            codex.sourceStatus(field(codex, 'model'), other)!.stale,
            isFalse,
          );
        }
        // A live source and an unknown status say nothing.
        final live = sourcesOf({'model': 'codex.option-source.live.json'});
        expect(codex.sourceStatus(field(codex, 'model'), live), isNull);
        final odd = {
          'model': {...stale['model']!, 'status': 'degraded'},
        };
        expect(codex.sourceStatus(field(codex, 'model'), odd), isNull);
      },
    );

    test('unavailableOptions are listed apart and never in the choices', () {
      final form = RuntimeForm.parse(fixture('codex.form.json'))!;
      final src = {
        'model': {
          ...sourcesOf({'model': 'codex.option-source.live.json'})['model']!,
          'unavailableOptions': [
            {
              'value': 'gpt-old',
              'label': 'GPT Old',
              'reason': 'Not installed here.',
            },
            {'value': '', 'label': 'blank'},
          ],
        },
      };
      final model = field(form, 'model');
      expect(
        [for (final o in form.unavailableOptions(model, src)) o['value']],
        ['gpt-old'],
      );
      expect(
        form
            .choices(model, src, form.initial(src))
            .any((o) => o['value'] == 'gpt-old'),
        isFalse,
      );
    });
  });

  group('typed value beside the list', () {
    test('dependent_select with listed options and a typed value is a combobox that keeps its default; no options is free text', () {
      final form = RuntimeForm.parse(fixture('builtin.form.v3.json'))!;
      final model = field(form, 'model');
      final src = deep({
        'provider': {
          'sourceId': 'provider',
          'kind': 'select',
          'pointer': '/providerId',
          'options': [
            {'value': 'openrouter', 'label': 'OpenRouter'},
            {'value': 'openai-compatible', 'label': 'OpenAI-compatible'},
          ],
          'defaultValue': 'openrouter',
        },
        'model': {
          'sourceId': 'model',
          'kind': 'dependent_select',
          'pointer': '/model',
          'dependsOn': '/providerId',
          'optionsByValue': {
            'openrouter': [
              {'value': 'openrouter/vendor/listed', 'label': 'Listed'},
              {'value': 'openrouter/vendor/other', 'label': 'Other'},
            ],
            'openai-compatible': [],
          },
          'defaultValueByValue': {'openrouter': 'openrouter/vendor/listed'},
          'customValueAllowedByValue': {
            'openrouter': true,
            'openai-compatible': true,
          },
        },
      }).map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
      final values = form.initial(src);
      expect(values['providerId'], 'openrouter');
      expect(
        values['model'],
        'openrouter/vendor/listed',
        reason: 'listed default kept',
      );
      expect(form.custom(model, src, values), isTrue);
      expect(form.freeText(model, src, values), isFalse);
      expect(form.choices(model, src, values), hasLength(2));
      expect(
        form.validate(src, {...values, 'model': 'vendor/typed'})['model'],
        isNull,
        reason: 'a typed id is valid',
      );
      final gateway = form.change(
        src,
        values,
        'providerId',
        'openai-compatible',
      );
      expect(form.freeText(model, src, gateway), isTrue);
      expect(gateway['model'], '');
    });
  });

  group('advanced disclosure', () {
    test(
      'starts open when any visible advanced field has a non-blank value',
      () {
        final builtin = RuntimeForm.parse(fixture('builtin.form.json'))!;
        final edit = RuntimeForm.parse(fixture('builtin.edit.json'))!;
        final gateway = {
          'providerId': 'openai-compatible',
          'contextWindow': '',
          'maxOutputTokens': '',
          'envVars': <String, String>{},
          'loadLocalPlugins': false,
        };
        expect(builtin.advancedStartsOpen(gateway), isFalse);
        expect(
          builtin.advancedStartsOpen({...gateway, 'contextWindow': '  '}),
          isFalse,
        );
        expect(
          builtin.advancedStartsOpen({...gateway, 'contextWindow': '128000'}),
          isTrue,
        );
        expect(
          builtin.advancedStartsOpen({
            ...gateway,
            'envVars': {'A': '1'},
          }),
          isTrue,
        );
        expect(
          builtin.advancedStartsOpen({...gateway, 'loadLocalPlugins': true}),
          isTrue,
        );
        expect(
          builtin.advancedStartsOpen({
            ...gateway,
            'providerId': 'anthropic',
            'maxOutputTokens': '8192',
          }),
          isFalse,
          reason: 'hidden field',
        );
        expect(edit.advancedStartsOpen(edit.initial({})), isTrue);
        expect(builtin.advancedStartsOpen({...gateway, 'model': 'm'}), isFalse);
      },
    );
  });
}
