import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/cause_notice.dart';
import '../data/user_error.dart';
import 'action_card_spec.dart';
import 'second_factor_step_up.dart';

typedef ActionCardFormPage = ({Object? title, List<ActionCardField> fields});
typedef ActionCardFormDraft = ({int page, CardJson values});
typedef ActionCardCandidate = ({String id, String label});

enum ActionCardFieldType {
  TextInput,
  TextArea,
  Select,
  Toggle,
  Choice,
  MemberPicker,
  ChannelPicker,
  AgentPicker;

  bool get picker => switch (this) {
    MemberPicker || ChannelPicker || AgentPicker => true,
    _ => false,
  };
}

class ActionCardField {
  const ActionCardField(this.name, this.type, this.spec);

  final String name;
  final ActionCardFieldType type;
  final CardJson spec;

  bool get required => spec['required'] == true;
  bool get multiple => spec['multiple'] == true;
  CardJson get other => cardObject(spec['other']);
  List<CardJson> get options =>
      cardList(spec['options']).map(cardObject).toList();
  int get maximum => !multiple
      ? 1
      : (spec['maxItems'] as int?) ??
            (type.picker ? 50 : options.length + (other.isEmpty ? 0 : 1));

  Object initial() => switch (type) {
    ActionCardFieldType.Toggle => spec['default'] == true,
    ActionCardFieldType.Choice => {
      'selected': cardList(cardObject(spec['default'])['selected']),
      if (cardObject(spec['default'])['other'] case final String other)
        'other': other,
    },
    _ when type.picker => [
      for (final ref in cardList(spec['default']))
        if (cardString(cardObject(ref)['id']) case final String id) id,
    ],
    _ => cardString(spec['default']) ?? '',
  };

  Object? submission(Object? value) {
    if (type == ActionCardFieldType.Choice) {
      final choice = cardObject(value);
      final selected = cardList(choice['selected']);
      final other = cardString(choice['other'])?.trim() ?? '';
      return {'selected': selected, if (other.isNotEmpty) 'other': other};
    }
    return value is String ? value.trim() : value;
  }

  String? issue(Object? raw) {
    final value = submission(raw);
    final limit = spec['maxLength'];
    if (value is String) {
      if (required && value.isEmpty) return 'Required';
      if (limit is int && value.runes.length > limit) return 'Too long';
    }
    if (type == ActionCardFieldType.Choice) {
      final choice = cardObject(value);
      final otherText = cardString(choice['other']);
      final otherLimit = other['maxLength'];
      if (otherText != null &&
          otherLimit is int &&
          otherText.runes.length > otherLimit) {
        return 'Too long';
      }
      final count =
          cardList(choice['selected']).length + (otherText == null ? 0 : 1);
      if (cardObject(raw).containsKey('other') && otherText == null) {
        return 'Enter your answer.';
      }
      final minimum = spec['minItems'] as int? ?? 1;
      if (count == 0 && required) return 'Choose an answer.';
      if (count > 0 && count < minimum) return 'Choose more options.';
      if (count > maximum) return 'Too many options selected.';
    }
    if (type.picker && required && cardList(value).isEmpty) return 'Required';
    return null;
  }
}

class ActionCardForm {
  const ActionCardForm(this.id, this.spec, this.fields, this.pages);

  final String id;
  final CardJson spec;
  final List<ActionCardField> fields;
  final List<ActionCardFormPage> pages;

  bool get inline => spec['placement'] == 'inline';
  bool get paged => pages.length > 1;

