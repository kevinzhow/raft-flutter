import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/runtime_config.dart';

// Fixtures mirror real server payloads: the stored configs of
// packages/server runtimeFormV2 / agents.api tests and the hydration cases of
// packages/shared runtimeConfig.test.ts (the Web `hydrateRuntimeConfigForm`
// this helper ports).
Map<String, dynamic> _codexFast() => {
  'id': 'a1',
  'runtime': 'codex',
  'model': 'gpt-7-live',
  'reasoningEffort': 'ultra',
  'envVars': {'K': 'v'},
  'runtimeConfig': {
    'version': 1,
    'runtime': 'codex',
    'model': {'kind': 'preset', 'id': 'gpt-7-live'},
    'mode': {'kind': 'fast'},
    'reasoningEffort': 'ultra',
    'envVars': {'K': 'v'},
  },
};

void main() {
  group('structured runtimeConfig', () {
    test(
      'mode.kind == fast is fast mode (the saved value the profile shows)',
      () {
        final c = RuntimeConfig.fromAgent(_codexFast());
        expect(c.runtime, 'codex');
        expect(c.fastMode, isTrue);
        expect(c.supportsFastMode, isTrue);
        expect(c.model, 'gpt-7-live');
        expect(c.customModel, isFalse);
        expect(c.reasoningEffort, 'ultra');
        expect(c.envVarMap, {'K': 'v'});
      },
    );

    test('mode.kind == default is not fast mode', () {
      final agent = _codexFast();
      (agent['runtimeConfig'] as Map)['mode'] = {'kind': 'default'};
      expect(RuntimeConfig.fromAgent(agent).fastMode, isFalse);
    });

    test('a custom model is the custom name', () {
      final c = RuntimeConfig.fromAgent({
        'runtime': 'codex',
        'model': 'x',
        'runtimeConfig': {
          'version': 1,
          'runtime': 'codex',
          'model': {'kind': 'custom', 'name': 'my-org/codex-custom'},
          'mode': {'kind': 'fast'},
          'reasoningEffort': 'high',
          'envVars': null,
        },
      });
      expect(c.customModel, isTrue);
      expect(c.model, 'my-org/codex-custom');
      expect(c.envVars, isNull);
    });

    test('the stored runtime wins over the flat column', () {
      final c = RuntimeConfig.fromAgent({
        'runtime': 'claude',
        'runtimeConfig': {
          'version': 1,
          'runtime': 'codex',
          'model': {'kind': 'preset', 'id': 'gpt-5.5'},
          'mode': {'kind': 'fast'},
        },
      });
      expect(c.runtime, 'codex');
      expect(c.fastMode, isTrue);
    });

    test('stored Claude custom provider, command and reasoning', () {
      final c = RuntimeConfig.fromAgent({
        'runtime': 'claude',
        'model': 'sonnet',
        'runtimeConfig': {
          'version': 1,
          'runtime': 'claude',
          'provider': {
            'kind': 'custom',
            'apiUrl': 'https://api.deepseek.com/anthropic',
            'apiKey': 'sk-deepseek-test',
          },
          'model': {'kind': 'custom', 'name': 'deepseek-v4-pro'},
          'mode': {'kind': 'default'},
          'reasoningEffort': null,
          'command': ' claude-p ',
          'envVars': null,
        },
        // Stale launch mirrors never override the stored provider.
        'envVars': {
          'ANTHROPIC_BASE_URL': 'https://stale.example.test/anthropic',
          'ANTHROPIC_API_KEY': 'sk-stale',
          'ANTHROPIC_CUSTOM_MODEL_OPTION': 'stale-model',
        },
      });
      expect(c.customProvider, isTrue);
      expect(c.providerApiUrl, 'https://api.deepseek.com/anthropic');
      expect(c.apiKey, 'sk-deepseek-test');
      expect(c.model, 'deepseek-v4-pro');
      expect(c.command, 'claude-p');
      expect(c.commandText, 'claude-p');
      expect(c.fastMode, isFalse);
      expect(c.reasoningEffort, isNull);
      expect(c.envVars, isNull);
    });

    test('a version other than 1 is not a stored config', () {
      final c = RuntimeConfig.fromAgent({
        'runtime': 'codex',
        'model': 'gpt-5.5',
        'runtimeConfig': {
          'version': 2,
          'runtime': 'claude',
          'model': {'kind': 'preset', 'id': 'opus'},
          'mode': {'kind': 'fast'},
        },
      });
      expect(c.runtime, 'codex');
      expect(c.model, 'gpt-5.5');
      expect(c.fastMode, isFalse);
    });

    test('unknown fields are ignored (read-side sanitising)', () {
      final c = RuntimeConfig.fromAgent({
        'runtimeConfig': {
          'version': 1,
          'runtime': 'codex',
          'surprise': true,
          'model': {'kind': 'preset', 'id': 'gpt-5.5', 'extra': 1},
          'mode': {'kind': 'fast', 'extra': 1},
        },
      });
      expect(c.fastMode, isTrue);
      expect(c.model, 'gpt-5.5');
    });
  });

  group('legacy columns only', () {
    test('flat columns fill the config; the mode is always default', () {
      final c = RuntimeConfig.fromAgent({
        'runtime': 'codex',
        'model': 'gpt-5-codex',
        'reasoningEffort': 'medium',
        'envVars': {'A': '1'},
      });
      expect(c.runtime, 'codex');
      expect(c.model, 'gpt-5-codex');
      expect(c.customModel, isFalse);
      expect(c.reasoningEffort, 'medium');
      expect(c.fastMode, isFalse);
      expect(c.envVarMap, {'A': '1'});
    });

    test('there is no flat fastMode column: the legacy flag is ignored', () {
      final c = RuntimeConfig.fromAgent({
        'runtime': 'codex',
        'model': 'gpt-5-codex',
        'fastMode': true,
      });
      expect(c.fastMode, isFalse);
    });

    test('a non-catalog model is custom, an empty one the runtime default', () {
      expect(
        RuntimeConfig.fromAgent({
          'runtime': 'cursor',
          'model': 'custom-composer',
        }).customModel,
        isTrue,
      );
      final c = RuntimeConfig.fromAgent({'runtime': 'codex', 'model': ' '});
      expect(c.model, 'gpt-6.1-sol');
      expect(c.customModel, isFalse);
    });

    test('no runtime at all is claude', () {
      expect(RuntimeConfig.fromAgent(const {}).runtime, 'claude');
    });

    test('legacy Claude env vars become the custom provider', () {
      final c = RuntimeConfig.fromAgent({
        'runtime': 'claude',
        'model': 'internal-gateway/claude-opus',
        'envVars': {
          'ANTHROPIC_BASE_URL': 'https://gateway.example.test/v1',
          'ANTHROPIC_API_KEY': 'sk-ant-test',
          'ANTHROPIC_CUSTOM_MODEL_OPTION': 'old-generated-value',
          'TEAM_FLAG': 'enabled',
        },
      });
      expect(c.customProvider, isTrue);
      expect(c.providerApiUrl, 'https://gateway.example.test/v1');
      expect(c.apiKey, 'sk-ant-test');
      expect(c.model, 'internal-gateway/claude-opus');
      expect(c.customModel, isTrue);
      // The runtime-controlled keys are not user env vars.
      expect(c.envVarMap, {'TEAM_FLAG': 'enabled'});
    });

    test('non-string env values are dropped', () {
      final c = RuntimeConfig.fromAgent({
        'runtime': 'cursor',
        'model': 'auto',
        'envVars': {'A': '1', 'B': 2},
      });
      expect(c.envVarMap, {'A': '1'});
    });
  });

  group('mixed: stored config completed from the flat columns', () {
    test('stored config without a model falls back to the flat model', () {
      final c = RuntimeConfig.fromAgent({
        'runtime': 'codex',
        'model': 'gpt-5.5',
        'reasoningEffort': 'low',
        'runtimeConfig': {
          'version': 1,
          'runtime': 'codex',
          'mode': {'kind': 'fast'},
        },
      });
      expect(c.model, 'gpt-5.5');
      expect(c.fastMode, isTrue);
      // The stored reasoningEffort (absent) falls back to the flat column.
      expect(c.reasoningEffort, 'low');
    });

    test('a stored null reasoning effort falls back to the flat column', () {
      final c = RuntimeConfig.fromAgent({
        'runtime': 'codex',
        'model': 'gpt-5.5',
        'reasoningEffort': 'high',
        'runtimeConfig': {
          'version': 1,
          'runtime': 'codex',
          'model': {'kind': 'preset', 'id': 'gpt-5.5'},
          'mode': {'kind': 'default'},
          'reasoningEffort': null,
        },
      });
      expect(c.reasoningEffort, 'high');
    });

    test(
      'stripped custom provider credentials recover from legacy env vars',
      () {
        final c = RuntimeConfig.fromAgent({
          'runtime': 'claude',
          'model': 'sonnet',
          'runtimeConfig': {
            'version': 1,
            'runtime': 'claude',
            'provider': {'kind': 'custom', 'apiUrl': '', 'apiKey': ''},
            'model': {'kind': 'preset', 'id': 'deepseek-v4-pro'},
            'mode': {'kind': 'default'},
            'reasoningEffort': null,
            'envVars': null,
          },
          'envVars': {
            'ANTHROPIC_BASE_URL': 'https://api.deepseek.com/anthropic',
            'ANTHROPIC_API_KEY': 'sk-deepseek-test',
            'ANTHROPIC_CUSTOM_MODEL_OPTION': 'deepseek-v4-pro',
          },
        });
        expect(c.providerApiUrl, 'https://api.deepseek.com/anthropic');
        expect(c.model, 'deepseek-v4-pro');
        expect(c.customModel, isTrue);
        expect(c.envVars, isNull);
      },
    );

    test('the stored env vars replace the flat ones', () {
      final c = RuntimeConfig.fromAgent({
        'runtime': 'codex',
        'envVars': {'OLD': '1'},
        'runtimeConfig': {
          'version': 1,
          'runtime': 'codex',
          'model': {'kind': 'preset', 'id': 'gpt-5.5'},
          'envVars': {'NEW': '2'},
        },
      });
      expect(c.envVarMap, {'NEW': '2'});
    });
  });

  group(
    'runtime support gates (Web supports* / REASONING_EFFORT_RUNTIMES)',
    () {
      test('fast mode: claude and codex only', () {
        for (final r in ['claude', 'codex']) {
          expect(runtimeSupportsFastMode(r), isTrue, reason: r);
        }
        for (final r in [
          'grok',
          'antigravity',
          'kimi',
          'copilot',
          'cursor',
          'gemini',
          'opencode',
          'builtin',
          'pi',
          'kimi-sdk',
        ]) {
          expect(runtimeSupportsFastMode(r), isFalse, reason: r);
        }
      });

      test(
        'an unsupported runtime hides the Mode row even with a fast config',
        () {
          // A fast mode on a runtime without a launch contract is never shown.
          final c = RuntimeConfig.fromAgent({
            'runtime': 'cursor',
            'model': 'auto',
            'runtimeConfig': {
              'version': 1,
              'runtime': 'cursor',
              'model': {'kind': 'preset', 'id': 'auto'},
              'mode': {'kind': 'fast'},
            },
          });
          expect(c.supportsFastMode, isFalse);
        },
      );

      test('reasoning, API URL and command sets', () {
        for (final r in [
          'builtin',
          'claude',
          'codex',
          'grok',
          'copilot',
          'pi',
          'kimi-sdk',
        ]) {
          expect(runtimeSupportsReasoning(r), isTrue, reason: r);
        }
        for (final r in [
          'antigravity',
          'kimi',
          'cursor',
          'gemini',
          'opencode',
        ]) {
          expect(runtimeSupportsReasoning(r), isFalse, reason: r);
        }
        expect(runtimeSupportsApiUrl('claude'), isTrue);
        expect(runtimeSupportsApiUrl('codex'), isFalse);
        expect(runtimeSupportsCommand('claude'), isTrue);
        expect(runtimeSupportsCommand('codex'), isFalse);
      });

      test('command is read for Claude only', () {
        Map<String, dynamic> agent(String runtime) => {
          'runtime': runtime,
          'runtimeConfig': {
            'version': 1,
            'runtime': runtime,
            'model': {'kind': 'preset', 'id': 'x'},
            'command': 'dev-cli',
          },
        };
        expect(RuntimeConfig.fromAgent(agent('claude')).commandText, 'dev-cli');
        expect(RuntimeConfig.fromAgent(agent('codex')).commandText, '');
      });

      test('controlled env keys are hidden per runtime', () {
        final env = {
          'ANTHROPIC_API_KEY': 'k',
          'OPENAI_API_KEY': 'k',
          'DEEPSEEK_API_KEY': 'k',
          'TEAM': 't',
        };
        Map<String, String> read(String runtime) => RuntimeConfig.fromAgent({
          'runtime': runtime,
          'model': 'x',
          'envVars': env,
        }).envVarMap;
        expect(read('codex'), env);
        expect(
          read('claude').keys,
          unorderedEquals(['OPENAI_API_KEY', 'DEEPSEEK_API_KEY', 'TEAM']),
        );
        expect(
          read('pi').keys,
          unorderedEquals(['ANTHROPIC_API_KEY', 'OPENAI_API_KEY', 'TEAM']),
        );
        expect(read('builtin'), {'TEAM': 't'});
      });
    },
  );
}
