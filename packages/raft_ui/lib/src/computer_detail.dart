// The desktop Computer detail page: a port of Web
// packages/web/src/components/machine/MachineDetailPanel.tsx (raft-source
// 26f77ef). Every section keeps the Web structure, copy and Tailwind
// geometry (cited per block) so the parity extension suite
// (tool/parity-ext, components.computers.*) can compare it section by
// section. Keys `computer-section-<name>` mark the compared regions.
//
// The view owns only UI state (editing, selection, disclosure, progress);
// the app supplies [RaftComputerDetailData] and performs every request
// through [RaftComputerDetailActions].
import 'dart:async';

import 'package:flutter/material.dart';

import '../raft_ui.dart';

// ------------------------------------------------------------------- data

/// utils/computerVersionFact.ts kinds.
enum RaftComputerVersionKind { unknown, cannotCheck, current, outdated }

/// The Computer service card's one status sentence + next step.
enum RaftComputerServiceKind {
  reading,
  cannotCheck,
  upToDate,
  upgrading,
  oneClick,
  commands,
}

/// MachineAgentList bulk modes.
enum RaftComputerBulk { start, stop, restart, session, full }

class RaftComputerService {
  const RaftComputerService({
    required this.kind,
    required this.sentence,
    this.version,
    this.webUpgradeOn = false,
  });
  final RaftComputerServiceKind kind;
  final String sentence;
  final String? version;
  final bool webUpgradeOn;
}

class RaftComputerAgent {
  const RaftComputerAgent({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.activity,
    required this.activityText,
    this.avatarUrl,
  });
  final String id, name, subtitle, activity, activityText;
  final String? avatarUrl;
  bool get online => activity != 'offline';
}

class RaftComputerCreator {
  const RaftComputerCreator({
    required this.name,
    required this.handle,
    this.avatarUrl,
  });
  final String name, handle;
  final String? avatarUrl;
}

/// getComputerCommands: the bundle the page shows.
class RaftComputerCommandSet {
  const RaftComputerCommandSet({
    required this.install,
    required this.setup,
    required this.status,
    required this.doctor,
    required this.restart,
    required this.restartService,
  });
  final String install, setup, status, doctor, restart, restartService;
}

class RaftComputerWorkspace {
  const RaftComputerWorkspace({
    required this.directoryName,
    required this.label,
    required this.status,
    required this.sizeLabel,
    required this.filesLabel,
    this.modifiedLabel,
  });
  final String directoryName, label, status, sizeLabel, filesLabel;
  final String? modifiedLabel;
}

class RaftComputerDetailData {
  const RaftComputerDetailData({
    required this.id,
    required this.name,
    required this.online,
    required this.isComputer,
    required this.slug,
    required this.runtimes,
    required this.createdLabel,
    required this.agents,
    required this.canManage,
    this.description,
    this.hostname,
    this.os,
    this.windows = false,
    this.computerVersion,
    this.versionKind = RaftComputerVersionKind.unknown,
    this.availableVersion,
    this.creator,
    this.diskLowTitle,
    this.commands,
    this.service,
  });
  final String id, name, slug, createdLabel;
  final String? description, hostname, os, computerVersion, availableVersion;
  final String? diskLowTitle;
  final bool online, isComputer, windows, canManage;
  final RaftComputerVersionKind versionKind;

  /// Detected Runtimes chips: label (with its availability suffix) and
  /// whether this machine reported it.
  final List<(String, bool)> runtimes;
  final RaftComputerCreator? creator;
  final List<RaftComputerAgent> agents;
  final RaftComputerCommandSet? commands;
  final RaftComputerService? service;
}

/// A failed request whose message the page shows as-is.
class RaftComputerActionError implements Exception {
  const RaftComputerActionError(this.message);
  final String message;
  @override
  String toString() => message;
}

class RaftComputerDetailActions {
  const RaftComputerDetailActions({
    required this.rename,
    required this.describe,
    required this.scanWorkspaces,
    required this.deleteWorkspace,
    required this.restart,
    required this.deleteComputer,
    required this.bulk,
    this.upgrade,
    this.openAgent,
    this.createAgent,
  });
  final Future<void> Function(String name) rename;
  final Future<void> Function(String? description) describe;
  final Future<List<RaftComputerWorkspace>> Function() scanWorkspaces;
  final Future<void> Function(String directoryName) deleteWorkspace;

  /// Throws [RaftComputerActionError] with the copy to show.
  final Future<void> Function() restart;
  final Future<void> Function(String version)? upgrade;
  final Future<void> Function() deleteComputer;

  /// Runs [mode] for the agent ids; returns how many failed.
  final Future<int> Function(RaftComputerBulk mode, List<String> agentIds) bulk;
  final ValueChanged<String>? openAgent;
  final VoidCallback? createAgent;
}

/// Text helpers for the Tailwind classes this page writes in JSX.
class _Ink {
  _Ink(this.t);
  final RaftTokens t;

  Color get strong => t.brutal ? Colors.black : t.colors['foreground-strong']!;
  Color muted(double brutalAlpha) =>
      raftPanelInk(t, brutalAlpha, t.colors['foreground-muted']!);
  Color get orange => t.product.brutalOrange;

  TextStyle body(double size, double line, {Color? color, FontWeight? w}) =>
      raftCssText.merge(
        RaftTypography.body(
          t,
          size: size,
          line: line,
          color: color,
          weight: w ?? FontWeight.w400,
        ),
      );
  TextStyle mono(double size, double line, {Color? color, FontWeight? w}) =>
      raftCssText.merge(
        RaftTypography.mono(
          t,
          size: size,
          line: line,
          color: color,
        ).copyWith(fontWeight: w),
      );

  /// `text-xs leading-5 text-foreground-muted theme-brutal:text-black/60`.
  TextStyle get note => body(12, 20, color: muted(.6));
}

/// `border-b border-line-muted theme-brutal:border-black/10` (also border-t).
Color computerPanelRule(RaftTokens t) => raftPanelRuleColor(t);

/// The border takes layout space like CSS (`Container` adds the border
/// dimensions to its padding).
Widget _rule(
  RaftTokens t, {
  Key? key,
  required bool top,
  required Widget child,
}) => Container(
  key: key,
  decoration: BoxDecoration(
    border: top
        ? Border(top: BorderSide(color: computerPanelRule(t)))
        : Border(bottom: BorderSide(color: computerPanelRule(t))),
  ),
  child: child,
);

Widget _gapColumn(double gap, List<Widget> children) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  mainAxisSize: MainAxisSize.min,
  children: [
    for (var i = 0; i < children.length; i++) ...[
      if (i > 0) SizedBox(height: gap),
      children[i],
    ],
  ],
);

