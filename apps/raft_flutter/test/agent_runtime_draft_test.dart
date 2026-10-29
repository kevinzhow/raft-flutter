import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/runtime_error.dart';
import 'package:raft_flutter/features/agent_runtime_catalog.dart';
import 'package:raft_flutter/features/agent_runtime_draft.dart';

RuntimeModelInfo _m(
  String id, {
  List<String>? efforts,
  String? def,
  String? verified,
}) => RuntimeModelInfo(
  id: id,
  label: id.toUpperCase(),
  supportedReasoningEfforts: efforts,
  defaultReasoningEffort: def,
  verified: verified,
);

void main() {
  group('hydrate and build', () {
    test('legacy columns fill the draft', () {
      final d = RuntimeDraft.hydrate({
        'runtime': 'codex',
        'model': 'gpt-5-codex',
        'reasoningEffort': 'medium',
        'envVars': {'A': '1'},
      });
      expect(d.runtime, 'codex');
      expect(d.model, 'gpt-5-codex');
      expect(d.reasoning, 'medium');
      expect(d.fastMode, isFalse);
      expect(d.envVarMap, {'A': '1'});
    });

    test('fast mode only comes from runtimeConfig.mode, not a flat flag', () {
      expect(
        RuntimeDraft.hydrate({
          'runtime': 'codex',
          'model': 'gpt-5-codex',
          'fastMode': true,
        }).fastMode,
        isFalse,
      );
      expect(
        RuntimeDraft.hydrate({
          'runtime': 'codex',
          'model': 'gpt-5-codex',
          'runtimeConfig': {
            'version': 1,
            'runtime': 'codex',
            'model': {'kind': 'preset', 'id': 'gpt-5-codex'},
            'mode': {'kind': 'fast'},
          },
        }).fastMode,
        isTrue,
      );
    });

    test('a structured runtimeConfig wins', () {
      final d = RuntimeDraft.hydrate({
        'runtime': 'claude',
        'model': 'old',
        'runtimeConfig': {
          'version': 1,
          'runtime': 'claude',
          'model': {'kind': 'custom', 'name': 'my-model'},
          'provider': {
            'kind': 'custom',
            'apiUrl': 'https://x.test',
            'apiKey': 'sk-1',
          },
          'mode': {'kind': 'fast'},
          'command': ' claude-dev ',
          'reasoningEffort': 'high',
          'envVars': {'K': 'v'},
        },
      });
      expect(d.customModelMode, isTrue);
      expect(d.model, 'my-model');
      expect(d.providerCustom, isTrue);
      expect(d.providerApiUrl, 'https://x.test');
      expect(d.command, 'claude-dev');
      expect(d.fastMode, isTrue);
      expect(d.reasoning, 'high');
    });

    test('buildRuntimeConfig follows the runtime capabilities', () {
      final codex = RuntimeDraft(
        runtime: 'codex',
        model: 'gpt-5-codex',
        fastMode: true,
        reasoning: 'high',
        envVars: [const MapEntry(' A ', '1'), const MapEntry('', 'x')],
      ).buildRuntimeConfig();
      expect(codex, {
        'version': runtimeConfigVersion,
        'runtime': 'codex',
        'model': {'kind': 'preset', 'id': 'gpt-5-codex'},
        'mode': {'kind': 'fast'},
        'reasoningEffort': 'high',
        'envVars': {'A': '1'},
      });
      final claude = RuntimeDraft(
        runtime: 'claude',
        model: 'my',
        customModelMode: true,
        providerCustom: true,
        providerApiUrl: ' https://gw.test ',
        providerApiKey: ' k ',
        command: ' c ',
        fastMode: true,
      ).buildRuntimeConfig();
      expect(claude['provider'], {
        'kind': 'custom',
        'apiUrl': 'https://gw.test',
        'apiKey': 'k',
      });
      expect(claude['model'], {'kind': 'custom', 'name': 'my'});
      expect(claude['command'], 'c');
      expect(claude['envVars'], isNull);
      // Fast mode is a Claude / Codex capability only.
      final cursor = RuntimeDraft(
        runtime: 'cursor',
        model: 'auto',
        fastMode: true,
        reasoning: 'high',
      ).buildRuntimeConfig();
      expect(cursor['mode'], {'kind': 'default'});
      expect(cursor['reasoningEffort'], isNull);
      expect(cursor.containsKey('provider'), isFalse);
      expect(cursor.containsKey('command'), isFalse);
    });

    test('changed compares every edited field', () {
      final base = RuntimeDraft(runtime: 'claude', model: 'opus');
      expect(base.copy().changedFrom(base), isFalse);
      for (final edit in <void Function(RuntimeDraft)>[
        (d) => d.model = 'sonnet',
        (d) => d.customModelMode = true,
        (d) => d.providerCustom = true,
        (d) => d.providerApiUrl = 'https://a.test',
        (d) => d.fastMode = true,
        (d) => d.command = 'x',
        (d) => d.reasoning = 'low',
        (d) => d.envVars = [const MapEntry('A', '1')],
        (d) => d.runtime = 'codex',
      ]) {
        final d = base.copy();
        edit(d);
        expect(d.changedFrom(base), isTrue);
      }
    });

    test('validity of the custom provider and custom model', () {
      final d = RuntimeDraft(
        runtime: 'claude',
        model: '',
        providerCustom: true,
        customModelMode: true,
      );
      expect(d.apiUrlInvalid, isTrue);
      expect(d.apiKeyInvalid, isTrue);
      expect(d.customModelInvalid, isTrue);
      d
        ..providerApiUrl = 'https://x.test'
        ..providerApiKey = 'k'
        ..model = 'm';
      expect(d.apiUrlInvalid, isFalse);
      expect(d.apiKeyInvalid, isFalse);
      expect(d.customModelInvalid, isFalse);
      // A URL typed under the default provider still has to be a URL.
      final other = RuntimeDraft(
        runtime: 'claude',
        model: 'opus',
        providerApiUrl: 'ftp://x',
      );
      expect(other.apiUrlInvalid, isTrue);
    });
  });

  group('model sources', () {
    test('parses typed outcomes and the old payload', () {
      expect(parseRuntimeModelSourcePayload(null), isA<RuntimeModelError>());
      final live = parseRuntimeModelSourcePayload({
        'kind': 'live',
        'value': {
          'models': [
            {'id': 'a', 'label': 'A', 'verified': 'launchable'},
          ],
          'default': 'a',
        },
      });
      expect(live, isA<RuntimeModelLive>());
      expect((live as RuntimeModelLive).models.single.id, 'a');
      expect(
        parseRuntimeModelSourcePayload({
          'kind': 'live',
          'value': {'models': []},
        }),
        isA<RuntimeModelNonLive>().having((s) => s.kind, 'kind', 'no_models'),
      );
      expect(
        parseRuntimeModelSourcePayload({
          'kind': 'missing_config',
          'recovery': 'kimi_login',
        }),
        isA<RuntimeModelNonLive>().having(
          (s) => s.recovery,
          'recovery',
          'kimi_login',
        ),
      );
      expect(
        parseRuntimeModelSourcePayload({'kind': 'unsupported'}),
        isA<RuntimeModelNonLive>().having((s) => s.kind, 'kind', 'unsupported'),
      );
      final error = parseRuntimeModelSourcePayload({
        'kind': 'error',
        'code': 'detect_timeout',
        'retryable': false,
      }) as RuntimeModelError;
      expect(error.code, 'detect_timeout');
      expect(error.retryable, isFalse);
      expect(
        (parseRuntimeModelSourcePayload({
          'kind': 'error',
          'code': 'bogus',
        }) as RuntimeModelError).code,
        isNull,
      );
      expect(
        parseRuntimeModelSourcePayload({
          'models': [
            {'id': 'x', 'label': 'X'},
          ],
        }),
        isA<RuntimeModelLive>(),
      );
    });

    test('runtime_not_found carries how the lookup ended; unknown is dropped', () {
      RuntimeModelError parse(Map<String, dynamic> extra) =>
          parseRuntimeModelSourcePayload({
            'kind': 'error',
            'code': 'runtime_not_found',
            ...extra,
          }) as RuntimeModelError;
      for (final reason in [
        'not_installed',
        'probe_timeout',
        'permission_denied',
        'probe_failed',
      ]) {
        expect(parse({'reason': reason}).reason, reason);
      }
      // An old daemon sends none; a value this client does not know is dropped.
      expect(parse({}).reason, isNull);
      expect(parse({'reason': 'cosmic_rays'}).reason, isNull);
      expect(parse({'reason': 7}).reason, isNull);
    });

    test('only a confirmed miss says install it', () {
      RuntimeLookupDisplay of(String? reason) =>
          runtimeLookupDisplayForReason(reason);
      expect(of('not_installed'), RuntimeLookupDisplay.confirmedMissing);
      expect(of('not_on_path'), RuntimeLookupDisplay.confirmedMissing);
      expect(of('probe_timeout'), RuntimeLookupDisplay.timeout);
      expect(of('lookup_timed_out'), RuntimeLookupDisplay.timeout);
      expect(of('permission_denied'), RuntimeLookupDisplay.permissionDenied);
      expect(
        of('lookup_permission_denied'),
        RuntimeLookupDisplay.permissionDenied,
      );
      for (final unresolved in ['probe_failed', 'lookup_failed', null, 'x']) {
        expect(of(unresolved), RuntimeLookupDisplay.unconfirmed);
      }
      expect(
        runtimeLookupText(RuntimeLookupDisplay.unconfirmed),
        isNot(contains('Install')),
      );
    });

    test('a failed detection offers the bundled catalog as suggestions', () {
      final options = runtimeModelFallbackOptions(
        'codex',
        const RuntimeModelError(),
      );
      expect(options, isNotEmpty);
      expect(options.every((m) => m.verified == 'suggestion_only'), isTrue);
      expect(
        runtimeModelFallbackOptions('codex', const RuntimeModelLoading()),
        isEmpty,
      );
      expect(
        runtimeModelFallbackOptions('builtin', const RuntimeModelError()),
        isEmpty,
      );
    });

    test('a static catalog stays visible while loading', () {
      final p = projectRuntimeModels(
        'claude',
        runtimeModelLoadingFor('claude'),
      );
      expect(p.models, isNotEmpty);
      expect(p.loading, isTrue);
      expect(p.live, isFalse);
      expect(
        projectRuntimeModels('codex', runtimeModelLoadingFor('codex')).models,
        isEmpty,
      );
    });

    test('Codex live models follow the bundled order', () {
      final bundled = runtimeModelCatalog['codex']!;
      final live = RuntimeModelLive([
        _m('zzz-new'),
        _m(bundled[1].id),
        _m(bundled[0].id),
      ]);
      final ids = [
        for (final m in projectRuntimeModels('codex', live).models) m.id,
      ];
      expect(ids, [bundled[0].id, bundled[1].id, 'zzz-new']);
    });

    test('runnable selection', () {
      const err = RuntimeModelError();
      final bundled = runtimeModelCatalog['codex']!.first.id;
      bool runnable(
        String model,
        RuntimeModelSource s, {
        bool custom = false,
        String? persisted,
      }) => runtimeModelSelectionIsRunnable(
        runtime: 'codex',
        source: s,
        model: model,
        customMode: custom,
        customAllowed: true,
        persistedModel: persisted,
      );
      expect(runnable('', err), isFalse);
      expect(runnable(bundled, err), isTrue);
      expect(runnable('nope', err), isFalse);
      expect(runnable('anything', err, custom: true), isTrue);
      final live = RuntimeModelLive([_m('a')]);
      expect(runnable('a', live), isTrue);
      expect(runnable('b', live), isFalse);
      // A stored model the Computer no longer lists may be kept as is.
      expect(runnable('b', live, persisted: 'b'), isTrue);
      expect(
        runtimeModelSelectionIsRunnable(
          runtime: 'antigravity',
          source: err,
          model: '',
          customMode: false,
          customAllowed: false,
        ),
        isTrue,
      );
    });
  });

  group('reasoning', () {
    test('a model that declares efforts gates the menu', () {
      final live = [
        _m('m1', efforts: ['low', 'medium'], def: 'medium'),
      ];
      expect(
        [for (final o in reasoningOptionsForModel('codex', 'm1', live)) o.$1],
        ['low', 'medium'],
      );
      // No declaration: the base ladder only (no max / ultra).
      expect(
        [
          for (final o in reasoningOptionsForModel(
            'claude',
            'unknown',
            const [],
          ))
            o.$1,
        ],
        ['low', 'medium', 'high', 'xhigh'],
      );
    });

    test('reconcile keeps a valid value, else the model default', () {
      final live = [
        _m('m1', efforts: ['low', 'medium'], def: 'medium'),
      ];
      expect(reconcileReasoningEffort('codex', 'm1', 'low', live), 'low');
      expect(reconcileReasoningEffort('codex', 'm1', 'ultra', live), 'medium');
      expect(reconcileReasoningEffort('codex', 'm1', null, live), 'medium');
      expect(
        reconcileReasoningEffort('claude', 'unknown', 'high', const []),
        'high',
      );
    });
  });

  test('save gate lists every reason', () {
    bool disabled({
      bool saving = false,
      bool changed = true,
      bool canSelect = true,
      bool url = false,
      bool key = false,
      bool custom = false,
      bool source = false,
    }) => runtimeConfigSaveDisabled(
      saving: saving,
      changed: changed,
      runtimeCanSelect: canSelect,
      providerApiUrlInvalid: url,
      providerApiKeyInvalid: key,
      customModelInvalid: custom,
      modelSourceInvalid: source,
    );
    expect(disabled(), isFalse);
    expect(disabled(saving: true), isTrue);
    expect(disabled(changed: false), isTrue);
    expect(disabled(canSelect: false), isTrue);
    expect(disabled(url: true), isTrue);
    expect(disabled(key: true), isTrue);
    expect(disabled(custom: true), isTrue);
    expect(disabled(source: true), isTrue);
  });

  test('runtime availability wording and visible runtimes', () {
    expect(runtimeAvailabilityKind('claude', ['claude']), 'none');
    expect(runtimeAvailabilityKind('claude', []), 'notInstalled');
    expect(runtimeAvailabilityKind('builtin', []), 'updateComputer');
    expect(runtimeAvailabilityKind('mystery', []), 'none');
    final visible = [
      for (final r in existingAgentRuntimeOptions('claude')) r.id,
    ];
    expect(visible, isNot(contains('gemini')));
    expect([
      for (final r in existingAgentRuntimeOptions('gemini')) r.id,
    ], contains('gemini'));
    expect(legacyRuntimeEditorSupports('codex'), isTrue);
    expect(legacyRuntimeEditorSupports('builtin'), isFalse);
    expect(legacyRuntimeEditorSupports('kimi-sdk'), isFalse);
    expect(
      defaultRuntimeModel('codex'),
      runtimeModelCatalog['codex']!.first.id,
    );
    expect(runtimeModelLabel('codex', 'not-a-model'), 'not-a-model');
  });
}
