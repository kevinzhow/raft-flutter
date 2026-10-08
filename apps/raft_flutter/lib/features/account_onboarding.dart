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
  });
  final RaftClient client;
  final Future<void> Function() onComplete, onSignOut;
  @override
  State<AccountOnboardingView> createState() => _OnboardingState();
}

class _OnboardingState extends State<AccountOnboardingView> {
  final form = GlobalKey<FormState>();
  final username = TextEditingController(),
      displayName = TextEditingController(),
      token = TextEditingController();
  StreamSubscription<RaftEvent>? events;
  bool busy = false;
  String? error, notice;
  RaftClient get client => widget.client;
  @override
  void initState() {
    super.initState();
    events = client.events.listen((event) {
      if (event.name == 'account:updated' && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    events?.cancel();
    username.dispose();
    displayName.dispose();
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
    if (!form.currentState!.validate()) return;
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: RaftPanel(
                shadow: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      raftText(
                        context,
                        verified ? 'Set up your account' : 'Verify your email',
                      ),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    if (!verified) ...[
                      Text(
                        '${raftText(context, 'Check the verification email sent to')} ${client.user?.string('email') ?? ''}.',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('verification-token'),
                        controller: token,
                        enabled: !busy,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: raftText(
                            context,
                            'Verification link or code',
                          ),
                        ),
                        onSubmitted: (_) => run(verify),
                      ),
                      const SizedBox(height: 16),
                      RaftButton(
                        label: raftText(context, 'Verify email'),
                        busy: busy,
                        onPressed: () => run(verify),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => run(() async {
                                await client.post('/auth/resend-verification');
                                if (mounted) {
                                  setState(
                                    () => notice = 'Verification email sent.',
                                  );
                                }
                              }),
                        child: Text(
                          raftText(context, 'Resend verification email'),
                        ),
                      ),
                      TextButton(
                        onPressed: busy ? null : () => run(client.reloadUser),
                        child: Text(
                          raftText(context, 'I have verified my email'),
                        ),
                      ),
                    ] else if (accountNeedsProfile(client.user))
                      Form(
                        key: form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              raftText(
                                context,
                                'Choose a permanent username. Your display name can be changed later.',
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const Key('onboarding-username'),
                              controller: username,
                              enabled: !busy,
                              validator: (v) => accountUsernameError(v ?? ''),
                              decoration: InputDecoration(
                                labelText: raftText(context, 'Username'),
                                prefixText: '@',
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const Key('onboarding-display-name'),
                              controller: displayName,
                              enabled: !busy,
                              validator: (v) => v?.trim().isEmpty ?? true
                                  ? 'Enter a display name.'
                                  : null,
                              decoration: InputDecoration(
                                labelText: raftText(context, 'Display name'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: busy
                                  ? null
                                  : () => run(
                                      () => AccountMediaActions.uploadAvatar(
                                        client,
                                      ),
                                    ),
                              icon: const RaftIcon(RaftGlyph.camera, size: 15),
                              label: Text(
                                raftText(context, 'Choose profile image'),
                              ),
                            ),
                            RaftButton(
                              label: raftText(context, 'Complete profile'),
                              busy: busy,
                              onPressed: () => run(completeProfile),
                            ),
                          ],
                        ),
                      ),
                    if (error != null)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          error!,
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
                    TextButton(
                      onPressed: busy ? null : widget.onSignOut,
                      child: Text(raftText(context, 'Sign out')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
