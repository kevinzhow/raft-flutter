import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:mermaid_flutter/mermaid_flutter.dart';

import 'localization.dart';
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
}) {
  final protected = RegExp(
    r'(`{3,}|~{3,})[^\n]*\n[\s\S]*?\1|`+[^`]*`+|!?\[[^\]]*\]\([^)]*\)|https?://[^\s]+',
  );
  String plain(String text) {
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
        if ((ref.text.startsWith('#') || ref.text.startsWith('dm:')) &&
            (right == ':' || right == '~')) {
          continue;
        }
        matches.add((start: m.start, end: m.end, label: m[0]!, href: ref.href));
      }
    }
    if (taskHref != null) {
      for (final m in RegExp(
        r'\btask[ \t]+#([1-9][0-9]*)\b',
        caseSensitive: false,
      ).allMatches(text)) {
        final start = m.end - m[1]!.length - 1;
        matches.add((
          start: start,
          end: m.end,
          label: '#${m[1]}',
          href: taskHref(int.parse(m[1]!)),
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
  for (final m in protected.allMatches(source)) {
    out.write(plain(source.substring(cursor, m.start)));
    out.write(m[0]);
    cursor = m.end;
  }
  out.write(plain(source.substring(cursor)));
  return out.toString();
}

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
    this.onCopyCode,
    this.exportMode = false,
  });
  final String content;
  final Future<void> Function(String)? onCopyCode;
  final double fontSize;
  final bool exportMode;
  final List<RaftTextReference> references;
  final String Function(int)? taskHref;
  final ValueChanged<String>? onLink;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final prepared = raftMessageReferences(
      content,
      references: references,
      taskHref: taskHref,
    );
    final blocks = <Widget>[];
    final lines = prepared.split('\n');
    final markdown = StringBuffer();
    void flush() {
      if (markdown.isEmpty) return;
      blocks.add(
        SelectionArea(
          child: MarkdownBody(
            builders: {'a': _MessageLinkBuilder(onLink)},
            data: markdown.toString(),
            softLineBreak: true,
            onTapLink: (_, href, _) {
              if (href != null) onLink?.call(href);
            },
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                .copyWith(
                  p: TextStyle(fontSize: fontSize, height: 1.5, color: t.ink),
                  a: TextStyle(
                    color: t.accent,
                    decoration: TextDecoration.underline,
                  ),
                  code: TextStyle(
                    fontFamily: 'packages/raft_ui/GeistMono',
                    fontSize: 12,
                    color: t.ink,
                    backgroundColor: t.sidebar,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: t.sidebar,
                    borderRadius: BorderRadius.circular(t.radius),
                  ),
                ),
          ),
        ),
      );
      markdown.clear();
    }

    for (var i = 0; i < lines.length; i++) {
      final start = RegExp(
        r'^ {0,3}(`{3,}|~{3,})\s*mermaid\s*$',
        caseSensitive: false,
      ).firstMatch(lines[i]);
      if (start == null) {
        // A Mermaid-looking fence inside another code block is literal code.
        final other = RegExp(r'^ {0,3}(`{3,}|~{3,})').firstMatch(lines[i]);
        markdown.writeln(lines[i]);
        if (other != null) {
          final fence = other[1]!;
          while (++i < lines.length) {
            markdown.writeln(lines[i]);
            if (RegExp(
              '^ {0,3}${RegExp.escape(fence[0])}{${fence.length},}\\s*\$',
            ).hasMatch(lines[i])) {
              break;
            }
          }
        }
        continue;
      }
      final fence = start[1]!;
      var end = i + 1;
      while (end < lines.length &&
          !RegExp('^ {0,3}${RegExp.escape(fence[0])}{${fence.length},}\\s*\$')
              .hasMatch(lines[end])) {
        end++;
      }
      if (end == lines.length) {
        markdown.writeln(lines[i]);
        continue;
      }
      flush();
      blocks.add(
        RaftMermaidBlock(
          source: lines.sublist(i + 1, end).join('\n'),
          onCopy: onCopyCode,
          exportMode: exportMode,
        ),
      );
      i = end;
    }
    flush();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks
          .map(
            (b) => Padding(padding: const EdgeInsets.only(bottom: 8), child: b),
          )
          .toList(),
    );
  }
}

