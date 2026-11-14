// Web v1.24.0 Settings › Account › Passkeys (components/settings/
// PasskeysSection.tsx): list, rename and delete the person's passkeys. Sits
// before Two-step verification.
//
// Adding a passkey needs a native passkey provider and an app origin the
// server trusts; this client has neither yet (2654e77c), so Add is disabled
// with Web's "can't create passkeys" line, as in a browser without WebAuthn.
// WP-PASSKEY connects it.
//
// Deleting is confirmed first; with two-step verification on, the server
// also asks for a second-factor answer in the same request (403
// `step_up_required` with `methods`), and never takes the last way to verify
// (the menu item is disabled and the reason sits under the list).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'account_security_answer.dart';
import 'account_security_dialogs.dart';
import 'account_security_two_step.dart';
import 'second_factor_step_up.dart';

const _nameMaxLength = 64;

/// Web `settings.passkeys.lastFactor`.
const _lastFactor =
    "This is your only passkey or authenticator app, so it can't be deleted while two-step verification is on. Add another passkey first, or <turnOff>turn off two-step verification</turnOff>.";

class PasskeysSection extends StatefulWidget {
  const PasskeysSection({
    super.key,
    required this.controller,
    required this.settings,
  });
  final WorkspaceController controller;
  final SecondFactorSettings settings;

  @override
  State<PasskeysSection> createState() => _PasskeysState();
}

class _PasskeysState extends State<PasskeysSection> {
  RaftClient get client => widget.controller.client;
  List<PasskeySummary>? passkeys;
  SecondFactorStatus? status;
  bool absent = false, loadFailed = false;
  int request = 0, revision = 0;

  @override
  void initState() {
    super.initState();
    revision = widget.settings.revision;
    widget.settings.addListener(settingsChanged);
    unawaited(load());
  }

  @override
  void dispose() {
    widget.settings.removeListener(settingsChanged);
    super.dispose();
  }

  void settingsChanged() {
    if (widget.settings.revision == revision) return;
    revision = widget.settings.revision;
    unawaited(load());
  }

  Future<void> load() async {
    final mine = ++request, user = client.user?.id;
    try {
      final result = await Future.wait([
        client.listPasskeys(),
        client.secondFactorStatus(),
      ]);
      if (!mounted || mine != request || client.user?.id != user) return;
      final next = result[1] as SecondFactorStatus;
      rememberSecondFactorStatus(client, next);
      setState(() {
        passkeys = result[0] as List<PasskeySummary>;
        status = next;
        loadFailed = false;
      });
    } catch (error) {
      if (!mounted || mine != request) return;
      setState(() {
        if (error is RaftApiException && error.status == 404) {
          absent = true;
        } else {
          loadFailed = true;
        }
      });
    }
  }

  Future<void> rename(PasskeySummary passkey) async {
    final renamed = await showSecondFactorStep<bool>(
      context,
      label: 'Rename passkey',
      builder: (_) => _RenameDialog(client: client, passkey: passkey),
    );
    if (renamed == true) widget.settings.changed();
  }

