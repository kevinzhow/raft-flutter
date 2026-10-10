import 'mermaid_toolbar_recipe.dart';
import 'message_reference_chip.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:mermaid_flutter/mermaid_flutter.dart';
import 'package:mermaid_core/mermaid_core.dart' as core;

import 'package:re_highlight/re_highlight.dart';
import 'panel_layout.dart' show raftTextMetricsCache;
import 'viewport_breakpoints.dart';
import 'package:re_highlight/styles/github.dart';
import 'package:re_highlight/styles/github-dark.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/clojure.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/diff.dart';
import 'package:re_highlight/languages/dockerfile.dart';
import 'package:re_highlight/languages/elixir.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/graphql.dart';
import 'package:re_highlight/languages/haskell.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/lua.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/perl.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/ruby.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/scala.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';

import 'icons.dart';
import 'lru_cache.dart';
import 'message_list_marker.dart';
import 'message_content_tokens.dart';
import 'attachment_lightbox.dart';
import 'diagram_theme.dart';
import 'design_primitives.dart';
import 'localization.dart';
import 'message_semantics.dart';
import 'theme.dart';

/// A reference is interactive only when its identity is supplied by the
/// current workspace projection. User text never supplies a target identity.
class RaftTextReference {
  const RaftTextReference({
    required this.text,
    required this.href,
    this.identityBacked = false,
  });
  final String text, href;
  final bool identityBacked;
}

