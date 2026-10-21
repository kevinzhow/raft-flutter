import 'text_selection_toolbar.dart';

import 'package:flutter/material.dart';

import 'localization.dart';

import 'components.dart';
import 'dialog_card.dart' show RaftCloseButton;
import 'dismiss_scope.dart';
import 'form_presentation.dart';
import 'settings_layout.dart' show RaftSpace;
import 'error_presentation.dart';
import 'theme.dart';
import 'design_primitives.dart';
import 'icons.dart';

class RaftFormField {
  const RaftFormField(
    this.id,
    this.label, {
    this.initial = '',
    this.required = false,
    this.multiline = false,
    this.obscure = false,
    this.trim = true,
    this.choices,
    this.localizeChoices = true,
    this.help,
    this.validator,
  });
  final String id, label, initial;
  final bool required, multiline, obscure, trim, localizeChoices;
  final Map<String, String>? choices;
  final String? help;
  final String? Function(String)? validator;
}

/// Owns each editor for the full dialog route lifetime, including its exit
/// transition. Failed submissions keep the values and focus in the dialog.
///
/// Opened with [showRaftForm] it is a bottom sheet below 768 (the title and
/// close button pinned above, the fields scrolling, Cancel / submit pinned
/// below the fields, above the keyboard) and an `AlertDialog` from 768, in the
/// same route: crossing the breakpoint keeps the typed text, the focus and the
/// caret. Opened with a plain `showDialog` it is the dialog.
class RaftFormDialog extends StatefulWidget {
  const RaftFormDialog({
    super.key,
    required this.title,
    required this.fields,
    required this.onSubmit,
    this.submitLabel = 'Save',
    this.description,
    this.destructive = false,
    this.extra,
    this.errorFallback,
    this.errorContent,
    this.submitEnabled = true,
    this.busyLabel,
  });
  final String title, submitLabel;

  /// False keeps the submit action disabled (Web `disabled={!target}`).
  final bool submitEnabled;

  /// The submit action's catalog text while the submit is in flight (Web
  /// "Starting migration…" in place of the idle label); null keeps
  /// [submitLabel].
  final String? busyLabel;

  /// Rich content for a failed submit (a banner with details and a recovery
  /// action) in place of the plain error banner. Returning null for an error
  /// keeps the plain banner.
  final Widget? Function(BuildContext context, Object error)? errorContent;

  /// The surface's Web fallback message, shown when a failed submit carries no
  /// server text (`err.response?.data?.error || formatMessage(fallback)`).
  final String? errorFallback;
  final String? description;
  final bool destructive;
  final Widget? extra;
  final List<RaftFormField> fields;
  final Future<void> Function(Map<String, String>) onSubmit;
  @override
  State<RaftFormDialog> createState() => _RaftFormDialogState();
}

class _RaftFormDialogState extends State<RaftFormDialog> {
  final form = GlobalKey<FormState>();
  final editors = <String, TextEditingController>{};
  final choices = <String, String>{};
  bool busy = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next submit starts, validation included; the dialog state is dropped when it closes.
  String? error;
  // ignore: raft_lints/avoid_imperative_notice_state -- Same lifetime as [error]: cleared when the next submit starts.
  Widget? errorWidget;

  /// Keeps one editor / selection per current field: the dialog can be rebuilt
  /// with another field set (e.g. after its inputs load) and submit() and the
  /// field widgets read these maps by field id.
  void _sync() {
    final ids = {for (final f in widget.fields) f.id};
    for (final id in editors.keys.toList()) {
      if (!ids.contains(id)) editors.remove(id)!.dispose();
    }
    for (final id in choices.keys.toList()) {
      if (!ids.contains(id)) choices.remove(id);
    }
    for (final field in widget.fields) {
      editors.putIfAbsent(
        field.id,
        () => TextEditingController(text: field.initial),
      );
      if (field.choices != null) {
        choices.putIfAbsent(
          field.id,
          () =>
              field.initial.isEmpty ? field.choices!.keys.first : field.initial,
        );
      }
    }
  }

  /// A choice moved off the value it opened with (the guard asks before a
  /// close throws it away).
  bool _choicesChanged() => widget.fields.any(
    (f) =>
        f.choices != null &&
        choices[f.id] !=
            (f.initial.isEmpty ? f.choices!.keys.first : f.initial),
  );

  RaftUnsavedGuardState? _guard;

  @override
  void initState() {
    super.initState();
    _sync();
    _guard = RaftUnsavedGuard.maybeOf(context)?..watch(_choicesChanged);
  }

