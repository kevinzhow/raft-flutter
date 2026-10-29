import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Routes a paste through attachment inspection while retaining its text.
class RaftComposerPasteAction extends ContextAction<PasteTextIntent> {
  RaftComposerPasteAction(this.handler);

  final Future<bool> Function()? Function() handler;

  @override
  bool isEnabled(PasteTextIntent intent, [BuildContext? context]) =>
      callingAction?.isEnabled(intent) ?? true;

  @override
  Object? invoke(PasteTextIntent intent, [BuildContext? context]) {
    final take = handler();
    final editor = context?.findAncestorStateOfType<EditableTextState>();
    if (take == null || editor == null) return callingAction?.invoke(intent);
    return pasteComposerClipboard(editor, take, cause: intent.cause);
  }
}

/// Captures text before asynchronous attachment reads can outlive its provider.
///
/// The focused editor still owns formatters, selection, change notification and
/// undo. A disposed, replaced, read-only or unfocused editor rejects completion.
Future<void> pasteComposerClipboard(
  EditableTextState editor,
  Future<bool> Function() takeAttachments, {
  required SelectionChangedCause cause,
}) async {
  final controller = editor.widget.controller;
  bool current() =>
      editor.mounted &&
      identical(editor.widget.controller, controller) &&
      !editor.widget.readOnly &&
      editor.widget.focusNode.hasFocus;
  ClipboardData? snapshot;
  try {
    snapshot = await Clipboard.getData(Clipboard.kTextPlain);
  } catch (_) {
    // Clipboard text may be unavailable while files remain readable.
  }
  if (!current()) return;
  var taken = false;
  try {
    taken = await takeAttachments();
  } catch (_) {
    // An attachment failure still permits the captured text paste.
  }
  if (taken || snapshot?.text == null || !current()) {
    return;
  }
  final value = editor.textEditingValue,
      selection = editor.textEditingValue.selection;
  if (!selection.isValid) return;
  final end = selection.end;
  editor.userUpdateTextEditingValue(
    value
        .copyWith(selection: TextSelection.collapsed(offset: end))
        .replaced(selection, snapshot!.text!),
    cause,
  );
  if (cause == SelectionChangedCause.toolbar) {
    editor.bringIntoView(editor.textEditingValue.selection.extent);
    editor.hideToolbar();
  }
}
