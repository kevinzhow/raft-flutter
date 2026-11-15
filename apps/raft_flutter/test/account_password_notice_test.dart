// Web v1.24.0 features/settings/account/AccountSection.tsx:537: the open
// Change password form says, in an info banner after the fields, that a new
// password signs you out everywhere and stops device-login credentials
// (`settings.account.deviceLoginNotice`).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/account_password_editor.dart';
import 'package:raft_ui/raft_ui.dart';

const _en =
    "Changing your password signs you out everywhere. Computers and agent credentials set up through a device login (Raft Computer, the raft CLI) stop working too, so you'll need to log in on them again.";
const _zh =
    '修改密码会让你在所有设备上退出登录。通过设备登录（Raft Computer、raft CLI）设置的电脑连接和 Agent 凭证也会失效，需要在这些地方重新登录。';
const _notice = ValueKey('account-password-device-login-notice');

void main() {
  late RaftClient client;
  late WorkspaceController w;
  setUp(() {
    client = RaftClient(
      origin: 'https://fixture.invalid',
      sessionStore: MemorySessionStore(),
    )..user = RaftRecord({'id': 'owner', 'email': 'fixture@example.invalid'});
    w = WorkspaceController(client);
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  Future<void> mount(WidgetTester t, {bool zh = false}) async {
    await t.pumpWidget(
      MaterialApp(
        locale: zh ? const Locale('zh') : null,
        supportedLocales: zh ? const [Locale('zh')] : const [Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: raftTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AccountPasswordEditor(controller: w),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('the open form shows the notice after the fields, before the '
      'button; the closed row does not', (t) async {
    await mount(t);
    expect(find.byKey(_notice), findsNothing);
    await t.tap(find.byKey(const ValueKey('account-change-password')));
    await t.pumpAndSettle();
    final notice = find.byKey(_notice);
    expect(notice, findsOneWidget);
    expect(
      find.descendant(of: notice, matching: find.text(_en)),
      findsOneWidget,
    );
    expect(t.widget<RaftBanner>(notice).status, RaftBannerRecipeStatus.info);
    final confirm = t.getRect(
      find.byKey(const ValueKey('account-confirm-password')),
    );
    final submit = t.getRect(
      find.byKey(const ValueKey('account-password-submit')),
    );
    expect(t.getRect(notice).top, greaterThan(confirm.bottom));
    expect(t.getRect(notice).bottom, lessThan(submit.top));
  });

  testWidgets('it reads in Chinese with the Web zh-cn text', (t) async {
    await mount(t, zh: true);
    await t.tap(find.byKey(const ValueKey('account-change-password')));
    await t.pumpAndSettle();
    expect(find.text(_zh), findsOneWidget);
  });
}
