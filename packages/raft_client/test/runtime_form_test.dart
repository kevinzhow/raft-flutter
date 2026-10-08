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
}
