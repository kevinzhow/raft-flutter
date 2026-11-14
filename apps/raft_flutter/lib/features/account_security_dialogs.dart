// The dialog parts Web v1.24.0 TwoStepVerificationSection.tsx shares with
// PasskeysSection.tsx: one dialog per step (title and X, a body, then Cancel
// and the step's one commit), the code or password field with its error
// under it, and the backup codes shown once.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../platform/attachment_files.dart';
import 'account_security_answer.dart';

/// Web `StepDialog`: a bottom sheet below 768 and a dialog from there
/// ([showRaftForm]). Closing is refused while [busy]; a scrim press does not
/// close it.
class SecondFactorStepDialog extends StatelessWidget {
  const SecondFactorStepDialog({
    super.key,
    required this.title,
    required this.children,
    required this.actions,
    this.busy = false,
  });
  final String title;
  final List<Widget> children;
  final List<Widget> actions;
  final bool busy;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: RaftDialog.card(
      title: title,
      closeEnabled: !busy,
      onClose: () {
        if (!busy) Navigator.of(context).pop();
      },
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

/// Opens a step dialog; [builder] draws a [SecondFactorStepDialog].
Future<T?> showSecondFactorStep<T>(
  BuildContext context, {
  required String label,
  required WidgetBuilder builder,
}) => showRaftForm<T>(
  context,
  label: raftText(context, label),
  // A typed code is not a draft: closing never asks first. The form window's
  // closes are the approved `form-dialog` set (close registry).
  guardUnsaved: false,
  builder: builder,
);

/// Web `CancelButton`: ghost, disabled while busy.
Widget secondFactorCancel(BuildContext context, {bool busy = false}) =>
    RaftButton(
      key: const ValueKey('second-factor-step-cancel'),
      label: raftText(context, 'Cancel'),
      tone: RaftButtonRecipeVariant.ghost,
      size: RaftButtonRecipeSize.lg,
      onPressed: busy ? null : () => Navigator.of(context).pop(),
    );

/// Web `CommitButton` (`DialogCommit`).
Widget secondFactorCommit(
  BuildContext context, {
  required String label,
  required VoidCallback? onPressed,
  bool busy = false,
  RaftButtonRecipeVariant variant = RaftButtonRecipeVariant.accent,
  Key key = const ValueKey('second-factor-step-commit'),
}) => RaftButton(
  key: key,
  label: raftText(context, label),
  tone: variant,
  size: RaftButtonRecipeSize.lg,
  busy: busy,
  onPressed: busy ? null : onPressed,
);

/// Web `DoneButton`.
Widget secondFactorDone(BuildContext context) => secondFactorCommit(
  context,
  label: 'Done',
  key: const ValueKey('second-factor-step-done'),
  onPressed: () => Navigator.of(context).pop(),
);

/// Web `AnswerField`: a code or password field; its error under it.
class SecondFactorAnswerField extends StatelessWidget {
  const SecondFactorAnswerField({
    super.key,
    required this.kind,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    this.error,
    this.enabled = true,
  });
  final SecondFactorAnswerKind kind;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final String? error;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final label = raftText(context, switch (kind) {
      SecondFactorAnswerKind.password => 'Password',
      SecondFactorAnswerKind.backupCode => 'Backup code',
      SecondFactorAnswerKind.totp => 'Authenticator code',
    });
    return RaftField(
      label: label,
      error: error,
      child: RaftTextInput(
        key: ValueKey('second-factor-answer-${kind.name}'),
        controller: controller,
        autofocus: true,
        enabled: enabled,
        invalid: error != null,
        obscureText: kind == SecondFactorAnswerKind.password,
        keyboardType: kind == SecondFactorAnswerKind.totp
            ? TextInputType.number
            : TextInputType.text,
        autofillHints: switch (kind) {
          SecondFactorAnswerKind.password => const [AutofillHints.password],
          SecondFactorAnswerKind.totp => const [AutofillHints.oneTimeCode],
          SecondFactorAnswerKind.backupCode => null,
        },
        semanticLabel: label,
        onChanged: onChanged,
        onSubmitted: (_) => onSubmitted(),
      ),
    );
  }
}

/// A banner in a step (`Banner density="sm"`).
Widget secondFactorBanner(
  String text, {
  RaftBannerRecipeStatus status = RaftBannerRecipeStatus.warning,
  bool live = true,
  Key? key,
}) => RaftBanner(
  key: key,
  status: status,
  size: RaftBannerRecipeSize.sm,
  live: live,
  description: text,
);

/// Web `BackupCodesPanel`: the codes in two columns, Copy and Download.
class BackupCodesPanel extends StatefulWidget {
  const BackupCodesPanel({
    super.key,
    required this.codes,
    required this.client,
    this.files,
  });
  final List<String> codes;
  final RaftClient client;

  /// Tests replace the platform save picker.
  final AttachmentFiles? files;

  @override
  State<BackupCodesPanel> createState() => _BackupCodesPanelState();
}

class _BackupCodesPanelState extends State<BackupCodesPanel> {
  bool copied = false, copyFailed = false;

