import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/source_feedback_store.dart';
import '../data/workspace_controller.dart';
import 'page_layout.dart';

/// GET-only account-owned inbox and conversation. No creation/reply/close action.
class SourceFeedbackView extends StatefulWidget {
  const SourceFeedbackView({
    super.key,
    required this.controller,
    this.onUnreadChanged,
  });
  final WorkspaceController controller;
  final ValueChanged<int>? onUnreadChanged;
  @override
  State<SourceFeedbackView> createState() => _SourceFeedbackViewState();
}

class _SourceFeedbackViewState extends State<SourceFeedbackView> {
  late SourceFeedbackStore store;
  StreamSubscription<RaftEvent>? session;

  /// Account/server identity only: the inbox survives channel switches and
  /// thread opens (Source feedback store is account-owned).
  String? authority() {
    final w = widget.controller;
    final user = w.client.user;
    if (user == null) return null;
    return jsonEncode([
      w.client.origin,
      user.id,
      w.client.serverId,
      w.server?.id,
      w.server?.string('role'),
      w.client.generation,
    ]);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    try {
      return await widget.controller.client.get(path, query: query);
    } on RaftApiException catch (e) {
      throw SourceFeedbackFailure(switch (e.details['code']) {
        'feedback_not_found' => SourceFeedbackError.notFound,
        'feedback_rate_limited' => SourceFeedbackError.rateLimited,
        _ =>
          e.status == 401 || e.status == 403
              ? SourceFeedbackError.unauthorized
              : SourceFeedbackError.unavailable,
      });
    }
  }

  void bind() {
    store = SourceFeedbackStore(
      get: get,
      authority: authority,
      onUnreadChanged: (count) {
        if (mounted && store.authorized) widget.onUnreadChanged?.call(count);
      },
    );
    widget.controller.addListener(changed);
    session = widget.controller.client.events.listen((_) => changed());
    unawaited(store.loadList());
  }

  void changed() {
    if (!mounted) return;
    if (store.syncAuthority()) unawaited(store.loadList());
  }

  @override
  void initState() {
    super.initState();
    bind();
  }