/// Protect code, authored links and URLs before adding identity-backed links.
/// Explicit task refs can be resolved asynchronously; bare numbers stay text.
String raftMessageReferences(
  String source, {
  List<RaftTextReference> references = const [],
  String Function(int number)? taskHref,
  bool Function(int number)? knownTaskNumber,
}) {
  final protected = RegExp(
    r'(`{3,}|~{3,})[^\n]*\n[\s\S]*?\1|`+[^`]*`+|!?\[[^\]]*\]\([^)]*\)|https?://[^\s]+',
  );
  // Inside an authored link label a reference cannot become a nested
  // markdown link; it is wrapped in private-use sentinels that
  // _ReferenceSentinelSyntax turns into a `raftref` element (Web chips
  // refs inside link labels too: MessageItem only protects code).
  String plain(String text, {bool sentinel = false}) {
    final matches = <({int start, int end, String label, String href})>[];
    for (final ref in references) {
      if (ref.text.isEmpty) continue;
      final pattern = RegExp(RegExp.escape(ref.text));
      for (final m in pattern.allMatches(text)) {
        final left = m.start == 0 ? '' : text.substring(m.start - 1, m.start);
        final right = m.end == text.length
            ? ''
            : text.substring(m.end, m.end + 1);
        // Conservative free-text grammar also protects emails and longer names.
        if (!ref.identityBacked &&
            left.isNotEmpty &&
            RegExp(r'[\p{L}\p{N}_@/]', unicode: true).hasMatch(left)) {
          continue;
        }
        if (right.isNotEmpty &&
            RegExp(r'[\p{L}\p{N}_-]', unicode: true).hasMatch(right)) {
          continue;
        }
        if (right == '.' &&
            m.end + 1 < text.length &&
            RegExp(
              r'[\p{L}\p{N}_]',
              unicode: true,
            ).hasMatch(text.substring(m.end + 1, m.end + 2))) {
          continue;
        }
        if (ref.text.startsWith('@') &&
            (right == '~' || text.substring(0, m.start).endsWith('dm:'))) {
          continue;
        }
        // `#chan:shortId` / `dm:@peer:shortId` belong to the thread-ref
        // pass (Web runs it first); a plain `#design:` is still a channel.
        if ((ref.text.startsWith('#') || ref.text.startsWith('dm:')) &&
            (right == '~' ||
                (right == ':' &&
                    RegExp(
                      r'^:[0-9a-f]{6,8}(?![0-9a-z])',
                      caseSensitive: false,
                    ).hasMatch(text.substring(m.end))))) {
          continue;
        }
        matches.add((start: m.start, end: m.end, label: m[0]!, href: ref.href));
      }
    }
    if (taskHref != null) {
      // Web createRaftBareTaskRefRegex: `task #N` always, bare `#N` only for
      // a known task.
      for (final m in RegExp(
        r'(?:^|(?<=[^\w/]))(task\s+)?#([1-9][0-9]*)\b',
        caseSensitive: false,
      ).allMatches(text)) {
        final number = int.parse(m[2]!);
        if (m[1] == null && !(knownTaskNumber?.call(number) ?? false)) {
          continue;
        }
        final start = m.end - m[2]!.length - 1;
        matches.add((
          start: start,
          end: m.end,
          label: '#${m[2]}',
          href: taskHref(number),
        ));
      }
    }
    matches.sort(
      (a, b) => a.start != b.start
          ? a.start.compareTo(b.start)
          : b.end.compareTo(a.end),
    );
    final result = StringBuffer();
    var cursor = 0;
    for (final m in matches) {
      if (m.start < cursor) continue;
      result.write(text.substring(cursor, m.start));
      if (sentinel) {
        result.write('\u{E000}${m.href}\u{E001}${m.label}\u{E002}');
        cursor = m.end;
        continue;
      }
      final label = m.label
          .replaceAll(r'\', r'\\')
          .replaceAll('[', r'\[')
          .replaceAll(']', r'\]');
      result.write('[$label](<${m.href}>)');
      cursor = m.end;
    }
    result.write(text.substring(cursor));
    return result.toString();
  }

  final out = StringBuffer();
  var cursor = 0;
  final authoredLink = RegExp(r'^\[([^\]]*)\](\([^)]*\))$');
  for (final m in protected.allMatches(source)) {
    out.write(plain(source.substring(cursor, m.start)));
    final link = authoredLink.firstMatch(m[0]!);
    out.write(
      link == null ? m[0] : '[${plain(link[1]!, sentinel: true)}]${link[2]}',
    );
    cursor = m.end;
  }
  out.write(plain(source.substring(cursor)));
  return out.toString();
}

/// Inputs of [raftMessageReferences] that change its output. Task closures
/// are reduced to their answers for the numbers this text can reference.
@immutable
class _ReferencesKey {
  _ReferencesKey(
    this.source,
    List<RaftTextReference> references,
    String Function(int number)? taskHref,
    bool Function(int number)? knownTaskNumber,
  ) : references = [
        for (final r in references) (r.text, r.href, r.identityBacked),
      ],
      tasks = taskHref == null
          ? null
          : [
              for (final n in {
                for (final m in _taskNumberPattern.allMatches(source))
                  int.parse(m[1]!),
              })
                (n, taskHref(n), knownTaskNumber?.call(n) ?? false),
            ];
  static final _taskNumberPattern = RegExp(r'#([1-9][0-9]*)');
  final String source;
  final List<(String, String, bool)> references;
  final List<(int, String, bool)>? tasks;
  @override
  bool operator ==(Object other) =>
      other is _ReferencesKey &&
      other.source == source &&
      listEquals(other.references, references) &&
      listEquals(other.tasks, tasks);
  @override
  int get hashCode => Object.hash(
    source,
    Object.hashAll(references),
    tasks == null ? null : Object.hashAll(tasks!),
  );
}

/// One rendered block of a message body: a Markdown run, or a fenced code or
/// Mermaid block that the Markdown renderer does not own.
@immutable
class _BodyChunk {
  const _BodyChunk.markdown(this.text) : language = null, mermaid = false;
  const _BodyChunk.code(this.text, this.language, {required this.mermaid});
  final String text;
  final String? language;
  final bool mermaid;
  bool get markdown => language == null && !mermaid;
}

final _fenceStart = RegExp(r'^ {0,3}(`{3,}|~{3,})\s*([^\s`]*)\s*$');

List<_BodyChunk> _splitBody(String prepared) {
  final chunks = <_BodyChunk>[];
  final lines = prepared.split('\n');
  final markdown = StringBuffer();
  void flush() {
    if (markdown.isEmpty) return;
    chunks.add(_BodyChunk.markdown(markdown.toString()));
    markdown.clear();
  }

  for (var i = 0; i < lines.length; i++) {
    final start = _fenceStart.firstMatch(lines[i]);
    if (start == null) {
      markdown.writeln(lines[i]);
      continue;
    }
    final fence = start[1]!;
    final close = RegExp(
      '^ {0,3}${RegExp.escape(fence[0])}{${fence.length},}\\s*\$',
    );
    var end = i + 1;
    while (end < lines.length && !close.hasMatch(lines[end])) {
      end++;
    }
    if (end == lines.length) {
      markdown.writeln(lines[i]);
      continue;
    }
    flush();
    chunks.add(
      _BodyChunk.code(
        lines.sublist(i + 1, end).join('\n'),
        start[2],
        mermaid: start[2]!.toLowerCase() == 'mermaid',
      ),
    );
    i = end;
  }
  flush();
  return chunks;
}

/// Reference preparation and block splitting are pure functions of the
/// message text and its reference projection, so a row that is scrolled away
/// and back (or rebuilt by an unrelated update) does not redo them.
final _bodyChunkCache = RaftLruCache<_ReferencesKey, List<_BodyChunk>>(1024);

/// Capacities cover a full 500-message channel window (two Markdown runs
/// per message) so scrolling it end to end does not evict what the next
/// pass needs.
///
/// Parsed Markdown trees keyed by their exact source. Every message body uses
/// the same parser configuration (GitHub flavoured, reference sentinels).
/// A tree is shared only when MarkdownBuilder cannot change it: the builder
/// appends a placeholder to an empty list item after visiting it, which
/// would alter a second build, so such sources are parsed per build.
@visibleForTesting
final raftMarkdownAstCache = RaftLruCache<String, List<md.Node>?>(1024);

List<md.Node> _parseMarkdownSource(String data) => md.Document(
  inlineSyntaxes: [_ReferenceSentinelSyntax()],
  extensionSet: md.ExtensionSet.gitHubFlavored,
  encodeHtml: false,
).parseLines(const LineSplitter().convert(data));

bool _hasEmptyListItem(List<md.Node>? nodes) =>
    nodes != null &&
    nodes.any(
      (n) =>
          n is md.Element &&
          ((n.tag == 'li' && (n.children?.isEmpty ?? false)) ||
              _hasEmptyListItem(n.children)),
    );

List<md.Node> _parseMarkdown(String data) =>
    raftMarkdownAstCache.putIfAbsent(data, () {
      final nodes = _parseMarkdownSource(data);
      return _hasEmptyListItem(nodes) ? null : nodes;
    }) ??
    _parseMarkdownSource(data);

/// Exactly the style sheet MarkdownBody resolves (its Material fallback
/// merged with the message recipe), computed once per theme and text scale.
@immutable
class _StyleSheetKey {
  const _StyleSheetKey(
    this.theme,
    this.scaler,
    this.fontSize,
    this.lineHeight,
    this.document,
    this.mountedMessage,
    this.foreground,
  );
  final ThemeData theme;
  final TextScaler scaler;
  final double fontSize;
  final double? lineHeight;
  final bool document, mountedMessage;
  final Color? foreground;
  @override
  bool operator ==(Object other) =>
      other is _StyleSheetKey &&
      identical(other.theme, theme) &&
      other.scaler == scaler &&
      other.fontSize == fontSize &&
      other.lineHeight == lineHeight &&
      other.document == document &&
      other.mountedMessage == mountedMessage &&
      other.foreground == foreground;
  @override
  int get hashCode => Object.hash(
    identityHashCode(theme),
    scaler,
    fontSize,
    lineHeight,
    document,
    mountedMessage,
    foreground,
  );
}

final _styleSheetCache =
    RaftLruCache<_StyleSheetKey, (MarkdownStyleSheet, MarkdownStyleSheet)>(32);

/// Markdown and native Mermaid rendering. HTML is kept as text by the Markdown
/// parser. Diagram callbacks, scripts and remote resources are never executed.
class RaftMessageBody extends StatelessWidget {
  const RaftMessageBody({
    super.key,
    required this.content,
    this.onLink,
    this.references = const [],
    this.taskHref,
    this.fontSize = 14,
    this.foregroundColor,
    this.documentMode = false,
    this.mountedMessage = false,
    this.onCopyCode,
    this.onExportDiagram,
    this.exportMode = false,
    this.referenceAppearance,
    this.knownTaskNumber,
    this.lineHeight,
    this.enableProseSelection = true,
    this.compactSemantics = false,
  });

  /// Inside a compact timeline row whose label already announces the text:
  /// prose contributes only its links (see [RaftMessageProseSemantics]).
  final bool compactSemantics;

  /// Optional prose line height (px) for non-message surfaces.
  final double? lineHeight;

  /// Interactive containers such as an anchored comment button own taps.
  /// Ordinary message/document bodies retain their selection region.
  final bool enableProseSelection;
  final String content;

  /// Chip/text treatment for an identity-backed reference href (Web
  /// MessageItem markdown `a` renderer); null keeps a plain link.
  final RaftReferenceAppearance? Function(String href)? referenceAppearance;

  /// Web `knownTaskNumbers`: bare `#N` links only for loaded tasks.
  final bool Function(int number)? knownTaskNumber;
  final Future<void> Function(String)? onCopyCode;
  final Future<void> Function(String, Uint8List)? onExportDiagram;
  final double fontSize;
  final Color? foregroundColor;
  final bool documentMode;
  final bool mountedMessage;
  final bool exportMode;
  final List<RaftTextReference> references;
  final String Function(int)? taskHref;
  final ValueChanged<String>? onLink;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final key = _ReferencesKey(content, references, taskHref, knownTaskNumber);
    final chunks = _bodyChunkCache.putIfAbsent(
      key,
      () => _splitBody(
        raftMessageReferences(
          content,
          references: references,
          taskHref: taskHref,
          knownTaskNumber: knownTaskNumber,
        ),
      ),
    );
    final recipe = MessageContentRecipe(
      t,
      fontSize: fontSize,
      lineHeight: lineHeight,
      document: documentMode,
      mountedMessage: mountedMessage,
      foreground: foregroundColor,
    );
    (MarkdownStyleSheet, MarkdownStyleSheet)? styleSheets;
    (MarkdownStyleSheet, MarkdownStyleSheet) resolveStyleSheets() =>
        styleSheets ??= _styleSheetCache.putIfAbsent(
          _StyleSheetKey(
            Theme.of(context),
            MediaQuery.textScalerOf(context),
            fontSize,
            lineHeight,
            documentMode,
            mountedMessage,
            foregroundColor,
          ),
          () {
            final own = recipe.stylesheet(context);
            // MarkdownBody: kFallbackStyle(context).merge(styleSheet).
            return (
              own,
              MarkdownStyleSheet.fromTheme(Theme.of(context))
                  .copyWith(textScaler: MediaQuery.textScalerOf(context))
                  .merge(own),
            );
          },
        );
    final builders = <String, MarkdownElementBuilder>{
      'a': _MessageLinkBuilder(onLink, referenceAppearance),
      'raftref': _MessageLinkBuilder(onLink, referenceAppearance),
      'code': _MessageInlineCodeBuilder(),
    };
    final bulletStyle = recipe.body;
    final indent = documentMode
        ? MessageContentPrimitive.documentListIndent
        : MessageContentPrimitive.compactListIndent;
    // A compact row's label announces the prose; only its links stay.
    Widget compactProse(String markdown, Widget block) => compactSemantics
        ? RaftMessageProseSemantics(
            links: raftMessageSemanticsLinks(markdown),
            onLink: onLink,
            child: block,
          )
        : block;
    final proseSelection =
        enableProseSelection && chunks.any((c) => c.markdown);
    Widget selectable(Widget block) =>
        proseSelection ? SelectionContainer.disabled(child: block) : block;
    final blocks = <Widget>[
      for (final chunk in chunks)
        if (chunk.markdown)
          compactProse(
            chunk.text,
            _RaftMarkdown(
              data: chunk.text,
              styleSheet: resolveStyleSheets().$1,
              resolvedStyleSheet: resolveStyleSheets().$2,
              builders: builders,
              paddingBuilderFactory: () => recipe.headingPadding(chunk.text),
              onTapLink: (_, href, _) {
                if (href != null) onLink?.call(href);
              },
              bulletBuilder: (parameters) => RaftMarkdownListMarker(
                orderedIndex: parameters.style == BulletStyle.orderedList
                    ? parameters.index
                    : null,
                indent: indent,
                style: bulletStyle,
              ),
            ),
          )
        else
          // Code and diagram blocks keep their own selection and controls;
          // their labels never join the prose selection.
          selectable(
            chunk.mermaid
                ? RaftMermaidBlock(
                    source: chunk.text,
                    onCopy: onCopyCode,
                    onExport: onExportDiagram,
                    exportMode: exportMode,
                  )
                : RaftCodeBlock(
                    code: chunk.text,
                    language: chunk.language,
                    onCopy: onCopyCode,
                    exportMode: exportMode,
                    fontSize: fontSize,
                  ),
          ),
    ];
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
    if (!proseSelection) return body;
    // One selection region per message: prose blocks before and after a
    // code block share it, and a row mounts one region instead of several.
    return SelectionArea(
      // Message context menus belong to the message host.
      contextMenuBuilder: (_, _) => const SizedBox.shrink(),
      child: body,
    );
  }
}

