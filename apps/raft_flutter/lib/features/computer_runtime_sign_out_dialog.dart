// Web v1.24 features/computer/RuntimeSignOutDialog.tsx: sign a Computer's
// runtime out (or, for Pi / OpenCode, one provider's account or key), after a
// confirmation that names the agents on that Computer that use the sign-in.
// The logout runs on the Computer; whatever its answer, the cached sign-in
// view is dropped so the card reads the new state.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/runtime_auth.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'computers_rack/computers_rack_model.dart' show rackRuntimeDisplayName;
import 'icu_message.dart';

/// useComputerName: the Computer's name, or null (the caller says "this
/// Computer").
String? runtimeComputerName(WorkspaceController w, String machineId) {
  final name = w.services.entityDirectory.computer(machineId)?['name'];
  return name is String && name.trim().isNotEmpty ? name : null;
}

/// STILL_LOGGED_IN_MESSAGE.
String _stillLoggedIn(String runtime) => switch (runtime) {
  'antigravity' => 'Still signed in: another sign-in is active on that Computer, such as GEMINI_API_KEY in its environment or a sign-in kept in its system keyring. Remove it on that Computer.',
  'grok' => 'Still signed in: another xAI sign-in is active on that Computer, such as an API key in its environment. Remove it on that Computer.',
  _ => "Still signed in: an API key in that Computer's environment is used",
};

/// logoutFailureMessageId, as the catalog's English text.
String runtimeLogoutFailureText(String runtime, Map<String, dynamic> result) {
  if (result['kind'] == 'unsupported') {
    return switch (result['reason']) {
      'version_unsupported' => '{runtime} on this Computer is too old to sign in from the web; update it there.',
      'not_installed' => '{runtime} is not installed on this Computer.',
      _ => "This {runtime} installation can't be signed in from the web. Sign in on the Computer itself.",
    };
  }
  return switch (result['reason']) {
    'still_logged_in' => _stillLoggedIn(runtime),
    'timed_out' => 'The Computer did not answer in time. Try again.',
    // OpenCode: a sign-in on that Computer holds its one OpenCode server.
    'busy' => 'A sign-in is in progress on this Computer. Finish or cancel it, then try again.',
    _ => '{runtime} could not be signed out. Try again.',
  };
}

/// logoutRequestMessageId, as the catalog's English text.
String runtimeLogoutRequestErrorText(Object error) {
  final (:status, :code) = runtimeAuthRequestError(error);
  if (code == 'computer_offline') {
    return 'This Computer is offline. Connect it, then try again.';
  }
  if (code == 'computer_upgrade_required') {
    return 'Upgrade this Computer to sign in from here';
  }
  if (code == 'computer_not_attached') {
    return "This Computer has no owner, so its runtimes can't be signed in from here";
  }
  if (code == 'computer_timeout' || status == 504) {
    return 'The Computer did not answer in time. Try again.';
  }
  if (status == 403) {
    return 'Only the person who connected this Computer, or an owner or admin, can sign its runtimes in or out.';
  }
  return '{runtime} could not be signed out. Try again.';
}

/// Opens the sign-out confirmation for [runtime] (a runtime-auth id) on the
/// Computer [machineId]; [runtimeId] is the Raft runtime id it is shown for.
/// [provider]: the one provider to sign out of a per-provider runtime (Pi):
/// an account is signed out, a key removed; the runtime's others stay.
Future<void> showComputerRuntimeSignOutDialog(
  BuildContext context, {
  required WorkspaceController controller,
  required RuntimeAuthClient client,
  required String serverId,
  required String machineId,
  required String runtimeId,
  required String runtime,
  RuntimeAuthSignedInProvider? provider,
}) {
  final directory = controller.services.entityDirectory
    ..ensure(const [WorkspaceEntityKind.agents]);
  return showRaftDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialog) => _SignOutDialog(
      directory: directory,
      client: client,
      serverId: serverId,
      machineId: machineId,
      runtimeId: runtimeId,
      runtime: runtime,
      provider: provider,
      computer:
          runtimeComputerName(controller, machineId) ??
          raftText(dialog, 'this Computer'),
    ),
  );
}

class _SignOutDialog extends StatefulWidget {
  const _SignOutDialog({
    required this.directory,
    required this.client,
    required this.serverId,
    required this.machineId,
    required this.runtimeId,
    required this.runtime,
    required this.provider,
    required this.computer,
  });
  final WorkspaceEntityDirectory directory;
  final RuntimeAuthClient client;
  final String serverId, machineId, runtimeId, runtime, computer;
  final RuntimeAuthSignedInProvider? provider;

