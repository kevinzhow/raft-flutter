// Settings > Workspace > Administration (SettingsPanel.tsx
// AdministrationTabContent at raft-source 26f77ef), section by section:
//   AdminsSection, SystemChannelsSection, InvitesSection, JoinLinksSection,
//   PreJoinAgreementSection, OnboardingAgentSection, ServerTranslationSection,
//   WorkspaceProductAnalyticsSection (UsageDataSettings.tsx SwitchRow) and
//   MemberPermissionsSection.
// Presentation only: the app owns data, permission gates and requests and
// passes values plus callbacks; every class list is resolved here.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../raft_ui.dart';
import 'anchored_popup.dart';
import 'recipes/input.g.dart' show RaftInputRecipe;

/// `text-foreground-muted theme-brutal:text-black/40`.
Color _quiet(RaftTokens t) =>
    t.brutal ? Colors.black.withValues(alpha: .4) : t.muted;

/// The `sm:` breakpoint (640px viewport).
bool _sm(BuildContext context) => raftBreakpointWidth(context) >= 640;

/// The `md:` breakpoint (768px viewport).
bool _md(BuildContext context) => raftBreakpointWidth(context) >= 768;

/// Save button label state shared by the section forms.
enum RaftAdminSaveState { idle, saving, saved }

/// One Administration section: `div.mb-6` with SectionHeader (`mb-3`) and
/// its card. [regionKey] keys the section box (bottom margin excluded).
class RaftAdminSection extends StatelessWidget {
  const RaftAdminSection({
    super.key,
    required this.label,
    required this.glyph,
    required this.child,
    this.count,
    this.regionKey,
  });
  final String label;
  final RaftGlyph glyph;
  final int? count;
  final Widget child;
  final Key? regionKey;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: RaftCssPixelSnap(
      child: RaftInheritedFont(
        child: Column(
          key: regionKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RaftSettingsSectionHeader(
              label: label,
              glyph: glyph,
              count: count,
              display: true,
            ),
            child,
          ],
        ),
      ),
    ),
  );
}

/// `Banner intent="warning" density="sm" className="font-bold"`.
class RaftAdminWarning extends StatelessWidget {
  const RaftAdminWarning(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) =>
      RaftErrorBanner(message, small: true, bold: true);
}

/// `Button variant="accent" size="sm"` Save / Saving… / (Check) Saved.
class RaftAdminSaveButton extends StatelessWidget {
  const RaftAdminSaveButton({
    super.key,
    required this.state,
    required this.onPressed,
    this.savedCheck = true,
  });
  final RaftAdminSaveState state;
  final VoidCallback? onPressed;

  /// `<Check size={14} />` before "Saved" (the checkbox forms; the
  /// agreement and onboarding saves show the word only).
  final bool savedCheck;
  @override
  Widget build(BuildContext context) => RaftSettingsRecipeButton(
    label: switch (state) {
      RaftAdminSaveState.saving => 'Saving…',
      RaftAdminSaveState.saved => 'Saved',
      RaftAdminSaveState.idle => 'Save',
    },
    glyph: state == RaftAdminSaveState.saved && savedCheck
        ? RaftGlyph.check
        : null,
    glyphSize: 14,
    variant: RaftButtonRecipeVariant.accent,
    size: RaftButtonRecipeSize.sm,
    onPressed: onPressed,
  );
}

/// `label.flex.items-start.gap-3`: a `Checkbox size="md"` (`mt-0.5`) and the
/// `text-sm font-bold` title over the `mt-0.5 text-xs` description.
class RaftAdminCheckboxRow extends StatelessWidget {
  const RaftAdminCheckboxRow({
    super.key,
    required this.title,
    required this.description,
    required this.checked,
    this.onChanged,
    this.dimmed = false,
    this.checkboxKey,
  });
  final String title, description;
  final bool checked;

  /// Null disables the checkbox.
  final ValueChanged<bool>? onChanged;

  /// The label's `opacity-60`.
  final bool dimmed;
  final Key? checkboxKey;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), text = RaftSettingsText(t);
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: RaftCheckbox(
            key: checkboxKey,
            value: checked,
            size: RaftCheckboxRecipeSize.md,
            semanticLabel: raftText(context, title),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onChanged == null ? null : () => onChanged!(!checked),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RaftCssText(raftText(context, title), style: text.title),
                const SizedBox(height: 2),
                RaftCssText(
                  raftText(context, description),
                  style: text.description,
                ),
              ],
            ),
          ),
        ),
      ],
    );
    return dimmed ? Opacity(opacity: .6, child: row) : row;
  }
}

/// SystemChannelsSection / MemberPermissionsSection / ServerTranslationSection:
/// `form.p-4.space-y-3` holding the checkbox row, warnings and Save.
class RaftAdminCheckboxForm extends StatelessWidget {
  const RaftAdminCheckboxForm({
    super.key,
    required this.title,
    required this.description,
    required this.checked,
    this.onChanged,
    this.dimmed = false,
    this.warnings = const [],
    this.save,
    this.onSave,
    this.checkboxKey,
    this.saveKey,
  });
  final String title, description;
  final bool checked, dimmed;
  final ValueChanged<bool>? onChanged;
  final List<String> warnings;

  /// Null hides the Save button (no edit permission).
  final RaftAdminSaveState? save;
  final VoidCallback? onSave;
  final Key? checkboxKey, saveKey;

  @override
  Widget build(BuildContext context) => RaftSettingsCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RaftAdminCheckboxRow(
          checkboxKey: checkboxKey,
          title: title,
          description: description,
          checked: checked,
          dimmed: dimmed,
          onChanged: onChanged,
        ),
        for (final warning in warnings) ...[
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: RaftAdminWarning(warning)),
        ],
        if (save case final save?) ...[
          const SizedBox(height: 12),
          RaftAdminSaveButton(key: saveKey, state: save, onPressed: onSave),
        ],
      ],
    ),
  );
}

// ---------------------------------------------------------------- admins

