import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Search results and task filters')
Widget searchSurfacesPreview() => const _SearchSurfaces();

class _SearchSurfaces extends StatefulWidget {
  const _SearchSurfaces();
  @override
  State<_SearchSurfaces> createState() => _SearchSurfacesState();
}

class _SearchSurfacesState extends State<_SearchSurfaces> {
  bool selected = false;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftSearchResultSurface(
          entity: true,
          selected: selected,
          onPressed: () => setState(() => selected = !selected),
          child: const Text('#design · Channel'),
        ),
        const SizedBox(height: 16),
        RaftSearchResultSurface(
          selected: !selected,
          onPressed: () => setState(() => selected = !selected),
          child: const Row(
            children: [
              RaftThreadIcon(size: 10),
              SizedBox(width: 8),
              Text('A thread message result'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: RaftTaskFilterButton(
            selected: selected,
            onPressed: () => setState(() => selected = !selected),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                RaftIcon(RaftGlyph.hash, size: 14),
                Text('Channel'),
                RaftIcon(RaftGlyph.chevronDown, size: 12),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

@RaftPreviews('Search input focus and clear')
Widget searchInputPreview() => const _SearchInputPreview();

class _SearchInputPreview extends StatefulWidget {
  const _SearchInputPreview();
  @override
  State<_SearchInputPreview> createState() => _SearchInputPreviewState();
}

class _SearchInputPreviewState extends State<_SearchInputPreview> {
  final controller = TextEditingController(text: 'android');
  final focus = FocusNode();
  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        RaftSearchInput(
          controller: controller,
          focusNode: focus,
          hint: 'Search messages',
          clearLabel: 'Clear search',
          showEscape: true,
          onClear: controller.clear,
        ),
      ],
    ),
  );
}

@RaftPreviews('Task document typography and inline status')
Widget taskDocumentPreview() => const _TaskDocumentPreview();

class _TaskDocumentPreview extends StatefulWidget {
  const _TaskDocumentPreview();
  @override
  State<_TaskDocumentPreview> createState() => _TaskDocumentPreviewState();
}

class _TaskDocumentPreviewState extends State<_TaskDocumentPreview> {
  String status = 'todo';
  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    style: RaftTaskSectionRecipe(RaftTokens.of(context)).documentStyle,
    child: RaftTaskCard(
      title: 'Review the thread header strip baselines',
      number: '210',
      channel: 'design',
      description: 'Source task description',
      status: status,
      onTap: () {},
      statusOptions: const ['todo', 'in_progress', 'done'],
      onStatus: (value) => setState(() => status = value),
    ),
  );
}