  @override
  void didUpdateWidget(RaftFormDialog old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _guard?.unwatch(_choicesChanged);
    for (final editor in editors.values) {
      editor.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    // Web: every submit starts with `setError("")`, validation included, so a
    // rejection of the previous values does not outlive them.
    if (error != null || errorWidget != null) {
      setState(() {
        error = null;
        errorWidget = null;
      });
    }
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.onSubmit({
        for (final field in widget.fields)
          field.id: field.choices == null
              ? (field.trim
                    ? editors[field.id]!.text.trim()
                    : editors[field.id]!.text)
              : choices[field.id]!,
      });
      // Authority guards can remove this route while an awaited submission
      // completes. Its stale context must never pop the underlying home route.
      if (mounted && ModalRoute.of(context)?.isCurrent == true)
        Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        final custom = widget.errorContent?.call(context, e);
        setState(() {
          errorWidget = custom;
          error = custom == null
              ? raftErrorMessage(context, e, fallback: widget.errorFallback)
              : null;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _field(RaftFormField field) {
    final t = RaftTokens.of(context);
    final label = raftText(context, field.label);
    final decoration = InputDecoration(
      helperText: field.help == null ? null : raftText(context, field.help!),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: label,
            child: ExcludeSemantics(
              child: Text(
                label.toUpperCase(),
                style: RaftTypography.heading(
                  t,
                  size: 14,
                  line: 20,
                  weight: t.brutal ? FontWeight.w700 : FontWeight.w500,
                ).copyWith(letterSpacing: .35),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Semantics(
            label: label,
            child: RaftFieldSurface(
              child: field.choices != null
                  ? DropdownButtonFormField<String>(
                      isExpanded: true,
                      key: ValueKey('field-${field.id}'),
                      initialValue: choices[field.id],
                      decoration: decoration,
                      style: t.fieldStyle,
                      icon: const RaftIcon(RaftGlyph.chevronDown, size: 14),
                      dropdownColor: t.popover,
                      borderRadius: RaftShapes.field(t),
                      items: [
                        for (final entry in field.choices!.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(
                              field.localizeChoices
                                  ? raftText(context, entry.value)
                                  : entry.value,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (v) {
                              choices[field.id] = v!;
                              RaftUnsavedGuard.maybeOf(context)?.recheck();
                            },
                    )
                  : TextFormField(
                      contextMenuBuilder: RaftTextSelectionToolbar.editableText,
                      autofillHints: null,
                      key: ValueKey('field-${field.id}'),
                      controller: editors[field.id],
                      enabled: !busy,
                      obscureText: field.obscure,
                      autofocus: field == widget.fields.first,
                      minLines: field.multiline ? 3 : 1,
                      maxLines: field.multiline ? 8 : 1,
                      style: t.fieldStyle,
                      decoration: decoration,
                      validator: (value) {
                        final text = field.trim
                            ? value?.trim() ?? ''
                            : value ?? '';
                        if (field.required && text.isEmpty)
                          return Localizations.localeOf(context).languageCode ==
                                  'zh'
                              ? '${label}为必填项。'
                              : '${field.label} is required.';
                        final problem = field.validator?.call(text);
                        return problem == null
                            ? null
                            : raftText(context, problem);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// The fields, the description, the extra content and the error: the same
  /// widgets in the dialog and in the sheet. The form key moves them from one
  /// to the other with their state (focus, caret) when the window crosses the
  /// breakpoint.
  Widget _form() => Form(
    key: form,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.description != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(widget.description!),
          ),
        for (final field in widget.fields) _field(field),
        if (widget.extra != null)
          ExcludeFocus(
            excluding: busy,
            child: IgnorePointer(ignoring: busy, child: widget.extra!),
          ),
        ?errorWidget,
        if (error != null) RaftErrorBanner(error!),
      ],
    ),
  );

  List<Widget> _actions() => [
    RaftTextButton(
      label: 'Cancel',
      variant: RaftControlVariant.outline,
      onPressed: busy ? null : () => Navigator.pop(context, false),
    ),
    RaftButton(
      label: busy && widget.busyLabel != null
          ? widget.busyLabel!
          : widget.submitLabel,
      busy: busy,
      onPressed: widget.submitEnabled ? submit : null,
      destructive: widget.destructive,
    ),
  ];

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    // Web `DialogCard`: Escape and the header X close it, a scrim press does
    // not (the call sites open it with `barrierDismissible: false`).
    child: RaftDismissScope(
      child: RaftFormFrame.sheetOf(context)
          ? RaftFormSheet(
              title: raftText(context, widget.title),
              uppercase: false,
              onClose: busy ? null : () => Navigator.pop(context, false),
              body: _form(),
              footer: OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: RaftSpace.x2,
                overflowSpacing: RaftSpace.x2,
                children: _actions(),
              ),
            )
          : AlertDialog(
              title: Row(
                children: [
                  Expanded(child: Text(raftText(context, widget.title))),
                  RaftCloseButton(
                    onPressed: busy
                        ? null
                        : raftGuardedClose(
                            context,
                            () => Navigator.pop(context, false),
                          ),
                  ),
                ],
              ),
              titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              actionsPadding: const EdgeInsets.all(16),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(child: _form()),
              ),
              actions: _actions(),
            ),
    ),
  );
}