  static ActionCardForm? read(String id, Object? raw) {
    final spec = cardObject(raw);
    final rows = cardList(spec['fields']);
    if (!_hasText(spec['title']) ||
        !_hasText(spec['submitLabel']) ||
        rows.length > 12 ||
        spec['fields'] is! List) {
      return null;
    }
    final fields = <String, ActionCardField>{};
    for (final row in rows) {
      final field = cardObject(row);
      final name = cardString(field['name']);
      final type = ActionCardFieldType.values
          .where((value) => value.name == field['type'])
          .firstOrNull;
      if (name == null ||
          type == null ||
          fields.containsKey(name) ||
          !_hasText(field['label'])) {
        return null;
      }
      if (type == ActionCardFieldType.Select ||
          type == ActionCardFieldType.Choice) {
        final options = cardList(field['options']);
        final values = <String>{};
        if (options.isEmpty || options.length > 32) return null;
        for (final raw in options) {
          final option = cardObject(raw);
          final value = cardString(option['value']);
          if (value == null ||
              !values.add(value) ||
              !_hasText(option['label'])) {
            return null;
          }
        }
      }
      for (final key in ['minItems', 'maxItems', 'maxLength', 'rows']) {
        final value = field[key];
        if (value != null && (value is! int || value < 1)) return null;
      }
      fields[name] = ActionCardField(name, type, field);
    }
    final all = fields.values.toList();
    final pages = <ActionCardFormPage>[];
    final assigned = <String>{};
    final steps = cardList(spec['steps']);
    if (steps.length >= 2 && steps.length <= 10) {
      for (final raw in steps) {
        final step = cardObject(raw);
        final names = cardList(step['fields']);
        final grouped = <ActionCardField>[];
        for (final name in names.whereType<String>()) {
          final field = fields[name];
          if (field != null && assigned.add(name)) grouped.add(field);
        }
        if (grouped.length != names.length || grouped.isEmpty) break;
        pages.add((title: step['title'], fields: grouped));
      }
    }
    if (pages.length != steps.length ||
        assigned.length != all.length ||
        pages.isEmpty) {
      pages
        ..clear()
        ..add((title: null, fields: all));
    }
    return ActionCardForm(id, spec, all, pages);
  }

  static bool _hasText(Object? value) =>
      cardString(cardObject(cardObject(value)['text'])['en']) != null;
}

class ActionCardFormView extends StatefulWidget {
  const ActionCardFormView({
    super.key,
    required this.form,
    required this.entityName,
    required this.candidates,
    required this.onSubmit,
    this.inline = false,
    this.question = false,
    this.enabled = true,
    this.buttonLabel,
    this.draft,
    this.onDraft,
  });

  final ActionCardForm form;
  final ActionCardEntityName entityName;
  final List<ActionCardCandidate> Function(ActionCardField) candidates;
  final Future<void> Function(CardJson) onSubmit;
  final bool inline, question, enabled;
  final Object? buttonLabel;
  final ActionCardFormDraft? draft;
  final ValueChanged<ActionCardFormDraft?>? onDraft;

  @override
  State<ActionCardFormView> createState() => _ActionCardFormViewState();
}

