import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/app_install_expectation.dart';
import '../data/cause_notice.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import 'connected_app_consent.dart';
import 'management_support.dart';

class ConnectedAppPromptTextPanel extends StatefulWidget {
  const ConnectedAppPromptTextPanel({
    super.key,
    required this.workspace,
    required this.clientId,
    required this.service,
    this.onReviewed,
    this.onPendingText,
    this.onConfirmed,
    this.published = false,
  });

  final WorkspaceController workspace;
  final String clientId;
  final String? service;
  final Future<void> Function()? onReviewed;
  final ValueChanged<ConnectedAppPromptText>? onPendingText;
  final VoidCallback? onConfirmed;
  final bool published;

  @override
  State<ConnectedAppPromptTextPanel> createState() =>
      _ConnectedAppPromptTextPanelState();
}

class _ConnectedAppPromptTextPanelState
    extends State<ConnectedAppPromptTextPanel> {
  static const _changed =
      'The text changed while you were looking at it. Review the current text, then try again.';
  static const _reviewFailed = "Couldn't review the text update.";
  final reason = TextEditingController();
  final canReject = ValueNotifier(false);
  late final authority = pageIdentity(widget.workspace);
  late final issue = CauseNotice(scope: () => pageIdentity(widget.workspace));
  Map<String, dynamic> state = {};
  bool busy = false;

  bool get reviewer => widget.onReviewed != null;
  bool get current => mounted && authority == pageIdentity(widget.workspace);
  String get path => '/integrations/clients/${widget.clientId}/prompt-text';
  String get snapshot => 'app-prompt-text:${widget.clientId}';
  RaftClient get client => widget.workspace.client;
  String tr(String message) => raftText(context, message);

  @override
  void initState() {
    super.initState();
    state = managementMap(
      readPageSnapshot(widget.workspace, snapshot)?['state'],
    );
    read(first: true);
  }

  @override
  void dispose() {
    reason.dispose();
    canReject.dispose();
    super.dispose();
  }

  void accept(Map<String, dynamic> next) {
    setState(() => state = next);
    writePageSnapshot(widget.workspace, snapshot, authority, {'state': next});
  }

  Future<void> read({bool first = false}) async {
    Map<String, dynamic> next;
    try {
      next = managementMap(await client.get(path));
    } on RaftApiException {
      next = {};
    }
    if (!current) return;
    accept(next);
    final pending = text(next['pending']);
    if (first && pending != null) widget.onPendingText?.call(pending);
  }

  ConnectedAppPromptText? text(Object? raw) =>
      ConnectedAppPromptText.read(raw, service: widget.service);

  Future<void> review(String revision, {String? rejection}) async {
    if (!current || busy) return;
    setState(() {
      busy = true;
      issue.clear();
    });
    try {
      await client.post(
        '$path/review',
        data: {
          'decision': rejection == null ? 'approve' : 'reject',
          'expected_revision_id': revision,
          'reason': ?rejection,
        },
      );
      if (!current) return;
      reason.clear();
      canReject.value = false;
      await read();
      if (current) await widget.onReviewed?.call();
    } catch (error) {
      if (!current) return;
      final String message;
      if (error is RaftApiException &&
          (error.status == 404 ||
              (error.status == 409 &&
                  error.details['code'] == 'PROMPT_TEXT_REVIEW_STALE'))) {
        await read();
        if (!current) return;
        message = error.status == 404
            ? 'Nothing is waiting for review any more.'
            : _changed;
      } else {
        message = userErrorText(error, fallback: _reviewFailed, where: path);
      }
      if (rejection != null) throw StateError(tr(message));
      setState(() => issue.raise(tr(message)));
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  Future<void> reject() async {
    setState(issue.clear);
    await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: const ValueKey('app-prompt-text-reject-dialog'),
        title: tr('Reject text update'),
        plainMessage: true,
        confirmLabel: tr('Reject'),
        confirmVariant: RaftButtonRecipeVariant.warning,
        loadingLabel: tr('Rejecting...'),
        confirmEnabled: canReject,
        confirmKey: const ValueKey('app-prompt-text-reject-confirm'),
        content: RaftField(
          label: tr('Reason for rejecting'),
          hint: tr('The developer sees this.'),
          required: true,
          child: RaftTextarea(
            fieldKey: const ValueKey('app-prompt-text-reject-reason'),
            controller: reason,
            rows: 3,
            maxLength: 2000,
            growsWithScale: true,
            onChanged: (value) => canReject.value = value.trim().isNotEmpty,
          ),
        ),
        onConfirm: () async {
          final revision = managementMap(state['pending'])['id'];
          if (revision is! String || state['can_review'] != true) {
            throw StateError(tr('Nothing is waiting for review any more.'));
          }
          await review(revision, rejection: reason.text.trim());
        },
      ),
      overModal: true,
    );
  }

  Future<void> confirm(String revision) async {
    if (!current || busy) return;
    setState(() {
      busy = true;
      issue.clear();
    });
    try {
      await client.request(
        'PUT',
        '$path/confirm',
        data: {'expected_revision_id': revision},
      );
      if (current) {
        accept({...state, 'local_confirmed_revision_id': revision});
        widget.onConfirmed?.call();
      }
    } catch (error) {
      if (!current) return;
      if (error is RaftApiException && isAppPermissionsChanged(error)) {
        final moved = error.details['current_text_revision_id'];
        if (moved is String && moved != revision) {
          final fields = managementMap(error.details['current_text']);
          if (text(fields) != null) {
            accept({
              ...state,
              'current': {...fields, 'id': moved},
            });
          } else {
            await read();
          }
          if (current) setState(() => issue.raise(tr(_changed)));
          return;
        }
      }
      final message = userErrorText(
        error,
        fallback: "Couldn't confirm the text.",
        where: path,
      );
      setState(() => issue.raise(tr(message)));
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!current || state.isEmpty) return const SizedBox.shrink();
    final active = managementMap(state['current']);
    final pending = managementMap(state['pending']);
    final rejected = managementMap(state['rejected']);
    final activeText = text(active);
    final pendingText = text(pending);
    final activeId = active['id'];
    final pendingId = pending['id'];
    const pendingBadge = 'Text update pending Raft review';
    final comparison = ConnectedAppPromptComparison(
      before: activeText,
      after: pendingText,
      beforeTitle: 'Live now',
      afterTitle: 'Submitted for review',
    );
    final message = issue.message;
    if (reviewer) {
      final canReview =
          state['can_review'] == true &&
          pendingId is String &&
          pendingText != null;
      if (!canReview && message == null) return const SizedBox.shrink();
      return RaftConnectedAppDetailSection(
        title: 'Agent prompt text',
        cream: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: RaftSpace.x3,
          children: [
            if (canReview) ...[
              RaftConnectedAppParagraph(
                tr(
                  "The developer changed the text this app adds to agent prompts. Approved text goes live, then each Server's admins confirm it.",
                ),
                small: true,
              ),
              _badge(pendingBadge),
              comparison,
            ],
            if (message != null) RaftErrorBanner(message),
            if (canReview)
              Wrap(
                alignment: WrapAlignment.end,
                spacing: RaftSpace.x2,
                runSpacing: RaftSpace.x2,
                children: [
                  RaftButton(
                    label: tr('Reject text update'),
                    tone: RaftButtonRecipeVariant.outline,
                    onPressed: busy ? null : reject,
                  ),
                  RaftButton(
                    label: tr(busy ? 'Approving...' : 'Approve text update'),
                    onPressed: busy ? null : () => review(pendingId),
                  ),
                ],
              ),
          ],
        ),
      );
    }
    final needsConfirmation =
        activeId is String &&
        activeText != null &&
        activeId != state['local_confirmed_revision_id'];
    final rejectedText = pendingText == null ? text(rejected) : null;
    if (!widget.published &&
        pendingText == null &&
        rejectedText == null &&
        !needsConfirmation) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x3,
      children: [
        if (widget.published)
          RaftBanner(
            live: false,
            status: RaftBannerRecipeStatus.info,
            description: tr(
              "This app is published, so changes to its name, description and When to use go through Raft review first, then each Server's admins confirm them. Until then, agents keep using the last confirmed text.",
            ),
          ),
        if (pendingText != null) ...[_badge(pendingBadge), comparison],
        if (rejectedText != null) ...[
          RaftBanner(
            live: false,
            description: raftFormat(
              context,
              'Raft rejected the text update, so agents keep using the last confirmed text. Reason: {reason}',
              {'reason': rejected['reject_reason'] ?? ''},
            ),
          ),
          ConnectedAppPromptTextBlock(
            title: 'Rejected text',
            text: rejectedText,
          ),
        ],
        if (needsConfirmation) ...[
          RaftBanner(
            live: false,
            description: tr(
              "An agent changed the text this app adds to agent prompts. Until an admin confirms it, agents keep using the last confirmed version. Confirmed text reaches each agent the next time it starts.",
            ),
            action: widget.workspace.can('manageIntegrations')
                ? RaftButton(
                    label: tr(busy ? 'Confirming...' : 'Confirm text'),
                    tone: RaftButtonRecipeVariant.outline,
                    onPressed: busy ? null : () => confirm(activeId),
                  )
                : null,
          ),
          ConnectedAppPromptTextBlock(
            title: 'After you confirm',
            text: activeText,
          ),
        ],
        if (message != null) RaftErrorBanner(message),
      ],
    );
  }

  Widget _badge(String label) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: RaftSettingsRecipeBadge(
      label: tr(label),
      variant: RaftBadgeRecipeVariant.warning,
    ),
  );
}
