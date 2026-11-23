import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:markdown/markdown.dart' as md;

import 'localization.dart';
import 'markdown_autolink.dart';

/// Compact accessibility contract for one timeline message row.
///
/// Every visible message row used to contribute a dozen semantics nodes: the
/// avatar image, author button, timestamp, one node per paragraph, three per
/// paragraph that contains a link, a nested horizontal scroll node per code
/// block and a node per reaction. While a row is partly clipped by the
/// viewport, all of them are rebuilt and re-sent each scroll frame.
///
/// A compact row instead forms a single semantics boundary whose label
/// carries author, time and the plain message text. Row actions become custom
/// semantics actions (and the long-press action opens the full message menu,
/// which is the path on Linux AT-SPI where Flutter does not name custom
/// actions). Only interactive content keeps child nodes: links and mentions,
/// code blocks (copy), attachments, reactions, task chips, thread badges and
/// the Show more toggle. On a touch row links, mentions and reactions are
/// actions of the row node instead ([RaftMessageLinkActions]); every other
/// control keeps its own node.
@immutable
class RaftMessageSemanticsAction {
  const RaftMessageSemanticsAction(this.label, this.onInvoke);

  /// Localized, stable action name ("Reply in thread", "Save"...).
  final String label;

  /// Receives the row's context, e.g. as a popup anchor.
  final void Function(BuildContext row) onInvoke;
}

/// Published by a compact [RaftMessageRow]; message content reads it to drop
/// prose nodes the row label already announces.
class RaftMessageSemanticsScope extends InheritedWidget {
  const RaftMessageSemanticsScope({
    super.key,
    required this.visibleFraction,
    this.mergeInlineActions = false,
    this.linkActions,
    required super.child,
  });

  /// Fraction of the message text that is visible while the content is
  /// collapsed; null when it is fully shown. Reported by [RaftCollapsible].
  final ValueNotifier<double?> visibleFraction;
  final bool mergeInlineActions;

  /// Where prose publishes its links as actions of the row node, when the
  /// row is a touch row ([mergeInlineActions]).
  final RaftMessageLinkActions? linkActions;

  static RaftMessageSemanticsScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RaftMessageSemanticsScope>();

  @override
  bool updateShouldNotify(RaftMessageSemanticsScope oldWidget) =>
      !identical(visibleFraction, oldWidget.visibleFraction) ||
      mergeInlineActions != oldWidget.mergeInlineActions ||
      !identical(linkActions, oldWidget.linkActions);
}

/// The link actions a touch row's prose lifts onto the row node.
///
/// Links are published here instead of being merged up through the
/// semantics tree: merging would need the row to absorb its descendants,
/// and then every interactive control in it that is not its own semantics
/// boundary (cards, attachments, thread previews, footer controls) would
/// disappear into the row node.
class RaftMessageLinkActions {
  final _published =
      <Object, (List<RaftMessageSemanticsLink>, ValueChanged<String>)>{};
  VoidCallback? _listener;

  void _publish(
    Object owner,
    (List<RaftMessageSemanticsLink>, ValueChanged<String>)? links,
  ) {
    if (links == null) {
      if (_published.remove(owner) == null) return;
    } else {
      _published[owner] = links;
    }
    _listener?.call();
  }

