import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';

RaftThemePack pack(Map<String, Object?> light, {Map<String, Object?>? dark}) =>
    RaftThemePack.parse(
      jsonEncode({
        'format': 'raft-theme/1',
        'id': 'font-fixture',
        'name': 'Font fixture',
        'version': '1.0.0',
        'extends': 'raft',
        'modes': {'light': light, 'dark': dark ?? <String, Object?>{}},
      }),
    );

void main() {
  test('mode font references inherit and independently override at night', () {
    final base = pack(
      {
        'font': {'font.messageTime': '{fonts.mono}'},
      },
      dark: {
        'font': {'font.messageTime': '{fonts.sans}'},
      },
    );
    final child = pack({});
    expect(
      child.resolve(dark: false, base: base).fontRefs['font.messageTime'],
      'mono',
    );
    expect(
      child.resolve(dark: true, base: base).fontRefs['font.messageTime'],
      'sans',
    );
    final override = pack({
      'font': {'font.messageTime': '{fonts.heading}'},
    });
    expect(
      override.resolve(dark: false, base: base).fontRefs['font.messageTime'],
      'heading',
    );
  });
  test(
    'mode font references reject unknown roles and non-reference families',
    () {
      for (final font in [
        {'font.other': '{fonts.mono}'},
        {'font.messageTime': 'mono'},
        {'font.messageTime': '{fonts.missing}'},
        {'font.messageTime': 1},
      ]) {
        expect(
          () => pack({'font': font}),
          throwsA(
            predicate(
              (e) =>
                  e is RaftThemeException && e.where?.contains('.font') == true,
            ),
          ),
        );
      }
      expect(
        () => pack({'font': 'not-an-object'}),
        throwsA(
          predicate(
            (e) =>
                e is RaftThemeException && e.where?.contains('.font') == true,
          ),
        ),
      );
    },
  );
}