/// MarkdownBody with the parse step memoised: same builder, style sheet,
/// defaults and widget output; only [md.Document.parseLines] is shared.
class _RaftMarkdown extends MarkdownBody {
  const _RaftMarkdown({
    required super.data,
    required MarkdownStyleSheet super.styleSheet,
    required this.resolvedStyleSheet,
    required Map<String, MarkdownElementBuilder> super.builders,
    required this.paddingBuilderFactory,
    required MarkdownTapLinkCallback super.onTapLink,
    required MarkdownBulletBuilder super.bulletBuilder,
  }) : super(softLineBreak: true);

  /// MarkdownBody's effective sheet: Material fallback merged with
  /// [styleSheet].
  final MarkdownStyleSheet resolvedStyleSheet;

  /// Heading padding builders carry per-build state, so each build gets
  /// fresh ones.
  final Map<String, MarkdownPaddingBuilder> Function() paddingBuilderFactory;

  @override
  State<MarkdownWidget> createState() => _RaftMarkdownState();
}

class _RaftMarkdownState extends State<MarkdownWidget>
    implements MarkdownBuilderDelegate {
  _RaftMarkdown get markdown => widget as _RaftMarkdown;
  List<Widget>? children;
  final recognizers = <GestureRecognizer>[];

  @override
  void didChangeDependencies() {
    rebuildChildren();
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(MarkdownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data ||
        widget.styleSheet != oldWidget.styleSheet) {
      rebuildChildren();
    }
  }

  @override
  void dispose() {
    disposeRecognizers();
    super.dispose();
  }

  void disposeRecognizers() {
    final current = List<GestureRecognizer>.of(recognizers);
    recognizers.clear();
    for (final recognizer in current) {
      recognizer.dispose();
    }
  }

  void rebuildChildren() {
    disposeRecognizers();
    children = MarkdownBuilder(
      delegate: this,
      selectable: false,
      styleSheet: markdown.resolvedStyleSheet,
      imageDirectory: null,
      imageBuilder: null,
      checkboxBuilder: null,
      bulletBuilder: widget.bulletBuilder,
      builders: widget.builders,
      paddingBuilders: markdown.paddingBuilderFactory(),
      fitContent: true,
      listItemCrossAxisAlignment: MarkdownListItemCrossAxisAlignment.baseline,
      onSelectionChanged: null,
      onTapText: null,
      softLineBreak: true,
    ).build(_parseMarkdown(widget.data));
  }

  @override
  GestureRecognizer createLink(String text, String? href, String title) {
    final recognizer = TapGestureRecognizer()
      ..onTap = () => widget.onTapLink?.call(text, href, title);
    recognizers.add(recognizer);
    return recognizer;
  }

  @override
  TextSpan formatText(MarkdownStyleSheet styleSheet, String code) => TextSpan(
    style: styleSheet.code,
    text: code.replaceAll(RegExp(r'\n$'), ''),
  );

  @override
  Widget build(BuildContext context) => children!.length == 1
      ? children!.single
      : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children!,
        );
}