  @override
  void didUpdateWidget(SourceFeedbackView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(changed);
      unawaited(session?.cancel());
      store.dispose();
      bind();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(changed);
    unawaited(session?.cancel());
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SourceFeedbackProjectionView(store: store);
}

// Original FeedbackInbox uses source Tabs and18px content inset/gap12;
// AboutFeedbackPanel supplies the shared canonical PanelHeader separately.
@immutable
class _FeedbackRecipe {
  const _FeedbackRecipe(this.tokens);
  final RaftTokens tokens;
  EdgeInsets get inset => const EdgeInsets.all(18);
  double get gap => 12;
  TextStyle get title => RaftTypography.heading(tokens, size: 14, line: 20);
  TextStyle get body => RaftTypography.body(tokens, size: 14, line: 20);
  TextStyle get meta =>
      RaftTypography.body(tokens, size: 12, line: 16.8, color: tokens.muted);
}

String _copy(BuildContext context, String english, String chinese) =>
    Localizations.localeOf(context).languageCode == 'zh' ? chinese : english;

String _status(BuildContext context, String status) => switch (status) {
  'open' => _copy(context, 'Open', '待处理'),
  'in_progress' => _copy(context, 'In progress', '处理中'),
  'resolved' => _copy(context, 'Resolved', '已解决'),
  'closed' => _copy(context, 'Closed', '已关闭'),
  _ => '',
};

String? _reason(BuildContext context, String? reason) => switch (reason) {
  'completed' => _copy(context, 'Completed', '已完成'),
  'no_longer_needed' => _copy(context, 'No longer needed', '不再需要'),
  'not_planned' => _copy(context, 'Not planned', '暂不处理'),
  'cannot_reproduce' => _copy(context, 'Cannot reproduce', '无法复现'),
  'duplicate' => _copy(context, 'Duplicate', '重复工单'),
  _ => null,
};

String _errorCopy(BuildContext context, SourceFeedbackError error) =>
    switch (error) {
      SourceFeedbackError.unavailable => _copy(
        context,
        "Couldn't load feedback. Try again.",
        '反馈加载失败，请重试。',
      ),
      SourceFeedbackError.unauthorized => _copy(
        context,
        'Your feedback session expired. Reopen feedback and try again.',
        '反馈会话已过期，请重新打开后重试。',
      ),
      SourceFeedbackError.notFound => _copy(
        context,
        'This feedback ticket is no longer available.',
        '该反馈工单已不可用。',
      ),
      SourceFeedbackError.rateLimited => _copy(
        context,
        'Too many feedback requests. Try again later.',
        '请求过于频繁，请稍后重试。',
      ),
    };

// Original provider.js16–20 formats new Date(number): epoch milliseconds,
// local timezone, medium date (including year), short localized time.
bool _dateSymbolsReady = false;
String _date(BuildContext context, int milliseconds) {
  if (!_dateSymbolsReady) {
    // intl's local provider installs its bundled symbol tables synchronously;
    // the returned completed Future performs no network or file operations.
    unawaited(initializeDateFormatting());
    _dateSymbolsReady = true;
  }
  return DateFormat.yMMMd(
    Localizations.localeOf(context).languageCode == 'zh' ? 'zh_CN' : 'en',
  ).add_jm().format(DateTime.fromMillisecondsSinceEpoch(milliseconds));
}

/// Transport-independent presentation seam used for delayed-GET widget tests.
class SourceFeedbackProjectionView extends StatelessWidget {
  const SourceFeedbackProjectionView({super.key, required this.store});
  final SourceFeedbackStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final t = RaftTokens.of(context),
          recipe = _FeedbackRecipe(RaftTokens.of(context));
      final detail = store.selectedId != null;
      return PopScope(
        canPop: !detail,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && detail) store.back();
        },
        child: Material(
          color: t.canvas,
          child: Column(
            children: [
              RaftPageHeader(
                title: detail
                    ? _copy(context, 'Feedback ticket', '反馈工单')
                    : _copy(context, 'Feedback', '反馈'),
                height: raftPageHeaderHeight(context),
                mobile:
                    MediaQuery.sizeOf(context).width <
                    RaftLayoutMetrics.desktopBreakpoint,
                icon: const RaftIcon(RaftGlyph.messageSquare, size: 18),
                leading: detail ? RaftBackButton(onPressed: store.back) : null,
                actions: [
                  RaftIconButton(
                    glyph: RaftGlyph.refreshCw,
                    tooltip: _copy(context, 'Refresh', '刷新'),
                    onPressed:
                        !store.authorized ||
                            (detail ? store.detailLoading : store.listLoading)
                        ? null
                        : () => unawaited(
                            detail ? store.loadDetail() : store.loadList(),
                          ),
                  ),
                ],
              ),
              Expanded(
                child: !store.authorized
                    ? Center(
                        child: Text(
                          _errorCopy(context, SourceFeedbackError.unauthorized),
                          style: recipe.body,
                        ),
                      )
                    : detail
                    ? _detail(context, recipe)
                    : _inbox(context, recipe),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _error(
    BuildContext context,
    SourceFeedbackError error,
    VoidCallback retry,
  ) => Semantics(
    liveRegion: true,
    child: RaftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_errorCopy(context, error)),
          const SizedBox(height: 12),
          RaftTextButton(
            label: _copy(context, 'Try again', '重试'),
            onPressed: retry,
          ),
        ],
      ),
    ),
  );

  Widget _loading(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(_copy(context, 'Loading feedback', '正在加载反馈')),
  );