class _ActionCardFormViewState extends State<ActionCardFormView>
    with WidgetsBindingObserver {
  late final CardJson _values;
  late int _page;
  Timer? _turnGuard;
  final _issues = <String, String>{};
  final _focus = <String, FocusNode>{};
  final _pageFocus = FocusNode();
  Timer? _undo;
  CardJson? _pending;
  bool _sending = false;
  bool _succeeded = false;
  final _notice = CauseNotice();

  bool get _busy => _sending || _pending != null;
  ActionCardForm get _form => widget.form;
  bool get _tapSubmits {
    final field = _form.fields.singleOrNull;
    return widget.question &&
        field != null &&
        field.type == ActionCardFieldType.Choice &&
        !field.multiple &&
        !cardObject(_values[field.name]).containsKey('other');
  }

  @override
  void initState() {
    super.initState();
    _values = {
      for (final field in _form.fields)
        field.name: widget.draft?.values[field.name] ?? field.initial(),
    };
    _page = (widget.draft?.page ?? 0).clamp(0, _form.pages.length - 1);
    if (widget.question) WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _flush();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _turnGuard?.cancel();
    _undo?.cancel();
    final payload = _pending;
    final submit = widget.onSubmit;
    if (payload != null && widget.enabled) {
      unawaited(
        // ignore: raft_lints/avoid_unreviewed_idle_work -- Flushes one already committed answer after the widget tree unlocks; it never reschedules.
        Future<void>.microtask(() => submit(payload)).catchError((Object _) {}),
      );
    }
    for (final node in _focus.values) {
      node.dispose();
    }
    _pageFocus.dispose();
    super.dispose();
  }

  String _copy(Object? value) =>
      actionCardCopy(context, value, widget.entityName);

  void _saveDraft() =>
      widget.onDraft?.call((page: _page, values: CardJson.of(_values)));

  void _edit(ActionCardField field, Object? value) {
    if (_busy || !widget.enabled) return;
    setState(() {
      _values[field.name] = value;
      _issues.remove(field.name);
      _notice.clear();
    });
    _saveDraft();
  }

  void _go(int index) {
    setState(() {
      _page = index;
    });
    _turnGuard?.cancel();
    _turnGuard = Timer(const Duration(milliseconds: 500), () {});
    _saveDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final first = _form.pages[_page].fields.firstOrNull;
      (_focus[first?.name] ?? _pageFocus).requestFocus();
    });
  }

  void _submit() {
    if (_busy || !widget.enabled || _succeeded) return;
    if (_turnGuard?.isActive == true) return;
    final last = widget.inline || _page == _form.pages.length - 1;
    final fields = last ? _form.fields : _form.pages[_page].fields;
    final issues = <String, String>{};
    for (final field in fields) {
      final issue = field.issue(_values[field.name]);
      if (issue != null) issues[field.name] = issue;
    }
    setState(() {
      _issues
        ..clear()
        ..addAll(issues);
      _notice.clear();
    });
    if (issues.isNotEmpty) {
      final first = issues.keys.first;
      final index = _form.pages.indexWhere(
        (page) => page.fields.any((field) => field.name == first),
      );
      if (!widget.inline && index >= 0 && index != _page) _go(index);
      _focus[first]?.requestFocus();
      return;
    }
    if (!last) {
      _go(_page + 1);
      return;
    }
    final values = {
      for (final field in _form.fields)
        field.name: field.submission(_values[field.name]),
    };
    if (widget.question) {
      setState(() => _pending = values);
      _undo = Timer(const Duration(milliseconds: 1500), _flush);
    } else {
      unawaited(_send(values));
    }
  }

  void _cancelPending() {
    _undo?.cancel();
    setState(() => _pending = null);
  }

  void _flush() {
    final payload = _pending;
    if (payload == null || !mounted) return;
    _cancelPending();
    if (widget.enabled) unawaited(_send(payload));
  }

  Future<void> _send(CardJson values) async {
    setState(() => _sending = true);
    final save = widget.onDraft;
    try {
      await widget.onSubmit(values);
      save?.call(null);
      _succeeded = true;
      if (mounted &&
          !widget.inline &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted && !isSecondFactorStepUpCancelled(error)) {
        if (!_showServerIssues(error)) {
          setState(
            () => _notice.raise(
              userErrorText(
                error,
                fallback: 'Failed to execute action',
                where: 'action card form',
              ),
              whileTrue: () => widget.enabled && !_succeeded,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _showServerIssues(Object error) {
    if (error is! RaftApiException ||
        error.status != 422 ||
        error.details['errorCode'] != 'FORM_INVALID') {
      return false;
    }
    final fields = _form.fields.map((field) => field.name).toSet();
    final issues = <String, String>{};
    final summary = <String>[];
    for (final raw in cardList(error.details['issues']).take(24)) {
      final issue = cardObject(raw);
      final text = _copy(issue['message']);
      if (!isDisplayableServerMessage(text)) continue;
      final name = cardString(issue['field']);
      if (name != null && fields.contains(name)) {
        issues.putIfAbsent(name, () => text);
      } else {
        summary.add(text);
      }
    }
    if (issues.isEmpty && summary.isEmpty) return false;
    setState(() {
      _issues.addAll(issues);
      _notice.raise(
        summary.join('\n'),
        whileTrue: () => widget.enabled && !_succeeded,
      );
    });
    final first = _form.pages.indexWhere(
      (page) => page.fields.any((field) => issues.containsKey(field.name)),
    );
    if (!widget.inline && first >= 0 && first != _page) _go(first);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || issues.isEmpty) return;
      final field = _form.pages[_page].fields
          .where((field) => issues.containsKey(field.name))
          .firstOrNull;
      _focus[field?.name]?.requestFocus();
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.inline
        ? (title: null, fields: _form.fields)
        : _form.pages[_page];
    final last = widget.inline || _page == _form.pages.length - 1;
    final submitLabels = cardObject(_form.spec['submitLabels']);
    final selected = cardString(_values[submitLabels['field']]);
    final submitLabel =
        widget.buttonLabel ??
        cardObject(submitLabels['labels'])[selected] ??
        _form.spec['submitLabel'];
    final interactive = widget.enabled && !_busy && !_succeeded;
    final controls = Wrap(
      alignment: WrapAlignment.end,
      spacing: RaftSpace.x2,
      runSpacing: RaftSpace.x2,
      children: [
        if (_pending != null)
          Text(
            raftText(context, 'Submitted'),
            semanticsLabel: raftText(context, 'Submitted'),
          ),
        if (_pending != null)
          RaftButton(
            label: 'Undo',
            uiVariant: RaftButtonVariant.ghost,
            uiSize: RaftButtonSize.md,
            onPressed: _cancelPending,
          )
        else ...[
          if (!widget.inline)
            RaftButton(
              label: _page == 0 ? 'Cancel' : 'Back',
              uiVariant: RaftButtonVariant.ghost,
              uiSize: RaftButtonSize.md,
              onPressed: _sending
                  ? null
                  : _page == 0
                  ? () => Navigator.of(context).pop(false)
                  : () => _go(_page - 1),
            ),
          if (widget.enabled && !_tapSubmits)
            RaftButton(
              key: const ValueKey('action-card-form-submit'),
              label: _sending
                  ? 'Submitting…'
                  : last
                  ? _copy(submitLabel)
                  : 'Next',
              uiVariant: RaftButtonVariant.outline,
              uiSize: RaftButtonSize.md,
              autoHeight: true,
              onPressed: interactive ? _submit : null,
            ),
        ],
      ],
    );
    final body = Focus(
      focusNode: _pageFocus,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: RaftSpace.x3,
        children: [
          if (_notice.message case final String error)
            RaftErrorBanner(error, small: true),
          if (!widget.inline && _page == 0 && _form.spec['description'] != null)
            Text(_copy(_form.spec['description'])),
          if (page.title != null) Text(_copy(page.title)),
          for (final field in page.fields) _field(field, interactive),
          if (widget.inline) controls,
        ],
      ),
    );
    if (widget.inline) return body;
    return PopScope(
      canPop: !_sending,
      child: RaftDialog.card(
        title: _copy(_form.spec['title']),
        onClose: () {
          if (!_sending) Navigator.of(context).maybePop();
        },
        actions: controls,
        child: body,
      ),
    );
  }

  Widget _field(ActionCardField field, bool enabled) {
    final label = _copy(field.spec['label']);
    final value = _values[field.name];
    final issue = _issues[field.name];
    final hint = field.spec['placeholder'] == null
        ? null
        : _copy(field.spec['placeholder']);
    final focus = _focus.putIfAbsent(field.name, FocusNode.new);
    Widget control;
    switch (field.type) {
      case ActionCardFieldType.TextInput:
        control = RaftTextInput(
          initialValue: value as String?,
          hintText: hint,
          focusNode: focus,
          enabled: enabled,
          invalid: issue != null,
          onSubmitted: (_) => _submit(),
          onChanged: (text) => _edit(field, text),
        );
      case ActionCardFieldType.TextArea:
        control = RaftTextarea(
          initialValue: value as String?,
          hintText: hint,
          rows: (field.spec['rows'] as int? ?? 3).clamp(2, 12),
          focusNode: focus,
          enabled: enabled,
          growsWithScale: true,
          invalid: issue != null,
          onChanged: (text) => _edit(field, text),
        );
      case ActionCardFieldType.Select:
        control = RaftSelectField<String>(
          key: ValueKey('action-card-select-${field.name}'),
          label: label,
          value: cardString(value),
          placeholder: hint ?? 'Select...',
          invalid: issue != null,
          items: [
            for (final option in field.options)
              if (cardString(option['value']) case final String id)
                RaftSelectItem(value: id, label: _copy(option['label'])),
          ],
          onChanged: enabled ? (next) => _edit(field, next ?? '') : null,
        );
      case ActionCardFieldType.Toggle:
        control = RaftSwitch(
          value: value == true,
          semanticLabel: label,
          focusNode: focus,
          onChanged: enabled ? (next) => _edit(field, next) : null,
        );
      case ActionCardFieldType.Choice:
        control = _choice(field, cardObject(value), enabled);
      default:
        final choices = widget.candidates(field);
        final selected = cardList(value).whereType<String>().toSet();
        control = choices.isEmpty
            ? Text(
                field.spec['emptyText'] == null
                    ? raftText(context, 'Nothing to choose from.')
                    : _copy(field.spec['emptyText']),
              )
            : field.multiple
            ? Column(
                children: [
                  for (final option in choices)
                    RaftCheckboxRow(
                      title: option.label,
                      value: selected.contains(option.id),
                      onChanged:
                          enabled &&
                              (selected.contains(option.id) ||
                                  selected.length < field.maximum)
                          ? (checked) => _edit(field, [
                              ...selected.where((id) => id != option.id),
                              if (checked == true) option.id,
                            ])
                          : null,
                    ),
                ],
              )
            : RaftSelectField<String>(
                label: label,
                value: selected.firstOrNull,
                placeholder: hint ?? 'Select...',
                items: [
                  for (final option in choices)
                    RaftSelectItem(value: option.id, label: option.label),
                ],
                onChanged: enabled ? (next) => _edit(field, [?next]) : null,
              );
    }
    return RaftProductFormField(
      key: ValueKey('action-card-field-${field.name}'),
      label: label,
      required: field.required,
      hint: field.spec['description'] == null
          ? null
          : _copy(field.spec['description']),
      error: issue,
      child: control,
    );
  }

  Widget _choice(ActionCardField field, CardJson value, bool enabled) {
    final selected = cardList(value['selected']).whereType<String>().toSet();
    final hasOther = value.containsKey('other');
    final other = field.other;
    final otherText = value['other'] as String? ?? '';
    final full = selected.length + (hasOther ? 1 : 0) >= field.maximum;
    final options = [
      ...field.options,
      if (other.isNotEmpty) {...other, 'value': 'other'},
    ];
    bool checked(String id) => id == 'other' ? hasOther : selected.contains(id);
    void select(String id) {
      final next = field.multiple ? selected.toSet() : <String>{};
      if (id != 'other' && (!checked(id) || !field.multiple)) {
        next.add(id);
      } else {
        next.remove(id);
      }
      if (!field.multiple && id == 'other') next.clear();
      if (field.multiple && id == 'other') next.addAll(selected);
      _edit(field, {
        'selected': next.toList(),
        if (id == 'other'
            ? !hasOther || !field.multiple
            : field.multiple && hasOther)
          'other': otherText,
      });
      if (_tapSubmits) _submit();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x2,
      children: [
        if (field.multiple) ...[
          for (final option in options)
            if (cardString(option['value']) case final String id)
              RaftCheckboxRow(
                title: _copy(option['label']),
                description: option['description'] == null
                    ? null
                    : _copy(option['description']),
                value: checked(id),
                onChanged: enabled && (checked(id) || !full)
                    ? (_) => select(id)
                    : null,
              ),
        ] else
          RaftRadioGroup<String>(
            value: hasOther ? 'other' : selected.firstOrNull,
            onChanged: enabled ? select : null,
            children: [
              for (final option in options)
                if (cardString(option['value']) case final String id)
                  RaftRadioGroupItem(
                    value: id,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_copy(option['label'])),
                        if (option['description'] != null)
                          Text(_copy(option['description'])),
                      ],
                    ),
                  ),
            ],
          ),
        if (hasOther)
          RaftTextInput(
            initialValue: otherText,
            hintText: _copy(other['placeholder']),
            enabled: enabled,
            onSubmitted: (_) => _submit(),
            onChanged: (text) =>
                _edit(field, {'selected': selected.toList(), 'other': text}),
          ),
      ],
    );
  }
}
