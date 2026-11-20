import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'management_support.dart';

class ConnectedAppMarketplace {
  static const path = '/integrations/marketplace/listings';

  final rows = <String, Map<String, dynamic>>{};
  int total = 0;
  String? cursor;
  bool loading = false, failed = false, legacy = false, loaded = false;
  int _request = 0;

  void clear() {
    _request++;
    rows.clear();
    total = 0;
    cursor = null;
    loading = failed = legacy = loaded = false;
  }

  Future<void> fetch(
    RaftClient client,
    Map<String, dynamic> filters, {
    required bool Function() isCurrent,
    bool next = false,
  }) async {
    final after = next ? cursor : null;
    if (next && (loading || after == null)) return;
    final ticket = ++_request;
    loading = true;
    failed = false;
    bool current() => ticket == _request && isCurrent();
    try {
      final result = await client.get(
        path,
        query: {...filters, 'cursor': ?after},
      );
      if (!current()) return;
      if (result is! Map || result['items'] is! List) {
        throw const FormatException('Invalid marketplace page');
      }
      if (!next) rows.clear();
      for (final row in managementRows(result['items'])) {
        final id = row['id'];
        if (id is String) rows.putIfAbsent(id, () => row);
      }
      cursor = result['nextCursor'] as String?;
      total = result['total'] as int? ?? rows.length;
      loaded = true;
      legacy = false;
    } on RaftApiException catch (failure) {
      if (!current()) return;
      if (next && failure.details['code'] == 'INVALID_CURSOR') {
        await fetch(client, filters, isCurrent: isCurrent);
      } else if (!next && failure.status == 404) {
        legacy = loaded = true;
      } else {
        failed = true;
      }
    } on FormatException {
      if (current()) failed = true;
    } finally {
      if (current()) loading = false;
    }
  }
}

class ConnectedAppMarketplaceFooter extends StatelessWidget {
  const ConnectedAppMarketplaceFooter({
    super.key,
    required this.page,
    required this.retry,
    required this.loadMore,
  });

  final ConnectedAppMarketplace page;
  final VoidCallback retry, loadMore;

  @override
  Widget build(BuildContext context) {
    String tr(String text) => raftText(context, text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x2,
      children: [
        if (page.failed)
          RaftConnectedAppsError(
            tr(
              page.loaded
                  ? "Couldn't load more apps."
                  : "Couldn't load the Marketplace.",
            ),
          ),
        if (page.loading || page.loaded || page.failed)
          Center(
            child: Wrap(
              spacing: RaftSpace.x3,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (page.loaded && page.rows.isNotEmpty)
                  Text(
                    raftFormat(context, 'Showing {shown} / {total}', {
                      'shown': page.rows.length,
                      'total': page.total,
                    }),
                  ),
                if (page.loading && !page.loaded)
                  const RaftSpinner(size: 16)
                else if (page.cursor != null || page.failed)
                  RaftConnectedAppButton(
                    label: tr(
                      page.loading
                          ? 'Loading…'
                          : page.cursor != null
                          ? 'Load more'
                          : 'Retry',
                    ),
                    onPressed: page.loading
                        ? null
                        : page.cursor != null
                        ? loadMore
                        : retry,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
