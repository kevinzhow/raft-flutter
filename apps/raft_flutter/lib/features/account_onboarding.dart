import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'auth_view.dart';

bool accountNeedsProfile(RaftRecord? user) =>
    user != null &&
    (user.string('name').isEmpty ||
        user.string('name').toLowerCase().startsWith('pending_'));
bool accountNeedsOnboarding(RaftRecord? user) =>
    user != null &&
    (user.json['emailVerified'] != true || accountNeedsProfile(user));
String? accountUsernameError(String value) {
  if (value.trim().length < 5 || value.trim().length > 32) {
    return 'Use between 5 and 32 characters.';
  }
  if (value.trim().toLowerCase().startsWith('pending_')) {
    return 'This username is reserved.';
  }
  if (!RegExp(
    r'^[\p{L}][\p{L}\p{N}_-]*$',
    unicode: true,
  ).hasMatch(value.trim())) {
    return 'Use letters, numbers, hyphens or underscores.';
  }
  return null;
}

class AccountMediaActions {
  static Future<void> uploadAvatar(RaftClient client) async {
    final generation = client.generation;
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Avatar image',
          extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
          mimeTypes: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
        ),
      ],
    );
    if (file == null) return;
    if (client.generation != generation) {
      throw const RaftApiException(
        'The active account changed. Choose the image again.',
      );
    }
    final length = await file.length();
    if (length > 5 * 1024 * 1024) {
      throw const RaftApiException('Avatar image must be 5 MB or smaller.');
    }
    final extension = file.name.split('.').last.toLowerCase();
    final mime = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
    }[extension];
    if (mime == null) {
      throw const RaftApiException('Choose a JPEG, PNG, GIF or WebP image.');
    }
    final bytes = await file.readAsBytes();
    if (client.generation != generation) {
      throw const RaftApiException(
        'The active account changed. Choose the image again.',
      );
    }
    await client.post(
      '/auth/me/avatar',
      data: FormData.fromMap({
        'avatar': MultipartFile.fromBytes(
          bytes,
          filename: file.name,
          contentType: DioMediaType.parse(mime),
        ),
      }),
    );
    await client.reloadUser();
  }

  static Future<void> removeAvatar(RaftClient client) async {
    await client.patch('/auth/me', data: {'avatarUrl': null});
    await client.reloadUser();
  }
}

/// Email and identity gates precede workspace requests, matching the Web flow.
class AccountOnboardingView extends StatefulWidget {
  const AccountOnboardingView({
    super.key,
    required this.client,
    required this.onComplete,
    required this.onSignOut,
    this.showSessionFooter = true,
  });
  final RaftClient client;
  final Future<void> Function() onComplete, onSignOut;

  /// OnboardingCreateShell `showSessionFooter` ("Signed in as … Log out").
  /// Web fixture previews opt out; the app always shows it.
  final bool showSessionFooter;
  @override
  State<AccountOnboardingView> createState() => _OnboardingState();
}

class _OnboardingState extends State<AccountOnboardingView> {
  final form = GlobalKey<FormState>();
  final username = TextEditingController(),
      displayName = TextEditingController(),
      token = TextEditingController();
  StreamSubscription<RaftEvent>? events;
  bool busy = false, displayNameEdited = false;
  String? error, notice, handleError, displayNameError;
  final usernameFocus = FocusNode();
  RaftClient get client => widget.client;
  @override
  void initState() {
    super.initState();
    events = client.events.listen((event) {
      if (event.name == 'account:updated' && mounted) setState(() {});
    });
    final suggested = client.user?.string('profileSetupSuggestedHandle') ?? '';
    if (suggested.isNotEmpty) {
      username.text = suggested;
      displayName.text = suggested;
    }
    usernameFocus.addListener(() {
      if (!usernameFocus.hasFocus) unawaited(usernameBlur());
    });
  }

  /// AccountIdentitySetupPage.handleUsernameBlur: format check first, then the
  /// advisory `/auth/me/username-available` precheck.
  Future<void> usernameBlur() async {
    final candidate = username.text.trim();
    final format = accountUsernameError(candidate);
    if (format != null) {
      setState(() => handleError = format);
      return;
    }
    try {
      final data = await client.get(
        '/auth/me/username-available',
        query: {'name': candidate},
      );
      if (!mounted || username.text.trim() != candidate) return;
      // Web: `if (!data.available)` — any body without available:true.
      if (data != null && (data is! Map || data['available'] != true)) {
        final message = data is Map ? data['message'] : null;
        setState(
          () => handleError = message is String
              ? message
              : raftText(context, 'This username is already taken.'),
        );
      }
    } catch (_) {
      // Best-effort precheck; submit validates authoritatively.
    }
  }

