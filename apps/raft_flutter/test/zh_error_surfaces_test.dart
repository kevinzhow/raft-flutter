import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/features/session_recovery_view.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _zh(Widget home) => MaterialApp(
  locale: const Locale('zh'),
  supportedLocales: const [Locale('zh')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: raftTheme(),
  home: home,
);

void main() {
  testWidgets('session recovery sentences show in Chinese', (tester) async {
    await tester.pumpWidget(
      _zh(
        SessionRecoveryView(
          failure: const SessionRestoreException(
            SessionRestoreFailureKind.storage,
          ),
          busy: false,
          onRetry: () {},
          onSignInAgain: () {},
        ),
      ),
    );
    expect(find.text('已保存的登录暂不可用'), findsOneWidget);
    expect(
      find.text('设备无法打开保存登录信息的安全存储。登录信息仍已保存，通常在设备解锁后即可恢复。'),
      findsOneWidget,
    );
  });

  testWidgets('a form field validator message is localized', (tester) async {
    await tester.pumpWidget(
      _zh(
        Scaffold(
          body: RaftFormDialog(
            title: 'Server URL',
            fields: const [
              RaftFormField('origin', 'Server URL', validator: authOriginError),
            ],
            onSubmit: (_) async {},
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'not a url');
    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(find.text('请输入服务器地址，例如 https://raft.example.com。'), findsOneWidget);
  });
}
