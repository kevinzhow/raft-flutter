import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:raft_ui/raft_ui.dart';

import 'search_continuation.dart';

/// Web `incompleteSearchNote`: how far back the walk got, or that only part of
/// the messages has been searched. The time reads as Web's `dateStyle:
/// "medium", timeStyle: "short"` in the display language.
String searchIncompleteNote(
  BuildContext context,
  SearchContinuation continuation,
) {
  final through = continuation.searchedThrough;
  if (through == null) {
    return raftText(
      context,
      'Only part of the messages has been searched so far.',
    );
  }
  final zh = Localizations.localeOf(context).languageCode == 'zh';
  final locale = zh ? 'zh_CN' : 'en';
  final local = through.toLocal();
  String time;
  try {
    final date = DateFormat.yMMMd(locale);
    time = zh
        ? '${date.format(local)} ${DateFormat.Hm(locale).format(local)}'
        : '${date.format(local)}, ${DateFormat.jm(locale).format(local)}';
  } catch (_) {
    time = local.toString();
  }
  return raftFormat(
    context,
    'Searched messages back to {time}. Older messages have not been searched yet.',
    {'time': time},
  );
}

/// Pages the results page on a press and reports what became of it, like Web's
/// `loadingMore` / `loadMoreError`: while the next page is in flight the
/// button reads "Loading…" and cannot be pressed again; a failed page keeps the
/// results and shows the warning with Retry. The page reports a failure through
/// its own state, which is read once the frame that carries it is built.
class SearchContinuing extends StatefulWidget {
  const SearchContinuing({
    super.key,
    required this.onMore,
    required this.failure,
    required this.builder,
  });

  /// Reads the next page; completes when the page has accepted or failed it.
  final FutureOr<void> Function() onMore;

  /// The page currently shows a search failure.
  final bool failure;
  final Widget Function(
    BuildContext context,
    bool loading,
    bool failed,
    VoidCallback press,
  )
  builder;

  @override
  State<SearchContinuing> createState() => _SearchContinuingState();
}

class _SearchContinuingState extends State<SearchContinuing> {
  bool loading = false, failed = false;

  Future<void> press() async {
    if (loading) return;
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      await widget.onMore();
    } catch (_) {
      // The page reports its own failure.
    }
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          loading = false;
          failed = widget.failure;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, loading, failed, press);
}

/// Web "Continue searching" / "Load More" button of the results page.
class SearchContinueButton extends StatelessWidget {
  const SearchContinueButton({
    super.key,
    required this.continuing,
    required this.loading,
    required this.onPressed,
  });

  /// The search is incomplete: the label says "Continue searching".
  final bool continuing, loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => RaftRecipeButton(
    label: raftText(
      context,
      loading
          ? 'Loading…'
          : continuing
          ? 'Continue searching'
          : 'Load More',
    ),
    variant: RaftButtonRecipeVariant.outline,
    size: RaftButtonRecipeSize.sm,
    disabled: loading,
    onPressed: onPressed,
  );
}

/// The warning that the next page could not be read, with Retry.
class SearchLoadMoreFailed extends StatelessWidget {
  const SearchLoadMoreFailed({
    super.key,
    required this.loading,
    required this.onRetry,
  });
  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => RaftBanner(
    key: const Key('search-load-more-failed'),
    status: RaftBannerRecipeStatus.warning,
    glyph: RaftGlyph.alertTriangle,
    description: raftText(context, 'Could not load more results.'),
    action: RaftRecipeButton(
      label: raftText(context, loading ? 'Loading…' : 'Retry'),
      variant: RaftButtonRecipeVariant.outline,
      size: RaftButtonRecipeSize.sm,
      disabled: loading,
      onPressed: onRetry,
    ),
  );
}

/// The results page's footer once there is more to read: the incomplete note
/// (while nothing failed), then either the paging button or, after a failed
/// page, the warning with Retry. Both leave the shown results in place.
class SearchContinueFooter extends StatelessWidget {
  const SearchContinueFooter({
    super.key,
    required this.continuation,
    required this.onMore,
    required this.failure,
  });
  final SearchContinuation continuation;
  final FutureOr<void> Function() onMore;
  final bool failure;

  @override
  Widget build(BuildContext context) {
    return SearchContinuing(
      onMore: onMore,
      failure: failure,
      builder: (context, loading, failed, press) => RaftSearchFooter(
        children: [
          if (continuation.pending && !failed)
            RaftSearchNote(
              searchIncompleteNote(context, continuation),
              key: const Key('search-incomplete-note'),
            ),
          if (failed)
            SearchLoadMoreFailed(loading: loading, onRetry: press)
          else
            SearchContinueButton(
              key: const Key('search-continue'),
              continuing: continuation.pending,
              loading: loading,
              onPressed: press,
            ),
        ],
      ),
    );
  }
}

/// Web `AppEmptyState` for a search that read part of the messages and found
/// nothing yet: "No matches yet", how far it got, and the way to go on.
class SearchIncompleteEmpty extends StatelessWidget {
  const SearchIncompleteEmpty({
    super.key,
    required this.continuation,
    required this.onMore,
    required this.failure,
  });
  final SearchContinuation continuation;
  final FutureOr<void> Function() onMore;
  final bool failure;

  @override
  Widget build(BuildContext context) => SearchContinuing(
    onMore: onMore,
    failure: failure,
    builder: (context, loading, failed, press) => RaftSearchEmptyFrame(
      footer: failed
          ? SearchLoadMoreFailed(loading: loading, onRetry: press)
          : null,
      child: RaftProductEmptyState(
        title: raftText(context, 'No matches yet'),
        description: searchIncompleteNote(context, continuation),
        icon: (context, size, color) =>
            RaftIcon(RaftGlyph.search, size: size, color: color),
        action: SearchContinueButton(
          key: const Key('search-continue'),
          continuing: true,
          loading: loading,
          onPressed: press,
        ),
      ),
    ),
  );
}
