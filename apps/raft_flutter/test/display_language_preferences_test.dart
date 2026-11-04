import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/device_display_preferences.dart';
import 'package:raft_flutter/data/display_language_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(DevicePreferences.reset);
  tearDown(DevicePreferences.reset);

  test(
    'anonymous choice never seeds or overwrites either signed-in account',
    () async {
      SharedPreferences.setMockInitialValues({
        displayLanguagePreferenceKey: 'zh-cn',
      });
      await DevicePreferences.load();
      final preferences = DisplayLanguagePreferences();
      expect(
        preferences.resolve(null, signedIn: false),
        const Locale('zh', 'CN'),
      );
      expect(
        preferences.resolve(null, signedIn: true),
        const Locale('zh', 'CN'),
      );
      expect(preferences.resolve('en-US', signedIn: true), const Locale('en'));
      expect(preferences.resolve('en', signedIn: true), const Locale('en'));
      await preferences.save('en');
      expect(
        preferences.resolve('zh-cn', signedIn: true),
        const Locale('zh', 'CN'),
      );
      expect(preferences.resolve(null, signedIn: false), const Locale('en'));
      preferences.dispose();
    },
  );

  test('unsupported and wrong-typed disk values are ignored without destroying old preferences', () async {
    for (final value in <Object>['ja', true, 42]) {
      SharedPreferences.setMockInitialValues({
        displayLanguagePreferenceKey: value,
        'raft.mode': 'dark',
      });
      await DevicePreferences.load();
      final preferences = DisplayLanguagePreferences();
      expect(preferences.value, isNull);
      await preferences.save('retired-language');
      final p = await SharedPreferences.getInstance();
      expect(p.get(displayLanguagePreferenceKey), value);
      expect(p.getString('raft.mode'), 'dark');
      preferences.dispose();
    }
  });

  test('last selected language is the value restored by a new owner', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = DisplayLanguagePreferences();
    final first = preferences.save('zh-cn');
    final second = preferences.save('en');
    await Future.wait([first, second]);
    await DevicePreferences.load();
    final restarted = DisplayLanguagePreferences();
    expect(restarted.value, 'en');
    preferences.dispose();
    restarted.dispose();
  });
  test(
    'retired display owners ignore late restore and new save requests',
    () async {
      SharedPreferences.setMockInitialValues({
        displayLanguagePreferenceKey: 'zh-cn',
        'raft.mode': 'dark',
      });
      final p = await SharedPreferences.getInstance();
      final owner = DeviceDisplayPreferences();
      owner.dispose();
      owner.adopt(p);
      owner.displayLanguage.adopt(p);
      await owner.displayLanguage.save('en');
      await owner.save(const RaftAppearance(mode: ThemeMode.light));
      expect(p.getString(displayLanguagePreferenceKey), 'zh-cn');
      expect(p.getString('raft.mode'), 'dark');
    },
  );
}
