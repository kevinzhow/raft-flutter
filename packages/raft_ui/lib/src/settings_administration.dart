// Settings > Workspace > Administration (SettingsPanel.tsx
// AdministrationTabContent at raft-source 26f77ef), section by section:
//   AdminsSection, SystemChannelsSection, InvitesSection, JoinLinksSection,
//   PreJoinAgreementSection, OnboardingAgentSection, ServerTranslationSection,
//   WorkspaceProductAnalyticsSection (UsageDataSettings.tsx SwitchRow) and
//   MemberPermissionsSection.
// Presentation only: the app owns data, permission gates and requests and
// passes values plus callbacks; every class list is resolved here.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../raft_ui.dart';
import 'recipes/input.g.dart' show RaftInputRecipe;

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
    size: RaftButtonRecipeSize.md,
    onPressed: onPressed,
  );
}

/// `label.flex.items-start.gap-3`: a `Checkbox size="md"` (`mt-0.5`) and the
/// `text-sm font-bold` title over the `mt-0.5 text-xs` description.
class RaftAdminCheckboxRow extends StatelessWidget {
  const RaftAdminCheckboxRow({
    super.key,
    required this.title,
    this.description,
    required this.checked,
    this.onChanged,
    this.dimmed = false,
    this.checkboxKey,
  });
  final String title;

  /// Null: the title alone (v1.24 PreJoinAgreementSection dropped its line).
  final String? description;
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
          padding: EdgeInsets.only(top: description == null ? 0 : 2),
          child: RaftCheckbox(
            key: checkboxKey,
            value: checked,
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
                if (description case final description?) ...[
                  const SizedBox(height: 2),
                  RaftCssText(
                    raftText(context, description),
                    style: text.description,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
    return dimmed ? Opacity(opacity: .6, child: row) : row;
  }
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
    this.searchText,
  });

  /// What the picker's search also matches besides the label (Web: a human's
  /// `email name`, an agent's `@name`).
  final String? searchText;

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

/// AdminsSection's group (Web v1.24): the add-owner/admin fields are the first
/// row (side by side from 32rem of the group's own width), then a row per
/// owner and admin; the error banner sits under the whole group.
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
    this.note,
  });

  /// Under the add row's fields (the owner hand-over's
  /// [RaftOwnComputersTransferNote]).
  final Widget? note;
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
    final selected = candidates.where((c) => c.key == selectedKey).firstOrNull;
    final canPromote = selected != null && roleOptions.isNotEmpty && !saving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // `@lg`: 32rem of the group's own width, and not under scaled text
            // (the fields no longer fit one row).
            final wide =
                constraints.maxWidth >= raftSettingsRowNarrowWidth &&
                !RaftScaled.grows(context);
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
                  RaftSelectItem(
                    value: value,
                    enabled: roleOptions.contains(value),
                    label: raftText(context, label),
                    cssText: true,
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
              label: promoting ? 'Saving…' : 'Update role',
              variant: RaftButtonRecipeVariant.accent,
              size: RaftButtonRecipeSize.lg,
              expand: !wide,
              onPressed: canPromote ? onPromote : null,
            );
            final first = RaftListRow(
              variant: RaftListRowVariant.plain,
              interactive: false,
              children: [
                RaftListRowBody(
                  children: [
                    const RaftListRowTitle('Add owner/admin'),
                    Padding(
                      padding: const EdgeInsets.only(top: RaftSpace.x2),
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: picker),
                                const SizedBox(width: RaftSpace.x2),
                                SizedBox(width: 120, child: roleSelect),
                                const SizedBox(width: RaftSpace.x2),
                                promote,
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                picker,
                                const SizedBox(height: RaftSpace.x2),
                                roleSelect,
                                const SizedBox(height: RaftSpace.x2),
                                promote,
                              ],
                            ),
                    ),
                    ?note,
                  ],
                ),
              ],
            );
            return RaftListRowGroup(
              children: [
                first,
                if (rows.isEmpty)
                  const RaftListRow(
                    variant: RaftListRowVariant.plain,
                    interactive: false,
                    children: [
                      RaftListRowBody(
                        children: [
                          RaftListRowDescription(
                            'No owners or admins yet',
                            wrap: true,
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  for (final row in rows)
                    _AdminListRow(row: row, saving: saving),
              ],
            );
          },
        ),
        // Adding and removing share this line, so it is under the whole group.
        if (error case final error?) ...[
          const SizedBox(height: RaftSpace.x3),
          RaftErrorBanner(error, small: true),
        ],
      ],
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
            size: RaftButtonRecipeSize.md,
            onPressed: saving ? null : row.onRemove,
          )
        else
          RaftCssText(
            raftText(context, row.note ?? ''),
            style: t.scale(RaftTypeScale.footnote, color: t.muted),
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
          color: hover ? t.colors['primary-soft'] : null,
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
                    color: selected != null ? text.strong : t.muted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: open ? .25 : 0,
                duration: raftMotionDuration(
                  context,
                  const Duration(milliseconds: 150),
                ),
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
                    '${c.label} ${c.searchText ?? c.optionLabel ?? ''}'
                        .toLowerCase()
                        .contains(needle))
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
                      emptyLabel: raftText(
                        context,
                        'No members match your search',
                      ),
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

/// InvitesSection's group (Web v1.24): a row per pending invite (the address,
/// when it was sent, Revoke), or the empty line once loaded.
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
    if (invites.isEmpty && loading) return const SizedBox.shrink();
    return RaftListRowGroup(
      children: [
        if (invites.isEmpty)
          const _EmptyRow('No pending invites')
        else
          for (final invite in invites)
            RaftListRow(
              key: ValueKey('admin-invite-${invite.id}'),
              variant: RaftListRowVariant.plain,
              interactive: false,
              children: [
                RaftListRowBody(children: [RaftListRowTitle(invite.email)]),
                RaftListRowMeta(invite.date),
                _IconAction(
                  key: ValueKey('admin-invite-revoke-${invite.id}'),
                  tooltip: 'Revoke invite',
                  glyph: RaftGlyph.x,
                  size: 14,
                  onPressed: invite.onRevoke,
                ),
              ],
            ),
      ],
    );
  }
}

