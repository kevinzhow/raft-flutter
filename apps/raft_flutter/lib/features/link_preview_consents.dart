import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/cause_notice.dart';
import '../data/workspace_controller.dart';
import 'app_link_store.dart';

const _description =
    'Apps you allow show previews of their links, for you on this server. After you allow an app, it knows which of its links you view.';

RaftListRow _consentRow(
  String title, {
  Key? key,
  String? description,
  Widget? action,
}) => RaftListRow(
  key: key,
  variant: RaftListRowVariant.plain,
  interactive: false,
  children: [
    RaftListRowBody(
      children: [
        RaftListRowTitle(title),
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
              action: RaftSettingsRecipeButton(
                label: tr('Retry'),
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
        return widget.guest
            ? _consentRow(tr('No link previews yet'))
            : const SizedBox.shrink();
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
            action: RaftSettingsRecipeButton(
              key: const ValueKey('link-preview-consents-manage'),
              label: tr('Manage'),
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
  late final issue = CauseNotice(scope: () => widget.store.current);
  String? changing;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> change(AppLinkConsentRow row, {required bool allow}) async {
    if (changing != null || !widget.store.current) return;
    setState(() {
      changing = row.id;
      issue.clear();
    });
    try {
      final ok = await widget.store.chooseApp(row.id, allow: allow);
      if (!mounted || !widget.store.current) return;
      if (ok) {
        await widget.store.readConsentChoices();
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
    await RaftConfirmDialog.show(
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
        loadingLabel: raftTextZh(context, 'Revoking…', '正在撤销…'),
        onConfirm: () => change(row, allow: false),
      ),
      overModal: true,
    );
  }

  Widget _row(BuildContext context, AppLinkConsentRow row) {
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(row.date.toLocal());
    return _consentRow(
      row.name,
      key: ValueKey('link-preview-choice-${row.id}'),
      description: raftFormat(
        context,
        row.allowed ? 'Allowed on {date}' : 'Declined on {date}',
        {'date': date},
      ),
      action: RaftButton(
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
      final query = search.text.trim().toLowerCase();
      final shown = [
        for (final row in rows ?? const <AppLinkConsentRow>[])
          if (row.name.toLowerCase().contains(query) &&
              (appId == null || row.id == appId))
            row,
      ];
      if (appId != null) {
        return shown.isEmpty
            ? const SizedBox.shrink()
            : _row(context, shown.first);
      }
      final body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: RaftSpace.x3,
        children: [
          Text(tr(_description)),
          if (rows?.isNotEmpty == true)
            RaftRecipeInput(
              controller: search,
              placeholder: tr('Search apps'),
              autofocus: !RaftInteraction.of(context).touch,
              onChanged: (_) => setState(() {}),
            ),
          if (issue.message case final message?) RaftErrorBanner(message),
          if (rows?.isEmpty == true)
            Text(tr('No link previews yet'))
          else if (shown.isEmpty)
            Text(tr('No apps match this search')),
          for (final allowed in [true, false])
            if (shown.any((row) => row.allowed == allowed)) ...[
              RaftDialogSectionEyebrow(tr(allowed ? 'Allowed' : 'Declined')),
              for (final row in shown.where((row) => row.allowed == allowed))
                _row(context, row),
            ],
        ],
      );
      void close() => Navigator.of(context).pop();
      const key = ValueKey('link-preview-consents-dialog');
      if (RaftFormFrame.sheetOf(context)) {
        return RaftFormSheet(
          key: key,
          title: tr('Link previews'),
          onClose: close,
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