class RaftMermaidBlock extends StatefulWidget {
  const RaftMermaidBlock({
    super.key,
    required this.source,
    this.onCopy,
    this.onExport,
    this.exportMode = false,
  });
  final bool exportMode;
  final String source;
  final Future<void> Function(String)? onCopy;
  final Future<void> Function(String, Uint8List)? onExport;
  @override
  State<RaftMermaidBlock> createState() => _RaftMermaidBlockState();
}

class _RaftMermaidBlockState extends State<RaftMermaidBlock> {
  bool showSource = false, copied = false;
  String? copyError;
  double zoom = 1;
  Offset pan = Offset.zero;
  core.RenderScene? scene;
  int revision = 0;
  bool? renderedDark;
  Timer? copiedTimer;
  DialogRoute<void>? expandedRoute;
  NavigatorState? expandedNavigator;
  void closeExpanded() {
    final route = expandedRoute, navigator = expandedNavigator;
    expandedRoute = null;
    expandedNavigator = null;
    if (route != null && navigator != null) {
      scheduleMicrotask(() {
        if (navigator.mounted && route.isActive) navigator.removeRoute(route);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dark = RaftTokens.of(context).dark;
    if (renderedDark != dark) {
      closeExpanded();
      revision++;
      scene = null;
      renderedDark = dark;
    }
  }

  @override
  void didUpdateWidget(RaftMermaidBlock old) {
    super.didUpdateWidget(old);
    if (old.source != widget.source) {
      closeExpanded();
      copiedTimer?.cancel();
      revision++;
      scene = null;
      copied = false;
      copyError = null;
      zoom = 1;
      pan = Offset.zero;
    }
  }

  @override
  void dispose() {
    revision++;
    copiedTimer?.cancel();
    closeExpanded();
    super.dispose();
  }

  Widget sourceText() => Semantics(
    label: widget.source,
    excludeSemantics: true,
    child: SelectableText(
      widget.source,
      style: TextStyle(
        fontFamily: RaftTokens.of(context).monoFont,
        fontSize: 14,
        height: 20 / 14,
        color: RaftCodeRecipe(RaftTokens.of(context)).foreground,
      ),
    ),
  );
  Widget diagram() {
    final current = revision;
    final content = widget.source;
    final dark = RaftTokens.of(context).dark;
    return MermaidDiagram(
      source: widget.source,
      theme: raftMermaidTheme(dark: RaftTokens.of(context).dark),
      semanticNodes: true,
      keepLastGoodSceneOnError: false,
      onSceneChanged: (value) {
        if (mounted &&
            current == revision &&
            content == widget.source &&
            renderedDark == dark)
          setState(() => scene = value);
      },
      errorBuilder: (context, error) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RaftIcon(
            RaftGlyph.image,
            size: 32,
            color: RaftTokens.of(context).muted,
          ),
          const SizedBox(height: 8),
          Text(
            raftText(context, "Couldn't render this diagram"),
            style: TextStyle(fontSize: 14, color: RaftTokens.of(context).muted),
          ),
        ],
      ),
    );
  }

  Future<void> copy() async {
    final current = revision, source = widget.source;
    try {
      if (widget.onCopy != null) {
        await widget.onCopy!(source);
      } else {
        await Clipboard.setData(ClipboardData(text: source));
      }
      if (!mounted || current != revision || source != widget.source) return;
      setState(() {
        copied = true;
        copyError = null;
      });
      copiedTimer?.cancel();
      copiedTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && current == revision) setState(() => copied = false);
      });
    } catch (_) {
      if (mounted && current == revision)
        setState(() => copyError = 'Could not copy code.');
    }
  }

  Future<void> export(String extension) async {
    if (widget.onExport == null) return;
    final current = revision;
    final content = widget.source;
    final dark = RaftTokens.of(context).dark;
    try {
      final Uint8List bytes;
      if (extension == 'mmd') {
        bytes = Uint8List.fromList(utf8.encode(content));
      } else {
        final rendered = scene;
        if (rendered == null) return;
        bytes = extension == 'png'
            ? await renderSceneToPng(rendered)
            : Uint8List.fromList(
                utf8.encode(
                  core
                      .renderSceneToSvg(rendered)
                      .replaceAll(RegExp(r'<a\s[^>]*>|</a>'), ''),
                ),
              );
      }
      try {
        if (!mounted ||
            current != revision ||
            content != widget.source ||
            dark != RaftTokens.of(context).dark)
          return;
        await widget.onExport!(extension, bytes);
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
    } catch (_) {
      if (mounted && current == revision)
        setState(() => copyError = 'Could not export diagram.');
    }
  }

  void expand() {
    if (expandedRoute?.isActive ?? false) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      builder: (dialogContext) => RaftAttachmentLightbox(
        title: raftText(dialogContext, 'Diagram'),
        closeLabel: 'Close',
        onClose: closeExpanded,
        child: ClipRect(
          child: Center(
            child: InteractiveViewer(
              minScale: .05,
              maxScale: 8,
              constrained: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: diagram(),
              ),
            ),
          ),
        ),
      ),
    );
    expandedRoute = route;
    expandedNavigator = navigator;
    navigator.push(route).whenComplete(() {
      if (identical(expandedRoute, route)) {
        expandedRoute = null;
        expandedNavigator = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftCodeRecipe(t);
    final surface = recipe.background;
    final border = t.brutal ? Colors.black : t.colors['line'] ?? t.line;
    final height = (MediaQuery.sizeOf(context).height * .5).clamp(320.0, 560.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        key: const ValueKey('mermaid-container'),
        width: double.infinity,
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: border, width: t.border),
          borderRadius: recipe.radius,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.exportMode)
                _MermaidToolbar(
                  showSource: showSource,
                  copied: copied,
                  valid: scene != null,
                  onSource: (value) => setState(() => showSource = value),
                  onCopy: copy,
                  onExpand: expand,
                  onZoom: (factor) =>
                      setState(() => zoom = (zoom * factor).clamp(.05, 8)),
                  onExport: widget.onExport == null ? null : export,
                ),
              if (copyError != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(raftText(context, copyError!)),
                  ),
                ),
              if (showSource)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 48, 12),
                  child: sourceText(),
                )
              else
                SizedBox(
                  key: const ValueKey('mermaid-viewport'),
                  height: height,
                  width: double.infinity,
                  child: ClipRect(
                    child: GestureDetector(
                      onPanUpdate: (details) =>
                          setState(() => pan += details.delta),
                      child: Center(
                        child: Transform.translate(
                          offset: pan,
                          child: Transform.scale(
                            scale: zoom,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: diagram(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MermaidToolbar extends StatelessWidget {
  const _MermaidToolbar({
    required this.showSource,
    required this.copied,
    required this.valid,
    required this.onSource,
    required this.onCopy,
    required this.onExpand,
    required this.onZoom,
    this.onExport,
  });
  final bool showSource, copied, valid;
  final ValueChanged<bool> onSource;
  final VoidCallback onCopy, onExpand;
  final ValueChanged<double> onZoom;
  final ValueChanged<String>? onExport;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabRecipe = RaftControlRecipe(
          t,
          kind: RaftControlKind.tab,
          visualHeight: RaftMetrics.buttonXs,
        );
        double tabWidth(String label) {
          final painter = TextPainter(
            text: TextSpan(
              text: raftText(context, label),
              style: tabRecipe.textStyle,
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final width =
              painter.width +
              tabRecipe.padding.horizontal +
              tabRecipe.iconSize +
              4 +
              2 * tabRecipe.side().width;
          painter.dispose();
          return width;
        }

        final toolbarRecipe = RaftMermaidToolbarRecipe(
          viewportWidth: raftBreakpointWidth(context),
          availableWidth: constraints.maxWidth,
          density: RaftDensityScope.of(context),
          showSource: showSource,
          diagramTabWidth: tabWidth('Diagram'),
          sourceTabWidth: tabWidth('Code'),
        );
        final desktop = toolbarRecipe.desktop;
        final line = t.brutal ? Colors.black : t.colors['line'] ?? t.line;
        Widget control(
          RaftGlyph icon,
          String tooltip,
          VoidCallback? action, {
          String? label,
          bool selected = false,
          bool ownTooltip = true,
        }) {
          if (label == null) {
            return RaftIconButton(
              glyph: icon,
              tooltip: ownTooltip ? tooltip : null,
              onPressed: action,
              visualSize: RaftMetrics.buttonSm,
              minimumTargetSize: toolbarRecipe.targetSize(RaftMetrics.buttonSm),
              glyphSize: RaftMetrics.iconSm,
              variant: RaftControlVariant.outline,
            );
          }
          return RaftControl(
            key: ValueKey((icon, desktop)),
            kind: RaftControlKind.tab,
            selected: selected,
            shadow: !t.brutal,
            onPressed: action,
            tooltip: raftText(context, tooltip),
            visualHeight: toolbarRecipe.tabVisualHeight,
            visualWidth: desktop ? null : RaftMetrics.buttonSm,
            padding: desktop ? null : EdgeInsets.zero,
            minimumTargetSize: toolbarRecipe.targetSize(
              toolbarRecipe.tabVisualHeight,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RaftIcon(icon, size: 13),
                if (desktop) ...[
                  const SizedBox(width: 4),
                  Text(raftText(context, label)),
                ],
              ],
            ),
          );
        }

        final wrap = toolbarRecipe.wrap;
        final controls = <Widget>[
          control(
            RaftGlyph.image,
            'Show diagram',
            () => onSource(false),
            label: 'Diagram',
            selected: !showSource,
          ),
          SizedBox(width: toolbarRecipe.gap),
          control(
            RaftGlyph.code2,
            'Show source',
            () => onSource(true),
            label: 'Code',
            selected: showSource,
          ),
          if (!wrap) const Spacer(),
          if (!showSource && desktop) ...[
            control(
              RaftGlyph.zoomOut,
              'Zoom Mermaid diagram out',
              valid ? () => onZoom(1 / 1.2) : null,
            ),
            SizedBox(width: toolbarRecipe.gap),
            control(
              RaftGlyph.zoomIn,
              'Zoom Mermaid diagram in',
              valid ? () => onZoom(1.2) : null,
            ),
            SizedBox(width: toolbarRecipe.gap),
          ],
          control(
            copied ? RaftGlyph.check : RaftGlyph.copy,
            copied ? 'Copied' : 'Copy code',
            onCopy,
          ),
          SizedBox(width: toolbarRecipe.gap),
          PopupMenuButton<String>(
            tooltip: raftText(context, 'Download Mermaid diagram'),
            enabled: onExport != null,
            onSelected: onExport,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'mmd', child: Text('Download source')),
              PopupMenuItem(
                value: 'png',
                enabled: valid,
                child: const Text('Download PNG'),
              ),
              PopupMenuItem(
                value: 'svg',
                enabled: valid,
                child: const Text('Download SVG'),
              ),
            ],
            padding: EdgeInsets.zero,
            child: IgnorePointer(
              child: control(
                RaftGlyph.download,
                'Download Mermaid diagram',
                onExport == null ? null : () {},
                ownTooltip: false,
              ),
            ),
          ),
          if (!showSource) ...[
            SizedBox(width: toolbarRecipe.gap),
            control(
              RaftGlyph.maximize2,
              'Expand diagram',
              valid ? onExpand : null,
            ),
          ],
        ];
        return Container(
          key: const ValueKey('mermaid-toolbar'),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: line, width: t.border),
            ),
          ),
          padding: RaftMermaidToolbarRecipe.inset,
          child: wrap
              ? Wrap(
                  spacing: 0,
                  runSpacing: toolbarRecipe.gap,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: controls,
                )
              : Row(children: controls),
        );
      },
    );
  }
}

