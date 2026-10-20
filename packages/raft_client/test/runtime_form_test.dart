import 'dart:convert';
import 'dart:io';

import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

Map<String, dynamic> fixture(String name) {
  final base = [
    'test/fixtures/runtime-form',
    'packages/raft_client/test/fixtures/runtime-form',
    '../../packages/raft_client/test/fixtures/runtime-form',
  ].firstWhere((path) => File('$path/$name').existsSync());
  return Map<String, dynamic>.from(
    jsonDecode(File('$base/$name').readAsStringSync()),
  );
}

Map<String, Map<String, dynamic>> sources(String name) {
  final raw = fixture(name);
  if (raw.containsKey('sourceId')) return {raw['sourceId']: raw};
  return {
    for (final e in raw.entries) e.key: Map<String, dynamic>.from(e.value),
  };
}

void main() {
  test(
    'native environment text preserves exact values and refuses silent loss',
    () {
      expect(parseRuntimeStringMap(' API_KEY=  x=y  \n\nLANG=日本語'), {
        'API_KEY': '  x=y  ',
        'LANG': '日本語',
      });
      for (final text in ['malformed', '=no-key', 'A=one\n A=two']) {
        expect(() => parseRuntimeStringMap(text), throwsFormatException);
      }
    },
  );
  test(
    'released Codex source initializes and cascades model/effort defaults',
    () {
      final form = RuntimeForm.parse(fixture('codex.form.json'))!;
      final live = sources('codex.option-source.live.json');
      final values = form.initial(live);
      expect(form.supported, true);
      expect(form.validate(live, values), isEmpty);
      final model = form.fields.firstWhere((f) => f.key == 'model');
      final choices = form.choices(model, live, values);
      final changed = form.change(live, values, 'model', choices.last['value']);
      expect(form.validate(live, changed), isEmpty);
      final custom = form.change(
        live,
        values,
        'model',
        ' my-org/custom-model ',
      );
      expect(form.submission(custom, live)['model'], 'my-org/custom-model');
      expect(form.submission(custom, live)['reasoningEffort'], null);
    },
  );
  test('unavailable required sources block save without falling back', () {
    final form = RuntimeForm.parse(fixture('codex.form.json'))!;
    final absent = sources('codex.option-source.unavailable.json');
    expect(
      form.validate(absent, form.initial(absent))['model'],
      'source_unavailable',
    );
    final model = form.fields.firstWhere((f) => f.key == 'model');
    expect(form.visible(model, form.initial(absent), absent), true);
  });
  test(
    'unknown fields survive edits and required capabilities fail closed',
    () {
      final raw = fixture('codex.edit.json');
      raw['dataSchema']['properties']['futureOptional'] = {
        'type': 'future_type',
      };
      raw['values']['futureOptional'] = {'future': 'opaque'};
      final form = RuntimeForm.parse(raw)!;
      final live = sources('codex.option-source.live.json');
      expect(form.submission(form.initial(live), live)['futureOptional'], {
        'future': 'opaque',
      });
      raw['dataSchema']['required'].add('futureOptional');
      final blocked = RuntimeForm.parse(raw)!;
      expect(
        blocked.validate(
          live,
          blocked.initial(live),
          editing: true,
        )['futureOptional'],
        'unsupported_required',
      );
      raw['requiredClientCapabilities'] = ['not-supported'];
      expect(RuntimeForm.parse(raw)!.supported, false);
      raw['requiredClientCapabilities'] = 'invalid';
      expect(RuntimeForm.parse(raw)!.supported, false);
    },
  );
  test('hidden provider fields omit stale values and secret edit blanks keep server value', () {
    final form = RuntimeForm.parse(fixture('pi.edit.configured.json'))!;
    final provider = sources('pi.option-source.provider.json');
    final models = sources('pi.option-source.provider-model.json');
    final all = {...provider, ...models};
    final values = form.initial(all);
    final submission = form.submission(values, all);
    for (final f in form.fields.where((f) => !form.visible(f, values))) {
      expect(submission.containsKey(f.key), false);
    }
    for (final f in form.fields.where((f) => f.kind == 'secret')) {
      if (form.visible(f, values))
        expect(
          form.validate(all, {...values, f.key: ''}, editing: true)[f.key],
          isNot('required'),
        );
    }
  });

  group('saved provider connections (provider.saved_connection)', () {
    Map<String, Map<String, dynamic>> builtinSources() => {
      'provider': fixture('builtin.saved.option-source.provider.json'),
      'model': fixture('builtin.saved.option-source.model.json'),
    };
    RuntimeForm builtin([String name = 'builtin.saved.form.json']) =>
        RuntimeForm.parse(fixture(name))!;

    // A server with provider_connections_v0 on adds this capability to the
    // Built-in Pi form. Before the client declared it, the whole form was
    // "unsupported" and Built-in Pi agents could be neither created nor edited.
    test('a Built-in Pi form that requires the capability is supported', () {
      final form = builtin();
      expect(form.capabilities, ['provider.saved_connection']);
      expect(form.supported, true);
      expect(
        form.validate(builtinSources(), form.initial(builtinSources())),
        isNot(contains('form')),
      );
      expect(builtin('builtin.saved.edit.json').supported, true);
      // A capability this client does not know still fails the whole form.
      final raw = fixture('builtin.saved.form.json');
      raw['requiredClientCapabilities'] = [
        'provider.saved_connection',
        'provider.future_thing',
      ];
      expect(RuntimeForm.parse(raw)!.supported, false);
    });

    test('x-connectionOwned marks the fields a connection owns', () {
      final form = builtin();
      expect(
        [
          for (final f in form.fields)
            if (f.connectionOwned) f.key,
        ],
        ['apiKey', 'baseUrl', 'supportsImageInput'],
      );
      expect(builtin().revision, 'saved-connection.v1:3f2a9c1e');
      final plain = fixture('builtin.saved.form.json')..remove('revision');
      expect(RuntimeForm.parse(plain)!.revision, isNull);
    });

    test(
      'a saved connection owns the credential: not required, not submitted',
      () {
        final form = builtin(), src = builtinSources();
        var values = form.initial(src);
        expect(values['providerId'], 'deepseek');
        expect(form.connectionActive(src, values), false);
        expect(form.validate(src, values)['apiKey'], 'required');
        values = form.change(src, values, 'apiKey', 'sk-typed');
        values = form.change(src, values, 'providerId', 'connection:conn-team');
        expect(form.connectionActive(src, values), true);
        // The typed key does not survive the hand-over to the connection.
        expect(values['apiKey'], '');
        expect(values['model'], 'deepseek-v4-pro');
        expect(form.validate(src, values), isEmpty);
        expect(form.submission(values, src), {
          'providerId': 'connection:conn-team',
          'model': 'deepseek-v4-pro',
          'loadLocalPlugins': false,
          'envVars': <String, String>{},
        });
        // Moving off the connection gives the fields back, empty and required.
        final direct = form.change(src, values, 'providerId', 'deepseek');
        expect(direct['apiKey'], '');
        expect(form.validate(src, direct)['apiKey'], 'required');
        expect(form.submission(direct, src)['apiKey'], '');
      },
    );

    test('a gateway connection keeps the endpoint fields visible but owned', () {
      final form = builtin(), src = builtinSources();
      final team = form.change(
        src,
        form.initial(src),
        'providerId',
        'connection:conn-team',
      );
      final gateway = form.change(
        src,
        form.change(
          src,
          form.initial(src),
          'providerId',
          'connection:conn-gateway',
        ),
        'model',
        'office-model',
      );
      RuntimeField field(String key) =>
          form.fields.firstWhere((f) => f.key == key);
      // The visibility rule sees the underlying provider id as well.
      expect(form.visible(field('baseUrl'), gateway, src), true);
      expect(form.visible(field('supportsImageInput'), gateway, src), true);
      expect(form.visible(field('baseUrl'), team, src), false);
      // Without sources only the raw value is known.
      expect(form.visible(field('baseUrl'), gateway), false);
      // Owned: no required/invalid-url error, nothing submitted, not even ''.
      expect(form.validate(src, gateway), isEmpty);
      final sent = form.submission(gateway, src);
      expect(sent.keys, isNot(contains('baseUrl')));
      expect(sent.keys, isNot(contains('supportsImageInput')));
      expect(sent.keys, isNot(contains('apiKey')));
      // The gateway connection may take a typed model; the preset one may not.
      expect(form.validate(src, {...gateway, 'model': 'anything'}), isEmpty);
      expect(
        form.validate(src, {...team, 'model': 'anything'})['model'],
        'not_a_choice',
      );
    });

    test('an unavailable connection stays visible and blocks the save', () {
      final form = builtin(), src = builtinSources();
      final values = form.change(
        src,
        form.initial(src),
        'providerId',
        'connection:conn-old',
      );
      expect(
        form.selectedConnection(
          form.fields.first,
          src,
          values,
        )?['unavailableReason'],
        'disabled',
      );
      expect(
        form.validate(src, values)['providerId'],
        'connection_unavailable',
      );
      expect(
        form.choices(form.fields.first, src, values).map((o) => o['value']),
        contains('connection:conn-old'),
      );
    });

    test(
      'an option whose value breaks connection:<id> is not a connection',
      () {
        final form = builtin(), src = builtinSources();
        final options = src['provider']!['options'] as List;
        options.add({
          'value': 'connection:other',
          'label': 'Liar',
          'connectionId': 'conn-liar',
          'group': 'saved',
        });
        final values = {...form.initial(src), 'providerId': 'connection:other'};
        expect(form.connectionActive(src, values), false);
      },
    );

    test('editing an agent bound to a connection', () {
      final form = builtin('builtin.saved.edit.json'), src = builtinSources();
      final values = form.initial(src);
      expect(values['providerId'], 'connection:conn-team');
      expect(form.connectionActive(src, values), true);
      expect(form.validate(src, values, editing: true), isEmpty);
      expect(form.submission(values, src).keys, isNot(contains('apiKey')));
      // The stored binding is not in the list for a caller who may not list
      // connections: it stays selected (not silently rewritten) but blocks.
      final direct = {'provider': src['provider']!, 'model': src['model']!};
      (direct['provider']!['options'] as List).removeWhere(
        (o) => (o as Map)['group'] == 'saved',
      );
      expect(
        form.validate(direct, values, editing: true)['providerId'],
        'not_a_choice',
      );
    });
  });
}
