// Web AgentDetailPanel "Update official identity": on the server's onboarding
// agent (Cindy) a manager can adopt Raft's official name, display name, role
// and avatar. `GET /agents/:id/onboarding-identity-adoption` previews the
// changes (`canAdopt` false once the agent already matches); the button opens
// a review of each field, before -> after, and `POST` applies it. Granting the
// server admin role is called out. The server broadcasts `agent:updated`, so
// the profile follows by itself.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import 'private_route_guard.dart' show workspaceAuthority;

/// `OnboardingIdentityChange`.
typedef IdentityChange = ({
  String field,
  String label,
  String? before,
  String? after,
});

/// `OnboardingIdentityAdoptionPreview` as far as the screen reads it.
class IdentityAdoptionPreview {
  const IdentityAdoptionPreview({
    required this.canAdopt,
    required this.changes,
  });
  final bool canAdopt;
  final List<IdentityChange> changes;

  /// A change grants the onboarding agent the server admin role.
  bool get grantsServerAdmin =>
      changes.any((c) => c.field == 'serverRole' && c.after == 'admin');

  static IdentityAdoptionPreview? parse(Object? json) {
    if (json is! Map) return null;
    String? text(Object? v) => v is String ? v : null;
    return IdentityAdoptionPreview(
      canAdopt: json['canAdopt'] == true,
      changes: [
        if (json['changes'] is List)
          for (final c in json['changes'] as List)
            if (c is Map && c['field'] is String)
              (
                field: c['field'] as String,
                label: text(c['label']) ?? c['field'] as String,
                before: text(c['before']),
                after: text(c['after']),
              ),
      ],
    );
  }
}

String identityAdoptionPath(String agentId) =>
    '/agents/${Uri.encodeComponent(agentId)}/onboarding-identity-adoption';

class AgentOnboardingIdentity extends StatefulWidget {
  const AgentOnboardingIdentity({
    super.key,
    required this.controller,
    required this.agentId,
    required this.identityKey,
  });

  final WorkspaceController controller;
  final String agentId;

  /// The agent's name, display name, description and avatar: a change of any
  /// of them (the adoption itself, an edit elsewhere) reads the preview again.
  final String identityKey;

  @override
  State<AgentOnboardingIdentity> createState() =>
      _AgentOnboardingIdentityState();
}

class _AgentOnboardingIdentityState extends State<AgentOnboardingIdentity> {
  WorkspaceController get w => widget.controller;
  IdentityAdoptionPreview? _preview;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next read succeeds; the block is keyed by agent.
  String _error = '';
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  @override
  void didUpdateWidget(AgentOnboardingIdentity old) {
    super.didUpdateWidget(old);
    if (old.agentId != widget.agentId) {
      _preview = null;
      _error = '';
    }
    if (old.agentId != widget.agentId ||
        old.identityKey != widget.identityKey) {
      unawaited(_read());
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _read() async {
    final run = ++_generation;
    final authority = workspaceAuthority(w);
    try {
      final data = await w.client.get(identityAdoptionPath(widget.agentId));
      if (!mounted ||
          run != _generation ||
          authority != workspaceAuthority(w)) {
        return;
      }
      setState(() {
        _preview = IdentityAdoptionPreview.parse(data);
        _error = '';
      });
    } catch (e) {
      if (!mounted || run != _generation) return;
      if (e is RaftApiException && e.staleScope) return;
      setState(() {
        _preview = null;
        _error = userErrorText(
          e,
          fallback: 'Failed to load official identity',
          where: 'onboarding identity adoption',
        );
      });
    }
  }

  Future<void> _adopt() async {
    final preview = _preview;
    if (preview == null || preview.changes.isEmpty) return;
    await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: const ValueKey('agent-identity-adoption-dialog'),
        confirmKey: const ValueKey('agent-identity-adoption-confirm'),
        title: preview.grantsServerAdmin
            ? 'Update identity and admin role'
            : 'Update official identity',
        confirmLabel: preview.grantsServerAdmin
            ? 'Update identity and role'
            : 'Update identity',
        loadingLabel: 'Updating…',
        confirmVariant: RaftButtonRecipeVariant.primary,
        maxWidth: 448,
        content: _Review(preview),
        onConfirm: () async {
          final data = await w.command(
            'POST',
            identityAdoptionPath(widget.agentId),
          );
          final next = IdentityAdoptionPreview.parse(data);
          if (mounted && next != null) setState(() => _preview = next);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAdopt = _preview?.canAdopt == true;
    if (!canAdopt && _error.isEmpty) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    return RaftPanelSection(
      key: const ValueKey('agent-identity-adoption'),
      topBorder: false,
      vertical: 12,
      gap: 8,
      children: [
        if (canAdopt)
          Align(
            alignment: Alignment.centerLeft,
            child: RaftRecipeButton(
              key: const ValueKey('agent-identity-adoption-button'),
              label: raftText(context, 'Update official identity'),
              variant: RaftButtonRecipeVariant.accent,
              size: RaftButtonRecipeSize.sm,
              onPressed: () => unawaited(_adopt()),
            ),
          ),
        if (_error.isNotEmpty)
          RaftCssText(
            _error,
            key: const ValueKey('agent-identity-adoption-error'),
            style: RaftPanelText.warningCaption(t),
          ),
      ],
    );
  }
}

/// The body of the review: what changes, field by field.
class _Review extends StatelessWidget {
  const _Review(this.preview);
  final IdentityAdoptionPreview preview;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    String value(String? v) =>
        v != null && v.trim().isNotEmpty ? v : tr('Blank');
    return RaftGapColumn(
      gap: 16,
      children: [
        RaftCssText(
          tr('Review official identity changes'),
          style: RaftPanelText.profileValue(t),
        ),
        RaftGapColumn(
          gap: 12,
          children: [
            for (final c in preview.changes)
              RaftGapColumn(
                key: ValueKey('identity-change-${c.field}'),
                gap: 2,
                children: [
                  RaftCssText(c.label, style: RaftInfoRow.labelStyle(t)),
                  RaftGapRow(
                    gap: 8,
                    children: [
                      Flexible(
                        child: RaftCssText(
                          value(c.before),
                          style: RaftPanelText.profileValue(t),
                        ),
                      ),
                      const RaftIcon(RaftGlyph.moveRight, size: 16),
                      Flexible(
                        child: RaftCssText(
                          value(c.after),
                          style: RaftPanelText.bold(t),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
        if (preview.grantsServerAdmin)
          RaftBanner(
            key: const ValueKey('identity-grants-admin'),
            size: RaftBannerRecipeSize.sm,
            glyph: RaftGlyph.triangleAlert,
            description: tr(
              'This will grant the onboarding agent admin permissions.',
            ),
          ),
        RaftCssText(
          tr('You can customize the agent again after updating its identity.'),
          style: RaftPanelText.caption(t),
        ),
      ],
    );
  }
}