  Future<void> copy() async {
    setState(() => copyFailed = false);
    try {
      await Clipboard.setData(ClipboardData(text: widget.codes.join('\n')));
      if (mounted) setState(() => copied = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          copied = false;
          copyFailed = true;
        });
      }
    }
  }

  Future<void> download() async {
    final heading = raftFormat(
      context,
      'Raft backup codes for {email}. Each code works once.',
      {'email': widget.client.user?.string('email') ?? ''},
    );
    final text = '$heading\n\n${widget.codes.join('\n')}\n';
    final user = widget.client.user?.id;
    await (widget.files ?? AttachmentFiles()).saveBytes(
      bytes: Uint8List.fromList(utf8.encode(text)),
      filename: 'raft-backup-codes.txt',
      mimeType: 'text/plain',
      authorized: () => mounted && widget.client.user?.id == user,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final codeStyle = RaftTypography.mono(
      t,
      size: 13,
      line: 20,
      color: t.ui.foreground,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: RaftSpace.x4,
      children: [
        Text(
          raftText(
            context,
            "Save these backup codes somewhere safe. If you can't use your authenticator app, each code lets you sign in once. You won't see them again.",
          ),
          style: RaftTypography.body(t, size: 15, line: 20, color: t.muted),
        ),
        // `CodeBlock` > `pre.grid grid-cols-2 gap-x-6 gap-y-1`.
        Container(
          key: const ValueKey('two-step-backup-codes'),
          padding: const EdgeInsets.all(RaftSpace.x3),
          decoration: BoxDecoration(
            color: t.ui.fillMuted,
            borderRadius: BorderRadius.circular(
              t.size('radius.control', fallback: 6),
            ),
            border: Border.all(color: t.ui.lineHairline),
          ),
          child: RaftSelectionArea(
            child: Wrap(
              spacing: RaftSpace.x6,
              runSpacing: RaftSpace.x1,
              children: [
                for (final code in widget.codes)
                  SizedBox(width: 120, child: Text(code, style: codeStyle)),
              ],
            ),
          ),
        ),
        Wrap(
          spacing: RaftSpace.x2,
          runSpacing: RaftSpace.x2,
          children: [
            RaftButton(
              key: const ValueKey('two-step-copy-codes'),
              label: raftText(context, copied ? 'Copied' : 'Copy'),
              glyph: RaftGlyph.copy,
              glyphSize: 14,
              tone: RaftButtonRecipeVariant.outline,
              size: RaftButtonRecipeSize.md,
              onPressed: copy,
            ),
            RaftButton(
              key: const ValueKey('two-step-download-codes'),
              label: raftText(context, 'Download'),
              glyph: RaftGlyph.download,
              glyphSize: 14,
              tone: RaftButtonRecipeVariant.outline,
              size: RaftButtonRecipeSize.md,
              onPressed: download,
            ),
          ],
        ),
        if (copyFailed)
          secondFactorBanner(
            raftText(
              context,
              "Couldn't copy the codes. Select and copy them yourself, or download them.",
            ),
          ),
      ],
    );
  }
}

/// Shows [codes] once (the Turn On end step, or "New backup codes").
Future<void> showBackupCodes(
  BuildContext context,
  RaftClient client,
  List<String> codes, {
  required String title,
  bool enabledNotice = false,
}) => showSecondFactorStep<void>(
  context,
  label: title,
  builder: (context) => SecondFactorStepDialog(
    key: const ValueKey('two-step-codes-dialog'),
    title: title,
    actions: [secondFactorDone(context)],
    children: [
      if (enabledNotice)
        secondFactorBanner(
          raftText(context, 'Two-step verification is on.'),
          status: RaftBannerRecipeStatus.success,
        ),
      BackupCodesPanel(codes: codes, client: client),
    ],
  ),
);

/// A step that only says something and closes with Done (Web `noPassword`).
Future<void> showSecondFactorNotice(
  BuildContext context, {
  required String title,
  required String description,
}) => showSecondFactorStep<void>(
  context,
  label: title,
  builder: (context) => SecondFactorStepDialog(
    key: const ValueKey('second-factor-notice-dialog'),
    title: title,
    actions: [secondFactorDone(context)],
    children: [RaftDialogDescription(description)],
  ),
);

