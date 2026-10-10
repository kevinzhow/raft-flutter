import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'auth_view.dart' show authLinkToken;

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
    final user = client.user;
    final avatarUrl = user?.string('avatarUrl') ?? '';
    final footerName = (user?.string('displayName') ?? '').isNotEmpty
        ? user!.string('displayName')
        : user?.string('email') ?? '';
    return Form(
      key: form,
      child: RaftOnboardingPage(
        title: tr(verified ? 'Set up your account' : 'Verify your email'),
        banner: error,
        notice: notice == null ? null : tr(notice!),
        footer: widget.showSessionFooter
            ? RaftAuthSessionFooter(
                name: footerName,
                onSignOut: busy ? null : widget.onSignOut,
              )
            : null,
        children: [
          if (!verified) ...[
            RaftAuthNote(
              '${tr('Check the verification email sent to')} ${user?.string('email') ?? ''}.',
            ),
            RaftAuthField(
              label: tr('Verification link or code'),
              child: TextField(
                autofillHints: null,
                key: const Key('verification-token'),
                controller: token,
                obscureText: true,
                style: t.fieldStyle,
                onSubmitted: (_) => run(verify),
              ),
            ),
            RaftAuthWideButton(
              variant: RaftControlVariant.accent,
              onPressed: busy ? null : () => run(verify),
              child: Text(tr('Verify email')),
            ),
            Center(
              child: RaftAuthTextLink(
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
              child: RaftAuthTextLink(
                label: tr('I have verified my email'),
                onTap: busy ? null : () => run(client.reloadUser),
              ),
            ),
          ] else if (profile)
            RaftAuthFormColumn(
              children: [
                RaftAuthField(
                  label: tr('Username'),
                  surface: false,
                  error: handleError,
                  helper: tr(
                    "Your unique name for @mentions and links. It can't be changed later.",
                  ),
                  child: RaftAuthHandleGroup(
                    child: TextFormField(
                      key: const Key('onboarding-username'),
                      controller: username,
                      focusNode: usernameFocus,
                      style: t.fieldStyle,
                      autofillHints: null,
                      decoration: raftAuthGroupedInputDecoration(
                        hintText: tr('alexchen'),
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
                RaftAuthField(
                  label: tr('Display name'),
                  error: displayNameError,
                  helper: tr(
                    'How your name appears in messages. Change this anytime.',
                  ),
                  helperHint: true,
                  child: TextFormField(
                    key: const Key('onboarding-display-name'),
                    controller: displayName,
                    style: t.fieldStyle,
                    autofillHints: null,
                    decoration: InputDecoration(hintText: tr('Alex Chen')),
                    onChanged: (_) => setState(() {
                      displayNameEdited = true;
                      displayNameError = null;
                    }),
                  ),
                ),
                RaftAuthAvatarField(
                  name: user?.string('displayName') ?? '',
                  imageUrl: avatarUrl.isEmpty ? null : avatarUrl,
                  onUpload: busy
                      ? null
                      : () =>
                            run(() => AccountMediaActions.uploadAvatar(client)),
                ),
                RaftAuthWideButton(
                  key: const Key('onboarding-complete'),
                  variant: RaftControlVariant.accent,
                  onPressed: busy ? null : () => run(completeProfile),
                  child: Text(tr(busy ? 'Saving identity…' : 'Continue')),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