/// `Button variant="outline" size="icon-md"` inside a Tooltip.
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
        size: RaftButtonRecipeSize.iconMd,
        onPressed: onPressed,
      ),
    ),
  );
}

/// A row with only a description (`ListRowDescription wrap`): the empty state.
class _EmptyRow extends StatelessWidget {
  const _EmptyRow(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => RaftListRow(
    variant: RaftListRowVariant.plain,
    interactive: false,
    children: [
      RaftListRowBody(children: [RaftListRowDescription(message, wrap: true)]),
    ],
  );
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

/// JoinLinksSection's group (Web v1.24): the create form (Max uses / Expires
/// at side by side from 32rem of the group's own width, the create error and
/// button) is the first row, then a row per active link.
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
    final maxField = RaftSettingsField(
      label: 'Max uses',
      child: RaftRecipeInput(
        fieldKey: const ValueKey('admin-join-link-max-uses'),
        controller: maxUses,
        placeholder: raftText(context, 'Unlimited'),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    );
    final expiresField = RaftSettingsField(
      label: 'Expires at',
      child: RaftAdminDateTimeField(value: expiresAt, onChanged: onExpiresAt),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= raftSettingsRowNarrowWidth;
        return RaftListRowGroup(
          children: [
            RaftListRow(
              variant: RaftListRowVariant.plain,
              interactive: false,
              children: [
                RaftListRowBody(
                  children: [
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: maxField),
                          const SizedBox(width: RaftSpace.x3),
                          Expanded(child: expiresField),
                        ],
                      )
                    else ...[
                      maxField,
                      const SizedBox(height: RaftSpace.x3),
                      expiresField,
                    ],
                    if (createError case final error?) ...[
                      const SizedBox(height: RaftSpace.x3),
                      RaftErrorBanner(error, small: true),
                    ],
                    const SizedBox(height: RaftSpace.x3),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: RaftSettingsRecipeButton(
                        key: const ValueKey('admin-join-link-create'),
                        label: creating ? 'Creating…' : 'Create invite link',
                        glyph: RaftGlyph.plus,
                        glyphSize: 14,
                        size: RaftButtonRecipeSize.md,
                        onPressed: creating ? null : onCreate,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (links.isEmpty)
              if (!loading)
                const _EmptyRow('No active invite links')
              else
                const SizedBox.shrink()
            else
              for (final link in links) _JoinLinkRow(link: link),
          ],
        );
      },
    );
  }
}

/// JoinLinkRow (Web v1.24): the link and its uses and expiry under it, Copy and
/// Revoke at the row's end.
class _JoinLinkRow extends StatelessWidget {
  const _JoinLinkRow({required this.link});
  final RaftAdminJoinLink link;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), text = RaftSettingsText(t);
    return RaftListRow(
      key: ValueKey('admin-join-link-${link.id}'),
      variant: RaftListRowVariant.plain,
      interactive: false,
      children: [
        RaftListRowBody(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: t.colors['fill-muted'] ?? text.panel,
                borderRadius: BorderRadius.circular(
                  t.size('radius.control', fallback: RaftRadius.control),
                ),
              ),
              child: SelectableText(
                link.url,
                maxLines: 1,
                style: RaftTypography.mono(
                  t,
                  size: 12,
                  line: 18,
                  color: text.strong,
                ),
              ),
            ),
            RaftListRowMeta(link.meta),
          ],
        ),
        _IconAction(
          key: ValueKey('admin-join-link-copy-${link.id}'),
          tooltip: 'Copy invite link',
          glyph: link.copied ? RaftGlyph.check : RaftGlyph.copy,
          size: 14,
          onPressed: link.onCopy,
        ),
        _IconAction(
          key: ValueKey('admin-join-link-revoke-${link.id}'),
          tooltip: 'Revoke invite link',
          glyph: RaftGlyph.x,
          size: 14,
          onPressed: link.onRevoke,
        ),
      ],
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
      semanticLabel: raftText(context, 'Expires at'),
      builder: (context, state) {
        final s = RaftInputRecipe.resolve(
          states: t.recipeStates(focusVisible: state.focusVisible),
          tokens: tokens,
        ).root;
        final style = s
            .text(tokens, base: DefaultTextStyle.of(context).style)
            .copyWith(fontSize: 14, height: 20 / 14);
        final grows = s.height != null && RaftScaled.grows(context);
        final minHeight = grows
            ? math.max(s.minHeight ?? 0, s.height!)
            : s.minHeight;
        return Container(
          height: grows ? null : s.height,
          constraints: minHeight == null
              ? null
              : BoxConstraints(minHeight: minHeight),
          decoration: s.decoration(tokens),
          padding: s.padding,
          alignment: s.height == null ? null : Alignment.centerLeft,
          child: Row(
            children: [
              Expanded(
                child: RaftCssText(
                  format(value),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
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
        raftText(context, 'Nothing to preview yet'),
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
                  SizedBox(height: 10),
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
                                    color: t.colors['danger'],
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
                color: t.colors['layer-canvas-muted'],
                border: Border.all(color: text.softEdge, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RaftCssText(
                    raftText(context, 'Preview'),
                    style: raftSettingsBody(
                      t,
                      size: 11,
                      line: 16.5,
                      weight: FontWeight.w700,
                      color: text.faint,
                    ),
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
    final radius = BorderRadius.circular(6);
    if (channels.isEmpty) {
      // `border border-dashed border-line-hairline`, no fill, hint text.
      return CustomPaint(
        foregroundPainter: RaftDashedBorderPainter(
          t.colors['line-hairline'] ?? t.colors['line-muted']!,
          1,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: SizedBox(
            width: double.infinity,
            child: Center(
              child: RaftCssText(
                raftText(context, 'No channels visible to visitors yet'),
                textAlign: TextAlign.center,
                style: raftSettingsBody(
                  t,
                  size: 12,
                  line: 16,
                  color: t.colors['foreground-hint'],
                ),
              ),
            ),
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
        border: Border.all(color: text.edge, width: 1),
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
                        color: t.colors['layer-inset'],
                        borderRadius: radius,
                        border: Border.all(color: t.colors['line-muted']!),
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
/// URL with Copy, the exposed
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
    this.searchEngines = false,
    this.onSearchEngines,
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

  /// Allow search engines to list the public channels
  /// (`publicSearchEnabled`); only meaningful while the server is public.
  /// A null [onSearchEngines] disables the switch.
  final bool searchEngines;
  final ValueChanged<bool>? onSearchEngines;
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
    );
    Widget switchRow(
      String title,
      String description,
      bool value,
      ValueChanged<bool>? onChanged,
      Key key,
    ) => Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // `text-subhead font-semibold text-foreground`.
              RaftCssText(
                raftText(context, title),
                style: RaftSettingsText(t, semanticTypography: true).title,
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
    final hairline = t.colors['line-hairline'] ?? t.colors['line-muted']!;
    Widget secondLevel(Key key, Widget child) => Padding(
      key: key,
      padding: const EdgeInsets.only(left: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: hairline)),
        ),
        child: Padding(padding: const EdgeInsets.only(left: 16), child: child),
      ),
    );
    return RaftSettingsCard.box(
      t,
      padding: const EdgeInsets.all(16),
      radius: BorderRadius.circular(8),
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
            RaftCssText(raftText(context, 'Public page'), style: eyebrow),
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
          // Public server SEO: also second level. It never makes anything
          // readable; it only decides whether public content may be indexed.
          const SizedBox(height: 16),
          secondLevel(
            const ValueKey('public-search-setting'),
            switchRow(
              'Allow search engines',
              'Search engines can show the channels visible to anyone, and their threads, in search results. Turning it off stops this, though results already listed can take a while to drop out. The channels stay public.',
              publiclyVisible && searchEngines,
              onSearchEngines,
              const ValueKey('public-search-switch'),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            key: const ValueKey('public-visibility-channels'),
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: hairline)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // `mb-2 text-subhead font-semibold text-foreground`.
                RaftCssText(
                  raftText(context, 'Channels visible to anyone'),
                  style: RaftSettingsText(t, semanticTypography: true).title,
                ),
                const SizedBox(height: 8),
                if (loading)
                  RaftSkeleton(
                    fromRecipe: true,
                    width: double.infinity,
                    height: 64,
                  )
                else
                  RaftPublicChannelList(channels: channels),
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