/// One answer typed in a step: the text, the failure under the field and in
/// the banner, and the busy flag (Web `useAnswer`).
mixin SecondFactorAnswerState<T extends StatefulWidget> on State<T> {
  final answer = TextEditingController();
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the answer is edited, on every submit and on a method switch; the dialog state is dropped when it closes.
  String? fieldError, bannerError;
  bool busy = false;

  String get entered => normalizeSecondFactorCode(answer.text);

  void changed(String _) {
    if (fieldError != null || bannerError != null) {
      setState(() => fieldError = null);
    } else {
      setState(() {});
    }
  }

  /// Web `useFailureCopy` placement: a wrong or used code or a wrong
  /// password under the field, anything else in the banner.
  void failed(RaftClient client, Object error, SecondFactorAnswerKind kind) {
    final text = secondFactorFailureText(context, client, error, kind);
    final code = SecondFactorFailure.of(error).code;
    final underField = const {
      'second_factor_code_invalid',
      'backup_code_used',
      'password_incorrect',
    }.contains(code);
    setState(() {
      fieldError = underField ? text : null;
      bannerError = underField ? null : text;
    });
  }

  /// Runs [step] with the busy flag and the failures cleared first.
  Future<void> attempt(
    Future<void> Function() step, {
    required RaftClient client,
    required SecondFactorAnswerKind kind,
    bool Function(Object error)? handled,
  }) async {
    if (busy) return;
    setState(() {
      busy = true;
      fieldError = bannerError = null;
    });
    try {
      await step();
    } catch (error) {
      if (!mounted) return;
      if (handled?.call(error) != true) failed(client, error, kind);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    answer.dispose();
    super.dispose();
  }
}

/// One answer step (Web `TurnOnDialog` password / scan / enable steps,
/// `RegenerateDialog`, `TurnOffDialog`, `ReauthDialog`): one way to answer at
/// a time, the others as links under it (what was typed resets on a switch).
/// [run] sends it; its result closes the step. [handled] takes a refusal the
/// step deals with itself (closing with null, say) before the copy shows it.
class SecondFactorAnswerStep<R> extends StatefulWidget {
  const SecondFactorAnswerStep({
    super.key,
    required this.client,
    required this.title,
    required this.kinds,
    required this.commitLabel,
    required this.run,
    this.description,
    this.before = const [],
    this.after = const [],
    this.commitVariant = RaftButtonRecipeVariant.accent,
    this.handled,
  });
  final RaftClient client;
  final String title, commitLabel;
  final String? description;

  /// The ways to answer, the first one shown; empty: none this client can use
  /// (only a passkey), so the step says so and has no commit.
  final List<SecondFactorAnswerKind> kinds;
  final List<Widget> before, after;
  final RaftButtonRecipeVariant commitVariant;
  final Future<R> Function(SecondFactorAnswerKind kind, String entered) run;
  final bool Function(BuildContext context, Object error)? handled;

  @override
  State<SecondFactorAnswerStep<R>> createState() =>
      _SecondFactorAnswerStepState<R>();
}

class _SecondFactorAnswerStepState<R> extends State<SecondFactorAnswerStep<R>>
    with SecondFactorAnswerState {
  late SecondFactorAnswerKind? kind = widget.kinds.firstOrNull;

  String get typed =>
      kind == SecondFactorAnswerKind.password ? answer.text : entered;

  Future<void> submit() async {
    final current = kind;
    if (current == null || typed.isEmpty || busy) return;
    final value = typed;
    await attempt(
      () async {
        final result = await widget.run(current, value);
        if (mounted) Navigator.of(context).pop(result);
      },
      client: widget.client,
      kind: current,
      handled: widget.handled == null
          ? null
          : (error) => widget.handled!(context, error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = kind;
    final others = [
      for (final other in widget.kinds)
        if (other != current) other,
    ];
    return SecondFactorStepDialog(
      key: const ValueKey('second-factor-answer-step'),
      title: widget.title,
      busy: busy,
      actions: [
        secondFactorCancel(context, busy: busy),
        if (current != null)
          secondFactorCommit(
            context,
            label: widget.commitLabel,
            variant: widget.commitVariant,
            busy: busy,
            onPressed: typed.isEmpty ? null : submit,
          ),
      ],
      children: [
        if (widget.description case final description?)
          RaftDialogDescription(description),
        ...widget.before,
        if (current == null)
          secondFactorBanner(
            raftText(
              context,
              "This browser can't use passkeys. Use another way, or open Raft in a browser that has your passkey.",
            ),
          )
        else
          SecondFactorAnswerField(
            key: ValueKey('second-factor-field-${current.name}'),
            kind: current,
            controller: answer,
            enabled: !busy,
            error: fieldError,
            onChanged: changed,
            onSubmitted: submit,
          ),
        if (others.isNotEmpty)
          Wrap(
            // Web `flex flex-wrap gap-x-4 gap-y-1`.
            spacing: RaftSpace.x4,
            runSpacing: RaftSpace.x1,
            children: [
              for (final other in others)
                RaftAuthTextLink(
                  key: ValueKey('second-factor-use-${other.name}'),
                  label: raftText(
                    context,
                    other == SecondFactorAnswerKind.backupCode
                        ? 'Use a backup code'
                        : 'Use authenticator code',
                  ),
                  onTap: busy
                      ? null
                      : () => setState(() {
                          kind = other;
                          answer.clear();
                          fieldError = bannerError = null;
                        }),
                ),
            ],
          ),
        if (bannerError case final error?)
          secondFactorBanner(error, key: const ValueKey('second-factor-error')),
        ...widget.after,
      ],
    );
  }
}
