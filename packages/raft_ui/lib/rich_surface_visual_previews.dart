import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'raft_ui.dart';
import 'rich_visual_previews.dart';

@RichVisualPreviews('Forwarded snapshot')
Widget visualForwardedSnapshot() => const _SurfaceFixture(kind: 'forwarded');
@RichVisualPreviews('Forwarded long source')
Widget visualForwardedLongSource() => const _SurfaceFixture(kind: 'forwarded-long');
@RichVisualPreviews('Outside list markers')
Widget visualOutsideListMarkers() => const _SurfaceFixture(kind: 'list-markers');
@RichVisualPreviews('Collapsed table borders')
Widget visualCollapsedTableBorders() => const _SurfaceFixture(kind: 'table-borders');
@RichVisualPreviews('Action card')
Widget visualActionCard() => const _SurfaceFixture(kind: 'action');
@RichVisualPreviews('Collapsed prose')
Widget visualCollapsedProse() => const _SurfaceFixture(kind: 'collapsible');
@RichVisualPreviews('Image gallery')
Widget visualImageGallery() => const _SurfaceFixture(kind: 'gallery');
@RichVisualPreviews('Attachment lightbox')
Widget visualAttachmentLightbox() => const _SurfaceFixture(kind: 'lightbox');
@RichVisualPreviews('Document sheet')
Widget visualDocumentSheet() => const _SurfaceFixture(kind: 'document');

/// Public synthetic content matches additional-reference-fixture.js exactly.
/// The source eight-line rule folds body content, excluding author metadata.
Map<String, dynamic> visualForwardedMetadata() => {
  'kind': 'forwarded-bundle', 'version': 1, 'forwardedItems': [
    {'index': 0, 'contentSnapshot': 'A **bold** plan with `inline code`.\n${List.generate(10, (i) => 'Public forwarded line ${i + 1}.').join('\n')}',
      'sourceAuthorSnapshot': {'type': 'user', 'uniqueName': 'Alice'},
      'sourceTargetSnapshot': {'id': 'public-design', 'type': 'channel', 'label': '#design', 'labelVisibility': 'public'},
      'attachmentPolicy': 'excluded', 'provenanceState': 'available'},
    {'index': 1, 'contentSnapshot': 'Review before shipping.\n\n- Draft\n- Ship',
      'sourceAuthorSnapshot': {'type': 'user', 'uniqueName': 'Bob'},
      'attachmentPolicy': 'excluded', 'provenanceState': 'original_unavailable'},
    {'index': 2, 'contentSnapshot': 'Approved.',
      'sourceAuthorSnapshot': {'type': 'user', 'uniqueName': 'Alice'},
      'attachmentPolicy': 'excluded', 'provenanceState': 'available'},
  ],
};

class _SurfaceFixture extends StatefulWidget {
  const _SurfaceFixture({required this.kind});
  final String kind;
  @override
  State<_SurfaceFixture> createState() => _SurfaceFixtureState();
}

