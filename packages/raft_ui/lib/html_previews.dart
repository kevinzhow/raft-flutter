import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('HTML preview')
Widget htmlPreview() => const _HtmlPreview();

class _HtmlPreview extends StatefulWidget {
  const _HtmlPreview();
  @override
  State<_HtmlPreview> createState() => _HtmlPreviewState();
}

class _HtmlPreviewState extends State<_HtmlPreview> {
  String status = 'No external action requested';
  final html = raftStaticHtml('''<h2>HTML · 中文と日本語</h2>
<p><strong>Native text</strong> with <em>emphasis</em> and
<a href="https://example.com/design">a design reference</a>.</p>
<table border="1"><tr><th>Step</th><th>Status</th></tr>
<tr><td>Review</td><td>Ready</td></tr></table>
<img src="file:///private/example.png" alt="Diagram image">
<script>document.body.innerHTML='This script must not run';</script>''');
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: RaftHtmlPreview(
          html: html,
          onLink: (_) => setState(() => status = 'External link requested'),
          onInteractive: () =>
              setState(() => status = 'Interactive preview requested'),
        ),
      ),
      Semantics(liveRegion: true, child: Text(status)),
    ],
  );
}
