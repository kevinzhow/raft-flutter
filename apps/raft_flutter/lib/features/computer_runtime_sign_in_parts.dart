// Pieces the two runtime sign-in dialogs share (Web v1.24 features/computer/
// RuntimeSignInDialog.tsx, PiSignInDialog.tsx, loopbackRequiredMethods.ts,
// providerConnectFailure.ts, useComputerName.ts): the step window, the words
// of each failure, the provider rows, and the memory of sign-in methods that
// ended as `loopback_required`.
//
// Nothing here logs: a pasted code and an API key are only ever read from
// their field, sent once and cleared.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/runtime_auth.dart';
import '../data/workspace_controller.dart';

/// useComputerName.ts: the Computer's name as people know it, else null.
String? computerNameOf(WorkspaceController w, String machineId) {
  final machine = w.services.entityDirectory.computer(machineId);
  final name = '${machine?['name'] ?? ''}'.trim();
  if (name.isNotEmpty) return name;
  final host = '${machine?['hostname'] ?? ''}'.trim();
  return host.isEmpty ? null : host;
}

/// Opens an https page in the system browser (Web NewTabLink). On a phone
/// this is also how a login that returns to a page on the Computer is
/// finished: the person signs in there and pastes the address back.
Future<void> openSignInPage(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // No browser to hand it to: the link stays on screen to copy.
  }
}

/// Why a sign-in or a provider list stopped, as the Web's catalog id of its
/// words, and whether starting it again could help.
class SignInFailure {
  const SignInFailure(this.message, {required this.retryable});
  final String message;
  final bool retryable;
}

/// RuntimeSignInDialog.tsx startFailure: the start request was refused.
SignInFailure signInStartFailure(int? status, String? code) {
  if (code == 'computer_offline') {
    return const SignInFailure(
      'This Computer is offline. Connect it, then try again.',
      retryable: true,
    );
  }
  if (code == 'computer_upgrade_required') {
    return const SignInFailure(
      'Upgrade this Computer to sign in from here',
      retryable: false,
    );
  }
  if (code == 'computer_not_attached') {
    return const SignInFailure(
      "This Computer has no owner, so its runtimes can't be signed in from here",
      retryable: false,
    );
  }
  if (code == 'login_in_progress') {
    return const SignInFailure(
      'A sign-in is already running on this Computer.',
      retryable: true,
    );
  }
  if (code == 'rate_limited' || status == 429) {
    return const SignInFailure(
      'Too many sign-in attempts on this Computer. Try again in a few minutes.',
      retryable: true,
    );
  }
  if (status == 403) {
    return const SignInFailure(
      'Only the person who connected this Computer, or an owner or admin, can sign its runtimes in or out.',
      retryable: false,
    );
  }
  if (status == 404) {
    return const SignInFailure(
      "This Computer or runtime wasn't found.",
      retryable: false,
    );
  }
  return const SignInFailure(
    'The sign-in could not start. Try again.',
    retryable: true,
  );
}

/// RuntimeSignInDialog.tsx resultFailure: the Computer ended the login
/// without signing in. [result] is `{kind, reason?}`, kind not `logged_in`.
SignInFailure signInResultFailure(Map<String, dynamic> result) {
  switch (result['kind']) {
    case 'busy':
      return const SignInFailure(
        'A sign-in is already running on this Computer.',
        retryable: true,
      );
    case 'cancelled':
      return const SignInFailure('The sign-in was cancelled.', retryable: true);
    case 'unsupported':
      return switch (result['reason']) {
        'version_unsupported' => const SignInFailure(
          '{runtime} on this Computer is too old to sign in from the web; update it there.',
          retryable: false,
        ),
        'not_installed' => const SignInFailure(
          '{runtime} is not installed on this Computer.',
          retryable: false,
        ),
        _ => const SignInFailure(
          "This {runtime} installation can't be signed in from the web. Sign in on the Computer itself.",
          retryable: false,
        ),
      };
  }
  return switch (result['reason']) {
    'timed_out' => const SignInFailure(
      'The sign-in took too long and stopped. Try again.',
      retryable: true,
    ),
    'rejected' => const SignInFailure(
      '{runtime} did not accept the sign-in. Try again.',
      retryable: true,
    ),
    'not_logged_in' => const SignInFailure(
      'The sign-in finished, but {runtime} is still not signed in. Try again.',
      retryable: true,
    ),
    'interaction_failed' => const SignInFailure(
      "{runtime} asked for something this page can't show. Sign in on the Computer itself.",
      retryable: false,
    ),
    // OpenCode: the chosen sign-in returns to a browser on the Computer
    // itself; another way, not a retry.
    'loopback_required' => const SignInFailure(
      "This way of signing in to {runtime} needs a browser on the Computer itself. Choose another way, or sign in on the Computer.",
      retryable: false,
    ),
    _ => const SignInFailure(
      '{runtime} stopped before the sign-in finished. Try again.',
      retryable: true,
    ),
  };
}

