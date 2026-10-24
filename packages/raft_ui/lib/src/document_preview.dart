import 'package:flutter/material.dart';

import 'raft_selection_area.dart';

import 'localization.dart';
import 'lazy_markdown_document.dart';
import 'attachment_comment_scope.dart';
import 'document_anchors.dart';
import 'markdown_outline.dart';
import 'message_body.dart';
import 'design_primitives.dart';
import 'message_content_tokens.dart';
import 'text_measure.dart';
import 'theme.dart';

/// Markdown longer than this many characters is laid out as a lazy list of
/// blocks (only the blocks near the viewport are built, parsed off the UI
/// isolate), not one column. Server previews are capped at 64 KB; a 40 KB
/// document in one column took ~100 ms of build and layout on every open,
/// while below this size the single column fits in a frame.
const raftLazyMarkdownChars = 4 * 1024;

/// Plain text with more lines than this is a lazy list of lines.
const raftLazyTextLines = 1000;

/// A CSV with more rows than this is a lazy list of fixed-height rows (the
/// server sends at most 200; local rendering of a large file can hold many
/// thousands, and a `Table` lays out every cell).
const raftLazyCsvRows = 200;

/// Structured, server-bounded attachment content. Never executes document HTML.
///
/// Web `AttachmentPreviewShell` panes: `TextPreviewPane`, `CsvPreviewPane`,
/// `XlsxPreviewPane` and `MarkdownPreviewPane`, each on the shell's canvas
/// surface (`bg-layer-canvas-muted`, brutal `bg-brutal-cream/45`).
class RaftDocumentPreview extends StatefulWidget {
  const RaftDocumentPreview({
    super.key,
    required this.data,
    this.truncated = false,
    @visibleForTesting this.lazyMarkdownChars = raftLazyMarkdownChars,
  });
  final Map<String, dynamic> data;
  final int lazyMarkdownChars;
  final bool truncated;
  @override
  State<RaftDocumentPreview> createState() => _RaftDocumentPreviewState();
}

class _RaftDocumentPreviewState extends State<RaftDocumentPreview> {
  int sheet = 0;

  // Markdown outline: the document scrolls through [markdownScroll] and its
  // headings are found inside [markdownBody] (Web `MarkdownOutlineNav` links).
  final markdownScroll = ScrollController();

  // Long text and CSV are lazy lists; a comment anchor's jump scrolls them.
  final lazyTextScroll = ScrollController(), lazyCsvScroll = ScrollController();
  double lazyCsvRowHeight = 0;
  final markdownBody = GlobalKey();
  final lazyMarkdown = RaftLazyMarkdownHandle();
  String? _outlineSource;
  List<RaftMarkdownOutlineItem> _outline = const [];

  List<RaftMarkdownOutlineItem> outlineOf(String source) {
    if (_outlineSource != source) {
      _outline = raftExtractMarkdownOutline(source);
      _outlineSource = source;
    }
    return _outline;
  }

  @override
  void dispose() {
    markdownScroll.dispose();
    lazyTextScroll.dispose();
    lazyCsvScroll.dispose();
    super.dispose();
  }

  Future<void> revealHeading(RaftMarkdownOutlineItem item) async {
    // A long document builds only the blocks near the viewport: build them
    // all so the heading is laid out, then find it.
    await lazyMarkdown.expandAll?.call();
    await WidgetsBinding.instance.endOfFrame;
    final root = markdownBody.currentContext?.findRenderObject();
    if (!mounted || root == null || !markdownScroll.hasClients) return;
    final paragraph = raftFindHeadingParagraph(
      root,
      item,
      raftHeadingOccurrence(_outline, item),
    );
    if (paragraph != null) {
      raftScrollToParagraph(markdownScroll.position, paragraph);
    }
  }