/// Inline Markdown links need an explicit focus/action widget. The upstream
/// recognizer alone is pointer-only and omits the link URL from Web semantics.
/// `\uE000href\uE001label\uE002` → `raftref` element (see
/// [raftMessageReferences]).
class _ReferenceSentinelSyntax extends md.InlineSyntax {
  _ReferenceSentinelSyntax()
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

/// Message InlineCode is a splittable text run with CSS px-1 padding, not
/// an indivisible chip. Empty placeholders add layout space without changing
/// authored code or the text returned by selection and accessibility.
class _MessageInlineCodeBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    dynamic element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final style = (parentStyle ?? DefaultTextStyle.of(context).style).merge(
      preferredStyle,
    );
    final (metrics, height) = _inlineCodeMetrics(
      style,
      Directionality.of(context),
      MediaQuery.textScalerOf(context),
    );
    InlineSpan padding() => WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: ExcludeSemantics(
        child: Baseline(
          baseline: metrics.baseline,
          baselineType: TextBaseline.alphabetic,
          child: SizedBox(
            width: 4,
            height: height,
            child: ColoredBox(
              color: style.backgroundColor ?? Colors.transparent,
            ),
          ),
        ),
      ),
    );
    return Text.rich(
      TextSpan(
        children: [
          padding(),
          TextSpan(text: element.textContent as String, style: style),
          padding(),
        ],
      ),
    );
  }
}