  @override
  void dispose() {
    events?.cancel();
    username.dispose();
    displayName.dispose();
    usernameFocus.dispose();
    token.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    final generation = client.generation;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await action();
      if (client.generation == generation &&
          !accountNeedsOnboarding(client.user)) {
        await widget.onComplete();
      }
    } catch (e) {
      if (mounted && client.generation == generation) {
        setState(() => error = '$e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verify() async {
    final code = authLinkToken(token.text.trim());
    if (code.isEmpty) {
      throw const RaftApiException(
        'Enter the verification link or code from your email.',
      );
    }
    await client.request(
      'POST',
      '/auth/verify-email',
      authorized: false,
      data: {'token': code},
    );
    await client.reloadUser();
    token.clear();
  }

  Future<void> completeProfile() async {
    final nameError = displayName.text.trim().isEmpty
        ? 'Enter a display name.'
        : null;
    final userError = accountUsernameError(username.text);
    setState(() {
      displayNameError = nameError;
      handleError = userError;
    });
    if (nameError != null || userError != null) return;
    final available = await client.get(
      '/auth/me/username-available',
      query: {'name': username.text.trim()},
    );
    if (available['available'] != true) {
      throw RaftApiException(
        available['message'] ?? 'This username is unavailable.',
      );
    }
    await client.post(
      '/auth/me/complete-profile',
      data: {
        'name': username.text.trim(),
        'displayName': displayName.text.trim(),
      },
    );
    await client.reloadUser();
  }

  @override
  Widget build(BuildContext context) {
    final verified = client.user?.json['emailVerified'] == true;
    final profile = verified && accountNeedsProfile(client.user);
    String tr(String s) => raftText(context, s);
    final t = RaftTokens.of(context);
    final muted = RaftTypography.heading(
      t,
      size: 14,
      line: 20,
      weight: FontWeight.w400,
    ).copyWith(color: t.muted);
    return AuthBrandShell(
      // OnboardingCreateShell form panel: `px-6 py-10`, column `gap-4`.
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _gap16([
            AuthIntro(
              title: tr(
                profile || verified
                    ? 'Set up your account'
                    : 'Verify your email',
              ),
            ),
            if (error != null) AuthBanner(text: error!),
            if (notice != null) AuthBanner(text: tr(notice!), info: true),
            if (!verified) ...[
              Text(
                '${tr('Check the verification email sent to')} ${client.user?.string('email') ?? ''}.',
                style: muted,
              ),
              AuthFieldBlock(
                label: tr('Verification link or code'),
                child: TextField(
                  key: const Key('verification-token'),
                  controller: token,
                  obscureText: true,
                  style: t.fieldStyle,
                  onSubmitted: (_) => run(verify),
                ),
              ),
              AuthWideButton(
                variant: RaftControlVariant.accent,
                onPressed: busy ? null : () => run(verify),
                child: Text(tr('Verify email')),
              ),
              Center(
                child: AuthTextLink(
                  label: tr('Resend verification email'),
                  onTap: busy
                      ? null
                      : () => run(() async {
                          await client.post('/auth/resend-verification');
                          if (mounted) {
                            setState(() => notice = 'Verification email sent.');
                          }
                        }),
                ),
              ),
              Center(
                child: AuthTextLink(
                  label: tr('I have verified my email'),
                  onTap: busy ? null : () => run(client.reloadUser),
                ),
              ),
            ] else if (profile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _gap16([
                  AuthFieldBlock(
                    label: tr('Username'),
                    surface: false,
                    error: handleError,
                    after: [
                      const SizedBox(height: 4), // mt-1
                      Text(
                        tr(
                          "Your unique name for @mentions and links. It can't be changed later.",
                        ),
                        style: _helper(t, t.muted),
                      ),
                    ],
                    child: _HandleInputGroup(
                      child: TextFormField(
                        key: const Key('onboarding-username'),
                        controller: username,
                        focusNode: usernameFocus,
                        style: t.fieldStyle,
                        autofillHints: const [AutofillHints.username],
                        decoration: InputDecoration(
                          hintText: tr('alexchen'),
                          // Input inside the group: `border-0` keeps only
                          // the input recipe padding (py-2 px-3).
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                        ),
                        onChanged: (value) {
                          final next = value.replaceFirst(RegExp(r'^@+'), '');
                          if (next != value) username.text = next;
                          setState(() {
                            handleError = null;
                            // Mirror into the display name until edited.
                            if (!displayNameEdited) {
                              displayName.text = next;
                              displayNameError = null;
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  AuthFieldBlock(
                    label: tr('Display name'),
                    error: displayNameError,
                    after: [
                      const SizedBox(height: 4),
                      Text(
                        tr(
                          'How your name appears in messages. Change this anytime.',
                        ),
                        style: _helper(t, t.semantic.foregroundHint),
                      ),
                    ],
                    child: TextFormField(
                      key: const Key('onboarding-display-name'),
                      controller: displayName,
                      style: t.fieldStyle,
                      autofillHints: const [AutofillHints.name],
                      decoration: InputDecoration(hintText: tr('Alex Chen')),
                      onChanged: (_) => setState(() {
                        displayNameEdited = true;
                        displayNameError = null;
                      }),
                    ),
                  ),
                  _AvatarField(
                    client: client,
                    busy: busy,
                    onUpload: () =>
                        run(() => AccountMediaActions.uploadAvatar(client)),
                  ),
                  AuthWideButton(
                    key: const Key('onboarding-complete'),
                    variant: RaftControlVariant.accent,
                    onPressed: busy ? null : () => run(completeProfile),
                    child: Text(tr(busy ? 'Saving identity…' : 'Continue')),
                  ),
                ]),
              ),
            if (widget.showSessionFooter)
              _SessionFooter(
                user: client.user,
                onSignOut: busy ? null : widget.onSignOut,
              ),
          ]),
        ),
      ),
    );
  }
}

List<Widget> _gap16(List<Widget> children) => [
  for (final (i, child) in children.indexed) ...[
    if (i > 0) const SizedBox(height: 16),
    child,
  ],
];

/// `mt-1 text-xs` helper paragraph.
TextStyle _helper(RaftTokens t, Color color) => RaftTypography.heading(
  t,
  size: 12,
  line: 16,
  weight: FontWeight.w400,
).copyWith(color: color);

/// AccountIdentitySetupPage username group: `flex items-stretch
/// overflow-hidden rounded-md border border-line-field bg-layer-panel
/// theme-brutal:rounded-none theme-brutal:border-2 theme-brutal:border-black
/// theme-brutal:bg-white theme-brutal:shadow-brutal-sm`, "@" addon `border-r
/// border-line-hairline bg-soft-signal px-3 font-mono text-base font-bold
/// text-foreground-muted theme-brutal:border-r-2 theme-brutal:border-black
/// theme-brutal:text-black/60`.
class _HandleInputGroup extends StatelessWidget {
  const _HandleInputGroup({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final border = t.brutal
        ? const BorderSide(color: Color(0xFF000000), width: 2)
        : BorderSide(color: t.semantic.lineField);
    return Container(
      decoration: BoxDecoration(
        color: t.brutal ? const Color(0xFFFFFFFF) : t.panel,
        border: Border.fromBorderSide(border),
        borderRadius: t.brutal ? null : BorderRadius.circular(6),
        boxShadow: t.brutal ? RaftProductShadows.shadowBrutalSm.outer : null,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.product.softSignal,
                border: Border(
                  right: t.brutal
                      ? border
                      : BorderSide(color: t.semantic.lineHairline),
                ),
              ),
              child: Text(
                '@',
                style: RaftTypography.mono(
                  t,
                  size: 16,
                  line: 24,
                  color: t.brutal ? const Color(0x99000000) : t.muted,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// "Profile picture" block: label `mb-1 text-sm font-bold
/// text-foreground-strong`; `flex items-center gap-3` with the 56px avatar
/// tile (`theme-brutal:shadow-brutal-sm`) and an sm outline "Upload" button
/// (Camera 15, `gap-1.5`) over `mt-1 text-xs text-foreground-hint` helper.
class _AvatarField extends StatelessWidget {
  const _AvatarField({
    required this.client,
    required this.busy,
    required this.onUpload,
  });
  final RaftClient client;
  final bool busy;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final user = client.user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('Profile picture'),
          style: RaftTypography.heading(t, size: 14, line: 20),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: t.brutal
                    ? RaftProductShadows.shadowBrutalSm.outer
                    : null,
              ),
              child: RaftAvatar(
                name: user?.string('displayName') ?? '',
                size: 56,
                imageUrl: user?.string('avatarUrl').isNotEmpty == true
                    ? user!.string('avatarUrl')
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RaftTextButton(
                    label: tr('Upload'),
                    // Web: Camera 15; RaftGlyph.camera arrives with the regenerated
                    // Lucide set (icons.dart is owned by the glyph track).
                    glyph: RaftGlyph.imagePlus,
                    visualHeight: RaftMetrics.buttonSm,
                    minimumTargetSize: RaftMetrics.buttonSm,
                    onPressed: busy ? null : onUpload,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr('A default is picked for you.'),
                    style: _helper(t, t.semantic.foregroundHint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// OnboardingSessionFooter: `text-center text-sm text-foreground-muted`,
/// "Signed in as {name}. " + muted TextLink "Log out".
class _SessionFooter extends StatelessWidget {
  const _SessionFooter({required this.user, this.onSignOut});
  final RaftRecord? user;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final name = user?.string('displayName').isNotEmpty == true
        ? user!.string('displayName')
        : user?.string('email') ?? '';
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        Text(
          '${raftText(context, 'Signed in as')} $name. ',
          style: RaftTypography.heading(
            t,
            size: 14,
            line: 20,
            weight: FontWeight.w400,
          ).copyWith(color: t.muted),
        ),
        AuthTextLink(label: raftText(context, 'Log out'), onTap: onSignOut),
      ],
    );
  }
}
