import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('HTML region comment capture', size: Size(856, 944))
Widget htmlRegionCommentPreview() => const _Preview();

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  final comments = RaftAttachmentCommentState()..commentMode = true;
  final geometry = _Geometry();
  @override
  void initState() {
    super.initState();
    comments.addListener(changed);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    comments.removeListener(changed);
    comments.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RaftAttachmentCommentScope(
    state: comments,
    child: Column(
      children: [
        Expanded(
          child: RaftHtmlRegionCommentSurface(
            controller: geometry,
            enabled: true,
            child: const SingleChildScrollView(
              child: RaftMessageBody(
                documentMode: true,
                content: '# Preview region\n\nOn a pointer, drag a region here. Stored regions also open on touch.\n\n## Details\n\nA renderer supplies bounded document coordinates.',
              ),
            ),
          ),
        ),
        Wrap(
          children: [
            if (comments.pendingAnchor != null)
              RaftCommentAnchorChip(
                label: 'Preview region',
                removeLabel: 'Remove Anchor',
                onRemove: comments.clearAnchor,
              ),
            RaftButton.text(
              onPressed: () => comments.jump(_Geometry.region.anchor),
              child: const Text('Jump to stored region'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Geometry implements RaftHtmlRegionController {
  static const region = RaftHtmlRegion(
    rect: Rect.fromLTWH(20, 90, 220, 70),
    viewportWidth: 856,
    document: Size(856, 1200),
    quote: 'Preview region',
  );
  @override
  bool get active => true;
  @override
  Future<RaftHtmlGeometry?> measure(Size host) async => RaftHtmlGeometry(
    viewport: host,
    visible: host,
    scroll: Offset.zero,
    document: Size(host.width, 1200),
  );
  @override
  Future<RaftHtmlRegionLocation?> capture(Rect rect, Size host) async =>
      RaftHtmlRegionLocation(
        (await measure(host))!,
        RaftHtmlRegion(
          rect: rect,
          viewportWidth: host.width,
          document: Size(host.width, 1200),
          quote: 'Preview region',
        ),
      );
  @override
  Future<RaftHtmlRegionLocation?> jump(
    RaftHtmlRegion region,
    Size host,
  ) async => RaftHtmlRegionLocation((await measure(host))!, region);
  @override
  Future<RaftHtmlGeometry?> scrollBy(Offset delta, Size host) => measure(host);
}