/// Web `KeyValueRow`: label `mb-1 text-xs text-foreground-muted
/// theme-brutal:text-black/50`, value `text-sm text-foreground-strong
/// theme-brutal:text-black` (+ `font-mono`).
class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);
  final String label;
  final Widget value;
  @override
  Widget build(BuildContext context) {
    final ink = _Ink(RaftTokens.of(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RaftCssText(label, style: ink.body(12, 16, color: ink.muted(.5))),
        const SizedBox(height: 4),
        DefaultTextStyle.merge(
          style: ink.body(14, 20, color: ink.strong),
          child: value,
        ),
      ],
    );
  }
}

/// `<Terminal size={16} /> <SectionEyebrow>` header row (`flex items-center
/// gap-2`).
Widget _terminalEyebrow(RaftTokens t, String label) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    RaftIcon(RaftGlyph.terminal, size: 16, color: _Ink(t).strong),
    const SizedBox(width: 8),
    Flexible(child: RaftSectionEyebrow(label)),
  ],
);

/// `<Button size="sm" className="px-2 py-1 text-xs flex items-center
/// gap-1">` with a 12px Lucide icon.
Widget _smallButton(
  String label, {
  Key? key,
  RaftGlyph? glyph,
  RaftButtonRecipeVariant variant = RaftButtonRecipeVariant.outline,
  VoidCallback? onPressed,
  bool brutalDisabledFill = false,
}) => RaftRecipeButton(
  // `theme-brutal:disabled:bg-gray-200` (bulk action bar).
  brutalSurface: brutalDisabledFill && onPressed == null
      ? (t, _) => BoxDecoration(
          color: const Color(0xFFE5E7EB),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: RaftShadowSet.brutalSm,
        )
      : null,
  key: key,
  label: label,
  glyph: glyph,
  glyphSize: 12,
  variant: variant,
  size: RaftButtonRecipeSize.sm,
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  textStep: (12, 16),
  gap: 4,
  disabled: onPressed == null,
  onPressed: onPressed,
);

/// `px-3 py-2 text-sm font-bold flex items-center gap-1.5` / `px-4 py-2`
/// action buttons with a 14px icon.
Widget _actionButton(
  String label, {
  Key? key,
  RaftGlyph? glyph,
  RaftButtonRecipeVariant variant = RaftButtonRecipeVariant.outline,
  VoidCallback? onPressed,
  double horizontal = 12,
  String? tooltip,
}) => RaftRecipeButton(
  key: key,
  label: label,
  glyph: glyph,
  glyphSize: 14,
  variant: variant,
  size: RaftButtonRecipeSize.sm,
  padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 8),
  textStep: (14, 20),
  gap: 6,
  tooltip: tooltip,
  fontWeight: FontWeight.w700,
  disabled: onPressed == null,
  onPressed: onPressed,
);

// ------------------------------------------------------------------ panel

class RaftComputerDetailView extends StatefulWidget {
  const RaftComputerDetailView({
    super.key,
    required this.data,
    required this.actions,
  });
  final RaftComputerDetailData data;
  final RaftComputerDetailActions actions;
  @override
  State<RaftComputerDetailView> createState() => _RaftComputerDetailViewState();
}

class _RaftComputerDetailViewState extends State<RaftComputerDetailView> {
  RaftComputerDetailData get d => widget.data;
  bool get online => d.online;
  bool get isComputer => d.isComputer;

  bool editingName = false, savingName = false;
  String nameError = '';
  final nameField = TextEditingController();
  bool editingDescription = false, savingDescription = false;
  String descriptionError = '';
  final descriptionField = TextEditingController();

  bool selectionMode = false;
  final selected = <String>{};
  RaftComputerBulk? bulkAction;
  String bulkError = '';

  bool scanned = false, scanning = false;
  List<RaftComputerWorkspace> workspaces = const [];

  bool showRecoverySetup = false;
  bool? recoveryGuide;
  String? recoveryKey;

  /// computerOperationProgress: restart in flight / done / error.
  ({bool done, String? error})? operation;
  Timer? operationTimer;

  @override
  void didUpdateWidget(RaftComputerDetailView old) {
    super.didUpdateWidget(old);
    if (old.data.id != d.id) {
      editingName = editingDescription = selectionMode = false;
      selected.clear();
      scanned = false;
      workspaces = const [];
      operation = null;
    }
    // Agents that left the machine drop out of the selection.
    selected.removeWhere((id) => !d.agents.any((a) => a.id == id));
  }

  @override
  void dispose() {
    operationTimer?.cancel();
    nameField.dispose();
    descriptionField.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ actions

  Future<void> saveName() async {
    final next = nameField.text.trim();
    if (next.isEmpty) {
      setState(() => nameError = 'Computer name is required');
      return;
    }
    if (next == d.name) {
      setState(() => editingName = false);
      return;
    }
    setState(() {
      nameError = '';
      savingName = true;
    });
    try {
      await widget.actions.rename(next);
      if (mounted) setState(() => editingName = false);
    } catch (_) {
      if (mounted) setState(() => nameError = 'Failed to rename computer');
    } finally {
      if (mounted) setState(() => savingName = false);
    }
  }

  Future<void> saveDescription() async {
    final next = descriptionField.text.trim();
    if (next.length > 500) {
      setState(
        () => descriptionError = 'Description must be 500 characters or less',
      );
      return;
    }
    if (next == (d.description ?? '')) {
      setState(() => editingDescription = false);
      return;
    }
    setState(() {
      descriptionError = '';
      savingDescription = true;
    });
    try {
      await widget.actions.describe(next.isEmpty ? null : next);
      if (mounted) setState(() => editingDescription = false);
    } catch (_) {
      if (mounted) {
        setState(() => descriptionError = 'Failed to update description');
      }
    } finally {
      if (mounted) setState(() => savingDescription = false);
    }
  }

  Future<void> scan() async {
    setState(() => scanning = true);
    try {
      final found = await widget.actions.scanWorkspaces();
      if (!mounted) return;
      setState(() {
        workspaces = found;
        scanned = true;
      });
    } catch (_) {
      if (mounted) setState(() => scanned = true);
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  Future<void> deleteWorkspace(RaftComputerWorkspace ws) async {
    final ok = await _confirm(
      title: 'Delete Workspace',
      message:
          'Delete workspace for "${ws.label}"? This will permanently remove all workspace files (MEMORY.md, notes/, etc.) from the computer.',
      confirmLabel: 'Delete Workspace',
    );
    if (ok != true) return;
    await widget.actions.deleteWorkspace(ws.directoryName);
    if (mounted) {
      setState(
        () => workspaces = [
          for (final e in workspaces)
            if (e.directoryName != ws.directoryName) e,
        ],
      );
    }
  }

  Future<void> restart() async {
    operationTimer?.cancel();
    setState(() => operation = (done: false, error: null));
    try {
      await widget.actions.restart();
      // Progress stays until the Computer reconnects; the Web gives up
      // after 60s so the buttons come back.
      operationTimer = Timer(const Duration(seconds: 60), () {
        if (!mounted) return;
        setState(
          () => operation = (
            done: true,
            error: 'Restart timed out. Check that the Computer is online and retry.',
          ),
        );
        operationTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => operation = null);
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => operation = (
          done: true,
          error: e is RaftComputerActionError
              ? e.message
              : 'Failed to request restart. The Computer must be online.',
        ),
      );
      operationTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => operation = null);
      });
    }
  }

