import 'dart:async';

import 'package:flutter/material.dart';

import '../platform/oauth_broker.dart';

import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'management_support.dart';

String? authEmailError(String value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
    ? null
    : 'Enter a valid email address.';
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
  });
  final Future<void> Function(String, String, String, bool)? onOAuth;
  final RaftClient Function(String)? anonymousClientFactory;
  final String origin;
  final String? bootError;
  final Future<void> Function(String, String, String) onLogin;
  final Future<void> Function(String, String, String, bool) onRegister;
  @override
  State<AuthView> createState() => _AuthState();
}

class _AuthState extends State<AuthView> {
  final form = GlobalKey<FormState>();
  late final base = TextEditingController(text: widget.origin);
  final email = TextEditingController(),
      password = TextEditingController(),
      token = TextEditingController();
  bool busy = false, visible = false, accepted = false;
  List<Map<String, dynamic>> providers = [];
  NativeOAuthBroker? broker;
  Timer? providerDebounce;
  int providerRequest = 0;
  @override
  void initState() {
    super.initState();
    loadProviders();
  }

  Future<void> loadProviders() async {
    final request = ++providerRequest;
    if (widget.onOAuth == null || authOriginError(base.text) != null) {
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
      final data = await client.request(
        'GET',
        '/auth/providers',
        query: {'platform': 'mobile'},
        authorized: false,
      );
      if (mounted && request == providerRequest) {
        setState(
          () => providers = managementRows(
            data['providers'],
          ).where((p) => p['enabled'] == true).toList(),
        );
      }
    } catch (_) {
      if (mounted && request == providerRequest) setState(() => providers = []);
    } finally {
      await client.dispose();
    }
  }

  Future<void> social(String provider) async {
    if (busy || widget.onOAuth == null || authOriginError(base.text) != null) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    final client =
        widget.anonymousClientFactory?.call(base.text.trim()) ??
        RaftClient(
          origin: base.text.trim(),
          sessionStore: MemorySessionStore(),
        );
    final active = NativeOAuthBroker();
    broker = active;
    try {
      final handoff = await active.begin(client, provider);
      if (mounted) {
        await widget.onOAuth!(
          base.text.trim(),
          handoff.code,
          handoff.verifier,
          // Login: "By continuing, you agree to the Terms of Service and
          // Privacy Policy" (pages.login.legalAgreement); register: checkbox.
          mode == 'login' || accepted,
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      await active.cancel();
      await client.dispose();
      broker = null;
      if (mounted) setState(() => busy = false);
    }
  }

  String mode = 'login';
  String? error, notice;
  @override
  void dispose() {
    providerDebounce?.cancel();
    unawaited(broker?.cancel() ?? Future<void>.value());
    base.dispose();
    email.dispose();
    password.dispose();
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
      return await client.request('POST', path, data: data, authorized: false);
    } finally {
      await client.dispose();
    }
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    if (mode == 'register' && !accepted) {
      setState(
        () =>
            error = 'Accept the terms and privacy policy to create an account.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      switch (mode) {
        case 'login':
          await widget.onLogin(
            base.text.trim(),
            email.text.trim(),
            password.text,
          );
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
            setState(
              () => notice =
                  'If an account exists with that email, a reset link has been sent.',
            );
          }
        case 'reset':
          final code = authLinkToken(token.text.trim());
          if (code.isEmpty) {
            throw const RaftApiException(
              'Enter a password reset link or code.',
            );
          }
          await anonymous('/auth/reset-password', {
            'token': code,
            'password': password.text,
          });
          if (mounted) {
            setState(() {
              mode = 'login';
              password.clear();
              token.clear();
              notice = 'Password reset. Sign in with your new password.';
            });
          }
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void switchMode(String next) {
    if (busy) return;
    setState(() {
      mode = next;
      error = null;
      notice = null;
      password.clear();
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
    await showDialog<void>(
      context: context,
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
    if (next == null || next == base.text.trim()) return;
    setState(() {
      base.text = next!;
      providers = [];
    });
    providerRequest++;
    providerDebounce?.cancel();
    await loadProviders();
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
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    return Form(
      key: form,
      child: AutofillGroup(
        child: RaftAuthPage(
          mode: authMode,
          busy: busy,
          server: Uri.tryParse(base.text.trim())?.authority ?? base.text.trim(),
          onServer: busy ? null : editServer,
          banner: error ?? widget.bootError,
          notice: notice,
          emailField: mode == 'reset'
              ? null
              : TextFormField(
                  key: const Key('login-email'),
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  validator: (v) => authEmailError(v ?? ''),
                  style: t.fieldStyle,
                ),
          tokenField: mode != 'reset'
              ? null
              : TextFormField(
                  key: const Key('reset-token'),
                  controller: token,
                  obscureText: true,
                  validator: (v) => v?.trim().isEmpty ?? true
                      ? 'Enter a password reset link or code.'
                      : null,
                  style: t.fieldStyle,
                ),
          passwordField: mode == 'forgot'
              ? null
              : TextFormField(
                  key: const Key('login-password'),
                  controller: password,
                  // Web: plain Input type=password, no visibility toggle
                  // (LoginPage.tsx:96-108, RegisterPage.tsx).
                  obscureText: true,
                  obscuringCharacter: '•',
                  autofillHints: [
                    mode == 'login'
                        ? AutofillHints.password
                        : AutofillHints.newPassword,
                  ],
                  validator: (v) => v == null || v.isEmpty
                      ? 'Enter your password.'
                      : mode != 'login' && v.length < 8
                      ? 'Use at least 8 characters.'
                      : null,
                  onFieldSubmitted: (_) => submitChecked(),
                  style: t.fieldStyle,
                  decoration: InputDecoration(
                    hintText: mode == 'login' ? null : tr('Min 8 characters'),
                  ),
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
              RaftAuthProviderEntry('${p['id']}', '${p['label']}'),
          ],
          onProvider: (id) => social(id),
          onCancelBrowser: broker == null ? null : () => broker!.cancel(),
          onMode: (next) => switchMode(next.name),
          onTerms: () => managementLaunch('https://raft.build/terms'),
          onPrivacy: () => managementLaunch('https://raft.build/privacy'),
        ),
      ),
    );
  }
}
