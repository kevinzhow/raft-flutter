import 'package:flutter/material.dart';

import 'localization.dart';

import 'components.dart';
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
  });
  final String title, submitLabel;
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
  late final editors = {
    for (final field in widget.fields)
      field.id: TextEditingController(text: field.initial),
  };
  late final choices = {
    for (final field in widget.fields.where((f) => f.choices != null))
      field.id: field.initial.isEmpty
          ? field.choices!.keys.first
          : field.initial,
  };
  bool busy = false;
  String? error;
  @override
  void dispose() {
    for (final editor in editors.values) {
      editor.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
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
      if (mounted) setState(() => error = '$e');
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
                      onChanged: busy ? null : (v) => choices[field.id] = v!,
                    )
                  : TextFormField(
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
                        return field.validator?.call(text);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(raftText(context, widget.title)),
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      actionsPadding: const EdgeInsets.all(16),
      content: SizedBox(
        width: 480,
        child: Form(
          key: form,
          child: SingleChildScrollView(
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
                if (error != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        RaftTextButton(
          label: 'Cancel',
          variant: RaftControlVariant.outline,
          onPressed: busy ? null : () => Navigator.pop(context, false),
        ),
        RaftButton(
          label: widget.submitLabel,
          busy: busy,
          onPressed: submit,
          destructive: widget.destructive,
        ),
      ],
    ),
  );
}