/// One Owners & Admins row or picker candidate.
class RaftAdminPrincipal {
  const RaftAdminPrincipal({
    required this.key,
    required this.label,
    required this.agent,
    this.subtitle,
    this.avatarUrl,
    this.optionLabel,
  });

  /// `getAdminPrincipalKey` (`human:<id>` / `agent:<id>`).
  final String key;
  final String label;
  final bool agent;

  /// Row subtitle (`email · Owner`, `Agent · Admin`).
  final String? subtitle;

  /// Picker option text (`Label · email`, `{name} · Agent`).
  final String? optionLabel;
  final String? avatarUrl;
}

/// A listed owner/admin with its right-hand action.
class RaftAdminRow {
  const RaftAdminRow({
    required this.principal,
    this.removeLabel,
    this.onRemove,
    this.note,
    this.saving = false,
  });
  final RaftAdminPrincipal principal;

  /// `Remove Owner` / `Remove Admin`; null shows [note] instead.
  final String? removeLabel;
  final VoidCallback? onRemove;

  /// `Last owner` / `Owner only`.
  final String? note;

  /// This row's role change is in flight (`Saving…`).
  final bool saving;
}

/// AdminsSection's card: the add-owner/admin picker row, the owner/admin
/// list and the error banner.
class RaftAdminsCard extends StatelessWidget {
  const RaftAdminsCard({
    super.key,
    required this.candidates,
    required this.rows,
    required this.selectedKey,
    required this.onSelect,
    required this.role,
    required this.roleOptions,
    required this.onRole,
    required this.onPromote,
    this.saving = false,
    this.promoting = false,
    this.error,
  });
  final List<RaftAdminPrincipal> candidates;
  final List<RaftAdminRow> rows;
  final String? selectedKey;
  final ValueChanged<String?> onSelect;

  /// The selected role (`owner` / `admin`) and the enabled options.
  final String role;
  final Set<String> roleOptions;
  final ValueChanged<String> onRole;
  final VoidCallback onPromote;

  /// Any role change in flight (disables every control).
  final bool saving;

  /// The selected candidate is being promoted (`Saving…`).
  final bool promoting;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), text = RaftSettingsText(t);
    final selected = candidates.where((c) => c.key == selectedKey).firstOrNull;
    final canPromote = selected != null && roleOptions.isNotEmpty && !saving;
    // The picker, role and action stack when text is scaled up: they no longer
    // fit one row.
    final wide = _sm(context) && !RaftScaled.grows(context);
    final picker = RaftAdminPrincipalPicker(
      candidates: candidates,
      selectedKey: selected?.key,
      enabled: candidates.isNotEmpty && !saving,
      onSelect: onSelect,
    );
    final roleSelect = RaftSelectField<String>(
      key: const ValueKey('admin-role-select'),
      label: raftText(context, 'Role'),
      placeholder: 'Role',
      value: role,
      items: [
        for (final (value, label) in const [
          ('owner', 'Owner'),
          ('admin', 'Admin'),
        ])
          DropdownMenuItem(
            value: value,
            enabled: roleOptions.contains(value),
            child: RaftCssText(raftText(context, label)),
          ),
      ],
      onChanged: canPromote
          ? (value) {
              if (value != null) onRole(value);
            }
          : null,
    );
    final promote = RaftSettingsRecipeButton(
      key: const ValueKey('admin-update-role'),
      label: promoting ? 'Saving…' : 'Update Role',
      variant: RaftButtonRecipeVariant.accent,
      size: RaftButtonRecipeSize.sm,
      expand: !wide,
      onPressed: canPromote ? onPromote : null,
    );
    return RaftSettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftCssText(
            raftText(context, 'Add owner/admin'),
            style: raftSettingsBody(
              t,
              size: 12,
              line: 16,
              weight: FontWeight.w700,
              color: text.muted,
            ),
          ),
          const SizedBox(height: 8),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: picker),
                const SizedBox(width: 8),
                SizedBox(width: 120, child: roleSelect),
                const SizedBox(width: 8),
                promote,
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                picker,
                const SizedBox(height: 8),
                roleSelect,
                const SizedBox(height: 8),
                promote,
              ],
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: text.edge, width: 2)),
            ),
            child: rows.isEmpty
                ? RaftCssText(
                    raftText(context, 'No owners or admins yet.'),
                    style: raftSettingsBody(
                      t,
                      size: 12,
                      line: 16,
                      color: _quiet(t),
                    ).copyWith(fontStyle: FontStyle.italic),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, row) in rows.indexed) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _AdminListRow(row: row, saving: saving),
                      ],
                    ],
                  ),
          ),
          if (error case final error?) ...[
            const SizedBox(height: 16),
            RaftAdminWarning(error),
          ],
        ],
      ),
    );
  }
}

class _AdminListRow extends StatelessWidget {
  const _AdminListRow({required this.row, required this.saving});
  final RaftAdminRow row;
  final bool saving;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final p = row.principal;
    return RaftAvatarListRow(
      key: ValueKey('admin-row-${p.key}'),
      avatar: RaftAvatarSlot(
        name: p.label,
        slot: RaftAvatarSlotContext.surfaceList,
        agent: p.agent,
        avatarUrl: p.avatarUrl,
      ),
      name: p.label,
      subtitle: p.subtitle,
      rightContent: [
        if (row.removeLabel != null)
          RaftSettingsRecipeButton(
            key: ValueKey('admin-remove-${p.key}'),
            label: row.saving ? 'Saving…' : row.removeLabel!,
            size: RaftButtonRecipeSize.sm,
            onPressed: saving ? null : row.onRemove,
          )
        else
          RaftCssText(
            raftText(context, row.note ?? ''),
            style: RaftTypography.mono(t, size: 10, line: 15, color: _quiet(t)),
          ),
      ],
    );
  }
}