/// failureMessageFor: a per-provider runtime's busy names it, and OpenCode's
/// "too old" says it needs OpenCode 2.
String signInFailureMessageFor(
  String runtime,
  bool perProvider,
  String message,
) {
  if (message == 'A sign-in is already running on this Computer.' &&
      perProvider) {
    return runtime == 'opencode'
        ? 'Another OpenCode sign-in is in progress on this Computer, for this or another provider. Finish or cancel it, then try again.'
        : 'Another Pi sign-in is in progress on this Computer, for this or another provider. Finish or cancel it, then try again.';
  }
  if (message ==
          '{runtime} on this Computer is too old to sign in from the web; update it there.' &&
      runtime == 'opencode') {
    return "Upgrade OpenCode on the Computer to 2.x, then use Rescan runtimes on the Computer's page.";
  }
  return message;
}

/// providerConnectFailure.ts providerRequestFailure: a provider list or
/// connect the server refused. A key field the server named is [field].
({SignInFailure? failure, bool field}) signInProviderRequestFailure(
  Object error, {
  required bool connect,
}) {
  final (:status, :code) = runtimeAuthRequestError(error);
  if (code == 'invalid_api_key') return (failure: null, field: true);
  SignInFailure failure(String message, bool retryable) =>
      SignInFailure(message, retryable: retryable);
  if (code == 'computer_offline') {
    return (
      failure: failure(
        'This Computer is offline. Connect it, then try again.',
        true,
      ),
      field: false,
    );
  }
  if (code == 'computer_upgrade_required') {
    return (
      failure: failure(
        'Upgrade this Computer to connect a provider from here',
        false,
      ),
      field: false,
    );
  }
  if (code == 'computer_not_attached') {
    return (
      failure: failure(
        "This Computer has no owner, so its runtimes can't be connected from here",
        false,
      ),
      field: false,
    );
  }
  if (code == 'computer_timeout' || status == 504) {
    return (
      failure: connect
          ? failure(
              '{runtime} took too long to answer. The key may or may not be saved: check the card, then try again if needed.',
              true,
            )
          : failure('The Computer did not answer in time. Try again.', true),
      field: false,
    );
  }
  if (code == 'rate_limited' || status == 429) {
    return (
      failure: failure(
        'Too many attempts on this Computer. Try again in a few minutes.',
        true,
      ),
      field: false,
    );
  }
  if (status == 400) {
    return (
      failure: failure('Check the details and try again.', true),
      field: false,
    );
  }
  if (status == 403) {
    return (
      failure: failure(
        'Only the person who connected this Computer, or an owner or admin, can connect its runtimes to a provider.',
        false,
      ),
      field: false,
    );
  }
  if (status == 404) {
    return (
      failure: failure("This Computer or runtime wasn't found.", false),
      field: false,
    );
  }
  return (
    failure: failure("Couldn't reach the Computer. Try again.", true),
    field: false,
  );
}

/// providerConnectFailure.ts providerResultFailure: the Computer answered,
/// but without a list or a save. [result] is `{kind, reason?}`.
SignInFailure signInProviderResultFailure(
  Map<String, dynamic> result, {
  required bool connect,
}) {
  switch (result['kind']) {
    case 'busy':
      return const SignInFailure(
        'Another provider is being connected on this Computer. Try again in a moment.',
        retryable: true,
      );
    case 'unsupported':
      return result['reason'] == 'not_installed'
          ? const SignInFailure(
              '{runtime} is not installed on this Computer.',
              retryable: false,
            )
          : const SignInFailure(
              "{runtime} on this Computer can't be connected from the web.",
              retryable: false,
            );
  }
  return switch (result['reason']) {
    'rejected' => const SignInFailure(
      '{runtime} did not accept these settings. Check the key and try again.',
      retryable: true,
    ),
    'timed_out' =>
      connect
          ? const SignInFailure(
              '{runtime} took too long to answer. The key may or may not be saved: check the card, then try again if needed.',
              retryable: true,
            )
          : const SignInFailure(
              '{runtime} took too long to answer. Try again.',
              retryable: true,
            ),
    'process_failed' => const SignInFailure(
      '{runtime} could not run on this Computer. Try again.',
      retryable: true,
    ),
    'invalid_response' => const SignInFailure(
      "{runtime} answered in a way this page can't read. Update {runtime} on the Computer, then try again.",
      retryable: false,
    ),
    // The server could not hand the connect to the Computer's own
    // connection: nothing was saved.
    _ => const SignInFailure(
      "Couldn't reach the Computer. Try again.",
      retryable: true,
    ),
  };
}

/// runtimeAuthLiteralApiKeyFits: whether the key may be saved as typed. Pi
/// runs a key starting with `!` as a command and fills in a `$` name;
/// OpenCode is not given an `{env:}` or `{file:}` reference; both send it in
/// an HTTP header, one byte per character.
bool runtimeAuthLiteralApiKeyFits(String runtime, String apiKey) {
  if (apiKey.codeUnits.any((unit) => unit > 0xff)) return false;
  return switch (runtime) {
    'pi' => !apiKey.startsWith('!') && !apiKey.contains(r'$'),
    'opencode' => !RegExp(
      r'\{(?:env|file):',
      caseSensitive: false,
    ).hasMatch(apiKey),
    _ => true,
  };
}

