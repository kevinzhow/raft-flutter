import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show
        ClearSelectionEvent,
        ScrollCacheExtent,
        SelectAllSelectionEvent,
        SelectionEvent,
        SelectionResult;
import 'package:flutter/scheduler.dart';

import 'localization.dart';
import 'markdown_blocks.dart';
import 'message_body.dart';
import 'message_content_tokens.dart';
import 'raft_selection_area.dart';

/// A long Markdown document cut into blocks that render on their own, with
/// everything [RaftMessageBody] would otherwise derive for each block.
class RaftParsedMarkdown {
  const RaftParsedMarkdown(this.blocks, this.bodies);
  final List<String> blocks;
  final List<RaftPreparedBody> bodies;
}

/// Roughly how many characters one block holds. A block is the unit of
/// build and layout, so a few screenfuls of text keep one frame cheap.
const raftLazyMarkdownBlockChars = 2500;

/// Splits and parses a document. Pure and top-level so it can run in an
/// isolate: on the UI isolate it is a few milliseconds per 10 KB.
RaftParsedMarkdown raftParseMarkdownDocument(String source) {
  final blocks = raftSplitMarkdownBlocks(
    source,
    target: raftLazyMarkdownBlockChars,
  );
  return RaftParsedMarkdown(blocks, [
    for (final block in blocks) raftPrepareBody(block),
  ]);
}

/// How a large document is parsed. The default does it off the UI isolate;
/// tests replace it to observe or control the hand-off.
@visibleForTesting
Future<RaftParsedMarkdown> Function(String source) raftMarkdownDocumentParser =
    (source) => compute(raftParseMarkdownDocument, source);

/// Parsed documents by content, so reopening one (or coming back to it) does
/// not parse again.
final _parsedDocuments = <String, RaftParsedMarkdown>{};
const _parsedDocumentsKept = 4;

@visibleForTesting
void clearParsedMarkdownDocuments() => _parsedDocuments.clear();

/// Lets the owner of a [RaftLazyMarkdownDocument] ask it to build every block
/// (the outline reveals a heading that may sit in a block not built yet).
class RaftLazyMarkdownHandle {
  /// Set while a document is mounted; completes once every block is built.
  Future<void> Function()? expandAll;
}

/// A long Markdown document as a lazily built list of blocks on one paper
/// sheet (borders on the sides, top of the first block and bottom of the
/// last). Only the blocks near the viewport are built and laid out, and the
/// parse runs off the UI isolate.
class RaftLazyMarkdownDocument extends StatefulWidget {
  const RaftLazyMarkdownDocument({
    super.key,
    required this.source,
    required this.recipe,
    required this.truncated,
    required this.shadow,
    this.controller,
    this.handle,
  });
  final String source;

  /// The list's scroll controller, for the owner's outline navigation.
  final ScrollController? controller;
  final RaftLazyMarkdownHandle? handle;
  final DocumentAttachmentRecipe recipe;
  final bool truncated;
  final List<BoxShadow> shadow;

  @override
  State<RaftLazyMarkdownDocument> createState() =>
      _RaftLazyMarkdownDocumentState();
}

/// A cache extent that reaches every block of a document (previews are at
/// most 64 KB, about 40 000 px). Finite: an infinite one gives the semantics
/// tree a non-finite rect.
const _wholeDocument = 200000.0;

/// The space between two blocks' text (each block is its own paper slice).
const _blockGap = 16.0;

/// The first block of [source], cut by the same rule as the full split, so a
/// document shows its beginning on the very first frame while the rest is
/// parsed elsewhere. A prefix that ends mid-construct is never shown: the
/// split of a prefix is only trusted up to its first cut.
String firstMarkdownBlock(String source) {
  var length = raftLazyMarkdownBlockChars * 2;
  while (true) {
    if (length >= source.length) {
      return raftSplitMarkdownBlocks(
        source,
        target: raftLazyMarkdownBlockChars,
      ).first;
    }
    final blocks = raftSplitMarkdownBlocks(
      source.substring(0, length),
      target: raftLazyMarkdownBlockChars,
    );
    if (blocks.length > 1) return blocks.first;
    length *= 2;
  }
}

class _RaftLazyMarkdownDocumentState extends State<RaftLazyMarkdownDocument> {
  RaftParsedMarkdown? parsed;

