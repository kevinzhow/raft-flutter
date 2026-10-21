import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/oauth_broker.dart';
import '../platform/local_network_access.dart';
import '../platform/app_services.dart';
import '../platform/system_bars.dart';

import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/server_error_code.dart';
import '../data/user_error.dart';
import 'auth_account_link.dart';
import 'management_support.dart';

bool isValidAuthEmail(String value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
String? authEmailError(String value) =>
    isValidAuthEmail(value) ? null : 'Invalid email format';
String? authOriginError(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
          ['http', 'https'].contains(uri.scheme) &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty &&
          (uri.path.isEmpty || uri.path == '/') &&
          uri.query.isEmpty &&
          uri.fragment.isEmpty
      ? null
      : 'Enter the server origin, such as https://raft.example.com.';
}

/// Web `authServerErrorMessage(err, fallback)`: bad credentials get the
/// localized sentence, otherwise the server's own text, else [fallback].
String authFailureText(Object error, String fallback, {String? where}) =>
    serverErrorIs(error, 'Invalid email or password')
    ? 'Incorrect email or password.'
    // Native only (no Web counterpart): the Android local-network permission
    // the person has to grant is actionable, so it is shown as is.
    : serverErrorIs(error, localNetworkPermissionError)
    ? localNetworkPermissionError
    : userErrorText(
        error,
        fallback: fallback,
        codeText: const {
          'AUTH_INVALID_CREDENTIALS': 'Incorrect email or password.',
        },
        where: where,
      );

String authLinkToken(String value, {String parameter = 'token'}) {
  final uri = Uri.tryParse(value);
  return uri != null && uri.hasScheme
      ? (uri.queryParameters[parameter] ?? '')
      : value;
}

class AuthView extends StatefulWidget {
  const AuthView({
    super.key,
    required this.origin,
    required this.onLogin,
    required this.onRegister,
    this.bootError,
    this.onOAuth,
    this.anonymousClientFactory,
    this.oauthBrokerFactory,
    this.initialMode = 'login',
    this.resetToken,
    this.authenticate,
  });
  final Future<void> Function(String, String, String, bool)? onOAuth;

  /// Runs a sign-in step on the app's session client. With it the browser
  /// sign-in completes through it (so [onOAuth] is not needed), and the
  /// "sign in and connect" continuation can add its handle to the request.
  final AuthAuthenticate? authenticate;

  /// First mode shown: 'login', 'register', 'forgot' or 'reset' (a reset or
  /// verification link opens straight into its page, like the Web query
  /// params).
  final String initialMode;

  /// Token of a password-reset link that opened the app (`?reset=`); the
  /// reset page then asks only for the new password, like Web. Without it the
  /// page also asks for the link or code (native clients have no URL).
  final String? resetToken;
  final RaftClient Function(String)? anonymousClientFactory;

  /// The browser sign-in broker (tests inject a fake launcher).
  final NativeOAuthBroker Function()? oauthBrokerFactory;
  final String origin;
  final String? bootError;
  final Future<void> Function(String, String, String) onLogin;
  final Future<void> Function(String, String, String, bool) onRegister;
  @override
  State<AuthView> createState() => _AuthState();
}

class _AuthState extends State<AuthView> {
  LocalNetworkAccess get networkAccess =>
      AppServicesScope.maybeReadOf(context)?.localNetwork ??
      const LocalNetworkAccess();

  late final base = TextEditingController(text: widget.origin);
  final email = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController(),
      token = TextEditingController();
  bool busy = false, visible = false, accepted = false;
  bool forgotSent = false, resetDone = false;
  String sentEmail = '';
  // ignore: raft_lints/avoid_imperative_notice_state -- Each clears when its field is edited, on submit revalidation and on mode switch.
  String? emailError, passwordError, confirmError, tokenError;
  List<Map<String, dynamic>> providers = [];
  NativeOAuthBroker? broker;

  /// The pending "sign in and connect" this page continues, and why its last
  /// attempt failed (a server `code`). Kept across the forgot-password page.
  PendingAccountLink? link;
  // ignore: raft_lints/avoid_imperative_notice_state -- Clears on submit, social sign-in start, cancel, restart and when a new link starts.
  String? linkFailure;
  Timer? providerDebounce;
  int providerRequest = 0;
  @override
  void initState() {
    super.initState();
    loadProviders();
  }

  bool get hasOAuth => widget.onOAuth != null || widget.authenticate != null;

  Future<void> loadProviders({bool requestPermission = false}) async {
    final request = ++providerRequest;
    if (!hasOAuth || authOriginError(base.text) != null) {
      if (mounted) setState(() => providers = []);
      return;
    }
    final client =
        widget.anonymousClientFactory?.call(base.text.trim()) ??
        RaftClient(
          origin: base.text.trim(),
          sessionStore: MemorySessionStore(),
        );
    try {
      await networkAccess.ensure(client.origin, request: requestPermission);
      if (!mounted || request != providerRequest) return;
      final data = await client.request(
        'GET',
        '/auth/providers',
        query: {'platform': 'mobile'},
        authorized: false,
      );
      if (mounted && request == providerRequest) {
        setState(
          () =>
              providers = managementRows(data['providers'])
                  .where((p) => p['enabled'] == true)
                  .toList(),
        );
      }
    } catch (e) {
      if (mounted && request == providerRequest) {
        setState(() {
          providers = [];
          if (requestPermission && e is RaftApiException) {
            error = authFailureText(e, 'Login failed', where: 'auth providers');
          }
        });
      }
    } finally {
      await client.dispose();
    }
  }

  Future<void> social(String provider) async {
    if (busy || !hasOAuth || authOriginError(base.text) != null) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
      notice = null;
      linkFailure = null;
    });
    final client =
        widget.anonymousClientFactory?.call(base.text.trim()) ??
        RaftClient(
          origin: base.text.trim(),
          sessionStore: MemorySessionStore(),
        );
    final active =
        widget.oauthBrokerFactory?.call() ??
        NativeOAuthBroker(locale: Localizations.maybeLocaleOf(context));
    broker = active;
    void helpChanged() {
      if (mounted) setState(() {});
    }

    active.helpUrl.addListener(helpChanged);
    try {
      await networkAccess.ensure(base.text.trim(), request: true);
      if (!mounted) return;
      final handoff = await active.begin(client, provider);
      if (mounted) {
        // Login: "By continuing, you agree to the Terms of Service and
        // Privacy Policy" (pages.login.legalAgreement); register: checkbox.
        final agreed = mode == 'login' || accepted;
        final pending = link?.continuation;
        final run = widget.authenticate;
        if (run != null) {
          await run(
            base.text.trim(),
            (c) => c.completeMobileOAuth(
              handoff.code,
              handoff.verifier,
              acceptTerms: agreed,
              link: pending,
            ),
          );
        } else {
          await widget.onOAuth!(
            base.text.trim(),
            handoff.code,
            handoff.verifier,
            agreed,
          );
        }
      }
    } catch (e) {
      // Web SocialAuthCallbackPage: `finishFailed` unless the server sent text.
      // A sign-in the person cancelled reports nothing.
      if (mounted && !active.cancelled) {
        final conflict = PendingAccountLink.fromError(e);
        setState(() {
          if (conflict != null) {
            startLink(conflict);
          } else if (link != null && isAccountLinkFailure(e)) {
            linkFailure = serverErrorCode(e);
          } else {
            error = authFailureText(
              e,
              'Failed to finish sign-in',
              where: 'social sign-in',
            );
          }
        });
      }
    } finally {
      active.helpUrl.removeListener(helpChanged);
      await active.cancel();
      await client.dispose();
      broker = null;
      if (mounted) setState(() => busy = false);
    }
  }

  /// The server asked to sign in to the account that owns this email: the
  /// page becomes "Connect to your existing account" (Web `accountLink`).
  void startLink(PendingAccountLink pending) {
    link = pending;
    linkFailure = null;
    error = null;
    mode = 'login';
    accepted = false;
    email.text = pending.email;
    password.clear();
    emailError = passwordError = null;
  }

  /// "Don't connect {provider}" / "Back to Sign In": drop the pending link on
  /// the server, then show the ordinary sign-in page.
  Future<void> cancelLink() async {
    final pending = link;
    if (pending == null || busy) return;
    setState(() {
      busy = true;
      error = null;
      linkFailure = null;
    });
    try {
      await anonymous('/auth/pending-link/cancel', {
        'pendingLinkToken': pending.token,
      });
      if (mounted) setState(() => link = null);
    } catch (_) {
      if (mounted) setState(() => error = 'Login failed');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// An expired link only continues by starting the provider again.
  void restartLink() {
    final pending = link;
    if (pending == null || busy) return;
    setState(() {
      link = null;
      linkFailure = null;
    });
    unawaited(social(pending.provider));
  }

  late String mode = widget.initialMode;
  // ignore: raft_lints/avoid_imperative_notice_state -- error clears on submit, social sign-in start, mode switch and server edit; notice is never raised (always null).
  String? error, notice;
  @override
  void dispose() {
    providerDebounce?.cancel();
    unawaited(broker?.cancel() ?? Future<void>.value());
    base.dispose();
    email.dispose();
    password.dispose();
    confirm.dispose();
    token.dispose();
    super.dispose();
  }

  Future<dynamic> anonymous(String path, Map<String, dynamic> data) async {
    final client =
        widget.anonymousClientFactory?.call(base.text.trim()) ??
        RaftClient(
          origin: base.text.trim(),
          sessionStore: MemorySessionStore(),
        );
    try {
      await networkAccess.ensure(base.text.trim(), request: true);
      if (!mounted) return null;
      return await client.request('POST', path, data: data, authorized: false);
    } finally {
      await client.dispose();
    }
  }

  /// Web validation order (LoginPage / RegisterPage / ResetPasswordPage): the
  /// first failing field shows its message under the control and nothing is
  /// sent.
  bool validate() {
    String? email, pass, conf, tok;
    if (mode != 'reset' && !isValidAuthEmail(this.email.text)) {
      email = 'Invalid email format';
    } else if (mode == 'reset' &&
        widget.resetToken == null &&
        token.text.trim().isEmpty) {
      tok = 'Enter a password reset link or code.';
    } else if (mode == 'login' && password.text.isEmpty) {
      pass = 'Password is required';
    } else if ((mode == 'register' || mode == 'reset') &&
        password.text.length < 8) {
      pass = 'Password must be at least 8 characters';
    } else if (mode == 'reset' && password.text != confirm.text) {
      conf = 'Passwords do not match';
    }
    setState(() {
      emailError = email;
      passwordError = pass;
      confirmError = conf;
      tokenError = tok;
    });
    return email == null && pass == null && conf == null && tok == null;
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() {
      error = null;
      notice = null;
      linkFailure = null;
    });
    if (!validate()) return;
    if (mode == 'register' && !accepted) {
      setState(
        () => error = 'You must agree to the Terms of Service and acknowledge the Privacy Policy to create an account.',
      );
      return;
    }
    setState(() => busy = true);
    try {
      switch (mode) {
        case 'login':
          final pending = link?.continuation;
          final run = widget.authenticate;
          if (pending != null && run != null) {
            await run(
              base.text.trim(),
              (c) => c.login(email.text.trim(), password.text, link: pending),
            );
          } else {
            await widget.onLogin(
              base.text.trim(),
              email.text.trim(),
              password.text,
            );
          }
        case 'register':
          await widget.onRegister(
            base.text.trim(),
            email.text.trim(),
            password.text,
            accepted,
          );
        case 'forgot':
          await anonymous('/auth/forgot-password', {
            'email': email.text.trim(),
          });
          if (mounted) {
            setState(() {
              forgotSent = true;
              sentEmail = email.text.trim();
            });
          }
        case 'reset':
          final code = widget.resetToken ?? authLinkToken(token.text.trim());
          if (code.isEmpty) {
            throw const RaftUserError('Enter a password reset link or code.');
          }
          await anonymous('/auth/reset-password', {
            'token': code,
            'password': password.text,
          });
          if (mounted) setState(() => resetDone = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (mode == 'login' && link != null && isAccountLinkFailure(e)) {
            linkFailure = serverErrorCode(e);
          } else {
            error = authFailureText(e, switch (mode) {
              'register' => 'Registration failed',
              'forgot' => 'Failed to send reset email',
              'reset' => 'Password reset failed. The link may be expired.',
              _ => 'Login failed',
            }, where: 'auth $mode');
          }
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void switchMode(String next) {
    if (busy) return;
    TextInput.finishAutofillContext(shouldSave: false);
    setState(() {
      mode = next;
      error = null;
      notice = null;
      emailError = passwordError = confirmError = tokenError = null;
      forgotSent = false;
      resetDone = false;
      password.clear();
      confirm.clear();
      token.clear();
      accepted = false;
    });
  }

  RaftAuthMode get authMode => switch (mode) {
    'register' => RaftAuthMode.register,
    'forgot' => RaftAuthMode.forgot,
    'reset' => RaftAuthMode.reset,
    _ => RaftAuthMode.login,
  };

  /// Platform exception (native client only): the Web page is served by its
  /// own origin, a native client must be told which server to use. The origin
  /// is edited from the brand bar instead of adding a form row, so the Web
  /// card keeps its exact layout.
  Future<void> editServer() async {
    if (busy) return;
    String? next;
    // ds-allow: native-only server origin editor (no Web counterpart); opens the shared RaftFormDialog.
    await showRaftForm<void>(
      context,
      builder: (context) => RaftFormDialog(
        title: raftText(context, 'Server URL'),
        fields: [
          RaftFormField(
            'origin',
            'Server URL',
            initial: base.text.trim(),
            required: true,
            validator: authOriginError,
          ),
        ],
        onSubmit: (values) async => next = values['origin'],
      ),
    );
    if (!mounted || next == null) return;
    setState(() {
      base.text = next!;
      providers = [];
      error = null;
    });
    providerRequest++;
    providerDebounce?.cancel();
    await loadProviders(requestPermission: true);
  }

  Future<void> submitChecked() async {
    final originError = authOriginError(base.text);
    if (originError != null) {
      setState(() => error = originError);
      return;
    }
    await submit();
  }

  @override
  Widget build(BuildContext context) {
    String tr(String s) => raftText(context, s);
    if (mode == 'forgot' && forgotSent) {
      // ForgotPasswordPage `sent`: "Check your email" + Back to Sign In.
      return RaftAuthResultPage(
        title: tr('Check your email'),
        descriptionSpan: _sentSpan(context),
        // AuthBrandIntro `mb-5` and the `<div className="mb-6" />` that follows
        // collapse to 24px: 4px on top of the intro's own 20.
        gapBeforeButton: 4,
        buttonLabel: tr('Back to Sign In'),
        buttonIcon: RaftGlyph.arrowLeft,
        onButton: () => switchMode('login'),
        // Native only: Web opens the reset link in the browser; a native
        // client takes the link or code here. Pinned over the page bottom so
        // the Web composition keeps its geometry.
        overlayLink: RaftAuthTextLink(
          label: tr('I have a reset link'),
          onTap: () => switchMode('reset'),
        ),
      );
    }
    if (mode == 'reset' && resetDone) {
      return RaftAuthResultPage(
        title: tr('Password reset'),
        description: tr('Your password has been updated. You can now sign in.'),
        buttonLabel: tr('Back to Sign In'),
        buttonIcon: RaftGlyph.arrowLeft,
        onButton: () => switchMode('login'),
      );
    }
    final t = RaftTokens.of(context);
    final pending = link;
    final failure = pending == null || linkFailure == null
        ? null
        : accountLinkFailureText(context, linkFailure, pending);
    Widget bars(Widget page) =>
        RaftSystemBarSurface(statusBarFallback: t.canvas, child: page);
    final page = AutofillGroup(
      key: ValueKey(mode),
      onDisposeAction: mode == 'login'
          ? AutofillContextAction.commit
          : AutofillContextAction.cancel,
      child: RaftAuthPage(
        mode: authMode,
        busy: busy,
        server: Uri.tryParse(base.text.trim())?.authority ?? base.text.trim(),
        onServer: busy ? null : editServer,
        banner: failure ?? (error == null ? widget.bootError : tr(error!)),
        accountLink: pending == null || mode != 'login'
            ? null
            : RaftAuthAccountLink(
                providerLabel: socialProviderLabel(pending.provider),
                passwordSignIn: pending.passwordSignIn,
                expired: linkFailure == 'pending_link_expired',
                conflict: linkFailure == 'provider_conflict',
                onCancel: busy ? null : cancelLink,
                onRestart: busy ? null : restartLink,
              ),
        notice: notice,
        emailError: emailError == null ? null : tr(emailError!),
        tokenError: tokenError == null ? null : tr(tokenError!),
        passwordError: passwordError == null ? null : tr(passwordError!),
        confirmError: confirmError == null ? null : tr(confirmError!),
        emailField: mode == 'reset'
            ? null
            : RaftTextInput(
                key: const Key('login-email'),
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: mode == 'login'
                    ? const [AutofillHints.username]
                    : null,
                invalid: emailError != null,
                semanticLabel: tr('Email'),
                onChanged: (_) {
                  if (emailError != null) setState(() => emailError = null);
                },
              ),
        tokenField: mode != 'reset' || widget.resetToken != null
            ? null
            : RaftTextInput(
                key: const Key('reset-token'),
                controller: token,
                obscureText: true,
                invalid: tokenError != null,
                semanticLabel: tr('Password reset link or code'),
                onChanged: (_) {
                  if (tokenError != null) setState(() => tokenError = null);
                },
              ),
        passwordField: mode == 'forgot'
            ? null
            : RaftTextInput(
                key: Key(mode == 'reset' ? 'reset-password' : 'login-password'),
                controller: password,
                autofocus: pending != null,
                // Web: plain Input type=password, no visibility toggle
                // (LoginPage.tsx, RegisterPage.tsx).
                obscureText: true,
                autofillHints: mode == 'login'
                    ? const [AutofillHints.password]
                    : null,
                invalid: passwordError != null,
                semanticLabel: tr(
                  mode == 'reset' ? 'New password' : 'Password',
                ),
                hintText: mode == 'login' ? null : tr('Min 8 characters'),
                onChanged: (_) {
                  if (passwordError != null) {
                    setState(() => passwordError = null);
                  }
                },
                onSubmitted: mode == 'reset' ? null : (_) => submitChecked(),
              ),
        confirmField: mode != 'reset'
            ? null
            : RaftTextInput(
                key: const Key('reset-confirm'),
                controller: confirm,
                obscureText: true,
                invalid: confirmError != null,
                semanticLabel: tr('Confirm password'),
                onChanged: (_) {
                  if (confirmError != null) {
                    setState(() => confirmError = null);
                  }
                },
                onSubmitted: (_) => submitChecked(),
              ),
        accepted: accepted,
        onAccepted: (v) => setState(() => accepted = v),
        submitKey: const Key('login-submit'),
        // RegisterPage: disabled={loading || !acceptedLegal}.
        onSubmit: busy || (mode == 'register' && !accepted)
            ? null
            : submitChecked,
        providers: [
          for (final p in providers)
            if (pending == null || pending.providers.contains(p['id']))
              RaftAuthProviderEntry('${p['id']}', '${p['label']}'),
        ],
        onProvider: (id) => social(id),
        onCancelBrowser: broker == null ? null : () => broker!.cancel(),
        // "Browser didn't open?": the launcher failed or nothing came back
        // after a few seconds (desktop). The URL stays out of logs.
        onCopyLink: broker?.helpUrl.value == null
            ? null
            : () => unawaited(
                Clipboard.setData(
                  ClipboardData(text: broker!.helpUrl.value.toString()),
                ),
              ),
        onOpenAgain: broker?.helpUrl.value == null
            ? null
            : () => unawaited(broker!.openAgain()),
        onMode: (next) => switchMode(next.name),
        onTerms: () => managementLaunch('https://raft.build/terms'),
        onPrivacy: () => managementLaunch('https://raft.build/privacy'),
      ),
    );
    // The system-bar overlay fills its parent: a host that gives the page
    // unbounded height (a scroll view) keeps the bare page.
    return LayoutBuilder(
      builder: (context, box) => box.hasBoundedHeight ? bars(page) : page,
    );
  }

  /// pages.forgotPassword.sentTo: the address in `<strong font-mono
  /// text-sm>`.
  InlineSpan _sentSpan(BuildContext context) {
    final template = raftText(
      context,
      "If an account exists with {email}, we've sent a password reset link.",
    );
    final at = template.indexOf('{email}');
    return TextSpan(
      children: [
        TextSpan(text: template.substring(0, at)),
        raftAuthMonoStrongSpan(context, sentEmail),
        TextSpan(text: template.substring(at + '{email}'.length)),
      ],
    );
  }
}
