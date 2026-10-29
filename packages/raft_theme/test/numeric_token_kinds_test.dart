import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';

RaftThemePack numeric(String token, num value) => RaftThemePack.parse(
  jsonEncode({
    'format': 'raft-theme/1',
    'id': 'numeric-kinds',
    'version': '1.0.0',
    'name': 'Numeric kinds',
    'modes': {
      'light': {
        'geometry': {token: value},
      },
      'dark': <String, Object?>{},
    },
  }),
);
void main() {
  test('blur tokens use nonnegative pixels', () {
    expect(
      numeric('blur.dialogBackdrop', 0).light.geometry['blur.dialogBackdrop'],
      0,
    );
    expect(
      numeric('blur.dialogBackdrop', 2.5).light.geometry['blur.dialogBackdrop'],
      2.5,
    );
    expect(
      () => numeric('blur.dialogBackdrop', -0.1),
      throwsA(isA<RaftThemeException>()),
    );
  });
  test('duration tokens accept positive whole milliseconds', () {
    for (final value in [1, 1000, 1000.0]) {
      expect(
        numeric(
          'duration.spinnerTurn',
          value,
        ).light.geometry['duration.spinnerTurn'],
        value,
      );
    }
  });
  test('duration tokens reject zero negative and fractional milliseconds', () {
    for (final value in [0, -1, 1.5]) {
      expect(
        () => numeric('duration.spinnerTurn', value),
        throwsA(
          predicate(
            (e) =>
                e is RaftThemeException &&
                e.message.contains('positive integer milliseconds') &&
                e.where!.endsWith('duration.spinnerTurn'),
          ),
        ),
      );
    }
  });
  test('ratio tokens accept inclusive zero through one', () {
    for (final value in [0, .5, 1]) {
      expect(
        numeric(
          'ratio.spinnerRingRadius',
          value,
        ).light.geometry['ratio.spinnerRingRadius'],
        value,
      );
    }
  });
  test('ratio tokens reject values outside zero through one', () {
    for (final value in [-.01, 1.01]) {
      expect(
        () => numeric('ratio.spinnerRingRadius', value),
        throwsA(
          predicate(
            (e) =>
                e is RaftThemeException &&
                e.message.contains('between 0 and 1') &&
                e.where!.endsWith('ratio.spinnerRingRadius'),
          ),
        ),
      );
    }
  });
}
