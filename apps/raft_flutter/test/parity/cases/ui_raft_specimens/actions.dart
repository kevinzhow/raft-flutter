// Button specimens (specimens.tsx: ButtonVariants, ButtonSizes, ButtonStates).
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support.dart';

final Map<String, RaftSpecimenBuilder> raftActionSpecimens = {
  'button.variants': _buttonVariants,
  'button.sizes': _buttonSizes,
  'button.states': _buttonStates,
};

void _noop() {}

Widget _icon(
  RaftGlyph glyph,
  String label,
  RaftButtonVariant variant,
  RaftButtonSize size, {
  bool disabled = false,
}) => RaftButton(
  label: '',
  glyph: glyph,
  uiVariant: variant,
  uiSize: size,
  semanticLabel: label,
  onPressed: disabled ? null : _noop,
);

Widget _buttonVariants(BuildContext context, RaftTokens t) => specimenStack([
  // ButtonPreviewContent
  specimenRow([
    RaftButton(
      label: 'Button',
      uiVariant: RaftButtonVariant.standard,
      uiSize: RaftButtonSize.md,
      onPressed: _noop,
    ),
  ]),
  specimenRow([
    RaftButton(
      label: 'Send',
      uiVariant: RaftButtonVariant.primary,
      onPressed: _noop,
    ),
    RaftButton(
      label: 'Assign',
      uiVariant: RaftButtonVariant.standard,
      onPressed: _noop,
    ),
    RaftButton(
      label: 'Cancel',
      uiVariant: RaftButtonVariant.ghost,
      onPressed: _noop,
    ),
  ]),
  specimenRow([
    RaftButton(
      label: 'Stop Wug',
      uiVariant: RaftButtonVariant.warning,
      onPressed: _noop,
    ),
    RaftButton(
      label: 'Delete Agent',
      uiVariant: RaftButtonVariant.danger,
      onPressed: _noop,
    ),
  ]),
  // on-frame sits on the yellow frame (`flex items-center gap-1 rounded-control bg-layer-frame p-1.5`)
  Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: t.ui.layerFrame,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        RaftButton(
          label: 'Acme',
          uiVariant: RaftButtonVariant.onFrame,
          onPressed: _noop,
        ),
        const SizedBox(width: 4),
        _icon(
          RaftGlyph.search,
          'Search',
          RaftButtonVariant.onFrame,
          RaftButtonSize.iconMd,
        ),
      ],
    ),
  ),
]);

Widget _buttonSizes(BuildContext context, RaftTokens t) => specimenStack([
  specimenRow([
    RaftButton(
      label: 'Medium',
      uiVariant: RaftButtonVariant.standard,
      uiSize: RaftButtonSize.md,
      onPressed: _noop,
    ),
    RaftButton(
      label: 'Large',
      uiVariant: RaftButtonVariant.standard,
      uiSize: RaftButtonSize.lg,
      onPressed: _noop,
    ),
  ]),
  specimenFull(
    RaftButton(
      label: 'Create Account',
      uiVariant: RaftButtonVariant.primary,
      uiSize: RaftButtonSize.xl,
      expand: true,
      onPressed: _noop,
    ),
  ),
  specimenRow([
    RaftButton(
      label: 'New Task',
      uiVariant: RaftButtonVariant.standard,
      glyph: RaftGlyph.plus,
      uiSize: RaftButtonSize.md,
      onPressed: _noop,
    ),
    RaftButton(
      label: 'Next',
      glyph: RaftGlyph.send,
      iconInlineEnd: true,
      uiVariant: RaftButtonVariant.primary,
      uiSize: RaftButtonSize.md,
      onPressed: _noop,
    ),
  ]),
  specimenRow([
    _icon(
      RaftGlyph.search,
      'Search',
      RaftButtonVariant.ghost,
      RaftButtonSize.iconLg,
    ),
    _icon(
      RaftGlyph.search,
      'Search',
      RaftButtonVariant.ghost,
      RaftButtonSize.iconMd,
    ),
    _icon(
      RaftGlyph.plus,
      'Add',
      RaftButtonVariant.standard,
      RaftButtonSize.iconMd,
    ),
    _icon(
      RaftGlyph.send,
      'Send',
      RaftButtonVariant.primary,
      RaftButtonSize.iconMd,
    ),
    _icon(
      RaftGlyph.plus,
      'Add',
      RaftButtonVariant.standard,
      RaftButtonSize.iconLg,
    ),
  ]),
]);

Widget _buttonStates(BuildContext context, RaftTokens t) => specimenStack([
  specimenRow([
    RaftButton(label: 'Send', uiVariant: RaftButtonVariant.primary),
    RaftButton(label: 'Assign', uiVariant: RaftButtonVariant.standard),
    RaftButton(label: 'Cancel', uiVariant: RaftButtonVariant.ghost),
  ]),
  specimenRow([
    RaftButton(label: 'Stop Wug', uiVariant: RaftButtonVariant.warning),
    RaftButton(label: 'Delete Agent', uiVariant: RaftButtonVariant.danger),
    _icon(
      RaftGlyph.search,
      'Search',
      RaftButtonVariant.ghost,
      RaftButtonSize.iconMd,
      disabled: true,
    ),
  ]),
  specimenRow([
    RaftButton(
      label: 'Creating…',
      uiVariant: RaftButtonVariant.primary,
      busy: true,
      onPressed: _noop,
    ),
    RaftButton(
      label: 'Saving…',
      uiVariant: RaftButtonVariant.standard,
      busy: true,
      onPressed: _noop,
    ),
  ]),
]);
