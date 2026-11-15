import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/runtime_error.dart';
import 'package:raft_flutter/features/agent_runtime_catalog.dart';
import 'package:raft_flutter/features/agent_runtime_models.dart';

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

  test('the default model and label come from the bundled catalog', () {
    expect(
      defaultRuntimeModel('codex'),
      runtimeModelCatalog['codex']!.first.id,
    );
    expect(runtimeModelLabel('codex', 'not-a-model'), 'not-a-model');
  });

  group('reasoning efforts follow Web 1.24', () {
    List<String> ids(
      String runtime,
      String model, [
      List<RuntimeModelInfo>? l,
    ]) => [
      for (final o in reasoningOptionsForModel(runtime, model, l ?? const []))
        o.$1,
    ];

    test('off and minimal are Pi levels only', () {
      expect(isReasoningEffortOfferedOnRuntime('pi', 'off'), isTrue);
      expect(isReasoningEffortOfferedOnRuntime('builtin', 'minimal'), isTrue);
      expect(isReasoningEffortOfferedOnRuntime('claude', 'off'), isFalse);
      expect(isReasoningEffortOfferedOnRuntime('claude', 'high'), isTrue);
      // A model that declares them on another runtime does not offer them.
      expect(
        ids('claude', 'm', [
          _m('m', efforts: ['off', 'minimal', 'low']),
        ]),
        ['low'],
      );
    });

    test('a model that declares none gets the runtime default set', () {
      expect(ids('pi', 'unknown'), [
        'off',
        'minimal',
        'low',
        'medium',
        'high',
        'xhigh',
        'max',
      ]);
      expect(ids('claude', 'unknown'), ['low', 'medium', 'high', 'xhigh']);
    });

    test('Antigravity and CodeBuddy list efforts per model only', () {
      for (final runtime in ['antigravity', 'codebuddy']) {
        expect(runtimeOffersUndeclaredReasoningEfforts(runtime), isFalse);
        expect(ids(runtime, 'unknown'), isEmpty, reason: runtime);
        // The current value is dropped: the model offers no levels.
        expect(
          reconcileReasoningEffort(runtime, 'unknown', 'high', const []),
          isNull,
          reason: runtime,
        );
        expect(
          ids(runtime, 'm', [
            _m('m', efforts: ['low', 'high']),
          ]),
          ['low', 'high'],
        );
      }
      expect(runtimeOffersUndeclaredReasoningEfforts('claude'), isTrue);
    });

    test('the ladder labels follow the shared catalog', () {
      final labels = {for (final e in reasoningEfforts) e.$1: e.$2};
      expect(labels['off'], 'No reasoning');
      expect(labels['xhigh'], 'Extra high');
    });
  });

  group('runtime catalog v1.24', () {
    test('the three OAR-only runtimes are experimental and creatable', () {
      for (final (id, name) in [
        ('qwen', 'Qwen Code'),
        ('qoder', 'Qoder'),
        ('codebuddy', 'CodeBuddy Code'),
      ]) {
        final info = runtimeInfos.firstWhere((r) => r.id == id);
        expect(info.name, name);
        expect(info.experimental, isTrue);
        expect(info.oarOnly, isTrue);
        expect(info.supported && !info.deprecated, isTrue);
      }
      expect(runtimeInfos.where((r) => r.oarOnly).map((r) => r.id).toSet(), {
        'qwen',
        'qoder',
        'codebuddy',
      });
      expect(
        runtimeInfos.firstWhere((r) => r.id == 'claude').experimental,
        isFalse,
      );
    });

    test('Claude Fable 5.2 is bundled', () {
      expect(
        runtimeModelCatalog['claude']!.map((m) => m.id),
        contains('claude-fable-5-2'),
      );
    });
  });

  group('freshness, unavailable models and the catalog capability', () {
    Map<String, dynamic> live({Object? unavailable, Object? catalog}) => {
      'kind': 'live',
      'value': {
        'models': [
          {'id': 'a', 'label': 'A'},
        ],
        'unavailable': ?unavailable,
        'catalog': ?catalog,
      },
    };

    test('freshness is read from the same body; none means ok', () {
      expect(parseRuntimeModelFreshness(live()).state, 'ok');
      expect(parseRuntimeModelFreshness(null).state, 'ok');
      final stale = parseRuntimeModelFreshness({
        ...live(),
        'freshness': {'state': 'stale', 'fetchedAt': '2026-11-16T00:00:00Z'},
      });
      expect(stale.state, 'stale');
      expect(stale.fetchedAt, '2026-11-16T00:00:00Z');
      expect(
        parseRuntimeModelFreshness({
          'freshness': {'state': 'stale', 'fetchedAt': 7},
        }).fetchedAt,
        isNull,
      );
      expect(
        parseRuntimeModelFreshness({
          'freshness': {'state': 'unavailable'},
        }).state,
        'unavailable',
      );
      expect(
        parseRuntimeModelFreshness({
          'freshness': {'state': 'bogus'},
        }).isOk,
        isTrue,
      );
    });

    test('only a fresh live list is shared; a stale one asks again', () {
      RuntimeModelLoad load(Map<String, dynamic> body) =>
          parseRuntimeModelLoad(body);
      expect(runtimeModelLoadReusable(load(live())), isTrue);
      expect(
        runtimeModelLoadReusable(
          load({
            ...live(),
            'freshness': {'state': 'stale'},
          }),
        ),
        isFalse,
      );
      expect(
        runtimeModelLoadReusable(
          load({
            'kind': 'error',
            'freshness': {'state': 'unavailable'},
          }),
        ),
        isFalse,
      );
      expect(runtimeModelLoadReusable(load({'kind': 'no_models'})), isFalse);
    });

    test('unavailable entries are sanitised: bounded, deduplicated, plain', () {
      final long = 'x' * 300;
      final source = parseRuntimeModelSourcePayload(
        live(
          unavailable: [
            {'id': 'b', 'label': ' Model\n  B ', 'reason': long},
            {'id': 'b', 'label': 'dup'},
            {'id': '', 'label': 'empty id'},
            {'id': 'c'},
            'junk',
            {'id': 'd', 'label': '   ', 'reason': 5},
          ],
        ),
      ) as RuntimeModelLive;
      final byId = {for (final m in source.unavailable) m.id: m};
      expect(byId.keys, ['b', 'c', 'd']);
      expect(byId['b']!.label, 'Model B');
      expect(byId['b']!.reason.length, 200);
      expect(byId['b']!.reason.endsWith('\u2026'), isTrue);
      expect(byId['c']!.label, 'c');
      expect(byId['c']!.reason, '');
      expect(byId['d']!.label, 'd');
      // Never part of the usable list.
      expect(source.models.map((m) => m.id), ['a']);
    });

    test('at most 50 unavailable entries are kept', () {
      final source = parseRuntimeModelSourcePayload(
        live(
          unavailable: [
            for (var i = 0; i < 80; i++) {'id': 'm$i', 'label': 'M$i'},
          ],
        ),
      ) as RuntimeModelLive;
      expect(source.unavailable, hasLength(50));
    });

    test('unavailable models without a usable one are no_models', () {
      expect(
        parseRuntimeModelSourcePayload({
          'kind': 'live',
          'value': {
            'models': [],
            'unavailable': [
              {'id': 'x', 'label': 'X'},
            ],
          },
        }),
        isA<RuntimeModelNonLive>().having((s) => s.kind, 'kind', 'no_models'),
      );
    });

    test('the Built-in catalog capability and its custom providers', () {
      final ok = parseRuntimeModelSourcePayload(
        live(
          catalog: {
            'protocolVersion': 1,
            'runtime': 'builtin',
            'runtimeVersion': '1.2.3',
            'customModelProviderIds': ['openrouter', 7],
          },
        ),
      ) as RuntimeModelLive;
      expect(ok.catalog!.runtimeVersion, '1.2.3');
      expect(ok.catalog!.customModelProviderIds, ['openrouter']);
      final older = parseRuntimeModelSourcePayload(
        live(
          catalog: {
            'protocolVersion': 1,
            'runtime': 'builtin',
            'runtimeVersion': '1.0.0',
          },
        ),
      ) as RuntimeModelLive;
      // Absent on older Computers: none.
      expect(older.catalog!.customModelProviderIds, isEmpty);
      for (final bad in [
        {'protocolVersion': 2, 'runtime': 'builtin', 'runtimeVersion': '1'},
        {'protocolVersion': 1, 'runtime': 'pi', 'runtimeVersion': '1'},
        {'protocolVersion': 1, 'runtime': 'builtin', 'runtimeVersion': ' '},
      ]) {
        expect(
          (parseRuntimeModelSourcePayload(
            live(catalog: bad),
          ) as RuntimeModelLive).catalog,
          isNull,
        );
      }
    });
  });
}
