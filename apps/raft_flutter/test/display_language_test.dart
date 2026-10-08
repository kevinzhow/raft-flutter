import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/main.dart' show displayLocale;
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('user-defined dropdown labels remain verbatim in Chinese', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(
          body: RaftFormDialog(
            title: 'Move to sidebar section',
            fields: const [
              RaftFormField(
                'section',
                'Section',
                initial: 'mine',
                choices: {'mine': 'Save'},
                localizeChoices: false,
              ),
            ],
            onSubmit: (_) async {},
          ),
        ),
      ),
    );
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget); // Only the actual submit button.
  });

  test('display locale uses only shipped UI languages and device fallback', () {
    expect(
      displayLocale('zh-cn', device: const Locale('en')),
      const Locale('zh', 'CN'),
    );
    expect(
      displayLocale('en', device: const Locale('zh', 'CN')),
      const Locale('en'),
    );
    expect(
      displayLocale(null, device: const Locale('zh', 'CN')),
      const Locale('zh', 'CN'),
    );
    expect(
      displayLocale(null, device: const Locale('ja', 'JP')),
      const Locale('en'),
    );
    expect(
      displayLocale(null, device: const Locale('zh', 'TW')),
      const Locale('en'),
    );
  });
  testWidgets(
    'Chinese controls render while message and user names stay intact',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: Column(
              children: [
                RaftButton(label: 'Save', onPressed: () {}),
                RaftNavItem(label: 'Search', icon: Icons.tag, onTap: () {}),
                const RaftMessageTile(
                  author: 'Delete',
                  timestamp: '09:41',
                  content: 'Save',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('保存'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(
        find.text('回复话题'),
        findsNothing,
      ); // no reply button when callback omitted.
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Chinese form field labels and required validation use rendered locale',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: RaftFormDialog(
              title: 'Create channel',
              fields: const [
                RaftFormField('name', 'Channel name', required: true),
              ],
              onSubmit: (_) async {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('频道名称为必填项。'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'localized templates keep placeholder-like user names untouched',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: Text(
                raftFormat(context, 'Make {name} a {role} in {workspace}.', {
                  'name': 'Save {role}',
                  'role': '管理员',
                  'workspace': 'Delete',
                }),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('将Save {role}设为Delete的管理员。'), findsOneWidget);
    },
  );
}