class RaftMermaidBlock extends StatefulWidget {
  const RaftMermaidBlock({
    super.key,
    required this.source,
    this.onCopy,
    this.exportMode = false,
  });
  final bool exportMode;
  final String source;
  final Future<void> Function(String)? onCopy;
  @override
  State<RaftMermaidBlock> createState() => _RaftMermaidBlockState();
}

class _RaftMermaidBlockState extends State<RaftMermaidBlock> {
  bool showSource = false, copied = false;
  String? copyError;
  Widget sourceText() => Semantics(
    label: widget.source,
    child: ExcludeSemantics(
      child: SelectableText(
        widget.source,
        style: const TextStyle(fontFamily: 'packages/raft_ui/GeistMono'),
      ),
    ),
  );
  Widget diagram() => MermaidDiagram(
    source: widget.source,
    theme: MaterialMermaidTheme.fromTheme(Theme.of(context)),
    semanticNodes: true,
    keepLastGoodSceneOnError: false,
    errorBuilder: (context, error) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          raftText(
            context,
            'Unable to render this diagram. The source is shown below.',
          ),
          style: TextStyle(color: RaftTokens.of(context).muted),
        ),
        const SizedBox(height: 8),
        sourceText(),
      ],
    ),
  );
  Future<void> copy() async {
    try {
      if (widget.onCopy != null) {
        await widget.onCopy!(widget.source);
      } else {
        await Clipboard.setData(ClipboardData(text: widget.source));
      }
      if (mounted) {
        setState(() {
          copied = true;
          copyError = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => copyError = 'Could not copy code.');
    }
  }

  void expand() => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: SizedBox(
        width: 1000,
        height: 700,
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 16),
                const Expanded(child: Text('Mermaid')),
                IconButton(
                  tooltip: raftText(context, 'Close'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: .1,
                maxScale: 8,
                constrained: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: diagram(),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.panel,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(t.radius),
      ),
      child: Material(
        color: t.panel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.exportMode)
              Row(
                children: [
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Mermaid')),
                  IconButton(
                    tooltip: raftText(
                      context,
                      showSource ? 'Show diagram' : 'Show source',
                    ),
                    onPressed: () => setState(() => showSource = !showSource),
                    icon: Icon(
                      showSource ? Icons.account_tree_outlined : Icons.code,
                    ),
                  ),
                  IconButton(
                    tooltip: raftText(context, copied ? 'Copied' : 'Copy code'),
                    onPressed: copy,
                    icon: Icon(copied ? Icons.check : Icons.copy),
                  ),
                  IconButton(
                    tooltip: raftText(context, 'Expand diagram'),
                    onPressed: expand,
                    icon: const Icon(Icons.open_in_full),
                  ),
                ],
              ),
            if (copyError != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(raftText(context, copyError!)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: showSource
                  ? sourceText()
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topLeft,
                        child: diagram(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline Markdown links need an explicit focus/action widget. The upstream
/// recognizer alone is pointer-only and omits the link URL from Web semantics.
class _MessageLinkBuilder extends MarkdownElementBuilder {
  _MessageLinkBuilder(this.onLink);
  final ValueChanged<String>? onLink;
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    dynamic element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final href = element.attributes['href'] as String?;
    if (href == null) return null;
    return _MessageLink(
      label: element.textContent as String,
      href: href,
      style: parentStyle?.merge(preferredStyle),
      onLink: onLink,
    );
  }
}

class _MessageLink extends StatefulWidget {
  const _MessageLink({
    required this.label,
    required this.href,
    this.style,
    this.onLink,
  });
  final String label, href;
  final TextStyle? style;
  final ValueChanged<String>? onLink;
  @override
  State<_MessageLink> createState() => _MessageLinkState();
}

class _MessageLinkState extends State<_MessageLink> {
  bool focused = false;
  void openLink() => widget.onLink?.call(widget.href);
  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    onShowFocusHighlight: (value) => setState(() => focused = value),
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          openLink();
          return null;
        },
      ),
    },
    child: Semantics(
      link: true,
      linkUrl: Uri.tryParse(widget.href),
      label: widget.label,
      onTap: widget.onLink == null ? null : openLink,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: openLink,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: focused
                    ? Border.all(color: RaftTokens.of(context).accent)
                    : null,
              ),
              child: Text(widget.label, style: widget.style),
            ),
          ),
        ),
      ),
    ),
  );
}
