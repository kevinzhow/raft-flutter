// Markdown's structural comment location. The renderer annotates its actual
// blocks; no text search can confuse a heading with a same-named paragraph.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:markdown/markdown.dart' as md;

import 'attachment_comment_scope.dart';
import 'interaction.dart';
import 'markdown_outline.dart';
import 'message_markdown.dart' show RaftMarkdownHeadingElement;
import 'theme.dart';

const _kind = 'md-section';
const _unsectioned = RaftMarkdownOutlineItem(
  id: '',
  level: 1,
  sourceLine: 0,
  title: '',
);

/// A live document owns its heading IDs, block geometry and jump animation.
/// Layout and interaction remain those of the existing document renderer.
class RaftMarkdownCommentAnchorHost extends StatefulWidget {
  const RaftMarkdownCommentAnchorHost({
    super.key,
    required this.outline,
    required this.expand,
    required this.child,
  });
  final List<RaftMarkdownOutlineItem> outline;
  final Future<void> Function() expand;
  final Widget child;
  @override
  State<RaftMarkdownCommentAnchorHost> createState() => _MarkdownAnchors();
}

class _MarkdownAnchors extends State<RaftMarkdownCommentAnchorHost>
    with SingleTickerProviderStateMixin {
  RaftAttachmentCommentState? comments;
  final entries = <GlobalKey, _MarkdownEntry>{};
  late final animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  final paint = _MarkdownPaint();
  String? flashing;
  Offset? down;
  int revision = 0, selectionRevision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = RaftAttachmentCommentScope.read(context);
    if (identical(next, comments)) return;
    detach();
    comments = next;
    next?.jumpHandler = jump;
    next?.orderHandler = order;
    retireStale();
  }

  void detach() {
    if (comments?.jumpHandler == jump) {
      comments?.jumpHandler = null;
      if (comments?.pendingAnchor?['type'] == _kind) comments?.clearAnchor();
    }
    if (comments?.orderHandler == order) comments?.orderHandler = null;
    revision++;
  }

  @override
  void didUpdateWidget(RaftMarkdownCommentAnchorHost old) {
    super.didUpdateWidget(old);
    if (old.outline == widget.outline) return;
    revision++;
    flashing = null;
    animation.stop();
    retireStale();
  }

  void retireStale() {
    final ticket = revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ticket != revision) return;
      final pending = comments?.pendingAnchor;
      if (pending != null && idOf(pending) != null && order(pending) == null)
        comments?.clearAnchor();
    });
  }

  @override
  void dispose() {
    detach();
    animation.dispose();
    paint.dispose();
    super.dispose();
  }

  String? idOf(RaftCommentAnchor anchor) {
    final data = anchor['data'];
    return anchor['type'] == _kind && data is Map && data['headingId'] is String
        ? data['headingId'] as String
        : null;
  }

  num? order(RaftCommentAnchor anchor) {
    final id = idOf(anchor);
    return widget.outline.where((h) => h.id == id).firstOrNull?.sourceLine;
  }

  bool jump(RaftCommentAnchor anchor) {
    final id = idOf(anchor);
    if (id == null || order(anchor) == null) return false;
    unawaited(reveal(id, revision));
    return true;
  }

  Future<void> reveal(String id, int ticket) async {
    await widget.expand();
    if (!mounted || ticket != revision) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || ticket != revision) return;
    final target = entries.values
        .where((e) => e.heading && e.item.id == id)
        .firstOrNull;
    final at = target?.key.currentContext;
    if (at == null) return;
    await Scrollable.ensureVisible(
      at,
      alignment: .5,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    if (!mounted || ticket != revision) return;
    flashing = id;
    animation.removeListener(paint.changed);
    animation.addListener(paint.changed);
    unawaited(
      animation.forward(from: 0).whenComplete(() {
        if (!mounted || ticket != revision) return;
        flashing = null;
        paint.changed();
      }),
    );
    paint.changed();
  }

  RaftCommentAnchor? anchor(_MarkdownEntry entry, String text) =>
      entry.item.id.isEmpty
      ? null
      : {
          'type': _kind,
          'data': {
            'headingId': entry.item.id,
            'headingTitle': entry.item.title,
            'quote': ?raftCommentQuote(text),
          },
        };

  void selectionChanged(SelectedContent? content) {
    final quote = raftCommentQuote(content?.plainText ?? '');
    final ticket = ++selectionRevision;
    if (quote == null || comments?.commentMode != true) return;
    // Selection callbacks can precede the delegates' final range update.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          ticket != selectionRevision ||
          comments?.commentMode != true)
        return;
      final selected = entries.values.where((e) => e.hasSelection).toList()
        ..sort((a, b) {
          final section = a.item.sourceLine.compareTo(b.item.sourceLine);
          return section != 0
              ? section
              : (a.rect?.top ?? 0).compareTo(b.rect?.top ?? 0);
        });
      if (selected.isNotEmpty) {
        final location = anchor(selected.first, quote);
        if (location != null) comments!.pushAnchor(location);
      }
    });
  }

  void pointerUp(PointerUpEvent event) {
    final start = down;
    down = null;
    if (start == null ||
        comments?.commentMode != true ||
        (event.position - start).distance > 6)
      return;
    final hit =
        entries.values
            .where((e) => e.rect?.contains(event.position) == true)
            .toList()
          ..sort(
            (a, b) => (a.rect!.width * a.rect!.height).compareTo(
              b.rect!.width * b.rect!.height,
            ),
          );
    if (hit.isNotEmpty) {
      final location = anchor(hit.first, hit.first.text);
      if (location != null) comments!.pushAnchor(location);
    }
  }

  @override
  Widget build(BuildContext context) => RaftMarkdownAnchorFragment(
    owner: this,
    headings: widget.outline,
    child: Listener(
      onPointerDown: (e) => down =
          comments?.commentMode == true && RaftInteraction.of(context).touch
          ? e.position
          : null,
      onPointerMove: (e) {
        if (down != null && (e.position - down!).distance > 6) down = null;
      },
      onPointerUp: pointerUp,
      onPointerCancel: (_) => down = null,
      child: widget.child,
    ),
  );
}

