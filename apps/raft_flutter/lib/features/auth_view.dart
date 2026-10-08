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
          () =>
              providers = managementRows(data['providers'])
                  .where((p) => p['enabled'] == true)
                  .toList(),
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
          accepted,
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
              () => notice = 'If an account exists with that email, a reset link has been sent.',
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

  String get title => switch (mode) {
    'register' => 'Create account',
    'forgot' => 'Reset password',
    'reset' => 'Set new password',
    _ => 'Sign in',
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Raft',
                  style: Theme.of(context).textTheme.displaySmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  raftText(
                    context,
                    'A shared workspace for humans and agents.',
                  ),
                ),
                const SizedBox(height: 24),
                RaftPanel(
                  shadow: true,
                  child: Form(
                    key: form,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            raftText(context, title),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            key: const Key('login-origin'),
                            onChanged: (_) {
                              providerRequest++;
                              setState(() => providers = []);
                              providerDebounce?.cancel();
                              providerDebounce = Timer(
                                const Duration(milliseconds: 400),
                                loadProviders,
                              );
                            },
                            controller: base,
                            enabled: !busy,
                            keyboardType: TextInputType.url,
                            validator: (v) => authOriginError(v ?? ''),
                            decoration: InputDecoration(
                              labelText: raftText(context, 'Server URL'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (mode != 'reset') ...[
                            TextFormField(
                              key: const Key('login-email'),
                              controller: email,
                              enabled: !busy,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.username],
                              validator: (v) => authEmailError(v ?? ''),
                              decoration: InputDecoration(
                                labelText: raftText(context, 'Email'),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (mode == 'reset') ...[
                            TextFormField(
                              key: const Key('reset-token'),
                              controller: token,
                              enabled: !busy,
                              obscureText: true,
                              validator: (v) => v?.trim().isEmpty ?? true
                                  ? 'Enter a password reset link or code.'
                                  : null,
                              decoration: InputDecoration(
                                labelText: raftText(
                                  context,
                                  'Password reset link or code',
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (mode != 'forgot') ...[
                            TextFormField(
                              key: const Key('login-password'),
                              controller: password,
                              enabled: !busy,
                              obscureText: !visible,
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
                              onFieldSubmitted: (_) => submit(),
                              decoration: InputDecoration(
                                labelText: raftText(
                                  context,
                                  mode == 'reset' ? 'New password' : 'Password',
                                ),
                                suffixIcon: IconButton(
                                  tooltip: raftText(
                                    context,
                                    visible ? 'Hide password' : 'Show password',
                                  ),
                                  onPressed: () =>
                                      setState(() => visible = !visible),
                                  icon: Icon(
                                    visible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (mode == 'register' ||
                              (mode == 'login' && providers.isNotEmpty)) ...[
                            CheckboxListTile(
                              key: const Key('register-legal'),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: accepted,
                              onChanged: busy
                                  ? null
                                  : (v) => setState(() => accepted = v == true),
                              title: Text(
                                raftText(
                                  context,
                                  'I accept the terms and privacy policy.',
                                ),
                              ),
                            ),
                            Wrap(
                              children: [
                                TextButton(
                                  onPressed: () => managementLaunch(
                                    'https://raft.build/terms',
                                  ),
                                  child: Text(
                                    raftText(context, 'Terms of service'),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => managementLaunch(
                                    'https://raft.build/privacy',
                                  ),
                                  child: Text(
                                    raftText(context, 'Privacy policy'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (providers.isNotEmpty &&
                              (mode == 'login' || mode == 'register')) ...[
                            for (final provider in providers)
                              TextButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => social(provider['id']),
                                icon: const Icon(Icons.open_in_browser),
                                label: Text(
                                  '${raftText(context, 'Continue with')} ${provider['label']}',
                                ),
                              ),
                            if (broker != null)
                              TextButton(
                                onPressed: () => broker!.cancel(),
                                child: Text(
                                  raftText(context, 'Cancel browser sign-in'),
                                ),
                              ),
                          ],
                          if (error != null || widget.bootError != null)
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                error ?? widget.bootError!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          if (notice != null)
                            Semantics(
                              liveRegion: true,
                              child: Text(raftText(context, notice!)),
                            ),
                          const SizedBox(height: 20),
                          RaftButton(
                            key: const Key('login-submit'),
                            label: raftText(context, title),
                            busy: busy,
                            onPressed: submit,
                          ),
                          if (mode == 'login')
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => switchMode('register'),
                                  child: Text(
                                    raftText(context, 'Create account'),
                                  ),
                                ),
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => switchMode('forgot'),
                                  child: Text(
                                    raftText(context, 'Forgot password?'),
                                  ),
                                ),
                              ],
                            )
                          else
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => switchMode('login'),
                              child: Text(raftText(context, 'Back to sign in')),
                            ),
                          if (mode == 'forgot')
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => switchMode('reset'),
                              child: Text(
                                raftText(context, 'I have a reset link'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Linux · Android · macOS',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
