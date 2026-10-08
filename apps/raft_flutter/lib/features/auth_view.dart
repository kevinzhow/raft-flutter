import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../platform/oauth_broker.dart';

import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart' hide RaftFieldRecipe;
import 'package:raft_ui/recipes.dart';

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

  // Web copy (packages/web/src/i18n/messages/en.ts, pages.login/register/
  // forgotPassword/resetPassword).
  String get title => switch (mode) {
    'register' => 'Create your account',
    'forgot' => 'Reset Password',
    'reset' => 'Set New Password',
    _ => 'Sign In',
  };
  String get submitLabel => switch (mode) {
    'register' => busy ? 'Creating account…' : 'Continue',
    'forgot' => busy ? 'Sending…' : 'Send Reset Link',
    'reset' => busy ? 'Resetting…' : 'Reset Password',
    _ => busy ? 'Signing in…' : 'Sign In',
  };

  /// Platform exception (native client only): the Web page is served by its
  /// own origin, a native client must be told which server to use. The origin
  /// is edited from the brand bar instead of adding a form row, so the Web
  /// card keeps its exact layout.
  Future<void> editServer() async {
    if (busy) return;
    String? next;
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
    final socialModes = mode == 'login' || mode == 'register';
    final banner = error ?? widget.bootError;
    return AuthBrandShell(
      server: Uri.tryParse(base.text.trim())?.authority ?? base.text.trim(),
      onServer: busy ? null : editServer,
      child: Form(
        key: form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthIntro(
                title: tr(title),
                description: mode == 'forgot'
                    ? tr(
                        'Enter your email and we\'ll send you a link to reset your password.',
                      )
                    : null,
              ),
              if (banner != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16), // mb-4
                  child: AuthBanner(text: banner),
                ),
              if (notice != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AuthBanner(text: tr(notice!), info: true),
                ),
              // <form className="space-y-4">
              if (mode != 'reset')
                AuthFieldBlock(
                  label: tr('Email'),
                  child: TextFormField(
                    key: const Key('login-email'),
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    validator: (v) => authEmailError(v ?? ''),
                    style: _authFieldText(t),
                    decoration: const InputDecoration(),
                  ),
                ),
              if (mode == 'reset')
                AuthFieldBlock(
                  label: tr('Password reset link or code'),
                  child: TextFormField(
                    key: const Key('reset-token'),
                    controller: token,
                    obscureText: true,
                    validator: (v) => v?.trim().isEmpty ?? true
                        ? 'Enter a password reset link or code.'
                        : null,
                    style: _authFieldText(t),
                  ),
                ),
              if (mode != 'forgot') ...[
                const SizedBox(height: 16),
                AuthFieldBlock(
                  label: tr(mode == 'reset' ? 'New password' : 'Password'),
                  child: TextFormField(
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
                    style: _authFieldText(t),
                    decoration: InputDecoration(
                      hintText: mode == 'login' ? null : tr('Min 8 characters'),
                    ),
                  ),
                ),
              ],
              if (mode == 'register') ...[
                const SizedBox(height: 16),
                _AuthLegalCheckbox(
                  checked: accepted,
                  onChanged: busy ? null : (v) => setState(() => accepted = v),
                ),
              ],
              const SizedBox(height: 16),
              _AuthSubmit(
                key: const Key('login-submit'),
                label: tr(submitLabel),
                // RegisterPage: disabled={loading || !acceptedLegal}.
                onPressed: busy || (mode == 'register' && !accepted)
                    ? null
                    : submitChecked,
              ),
              if (providers.isNotEmpty && socialModes) ...[
                _AuthOrDivider(label: tr('or')),
                for (final (i, provider) in providers.indexed) ...[
                  if (i > 0) const SizedBox(height: 8), // space-y-2
                  _AuthSocialButton(
                    provider: '${provider['id']}',
                    label: tr('Continue with ${provider['label']}'),
                    // Web social buttons are never gated on the checkbox
                    // (RegisterPage handleSocialLogin); login shows
                    // pages.login.legalAgreement instead.
                    // Web only disables the submit button while loading.
                    onPressed: () => social('${provider['id']}'),
                  ),
                ],
                if (broker != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: AuthTextLink(
                      label: tr('Cancel browser sign-in'),
                      onTap: () => broker!.cancel(),
                    ),
                  ),
                ],
              ],
              if (mode == 'login') ...[
                const SizedBox(height: 16), // mt-4
                _AuthLegalNotice(
                  onTerms: () => managementLaunch('https://raft.build/terms'),
                  onPrivacy: () =>
                      managementLaunch('https://raft.build/privacy'),
                ),
                const SizedBox(height: 12), // mt-3
                Center(
                  child: AuthTextLink(
                    label: tr('Forgot password?'),
                    onTap: () => switchMode('forgot'),
                  ),
                ),
                const SizedBox(height: 8), // mt-2
                _AuthPrompt(
                  prefix: tr('No account?'),
                  link: tr('Create one'),
                  onTap: () => switchMode('register'),
                ),
              ] else if (mode == 'register') ...[
                const SizedBox(height: 16), // mt-4
                _AuthPrompt(
                  prefix: tr('Already have an account?'),
                  link: tr('Sign in'),
                  onTap: () => switchMode('login'),
                ),
              ] else ...[
                const SizedBox(height: 16),
                if (mode == 'forgot') ...[
                  Center(
                    child: AuthTextLink(
                      label: tr('I have a reset link'),
                      onTap: busy ? null : () => switchMode('reset'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Center(
                  child: AuthTextLink(
                    label: tr('Back to sign in'),
                    onTap: busy ? null : () => switchMode('login'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _authFieldText(RaftTokens t) => t.fieldStyle;

/// AuthBrandShell (packages/web/src/components/brand/AuthBrandShell.tsx):
/// `bg-layer-canvas font-display safe-top safe-bottom`, brand top bar, then
/// `flex min-h-0 flex-1 items-center justify-center px-5 pb-10 pt-10`, content
/// `w-full max-w-md`. With a bounded height the stack is `min-h-full` (content
/// centred); in an unbounded host it shrink-wraps like CSS `min-h-full` of an
/// auto-height parent.
class AuthBrandShell extends StatelessWidget {
  const AuthBrandShell({
    super.key,
    required this.child,
    this.server,
    this.onServer,
    this.padding = const EdgeInsets.fromLTRB(20, 40, 20, 40),
  });
  final Widget child;
  final String? server;
  final VoidCallback? onServer;

  /// `px-5 pb-10 pt-10` (AuthBrandShell); OnboardingCreateShell's form panel
  /// is `px-6 py-10`.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final safe = MediaQuery.paddingOf(context);
    final content = Padding(
      padding: padding,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448), // max-w-md
          child: child,
        ),
      ),
    );
    return Material(
      color: t.canvas,
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontFamily: t.headingFont,
          color: t.semantic.foreground,
        ),
        child: Padding(
          // `safe-top`; `safe-bottom` = inset + 1rem (index.css .safe-bottom).
          padding: EdgeInsets.only(top: safe.top, bottom: safe.bottom + 16),
          child: LayoutBuilder(
            builder: (context, box) {
              final bar = AuthBrandTopBar(server: server, onServer: onServer);
              if (!box.hasBoundedHeight) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [bar, content],
                );
              }
              final barHeight = t.brutal
                  ? RaftMetrics.brutalPanelHeader
                  : RaftMetrics.panelHeader;
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    bar,
                    // `flex-1 items-center justify-center` under `min-h-full`.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (box.maxHeight - barHeight).clamp(
                          0.0,
                          double.infinity,
                        ),
                      ),
                      child: Align(child: content),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// AUTH_BRAND_TOP_BAR_CLASS: `h-panel-header border-b border-line-hairline
/// bg-layer-panel px-4 theme-brutal:border-b-2 theme-brutal:border-black
/// theme-brutal:bg-soft-signal`, RaftBrandLockup `h-5 w-auto`.
class AuthBrandTopBar extends StatelessWidget {
  const AuthBrandTopBar({super.key, this.server, this.onServer});

  /// Native-only server origin control; null hides it (onboarding pages).
  final String? server;
  final VoidCallback? onServer;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      // --shell-header-height (62 brutal / 56 elegant); border-box.
      height: t.brutal
          ? RaftMetrics.brutalPanelHeader
          : RaftMetrics.panelHeader,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: t.brutal ? t.product.softSignal : t.panel,
        border: Border(
          bottom: t.brutal
              ? const BorderSide(color: Color(0xFF000000), width: 2)
              : BorderSide(color: t.semantic.lineHairline),
        ),
      ),
      child: Row(
        children: [
          const RaftBrandMark(RaftBrandMarkKind.logo, height: 20),
          const Spacer(),
          // Native-only server origin control (see _AuthState.editServer).
          if (server != null)
            Semantics(
              button: true,
              label: raftText(context, 'Server URL'),
              child: AuthTextLink(
                key: const Key('login-server'),
                label: server!,
                onTap: onServer,
                small: true,
              ),
            ),
        ],
      ),
    );
  }
}

/// AuthBrandIntro: `mb-5 text-center`; icon `mx-auto mb-4 size-9`; h1
/// `text-xl font-bold`; description `mt-2 text-sm text-foreground-muted`.
class AuthIntro extends StatelessWidget {
  const AuthIntro({super.key, required this.title, this.description});
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          RaftBrandMark(
            RaftBrandMarkKind.icon,
            height: 36,
            width: 36,
            invert: t.dark,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: RaftTypography.heading(
              t,
              size: 20,
              line: 28,
            ).copyWith(color: t.semantic.foreground),
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: RaftTypography.heading(
                t,
                size: 14,
                line: 20,
                weight: FontWeight.w400,
              ).copyWith(color: t.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// FormField labelStyle="plain" over raft-ui Field: label `mb-1 block text-sm`
/// (field label recipe: 14/20, 700 brutal / 500 elegant, foreground), Field
/// `gap-1` before the control.
class AuthFieldBlock extends StatelessWidget {
  const AuthFieldBlock({
    super.key,
    required this.label,
    required this.child,
    this.after,
    this.error,
    this.surface = true,
  });
  final String label;
  final Widget child;

  /// Children rendered after the control inside the field (helper `<p>`s).
  final List<Widget>? after;

  /// FieldError `mt-1` (field recipe error slot).
  final String? error;

  /// Wrap [child] in the shared field frame (false when the child draws its
  /// own frame, e.g. an input group).
  final bool surface;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = RaftRecipeTokens(t);
    final style = RaftFieldRecipe.resolve(
      theme: t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant,
      tokens: tokens,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: style.label.textStyle(tokens)),
        SizedBox(height: 4 + (style.root.rowGap ?? 0)),
        surface ? RaftFieldSurface(child: child) : child,
        // Field `gap` separates every direct child of the field.
        if (after != null) ...[
          SizedBox(height: style.root.rowGap ?? 0),
          ...after!,
        ],
        if (error != null) ...[
          SizedBox(height: (style.root.rowGap ?? 0) + 4),
          Semantics(
            liveRegion: true,
            child: Text(error!, style: style.error.textStyle(tokens)),
          ),
        ],
      ],
    );
  }
}

/// `<Button type="submit" size="lg" variant="accent" className="w-full">`.
class _AuthSubmit extends StatelessWidget {
  const _AuthSubmit({super.key, required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => AuthWideButton(
    onPressed: onPressed,
    variant: RaftControlVariant.accent,
    child: Text(label, maxLines: 1),
  );
}

/// `size="lg" className="w-full"` raft-ui Button. The layout box is the CSS
/// box (lg height), as on Web; the loading state is the disabled label
/// ("Signing in…"), not a spinner.
class AuthWideButton extends StatelessWidget {
  const AuthWideButton({
    super.key,
    required this.child,
    required this.variant,
    this.onPressed,
  });
  final Widget child;
  final RaftControlVariant variant;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final height = _lgHeight(context);
    return LayoutBuilder(
      builder: (context, box) => RaftControl(
        onPressed: onPressed,
        variant: variant,
        visualHeight: height,
        visualWidth: box.maxWidth,
        minimumTargetSize: height,
        child: child,
      ),
    );
  }
}

double _lgHeight(BuildContext context) => RaftButtonRecipe.resolve(
  theme: RaftTokens.of(context).brutal
      ? RaftRecipeTheme.brutal
      : RaftRecipeTheme.elegant,
  size: RaftButtonRecipeSize.lg,
).root.height!;

/// `my-4 flex items-center gap-3`; rules `h-0.5 flex-1 bg-line-strong
/// theme-brutal:bg-black`; label `text-xs font-bold uppercase tracking-widest
/// text-foreground-muted theme-brutal:text-black/45`.
class _AuthOrDivider extends StatelessWidget {
  const _AuthOrDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rule = Expanded(
      child: Container(
        height: 2,
        color: t.brutal ? const Color(0xFF000000) : t.semantic.lineStrong,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          rule,
          const SizedBox(width: 12),
          Text(
            label.toUpperCase(),
            style: RaftTypography.heading(t, size: 12, line: 16).copyWith(
              letterSpacing: 12 * .1,
              color: t.brutal ? const Color(0x73000000) : t.muted,
            ),
          ),
          const SizedBox(width: 12),
          rule,
        ],
      ),
    );
  }
}

/// SocialProviderButton: `<Button variant="outline" size="lg" className="w-full
/// gap-3">` with the provider logo (`size-5`) and "Continue with {provider}".
class _AuthSocialButton extends StatelessWidget {
  const _AuthSocialButton({
    required this.provider,
    required this.label,
    this.onPressed,
  });
  final String provider, label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final mark = switch (provider) {
      'google' => RaftBrandMarkKind.google,
      'github' => RaftBrandMarkKind.github,
      _ => RaftBrandMarkKind.apple,
    };
    return AuthWideButton(
      onPressed: onPressed,
      variant: RaftControlVariant.outline,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RaftBrandMark(
            mark,
            height: 20,
            width: 20,
            invert: t.dark && mark != RaftBrandMarkKind.google,
          ),
          const SizedBox(width: 12), // gap-3
          Flexible(child: Text(label, maxLines: 1)),
        ],
      ),
    );
  }
}