/// The `admin-principal-picker` trigger (`h-10 border ... text-xs font-bold
/// shadow-raft-sm`, ChevronRight turning 90° while open) and its
/// SelectionPopover (`width="trigger"`, searchable, `top-[calc(100%+8px)]`).
class RaftAdminPrincipalPicker extends StatefulWidget {
  const RaftAdminPrincipalPicker({
    super.key,
    required this.candidates,
    required this.selectedKey,
    required this.onSelect,
    this.enabled = true,
  });
  final List<RaftAdminPrincipal> candidates;
  final String? selectedKey;
  final ValueChanged<String?> onSelect;
  final bool enabled;
  @override
  State<RaftAdminPrincipalPicker> createState() =>
      _RaftAdminPrincipalPickerState();
}

class _RaftAdminPrincipalPickerState extends State<RaftAdminPrincipalPicker> {
  final portal = OverlayPortalController();
  final link = LayerLink();
  final search = TextEditingController();
  final region = GlobalKey();
  double width = 0;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RaftAdminPrincipalPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && portal.isShowing) portal.hide();
  }

  void toggle() {
    setState(() {
      if (portal.isShowing) {
        portal.hide();
      } else {
        // Reset-on-open search, like the Web effect.
        search.clear();
        portal.show();
      }
    });
  }

  void close() {
    if (portal.isShowing) setState(portal.hide);
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), text = RaftSettingsText(t);
    final selected = widget.candidates
        .where((c) => c.key == widget.selectedKey)
        .firstOrNull;
    final open = portal.isShowing;
    final grows = RaftScaled.grows(context);
    // Agents read their plain label on the trigger; humans `Label · email`.
    final label =
        (selected != null && !selected.agent ? selected.optionLabel : null) ??
        selected?.label ??
        raftText(
          context,
          widget.candidates.isNotEmpty
              ? 'Search members...'
              : 'No members to promote',
        );
    final trigger = RaftInteractive(
      key: const ValueKey('admin-principal-picker'),
      onPressed: widget.enabled ? toggle : null,
      semanticLabel: label,
      builder: (context, state) {
        final hover = state.hovered && state.enabled;
        final box = RaftSettingsCard.box(
          t,
          height: grows ? null : 40,
          minHeight: grows ? 40 : null,
          padding: grows
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
              : const EdgeInsets.symmetric(horizontal: 12),
          color: hover
              ? (t.brutal
                    ? t.colors['color-soft-signal']!.withValues(alpha: .3)
                    : t.colors['primary-soft'])
              : null,
          child: Row(
            children: [
              Expanded(
                child: RaftCssText(
                  label,
                  maxLines: grows ? null : 1,
                  softWrap: grows,
                  overflow: grows ? TextOverflow.clip : TextOverflow.ellipsis,
                  style: raftSettingsBody(
                    t,
                    size: 12,
                    line: 16,
                    weight: FontWeight.w700,
                    color: selected != null
                        ? text.strong
                        : t.brutal
                        ? Colors.black.withValues(alpha: .45)
                        : t.muted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: open ? .25 : 0,
                duration: const Duration(milliseconds: 150),
                child: RaftIcon(
                  RaftGlyph.chevronRight,
                  size: 14,
                  color: text.strong,
                ),
              ),
            ],
          ),
        );
        return state.enabled ? box : Opacity(opacity: .5, child: box);
      },
    );
    return KeyedSubtree(
      key: const ValueKey('admin-principal-picker-region'),
      child: CompositedTransformTarget(
        key: region,
        link: link,
        child: OverlayPortal(
          controller: portal,
          overlayChildBuilder: raftBackDismissed(close, (context) {
            final box = this.context.findRenderObject() as RenderBox?;
            final width = box?.size.width ?? 240;
            final needle = search.text.trim().toLowerCase();
            final options = [
              for (final c in widget.candidates)
                if (needle.isEmpty ||
                    '${c.label} ${c.optionLabel ?? ''}'.toLowerCase().contains(
                      needle,
                    ))
                  c,
            ];
            return CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): close,
              },
              child: Stack(
                children: [
                  // Web: a mousedown outside the picker closes it.
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (_) => close(),
                    ),
                  ),
                  RaftAnchoredPopup(
                    anchorKey: region,
                    movement: Scrollable.maybeOf(this.context)?.position,
                    gap: 8,
                    child: RaftSelectionPopover(
                      key: const ValueKey('admin-principal-popover'),
                      title: raftText(context, 'Members'),
                      width: width,
                      searchController: search,
                      searchPlaceholder: raftText(context, 'Search members...'),
                      onSearchChanged: (_) => setState(() {}),
                      emptyLabel: raftText(context, 'No matching members'),
                      clearLabel: raftText(context, 'Clear'),
                      onClear: selected == null
                          ? null
                          : () {
                              widget.onSelect(null);
                              close();
                            },
                      options: [
                        for (final c in options)
                          RaftSelectionOption(
                            rowKey: ValueKey('admin-candidate-${c.key}'),
                            label: c.optionLabel ?? c.label,
                            checked: c.key == widget.selectedKey,
                            reserveLeadingSlot: true,
                            leading: RaftAvatarSlot(
                              name: c.label,
                              slot: RaftAvatarSlotContext.compactList,
                              agent: c.agent,
                              avatarUrl: c.avatarUrl,
                            ),
                            onTap: () {
                              widget.onSelect(c.key);
                              search.clear();
                              close();
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          child: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
            },
            child: Actions(
              actions: {
                DismissIntent: CallbackAction<DismissIntent>(
                  onInvoke: (_) => close(),
                ),
              },
              child: trigger,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- invites

class RaftAdminInvite {
  const RaftAdminInvite({
    required this.id,
    required this.email,
    required this.date,
    required this.onRevoke,
  });
  final String id, email, date;
  final VoidCallback onRevoke;
}

/// InvitesSection's card: bordered invite rows (`space-y-1.5`) with the
/// revoke icon button, or the italic empty line once loaded.
class RaftAdminInvitesCard extends StatelessWidget {
  const RaftAdminInvitesCard({
    super.key,
    required this.invites,
    this.loading = false,
  });
  final List<RaftAdminInvite> invites;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), text = RaftSettingsText(t);
    return RaftSettingsCard(
      child: invites.isEmpty
          ? loading
                ? const SizedBox.shrink()
                : _EmptyLine('No pending invites.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, invite) in invites.indexed) ...[
                  if (i > 0) const SizedBox(height: 6),
                  Container(
                    key: ValueKey('admin-invite-${invite.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: text.softEdge,
                        width: t.brutal ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: RaftCssText(
                            invite.email,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: RaftTypography.mono(
                              t,
                              size: 12,
                              line: 16,
                              color: text.strong,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        RaftCssText(
                          invite.date,
                          style: RaftTypography.mono(
                            t,
                            size: 10,
                            line: 15,
                            color: _quiet(t),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _IconAction(
                          key: ValueKey('admin-invite-revoke-${invite.id}'),
                          tooltip: 'Revoke invite',
                          glyph: RaftGlyph.x,
                          size: 12,
                          onPressed: invite.onRevoke,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// `Button variant="outline" size="icon-sm"` inside a Tooltip.
class _IconAction extends StatelessWidget {
  const _IconAction({
    super.key,
    required this.tooltip,
    required this.glyph,
    required this.size,
    required this.onPressed,
  });
  final String tooltip;
  final RaftGlyph glyph;
  final double size;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => RaftTooltip(
    message: raftText(context, tooltip),
    child: Semantics(
      label: raftText(context, tooltip),
      button: true,
      child: RaftSettingsRecipeButton(
        label: '',
        glyph: glyph,
        glyphSize: size,
        size: RaftButtonRecipeSize.iconSm,
        onPressed: onPressed,
      ),
    ),
  );
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.message);
  final String message;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftCssText(
      raftText(context, message),
      style: raftSettingsBody(
        t,
        size: 12,
        line: 16,
        color: _quiet(t),
      ).copyWith(fontStyle: FontStyle.italic),
    );
  }
}

// ---------------------------------------------------------------- join links

class RaftAdminJoinLink {
  const RaftAdminJoinLink({
    required this.id,
    required this.url,
    required this.meta,
    required this.copied,
    required this.onCopy,
    required this.onRevoke,
  });
  final String id, url;

  /// `8/25 uses · expires Jun 19, 20:24`.
  final String meta;
  final bool copied;
  final VoidCallback onCopy, onRevoke;
}

/// JoinLinksSection's card: the create form (Max Uses / Expires At,
/// `md:grid-cols-2`), the create error and button, then the link rows.
class RaftAdminJoinLinksCard extends StatelessWidget {
  const RaftAdminJoinLinksCard({
    super.key,
    required this.maxUses,
    required this.expiresAt,
    required this.onExpiresAt,
    required this.onCreate,
    required this.links,
    this.creating = false,
    this.loading = false,
    this.createError,
  });
  final TextEditingController maxUses;

  /// The chosen expiry (local wall time) or null.
  final DateTime? expiresAt;
  final ValueChanged<DateTime?> onExpiresAt;
  final VoidCallback onCreate;
  final List<RaftAdminJoinLink> links;
  final bool creating, loading;
  final String? createError;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), text = RaftSettingsText(t);
    final maxField = RaftSettingsField(
      label: 'Max Uses',
      child: RaftRecipeInput(
        fieldKey: const ValueKey('admin-join-link-max-uses'),
        controller: maxUses,
        placeholder: raftText(context, 'Unlimited'),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    );
    final expiresField = RaftSettingsField(
      label: 'Expires At',
      child: RaftAdminDateTimeField(value: expiresAt, onChanged: onExpiresAt),
    );
    return RaftSettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_md(context))
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: maxField),
                const SizedBox(width: 12),
                Expanded(child: expiresField),
              ],
            )
          else ...[
            maxField,
            const SizedBox(height: 12),
            expiresField,
          ],
          if (createError case final error?) ...[
            const SizedBox(height: 12),
            RaftAdminWarning(error),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: RaftSettingsRecipeButton(
              key: const ValueKey('admin-join-link-create'),
              label: creating ? 'Creating…' : 'Create Invite Link',
              glyph: RaftGlyph.plus,
              glyphSize: 14,
              variant: RaftButtonRecipeVariant.accent,
              size: RaftButtonRecipeSize.sm,
              onPressed: creating ? null : onCreate,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: text.edge, width: 2)),
            ),
            child: links.isEmpty
                ? loading
                      ? const SizedBox.shrink()
                      : _EmptyLine('No active invite links.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, link) in links.indexed) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _JoinLinkRow(link: link),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _JoinLinkRow extends StatelessWidget {
  const _JoinLinkRow({required this.link});
  final RaftAdminJoinLink link;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), text = RaftSettingsText(t);
    return Container(
      key: ValueKey('admin-join-link-${link.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: text.softEdge, width: t.brutal ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // `flex items-center gap-2`: Blink centres the 28px icon buttons
          // and the 8 + 16.5 + borders URL box in the taller one and snaps
          // each to whole pixels; Flutter would paint the half pixel.
          Builder(
            builder: (context) {
              final urlHeight = 8 + 16.5 + (t.brutal ? 4.0 : 2.0);
              final rowHeight = urlHeight > 28 ? urlHeight : 28.0;
              double snapped(double h) => ((rowHeight - h) / 2).roundToDouble();
              Widget top(double h, Widget child) => Padding(
                padding: EdgeInsets.only(top: snapped(h)),
                child: child,
              );
              return ConstrainedBox(
                // The row height is a minimum: a taller URL line (larger text,
                // Android Chinese control line) grows the row.
                constraints: BoxConstraints(minHeight: rowHeight),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: top(
                        urlHeight,
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: text.panel,
                            border: Border.all(
                              color: text.edge,
                              width: t.brutal ? 2 : 1,
                            ),
                          ),
                          child: ConstrainedBox(
                            // Blink's 16.5px line box (Flutter rounds a
                            // paragraph's line to whole pixels); a minimum, so
                            // a taller line box grows the field.
                            constraints: const BoxConstraints(minHeight: 16.5),
                            child: SelectableText(
                              link.url,
                              maxLines: 1,
                              style: RaftTypography.mono(
                                t,
                                size: 11,
                                line: 16.5,
                                color: text.strong,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    top(
                      28,
                      _IconAction(
                        key: ValueKey('admin-join-link-copy-${link.id}'),
                        tooltip: 'Copy invite link',
                        glyph: link.copied ? RaftGlyph.check : RaftGlyph.copy,
                        size: 14,
                        onPressed: link.onCopy,
                      ),
                    ),
                    const SizedBox(width: 8),
                    top(
                      28,
                      _IconAction(
                        key: ValueKey('admin-join-link-revoke-${link.id}'),
                        tooltip: 'Revoke invite link',
                        glyph: RaftGlyph.x,
                        size: 14,
                        onPressed: link.onRevoke,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          RaftCssText(
            link.meta,
            style: RaftTypography.mono(
              t,
              size: 11,
              line: 16.5,
              color: text.faint,
            ),
          ),
        ],
      ),
    );
  }
}

/// `<Input type="datetime-local">`: the value (or Chromium's
/// `mm/dd/yyyy, --:-- --` mask) with the calendar indicator; activating it
/// picks a date, then a time.
class RaftAdminDateTimeField extends StatelessWidget {
  const RaftAdminDateTimeField({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// Chromium's en-US datetime-local rendering.
  static String format(DateTime? v) {
    if (v == null) return 'mm/dd/yyyy, --:-- --';
    final hour = v.hour % 12 == 0 ? 12 : v.hour % 12;
    return '${_two(v.month)}/${_two(v.day)}/${v.year}, '
        '${_two(hour)}:${_two(v.minute)} ${v.hour < 12 ? 'AM' : 'PM'}';
  }

  Future<void> pick(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value ?? now),
    );
    if (time == null) return;
    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), tokens = t.recipeTokens;
    return RaftInteractive(
      key: const ValueKey('admin-join-link-expires-at'),
      onPressed: () => pick(context),
      semanticLabel: raftText(context, 'Expires At'),
      builder: (context, state) {
        final s = RaftInputRecipe.resolve(
          theme: t.recipeTheme,
          states: t.recipeStates(focusVisible: state.focusVisible),
          tokens: tokens,
        ).root;
        final style = s
            .text(tokens, base: DefaultTextStyle.of(context).style)
            .copyWith(fontSize: 14, height: 20 / 14);
        return Container(
          decoration: s.decoration(tokens),
          padding: s.padding,
          child: Row(
            children: [
              Expanded(
                child: RaftCssText(
                  format(value),
                  maxLines: 1,
                  softWrap: false,
                  style: style,
                ),
              ),
              RaftIcon(RaftGlyph.calendar, size: 14, color: style.color),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- agreement

/// AgreementBody.tsx: blank-line paragraphs (lines joined by `<br>`),
/// `-`/`*` bullet and `1.`/`1)` numbered lists; `space-y-2`, lists
/// `space-y-1 pl-5`.
class RaftAgreementBody extends StatelessWidget {
  const RaftAgreementBody({super.key, required this.source, this.style});
  final String source;
  final TextStyle? style;

  static final _unordered = RegExp(r'^\s*[-*]\s+(.+)$');
  static final _ordered = RegExp(r'^\s*\d+[.)]\s+(.+)$');

  /// `(kind, lines)` blocks; kind is `p`, `ul` or `ol`.
  static List<(String, List<String>)> parse(String source) {
    final blocks = <(String, List<String>)>[];
    final paragraph = <String>[];
    (String, List<String>)? list;
    void pushParagraph() {
      if (paragraph.isNotEmpty) {
        blocks.add(('p', [...paragraph]));
        paragraph.clear();
      }
    }

    void flushList() {
      if (list != null && list!.$2.isNotEmpty) blocks.add(list!);
      list = null;
    }

    for (final raw in source.replaceAll(RegExp(r'\r\n?'), '\n').split('\n')) {
      final line = raw.trimRight();
      final unordered = _unordered.firstMatch(line);
      final ordered = _ordered.firstMatch(line);
      if (line.trim().isEmpty) {
        pushParagraph();
        flushList();
        continue;
      }
      if (unordered != null || ordered != null) {
        pushParagraph();
        final kind = unordered != null ? 'ul' : 'ol';
        final item = (unordered ?? ordered)!.group(1)!.trim();
        if (list == null || list!.$1 != kind) {
          flushList();
          list = (kind, <String>[]);
        }
        list!.$2.add(item);
        continue;
      }
      flushList();
      paragraph.add(line.trim());
    }
    pushParagraph();
    flushList();
    return blocks;
  }

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final blocks = parse(source);
    if (blocks.isEmpty) {
      return RaftCssText(
        raftText(context, 'Nothing to preview yet.'),
        style: base.copyWith(color: Colors.black.withValues(alpha: .5)),
      );
    }
    Widget item(String marker, String value) => Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -20,
            width: 20,
            child: RaftCssText(marker, textAlign: TextAlign.right, style: base),
          ),
          RaftCssText(value, style: base),
        ],
      ),
    );
    return DefaultTextStyle.merge(
      style: base,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, (kind, lines)) in blocks.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            if (kind == 'p')
              RaftCssText(lines.join('\n'), style: base)
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (j, line) in lines.indexed) ...[
                    if (j > 0) const SizedBox(height: 4),
                    item(kind == 'ul' ? '•  ' : '${j + 1}. ', line),
                  ],
                ],
              ),
          ],
        ],
      ),
    );
  }
}

/// PreJoinAgreementSection's card.
class RaftAdminAgreementCard extends StatelessWidget {
  const RaftAdminAgreementCard({
    super.key,
    required this.enabled,
    required this.onEnabled,
    required this.title,
    required this.body,
    required this.save,
    required this.onSave,
    this.busy = false,
    this.error,
    this.maxLength = 5000,
  });
  final bool enabled;
  final ValueChanged<bool> onEnabled;
  final TextEditingController title, body;
  final RaftAdminSaveState save;

  /// Null disables Save (clean, too long, saving or loading).
  final VoidCallback? onSave;

  /// Saving or loading: the controls are disabled and dimmed.
  final bool busy;
  final String? error;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), text = RaftSettingsText(t);
    final tooLong = body.text.length > maxLength;
    return RaftSettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftAdminCheckboxRow(
            checkboxKey: const ValueKey('admin-agreement-enabled'),
            title: 'Require agreement before joining',
            description: 'New invite-link and community joins must accept the current version before membership is created.',
            checked: enabled,
            dimmed: busy,
            onChanged: busy ? null : onEnabled,
          ),
          if (enabled) ...[
            const SizedBox(height: 16),
            RaftSettingsField(
              label: 'Title',
              child: RaftRecipeInput(
                fieldKey: const ValueKey('admin-agreement-title'),
                controller: title,
                maxLength: 160,
                enabled: !busy,
              ),
            ),
            const SizedBox(height: 16),
            RaftSettingsField(
              label: 'Body',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Opacity(
                    opacity: busy ? .6 : 1,
                    child: RaftTextarea(
                      fieldKey: const ValueKey('admin-agreement-body'),
                      controller: body,
                      rows: 7,
                      maxLength: maxLength,
                      enabled: !busy,
                      invalid: tooLong,
                      // `font-mono text-xs`: the recipe keeps the field's ink colour.
                      textStyle: TextStyle(
                        fontFamily: t.monoFont,
                        fontSize: 12,
                        height: 16 / 12,
                      ),
                    ),
                  ),
                  // `mt-1` plus the inline-block textarea's baseline gap
                  // (the 20px strut's descent) under it.
                  // ds-allow: Web SettingsPanel.tsx agreement textarea `mt-1` plus inline-block baseline gap (computed, no class)
                  SizedBox(height: t.brutal ? 7 : 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: tooLong
                            ? Semantics(
                                liveRegion: true,
                                child: RaftCssText(
                                  raftFormat(
                                    context,
                                    'Agreement body must be {max} characters or fewer',
                                    {'max': '5,000'},
                                  ),
                                  style: raftSettingsBody(
                                    t,
                                    size: 12,
                                    line: 16,
                                    color: t.brutal
                                        ? t.colors['color-brutal-red']
                                        : t.colors['danger'],
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 12),
                      RaftTextareaCounter(
                        length: body.text.length,
                        limit: maxLength,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.brutal
                    ? t.colors['color-brutal-cream']
                    : t.colors['layer-canvas-muted'],
                border: Border.all(
                  color: text.softEdge,
                  width: t.brutal ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RaftCssText(
                    raftText(context, 'Preview').toUpperCase(),
                    style: raftSettingsBody(
                      t,
                      size: 11,
                      line: 16.5,
                      weight: FontWeight.w700,
                      color: text.faint,
                    ).copyWith(letterSpacing: 1.1),
                  ),
                  const SizedBox(height: 8),
                  RaftAgreementBody(
                    source: body.text,
                    style: raftSettingsBody(
                      t,
                      size: 14,
                      line: 20,
                      color: text.strong,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (error case final error?) ...[
            const SizedBox(height: 16),
            RaftAdminWarning(error),
          ],
          const SizedBox(height: 16),
          RaftCssText(
            raftText(
              context,
              'Saving creates a new version; previous accepted versions remain auditable.',
            ),
            style: raftSettingsBody(t, size: 11, line: 16.5, color: text.faint),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: RaftAdminSaveButton(
              key: const ValueKey('admin-agreement-save'),
              state: save,
              savedCheck: false,
              onPressed: onSave,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- onboarding

/// OnboardingAgentSection's card: the onboarding-agent and greeting selects,
/// Save and (when the server's setup projection asks for it) Finish setup.
class RaftAdminOnboardingCard extends StatelessWidget {
  const RaftAdminOnboardingCard({
    super.key,
    required this.agentId,
    required this.agents,
    required this.onAgent,
    required this.greeting,
    required this.onGreeting,
    required this.save,
    required this.onSave,
    this.disabled = false,
    this.error,
    this.showSetup = false,
    this.openingSetup = false,
    this.onFinishSetup,
  });

  /// '' = disabled; otherwise an agent id.
  final String agentId;

  /// `(id, '@name (displayName)')`.
  final List<(String, String)> agents;
  final ValueChanged<String> onAgent;
  final bool greeting;
  final ValueChanged<bool> onGreeting;
  final RaftAdminSaveState save;
  final VoidCallback? onSave;

  /// Saving or loading.
  final bool disabled;
  final String? error;
  final bool showSetup, openingSetup;
  final VoidCallback? onFinishSetup;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), text = RaftSettingsText(t);
    final wide = _sm(context);
    Widget row(String title, String description, double width, Widget field) {
      final copy = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RaftCssText(raftText(context, title), style: text.title),
          const SizedBox(height: 2),
          RaftCssText(raftText(context, description), style: text.description),
        ],
      );
      if (!wide) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [copy, const SizedBox(height: 8), field],
        );
      }
      return Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: copy,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: width, child: field),
        ],
      );
    }

    return RaftSettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(
            'Human Onboarding Agent',
            'Select one agent for member onboarding flows, or disable automatic onboarding.',
            320,
            RaftSelectField<String>(
              key: const ValueKey('admin-onboarding-agent'),
              label: raftText(context, 'Onboarding agent'),
              placeholder: 'Onboarding agent',
              value: agentId,
              items: [
                DropdownMenuItem(
                  value: '',
                  child: RaftCssText(
                    raftText(context, 'Disabled (no automatic onboarding)'),
                  ),
                ),
                for (final (id, label) in agents)
                  DropdownMenuItem(value: id, child: RaftCssText(label)),
              ],
              onChanged: disabled
                  ? null
                  : (value) {
                      if (value != null) onAgent(value);
                    },
            ),
          ),
          const SizedBox(height: 16),
          row(
            'New Agent Greeting',
            'When enabled, a newly started agent posts a short self-introduction in #all. Existing agents are not affected.',
            112,
            RaftSelectField<String>(
              key: const ValueKey('admin-onboarding-greeting'),
              label: raftText(context, 'Greeting'),
              placeholder: 'Greeting',
              value: greeting ? 'yes' : 'no',
              items: [
                DropdownMenuItem(
                  value: 'yes',
                  child: RaftCssText(raftText(context, 'Yes')),
                ),
                DropdownMenuItem(
                  value: 'no',
                  child: RaftCssText(raftText(context, 'No')),
                ),
              ],
              onChanged: disabled
                  ? null
                  : (value) {
                      if (value != null) onGreeting(value == 'yes');
                    },
            ),
          ),
          if (error case final error?) ...[
            const SizedBox(height: 8),
            RaftAdminWarning(error),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: RaftAdminSaveButton(
              key: const ValueKey('admin-onboarding-save'),
              state: save,
              savedCheck: false,
              onPressed: onSave,
            ),
          ),
          if (showSetup) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: text.edge, width: 2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RaftCssText(
                          raftText(context, 'Server setup'),
                          style: raftSettingsBody(
                            t,
                            size: 12,
                            line: 16,
                            weight: FontWeight.w700,
                            color: text.strong,
                          ),
                        ),
                        RaftCssText(
                          raftText(
                            context,
                            'Continue the guided Computer and onboarding agent setup.',
                          ),
                          style: raftSettingsBody(
                            t,
                            size: 11,
                            line: 16.5,
                            color: text.faint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  RaftSettingsRecipeButton(
                    key: const ValueKey('finish-server-setup'),
                    label: openingSetup ? 'Opening…' : 'Finish setup',
                    trailingGlyph: openingSetup ? null : RaftGlyph.chevronRight,
                    glyphSize: 14,
                    size: RaftButtonRecipeSize.sm,
                    onPressed: openingSetup ? null : onFinishSetup,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- analytics

/// UsageDataSettings.tsx SwitchRow on the workspace Product analytics card:
/// title + `text-xs leading-5` description beside a `Switch size="md"`
/// (`mt-0.5`), the failure banner below (`mt-3`).
class RaftAdminSwitchCard extends StatelessWidget {
  const RaftAdminSwitchCard({
    super.key,
    required this.title,
    required this.description,
    required this.checked,
    this.onChanged,
    this.error,
    this.switchKey,
    this.descriptionLink,
    this.onDescriptionLink,
    this.topGap = 0,
    this.cardKey,
  });

  /// Key of the card box itself (excluding [topGap]).
  final Key? cardKey;

  /// Space above the card (`mt-6` of UsageDataSettingsCard).
  final double topGap;
  final String title, description;
  final bool checked;
  final ValueChanged<bool>? onChanged;
  final String? error;
  final Key? switchKey;

  /// Trailing `<a class="font-bold underline underline-offset-2">` after the
  /// description (UsageDataSettingsCard's "Learn more").
  final String? descriptionLink;
  final VoidCallback? onDescriptionLink;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), text = RaftSettingsText(t);
    return Padding(
      padding: EdgeInsets.only(top: topGap),
      child: RaftSettingsCard(
        key: cardKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RaftCssText(
                        raftText(context, title),
                        style: text.title.copyWith(color: t.strong),
                      ),
                      const SizedBox(height: 2),
                      Builder(
                        builder: (context) {
                          final body = raftSettingsBody(
                            t,
                            size: 12,
                            line: 20,
                            color: t.muted,
                          );
                          final link = descriptionLink;
                          if (link == null) {
                            return RaftCssText(
                              raftText(context, description),
                              style: body,
                            );
                          }
                          return RaftCssText.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${raftText(context, description)} ',
                                ),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: onDescriptionLink,
                                    child: RaftUnderlinedText(
                                      raftText(context, link),
                                      style: body.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            style: body,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: RaftSwitch(
                    key: switchKey,
                    value: checked,
                    size: RaftSwitchSize.md,
                    // Web: the 44x24 Switch is the whole target (no touch
                    // padding), so the card layout matches at phone width.
                    minimumTargetSize: 0,
                    enabled: onChanged != null,
                    semanticLabel: raftText(context, title),
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
            if (error case final error?) ...[
              const SizedBox(height: 12),
              RaftAdminWarning(error),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- public

/// One channel in the public exposure inventory.
class RaftPublicChannel {
  const RaftPublicChannel({required this.name, this.description});
  final String name;
  final String? description;
}

/// SettingsPanel.tsx PublicChannelList: a bordered `divide-y` list of
/// `h-[3.625rem]` rows (Hash tile, name, description) capped at two rows
/// (`max-h-[7.5rem]`, scrolls inside), or the dashed empty box.
class RaftPublicChannelList extends StatelessWidget {
  const RaftPublicChannelList({super.key, required this.channels});
  final List<RaftPublicChannel> channels;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), text = RaftSettingsText(t);
    final radius = BorderRadius.circular(t.brutal ? 0 : 6);
    if (channels.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: t.brutal
              ? const Color(0xFFF9FAFB)
              : t.colors['fill-muted']!.withValues(
                  alpha: t.colors['fill-muted']!.a * .4,
                ),
          borderRadius: radius,
          border: Border.all(
            color: t.brutal
                ? Colors.black.withValues(alpha: .25)
                : t.colors['line-muted']!,
            width: t.brutal ? 2 : 1,
          ),
        ),
        child: RaftCssText(
          raftText(
            context,
            'No channels are currently marked visible to Guests.',
          ),
          textAlign: TextAlign.center,
          style: raftSettingsBody(
            t,
            size: 12,
            line: 16,
            color: t.brutal ? Colors.black.withValues(alpha: .55) : t.muted,
          ),
        ),
      );
    }
    final hairline = t.colors['line-hairline'] ?? t.colors['line-muted']!;
    return Container(
      constraints: const BoxConstraints(maxHeight: 120),
      decoration: BoxDecoration(
        color: text.panel,
        borderRadius: radius,
        border: Border.all(color: text.edge, width: t.brutal ? 2 : 1),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, channel) in channels.indexed)
              Container(
                height: 58,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: i == 0
                    ? null
                    : BoxDecoration(
                        border: Border(top: BorderSide(color: hairline)),
                      ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.brutal
                            ? t.colors['color-brutal-cream']
                            : t.colors['layer-inset'],
                        borderRadius: radius,
                        border: Border.all(
                          color: t.brutal
                              ? Colors.black
                              : t.colors['line-muted']!,
                        ),
                      ),
                      child: RaftIcon(
                        RaftGlyph.hash,
                        size: 14,
                        strokeWidth: 2.5,
                        color: text.strong,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RaftCssText(
                            channel.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.title.copyWith(color: t.strong),
                          ),
                          if (channel.description case final d?
                              when d.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            RaftCssText(
                              d,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: raftSettingsBody(
                                t,
                                size: 12,
                                line: 16,
                                color: t.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// SettingsPanel.tsx PublicVisibilitySection's card (Server Profile tab,
/// owner only behind `public_server_v0`): the public switch, the public page
/// URL with Copy, the Guest-join switch (`server_guest_v0`), the exposed
/// channel list and the error banner.
class RaftPublicVisibilityCard extends StatelessWidget {
  const RaftPublicVisibilityCard({
    super.key,
    required this.publiclyVisible,
    required this.onPublic,
    required this.channels,
    this.publicUrl,
    this.copied = false,
    this.onCopy,
    this.guestJoin,
    this.onGuestJoin,
    this.loading = false,
    this.error,
  });
  final bool publiclyVisible;

  /// Null disables the switch (loading, saving or no readback).
  final ValueChanged<bool>? onPublic;
  final List<RaftPublicChannel> channels;
  final String? publicUrl;
  final bool copied;
  final VoidCallback? onCopy;

  /// Null hides the Guest-join row (`server_guest_v0` off).
  final bool? guestJoin;
  final ValueChanged<bool>? onGuestJoin;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final eyebrow = raftSettingsBody(
      t,
      size: 12,
      line: 16,
      weight: FontWeight.w700,
      color: t.muted,
    ).copyWith(letterSpacing: .3);
    Widget switchRow(
      String title,
      String description,
      bool value,
      ValueChanged<bool>? onChanged,
      Key key,
    ) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RaftCssText(
                raftText(context, title),
                style: RaftSettingsText(t).title.copyWith(color: t.strong),
              ),
              const SizedBox(height: 4),
              RaftCssText(
                raftText(context, description),
                style: raftSettingsBody(
                  t,
                  size: 12,
                  line: 12 * 1.625,
                  color: t.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        RaftSwitch(
          key: key,
          value: value,
          size: RaftSwitchSize.md,
          enabled: onChanged != null,
          semanticLabel: raftText(context, title),
          onChanged: onChanged,
        ),
      ],
    );
    return RaftSettingsCard.box(
      t,
      padding: const EdgeInsets.all(16),
      radius: t.brutal ? null : BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          switchRow(
            'Make this server public',
            'Anyone can read the channels listed below, without signing in or being invited.',
            publiclyVisible,
            onPublic,
            const ValueKey('public-visibility-switch'),
          ),
          if (publicUrl case final url?) ...[
            const SizedBox(height: 16),
            RaftCssText(
              raftText(context, 'Public page').toUpperCase(),
              style: eyebrow,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: RaftSettingsReadonlyValue(value: url)),
                const SizedBox(width: 8),
                RaftSettingsRecipeButton(
                  key: const ValueKey('public-visibility-copy-url'),
                  label: copied ? 'Copied' : 'Copy',
                  glyph: copied ? RaftGlyph.check : RaftGlyph.copy,
                  glyphSize: 15,
                  size: RaftButtonRecipeSize.lg,
                  onPressed: onCopy,
                ),
              ],
            ),
          ],
          if (guestJoin case final guest?) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: t.colors['line-hairline'] ?? t.colors['line-muted']!,
                  ),
                ),
              ),
              child: switchRow(
                'Allow visitors to join as Guest',
                'Signed-in visitors can choose to join. Public reading never adds membership automatically.',
                guest,
                onGuestJoin,
                const ValueKey('public-guest-join-switch'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          RaftCssText(
            raftText(context, 'Channels visible to anyone').toUpperCase(),
            style: eyebrow,
          ),
          const SizedBox(height: 8),
          if (loading)
            const RaftUiSkeleton(height: 64)
          else
            RaftPublicChannelList(channels: channels),
          if (error case final error?) ...[
            const SizedBox(height: 16),
            RaftAdminWarning(error),
          ],
        ],
      ),
    );
  }
}

/// The "Make this server public?" confirmation body: the lead line, the
/// exposed channel list and the audience note (`space-y-4`).
class RaftPublicVisibilityConfirmBody extends StatelessWidget {
  const RaftPublicVisibilityConfirmBody({super.key, required this.channels});
  final List<RaftPublicChannel> channels;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftCssText(
          raftText(context, 'These channels will become readable by anyone:'),
          style: RaftConfirmDialog.messageStyle(t).copyWith(color: t.strong),
        ),
        const SizedBox(height: 16),
        RaftPublicChannelList(channels: channels),
        const SizedBox(height: 16),
        RaftCssText(
          raftText(
            context,
            'You marked these channels visible to Guests earlier. That choice will now apply to everyone, not only the Guests you invited. You will not be asked again for each channel.',
          ),
          style: raftSettingsBody(
            t,
            size: 12,
            line: 12 * 1.625,
            color: t.muted,
          ),
        ),
      ],
    );
  }
}