  @override
  State<_SignOutDialog> createState() => _SignOutDialogState();
}

class _SignOutDialogState extends State<_SignOutDialog> {
  @override
  void initState() {
    super.initState();
    widget.directory.addListener(_agents);
  }

  @override
  void dispose() {
    widget.directory.removeListener(_agents);
    super.dispose();
  }

  void _agents() {
    if (mounted) setState(() {});
  }

  /// Every agent on a runtime that uses this sign-in (for Kimi: Kimi Code's,
  /// not Kimi CLI's).
  List<Map<String, dynamic>> get agents => [
    for (final a in widget.directory.rows(WorkspaceEntityKind.agents))
      if (a['deletedAt'] == null &&
          a['machineId'] == widget.machineId &&
          runtimeAuthRuntimeFor('${a['runtime']}') == widget.runtime)
        a,
  ];

  Future<void> confirm() async {
    final provider = widget.provider;
    final name = provider?.label ?? rackRuntimeDisplayName(widget.runtimeId);
    final values = {'runtime': name, 'computer': widget.computer};
    Map<String, dynamic> result;
    try {
      result = await widget.client.logout(
        widget.serverId,
        widget.machineId,
        widget.runtime,
        providerId: provider?.id,
      );
    } catch (error) {
      if (!mounted) rethrow;
      throw RaftComputerActionError(
        raftFormat(context, runtimeLogoutRequestErrorText(error), values),
      );
    } finally {
      widget.client.invalidate(widget.serverId, widget.machineId);
    }
    if (result['kind'] != 'logged_out') {
      if (!mounted) return;
      throw RaftComputerActionError(
        raftFormat(
          context,
          runtimeLogoutFailureText(widget.runtime, result),
          values,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final provider = widget.provider;
    final piName = rackRuntimeDisplayName(widget.runtimeId);
    final name = provider?.label ?? piName;
    final removesKey = provider?.method == 'api_key';
    final list = agents;
    final values = {
      'runtime': name,
      'piRuntime': piName,
      'computer': widget.computer,
    };
    final muted = RaftConfirmDialog.messageStyle(t);
    return RaftConfirmDialog(
      surfaceKey: ValueKey('runtime-sign-out-dialog-${widget.runtime}'),
      title: raftFormat(
        context,
        removesKey ? 'Remove the {runtime} key?' : 'Sign out of {runtime}?',
        {'runtime': name},
      ),
      plainMessage: true,
      maxWidth: 448,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            raftFormat(
              context,
              provider != null
                  ? (removesKey
                        ? 'The {runtime} key will be removed from {piRuntime} on {computer}.'
                        : '{runtime} will be signed out of {piRuntime} on {computer}. Its other providers stay signed in.')
                  : '{runtime} will be signed out on {computer}.',
              values,
            ),
            style: muted,
          ),
          const SizedBox(height: 12),
          if (list.isNotEmpty) ...[
            Text(
              icuText(
                context,
                provider != null
                    ? "{count, plural, one {This {piRuntime} agent on this Computer may use {runtime}. It keeps running, but can't use {runtime} until someone adds it again:} other {These # {piRuntime} agents on this Computer may use {runtime}. They keep running, but can't use {runtime} until someone adds it again:}}"
                    : "{count, plural, one {This agent on this Computer uses {runtime}. It keeps running, but its next start can't authenticate until someone signs in again:} other {These # agents on this Computer use {runtime}. They keep running, but their next start can't authenticate until someone signs in again:}}",
                {...values, 'count': list.length},
              ),
              style: muted,
            ),
            const SizedBox(height: 6),
            Column(
              key: const ValueKey('runtime-sign-out-agents'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final a in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${(a['displayName'] ?? '').toString().isNotEmpty ? a['displayName'] : a['name']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: muted.copyWith(
                        color: t.strong,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ] else
            Text(
              raftFormat(context, 'No agents on this Computer use {runtime}.', {
                'runtime': piName,
              }),
              style: muted,
            ),
        ],
      ),
      confirmLabel: raftText(context, removesKey ? 'Remove' : 'Sign out'),
      confirmKey: const ValueKey('runtime-sign-out-confirm'),
      confirmVariant: RaftButtonRecipeVariant.warning,
      loadingLabel: raftText(context, 'Processing…'),
      onConfirm: confirm,
    );
  }
}