/// LegalAcceptanceCheckbox: `flex items-start gap-2.5 text-sm`, Checkbox
/// size md `mt-0.5`, copy `leading-5 text-foreground-muted`, links `font-bold
/// text-foreground-strong underline`.
class _AuthLegalCheckbox extends StatefulWidget {
  const _AuthLegalCheckbox({required this.checked, required this.onChanged});
  final bool checked;
  final ValueChanged<bool>? onChanged;
  @override
  State<_AuthLegalCheckbox> createState() => _AuthLegalCheckboxState();
}

class _AuthLegalCheckboxState extends State<_AuthLegalCheckbox> {
  late final terms = TapGestureRecognizer()
    ..onTap = () => managementLaunch('https://raft.build/terms');
  late final privacy = TapGestureRecognizer()
    ..onTap = () => managementLaunch('https://raft.build/privacy');

  @override
  void dispose() {
    terms.dispose();
    privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final base = RaftTypography.heading(
      t,
      size: 14,
      line: 20,
      weight: FontWeight.w400,
    ).copyWith(color: t.muted);
    final link = base.copyWith(
      fontWeight: FontWeight.w700,
      color: t.strong,
      decoration: TextDecoration.underline,
    );
    final size = RaftCheckboxRecipe.resolve(
      theme: t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant,
      size: RaftCheckboxRecipeSize.md,
    ).root.width!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2), // mt-0.5
          child: SizedBox.square(
            dimension: size,
            child: Checkbox(
              key: const Key('register-legal'),
              value: widget.checked,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              onChanged: widget.onChanged == null
                  ? null
                  : (v) => widget.onChanged!(v == true),
            ),
          ),
        ),
        const SizedBox(width: 10), // gap-2.5
        Expanded(
          child: Text.rich(
            TextSpan(
              style: base,
              children: [
                TextSpan(text: '${tr('I agree to the')} '),
                TextSpan(
                  text: tr('Terms of Service'),
                  style: link,
                  recognizer: terms,
                ),
                TextSpan(text: ' ${tr('and acknowledge the')} '),
                TextSpan(
                  text: tr('Privacy Policy'),
                  style: link,
                  recognizer: privacy,
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// pages.login.legalAgreement: `mt-4 text-center text-xs leading-5
/// text-foreground-muted theme-brutal:text-black/60`, links `underline`.
class _AuthLegalNotice extends StatefulWidget {
  const _AuthLegalNotice({required this.onTerms, required this.onPrivacy});
  final VoidCallback onTerms, onPrivacy;
  @override
  State<_AuthLegalNotice> createState() => _AuthLegalNoticeState();
}

class _AuthLegalNoticeState extends State<_AuthLegalNotice> {
  late final terms = TapGestureRecognizer()..onTap = widget.onTerms;
  late final privacy = TapGestureRecognizer()..onTap = widget.onPrivacy;

  @override
  void dispose() {
    terms.dispose();
    privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final base = RaftTypography.heading(
      t,
      size: 12,
      line: 20,
      weight: FontWeight.w400,
    ).copyWith(color: t.brutal ? const Color(0x99000000) : t.muted);
    final link = base.copyWith(decoration: TextDecoration.underline);
    return Text.rich(
      textAlign: TextAlign.center,
      TextSpan(
        style: base,
        children: [
          TextSpan(text: '${tr('By continuing, you agree to the')} '),
          TextSpan(
            text: tr('Terms of Service'),
            style: link,
            recognizer: terms,
          ),
          TextSpan(text: ' ${tr('and')} '),
          TextSpan(
            text: tr('Privacy Policy'),
            style: link,
            recognizer: privacy,
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}

/// TextLink (packages/web/src/components/ui/TextLink.tsx): `muted` =
/// `text-foreground-muted underline`, `primary` = `font-bold text-accent-strong
/// underline theme-brutal:text-brutal-pink`; `disabled:opacity-50`. Used in
/// `text-sm` paragraphs.
class AuthTextLink extends StatelessWidget {
  const AuthTextLink({
    super.key,
    required this.label,
    this.onTap,
    this.small = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Opacity(
      opacity: onTap == null ? .5 : 1,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Text(label, style: _linkStyle(t, size: small ? 12 : 14)),
      ),
    );
  }
}

TextStyle _linkStyle(RaftTokens t, {bool primary = false, double size = 14}) =>
    RaftTypography.heading(
      t,
      size: size,
      line: size == 14 ? 20 : 16,
      weight: primary ? FontWeight.w700 : FontWeight.w400,
    ).copyWith(
      color: primary
          ? (t.brutal ? t.product.brutalPink : t.semantic.accentStrong)
          : t.muted,
      decoration: TextDecoration.underline,
      decorationColor: primary
          ? (t.brutal ? t.product.brutalPink : t.semantic.accentStrong)
          : t.muted,
    );

/// `<p className="mt-4 text-center text-sm">` prompt + primary TextLink.
class _AuthPrompt extends StatefulWidget {
  const _AuthPrompt({required this.prefix, required this.link, this.onTap});
  final String prefix, link;
  final VoidCallback? onTap;
  @override
  State<_AuthPrompt> createState() => _AuthPromptState();
}

class _AuthPromptState extends State<_AuthPrompt> {
  final tap = TapGestureRecognizer();

  @override
  void dispose() {
    tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    tap.onTap = widget.onTap;
    return Text.rich(
      textAlign: TextAlign.center,
      TextSpan(
        style: RaftTypography.heading(
          t,
          size: 14,
          line: 20,
          weight: FontWeight.w400,
        ).copyWith(color: t.semantic.foreground),
        children: [
          TextSpan(text: '${widget.prefix} '),
          TextSpan(
            text: widget.link,
            style: _linkStyle(t, primary: true),
            recognizer: tap,
          ),
        ],
      ),
    );
  }
}

/// `<Banner intent="warning" className="mb-4 font-bold">` (raft-ui banner).
class AuthBanner extends StatelessWidget {
  const AuthBanner({super.key, required this.text, this.info = false});
  final String text;
  final bool info;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = RaftRecipeTokens(t);
    final s = RaftBannerRecipe.resolve(
      theme: t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant,
      status: info
          ? RaftBannerRecipeStatus.info
          : RaftBannerRecipeStatus.warning,
      tokens: tokens,
    );
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: s.root.padding,
        decoration: s.root.decoration(tokens),
        child: Text(
          text,
          style: s.root.textStyle(tokens).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
