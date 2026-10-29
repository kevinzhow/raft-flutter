// Form specimens (Input, Switch, Checkbox): the same markup as tool/parity-ui/host/src/specimens.tsx.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support.dart';

void _noop(bool _) {}

/// `<label className="flex items-center gap-3"><Checkbox/><span>text</span></label>` under `text-sm`.
Widget _checkboxLabel(RaftTokens t, bool value, String label) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    RaftCheckbox(value: value, onChanged: _noop, semanticLabel: label),
    const SizedBox(width: 12),
    Text(label, style: t.scale(RaftTypeScale.callout)),
  ],
);

final Map<String, RaftSpecimenBuilder> raftFormSpecimens = {
  'input.states': (context, t) => specimenStack([
    specimenFull(const RaftTextInput(hintText: 'you@example.com')),
    specimenFull(const RaftTextInput(initialValue: 'mia@botiverse.build')),
    specimenFull(
      const RaftTextInput(initialValue: 'not-an-email', invalid: true),
    ),
    specimenFull(
      const RaftTextInput(hintText: 'you@example.com', enabled: false),
    ),
    specimenFull(
      const RaftTextInput(initialValue: 'mia@botiverse.build', enabled: false),
    ),
  ]),
  'switch.states': (context, t) => specimenStack([
    specimenRow([
      RaftSwitch(value: false, onChanged: _noop, semanticLabel: 'Off'),
      RaftSwitch(value: true, onChanged: _noop, semanticLabel: 'On'),
      const RaftSwitch(value: false, semanticLabel: 'Off, disabled'),
      const RaftSwitch(value: true, semanticLabel: 'On, disabled'),
    ]),
  ]),
  'checkbox.states': (context, t) => specimenStack([
    specimenRow([
      RaftCheckbox(value: true, onChanged: _noop, semanticLabel: 'Checked'),
      RaftCheckbox(value: false, onChanged: _noop, semanticLabel: 'Unchecked'),
      RaftCheckbox(
        value: false,
        indeterminate: true,
        onChanged: _noop,
        semanticLabel: 'Mixed',
      ),
      const RaftCheckbox(value: false, semanticLabel: 'Disabled'),
      const RaftCheckbox(value: true, semanticLabel: 'Disabled checked'),
      RaftCheckbox(
        value: true,
        shape: RaftCheckboxShape.circle,
        onChanged: _noop,
        semanticLabel: 'Circle checked',
      ),
      RaftCheckbox(
        value: false,
        shape: RaftCheckboxShape.circle,
        onChanged: _noop,
        semanticLabel: 'Circle',
      ),
    ]),
    // `grid min-w-60 gap-2 text-sm`
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _checkboxLabel(t, true, 'Recent messages'),
        const SizedBox(height: 8),
        _checkboxLabel(t, true, 'Activity log'),
        const SizedBox(height: 8),
        _checkboxLabel(t, false, 'Trajectory log'),
      ],
    ),
    // CheckboxIndicatorContent: `flex items-center gap-4`
    const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RaftCheckboxIndicator(checked: false),
        SizedBox(width: 16),
        RaftCheckboxIndicator(checked: true),
        SizedBox(width: 16),
        RaftCheckboxIndicator(checked: true, mark: RaftCheckboxMark.minus),
        SizedBox(width: 16),
        RaftCheckboxIndicator(checked: true, shape: RaftCheckboxShape.circle),
        SizedBox(width: 16),
        RaftCheckboxIndicator(checked: true, disabled: true),
      ],
    ),
  ]),
};