  /// Web `MarkdownPreviewPane` at `xl`: the outline column beside the document.
  Widget withOutline(
    BuildContext context,
    List<RaftMarkdownOutlineItem> outline,
    Widget document,
    double top,
  ) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1152),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: raftMarkdownOutlineWidth,
            child: ListenableBuilder(
              listenable: markdownScroll,
              builder: (context, _) {
                // Sticky: level with the first block, then 24px under the top.
                final scrolled = markdownScroll.hasClients
                    ? markdownScroll.offset
                    : 0.0;
                return SingleChildScrollView(
                  padding: EdgeInsets.only(
                    top: (top - scrolled).clamp(24.0, top),
                    bottom: 24,
                  ),
                  child: RaftMarkdownOutlineNav(
                    outline: outline,
                    onSelect: (item) => revealHeading(item),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 24),
          Expanded(child: document),
        ],
      ),
    ),
  );

  // The lazy text layout splits its source once per content, not per build.
  String? _linesSource;
  List<String> _lines = const [];

  List<String> linesOf(String source) {
    if (!identical(_linesSource, source)) {
      final lines = source.split(RegExp(r'\r?\n'));
      // A closing newline does not start another line.
      if (lines.length > 1 && lines.last.isEmpty) lines.removeLast();
      _lines = lines;
      _linesSource = source;
    }
    return _lines;
  }

  static String plural(int count, String one, String other) =>
      '$count ${count == 1 ? one : other}';

  /// CSS `table-layout: auto` with `min-w-full`: each column takes its
  /// max-content width (capped by the cell's `max-w-[220px]`), and any width
  /// the container has beyond their sum is shared in proportion to them.
  static Map<int, TableColumnWidth> _columnWidths(
    BuildContext context,
    DocumentAttachmentRecipe recipe,
    List<String> headers,
    List<List> rows,
    double available,
  ) {
    double measure(String text, TextStyle style) =>
        raftTextWidth(TextSpan(text: text, style: style), maxLines: 1);
    final inset = recipe.cellInset.horizontal;
    final bold = recipe.tableText.copyWith(fontWeight: FontWeight.w700);
    final intrinsic = <double>[
      for (var i = 0; i < headers.length; i++)
        () {
          var width = measure(headers[i], bold);
          for (final row in rows) {
            if (i < row.length) {
              width = width > measure('${row[i]}', recipe.tableText)
                  ? width
                  : measure('${row[i]}', recipe.tableText);
            }
          }
          return (width.ceilToDouble() < recipe.maxColumnWidth
                  ? width.ceilToDouble()
                  : recipe.maxColumnWidth) +
              inset +
              1;
        }(),
    ];
    final total = intrinsic.fold<double>(0, (a, b) => a + b);
    final grow = available > total + 1 ? available / (total + 1) : 1.0;
    return {
      for (var i = 0; i < intrinsic.length; i++)
        i: FixedColumnWidth(intrinsic[i] * grow),
    };
  }

  /// A long text file: a lazy list of lines inside the usual bordered box.
  Widget _lazyText(
    BuildContext context,
    DocumentAttachmentRecipe recipe,
    TextStyle label,
    List<String> lines,
    bool truncated,
    List<BoxShadow> shadow,
  ) => ColoredBox(
    color: recipe.background,
    child: Padding(
      padding: recipe.inset,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(raftText(context, 'Plain text preview'), style: label),
                if (truncated)
                  Text(raftText(context, 'Truncated'), style: label),
              ],
            ),
          ),
          Expanded(
            child: Container(
   clipBehavior: Clip.antiAlias,
   decoration: BoxDecoration(
     borderRadius: recipe.radius,
                color: recipe.paper,
                border: Border.fromBorderSide(recipe.border),
                boxShadow: shadow,
              ),
              child: RaftSelectionArea(
                child: ListView.builder(
                  key: const ValueKey('lazy-text-lines'),
                  controller: lazyTextScroll,
                  padding: recipe.textInset,
                  itemCount: lines.length,
                  itemBuilder: (_, index) => RaftAnchorRow(
                    kind: 'lines',
                    number: index + 1,
                    text: lines[index],
                    child: Text(
                      lines[index].isEmpty ? ' ' : lines[index],
                      style: recipe.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  /// A long CSV: fixed-height rows in a lazy list under a pinned header row.
  /// Column widths come from the first rows (the widest cell of the sample,
  /// capped like the table's), so the grid does not shift while scrolling.
  Widget _lazyCsv(
    BuildContext context,
    DocumentAttachmentRecipe recipe,
    TextStyle label,
    List<BoxShadow> shadow, {
    required List<String> headers,
    required List<List> rows,
    required String summary,
    required String footer,
  }) {
    final t = RaftTokens.of(context);
    final rowHeight =
        recipe.tableText.fontSize! * (recipe.tableText.height ?? 1.5) +
        recipe.cellInset.vertical +
        1;
    lazyCsvRowHeight = rowHeight;
    return ColoredBox(
      color: recipe.background,
      child: Padding(
        padding: recipe.inset,
        child: LayoutBuilder(
          builder: (context, bounds) {
            final widths = _columnWidths(
              context,
              recipe,
              headers,
              rows.take(raftLazyCsvRows).toList(),
              bounds.maxWidth - recipe.border.width * 2 - 2,
            );
            final sizes = [
              for (final width in widths.values)
                (width as FixedColumnWidth).value,
            ];
            final total = sizes.fold<double>(0, (a, b) => a + b);
            Widget cells(List cells, TextStyle style, Color? stripe) =>
                SizedBox(
                  height: rowHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: stripe,
                      border: Border(bottom: recipe.cellBorder),
                    ),
                    child: Row(
                      children: [
                        for (var i = 0; i < sizes.length; i++)
                          SizedBox(
                            width: sizes[i],
                            child: Padding(
                              padding: recipe.cellInset.copyWith(
                                top: 0,
                                bottom: 0,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  i < cells.length ? '${cells[i]}' : '',
                                  style: style,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
            return DefaultTextStyle.merge(
              style: recipe.tableText,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      runSpacing: 12,
                      children: [
                        Text(
                          raftText(context, 'CSV data preview'),
                          style: label.copyWith(fontFamily: t.monoFont),
                        ),
                        Text(
                          summary,
                          style: label.copyWith(fontFamily: t.monoFont),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
   clipBehavior: Clip.antiAlias,
   decoration: BoxDecoration(
     borderRadius: recipe.radius,
                        color: recipe.paper,
                        border: Border.fromBorderSide(recipe.border),
                        boxShadow: shadow,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: total > bounds.maxWidth - 2
                              ? total
                              : bounds.maxWidth - recipe.border.width * 2,
                          child: Column(
                            children: [
                              cells(
                                [
                                  for (var i = 0; i < headers.length; i++)
                                    headers[i].isEmpty
                                        ? raftFormat(
                                            context,
                                            'Column {index}',
                                            {'index': i + 1},
                                          )
                                        : headers[i],
                                ],
                                recipe.tableText.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: t.strong,
                                ),
                                recipe.tableHeader,
                              ),
                              Expanded(
                                child: ListView.builder(
                                  key: const ValueKey('lazy-csv-rows'),
                                  controller: lazyCsvScroll,
                                  itemExtent: rowHeight,
                                  itemCount: rows.length,
                                  itemBuilder: (_, index) => RaftAnchorRow(
                                    kind: 'csv-rows',
                                    number: index + 1,
                                    text: rows[index].join('\t'),
                                    child: cells(
                                      rows[index],
                                      recipe.tableText,
                                      index.isEven ? recipe.rowStripe : null,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(footer, style: label),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final kind = data['kind'];
    // Web `data-anchor-line` / `data-anchor-row`: a comment session can anchor
    // to (and jump to) the numbered lines and rows of text, CSV and XLSX.
    final sheets = (data['sheets'] as List? ?? []).whereType<Map>().toList();
    final selected = sheets.isEmpty
        ? data
        : sheets[sheet.clamp(0, sheets.length - 1)];
    final tabular = kind == 'csv' || kind == 'xlsx';
    final lineCount = kind == 'markdown' || tabular
        ? 0
        : linesOf('${data['text'] ?? ''}').length;
    final rowCount = tabular ? (selected['rows'] as List? ?? []).length : 0;
    return RaftDocumentAnchorHost(
      totals: {'lines': lineCount, 'csv-rows': rowCount},
      scrollNear: scrollLazyNear,
      child: buildPane(context),
    );
  }

  /// A jump to a row the lazy list has not built: scroll close to it (the
  /// host then finds the row and refines).
  void scrollLazyNear(String kind, int number) {
    final controller = kind == 'lines' ? lazyTextScroll : lazyCsvScroll;
    if (!controller.hasClients) return;
    final extent = kind == 'lines'
        ? (DocumentAttachmentRecipe(RaftTokens.of(context)).text.fontSize ??
                  12) *
              (DocumentAttachmentRecipe(RaftTokens.of(context)).text.height ??
                  1.6)
        : lazyCsvRowHeight;
    final target = ((number - 1) * extent).clamp(
      0.0,
      controller.position.maxScrollExtent,
    );
    controller.jumpTo(target);
  }

  Widget buildPane(BuildContext context) {
    final data = widget.data;
    final t = RaftTokens.of(context);
    final recipe = DocumentAttachmentRecipe(t);
    final sheets = (data['sheets'] as List? ?? []).whereType<Map>().toList();
    final selected = sheets.isEmpty
        ? data
        : sheets[sheet.clamp(0, sheets.length - 1)];
    final kind = data['kind'];
    final tabular = ['csv', 'xlsx'].contains(kind);
    final headers = (selected['headers'] as List? ?? [])
        .map((v) => '$v')
        .toList();
    final rows = (selected['rows'] as List? ?? []).whereType<List>().toList();
    final truncated =
        widget.truncated ||
        data['truncated'] == true ||
        selected['truncated'] == true;
    final label = TextStyle(
      fontFamily: t.headingFont,
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w700,
      color: t.muted,
    );
    // `shadow-raft-sm theme-brutal:shadow-brutal-sm`
    final shadow = t.themeShadows.sm.outer;
    Widget pane(Widget child) => ColoredBox(
      color: kind == 'markdown' ? recipe.background : recipe.background,
      child: SingleChildScrollView(
        child: Padding(padding: recipe.inset, child: child),
      ),
    );
    final markdownSource = '${data['markdown'] ?? ''}';
    final outline = kind == 'markdown'
        ? outlineOf(markdownSource)
        : const <RaftMarkdownOutlineItem>[];
    final showOutline =
        outline.isNotEmpty &&
        MediaQuery.sizeOf(context).width >= raftMarkdownOutlineBreakpoint;
    if (kind == 'markdown' &&
        markdownSource.length > widget.lazyMarkdownChars) {
      final lazy = RaftLazyMarkdownDocument(
        key: markdownBody,
        source: markdownSource,
        recipe: recipe,
        truncated: truncated,
        shadow: shadow,
        controller: markdownScroll,
        handle: lazyMarkdown,
      );
      return showOutline
          ? ColoredBox(
              color: recipe.background,
              child: withOutline(
                context,
                outline,
                lazy,
                recipe.markdownInset(MediaQuery.sizeOf(context).width).top,
              ),
            )
          : lazy;
    }
    if (kind == 'markdown') {
      final width = MediaQuery.sizeOf(context).width;
      final document = ColoredBox(
        color: recipe.background,
        child: SingleChildScrollView(
          controller: markdownScroll,
          child: Padding(
            key: markdownBody,
            padding: recipe.markdownInset(width),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (truncated)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      raftText(
                        context,
                        'Preview truncated. Download the full file.',
                      ),
                    ),
                  ),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: recipe.radius,
                    color: recipe.paper,
                    border: Border.fromBorderSide(recipe.border),
                    boxShadow: shadow,
                  ),
                  child: Padding(
                    padding: width >= 768
                        ? const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 48,
                          )
                        : const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 32,
                          ),
                    child: RaftMessageBody(
                      content: '${data['markdown'] ?? ''}',
                      fontSize: 16,
                      documentMode: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return showOutline
          ? ColoredBox(
              color: recipe.background,
              child: withOutline(
                context,
                outline,
                document,
                recipe.markdownInset(width).top,
              ),
            )
          : document;
    }
    if (!tabular && '${data['text'] ?? ''}'.length > raftLazyTextLines) {
      final lines = linesOf('${data['text']}');
      if (lines.length > raftLazyTextLines) {
        return _lazyText(context, recipe, label, lines, truncated, shadow);
      }
    }
    if (!tabular) {
      // `TextPreviewPane`: label row, then a bordered `<pre>` of per-line rows.
      final lines = '${data['text'] ?? ''}'.split(RegExp(r'\r?\n'));
      return pane(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(raftText(context, 'Plain text preview'), style: label),
                  if (truncated)
                    Text(raftText(context, 'Truncated'), style: label),
                ],
              ),
            ),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: recipe.radius,
                color: recipe.paper,
                border: Border.fromBorderSide(recipe.border),
                boxShadow: shadow,
              ),
              child: Padding(
                padding: recipe.textInset,
                // Comment mode numbers the lines (Web `data-anchor-line`
                // rows); otherwise the text is one selectable block.
                child:
                    RaftAttachmentCommentScope.maybeOf(context)?.commentMode ==
                        true
                    ? RaftSelectionArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < lines.length; i++)
                              RaftAnchorRow(
                                kind: 'lines',
                                number: i + 1,
                                text: lines[i],
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    lines[i].isEmpty ? ' ' : lines[i],
                                    style: recipe.text,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    : SelectableText(
                        lines
                            .map((line) => line.isEmpty ? ' ' : line)
                            .join('\n'),
                        style: recipe.text,
                      ),
              ),
            ),
          ],
        ),
      );
    }
    // CSV / XLSX: label row, optional sheet tabs, bordered table, footer.
    final isXlsx = kind == 'xlsx';
    final rowCount = (selected['rowCount'] as num?)?.toInt() ?? rows.length;
    final columnCount =
        (selected['columnCount'] as num?)?.toInt() ?? headers.length;
    final empty = headers.isEmpty && rows.isEmpty;
    final footer = isXlsx
        ? (truncated
              ? raftFormat(
                  context,
                  'Preview truncated for performance. Showing the first {count} rows of this sheet.',
                  {'count': rows.length},
                )
              : raftFormat(context, 'Showing {shown} of {total} rows', {
                  'shown': rows.length,
                  'total': rowCount,
                }))
        : (truncated
              ? raftFormat(
                  context,
                  'Preview truncated for performance. Showing first {count} rows from the file prefix.',
                  {'count': rows.length},
                )
              : raftFormat(context, 'Showing {shown} of {total} rows', {
                  'shown': rows.length,
                  'total': rowCount,
                }));
    final summary = isXlsx
        ? plural(
            (data['sheetCount'] as num?)?.toInt() ?? sheets.length,
            'sheet',
            'sheets',
          )
        : '${truncated ? raftFormat(context, 'First {count} rows', {'count': rows.length}) : plural(rowCount, 'row', 'rows')} · ${plural(columnCount, 'column', 'columns')}';
    if (!isXlsx && rows.length > raftLazyCsvRows && headers.isNotEmpty) {
      return _lazyCsv(
        context,
        recipe,
        label,
        shadow,
        headers: headers,
        rows: rows,
        summary: summary,
        footer: footer,
      );
    }
    return pane(
      DefaultTextStyle.merge(
        style: recipe.tableText,
        child: LayoutBuilder(
          builder: (context, bounds) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: isXlsx ? 12 : 8),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      raftText(
                        context,
                        isXlsx ? 'XLSX data preview' : 'CSV data preview',
                      ),
                      style: label.copyWith(fontFamily: t.monoFont),
                    ),
                    Text(
                      summary,
                      style: label.copyWith(fontFamily: t.monoFont),
                    ),
                  ],
                ),
              ),
              if (isXlsx && sheets.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    children: [
                      for (var i = 0; i < sheets.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: RaftControl(
                            kind: RaftControlKind.tab,
                            selected: sheet == i,
                            shadow: false,
                            semanticLabel: '${sheets[i]['name'] ?? ''}',
                            onPressed: () => setState(() => sheet = i),
                            child: Text('${sheets[i]['name'] ?? ''}'),
                          ),
                        ),
                    ],
                  ),
                ),
              if (empty)
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: recipe.radius,
                    color: recipe.paper,
                    border: Border.fromBorderSide(recipe.border),
                    boxShadow: shadow,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      raftText(context, 'This spreadsheet is empty.'),
                      style: TextStyle(
                        fontFamily: t.headingFont,
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w700,
                        color: t.strong,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: recipe.radius,
                    color: recipe.paper,
                    border: Border.fromBorderSide(recipe.border),
                    boxShadow: shadow,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: bounds.maxWidth - recipe.border.width * 2,
                      ),
                      child: DecoratedBox(
                        // The collapsed table's own outer border sits just
                        // inside the box's border.
                        decoration: BoxDecoration(
                          border: Border.fromBorderSide(recipe.cellBorder),
                        ),
                        child: Table(
                          columnWidths: _columnWidths(
                            context,
                            recipe,
                            headers,
                            rows,
                            bounds.maxWidth - recipe.border.width * 2 - 2,
                          ),
                          border: TableBorder(
                            horizontalInside: recipe.cellBorder,
                            verticalInside: recipe.cellBorder,
                          ),
                          children: [
                            if (headers.isNotEmpty)
                              TableRow(
                                decoration: BoxDecoration(
                                  color: recipe.tableHeader,
                                ),
                                children: [
                                  for (var i = 0; i < headers.length; i++)
                                    Padding(
                                      padding: recipe.cellInset,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: recipe.maxColumnWidth,
                                        ),
                                        child: Text(
                                          headers[i].isEmpty
                                              ? raftFormat(
                                                  context,
                                                  'Column {index}',
                                                  {'index': i + 1},
                                                )
                                              : headers[i],
                                          style: recipe.tableText.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: t.strong,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            for (
                              var rowIndex = 0;
                              rowIndex < rows.length;
                              rowIndex++
                            )
                              if (headers.isNotEmpty)
                                TableRow(
                                  // `odd:bg-black/[0.03]`: the 1st, 3rd, ... row.
                                  decoration: BoxDecoration(
                                    color: rowIndex.isEven
                                        ? recipe.rowStripe
                                        : null,
                                  ),
                                  children: [
                                    for (var i = 0; i < headers.length; i++)
                                      RaftAnchorRow(
                                        kind: 'csv-rows',
                                        number: rowIndex + 1,
                                        text: rows[rowIndex].join('\t'),
                                        child: Padding(
                                          padding: recipe.cellInset,
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth: recipe.maxColumnWidth,
                                            ),
                                            child: Semantics(
                                              label: i < rows[rowIndex].length
                                                  ? '${rows[rowIndex][i]}'
                                                  : '',
                                              excludeSemantics: true,
                                              child: SelectableText(
                                                i < rows[rowIndex].length
                                                    ? '${rows[rowIndex][i]}'
                                                    : '',
                                                style: recipe.tableText,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (!empty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(footer, style: label),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