/// A lazy render block carries IDs from the complete document, so duplicate
/// headings never restart their suffixes at a lazy-list boundary.
class RaftMarkdownAnchorFragment extends InheritedWidget {
  const RaftMarkdownAnchorFragment({
    super.key,
    required this.owner,
    required this.headings,
    this.previous,
    required super.child,
  });
  final _MarkdownAnchors owner;
  final List<RaftMarkdownOutlineItem> headings;
  final RaftMarkdownOutlineItem? previous;
  static RaftMarkdownAnchorFragment? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RaftMarkdownAnchorFragment>();
  void selectionChanged(SelectedContent? content) =>
      owner.selectionChanged(content);
  RaftMarkdownAnchorBuilder builder() => RaftMarkdownAnchorBuilder(this);
  Widget slice(int start, int count, Widget child) {
    final offset = start.clamp(0, headings.length);
    return RaftMarkdownAnchorFragment(
      owner: owner,
      headings: headings.sublist(
        offset,
        (offset + count).clamp(offset, headings.length),
      ),
      previous: offset == 0 ? previous : headings[offset - 1],
      child: child,
    );
  }

  @override
  bool updateShouldNotify(RaftMarkdownAnchorFragment old) =>
      owner != old.owner ||
      headings != old.headings ||
      previous != old.previous;
}

/// Maps one renderer's Markdown chunks to the document's heading sequence.
class RaftMarkdownAnchorBuilder {
  RaftMarkdownAnchorBuilder(this.fragment);
  final RaftMarkdownAnchorFragment fragment;
  int cursor = 0;
  Widget wrapOther(String text, Widget child) {
    final previous = cursor == 0
        ? fragment.previous
        : (cursor <= fragment.headings.length
              ? fragment.headings[cursor - 1]
              : null);
    return RaftMarkdownAnchorBlock(
      owner: fragment.owner,
      item: previous ?? _unsectioned,
      heading: false,
      text: text,
      child: child,
    );
  }