  Future<void> delete(PasskeySummary passkey) async {
    List<SecondFactorMethod>? stepUp;
    var gone = false;
    String refused(Object error) {
      final code = SecondFactorFailure.of(error).code;
      if (code == 'passkey_not_found') gone = true;
      // Here the reason is plain text: the dialog is the delete step, not
      // the place to turn it off.
      return code == 'last_factor'
          ? raftText(context, _lastFactor).replaceAll(RegExp('</?turnOff>'), '')
          : raftText(context, 'Something went wrong');
    }

    final confirmed = await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: const ValueKey('passkeys-delete-dialog'),
        title: raftFormat(context, 'Delete “{name}”?', {'name': passkey.name}),
        message: "You can't sign in or verify with this passkey after this. It stays in your password manager until you remove it there too. Your other browsers are signed out. Computers and the raft CLI stay connected.",
        confirmLabel: 'Delete passkey',
        confirmKey: const ValueKey('passkeys-delete-confirm'),
        onConfirm: () async {
          try {
            await client.removePasskey(passkey.id);
          } catch (error) {
            final failure = SecondFactorFailure.of(error);
            if (failure.code == 'step_up_required') {
              stepUp = failure.methods;
              return;
            }
            final text = refused(error);
            if (gone) return;
            throw RaftUserError(text);
          }
        },
      ),
    );
    if (confirmed != true || !mounted) return;
    final methods = stepUp;
    if (methods != null) {
      final verified = await showVerifyItsYou(
        context,
        client,
        methods: methods,
        description: raftText(
          context,
          "Two-step verification is on. Verify it's you to delete this passkey.",
        ),
        onAnswer: (answer) async {
          try {
            await client.removePasskey(passkey.id, answer: answer);
          } catch (error) {
            final code = SecondFactorFailure.of(error).code;
            if (code == 'last_factor' || code == 'passkey_not_found') {
              final text = refused(error);
              if (gone) return;
              throw RaftUserError(text);
            }
            rethrow;
          }
        },
      );
      if (!verified) return;
    }
    widget.settings.changed();
  }

  @override
  Widget build(BuildContext context) {
    if (absent) return const SizedBox.shrink();
    final rows = passkeys, s = status;
    if (rows == null && !loadFailed) return const SizedBox.shrink();
    // With two-step verification on, the only passkey goes only while an
    // authenticator app stays.
    final lastFactor = s != null && s.enabled && !s.totp && rows?.length == 1;
    return Padding(
      key: const ValueKey('passkeys-section'),
      padding: const EdgeInsets.only(bottom: RaftSpace.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RaftSettingsSectionHeader(
            label: 'Passkeys',
            glyph: RaftGlyph.keyRound,
          ),
          if (rows == null)
            secondFactorBanner(
              raftText(
                context,
                "Couldn't load your passkeys. Reload the page to try again.",
              ),
            )
          else ...[
            RaftListRowGroup(
              key: const ValueKey('passkeys-rows'),
              children: [
                _addRow(context, rows.isEmpty),
                for (final passkey in rows)
                  _PasskeyRow(
                    key: ValueKey('passkey-row-${passkey.id}'),
                    client: client,
                    passkey: passkey,
                    deleteDisabled: lastFactor,
                    onRename: () => rename(passkey),
                    onDelete: () => delete(passkey),
                  ),
              ],
            ),
            if (lastFactor)
              Padding(
                padding: const EdgeInsets.only(top: RaftSpace.x3),
                child: _LastFactorNote(
                  onTurnOff: widget.settings.requestTurnOff,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _addRow(BuildContext context, bool empty) {
    final body = RaftListRowBody(
      children: [
        const RaftListRowTitle('Passkeys'),
        const RaftListRowDescription(
          "This browser can't create passkeys. Add one from a browser that supports them, such as a recent Chrome, Safari, Edge or Firefox.",
          key: ValueKey('passkeys-unsupported'),
          wrap: true,
        ),
        if (empty) const RaftListRowDescription('No passkeys yet', wrap: true),
      ],
    );
    final add = RaftButton(
      key: const ValueKey('passkeys-add'),
      label: raftText(context, 'Add passkey'),
      tone: RaftButtonRecipeVariant.outline,
      size: RaftButtonRecipeSize.md,
      // WP-PASSKEY: needs a native passkey provider.
      onPressed: null,
    );
    return RaftListRow(
      variant: RaftListRowVariant.plain,
      interactive: false,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 512
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: RaftSpace.x3,
                    children: [body, add],
                  )
                : Row(
                    spacing: RaftSpace.x3,
                    children: [
                      Expanded(child: body),
                      add,
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _PasskeyRow extends StatelessWidget {
  const _PasskeyRow({
    super.key,
    required this.client,
    required this.passkey,
    required this.deleteDisabled,
    required this.onRename,
    required this.onDelete,
  });
  final RaftClient client;
  final PasskeySummary passkey;
  final bool deleteDisabled;
  final VoidCallback onRename, onDelete;

  @override
  Widget build(BuildContext context) {
    final label = raftFormat(context, 'Actions for {name}', {
      'name': passkey.name,
    });
    final added = secondFactorCompactDate(context, client, passkey.createdAt);
    final used = passkey.lastUsedAt;
    return RaftListRow(
      variant: RaftListRowVariant.plain,
      interactive: false,
      semanticLabel: passkey.name,
      children: [
        const RaftIconTile(glyph: RaftGlyph.keyRound),
        RaftListRowBody(
          children: [
            Row(
              spacing: RaftSpace.x2,
              children: [
                Flexible(child: RaftListRowTitle(passkey.name)),
                if (passkey.synced)
                  const RaftSettingsRecipeBadge(
                    label: 'Synced',
                    variant: RaftBadgeRecipeVariant.default_,
                    appearance: RaftBadgeRecipeAppearance.soft,
                  ),
              ],
            ),
            RaftListRowDescription(
              used == null
                  ? raftFormat(context, 'Added {added} · Not used yet', {
                      'added': added,
                    })
                  : raftFormat(context, 'Added {added} · Last used {used}', {
                      'added': added,
                      'used': secondFactorCompactDate(context, client, used),
                    }),
            ),
          ],
        ),
        RaftDropdownMenu(
          label: label,
          tooltip: label,
          align: RaftDropdownAlign.end,
          width: 160,
          triggerBuilder: (context, focus, open) => Focus(
            focusNode: focus,
            child: RaftIconButton(
              key: ValueKey('passkey-actions-${passkey.id}'),
              glyph: RaftGlyph.ellipsisVertical,
              tooltip: label,
              semanticLabel: label,
              onPressed: open,
            ),
          ),
          entries: [
            RaftMenuEntry(
              label: raftText(context, 'Rename'),
              glyph: RaftGlyph.pencil,
              onPressed: onRename,
            ),
            RaftMenuEntry(
              label: raftText(context, 'Delete'),
              glyph: RaftGlyph.trash2,
              onPressed: deleteDisabled ? null : onDelete,
            ),
          ],
        ),
      ],
    );
  }
}

/// Web `settings.passkeys.lastFactor` with its `<turnOff>` link.
class _LastFactorNote extends StatelessWidget {
  const _LastFactorNote({required this.onTurnOff});
  final VoidCallback onTurnOff;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = raftText(context, _lastFactor);
    final open = text.indexOf('<turnOff>'), close = text.indexOf('</turnOff>');
    final style = RaftTypography.body(t, size: 13, line: 18, color: t.muted);
    if (open < 0 || close < open) {
      return Text(text, style: style);
    }
    return Wrap(
      key: const ValueKey('passkeys-last-factor'),
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(text.substring(0, open), style: style),
        RaftAuthTextLink(
          key: const ValueKey('passkeys-last-factor-turn-off'),
          label: text.substring(open + '<turnOff>'.length, close),
          bold: true,
          onTap: onTurnOff,
        ),
        Text(text.substring(close + '</turnOff>'.length), style: style),
      ],
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.client, required this.passkey});
  final RaftClient client;
  final PasskeySummary passkey;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final name = TextEditingController(text: widget.passkey.name);
  bool busy = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the name is edited and on every submit; the dialog state is dropped when it closes.
  String? fieldError, bannerError;

  String get trimmed => name.text.trim();

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (trimmed.isEmpty || busy) return;
    setState(() {
      busy = true;
      fieldError = bannerError = null;
    });
    try {
      await widget.client.renamePasskey(widget.passkey.id, trimmed);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final code = SecondFactorFailure.of(error).code;
      if (code == 'passkey_not_found') {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        busy = false;
        if (code == 'invalid_request') {
          fieldError = raftText(
            context,
            'Enter a name of up to 64 characters.',
          );
        } else {
          bannerError = raftText(context, 'Something went wrong');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => SecondFactorStepDialog(
    key: const ValueKey('passkeys-rename-dialog'),
    title: 'Rename passkey',
    busy: busy,
    actions: [
      secondFactorCancel(context, busy: busy),
      secondFactorCommit(
        context,
        label: 'Save',
        busy: busy,
        onPressed: trimmed.isEmpty ? null : submit,
      ),
    ],
    children: [
      RaftField(
        label: raftText(context, 'Name'),
        hint: raftText(context, 'Only you see this name.'),
        error: fieldError,
        child: RaftTextInput(
          key: const ValueKey('passkeys-rename-name'),
          controller: name,
          autofocus: true,
          enabled: !busy,
          invalid: fieldError != null,
          maxLength: _nameMaxLength,
          semanticLabel: raftText(context, 'Name'),
          onChanged: (_) => setState(() => fieldError = bannerError = null),
          onSubmitted: (_) => submit(),
        ),
      ),
      if (bannerError case final error?) secondFactorBanner(error),
    ],
  );
}
