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
    final slots = RaftDialogSlots.of(context);
    final body = KeyedSubtree(key: _body, child: d.content!);
    final footer = KeyedSubtree(
      key: _footer,
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: slots.footer.columnGap ?? 0,
        runSpacing: slots.footer.rowGap ?? 0,
        children: d.actions!,
      ),
    );
    if (RaftFormFrame.sheetOf(context)) {
      return RaftFormSheet(
        title: raftText(context, d.title! as String),
        onClose: d.onClose,
        body: body,
        footer: footer,
      );
    }
    return RaftDialog(
      title: d.title,
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
