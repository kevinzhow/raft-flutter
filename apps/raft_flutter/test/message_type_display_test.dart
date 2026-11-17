import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/personal_presentation.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/features/message_type_scale.dart';
import 'package:raft_ui/raft_ui.dart';

class _Storage implements SearchMemoryStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  for (final id in [raftThemePackId]) {
    testWidgets(
      '$id maps displayed tiers without rewriting stored preferences',
      (t) async {
        final disk = _Storage();
        final store = PersonalPresentationStore(storage: disk);
        await store.bind('https://fixture.invalid', 'u');
        for (var i = 0; i < 3; i++) {
          final tier = ['sm', 'md', 'lg'][i];
          store.update(store.key, font: tier);
          await store.writes;
          final before = jsonEncode(disk.values);
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(),
              home: PersonalPresentationScope(
                store: store,
                child: Builder(
                  builder: (context) {
                    final legacy = PersonalPresentationScope.bodyFontSize(
                      context,
                      'md',
                    );
                    return Text(
                      '${messagePreferenceDisplaySize(context, legacy)}',
                    );
                  },
                ),
              ),
            ),
          );
          final expected = [14.0, 16.0, 18.0][i];
          expect(find.text('$expected'), findsOneWidget);
          expect(store.value.font, tier);
          expect(store.value.fontSize, [12, 14, 16][i]);
          expect(jsonEncode(disk.values), before);
          expect(t.takeException(), isNull);
        }
        await t.pumpWidget(const SizedBox());
        store.dispose();
      },
    );
  }
}
