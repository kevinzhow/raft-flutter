part of 'dialog.dart';

class _ShellDialogParts extends StatefulWidget {
  const _ShellDialogParts({required this.dialog});
  final RaftDialog dialog;
  @override
  State<_ShellDialogParts> createState() => _ShellDialogPartsState();
}

class _ShellDialogPartsState extends State<_ShellDialogParts> {
  final _body = GlobalKey(debugLabel: 'dialog body');
  final _footer = GlobalKey(debugLabel: 'dialog footer');
  @override
  Widget build(BuildContext context) {
    final d = widget.dialog;
    final body = d.content == null
        ? null
        : KeyedSubtree(key: _body, child: d.content!);
    final footer = RaftDialogActions(key: _footer, children: d.actions!);
    final title = d.title! as String;
    if (RaftFormFrame.sheetOf(context)) {
      return RaftFormSheet(
        title: raftText(context, title),
        onClose: d.onClose,
        body: body ?? const SizedBox.shrink(),
        footer: footer,
      );
    }
    return RaftDialog(
      title: d._cssShellTitle
          ? RaftDialogTitle(title, cssLineBox: true)
          : title,
      semanticLabel: title,
      content: body,
      actions: [footer],
      maxWidth: d.maxWidth,
      contentKey: d.contentKey,
      onClose: raftGuardedClose(context, d.onClose),
      closeEnabled: d.closeEnabled,
      outlineClose: d.outlineClose,
    );
  }
}