class _SurfaceFixtureState extends State<_SurfaceFixture> {
  final hostKey = GlobalKey();
  final timers = <Timer>[];
  Map<String, dynamic>? metadata;
  String? result;
  bool lightboxOpen = true;
  @override
  void initState() {
    super.initState();
    metadata = visualForwardedMetadata();
    if (widget.kind == 'forwarded-long') {
      final first = (metadata!['forwardedItems'] as List).first as Map;
      (first['sourceTargetSnapshot'] as Map)['label'] = '#a-very-long-public-channel-name-that-needs-truncation';
    }
    for (final ms in [500, 1500, 3000]) {
      timers.add(Timer(Duration(milliseconds: ms), measure));
    }
  }
  @override
  void dispose() {
    for (final timer in timers) { timer.cancel(); }
    super.dispose();
  }
  void measure() {
    if (!mounted) return;
    final host = hostKey.currentContext?.findRenderObject();
    if (host is! RenderBox || !host.hasSize) return;
    final origin = host.localToGlobal(Offset.zero);
    final geometry = <Map<String, Object>>[];
    void visit(Element element) {
      final widget = element.widget;
      final name = switch (widget) {
        RaftForwardedBundle() => 'forwarded-bundle-card',
        RaftActionCard() => 'action-card',
        RaftCollapsible() => 'message-collapsible',
        RaftAttachmentGallery() => 'image-gallery',
        RaftAttachmentLightbox() => 'attachment-lightbox',
        Tooltip(:final message) => message,
        RaftShowMoreToggle(:final label) => label,
        Text(:final data) when data?.startsWith('from ') == true => 'forwarded-bundle-source-label',
        _ => null,
      };
      final render = element.findRenderObject();
      if (name != null && render is RenderBox && render.hasSize) {
        final position = render.localToGlobal(Offset.zero) - origin;
        geometry.add({'name': name, 'flutter': {'x': position.dx, 'y': position.dy,
          'width': render.size.width, 'height': render.size.height}});
      }
      element.visitChildren(visit);
    }
    (hostKey.currentContext as Element).visitChildren(visit);
    final t = RaftTokens.of(context);
    debugPrint('RICH_VISUAL_GEOMETRY ${jsonEncode({'kind': widget.kind, 'theme': '${t.brutal ? 'brutal' : 'elegant'}-${t.dark ? 'dark' : 'light'}', 'geometry': geometry})}');
  }
  Widget gallery() => RaftAttachmentGallery(
    dimensions: const [(width: 100, height: 100), (width: 100, height: 100), (width: 100, height: 100), (width: 100, height: 100)],
    itemBuilder: (index, extent, fit) => RaftAttachmentCard(
      filename: 'public-${index + 1}.png', mimeType: 'image/png', imageExtent: extent,
      preview: ColoredBox(color: [Colors.blue, Colors.red, Colors.green, Colors.amber][index]),
      onOpen: () => setState(() => result = 'Preview public-${index + 1}.png'),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final child = switch (widget.kind) {
      'forwarded' || 'forwarded-long' => RaftForwardedBundle(metadata: metadata!),
      'list-markers' => const RaftMessageBody(content: '- First\n  - Nested\n- Second\n\n99. First ordinal\n100. Second ordinal'),
      'table-borders' => const RaftMessageBody(content: '| Status | Count |\n|---|---|\n|Draft|3|\n|Review|4|\n|Ready|5|'),
      'action' => const RaftActionCard(title: 'Create public channel #design', state: 'executed',
        details: [(label: 'Description', value: 'Review before shipping.')],
        hint: 'Public component fixture.', completedBy: 'Kevin'),
      'collapsible' => RaftCollapsible(child: RaftMessageBody(content: List.generate(24, (i) => 'Public review paragraph ${i + 1}.').join('\n\n'))),
      'gallery' => gallery(),
      'lightbox' => !lightboxOpen ? RaftButton(label: 'Open preview', onPressed: () => setState(() => lightboxOpen = true)) : RaftAttachmentLightbox(title: 'public.png', titleBold: true,
        onClose: () => setState(() { lightboxOpen = false; result = 'Closed actual preview'; }),
        child: const Center(child: SizedBox(width: 320, height: 180, child: ColoredBox(color: Colors.blue))),
        footer: RaftTextButton(label: 'Download original', glyph: RaftGlyph.download, onPressed: () => setState(() => result = 'Download requested'))),
      'document' => const SizedBox(height: 480, child: RaftDocumentPreview(data: {'kind': 'xlsx', 'sheets': [
        {'name': 'First', 'headers': ['Status', 'Count'], 'rows': [['Draft', '3']]},
        {'name': 'Second', 'headers': ['Status', 'Count'], 'rows': [['Ready', '5']]},
      ]})),
      _ => const SizedBox(),
    };
    return SizedBox(key: hostKey, width: 640, height: 480, child: widget.kind == 'lightbox' ? child : SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      child, if (result != null) Semantics(liveRegion: true, child: Text(result!)),
    ])));
  }
}