  /// The row's own actions, then every published link in publication
  /// (reading) order. A link never replaces a row action or another link:
  /// a label that is not unique becomes "label, address", numbered if even
  /// that repeats.
  static Map<CustomSemanticsAction, VoidCallback> _actions(
    Map<String, VoidCallback> row,
    RaftMessageLinkActions? links,
  ) {
    final result = {
      for (final MapEntry(:key, :value) in row.entries)
        CustomSemanticsAction(label: key): value,
    };
    final published = links?._published.values ?? const [];
    final counts = <String, int>{};
    for (final (list, _) in published) {
      for (final link in list) {
        counts.update(link.label, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final taken = {...row.keys};
    for (final (list, open) in published) {
      for (final link in list) {
        var label = link.label;
        if (counts[label]! > 1 || taken.contains(label)) {
          label = '$label, ${link.href}';
        }
        if (taken.contains(label)) {
          var n = 2;
          while (taken.contains('$label ($n)')) {
            n++;
          }
          label = '$label ($n)';
        }
        taken.add(label);
        result[CustomSemanticsAction(label: label)] = () => open(link.href);
      }
    }
    return result;
  }
}

/// The text a collapsed row announces: the leading part that is on screen,
/// cut at a word boundary. Expanding the row announces the full text.
String raftMessageSemanticsExcerpt(String text, double? visibleFraction) {
  if (visibleFraction == null || visibleFraction >= 1) return text;
  final budget = (text.length * visibleFraction.clamp(0.0, 1.0)).floor();
  if (budget >= text.length) return text;
  var cut = budget;
  final boundary = RegExp(r'[\s，。！？、；：,.!?;:]');
  for (var i = budget; i > budget * .7 && i > 0; i--) {
    if (boundary.hasMatch(text[i - 1])) {
      cut = i;
      break;
    }
  }
  return '${text.substring(0, cut).trimRight()}…';
}

final _textCache = LinkedHashMap<(String, String), String>();
final _fence = RegExp(r'^ {0,3}(`{3,}|~{3,})\s*([^\s`]*)\s*$');

/// Short description of a fenced code block: "Code block, 3 lines, dart".
String raftCodeBlockSemanticsLabel(
  BuildContext context,
  String code,
  String? language,
) {
  final lines = code.isEmpty ? 0 : '\n'.allMatches(code).length + 1;
  final lang = language == null || language.isEmpty ? null : language;
  return lang == null
      ? raftFormat(
          context,
          lines == 1 ? 'Code block, {lines} line' : 'Code block, {lines} lines',
          {'lines': lines},
        )
      : raftFormat(
          context,
          lines == 1
              ? 'Code block, {lines} line, {language}'
              : 'Code block, {lines} lines, {language}',
          {'lines': lines, 'language': lang},
        );
}

/// Plain text a screen reader announces for Markdown message content. Fenced
/// code is summarized like [raftCodeBlockSemanticsLabel]; Markdown syntax is
/// dropped. Results are cached: rows re-enter the viewport repeatedly.
String raftMessageSemanticsText(BuildContext context, String markdown) {
  final locale = Localizations.maybeLocaleOf(context)?.languageCode ?? '';
  final key = (locale, markdown);
  final cached = _textCache.remove(key);
  if (cached != null) return _textCache[key] = cached;
  final out = <String>[];
  final prose = StringBuffer();
  void flush() {
    if (prose.isEmpty) return;
    out.addAll(_plainLines(prose.toString()));
    prose.clear();
  }

  final lines = markdown.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final start = _fence.firstMatch(lines[i]);
    if (start == null) {
      prose.writeln(lines[i]);
      continue;
    }
    final fence = start[1]!;
    var end = i + 1;
    final close = RegExp(
      '^ {0,3}${RegExp.escape(fence[0])}{${fence.length},}\\s*\$',
    );
    while (end < lines.length && !close.hasMatch(lines[end])) {
      end++;
    }
    if (end == lines.length) {
      prose.writeln(lines[i]);
      continue;
    }
    flush();
    final language = start[2]!;
    out.add(
      language.toLowerCase() == 'mermaid'
          ? raftText(context, 'Mermaid diagram')
          : raftCodeBlockSemanticsLabel(
              context,
              lines.sublist(i + 1, end).join('\n'),
              language,
            ),
    );
    i = end;
  }
  flush();
  final text = out.join('\n');
  _textCache[key] = text;
  if (_textCache.length > 512) _textCache.remove(_textCache.keys.first);
  return text;
}

// Linear regex scans, not a second Markdown parse: rows are built inside
// list layout, and a full parse per new row showed up in build time.
final _codeSpan = RegExp(r'(`+)(.+?)\1');
final _image = RegExp(r'!\[((?:\\.|[^\]\\])*)\]\([^)]*\)');
final _authoredLink = RegExp(
  r'\[((?:\\.|[^\]\\])*)\]\(\s*<?([^)\s>]*)>?(?:\s+"[^"]*")?\s*\)',
);
final _angleLink = RegExp(r'<((?:https?|mailto):[^>\s]+)>');
final _urlHint = RegExp(r'://|www\.', caseSensitive: false);
final _sentinel = RegExp(
  '\u{E000}([^\u{E001}]*)\u{E001}([^\u{E002}]*)\u{E002}',
);
final _escape = RegExp(r'\\([\\`*_{}\[\]()#+\-.!|~<>])');
final _emphasis = RegExp(
  r'\*\*|__|~~|(?<![\w*\\])[*_](?=\S)|(?<=\S)[*_](?![\w*])',
);
final _blockPrefix = RegExp(
  r'^\s{0,3}(?:#{1,6}\s+|(?:>\s?)+|(?:[-*+]|\d+[.)])\s+(?:\[[ xX]\]\s+)?)+',
);
final _rule = RegExp(r'^\s{0,3}(?:(?:[-*_]\s*){3,}|\|?[\s:|-]*-[\s:|-]*)$');

String _unescape(String text) => text.replaceAllMapped(_escape, (m) => m[1]!);

List<String> _plainLines(String markdown) {
  final lines = <String>[];
  for (final raw in markdown.split('\n')) {
    if (raw.trim().isEmpty || _rule.hasMatch(raw)) continue;
    var line = raw.replaceFirst(_blockPrefix, '');
    line = line
        .replaceAllMapped(_codeSpan, (m) => m[2]!)
        .replaceAllMapped(_sentinel, (m) => m[2]!)
        .replaceAllMapped(_image, (m) => m[1]!)
        .replaceAllMapped(_authoredLink, (m) => m[1]!)
        .replaceAllMapped(_angleLink, (m) => m[1]!)
        .replaceAll(_emphasis, '')
        .replaceAll('|', ' ');
    line = _unescape(line).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (line.isNotEmpty) lines.add(line);
  }
  return lines;
}

/// The links of a parsed (and reference-resolved) body, in reading order:
/// authored links, autolinks and identity references.
List<RaftMessageSemanticsLink> raftTreeSemanticsLinks(List<md.Node> nodes) {
  final found = <RaftMessageSemanticsLink>[];
  void visit(md.Node node) {
    if (node is! md.Element) return;
    final href = node.attributes['href'];
    if (node.tag == 'a' && href != null) {
      final label = node.textContent.trim();
      found.add((label: label.isEmpty ? href : label, href: href));
      return;
    }
    for (final child in node.children ?? const <md.Node>[]) {
      visit(child);
    }
  }

  nodes.forEach(visit);
  return found;
}

/// A link or identity reference rendered inside message prose.
typedef RaftMessageSemanticsLink = ({String label, String href});

final _linkCache = LinkedHashMap<String, List<RaftMessageSemanticsLink>>();

/// Links in prepared message Markdown (after [raftMessageReferences]), in
/// reading order: authored links, autolinks and identity references. Code
/// spans are skipped, as in the rendered body.
List<RaftMessageSemanticsLink> raftMessageSemanticsLinks(String markdown) {
  final cached = _linkCache.remove(markdown);
  if (cached != null) return _linkCache[markdown] = cached;
  final found = <(int, RaftMessageSemanticsLink)>[];
  if (markdown.contains('](') ||
      _urlHint.hasMatch(markdown) ||
      markdown.contains('\u{E000}')) {
    // Blank code spans (same length) so offsets stay comparable.
    final text = markdown.replaceAllMapped(
      _codeSpan,
      (m) => ' ' * m[0]!.length,
    );
    final taken = <(int, int)>[];
    bool free(Match m) => !taken.any((r) => m.start < r.$2 && r.$1 < m.end);
    // An image's source is not prose.
    for (final m in _image.allMatches(text)) {
      taken.add((m.start, m.end));
    }
    for (final m in _authoredLink.allMatches(text)) {
      if (m.start > 0 && text[m.start - 1] == '!') continue;
      taken.add((m.start, m.end));
      final label = _unescape(m[1]!.replaceAllMapped(_sentinel, (s) => s[2]!))
          .trim();
      found.add((m.start, (label: label.isEmpty ? m[2]! : label, href: m[2]!)));
      // A reference nested in an authored label is its own link.
      for (final s in _sentinel.allMatches(m[1]!)) {
        found.add((m.start + 1, (label: s[2]!, href: s[1]!)));
      }
    }
    for (final m in _sentinel.allMatches(text)) {
      if (!free(m)) continue;
      taken.add((m.start, m.end));
      found.add((m.start, (label: m[2]!, href: m[1]!)));
    }
    for (final m in _angleLink.allMatches(text)) {
      if (!free(m)) continue;
      taken.add((m.start, m.end));
      found.add((m.start, (label: m[1]!, href: m[1]!)));
    }
    // The same scan the renderer's syntax runs, so a URL is a link here
    // exactly when it is drawn as one.
    for (final u in raftBareUrls(text)) {
      if (!taken.any((r) => u.start < r.$2 && r.$1 < u.end)) {
        found.add((u.start, (label: u.text, href: u.href)));
      }
    }
  }
  found.sort((a, b) => a.$1.compareTo(b.$1));
  final result = List<RaftMessageSemanticsLink>.unmodifiable([
    for (final (_, link) in found) link,
  ]);
  _linkCache[markdown] = result;
  if (_linkCache.length > 512) _linkCache.remove(_linkCache.keys.first);
  return result;
}

/// Prose whose text the row label announces: its own text nodes are dropped
/// and each link becomes one compact link node. Link nodes are one logical
/// pixel tall strips at the top of the prose, so touch exploration of the
/// text finds the message row rather than an unrelated link.
class RaftMessageProseSemantics extends StatelessWidget {
  const RaftMessageProseSemantics({
    super.key,
    required this.links,
    required this.onLink,
    required this.child,
    this.linkActions,
  });
  final List<RaftMessageSemanticsLink> links;
  final ValueChanged<String>? onLink;
  final Widget child;
  final RaftMessageLinkActions? linkActions;
  @override
  Widget build(BuildContext context) {
    final prose = ExcludeSemantics(child: child);
    if (links.isEmpty) return prose;
    final scope = RaftMessageSemanticsScope.maybeOf(context);
    final row =
        linkActions ??
        (scope?.mergeInlineActions == true ? scope?.linkActions : null);
    if (row != null) {
      return _ProseLinkActions(
        links: links,
        onLink: onLink,
        row: row,
        child: prose,
      );
    }
    return Stack(
      children: [
        prose,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final link in links)
                Semantics(
                  container: true,
                  link: true,
                  label: link.label,
                  linkUrl: link.href.startsWith('http')
                      ? Uri.tryParse(link.href)
                      : null,
                  onTap: onLink == null ? null : () => onLink!(link.href),
                  // ignore: raft_lints/off_grid_spacing -- invisible semantics node, not layout
                  child: const SizedBox(height: 1),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Publishes a prose block's links as custom actions of its row node.
class _ProseLinkActions extends StatefulWidget {
  const _ProseLinkActions({
    required this.links,
    required this.onLink,
    required this.row,
    required this.child,
  });
  final List<RaftMessageSemanticsLink> links;
  final ValueChanged<String>? onLink;
  final RaftMessageLinkActions row;
  final Widget child;
  @override
  State<_ProseLinkActions> createState() => _ProseLinkActionsState();
}

class _ProseLinkActionsState extends State<_ProseLinkActions> {
  @override
  void initState() {
    super.initState();
    publish();
  }

  @override
  void didUpdateWidget(_ProseLinkActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.row, widget.row)) {
      oldWidget.row._publish(this, null);
    } else if (listEquals(oldWidget.links, widget.links) &&
        (oldWidget.onLink == null) == (widget.onLink == null)) {
      // Handlers read the current onLink; the published map stays stable.
      return;
    }
    publish();
  }

  /// Published only when the links change: the row rebuilds its action map
  /// then, and SemanticsNode compares handlers by identity.
  void publish() => widget.row._publish(
    this,
    widget.onLink == null ? null : (widget.links, open),
  );

  // Reads the current onLink.
  void open(String href) => widget.onLink?.call(href);

  @override
  void dispose() {
    widget.row._publish(this, null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The single semantics node of a compact message row.
///
/// A plain [Semantics] widget marks its node dirty on every rebuild (its
/// properties have identity equality), so hover, popup and parent rebuilds
/// would re-send every visible row. This node is only re-described when the
/// label or the action names actually change.
class RaftMessageRowSemantics extends SingleChildRenderObjectWidget {
  const RaftMessageRowSemantics({
    super.key,
    required this.label,
    required this.actions,
    required this.onAction,
    this.onLongPress,
    this.linkActions,
    super.child,
  });
  final String label;
  final List<String> actions;
  final ValueChanged<int> onAction;
  final VoidCallback? onLongPress;

  /// Prose links of a touch row, added to the row's own actions.
  final RaftMessageLinkActions? linkActions;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMessageRowSemantics(
        label: label,
        actions: actions,
        onAction: onAction,
        onLongPress: onLongPress,
        linkActions: linkActions,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMessageRowSemantics renderObject,
  ) {
    renderObject.update(
      label: label,
      actions: actions,
      onAction: onAction,
      onLongPress: onLongPress,
      linkActions: linkActions,
      textDirection: Directionality.of(context),
    );
  }
}

class _RenderMessageRowSemantics extends RenderProxyBox {
  _RenderMessageRowSemantics({
    required this.label,
    required this.actions,
    required this.onAction,
    required this.onLongPress,
    required this.linkActions,
    required this.textDirection,
  });
  String label;
  List<String> actions;
  ValueChanged<int> onAction;
  VoidCallback? onLongPress;
  RaftMessageLinkActions? linkActions;
  TextDirection textDirection;
  Map<CustomSemanticsAction, VoidCallback>? customActions;

  void update({
    required String label,
    required List<String> actions,
    required ValueChanged<int> onAction,
    required VoidCallback? onLongPress,
    required RaftMessageLinkActions? linkActions,
    required TextDirection textDirection,
  }) {
    // Callbacks are read when an action fires; replacing them is silent.
    this.onAction = onAction;
    final longPressChanged =
        (onLongPress == null) != (this.onLongPress == null);
    this.onLongPress = onLongPress;
    if (!identical(this.linkActions, linkActions)) {
      if (attached) {
        _unlisten();
        this.linkActions = linkActions;
        _listen();
      } else {
        this.linkActions = linkActions;
      }
      linksChanged();
    }
    if (this.label == label &&
        listEquals(this.actions, actions) &&
        this.textDirection == textDirection &&
        !longPressChanged) {
      return;
    }
    this.label = label;
    if (!listEquals(this.actions, actions)) customActions = null;
    this.actions = actions;
    this.textDirection = textDirection;
    markNeedsSemanticsUpdate();
  }

  void _listen() => linkActions?._listener = linksChanged;
  void _unlisten() {
    if (linkActions?._listener == linksChanged) linkActions!._listener = null;
  }

  void linksChanged() {
    customActions = null;
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    // Links may have changed while detached.
    customActions = null;
    _listen();
  }

  @override
  void detach() {
    _unlisten();
    super.detach();
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    // Children keep their own nodes, as interactive content must; the prose
    // excludes its text (the label announces it) and publishes its links.
    config
      ..isSemanticBoundary = true
      ..explicitChildNodes = true
      ..label = label
      ..textDirection = textDirection
      ..customSemanticsActions = rowActions;
    if (onLongPress != null) config.onLongPress = () => onLongPress?.call();
  }

  /// A stable map: SemanticsNode compares handlers by identity, so fresh
  /// closures would re-send the row on every update.
  Map<CustomSemanticsAction, VoidCallback> get rowActions =>
      customActions ??= RaftMessageLinkActions._actions({
        for (var i = 0; i < actions.length; i++) actions[i]: () => onAction(i),
      }, linkActions);
}