/// loopbackRequiredMethods.ts: OpenCode sign-ins seen to end as
/// `loopback_required` (only a browser on the Computer itself could finish
/// them), per Computer, runtime, provider and method, for the rest of this
/// session. The provider list shows them greyed out with why. Memory only.
final _loopbackRequired = <String>{};

String _loopbackKey(
  String machineId,
  String runtime,
  String providerId,
  String method,
) => [machineId, runtime, providerId, method].join('\u0000');

void rememberLoopbackRequired(
  String machineId,
  String runtime,
  String providerId,
  String method,
) =>
    _loopbackRequired.add(_loopbackKey(machineId, runtime, providerId, method));

bool isLoopbackRequired(
  String machineId,
  String runtime,
  String providerId,
  String method,
) => _loopbackRequired.contains(
  _loopbackKey(machineId, runtime, providerId, method),
);

/// Tests only.
@visibleForTesting
void clearLoopbackRequiredForTests() => _loopbackRequired.clear();

/// What the paste step of an account sign-in takes (Pi, OpenCode): `code` is
/// a code the sign-in page shows, `address` the address of the page the
/// browser lands on, which will not load.
enum SignInPaste { code, address }

/// The provider an account sign-in is for (Pi, OpenCode): the dialog is
/// named after it; [oauthMethod] is the chosen sign-in by its label
/// (OpenCode), and one that ends as `loopback_required` is remembered.
class SignInProvider {
  const SignInProvider({
    required this.id,
    required this.label,
    this.paste,
    this.oauthMethod,
  });
  final String id, label;
  final SignInPaste? paste;
  final String? oauthMethod;
}

/// The step window (Web StepDialog `disablePointerDismissal`): title and X,
/// the body, then the actions. A bottom sheet below 768 through
/// [showSignInStep].
class SignInStepDialog extends StatelessWidget {
  const SignInStepDialog({
    super.key,
    required this.title,
    required this.children,
    required this.actions,
    this.onClosed,
  });
  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  /// Called once the window was closed by any route (X, Esc, Back, a button).
  final VoidCallback? onClosed;

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) onClosed?.call();
    },
    child: RaftDialog.card(
      title: title,
      onClose: () => Navigator.of(context).pop(),
      actions: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: RaftSpace.x2,
        runSpacing: RaftSpace.x2,
        children: actions,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        // `DialogBody className="grid gap-4"`.
        spacing: RaftSpace.x4,
        children: children,
      ),
    ),
  );
}

/// Opens a step window: no scrim press and no drag down (Web
/// `disablePointerDismissal`), and a typed code or key is never a draft.
Future<void> showSignInStep(
  BuildContext context, {
  required String label,
  required WidgetBuilder builder,
}) => showRaftForm<void>(
  context,
  label: label,
  dismissible: false,
  dragDismissible: false,
  guardUnsaved: false,
  builder: builder,
);

/// Body copy of the step windows (`text-subhead text-foreground-muted`).
Widget signInHint(
  BuildContext context,
  String text, {
  Key? key,
  bool caption = false,
}) {
  final t = RaftTokens.of(context);
  return Text(
    text,
    key: key,
    style: RaftTypography.body(
      t,
      size: caption ? 12 : 14,
      line: caption ? 12 * 1.5 : 14 * 1.625,
      color: caption
          ? (t.colors['foreground-hint'] ?? t.muted)
          : (t.colors['foreground-muted'] ?? t.muted),
    ),
  );
}

/// Web `Spinner` + `role="status"` line.
Widget signInStatusLine(BuildContext context, String text, {Key? key}) =>
    Semantics(
      liveRegion: true,
      child: Row(
        key: key,
        children: [
          const RaftSpinner(size: 16),
          const SizedBox(width: RaftSpace.x2),
          Expanded(child: signInHint(context, text)),
        ],
      ),
    );

/// The commit button (Web `DialogCommit` primary).
Widget signInCommit(
  BuildContext context, {
  required Key key,
  required String label,
  required VoidCallback? onPressed,
  bool busy = false,
  String? loadingLabel,
  RaftButtonRecipeVariant tone = RaftButtonRecipeVariant.accent,
}) => RaftButton(
  key: key,
  label: label,
  tone: tone,
  size: RaftButtonRecipeSize.lg,
  busy: busy,
  loadingLabel: loadingLabel ?? 'Loading',
  onPressed: busy ? null : onPressed,
);

/// The ghost Cancel / Close / Back button.
Widget signInGhost(
  BuildContext context, {
  required Key key,
  required String label,
  required VoidCallback? onPressed,
}) => RaftButton(
  key: key,
  label: label,
  tone: RaftButtonRecipeVariant.ghost,
  size: RaftButtonRecipeSize.lg,
  onPressed: onPressed,
);
