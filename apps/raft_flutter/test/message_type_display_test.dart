import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/personal_presentation.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/features/message_type_scale.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

class _Storage implements SearchMemoryStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  for (final id in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
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
              theme: raftTheme(pack: packForThemeId(id)),
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
          final expected = (id == raftThemePackId
              ? [14.0, 16.0, 18.0]
              : [12.0, 14.0, 16.0])[i];
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
