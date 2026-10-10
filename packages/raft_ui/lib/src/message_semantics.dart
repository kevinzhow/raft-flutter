import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:markdown/markdown.dart' as md;

import 'localization.dart';

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
/// the Show more toggle.
@immutable
class RaftMessageSemanticsAction {
  const RaftMessageSemanticsAction(this.label, this.onInvoke);

  /// Localized, stable action name ("Reply in thread", "Save message"...).
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
    required super.child,
  });

  /// Fraction of the message text that is visible while the content is
  /// collapsed; null when it is fully shown. Reported by [RaftCollapsible].
  final ValueNotifier<double?> visibleFraction;

  static RaftMessageSemanticsScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RaftMessageSemanticsScope>();

  @override
  bool updateShouldNotify(RaftMessageSemanticsScope oldWidget) =>
      !identical(visibleFraction, oldWidget.visibleFraction);
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

const _blockTags = {
  'p',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'li',
  'blockquote',
  'pre',
  'tr',
  'hr',
  'table',
  'ul',
  'ol',
};

List<String> _plainLines(String markdown) {
  final nodes = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
    inlineSyntaxes: [_SemanticsSentinelSyntax()],
  ).parseLines(markdown.split('\n'));
  final lines = <String>[];
  final line = StringBuffer();
  void end() {
    final text = line.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isNotEmpty) lines.add(text);
    line.clear();
  }

  void visit(md.Node node) {
    if (node is md.Text) {
      line.write(node.text);
    } else if (node is md.Element) {
      final block = _blockTags.contains(node.tag);
      if (block) end();
      if (node.tag == 'img') line.write(node.attributes['alt'] ?? '');
      if (node.tag == 'br') line.write(' ');
      if (node.tag == 'td' || node.tag == 'th') line.write(' ');
      for (final child in node.children ?? const <md.Node>[]) {
        visit(child);
      }
      if (block) end();
    }
  }

  nodes.forEach(visit);
  end();
  return lines;
}

/// A link or identity reference rendered inside message prose.
typedef RaftMessageSemanticsLink = ({String label, String href});

final _linkCache = LinkedHashMap<String, List<RaftMessageSemanticsLink>>();

/// Links in prepared message Markdown (after [raftMessageReferences]), in
/// reading order: authored links, autolinks and identity references.
List<RaftMessageSemanticsLink> raftMessageSemanticsLinks(String markdown) {
  final cached = _linkCache.remove(markdown);
  if (cached != null) return _linkCache[markdown] = cached;
  final links = <RaftMessageSemanticsLink>[];
  void visit(md.Node node) {
    if (node is! md.Element) return;
    final href = node.attributes['href'];
    if ((node.tag == 'a' || node.tag == 'raftref') && href != null) {
      final label = node.textContent.trim();
      links.add((label: label.isEmpty ? href : label, href: href));
      // A reference nested in an authored label is its own link.
      for (final child in node.children ?? const <md.Node>[]) {
        if (child is md.Element && child.tag == 'raftref') visit(child);
      }
      return;
    }
    for (final child in node.children ?? const <md.Node>[]) {
      visit(child);
    }
  }

  if (markdown.contains('](') ||
      markdown.contains('://') ||
      markdown.contains('www.') ||
      markdown.contains('\u{E000}') ||
      markdown.contains('<')) {
    md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
      inlineSyntaxes: [_SemanticsSentinelSyntax()],
    ).parseLines(markdown.split('\n')).forEach(visit);
  }
  final result = List<RaftMessageSemanticsLink>.unmodifiable(links);
  _linkCache[markdown] = result;
  if (_linkCache.length > 512) _linkCache.remove(_linkCache.keys.first);
  return result;
}

/// Same private-use sentinel grammar as the message body's reference syntax.
class _SemanticsSentinelSyntax extends md.InlineSyntax {
  _SemanticsSentinelSyntax()
    : super('\u{E000}([^\u{E001}]*)\u{E001}([^\u{E002}]*)\u{E002}');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(
      md.Element('raftref', [md.Text(match[2]!)])
        ..attributes['href'] = match[1]!,
    );
    return true;
  }
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
  });
  final List<RaftMessageSemanticsLink> links;
  final ValueChanged<String>? onLink;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final prose = ExcludeSemantics(child: child);
    if (links.isEmpty) return prose;
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
                  child: const SizedBox(height: 1),
                ),
            ],
          ),
        ),
      ],
    );
  }
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
    super.child,
  });
  final String label;
  final List<String> actions;
  final ValueChanged<int> onAction;
  final VoidCallback? onLongPress;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMessageRowSemantics(
        label: label,
        actions: actions,
        onAction: onAction,
        onLongPress: onLongPress,
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
    required this.textDirection,
  });
  String label;
  List<String> actions;
  ValueChanged<int> onAction;
  VoidCallback? onLongPress;
  TextDirection textDirection;
  Map<CustomSemanticsAction, VoidCallback>? customActions;

  void update({
    required String label,
    required List<String> actions,
    required ValueChanged<int> onAction,
    required VoidCallback? onLongPress,
    required TextDirection textDirection,
  }) {
    // Callbacks are read when an action fires; replacing them is silent.
    this.onAction = onAction;
    final longPressChanged =
        (onLongPress == null) != (this.onLongPress == null);
    this.onLongPress = onLongPress;
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

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..explicitChildNodes = true
      ..label = label
      ..textDirection = textDirection
      // A stable map: SemanticsNode compares handlers by identity, so fresh
      // closures would re-send the row after every relayout below it.
      ..customSemanticsActions = customActions ??= {
        for (var i = 0; i < actions.length; i++)
          CustomSemanticsAction(label: actions[i]): () => onAction(i),
      };
    if (onLongPress != null) config.onLongPress = () => onLongPress?.call();
  }
}
