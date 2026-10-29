import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  test('the public switch geometry API remains available to callers', () {
    const defaults = RaftSwitchRecipe();
    expect(defaults.visualSize, const Size(50, 30));
    expect(defaults.thumbSize, 22);
    expect(defaults.thumbInset, 4);
    expect(defaults.travel, 20);
    expect(RaftSwitchMetrics.width, 50);
    expect(RaftSwitchMetrics.height, 30);
    expect(RaftSwitchMetrics.thumb, 22);
    expect(RaftSwitchMetrics.travel, 20);

    final pack = RaftThemePack.parse(
      jsonEncode({
        'format': raftThemePackFormat,
        'id': 'user:public-switch-api',
        'name': {'en': 'Custom'},
        'version': '1',
        'extends': 'raft',
        'modes': {
          'light': {
            'geometry': {
              'size.switch.width.sm': 64,
              'size.switch.height.sm': 32,
              'size.switch.thumb.sm': 20,
              'space.switchInset': 6,
            },
          },
          'dark': {},
        },
      }),
    );
    final custom = RaftSwitchRecipe(
      tokens: RaftTokens.theme(pack: pack),
      size: RaftSwitchSize.sm,
    );
    expect(custom.visualSize, const Size(64, 32));
    expect(custom.thumbSize, 20);
    expect(custom.thumbInset, 6);
    expect(custom.travel, 32);
  });
}