  Widget Function(md.Element, Widget) wrap(String source) {
    final local = raftExtractMarkdownOutline(source);
    final headings = fragment.headings.skip(cursor).take(local.length).toList();
    var previous = cursor == 0
        ? fragment.previous
        : (cursor <= fragment.headings.length
              ? fragment.headings[cursor - 1]
              : null);
    cursor += local.length;
    final byLine = {
      for (var i = 0; i < local.length && i < headings.length; i++)
        local[i].sourceLine: headings[i],
    };
    return (element, child) {
      final target = element is RaftMarkdownHeadingElement
          ? byLine[element.sourceLine]
          : null;
      final heading = target != null;
      if (target != null) {
        previous = RaftMarkdownOutlineItem(
          id: target.id,
          level: target.level,
          sourceLine: target.sourceLine,
          title: element.textContent.trim().isEmpty
              ? target.id
              : element.textContent.trim(),
        );
      }
      return RaftMarkdownAnchorBlock(
        owner: fragment.owner,
        item: previous ?? _unsectioned,
        heading: heading,
        text: element.textContent,
        child: child,
      );
    };
  }
}

class _MarkdownEntry {
  _MarkdownEntry(this.key, this.item, this.heading, this.text);
  final GlobalKey key;
  final RaftMarkdownOutlineItem item;
  final bool heading;
  final String text;
  final delegates = <SelectionContainerDelegate>{};
  bool get hasSelection => delegates.any(
    (d) => (d.getSelectedContent()?.plainText ?? '').isNotEmpty,
  );
  Rect? get rect {
    final box = key.currentContext?.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
  }
}

/// Layout-neutral annotation around the renderer's existing block. Selection
/// delegates are observed in place; adding nested containers would alter
/// long-press selection dispatch and the copied paragraph separators.
class RaftMarkdownAnchorBlock extends StatefulWidget {
  const RaftMarkdownAnchorBlock({
    super.key,
    required this.owner,
    required this.item,
    required this.heading,
    required this.text,
    required this.child,
  });
  final _MarkdownAnchors owner;
  final RaftMarkdownOutlineItem item;
  final bool heading;
  final String text;
  final Widget child;
  RaftMarkdownAnchorBlock withChild(Widget child) => RaftMarkdownAnchorBlock(
    key: key,
    owner: owner,
    item: item,
    heading: heading,
    text: text,
    child: child,
  );
  static Set<SelectionContainerDelegate>? delegatesOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_MarkdownBlockScope>()
          ?.entry
          .delegates;
  @override
  State<RaftMarkdownAnchorBlock> createState() => _MarkdownBlockState();
}

class _MarkdownBlockState extends State<RaftMarkdownAnchorBlock> {
  final key = GlobalKey();
  late _MarkdownEntry entry;
  void register() {
    entry = _MarkdownEntry(key, widget.item, widget.heading, widget.text);
    widget.owner.entries[key] = entry;
  }

  @override
  void initState() {
    super.initState();
    register();
  }

  @override
  void didUpdateWidget(RaftMarkdownAnchorBlock old) {
    super.didUpdateWidget(old);
    if (old.item == widget.item &&
        old.heading == widget.heading &&
        old.text == widget.text &&
        old.owner == widget.owner)
      return;
    old.owner.entries.remove(key);
    final delegates = entry.delegates;
    register();
    entry.delegates.addAll(delegates);
  }

  @override
  void dispose() {
    widget.owner.entries.remove(key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _MarkdownBlockScope(
    entry: entry,
    child: KeyedSubtree(
      key: key,
      child: ListenableBuilder(
        listenable: widget.owner.paint,
        builder: (context, child) {
          final active =
              widget.heading && widget.owner.flashing == widget.item.id;
          final t = widget.owner.animation.value;
          final strength = !active
              ? 0.0
              : t <= .35
              ? 1.0
              : 1 - Curves.easeOut.transform((t - .35) / .65);
          return ColoredBox(
            color: RaftTokens.of(context).colors['info-soft']!
                .withValues(alpha: strength),
            child: child,
          );
        },
        child: widget.child,
      ),
    ),
  );
}

class _MarkdownBlockScope extends InheritedWidget {
  const _MarkdownBlockScope({required this.entry, required super.child});
  final _MarkdownEntry entry;
  @override
  bool updateShouldNotify(_MarkdownBlockScope old) => entry != old.entry;
}

class _MarkdownPaint extends ChangeNotifier {
  void changed() => notifyListeners();
}