  Widget _inbox(BuildContext context, _FeedbackRecipe recipe) {
    final rows = store.visibleTickets;
    final empty = switch (store.filter) {
      SourceFeedbackFilter.all => _copy(context, 'No feedback yet', '还没有反馈'),
      SourceFeedbackFilter.open => _copy(
        context,
        'Nothing in progress',
        '没有进行中的反馈',
      ),
      SourceFeedbackFilter.resolved => _copy(
        context,
        'Nothing ended yet',
        '还没有已结束的反馈',
      ),
    };
    return ListView(
      key: const Key('feedback-inbox'),
      padding: recipe.inset,
      children: [
        RaftSegmentedControl<SourceFeedbackFilter>(
          value: store.filter,
          label: _copy(context, 'Status filter', '状态筛选'),
          style: RaftSegmentedStyle.tabs,
          items: [
            RaftSegmentedOption(
              value: SourceFeedbackFilter.all,
              label: _copy(context, 'All', '全部'),
            ),
            RaftSegmentedOption(
              value: SourceFeedbackFilter.open,
              label: _copy(context, 'Active', '活跃'),
            ),
            RaftSegmentedOption(
              value: SourceFeedbackFilter.resolved,
              label: _copy(context, 'Ended', '已结束'),
            ),
          ],
          onChanged: store.setFilter,
        ),
        SizedBox(height: recipe.gap),
        if (store.listLoading) _loading(context),
        if (store.listError != null)
          _error(
            context,
            store.listError!,
            () => unawaited(store.loadList(retry: true)),
          ),
        if (!store.listLoading && store.listError == null && rows.isEmpty)
          Text(empty, key: const Key('feedback-empty'), style: recipe.body),
        for (final ticket in rows) ...[
          RaftPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User content uses the raw-control child, never dictionary lookup.
                RaftControl(
                  key: ValueKey('feedback-ticket-${ticket.id}'),
                  variant: RaftControlVariant.ghost,
                  semanticLabel: ticket.title,
                  onPressed: () => unawaited(store.openTicket(ticket.id)),
                  child: Text(
                    ticket.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: recipe.title,
                  ),
                ),
                Text(_date(context, ticket.updatedAt), style: recipe.meta),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    Text(_status(context, ticket.status), style: recipe.meta),
                    Text(
                      _copy(
                        context,
                        ticket.kind == 'feedback' ? 'Idea' : 'Bug',
                        ticket.kind == 'feedback' ? '想法' : '问题',
                      ),
                      style: recipe.meta,
                    ),
                    if (ticket.unread)
                      Semantics(
                        key: ValueKey('feedback-unread-${ticket.id}'),
                        container: true,
                        label: _copy(
                          context,
                          '${ticket.badgeCount} unread',
                          '${ticket.badgeCount} 条未读',
                        ),
                        excludeSemantics: true,
                        child: Text(ticket.badgeLabel, style: recipe.meta),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (store.nextCursor != null && !store.listLoading)
          RaftTextButton(
            label: _copy(context, 'Load more', '加载更多'),
            onPressed: () => unawaited(store.loadList(more: true)),
          ),
      ],
    );
  }

  Widget _detail(BuildContext context, _FeedbackRecipe recipe) {
    final ticket = store.detail;
    return ListView(
      key: ValueKey('feedback-detail-${store.selectedId}'),
      padding: recipe.inset,
      children: [
        if (store.detailLoading) _loading(context),
        if (store.detailError != null)
          _error(
            context,
            store.detailError!,
            () => unawaited(store.loadDetail(retry: true)),
          ),
        if (ticket != null) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(_status(context, ticket.status), style: recipe.meta),
              Text(_date(context, ticket.createdAt), style: recipe.meta),
            ],
          ),
          SizedBox(height: recipe.gap),
          RaftPanel(child: SelectableText(ticket.message, style: recipe.body)),
          if (ticket.status == 'closed') ...[
            SizedBox(height: recipe.gap),
            Text(
              _copy(
                context,
                'This ticket is closed. The team can reopen it if more information is needed.',
                '该工单已关闭。如需更多信息，团队可以重新打开。',
              ),
              style: recipe.meta,
            ),
            if (_reason(context, ticket.closureReason) case final reason?)
              Text(
                _copy(context, 'Closed as $reason', '关闭原因：$reason'),
                style: recipe.meta,
              ),
          ],
          if (store.attachments.isNotEmpty) ...[
            SizedBox(height: recipe.gap),
            Text(_copy(context, 'Attachments', '附件'), style: recipe.title),
            for (final attachment in store.attachments)
              Text(
                '${attachment.filename} · ${attachment.size} B',
                style: recipe.meta,
              ),
          ],
          SizedBox(height: recipe.gap),
          if (store.comments.isEmpty && !store.detailLoading)
            Text(_copy(context, 'No replies yet', '暂无回复'), style: recipe.meta),
          for (final comment in store.comments) ...[
            RaftPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment.authorType == 'reporter'
                        ? _copy(context, 'You', '你')
                        : comment.authorType == 'staff'
                        ? _copy(context, 'Team', '团队')
                        : _copy(context, 'Update', '更新'),
                    style: recipe.title,
                  ),
                  Text(_date(context, comment.createdAt), style: recipe.meta),
                  const SizedBox(height: 4),
                  SelectableText(
                    comment.body,
                    key: ValueKey('feedback-comment-${comment.id}'),
                    style: recipe.body,
                  ),
                ],
              ),
            ),
            SizedBox(height: recipe.gap),
          ],
          if (store.nextCommentCursor != null && !store.detailLoading)
            RaftTextButton(
              label: _copy(context, 'Load more replies', '加载更多回复'),
              onPressed: () => unawaited(store.loadDetail(more: true)),
            ),
        ],
      ],
    );
  }
}