  /// Until the parse arrives: the document's first block, built in place.
  String? firstBlock;

  /// Select All was asked for: every block is built so the selection covers
  /// the whole document (as the single column did), until it is cleared.
  var expanded = false, selectAllPending = false;

  /// An outline jump built every block: they stay built (a selection being
  /// cleared must not drop the heading the reader is looking at).
  var pinned = false;
  BuildContext? insideArea;

  @override
  void initState() {
    super.initState();
    widget.handle?.expandAll = expandAll;
    load();
  }

  @override
  void didUpdateWidget(RaftLazyMarkdownDocument old) {
    super.didUpdateWidget(old);
    if (!identical(old.handle, widget.handle)) {
      old.handle?.expandAll = null;
      widget.handle?.expandAll = expandAll;
    }
    if (old.source != widget.source) load();
  }

  @override
  void dispose() {
    widget.handle?.expandAll = null;
    super.dispose();
  }

  /// Builds every block (as Select All does) and waits for the frames that
  /// lay them out. They stay built from then on ([pinned]).
  Future<void> expandAll() async {
    // The blocks come from the off-thread parse; until it lands only the
    // first block exists.
    for (var frames = 0; mounted && parsed == null && frames < 300; frames++) {
      await SchedulerBinding.instance.endOfFrame;
    }
    pinned = true;
    if (!expanded && mounted) setState(() => expanded = true);
    await SchedulerBinding.instance.endOfFrame;
    await SchedulerBinding.instance.endOfFrame;
  }

  void adopt(String source, RaftParsedMarkdown value) {
    for (var i = 0; i < value.blocks.length; i++) {
      raftAdoptPreparedBody(value.blocks[i], value.bodies[i]);
    }
    _parsedDocuments.remove(source);
    _parsedDocuments[source] = value;
    if (_parsedDocuments.length > _parsedDocumentsKept) {
      _parsedDocuments.remove(_parsedDocuments.keys.first);
    }
  }

  void load() {
    final source = widget.source;
    final known = _parsedDocuments[source];
    if (known != null) {
      adopt(source, known);
      parsed = known;
      firstBlock = null;
      return;
    }
    parsed = null;
    firstBlock = firstMarkdownBlock(source);
    raftMarkdownDocumentParser(source).then(
      (value) {
        if (!mounted || widget.source != source) return;
        adopt(source, value);
        setState(() {
          parsed = value;
          firstBlock = null;
        });
      },
      onError: (Object error, StackTrace stack) {
        // A worker that cannot start must not leave the document blank.
        if (!mounted || widget.source != source) return;
        final value = raftParseMarkdownDocument(source);
        adopt(source, value);
        setState(() {
          parsed = value;
          firstBlock = null;
        });
      },
    );
  }