  Future<void> upgrade(String target) async =>
      widget.actions.upgrade?.call(target);

  Future<void> deleteComputer() async {
    final count = d.agents.length;
    if (count > 0) {
      await _confirm(
        title: 'Cannot Delete Computer',
        message:
            'This computer has $count ${count == 1 ? 'agent' : 'agents'} assigned. Remove all agents before deleting the computer.',
        confirmLabel: 'OK',
        variant: RaftButtonRecipeVariant.outline,
        showCancel: false,
      );
      return;
    }
    final ok = await _confirm(
      title: 'Delete Computer',
      message: 'Are you sure you want to delete "${d.name}"?',
      confirmLabel: 'Delete Computer',
    );
    if (ok != true) return;
    await widget.actions.deleteComputer();
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    RaftButtonRecipeVariant variant = RaftButtonRecipeVariant.danger,
    bool showCancel = true,
  }) => RaftConfirmDialog.show(
    context,
    RaftConfirmDialog(
      surfaceKey: const ValueKey('computer-dialog'),
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      confirmVariant: variant,
      showCancel: showCancel,
    ),
  );

  Future<void> runBulk(RaftComputerBulk action) async {
    final chosen = d.agents.where((a) => selected.contains(a.id)).toList();
    final targets = action == RaftComputerBulk.start
        ? chosen.where((a) => !a.online).toList()
        : action == RaftComputerBulk.stop
        ? chosen.where((a) => a.online).toList()
        : chosen;
    if (targets.isEmpty) return;
    setState(() {
      bulkAction = action;
      bulkError = '';
    });
    final failed = await widget.actions.bulk(action, [
      for (final a in targets) a.id,
    ]);
    if (!mounted) return;
    setState(() {
      bulkAction = null;
      if (failed > 0) {
        bulkError =
            '$failed of ${targets.length} ${targets.length == 1 ? 'agent action' : 'agent actions'} failed. Try again or open an agent for details.';
      } else {
        selectionMode = false;
        selected.clear();
      }
    });
  }

  Future<void> showStopConfirm() async {
    final count = d.agents
        .where((a) => selected.contains(a.id) && a.online)
        .length;
    final ok = await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: const ValueKey('computer-dialog'),
        title: 'Stop Agents',
        message:
            'Stop $count selected online ${count == 1 ? 'agent' : 'agents'}? They will stop processing messages.',
        confirmLabel: 'Stop Agents',
        confirmVariant: RaftButtonRecipeVariant.warning,
      ),
    );
    if (ok == true) await runBulk(RaftComputerBulk.stop);
  }

  Future<void> showResetOptions() async {
    final count = selected.length;
    final mode = await showDialog<RaftComputerBulk>(
      context: context,
      barrierColor: RaftTokens.of(context).brutal
          ? Colors.black.withValues(alpha: .6)
          : RaftTokens.of(context).colors['layer-backdrop'],
      builder: (_) => _BulkResetDialog(count: count),
    );
    if (mode != null) await runBulk(mode);
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final manage = d.canManage;
    return RaftPanelTextScope(
      child: Column(
        key: const ValueKey('computer-detail-panel'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context, t),
          Expanded(
            child: ColoredBox(
              color: t.brutal ? Colors.white : t.colors['layer-panel']!,
              child: SingleChildScrollView(
                key: const Key('fleet-detail'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _identity(t),
                    if (d.diskLowTitle case final diskTitle?)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: RaftBanner(
                          key: const ValueKey('computer-disk-low-banner'),
                          title: diskTitle,
                          description: 'Agents on this computer may fail to save work or start. Raft removes its own old migration data automatically; if space stays low, free up space on this computer.',
                          size: RaftBannerRecipeSize.sm,
                          titleGap: 4,
                        ),
                      ),
                    _nameSection(t, manage),
                    _descriptionSection(t, manage),
                    _infoSection(t),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: _gapColumn(24, [
                        if (!isComputer && manage) ?_migrateBlock(t),
                        if (!isComputer && !manage && !online)
                          _connectionAdminOnly(t),
                        if (isComputer && !online) _recoveryCard(t, manage),
                        _agentsSection(t, manage),
                        if (online)
                          // `mt-2` collapses into `space-y-6` (24px).
                          Padding(
                            padding: EdgeInsets.zero,
                            child: _rule(
                              t,
                              key: const ValueKey(
                                'computer-section-workspaces',
                              ),
                              top: true,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: _workspacesSection(t, manage),
                              ),
                            ),
                          ),
                        if (manage) _actionsSection(t),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// PanelHeader with the Monitor 18 icon, `iconBg="bg-primary-soft
  /// theme-brutal:bg-soft-signal ..."` and `iconAlwaysVisible`.
  Widget _header(BuildContext context, RaftTokens t) => Container(
    key: const ValueKey('computer-section-header'),
    // MainLayout's content column (`bg-layer-canvas-muted`) shows through
    // the transparent Elegant PanelHeader; Brutal paints white.
    color: t.brutal ? Colors.white : t.colors['layer-canvas-muted'],
    child: RaftPanelHeaderBar(
      title: '${d.name}',
      iconSlot: RaftPanelHeaderIconTile(
        glyph: RaftGlyph.monitor,
        // bg-primary-soft theme-brutal:bg-soft-signal; elegant border-0
        // bg-fill-muted (`in-data-[theme=elegant]` wins).
        background: t.brutal ? t.product.softSignal : t.colors['fill-muted']!,
        borderless: !t.brutal,
      ),
    ),
  );

  /// `flex items-start gap-4 px-5 py-5 border-b`: Card size-16 + Monitor 28,
  /// name (`text-lg font-bold leading-tight`), status (StatusDot + `text-sm
  /// font-mono` muted/60), hostname (`text-sm font-mono` muted/50).
  Widget _identity(RaftTokens t) {
    final ink = _Ink(t);
    return _rule(
      t,
      key: const ValueKey('computer-section-identity'),
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(
              dimension: 64,
              child: RaftRecipeCard(
                child: Center(
                  child: RaftIcon(
                    RaftGlyph.monitor,
                    size: 28,
                    color: ink.strong,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RaftCssText(
                    '${d.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ink.body(
                      18,
                      22.5,
                      color: ink.strong,
                      w: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      RaftActivityDot(
                        color: online ? t.product.brutalLime : raftGray400,
                      ),
                      const SizedBox(width: 8),
                      RaftCssText(
                        online ? 'Connected' : 'Offline',
                        style: ink.mono(14, 20, color: ink.muted(.6)),
                      ),
                    ],
                  ),
                  if ((d.hostname ?? '').isNotEmpty)
                    RaftCssText(
                      d.hostname!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ink.mono(14, 20, color: ink.muted(.5)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Eyebrow + pencil row: `flex items-center gap-2 mb-1`.
  Widget _editableEyebrow(
    String label, {
    required bool canEdit,
    required String tooltip,
    required Key key,
    required VoidCallback onEdit,
  }) => Row(
    children: [
      RaftSectionEyebrow(label),
      if (canEdit) ...[
        const SizedBox(width: 8),
        KeyedSubtree(
          key: key,
          child: RaftInlineIconButton(
            glyph: RaftGlyph.pencil,
            tooltip: tooltip,
            onPressed: onEdit,
          ),
        ),
      ],
    ],
  );

  Widget _section(RaftTokens t, String name, List<Widget> children) => _rule(
    t,
    key: ValueKey('computer-section-$name'),
    top: false,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );

  Widget _saveCancel(bool saving, VoidCallback save, VoidCallback cancel) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _smallButton(
            'Save',
            variant: RaftButtonRecipeVariant.accent,
            onPressed: saving ? null : save,
          ),
          const SizedBox(width: 6),
          _smallButton('Cancel', onPressed: saving ? null : cancel),
        ],
      );

  Widget _nameSection(RaftTokens t, bool manage) {
    final ink = _Ink(t);
    return _section(t, 'name', [
      _editableEyebrow(
        'Name',
        canEdit: manage && !editingName,
        tooltip: 'Edit computer name',
        key: const ValueKey('computer-edit-name'),
        onEdit: () => setState(() {
          nameField.text = '${d.name}';
          nameError = '';
          editingName = true;
        }),
      ),
      const SizedBox(height: 4),
      if (manage && editingName)
        _gapColumn(5, [
          RaftRecipeInput(
            fieldKey: const ValueKey('computer-name-field'),
            controller: nameField,
            placeholder: 'Computer name',
            autofocus: true,
            onSubmitted: (_) => saveName(),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _saveCancel(
              savingName,
              saveName,
              () => setState(() => editingName = false),
            ),
          ),
          if (nameError.isNotEmpty)
            RaftCssText(
              nameError,
              style: ink.body(12, 16, color: ink.orange, w: FontWeight.w700),
            ),
        ])
      else
        RaftCssText('${d.name}', style: ink.body(14, 20, color: ink.strong)),
    ]);
  }

  Widget _descriptionSection(RaftTokens t, bool manage) {
    final ink = _Ink(t);
    final description = d.description ?? '';
    return _section(t, 'description', [
      _editableEyebrow(
        'Description',
        canEdit: manage && !editingDescription,
        tooltip: 'Edit computer description',
        key: const ValueKey('computer-edit-description'),
        onEdit: () => setState(() {
          descriptionField.text = description;
          descriptionError = '';
          editingDescription = true;
        }),
      ),
      const SizedBox(height: 4),
      if (manage && editingDescription)
        _gapColumn(5, [
          RaftRecipeTextarea(
            fieldKey: const ValueKey('computer-description-field'),
            controller: descriptionField,
            placeholder: 'What is this computer used for?',
            minHeight: 80,
            maxLength: 500,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          Row(
            children: [
              _saveCancel(
                savingDescription,
                saveDescription,
                () => setState(() => editingDescription = false),
              ),
              const Spacer(),
              RaftCssText(
                '${descriptionField.text.length}/500',
                style: ink.mono(11, 16, color: ink.muted(.4)),
              ),
            ],
          ),
          if (descriptionError.isNotEmpty)
            RaftCssText(
              descriptionError,
              style: ink.body(12, 16, color: ink.orange, w: FontWeight.w700),
            ),
        ])
      else
        RaftCssText(
          description.isEmpty ? 'No description' : description,
          style: description.isEmpty
              ? ink
                    .body(14, 22.75, color: ink.muted(.4))
                    .copyWith(fontStyle: FontStyle.italic)
              : ink.body(14, 22.75, color: ink.strong),
        ),
    ]);
  }

  Widget _infoSection(RaftTokens t) {
    final ink = _Ink(t);
    final version = d.computerVersion;

    final creator = d.creator;

    Widget versionValue() {
      if (version is String && version.isNotEmpty) {
        final outdated = d.versionKind == RaftComputerVersionKind.outdated;
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'v$version',
                style: ink.mono(
                  14,
                  20,
                  color: outdated ? ink.orange : ink.strong,
                  w: outdated ? FontWeight.w700 : null,
                ),
              ),
              if (d.versionKind == RaftComputerVersionKind.current)
                TextSpan(
                  text: ' · Up to date',
                  style: ink.body(12, 16, color: ink.muted(.6)),
                ),
              if (d.versionKind == RaftComputerVersionKind.outdated)
                TextSpan(
                  text: ' · v${d.availableVersion} available',
                  style: ink.body(
                    12,
                    16,
                    color: ink.orange,
                    w: FontWeight.w700,
                  ),
                ),
            ],
          ),
        );
      }
      return RaftCssText(
        online ? 'Reading version…' : '—',
        style: ink
            .body(14, 20, color: ink.muted(.4))
            .copyWith(fontStyle: FontStyle.italic),
      );
    }

    return _section(t, 'info', [
      const RaftSectionEyebrow('Info'),
      const SizedBox(height: 12),
      _gapColumn(12, [
        if ((d.os ?? '').isNotEmpty)
          _KeyValue(
            'OS',
            RaftCssText(d.os!, style: ink.mono(14, 20, color: ink.strong)),
          ),
        if (isComputer) _KeyValue('Computer Version', versionValue()),
        _KeyValue(
          'Detected Runtimes',
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (label, detected) in d.runtimes)
                RaftRuntimeChip(label: label, detected: detected),
            ],
          ),
        ),
        // `flex flex-wrap gap-x-8 gap-y-3`.
        Wrap(
          spacing: 32,
          runSpacing: 12,
          children: [
            _KeyValue(
              'Created',
              RaftCssText(
                d.createdLabel,
                style: ink.mono(14, 20, color: ink.strong),
              ),
            ),
            if (isComputer)
              _KeyValue(
                'Creator',
                creator != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RaftAvatarSlot(
                            name: creator.name,
                            agent: false,
                            avatarUrl: creator.avatarUrl,
                            slot: RaftAvatarSlotContext.creatorLink,
                          ),
                          const SizedBox(width: 8),
                          RaftCssText(
                            creator.name,
                            style: ink.body(
                              14,
                              20,
                              color: ink.strong,
                              w: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          RaftCssText(
                            '@${creator.handle}',
                            style: ink.mono(12, 16, color: ink.muted(.5)),
                          ),
                        ],
                      )
                    : RaftCssText(
                        'No creator assigned',
                        style: ink
                            .body(14, 20, color: ink.muted(.4))
                            .copyWith(fontStyle: FontStyle.italic),
                      ),
              ),
          ],
        ),
      ]),
    ]);
  }

  Widget _commandStep(String label, String command, {String? copyLabel}) {
    final ink = _Ink(RaftTokens.of(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftCssText(
          label,
          style: ink.body(12, 16, color: ink.muted(.6), w: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        RaftCopyableCode(
          command,
          copyLabel: copyLabel ?? 'Copy $label command',
        ),
      ],
    );
  }

  Widget? _migrateBlock(RaftTokens t) {
    final c = d.commands;
    if (c == null) return null;
    final windows = d.windows;
    final ink = _Ink(t);
    return Column(
      key: const ValueKey('computer-section-migrate'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftSectionEyebrow(
          'Migrate to Computer${windows ? ' · Windows x64' : ''}',
        ),
        const SizedBox(height: 8),
        RaftCssText(
          "Raft Computer replaces the legacy daemon — it runs the agents on this machine and keeps itself up to date. Migrating keeps this machine's agents. Run this on the machine itself (${windows ? 'Windows x64 PowerShell' : 'macOS / Linux'}):",
          style: ink.note,
        ),
        const SizedBox(height: 8),
        _gapColumn(12, [
          _commandStep('1. Install', c.install),
          _commandStep('2. Setup', c.setup),
        ]),
      ],
    );
  }

  Widget _connectionAdminOnly(RaftTokens t) {
    final ink = _Ink(t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RaftSectionEyebrow('Connection'),
        const SizedBox(height: 8),
        RaftCssText(
          'Connect commands and API key rotation are admin-only.',
          style: ink.mono(12, 16, color: ink.muted(.4)),
        ),
      ],
    );
  }

  Widget _recoveryCard(RaftTokens t, bool manage) {
    final ink = _Ink(t);
    final c = d.commands;
    final fresh = c;
    final slug = d.slug;
    return Column(
      key: const ValueKey('computer-section-recovery-card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _terminalEyebrow(t, 'Bring this computer back online'),
        const SizedBox(height: 8),
        if (!manage)
          RaftCssText(
            'This computer is offline . Bringing it back online is admin-only.',
            style: ink.body(12, 20, color: ink.muted(.5)),
          )
        else if (c != null)
          _gapColumn(16, [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RaftCssText(
                  "This computer is set up on /$slug but isn't connected right now. Run this on the machine to bring it back:",
                  style: ink.note,
                ),
                const SizedBox(height: 8),
                RaftCopyableCode(c.restart),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RaftCssText(
                  "Not sure why it's offline? Check with:",
                  style: ink.note,
                ),
                const SizedBox(height: 8),
                _gapColumn(8, [
                  RaftCopyableCode(c.status),
                  RaftCopyableCode(c.doctor),
                ]),
              ],
            ),
            _rule(
              t,
              top: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The inline button sits in its parent's 16px/24px line
                    // box: a 24px row with the 12px text on its baseline.
                    Container(
                      height: 24,
                      alignment: Alignment.topLeft,
                      padding: const EdgeInsets.only(top: 5),
                      child: RaftUnderlineTextButton(
                        key: const ValueKey('computer-recovery-setup-toggle'),
                        label: showRecoverySetup
                            ? 'Hide install and setup commands'
                            : 'raft-computer: command not found? Install or re-run setup',
                        style: ink.body(
                          12,
                          16,
                          color: ink.muted(.6),
                          w: FontWeight.w700,
                        ),
                        onPressed: () => setState(
                          () => showRecoverySetup = !showRecoverySetup,
                        ),
                      ),
                    ),
                    if (showRecoverySetup && fresh != null) ...[
                      const SizedBox(height: 8),
                      _gapColumn(12, [
                        RaftCssText(
                          'If the command is not installed, run Install first. Then re-run Setup to reconnect this Computer.',
                          style: ink.note,
                        ),
                        _commandStep(
                          '1. Install',
                          fresh.install,
                          copyLabel: 'Copy install command',
                        ),
                        _commandStep(
                          '2. Setup',
                          fresh.setup,
                          copyLabel: 'Copy setup command',
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
          ]),
      ],
    );
  }

  // ---------------------------------------------------- agents on computer

  Widget _agentsSection(RaftTokens t, bool manage) {
    final ink = _Ink(t);
    final list = d.agents;
    final allSelected = list.isNotEmpty && selected.length == list.length;
    final selectedOnline = list.where(
      (a) => selected.contains(a.id) && a.online,
    );
    final selectedOffline = list.where(
      (a) => selected.contains(a.id) && !a.online,
    );
    final action = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (manage && list.isNotEmpty) ...[
          if (selectionMode) ...[
            _smallButton(
              allSelected ? 'Clear All' : 'Select All',
              key: const ValueKey('computer-agents-select-all'),
              glyph: RaftGlyph.check,
              onPressed: () => setState(() {
                if (allSelected) {
                  selected.clear();
                } else {
                  selected.addAll([for (final a in list) a.id]);
                }
              }),
            ),
            const SizedBox(width: 6),
            _smallButton(
              'Cancel',
              glyph: RaftGlyph.x,
              onPressed: () => setState(() {
                selectionMode = false;
                selected.clear();
                bulkError = '';
              }),
            ),
          ] else
            _smallButton(
              'Select',
              key: const ValueKey('computer-agents-select'),
              glyph: RaftGlyph.check,
              onPressed: () => setState(() => selectionMode = true),
            ),
        ],
        if (manage && !selectionMode) ...[
          if (list.isNotEmpty) const SizedBox(width: 6),
          _smallButton(
            'Create',
            glyph: RaftGlyph.plus,
            variant: RaftButtonRecipeVariant.accent,
            onPressed: widget.actions.createAgent ?? () {},
          ),
        ],
      ],
    );
    Widget row(RaftComputerAgent a) {
      final subtitle = a.subtitle;
      final name = a.name;
      final activityText = a.activityText;
      final right = [
        RaftActivityDot(color: raftActivityDotColor(t, a.activity)),
        Flexible(
          child: RaftCssText(
            activityText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ink.mono(12, 16, color: ink.muted(.5)),
          ),
        ),
      ];
      final avatar = RaftAvatarSlot(
        name: name,
        avatarUrl: a.avatarUrl,
        slot: RaftAvatarSlotContext.surfaceList,
      );
      final isSelected = selected.contains(a.id);
      return RaftAvatarListRow(
        key: ValueKey('computer-agent-${a.id}'),
        avatar: selectionMode
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RaftCheckMarker(
                    checked: isSelected,
                    size: RaftCheckMarkerSize.lg,
                    yellow: true,
                    previewOnHover: true,
                  ),
                  const SizedBox(width: 12),
                  avatar,
                ],
              )
            : avatar,
        name: name,
        subtitle: subtitle,
        rightContent: right,
        selected: selectionMode && manage && isSelected,
        // `bg-layer-canvas-muted theme-brutal:bg-gray-100` rows.
        background: selectionMode && isSelected
            ? null
            : t.brutal
            ? const Color(0xFFF3F4F6)
            : t.colors['layer-canvas-muted'],
        onTap: selectionMode
            ? () => setState(() {
                if (!selected.remove(a.id)) selected.add(a.id);
              })
            : () => widget.actions.openAgent?.call(a.id),
      );
    }

    return Column(
      key: const ValueKey('computer-section-agents'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftSectionHeader(
          label: 'Agents on this computer',
          count: list.length,
          action: action,
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          RaftCssText(
            'No agents assigned to this computer yet.',
            style: ink
                .body(14, 20, color: ink.muted(.4))
                .copyWith(fontStyle: FontStyle.italic),
          )
        else
          _gapColumn(8, [
            if (manage && selected.isNotEmpty)
              RaftSurfaceListItem(
                selected: true,
                interactive: false,
                selectedBackground: t.brutal
                    ? const Color(0xFFF3F4F6)
                    : t.colors['layer-canvas-muted'],
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // `flex flex-wrap items-center gap-2`, eyebrow `mr-auto`.
                    Row(
                      children:
                          [
                                Expanded(
                                  child: RaftSectionEyebrow(
                                    '${selected.length} selected',
                                    color: ink.strong,
                                  ),
                                ),
                                _smallButton(
                                  bulkAction == RaftComputerBulk.start
                                      ? 'Starting…'
                                      : 'Start',
                                  glyph: RaftGlyph.play,
                                  variant: RaftButtonRecipeVariant.success,
                                  brutalDisabledFill: true,
                                  onPressed:
                                      bulkAction == null &&
                                          selectedOffline.isNotEmpty &&
                                          online
                                      ? () => runBulk(RaftComputerBulk.start)
                                      : null,
                                ),
                                _smallButton(
                                  'Stop',
                                  key: const ValueKey('computer-bulk-stop'),
                                  glyph: RaftGlyph.square,
                                  brutalDisabledFill: true,
                                  onPressed:
                                      bulkAction == null &&
                                          selectedOnline.isNotEmpty
                                      ? showStopConfirm
                                      : null,
                                ),
                                _smallButton(
                                  'Restart / Reset',
                                  key: const ValueKey(
                                    'computer-bulk-restart-reset',
                                  ),
                                  glyph: RaftGlyph.rotateCcw,
                                  brutalDisabledFill: true,
                                  onPressed: bulkAction == null && online
                                      ? showResetOptions
                                      : null,
                                ),
                              ]
                              .expand((w) => [w, const SizedBox(width: 8)])
                              .toList()
                            ..removeLast(),
                    ),
                    if (bulkError.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      RaftBanner(
                        description: bulkError,
                        size: RaftBannerRecipeSize.sm,
                      ),
                    ],
                  ],
                ),
              ),
            for (final a in list) row(a),
          ]),
      ],
    );
  }

  // ------------------------------------------------------- workspaces

  Widget _workspacesSection(RaftTokens t, bool manage) {
    final ink = _Ink(t);
    const order = {'orphan': 0, 'deleted': 1, 'stopped': 2, 'active': 3};
    final sorted = [...workspaces]
      ..sort((a, b) => (order[a.status] ?? 3).compareTo(order[b.status] ?? 3));
    final orphan = workspaces.where((e) => e.status == 'orphan').length;
    final deleted = workspaces.where((e) => e.status == 'deleted').length;
    String plural(int n, String one, String other) => n == 1 ? one : other;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftSectionHeader(
          label: 'Agent Workspaces',
          icon: RaftIcon(RaftGlyph.folderOpen, size: 14, color: ink.strong),
          action: _smallButton(
            scanning
                ? 'Scanning…'
                : scanned
                ? 'Rescan'
                : 'Scan',
            key: const ValueKey('computer-workspaces-scan'),
            glyph: RaftGlyph.refreshCw,
            onPressed: scanning ? null : scan,
          ),
        ),
        const SizedBox(height: 8),
        if (!scanned && !scanning)
          RaftCssText(
            'Click Scan to check for workspace directories on this computer.',
            style: ink
                .body(12, 16, color: ink.muted(.4))
                .copyWith(fontStyle: FontStyle.italic),
          ),
        if (scanned && workspaces.isEmpty)
          RaftCssText(
            'No workspace directories found.',
            style: ink
                .body(12, 16, color: ink.muted(.4))
                .copyWith(fontStyle: FontStyle.italic),
          ),
        if (scanned && orphan > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RaftBanner(
              size: RaftBannerRecipeSize.sm,
              description:
                  '$orphan orphaned ${plural(orphan, 'workspace', 'workspaces')} found — no matching agent record exists for these directories.',
              strongPrefix: '$orphan orphaned',
            ),
          ),
        if (scanned && deleted > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _DeletedWorkspaceNote(
              count: deleted,
              text:
                  ' ${plural(deleted, 'workspace', 'workspaces')} found — the agent is deleted but its files still remain on disk.',
            ),
          ),
        if (sorted.isNotEmpty)
          _gapColumn(6, [
            for (final ws in sorted)
              _WorkspaceRow(
                key: ValueKey('computer-workspace-${ws.directoryName}'),
                ws: ws,
                onDelete: manage ? () => deleteWorkspace(ws) : null,
              ),
          ]),
      ],
    );
  }

  // ----------------------------------------------------------- actions

  Widget _actionsSection(RaftTokens t) {
    final c = d.commands;
    final freshInstall = d.commands;
    return _rule(
      t,
      top: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const RaftSectionEyebrow('Actions'),
            const SizedBox(height: 12),
            if (isComputer && online) ...[
              _serviceCard(t, c),
              const SizedBox(height: 12),
            ],
            if (isComputer && c != null && freshInstall != null) ...[
              _recoveryGuide(t, c),
              const SizedBox(height: 12),
            ],
            RaftRecipeCard(
              key: const ValueKey('computer-section-delete'),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RaftCssText(
                          'Delete Computer',
                          style: _Ink(t).body(
                            14,
                            20,
                            color: _Ink(t).strong,
                            w: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        RaftCssText(
                          'Permanently remove this computer. All agents must be deleted first.',
                          style: _Ink(t).body(12, 16, color: _Ink(t).muted(.6)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _actionButton(
                    'Delete Computer',
                    key: const ValueKey('computer-delete'),
                    glyph: RaftGlyph.trash2,
                    variant: RaftButtonRecipeVariant.danger,
                    horizontal: 16,
                    onPressed: deleteComputer,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _serviceCard(RaftTokens t, RaftComputerCommandSet? c) {
    final ink = _Ink(t);
    final service = d.service;
    final kind = service?.kind ?? RaftComputerServiceKind.reading;
    final version = service?.version;
    final sentence = service?.sentence ?? '';
    final webUpgradeOn = service?.webUpgradeOn ?? false;
    final upgradeCommands = kind == RaftComputerServiceKind.commands ? c : null;
    final progress = operation;
    return RaftRecipeCard(
      key: const ValueKey('computer-section-service'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftCssText(
            'Computer',
            style: ink.body(14, 20, color: ink.strong, w: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          if (progress != null)
            progress.done
                ? Row(
                    children: [
                      RaftIcon(
                        progress.error != null
                            ? RaftGlyph.alertCircle
                            : RaftGlyph.checkCircle,
                        size: 14,
                        color: progress.error != null
                            ? t.product.brutalRed
                            : ink.muted(.7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RaftCssText(
                          progress.error ?? 'Restarted.',
                          style: ink.mono(
                            12,
                            16,
                            color: progress.error != null
                                ? t.product.brutalRed
                                : ink.muted(.7),
                          ),
                        ),
                      ),
                    ],
                  )
                : const RaftProgressBar(
                    tone: RaftProgressRecipeVariant.information,
                    label: 'Restarting…',
                  )
          else ...[
            RaftCssText(
              sentence,
              key: const ValueKey('computer-upgrade-status'),
              style: ink.note,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (kind != RaftComputerServiceKind.upgrading)
                  _actionButton(
                    'Restart',
                    key: const ValueKey('computer-restart'),
                    glyph: RaftGlyph.rotateCcw,
                    tooltip: "Use this to restart when the Computer isn't responding.",
                    onPressed: restart,
                  ),
                if (kind == RaftComputerServiceKind.upToDate && webUpgradeOn)
                  _actionButton(
                    'Up to date',
                    glyph: RaftGlyph.checkCircle,
                    variant: RaftButtonRecipeVariant.accent,
                  ),
                if (kind == RaftComputerServiceKind.oneClick)
                  _actionButton(
                    'Upgrade to v$version',
                    key: const ValueKey('computer-upgrade'),
                    glyph: RaftGlyph.play,
                    variant: RaftButtonRecipeVariant.accent,
                    onPressed: () => upgrade(version!),
                  ),
                if (kind == RaftComputerServiceKind.upgrading)
                  _actionButton(
                    'Upgrading…',
                    glyph: RaftGlyph.play,
                    variant: RaftButtonRecipeVariant.accent,
                  ),
              ],
            ),
            if (upgradeCommands != null) ...[
              const SizedBox(height: 12),
              _gapColumn(12, [
                _commandStep(
                  '1. Install the latest version',
                  upgradeCommands.install,
                  copyLabel: 'Copy install command',
                ),
                _commandStep(
                  '2. Restart',
                  upgradeCommands.restartService,
                  copyLabel: 'Copy restart after fresh install command',
                ),
              ]),
            ],
          ],
          if (c != null) ...[
            const SizedBox(height: 16),
            _rule(
              t,
              top: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _terminalEyebrow(t, "Verify from this computer's terminal"),
                    const SizedBox(height: 8),
                    RaftCssText(
                      'If this page and the computer seem to disagree, ask the computer itself:',
                      style: ink.note,
                    ),
                    const SizedBox(height: 8),
                    _gapColumn(8, [
                      RaftCopyableCode(c.status),
                      RaftCopyableCode(c.doctor),
                    ]),
                    const SizedBox(height: 12),
                    RaftCssText(
                      'Web buttons not responding? Restart from the terminal:',
                      style: ink.note,
                    ),
                    const SizedBox(height: 8),
                    RaftCopyableCode(c.restart),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _recoveryGuide(RaftTokens t, RaftComputerCommandSet c) {
    final ink = _Ink(t);
    final key = '${d.id}|${d.online}';
    if (recoveryKey != key) {
      recoveryKey = key;
      recoveryGuide = null;
    }
    final open = recoveryGuide ?? !online;
    final windows = d.windows;
    Widget step(
      String title,
      String description,
      String command,
      String copy,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftCssText(
          title,
          style: ink.body(12, 16, color: ink.strong, w: FontWeight.w700),
        ),
        RaftCssText(description, style: ink.note),
        const SizedBox(height: 8),
        RaftCopyableCode(command, copyLabel: copy),
      ],
    );
    return RaftRecipeCard(
      key: const ValueKey('computer-section-recovery-guide'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftInteractive(
            key: const ValueKey('computer-recovery-guide-toggle'),
            semanticLabel: open ? 'Hide Recovery guide' : 'Show Recovery guide',
            onPressed: () => setState(() => recoveryGuide = !open),
            builder: (context, _) => Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _terminalEyebrow(t, 'Recovery guide'),
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedRotation(
                  turns: open ? .25 : 0,
                  duration: Duration.zero,
                  child: RaftIcon(
                    RaftGlyph.chevronRight,
                    size: 16,
                    color: ink.muted(.6),
                  ),
                ),
              ],
            ),
          ),
          if (open) ...[
            const SizedBox(height: 12),
            _rule(
              t,
              top: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RaftCssText(
                      'Start with the lightest recovery step and move down only if the problem continues.',
                      style: ink.note,
                    ),
                    const SizedBox(height: 16),
                    _gapColumn(16, [
                      step(
                        '1. Restart',
                        'Use this first when the service is stuck or an upgrade is not taking effect.',
                        c.restart,
                        'Copy command',
                      ),
                      step(
                        '2. Fresh install${windows ? ' · Windows x64' : ''}',
                        "Reinstall the binary and supervisor without removing this Computer's identity or credentials.",
                        c.install,
                        'Copy fresh install command',
                      ),
                      step(
                        '3. Restart after install',
                        'Run this after the fresh install finishes so the service reloads the newly installed binary.',
                        c.restartService,
                        'Copy restart after fresh install command',
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// `mb-2 border-2 border-line-muted theme-brutal:border-black bg-fill-muted
/// theme-brutal:bg-gray-200 px-3 py-2 text-xs text-foreground-strong`.
class _DeletedWorkspaceNote extends StatelessWidget {
  const _DeletedWorkspaceNote({required this.count, required this.text});
  final int count;
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ink = _Ink(t);
    final style = ink.body(12, 16, color: ink.strong);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.brutal ? const Color(0xFFE5E7EB) : t.colors['fill-muted'],
        border: Border.all(
          color: t.brutal ? Colors.black : t.colors['line-muted']!,
          width: 2,
        ),
      ),
      child: Text.rich(
        TextSpan(
          style: style,
          children: [
            TextSpan(
              text: '$count deleted-agent',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }
}

/// WorkspacesSection row: `flex items-center gap-2 border-2 px-3 py-2`,
/// tinted per status, FolderOpen 14, name (`font-bold text-xs`) + status
/// badge, mono path, status note, size · files · modified, delete button.
class _WorkspaceRow extends StatelessWidget {
  const _WorkspaceRow({super.key, required this.ws, this.onDelete});
  final RaftComputerWorkspace ws;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ink = _Ink(t);
    final status = ws.status;
    final (border, fill) = switch (status) {
      'orphan' => (
        t.brutal ? t.product.brutalOrange : t.colors['warning']!,
        t.brutal
            ? t.product.brutalOrange.withValues(alpha: .1)
            : t.colors['warning-soft'],
      ),
      'deleted' => (
        t.brutal ? Colors.black : t.colors['line-muted']!,
        t.brutal ? const Color(0xFFF3F4F6) : t.colors['fill-muted'],
      ),
      _ => (
        t.brutal ? Colors.black.withValues(alpha: .3) : t.colors['line-muted']!,
        null,
      ),
    };
    final meta = ink.mono(10, 15, color: ink.muted(.5));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: border, width: 2),
      ),
      child: Row(
        children: [
          RaftIcon(RaftGlyph.folderOpen, size: 14, color: ink.muted(.4)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: RaftCssText(
                        ws.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ink.body(
                          12,
                          16,
                          color: ink.strong,
                          w: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    RaftRecipeBadge(
                      status,
                      uppercase: true,
                      appearance: RaftBadgeRecipeAppearance.solid,
                      variant: switch (status) {
                        'active' => RaftBadgeRecipeVariant.success,
                        'orphan' => RaftBadgeRecipeVariant.warning,
                        _ => RaftBadgeRecipeVariant.muted,
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                RaftCssText(
                  '~/.slock/agents/${ws.directoryName}/',
                  style: ink.mono(10, 15, color: ink.muted(.4)),
                ),
                if (status == 'deleted' || status == 'orphan') ...[
                  const SizedBox(height: 2),
                  RaftCssText(
                    status == 'deleted'
                        ? 'AGENT DELETED. WORKSPACE RETAINED ON DISK.'
                        : 'NO MATCHING AGENT RECORD FOUND.',
                    style: ink
                        .body(
                          10,
                          15,
                          color: status == 'orphan'
                              ? ink.orange
                              : ink.muted(.6),
                          w: FontWeight.w700,
                        )
                        .copyWith(letterSpacing: .25),
                  ),
                ],
                const SizedBox(height: 2),
                Wrap(
                  spacing: 12,
                  children: [
                    RaftCssText(ws.sizeLabel, style: meta),
                    RaftCssText(ws.filesLabel, style: meta),
                    if (ws.modifiedLabel != null)
                      RaftCssText(ws.modifiedLabel!, style: meta),
                  ],
                ),
              ],
            ),
          ),
          if (onDelete != null)
            RaftRecipeButton(
              key: ValueKey('computer-workspace-delete-${ws.directoryName}'),
              variant: RaftButtonRecipeVariant.danger,
              size: RaftButtonRecipeSize.sm,
              padding: const EdgeInsets.all(4),
              glyph: RaftGlyph.trash2,
              // The sm recipe's `& svg` 14px beats Lucide's size={12}.
              glyphSize: 14,
              tooltip: 'Delete workspace',
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

/// MachineAgentList `Restart N Agents` DialogCard: three option cards, the
/// full-reset warning, Cancel + the mode's action.
class _BulkResetDialog extends StatefulWidget {
  const _BulkResetDialog({required this.count});
  final int count;
  @override
  State<_BulkResetDialog> createState() => _BulkResetDialogState();
}

class _BulkResetDialogState extends State<_BulkResetDialog> {
  RaftComputerBulk mode = RaftComputerBulk.restart;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ink = _Ink(t);
    final options = [
      (
        RaftComputerBulk.restart,
        'Restart',
        'Stop and restart the selected agents. Runtime sessions and workspace files are preserved.',
        t.brutal
            ? t.product.brutalCyan.withValues(alpha: .2)
            : t.colors['info-soft']!,
      ),
      (
        RaftComputerBulk.session,
        'Reset Session & Restart',
        'Clear runtime sessions and restart the selected agents. Workspace files are preserved.',
        t.brutal
            ? t.product.brutalOrange.withValues(alpha: .2)
            : t.colors['warning-soft']!,
      ),
      (
        RaftComputerBulk.full,
        'Full Reset & Restart',
        'Clear runtime sessions, delete workspace files, and restart the selected agents.',
        t.brutal
            ? t.product.brutalRed.withValues(alpha: .2)
            : t.colors['danger-soft']!,
      ),
    ];
    final current = options.firstWhere((o) => o.$1 == mode);
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: RaftDialogCard(
            key: const ValueKey('computer-dialog'),
            title:
                'Restart ${widget.count} ${widget.count == 1 ? 'Agent' : 'Agents'}',
            onClose: () => Navigator.of(context).pop(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _gapColumn(12, [
                  for (final (value, label, description, tint) in options)
                    RaftOptionCard(
                      selected: mode == value,
                      selectedFill: tint,
                      onPressed: () => setState(() => mode = value),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RaftCssText(
                            label.toUpperCase(),
                            style: ink.body(
                              14,
                              20,
                              color: ink.strong,
                              w: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          RaftCssText(
                            description,
                            style: ink.body(12, 16, color: ink.muted(.6)),
                          ),
                        ],
                      ),
                    ),
                ]),
                if (mode == RaftComputerBulk.full) ...[
                  const SizedBox(height: 12),
                  const RaftBanner(
                    size: RaftBannerRecipeSize.sm,
                    description: 'Full reset permanently deletes workspace files including MEMORY.md and notes/. This cannot be undone.',
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _actionButton(
                      'Cancel',
                      horizontal: 16,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    _actionButton(
                      current.$2,
                      glyph: RaftGlyph.rotateCcw,
                      horizontal: 16,
                      variant: mode == RaftComputerBulk.full
                          ? RaftButtonRecipeVariant.danger
                          : mode == RaftComputerBulk.session
                          ? RaftButtonRecipeVariant.warning
                          : RaftButtonRecipeVariant.information,
                      onPressed: () => Navigator.of(context).pop(mode),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
