import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'previews.dart';
import 'raft_ui.dart';

/// Reproducible same-size fixtures paired with the pinned mounted Web imports.
/// Product widgets own their layout; this wrapper only sets comparison viewport.
final class RichVisualPreviews extends MultiPreview {
  const RichVisualPreviews(this.component);
  final String component;
  @override
  List<Preview> get previews => [
    Preview(
      group: 'Visual rich',
      name: '$component · Brutal light',
      size: const Size(640, 480),
      wrapper: _brutal,
    ),
    Preview(
      group: 'Visual rich',
      name: '$component · Elegant light',
      size: const Size(640, 480),
      wrapper: _elegant,
    ),
    Preview(
      group: 'Visual rich',
      name: '$component · Elegant dark',
      size: const Size(640, 480),
      wrapper: _dark,
    ),
  ];
}

Widget _viewport(Widget child) => MediaQuery(
  data: const MediaQueryData(size: Size(640, 480)),
  child: child,
);
Widget _brutal(Widget child) => brutalWrapper(_viewport(child));
Widget _elegant(Widget child) => elegantWrapper(_viewport(child));
Widget _dark(Widget child) => darkWrapper(_viewport(child));

@RichVisualPreviews('Flowchart')
Widget visualFlowchart() => const _RichFixture(kind: 'flowchart');
@RichVisualPreviews('Sequence')
Widget visualSequence() => const _RichFixture(kind: 'sequence');
@RichVisualPreviews('Pie')
Widget visualPie() => const _RichFixture(kind: 'pie');
@RichVisualPreviews('Code')
Widget visualCode() => const _RichFixture(kind: 'code');
@RichVisualPreviews('Markdown')
Widget visualMarkdown() => const _RichFixture(kind: 'markdown');
@RichVisualPreviews('File chip')
Widget visualFileChip() => const _RichFixture(kind: 'attachment');

class _RichFixture extends StatefulWidget {
  const _RichFixture({required this.kind});
  final String kind;
  @override
  State<_RichFixture> createState() => _RichFixtureState();
}

class _RichFixtureState extends State<_RichFixture> {
  String? result;
  final hostKey = GlobalKey();
  final timers = <Timer>[];
  @override
  void initState() {
    super.initState();
    for (final ms in [500, 1500, 3000]) {
      timers.add(
        Timer(Duration(milliseconds: ms), () {
          if (mounted) measure();
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final timer in timers) {
      timer.cancel();
    }
    super.dispose();
  }

  void measure() {
    if (!mounted) return;
    final geometry = <Map<String, Object>>[];
    final host = hostKey.currentContext?.findRenderObject();
    final origin = host is RenderBox
        ? host.localToGlobal(Offset.zero)
        : Offset.zero;
    if (host is RenderBox && host.hasSize)
      geometry.add({
        'name': 'DIV',
        'flutter': {
          'x': 0.0,
          'y': 0.0,
          'width': host.size.width,
          'height': host.size.height,
        },
      });
    void visit(Element element) {
      final widget = element.widget;
      String? name;
      if (identical(widget.key, hostKey)) {
        name = 'DIV';
      }
      if (widget.key == const ValueKey('mermaid-toolbar')) {
        name = 'r-mermaid-toolbar';
      }
      if (widget.key == const ValueKey('mermaid-viewport')) {
        name = 'r-mermaid-viewport';
      }
      if (widget.key == const ValueKey('mermaid-container')) {
        name = 'r-mermaid-diagram';
      }
      if (widget.key == const ValueKey('code-container')) {
        name = 'code-container';
      }
      if (widget is RaftAttachmentCard) {
        name = widget.filename;
      }
      if (widget is Tooltip) {
        name = widget.message;
      }
      if (widget is Text && widget.data == 'report.pdf') {
        name = 'attachment-filename';
      }
      if (widget is Text && widget.data == 'PDF') {
        name = 'attachment-type-badge';
      }
      final render = element.findRenderObject();
      if (name != null && render is RenderBox && render.hasSize) {
        final offset = render.localToGlobal(Offset.zero) - origin;
        geometry.add({
          'name': name,
          'flutter': {
            'x': offset.dx,
            'y': offset.dy,
            'width': render.size.width,
            'height': render.size.height,
          },
        });
      }
      element.visitChildren(visit);
    }

    (hostKey.currentContext as Element?)?.visitChildren(visit);
    final t = RaftTokens.of(context);
    debugPrint(
      'RICH_VISUAL_GEOMETRY ${jsonEncode({'kind': widget.kind, 'theme': '${t.brutal ? 'brutal' : 'elegant'}-${t.dark ? 'dark' : 'light'}', 'geometry': geometry})}',
    );
  }

  static const inputs = {
    'flowchart': 'flowchart LR\n  A[Draft] --> B{Review}\n  B -->|Approved| C[Ship]\n  B -->|Changes| A',
    'sequence': 'sequenceDiagram\n  participant Alice\n  participant Bob\n  Alice->>Bob: Review draft\n  Bob-->>Alice: Approved',
    'pie': 'pie title Work\n  "Draft" : 3\n  "Review" : 2\n  "Ship" : 5',
    'code': '```typescript\nconst count = 3;\nfunction greet(name: string) {\n  return `Hello \${name}`;\n}\n```',
    'markdown': '# Release notes\n\nA **bold** plan with `inline code` and a [link](https://example.com).\n\n> Review before shipping.\n\n- Draft\n- Ship\n\n| Status | Count |\n| --- | --- |\n| Ready | 3 |',
  };
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: hostKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.kind == 'attachment')
          RaftAttachmentCard(
            filename: 'report.pdf',
            mimeType: 'application/pdf',
            sizeBytes: 4096,
            onOpen: () => setState(() => result = 'Preview requested'),
          )
        else
          RaftMessageBody(
            content: ['code', 'markdown'].contains(widget.kind)
                ? inputs[widget.kind]!
                : '```mermaid\n${inputs[widget.kind]}\n```',
            onCopyCode: (source) async =>
                setState(() => result = 'Copied actual source'),
            onExportDiagram: (extension, bytes) async => setState(
              () => result = 'Export $extension: ${bytes.length} bytes',
            ),
            onLink: (href) => setState(() => result = 'Opened $href'),
          ),
        if (result != null) Semantics(liveRegion: true, child: Text(result!)),
      ],
    ),
  );
}