class _MessageLinkBuilder extends MarkdownElementBuilder {
  _MessageLinkBuilder(this.onLink, this.appearanceOf);
  final ValueChanged<String>? onLink;
  final RaftReferenceAppearance? Function(String href)? appearanceOf;

  InlineSpan _reference(
    BuildContext context,
    String href,
    String label,
    TextStyle base,
    TextStyle? linkStyle,
  ) => raftReferenceSpan(
    context,
    label: label,
    href: href,
    base: base,
    linkStyle: linkStyle,
    appearance: appearanceOf?.call(href),
    onTap: onLink == null ? null : () => onLink!(href),
  );

  /// Returns a `Text.rich` so flutter_markdown merges the link (or the inline
  /// chip WidgetSpan) into the paragraph's single RichText; the sentence then
  /// wraps around it like CSS inline content instead of breaking the line.
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    dynamic element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final href = element.attributes['href'] as String?;
    if (href == null) return null;
    final label = element.textContent as String;
    final base = parentStyle ?? DefaultTextStyle.of(context).style;
    // Identity-backed references (`raft-ref:` hrefs, also nested inside an
    // authored link label as `raftref` elements) are focusable inline links.
    if (element.tag == 'raftref' || href.startsWith('raft-ref:')) {
      return Text.rich(
        TextSpan(
          children: [_reference(context, href, label, base, preferredStyle)],
        ),
      );
    }
    final linkStyle = base.merge(preferredStyle);
    final recognizer = onLink == null
        ? null
        : (TapGestureRecognizer()..onTap = () => onLink!(href));
    final children = (element.children as List?) ?? const [];
    return Text.rich(
      TextSpan(
        children: [
          for (final child in children)
            if (child is md.Element && child.tag == 'raftref')
              _reference(
                context,
                child.attributes['href'] ?? '',
                child.textContent,
                base,
                preferredStyle,
              )
            else
              TextSpan(
                text: (child as md.Node).textContent,
                style: linkStyle,
                recognizer: recognizer,
                mouseCursor: SystemMouseCursors.click,
                semanticsLabel: child.textContent,
              ),
        ],
      ),
    );
  }
}

