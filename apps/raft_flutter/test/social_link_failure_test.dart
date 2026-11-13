// Web v1.24 SocialAuthCallbackPage `linkFailureMessageId`: Settings
// "Connect" refusals the person can act on, in the Web catalog's words.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/social_sign_in_failure.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _app(Widget home, {bool zh = false}) => MaterialApp(
  locale: zh ? const Locale('zh') : null,
  supportedLocales: zh ? const [Locale('zh')] : const [Locale('en', 'US')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: raftTheme(),
  home: home,
);

void main() {
  testWidgets('Settings "Connect" refusals say what to do, not the server', (
    t,
  ) async {
    late BuildContext context;
    await t.pumpWidget(
      _app(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
        zh: true,
      ),
    );
    RaftApiException refusal(String code, String error) =>
        RaftApiException.response(
          error,
          status: 409,
          body: {'code': code, 'error': error},
        );
    expect(
      socialLinkFailureText(
        context,
        refusal(
          'provider_conflict',
          'This GitHub account is already linked to another Raft account',
        ),
        'GitHub',
      ),
      '这个 GitHub 账号已经连接到另一个 Raft 账户。请先在那个账户里断开它，再回来重试。',
    );
    expect(
      socialLinkFailureText(
        context,
        refusal('provider_conflict', 'This GitHub identity belongs to another'),
        'GitHub',
      ),
      '这个 GitHub 账号已被另一个 Raft 账户使用，没能连接到这里。',
    );
    expect(
      socialLinkFailureText(
        context,
        refusal('email_verification_required', 'Verify your email'),
        'GitHub',
      ),
      '请先验证你的 Raft 账户邮箱。验证之前，只能连接主邮箱与 Raft 邮箱相同的 GitHub 账号。',
    );
    expect(
      socialLinkFailureText(context, refusal('other', 'Nope'), 'GitHub'),
      isNull,
    );
  });
}
