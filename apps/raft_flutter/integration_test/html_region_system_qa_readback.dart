// Read-only observations of the real product tree and rendered document.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

Map<String, Object?> htmlRegionSystemQaTree(GlobalKey previewKey) {
  RaftAttachmentCommentState? session;
  final controls = <Map<String, Object?>>[];
  final drafts = <String>[];
  final visibleText = <String>[];
  void visit(Element element) {
    final widget = element.widget;
    if (widget is RaftAttachmentCommentScope) session = widget.notifier;
    if (widget is EditableText) drafts.add(widget.controller.text);
    if (widget is Text && widget.data != null) visibleText.add(widget.data!);
    final key = widget.key;
    final label = switch (widget) {
      RaftInteractive() => widget.semanticLabel ?? widget.tooltip,
      RaftLightboxIconAction() => widget.label,
      EditableText() => 'comment-editor',
      _ => null,
    };
    if (label != null || key is ValueKey<String>) {
      final box = element.findRenderObject();
      if (box is RenderBox &&
          box.attached &&
          box.hasSize &&
          !box.size.isEmpty) {
        final position = box.localToGlobal(Offset.zero);
        controls.add({
          'label': label,
          'key': key is ValueKey<String> ? key.value : null,
          'rect': [position.dx, position.dy, box.size.width, box.size.height],
          if (widget is RaftInteractive) 'enabled': widget.onPressed != null,
          if (widget is RaftLightboxIconAction) 'active': widget.active,
        });
      }
    }
    element.visitChildren(visit);
  }

  final root = previewKey.currentContext;
  if (root is Element) visit(root);
  return {
    'commentMode': session?.commentMode,
    'pendingAnchor': session?.pendingAnchor,
    'controls': controls,
    'drafts': drafts,
    'visibleText': visibleText,
  };
}

const htmlRegionSystemQaDocumentReadback = '''JSON.stringify((()=>{
 const rect=id=>{
  const e=document.getElementById(id);if(!e)return null;
  const r=e.getBoundingClientRect();
  return {x:r.x,y:r.y,width:r.width,height:r.height,text:e.innerText};
 };
 return {
  title:document.title,counter:Number(document.getElementById('count').textContent),
  scroll:[scrollX,scrollY],viewport:[innerWidth,innerHeight],
  documentSize:[document.documentElement.scrollWidth,document.documentElement.scrollHeight],
  origin:self.origin,appBridge:typeof window.flutter_inappwebview,
  buttons:{increment:rect('increment'),reflow:rect('reflow')},
  blocks:{alpha:rect('alpha'),beta:rect('beta'),quote:rect('quote'),gamma:rect('gamma')},
  clicks:window.qaClicks,inputs:window.qaInputs,reflows:window.qaReflows
 };
})())''';
