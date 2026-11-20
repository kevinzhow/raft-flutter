import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/cause_notice.dart';
import '../data/workspace_controller.dart';
import 'app_link_store.dart';
import 'integrations_views.dart' show integrationInitials;

const _description =
    'Apps you allow show previews of their links, for you on this server. After you allow an app, it knows which of its links you view.';

RaftListRow _consentRow(
  String? title, {
  Key? key,
  String? description,
  Widget? logo,
  Widget? action,
}) => RaftListRow(
  key: key,
  variant: RaftListRowVariant.plain,
  interactive: false,
  children: [
    ?logo,
    RaftListRowBody(
      children: [
        if (title != null) RaftListRowTitle(title),
        if (description != null) RaftListRowDescription(description),
      ],
    ),
    ?action,
  ],
);

class LinkPreviewConsents extends StatefulWidget {
  const LinkPreviewConsents({
    super.key,
    required this.workspace,
    this.guest = false,
  });

  final WorkspaceController workspace;
  final bool guest;

  @override
  State<LinkPreviewConsents> createState() => _LinkPreviewConsentsState();
}

class _LinkPreviewConsentsState extends State<LinkPreviewConsents> {
  late final store = AppLinkStore.of(widget.workspace);

  @override
  void initState() {
    super.initState();
    unawaited(store.readConsentChoices());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      store.consentChoices,
      store.consentChoicesFailed,
    ]),
    builder: (context, _) {
      final rows = store.consentChoices.value;
      String tr(String value) => raftText(context, value);
      if (!store.current) return const SizedBox.shrink();
      if (store.consentChoicesFailed.value) {
        return RaftListRowGroup(
          children: [
            _consentRow(
              tr('Link previews'),
              description: tr('Couldn’t load your link preview choices.'),
              action: RaftButton(
                label: tr('Retry'),
                uiSize: RaftButtonSize.md,
                onPressed: store.readConsentChoices,
              ),
            ),
          ],
        );
      }
      if (rows == null) {
        return widget.guest
            ? const RaftListRowGroup(
                children: [
                  RaftListRowSkeleton(
                    variant: RaftListRowVariant.plain,
                    description: true,
                  ),
                ],
              )
            : const SizedBox.shrink();
      }
      if (rows.isEmpty) {
        if (!widget.guest) return const SizedBox.shrink();
        return RaftCard(
          key: const ValueKey('link-preview-consents-card'),
          variant: RaftCardRecipeVariant.inset,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RaftCardSectionHeader(
                aboveContent: true,
                title: RaftCardTitle(Text(tr('Link previews'))),
                description: RaftCardDescription(Text(tr(_description))),
              ),
              Padding(
                padding: const EdgeInsets.all(RaftSpace.x4),
                child: Text(
                  tr('No link previews yet'),
                  textAlign: TextAlign.center,
                  style: RaftTokens.of(context)
                      .scale(RaftTypeScale.callout, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      }
      final allowed = rows.where((row) => row.allowed).length;
      final declined = rows.length - allowed;
      final counts = [
        if (allowed > 0)
          raftFormat(context, '{count} allowed', {'count': allowed}),
        if (declined > 0)
          raftFormat(context, '{count} declined', {'count': declined}),
      ];
      return RaftListRowGroup(
        children: [
          _consentRow(
            tr('Link previews'),
            description: counts.join(' · '),
            action: RaftButton(
              key: const ValueKey('link-preview-consents-manage'),
              label: tr('Manage'),
              uiSize: RaftButtonSize.md,
              onPressed: () => openLinkPreviewConsents(context, store),
            ),
          ),
        ],
      );
    },
  );
}

Future<void> openLinkPreviewConsents(
  BuildContext context,
  AppLinkStore store,
) => showRaftForm<void>(
  context,
  guardUnsaved: false,
  dialogMaxWidth: 448,
  label: raftText(context, 'Link previews'),
  builder: (_) => _LinkPreviewChoices(store: store),
);

class LinkPreviewAppChoice extends StatelessWidget {
  const LinkPreviewAppChoice({
    super.key,
    required this.store,
    required this.appId,
  });

  final AppLinkStore store;
  final String appId;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: store.consentChoices,
    builder: (context, rows, _) {
      final choice = rows?.where((row) => row.id == appId).firstOrNull;
      if (choice == null || !store.current) return const SizedBox.shrink();
      return RaftConnectedAppDetailSection(
        title: 'Link previews',
        child: _LinkPreviewChoices(store: store, appId: appId),
      );
    },
  );
}

class _LinkPreviewChoices extends StatefulWidget {
  const _LinkPreviewChoices({required this.store, this.appId});
  final AppLinkStore store;
  final String? appId;

  @override
  State<_LinkPreviewChoices> createState() => _LinkPreviewChoicesState();
}

class _LinkPreviewChoicesState extends State<_LinkPreviewChoices> {
  final search = TextEditingController();
  final searchFocus = FocusNode();
  final actions = <String, FocusNode>{};
  late final issue = CauseNotice(scope: () => widget.store.current);
  String? changing;

  @override
  void dispose() {
    search.dispose();
    searchFocus.dispose();
    for (final action in actions.values) {
      action.dispose();
    }
    super.dispose();
  }

  Future<void> change(AppLinkConsentRow row, {required bool allow}) async {
    if (changing != null || !widget.store.current) return;
    final hadFocus = actions[row.id]?.hasFocus == true;
    setState(() {
      changing = row.id;
      issue.clear();
    });
    try {
      final ok = await widget.store.chooseApp(row.id, allow: allow);
      if (!mounted || !widget.store.current) return;
      if (ok) {
        await widget.store.readConsentChoices();
        if (allow && hadFocus) _restoreFocus(row.id);
      } else {
        final text = raftFormat(
          context,
          allow
              ? 'Couldn’t allow {app}. Check your connection and try again.'
              : 'Couldn’t revoke {app}. Check your connection and try again.',
          {'app': row.name},
        );
        if (!allow) throw StateError(text);
        setState(() => issue.raise(text));
      }
    } finally {
      if (mounted) setState(() => changing = null);
    }
  }

  Future<void> revoke(AppLinkConsentRow row) async {
    final confirmed = await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: const ValueKey('link-preview-consents-revoke-dialog'),
        title: raftFormat(context, 'Revoke {app}?', {'app': row.name}),
        message: raftFormat(
          context,
          '{app} link previews stop for you on this server, and {app} no longer learns which of its links you view. Signing in to {app} later won’t turn them back on; you can allow them again here anytime.',
          {'app': row.name},
        ),
        cancelLabel: raftText(context, 'Keep allowed'),
        confirmLabel: raftText(context, 'Revoke'),
        confirmKey: const ValueKey('link-preview-consents-revoke-confirm'),
        confirmVariant: RaftButtonRecipeVariant.warning,
        actionSize: RaftButtonRecipeSize.lg,
        maxWidth: 400,
        initialFocusCancel: true,
        loadingLabel: raftTextZh(context, 'Revoking…', '正在撤销…'),
        onConfirm: () => change(row, allow: false),
      ),
      overModal: widget.appId == null,
    );
    if (confirmed == true) _restoreFocus(row.id);
  }

  void _restoreFocus(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          (ModalRoute.of(context)?.isCurrent ?? true) &&
          widget.store.current) {
        actions[id]?.requestFocus();
      }
    });
  }

  RaftListRow _row(BuildContext context, AppLinkConsentRow row) {
    final date = DateFormat.yMMMd(Localizations.localeOf(context).toString())
        .format(row.date.toLocal());
    final manage = widget.appId == null;
    return _consentRow(
      manage ? row.name : null,
      key: ValueKey('link-preview-choice-${row.id}'),
      logo: manage
          ? ExcludeSemantics(
              child: RaftAppLogo(
                initials: integrationInitials(row.name),
                logoUrl: row.icon,
                size: RaftAppLogoSize.xs,
              ),
            )
          : null,
      description: raftFormat(
        context,
        row.allowed ? 'Allowed on {date}' : 'Declined on {date}',
        {'date': date},
      ),
      action: RaftButton(
        uiSize: RaftButtonSize.md,
        focusNode: actions.putIfAbsent(row.id, FocusNode.new),
        label: raftText(
          context,
          row.allowed
              ? 'Revoke'
              : changing == row.id
              ? 'Allowing…'
              : 'Allow',
        ),
        onPressed: changing != null
            ? null
            : row.allowed
            ? () => revoke(row)
            : () => change(row, allow: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: widget.store.consentChoices,
    builder: (context, rows, _) {
      String tr(String value) => raftText(context, value);
      final appId = widget.appId;
      final searchable = appId == null && (rows?.length ?? 0) > 8;
      final query = searchable ? search.text.trim().toLowerCase() : '';
      final shown = [
        for (final row in rows ?? const <AppLinkConsentRow>[])
          if (row.name.toLowerCase().contains(query) &&
              (appId == null || row.id == appId))
            row,
      ];
      if (appId != null) {
        return shown.isEmpty
            ? const SizedBox.shrink()
            : RaftListRowGroup(children: [_row(context, shown.first)]);
      }
      if (searchable && !RaftInteraction.of(context).touch) {
        if (!searchFocus.hasFocus && actions.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) searchFocus.requestFocus();
          });
        }
      }
      final body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: RaftSpace.x4,
        children: [
          RaftDialogDescription(tr(_description)),
          if (searchable)
            RaftSearchInput(
              controller: search,
              focusNode: searchFocus,
              hint: tr('Search apps'),
              clearLabel: tr('Clear search'),
              onChanged: (_) => setState(() {}),
              onClear: () {
                setState(search.clear);
                searchFocus.requestFocus();
              },
            ),
          if (issue.message case final message?) RaftErrorBanner(message),
          if (rows?.isEmpty == true)
            Text(tr('No link previews yet'))
          else if (shown.isEmpty)
            Text(tr('No apps match this search')),
          for (final allowed in [true, false])
            if (shown.any((row) => row.allowed == allowed))
              Column(
                spacing: RaftSpace.x2,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RaftDialogSectionEyebrow(
                    tr(allowed ? 'Allowed' : 'Declined'),
                  ),
                  RaftListRowGroup(
                    children: [
                      for (final row in shown.where(
                        (row) => row.allowed == allowed,
                      ))
                        _row(context, row),
                    ],
                  ),
                ],
              ),
        ],
      );
      void close() => Navigator.of(context).pop();
      const key = ValueKey('link-preview-consents-dialog');
      if (RaftFormFrame.sheetOf(context)) {
        return RaftFormSheet(
          key: key,
          title: tr('Link previews'),
          onClose: close,
          commit: const SizedBox.shrink(),
          body: body,
        );
      }
      return RaftDialog.card(
        key: key,
        title: 'Link previews',
        onClose: close,
        child: body,
      );
    },
  );
}