final _codeHighlighter = Highlight();
final _nativeCodeLanguages = <String, Mode>{
  'bash': langBash,
  'c': langC,
  'clojure': langClojure,
  'cpp': langCpp,
  'csharp': langCsharp,
  'css': langCss,
  'dart': langDart,
  'diff': langDiff,
  'dockerfile': langDockerfile,
  'elixir': langElixir,
  'go': langGo,
  'graphql': langGraphql,
  'haskell': langHaskell,
  'java': langJava,
  'javascript': langJavascript,
  'json': langJson,
  'kotlin': langKotlin,
  'lua': langLua,
  'markdown': langMarkdown,
  'perl': langPerl,
  'php': langPhp,
  'python': langPython,
  'ruby': langRuby,
  'rust': langRust,
  'scala': langScala,
  'sql': langSql,
  'swift': langSwift,
  'typescript': langTypescript,
  'xml': langXml,
  'yaml': langYaml,
};
final _codeLanguageAliases = <String, String>{
  'c++': 'cpp',
  'cc': 'cpp',
  'cjs': 'javascript',
  'clj': 'clojure',
  'cljs': 'clojure',
  'cs': 'csharp',
  'cxx': 'cpp',
  'docker': 'dockerfile',
  'ex': 'elixir',
  'exs': 'elixir',
  'gql': 'graphql',
  'hs': 'haskell',
  'js': 'javascript',
  'kt': 'kotlin',
  'kts': 'kotlin',
  'lhs': 'haskell',
  'md': 'markdown',
  'mjs': 'javascript',
  'pl': 'perl',
  'perl5': 'perl',
  'py': 'python',
  'rb': 'ruby',
  'sh': 'bash',
  'shell': 'bash',
  'ts': 'typescript',
  'yml': 'yaml',
  'zsh': 'bash',
  'html': 'xml',
  'jsonc': 'json',
  'jsx': 'javascript',
  'tsx': 'typescript',
  'shellscript': 'bash',
};

/// Highlighted code spans are immutable and depend only on these inputs, so
/// a row that remounts, rebuilds or changes hover state reuses its tokens.
final raftCodeSpanCache =
    RaftLruCache<(String, String?, TextStyle, bool), TextSpan>(512);

TextSpan raftCodeSpan(
  String code,
  String? language,
  TextStyle style, {
  required bool dark,
}) => raftCodeSpanCache.putIfAbsent((
  code,
  language,
  style,
  dark,
), () => _highlightCode(code, language, style, dark: dark));

TextSpan _highlightCode(
  String code,
  String? language,
  TextStyle style, {
  required bool dark,
}) {
  var name = (language ?? '').trim().toLowerCase().replaceFirst(
    RegExp(r'^language-'),
    '',
  );
  name = _codeLanguageAliases[name] ?? name;
  if (code.length > 50 * 1024 ||
      code.split('\n').length > 500 ||
      !_nativeCodeLanguages.containsKey(name)) {
    return TextSpan(text: code, style: style);
  }
  try {
    _codeHighlighter.registerLanguage(name, _nativeCodeLanguages[name]!);
    final renderer = _ScopedCodeRenderer(
      style,
      dark ? _darkCodeTokenTheme : _lightCodeTokenTheme,
    );
    _codeHighlighter.highlight(code: code, language: name).render(renderer);
    return renderer.span;
  } catch (_) {
    return TextSpan(text: code, style: style);
  }
}

/// highlight.js node scopes use dotted semantic names. Its generated CSS themes
/// use underscore-suffixed class selectors; normalize those separately and
/// inherit a containing scope through unscoped token-tree nodes.
class _ScopedCodeRenderer implements HighlightRenderer {
  _ScopedCodeRenderer(this.base, this.theme);
  final TextStyle base;
  final Map<String, TextStyle> theme;
  final stack = <({TextStyle style, List<InlineSpan> children})>[];
  final roots = <InlineSpan>[];
  TextSpan get span => TextSpan(style: base, children: roots);
  @override
  void addText(String text) {
    final span = TextSpan(
      text: text,
      style: stack.isEmpty ? base : stack.last.style,
    );
    (stack.isEmpty ? roots : stack.last.children).add(span);
  }

  @override
  void openNode(DataNode node) {
    var scope = node.scope;
    TextStyle? style;
    while (scope != null) {
      style = theme[scope];
      if (style != null || !scope.contains('.')) break;
      scope = scope.substring(0, scope.lastIndexOf('.'));
    }
    stack.add((
      style: (stack.isEmpty ? base : stack.last.style).merge(style),
      children: <InlineSpan>[],
    ));
  }

  @override
  void closeNode(DataNode node) {
    final completed = stack.removeLast();
    (stack.isEmpty ? roots : stack.last.children).add(
      TextSpan(style: completed.style, children: completed.children),
    );
  }
}

/// Native tokenization uses the same supported language names as Web. The
/// tokenizer is highlight.js, so TextMate/Shiki token equivalence is audited
/// separately from typography, surfaces and copy behavior.
class RaftCodeBlock extends StatefulWidget {
  const RaftCodeBlock({
    super.key,
    required this.code,
    this.language,
    this.onCopy,
    this.exportMode = false,
    this.fontSize = 14,
  });
  final String code;
  final String? language;
  final Future<void> Function(String)? onCopy;
  final bool exportMode;
  final double fontSize;
  @override
  State<RaftCodeBlock> createState() => _RaftCodeBlockState();
}

