import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_metadata_catalog.dart';
import 'package:raft_flutter/features/agent_metadata_projection.dart';
import 'package:raft_flutter/features/agent_runtime_catalog.dart';

/// Web v1.21.23 shared RUNTIME_MODELS (pi-ai 1.3.0): the Built-in Pi catalog
/// dropped a batch of OpenRouter Qwen / Claude Sonnet 4 models and gained the
/// GPT-6.1 Sol batch ones. An agent saved with a removed id still shows
/// something sensible: `getModelLabel` falls back to the raw id.
void main() {
  const scope = (
    origin: 'https://fixture.invalid',
    principal: 'alice',
    server: 's',
    authorityRevision: 1,
  );
  String? label(String runtime, String model) => agentPresentationModelLabel(
    scope: scope,
    identity: AgentPresentationIdentity(
      id: 'a',
      status: 'online',
      runtime: runtime,
      model: model,
    ),
  );

  test('the GPT-6.1 Sol batch models of the new catalog have their labels', () {
    final builtin = sourceRuntimeModelLabels['builtin']!;
    expect(
      builtin['openrouter/openai/gpt-6.1-sol:batch'],
      'OpenAI: GPT-6.1 Sol (batch)',
    );
    expect(
      builtin['openrouter/openai/gpt-6.1-sol-pro:batch'],
      'OpenAI: GPT-6.1 Sol Pro (batch)',
    );
    expect(
      label('builtin', 'openrouter/openai/gpt-6.1-sol:batch'),
      'OpenAI: GPT-6.1 Sol (batch)',
    );
    expect(builtin['google/gemini-4-argon'], 'Gemini 4 Argon');
  });

  test('models the new catalog removed are gone from the label table', () {
    final builtin = sourceRuntimeModelLabels['builtin']!;
    for (final id in [
      'openrouter/qwen/qwen3-max',
      'openrouter/qwen/qwen3-coder-plus',
      'openrouter/anthropic/claude-sonnet-4',
    ]) {
      expect(builtin.containsKey(id), isFalse, reason: id);
    }
  });

  test(
    'an agent saved with a removed model shows the bare id, not a crash',
    () {
      expect(
        label('builtin', 'openrouter/qwen/qwen3-max'),
        'openrouter/qwen/qwen3-max',
      );
      expect(label('builtin', 'no-such/model'), 'no-such/model');
      expect(label('no-such-runtime', 'm'), 'm');
    },
  );

  test('Claude models with a ladder declare it up to max', () {
    final claude = {
      for (final m in staticRuntimeModelSources['claude']!) m.id: m,
    };
    for (final id in [
      'opus',
      'sonnet',
      'claude-opus-5-5',
      'claude-sonnet-5-5',
      'claude-haiku-5-5',
    ]) {
      expect(claude[id]!.supportedReasoningEfforts, [
        'low',
        'medium',
        'high',
        'xhigh',
        'max',
      ], reason: id);
    }
    expect(claude['claude-haiku-4-5']!.supportedReasoningEfforts, isNull);
  });
}
