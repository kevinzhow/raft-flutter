import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../platform/file_selection.dart';

import '../data/cause_notice.dart';
import '../data/user_error.dart';
import 'auth_view.dart' show authFailureText, authLinkToken;

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

/// A profile image chosen and checked for upload (Web `PROFILE_AVATAR_ACCEPT`,
/// `MAX_PROFILE_AVATAR_BYTES`): the multipart `avatar` field.
class PickedAvatar {
  const PickedAvatar(this.name, this.bytes, this.mime);
  final String name, mime;
  final Uint8List bytes;

  FormData get form => FormData.fromMap({
    'avatar': MultipartFile.fromBytes(
      bytes,
      filename: name,
      contentType: DioMediaType.parse(mime),
    ),
  });
}

class AccountMediaActions {
  /// Opens the image picker (system photo picker on Android/iOS, the file
  /// picker on desktop) and validates the choice; null when cancelled.
  static Future<PickedAvatar?> pickAvatar(RaftClient client) async {
    final generation = client.generation;
    final file = await selectImage(
      typeGroup: const XTypeGroup(
        label: 'Avatar image',
        extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
        mimeTypes: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
        uniformTypeIdentifiers: ['public.image'],
      ),
    );
    if (file == null) return null;
    if (client.generation != generation) {
      throw const RaftUserError(raftGenericErrorText);
    }
    final length = await file.length();
    if (length > 5 * 1024 * 1024) {
      throw const RaftUserError('Avatar image must be 5 MB or smaller');
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
      throw const RaftUserError('Failed to upload avatar');
    }
    final bytes = await file.readAsBytes();
    if (client.generation != generation) {
      throw const RaftUserError(raftGenericErrorText);
    }
    return PickedAvatar(file.name, bytes, mime);
  }

  static Future<void> uploadAvatar(RaftClient client) async {
    final picked = await pickAvatar(client);
    if (picked == null) return;
    await client.post('/auth/me/avatar', data: picked.form);
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

class _OnboardingState extends State<AccountOnboardingView>
    with WidgetsBindingObserver {
  final form = GlobalKey<FormState>();
  final username = TextEditingController(),
      displayName = TextEditingController(),
      token = TextEditingController();
  StreamSubscription<RaftEvent>? events;
  bool busy = false, displayNameEdited = false;
  bool manualOpen = false, resending = false, verifying = false, resent = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- handleError/displayNameError clear when the field is edited and are recomputed on submit; notice is never raised (always null).
  String? notice, handleError, displayNameError;

  /// The page's banner. Web keeps the verification step and the identity step
  /// in two components, each with its own error, so a failure raised on one
  /// (a rejected token, a failed resend) is dropped once the account moves to
  /// the other.
  late final CauseNotice _banner = CauseNotice(scope: () => emailVerified);
  bool get emailVerified => client.user?.json['emailVerified'] == true;
  String? get error => _banner.message;
  final usernameFocus = FocusNode();
  RaftClient get client => widget.client;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    events = client.events.listen((event) {
      if (event.name == 'account:updated' && mounted) setState(() {});
    });
    // AccountIdentitySetupPage: the handle starts from the suggestion only for an OAuth provider account;
    // the display name starts from the account's own (a pre-filled one counts as already edited).
    final suggested =
        (client.user?.string('profileSetupProvider') ?? '').isEmpty
        ? ''
        : client.user?.string('profileSetupSuggestedHandle') ?? '';
    username.text = suggested;
    displayName.text = client.user?.string('displayName') ?? '';
    displayNameEdited = displayName.text.isNotEmpty;
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

  /// The verification link is opened in the browser; coming back to the app
  /// re-reads the account (Web reloads the page after the link).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        client.user?.json['emailVerified'] != true) {
      unawaited(run(client.reloadUser).catchError((_) {}));
    }
  }

