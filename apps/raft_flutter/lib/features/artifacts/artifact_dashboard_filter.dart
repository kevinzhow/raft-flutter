import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'artifact_dashboard_data.dart';

Future<ArtifactDashboardPlace?> showArtifactDashboardFilter(
  BuildContext context,
  ArtifactDashboardApi api, {
  required bool authors,
  String? selected,
}) => showRaftDialog<ArtifactDashboardPlace>(
  context: context,
  builder: (_) =>
      ArtifactDashboardFilter(api: api, authors: authors, selected: selected),
);

class ArtifactDashboardFilter extends StatefulWidget {
  const ArtifactDashboardFilter({
    super.key,
    required this.api,
    required this.authors,
    this.selected,
  });

  final ArtifactDashboardApi api;
  final bool authors;
  final String? selected;

  @override
  State<ArtifactDashboardFilter> createState() =>
      _ArtifactDashboardFilterState();
}

class _ArtifactDashboardFilterState extends State<ArtifactDashboardFilter> {
  final controller = TextEditingController();
  final focus = FocusNode();
  Timer? debounce;
  int attempt = 0;
  List<ArtifactDashboardChoice>? choices;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(read());
  }

  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> read() async {
    debounce?.cancel();
    final current = ++attempt;
    setState(() {
      choices = null;
      failed = false;
    });
    try {
      final next = await widget.api.choices(
        controller.text.trim(),
        authors: widget.authors,
      );
      if (mounted && current == attempt) setState(() => choices = next);
    } catch (_) {
      if (mounted && current == attempt) setState(() => failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    String text(String value) => raftText(context, value);
    final authors = widget.authors;
    final emptySearch = controller.text.trim().isEmpty;
    final rows = <ArtifactDashboardPlace>[
      if (widget.selected != null)
        (
          id: '',
          label: text(authors ? 'Clear author' : 'Clear conversation'),
          home: false,
        ),
      if (!authors && emptySearch) ...[
        (id: 'public', label: text('Anyone with the link'), home: true),
        (id: 'server', label: text('Everyone in this server'), home: true),
      ],
      for (final item in choices ?? const <ArtifactDashboardChoice>[])
        (id: item.id, label: item.label, home: false),
    ];
    return RaftDialog(
      contentKey: const Key('artifact-dashboard-filter'),
      title: Text(text(authors ? 'Author' : 'By conversation')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftSearchInput(
            controller: controller,
            focusNode: focus,
            hint: text(
              authors ? 'Search people or agents' : 'Search channels and DMs',
            ),
            clearLabel: text('Clear search'),
            onClear: () {
              controller.clear();
              unawaited(read());
            },
            onChanged: (_) {
              ++attempt;
              debounce?.cancel();
              debounce = Timer(
                const Duration(milliseconds: 300),
                () => unawaited(read()),
              );
            },
          ),
          if (failed)
            RaftButton(label: text('Try again'), onPressed: read)
          else if (choices == null)
            const RaftListRowSkeleton()
          else if (rows.isEmpty)
            Text(text(authors ? 'No one found' : 'No conversations found')),
          for (final row in rows)
            RaftListRow(
              selected: row.id == widget.selected,
              onPressed: () => Navigator.of(context).pop(row),
              children: [Expanded(child: RaftListRowTitle(row.label))],
            ),
        ],
      ),
    );
  }
}
