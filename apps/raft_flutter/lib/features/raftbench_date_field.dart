// The start-date field of the analysis settings: Web `<Input type="date">`
// (Chromium shows the locale's mm/dd/yyyy), here a recipe input that opens
// the platform date picker.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:raft_ui/raft_ui.dart';

class RaftbenchDateField extends StatefulWidget {
  const RaftbenchDateField({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
    this.semanticLabel,
    this.enabled = true,
  });

  /// `yyyy-MM-dd` (a UTC date), or empty / malformed while editing.
  final String value;

  /// The latest pickable `yyyy-MM-dd`.
  final String max;
  final ValueChanged<String> onChanged;
  final String? semanticLabel;
  final bool enabled;

  static DateTime? parse(String day) => DateTime.tryParse('${day}T00:00:00Z');

  /// Chromium's date input text: `mm/dd/yyyy` in English, `yyyy/mm/dd` for the
  /// Chinese locale; the placeholder when no valid date is set.
  static String format(String day, String locale) {
    final parsed = parse(day);
    final zh = locale.startsWith('zh');
    if (parsed == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) {
      return zh ? 'yyyy/mm/dd' : 'mm/dd/yyyy';
    }
    return DateFormat(zh ? 'yyyy/MM/dd' : 'MM/dd/yyyy').format(parsed);
  }

  @override
  State<RaftbenchDateField> createState() => _RaftbenchDateFieldState();
}

class _RaftbenchDateFieldState extends State<RaftbenchDateField> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _pick(BuildContext context) async {
    final last = RaftbenchDateField.parse(widget.max) ?? DateTime.now().toUtc();
    final current = RaftbenchDateField.parse(widget.value) ?? last;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(last) ? last : current,
      firstDate: DateTime.utc(2000),
      lastDate: last,
    );
    if (picked == null) return;
    widget.onChanged(DateFormat('yyyy-MM-dd').format(picked));
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    controller.text = RaftbenchDateField.format(widget.value, locale);
    return RaftInteractive(
      key: const ValueKey('raftbench-history-from'),
      onPressed: widget.enabled ? () => _pick(context) : null,
      semanticLabel: widget.semanticLabel,
      builder: (context, state) => AbsorbPointer(
        child: ExcludeFocus(
          child: RaftTextInput(
            controller: controller,
            readOnly: true,
            enabled: widget.enabled,
          ),
        ),
      ),
    );
  }
}