  /// A Select All reaches the sheet: build every block, then select again
  /// once the new blocks have registered with the selection area.
  void selectAllBlocks() {
    if (expanded) return;
    selectAllPending = true;
    setState(() => expanded = true);
    void select() {
      final region = insideArea
          ?.findAncestorStateOfType<SelectableRegionState>();
      if (!mounted || region == null) return;
      region.selectAll(SelectionChangedCause.toolbar);
    }

    // The new blocks register with the area through containers that each
    // update after a frame; the whole chain takes three, so wait four.
    void after(int frames) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (frames > 1) {
          after(frames - 1);
        } else {
          select();
        }
      });
      // ignore: raft_lints/avoid_unreviewed_idle_work -- four frames, once per user Select All; ends in select()
      SchedulerBinding.instance.scheduleFrame();
    }

    after(4);
  }

  /// The selection was cleared: lazy again.
  void selectionCleared() {
    if (!expanded || selectAllPending || pinned) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && expanded && !selectAllPending) {
        setState(() => expanded = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final complete = parsed != null;
    final blocks = parsed?.blocks ?? [firstBlock!];
    final truncated = widget.truncated;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 768;
    final edge = wide ? 40.0 : 24.0, vertical = wide ? 48.0 : 32.0;
    final side = recipe.border;
    final notice = truncated ? 1 : 0;
    return ColoredBox(
      color: recipe.background,
      // One selection region for the whole sheet, like the single column.
      child: RaftSelectionArea(
        child: _SheetSelection(
          onSelectAll: complete && !expanded ? selectAllBlocks : null,
          onClear: selectionCleared,
          onSelectAllHandled: () => selectAllPending = false,
          child: Builder(
            builder: (context) {
              insideArea = context;
              return CustomScrollView(
                controller: widget.controller,
                scrollCacheExtent: expanded
                    ? const ScrollCacheExtent.pixels(_wholeDocument)
                    : null,
                slivers: [
                  SliverPadding(
                    padding: recipe
                        .markdownInset(width)
                        .copyWith(top: 0, bottom: 0),
                    sliver: SliverList.builder(
                      itemCount: blocks.length + notice,
                      itemBuilder: (context, index) {
                        if (index < notice) {
                          return Padding(
                            padding: EdgeInsets.only(top: vertical, bottom: 16),
                            child: Text(
                              raftText(
                                context,
                                'Preview truncated. Download the full file.',
                              ),
                            ),
                          );
                        }
                        final at = index - notice;
                        final first = at == 0,
                            last = complete && at == blocks.length - 1;
                        return Padding(
                          padding: EdgeInsets.only(
                            top: first && !truncated ? vertical : 0,
                            bottom: last ? vertical : 0,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: recipe.paper,
                              border: Border(
                                left: side,
                                right: side,
                                top: first ? side : BorderSide.none,
                                bottom: last ? side : BorderSide.none,
                              ),
                              boxShadow: widget.shadow,
                            ),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                edge,
                                first ? vertical : 0,
                                edge,
                                last ? vertical : _blockGap - _BlockBreak.reach,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RaftMessageBody(
                                    content: blocks[at],
                                    fontSize: 16,
                                    documentMode: true,
                                    joinsAmbientSelection: true,
                                  ),
                                  if (!last) const _BlockBreak(),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The line break a copy keeps between two blocks. The scroll view's own
/// selection container joins what its blocks select with nothing, and a
/// container around a lazy sliver cannot be laid out, so the break is a line
/// of invisible text in the gap below every block but the last: a selection
/// that runs on into the next block includes it, one that ends in this block
/// does not. It sits [gap] below the block's text: Flutter orders selectables
/// within 3 px of each other by width, which would put it after the text.
class _BlockBreak extends StatelessWidget {
  const _BlockBreak();
  static const gap = 4.0, height = 1.0;

  /// The space the break takes out of the gap between two blocks.
  static const reach = gap + height;

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: gap),
    // ignore: raft_lints/avoid_fixed_height_text -- invisible 1px selection anchor, not content
    child: SizedBox(
      height: height,
      child: ExcludeSemantics(
        child: Text(
          '\n',
          textScaler: TextScaler.noScaling,
          style: TextStyle(fontSize: 1, height: 1, color: Color(0x00000000)),
        ),
      ),
    ),
  );
}

/// The selection container of the sheet. It sits above the scroll view's own
/// container and watches the events: a Select All first asks the sheet to
/// build every block (the lazily built ones are not selectables yet), and
/// clearing the selection lets it go lazy again.
class _SheetSelection extends StatefulWidget {
  const _SheetSelection({
    required this.onSelectAll,
    required this.onClear,
    required this.onSelectAllHandled,
    required this.child,
  });
  final VoidCallback? onSelectAll, onClear, onSelectAllHandled;
  final Widget child;

  @override
  State<_SheetSelection> createState() => _SheetSelectionState();
}

class _SheetSelectionState extends State<_SheetSelection> {
  late final _SheetDelegate delegate = _SheetDelegate(() => widget);

  @override
  void dispose() {
    delegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SelectionContainer(delegate: delegate, child: widget.child);
}

class _SheetDelegate extends StaticSelectionContainerDelegate {
  _SheetDelegate(this.widget);
  final _SheetSelection Function() widget;

  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    final sheet = widget();
    if (event is SelectAllSelectionEvent) {
      final ask = sheet.onSelectAll;
      if (ask != null) {
        // Not built yet: the sheet selects again when it is.
        ask();
        return SelectionResult.end;
      }
      sheet.onSelectAllHandled?.call();
    } else if (event is ClearSelectionEvent) {
      sheet.onClear?.call();
    }
    return super.dispatchSelectionEvent(event);
  }
}