  Future<void> resend() async {
    if (resending) return;
    setState(() {
      resending = true;
      _banner.clear();
      resent = false;
    });
    try {
      await client.post('/auth/resend-verification');
      if (mounted) setState(() => resent = true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _banner.raise(
            userErrorText(
              e,
              fallback: 'Failed to resend verification email',
              where: 'resend verification',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => resending = false);
    }
  }

  Future<void> verifyManual() async {
    if (verifying || token.text.trim().isEmpty) return;
    final generation = client.generation;
    setState(() {
      verifying = true;
      _banner.clear();
      resent = false;
    });
    try {
      await verify();
      if (client.generation == generation &&
          !accountNeedsOnboarding(client.user)) {
        await widget.onComplete();
      }
    } catch (e) {
      if (mounted && client.generation == generation) {
        setState(
          () => _banner.raise(
            userErrorText(
              e,
              fallback: 'Verification failed. The link may be expired.',
              where: 'verify email',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => verifying = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    events?.cancel();
    username.dispose();
    displayName.dispose();
    usernameFocus.dispose();
    token.dispose();
    super.dispose();
  }

  Future<void> run(
    Future<void> Function() action, {
    String fallback = "Couldn't finish identity setup",
  }) async {
    if (busy) return;
    final generation = client.generation;
    setState(() {
      busy = true;
      _banner.clear();
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
        setState(
          () =>
              _banner.raise(authFailureText(e, fallback, where: 'onboarding')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verify() async {
    final code = authLinkToken(token.text.trim());
    if (code.isEmpty) {
      throw const RaftUserError(
        'Verification failed. The link may be expired.',
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
      throw RaftUserError(
        available['message'] is String &&
                (available['message'] as String).trim().isNotEmpty
            ? available['message'] as String
            : 'This username is already taken.',
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
    if (!verified) {
      // EmailVerificationPage (CenteredCardFrame), not the onboarding shell.
      return RaftAuthVerifyPage(
        email: user?.string('email') ?? '',
        resending: resending,
        verifying: verifying,
        manualOpen: manualOpen,
        canVerify: token.text.trim().isNotEmpty,
        error: error,
        resent: resent,
        tokenField: RaftTextInput(
          key: const Key('verification-token'),
          controller: token,
          hintText: tr('Paste verification token'),
          semanticLabel: tr('Verification link or code'),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => verifyManual(),
        ),
        onResend: resend,
        onToggleManual: () => setState(() => manualOpen = !manualOpen),
        onVerify: verifyManual,
        onLogOut: () => unawaited(widget.onSignOut()),
      );
    }
    final footerName = (user?.string('displayName') ?? '').isNotEmpty
        ? user!.string('displayName')
        : user?.string('email') ?? '';
    return Form(
      key: form,
      child: RaftOnboardingPage(
        title: tr('Set up your account'),
        preview: profile
            ? RaftIdentityImpactPreview(
                displayName: displayName.text,
                handle: username.text,
                avatar: avatarUrl.isEmpty
                    ? null
                    : (size) => RaftAvatar(
                        name: user?.string('displayName') ?? '',
                        size: size,
                        imageUrl: avatarUrl,
                      ),
              )
            : null,
        banner: error,
        notice: notice == null ? null : tr(notice!),
        footer: widget.showSessionFooter
            ? RaftAuthSessionFooter(
                name: footerName,
                onSignOut: busy ? null : widget.onSignOut,
              )
            : null,
        children: [
          if (profile)
            RaftAuthFormColumn(
              children: [
                RaftAuthField(
                  label: tr('Username'),
                  surface: false,
                  error: handleError,
                  helper: tr(
                    "Your unique name for @mentions and links. It can't be changed later.",
                  ),
                  child: RaftAuthHandleInput(
                    fieldKey: const Key('onboarding-username'),
                    controller: username,
                    focusNode: usernameFocus,
                    hintText: tr('alexchen'),
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
                RaftAuthField(
                  label: tr('Display name'),
                  error: displayNameError,
                  helper: tr(
                    'How your name appears in messages. Change this anytime.',
                  ),
                  helperHint: true,
                  child: RaftTextInput(
                    fieldKey: const Key('onboarding-display-name'),
                    controller: displayName,
                    style: t.fieldStyle,
                    hintText: tr('Alex Chen'),
                    legacy: RaftLegacyInput.themed,
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
                      : () => run(
                          () => AccountMediaActions.uploadAvatar(client),
                          fallback: 'Failed to upload avatar',
                        ),
                ),
                RaftAuthWideButton(
                  key: const Key('onboarding-complete'),
                  variant: RaftControlVariant.accent,
                  onPressed: busy ? null : () => run(completeProfile),
                  label: tr(busy ? 'Saving Identity…' : 'Continue'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