class _RaftCodeBlockState extends State<RaftCodeBlock> {
  bool hovered = false, focused = false, copied = false;
  bool buttonHovered = false;
  String? error;
  int revision = 0;
  Timer? copiedTimer;
  Future<void> copy() async {
    final current = revision, source = widget.code;
    try {
      if (widget.onCopy != null) {
        await widget.onCopy!(source);
      } else {
        await Clipboard.setData(ClipboardData(text: source));
      }
      if (!mounted || current != revision || source != widget.code) return;
      setState(() {
        copied = true;
        error = null;
      });
      copiedTimer?.cancel();
      copiedTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && current == revision) setState(() => copied = false);
      });
    } catch (_) {
      if (mounted && current == revision)
        setState(() => error = 'Could not copy code.');
    }
  }

  @override
  void didUpdateWidget(RaftCodeBlock old) {
    super.didUpdateWidget(old);
    if (old.code != widget.code) {
      revision++;
      copiedTimer?.cancel();
      copied = false;
      error = null;
    }
  }

  @override
  void dispose() {
    revision++;
    copiedTimer?.cancel();
    super.dispose();
  }

  // The highlighted text box depends only on the code, language and theme.
  // Hover, focus and copy feedback rebuild the copy control, never re-run
  // tokenization or replace the selectable text widget.
  Widget? codeBox;
  Object? codeBoxKey;
  Widget buildCodeBox(RaftTokens t) {
    final recipe = RaftCodeRecipe(t);
    final textStyle = recipe.textStyle.copyWith(
      fontSize: widget.fontSize,
      color: recipe.foreground,
    );
    final key = (widget.code, widget.language, textStyle, t);
    if (codeBox != null && key == codeBoxKey) return codeBox!;
    codeBoxKey = key;
    final span = raftCodeSpan(
      widget.code,
      widget.language,
      textStyle,
      dark: t.dark,
    );
    return codeBox = Container(
      key: const ValueKey('code-container'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: recipe.background,
        border: Border.all(color: recipe.border, width: t.border),
        borderRadius: recipe.radius,
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 48, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectableText.rich(
          span,
          style: textStyle,
          textAlign: TextAlign.left,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final block = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: Focus(
          onFocusChange: (value) => setState(() => focused = value),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  buildCodeBox(t),
                  if (!widget.exportMode)
                    Positioned(
                      right: 8,
                      top: 8,
                      // index.css `.r-code-copy`: hidden; row hover or
                      // focus-visible .55; its own hover or copied 1;
                      // `@media (hover: none)` (touch) always .55.
                      child: MouseRegion(
                        onEnter: (_) => setState(() => buttonHovered = true),
                        onExit: (_) => setState(() => buttonHovered = false),
                        child: Opacity(
                          opacity: copied || buttonHovered
                              ? 1
                              : hovered ||
                                    focused ||
                                    RaftDensityScope.of(context) ==
                                        RaftDensity.touch
                              ? .55
                              : 0,
                          child: RaftIconButton(
                            glyph: copied ? RaftGlyph.check : RaftGlyph.copy,
                            tooltip: copied ? 'Copied' : 'Copy code',
                            onPressed: widget.code.isEmpty ? null : copy,
                            visualSize: RaftMetrics.buttonXs,
                            minimumTargetSize:
                                raftBreakpointWidth(context) < 768
                                ? RaftMetrics.touchTarget
                                : RaftMetrics.buttonXs,
                            glyphSize: RaftMetrics.iconSm,
                            variant: RaftControlVariant.ghost,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(raftText(context, error!)),
                ),
            ],
          ),
        ),
      ),
    );
    // One short node instead of the whole source (and a nested horizontal
    // scroll node): screen readers announce "Code block, N lines, language"
    // and activation copies the code, like the hover copy button.
    final canCopy = !widget.exportMode && widget.code.isNotEmpty;
    return Semantics(
      container: true,
      label: raftCodeBlockSemanticsLabel(context, widget.code, widget.language),
      value: error != null
          ? raftText(context, error!)
          : copied
          ? raftText(context, 'Copied')
          : null,
      liveRegion: error != null || copied,
      onTap: canCopy ? copy : null,
      onTapHint: canCopy ? raftText(context, 'Copy code') : null,
      excludeSemantics: true,
      child: block,
    );
  }
}

final _lightCodeTokenTheme = raftCodeTokenTheme(dark: false);
final _darkCodeTokenTheme = raftCodeTokenTheme(dark: true);

/// The source Shiki Github high contrast primitives mapped to the native
/// tokenizer's semantic scopes. Scope boundaries are independently compared.
Map<String, TextStyle> raftCodeTokenTheme({required bool dark}) {
  if (!dark)
    return {
      for (final entry in githubTheme.entries)
        entry.key
                .split('.')
                .map((scope) => scope.replaceFirst(RegExp(r'_+$'), ''))
                .join('.'):
            entry.value,
      'root': const TextStyle(color: Color(0xff24292e)),
    };
  const colors = <int, int>{
    0xffc9d1d9: 0xfff0f3f6,
    0xffff7b72: 0xffff9492,
    0xffd2a8ff: 0xffdbb7ff,
    0xff79c0ff: 0xff91cbff,
    0xffa5d6ff: 0xffaddcff,
    0xffffa657: 0xffffb757,
    0xff8b949e: 0xffbdc4cc,
    0xff7ee787: 0xff72f088,
  };
  return {
    for (final entry in githubDarkTheme.entries)
      entry.key
          .split('.')
          .map((scope) => scope.replaceFirst(RegExp(r'_+$'), ''))
          .join('.'): entry.key == 'root'
          ? const TextStyle(color: Color(0xfff0f3f6))
          : entry.value.copyWith(
              color: Color(
                colors[entry.value.color?.toARGB32()] ??
                    entry.value.color?.toARGB32() ??
                    0xfff0f3f6,
              ),
            ),
  };
}

// Space-glyph metrics per style/direction/scale, shared by every inline code
// span instead of measured again on each build.
final _inlineCodeMetricsCache =
    raftTextMetricsCache<
      (TextStyle, TextDirection, TextScaler),
      (LineMetrics, double)
    >();
(LineMetrics, double) _inlineCodeMetrics(
  TextStyle style,
  TextDirection direction,
  TextScaler scaler,
) => _inlineCodeMetricsCache.putIfAbsent((style, direction, scaler), () {
  final painter = TextPainter(
    text: TextSpan(text: ' ', style: style),
    textDirection: direction,
    textScaler: scaler,
  )..layout();
  final result = (painter.computeLineMetrics().single, painter.height);
  painter.dispose();
  return result;
});
