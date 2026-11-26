import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:raft_flutter/features/quoted_message_preview.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

import '../parity_harness.dart';

final Map<String, dynamic> _wave4bFixture = jsonDecode(
  File('../../tool/parity-ext/fixtures/legacy-wave4b.json').readAsStringSync(),
) as Map<String, dynamic>;

Widget _canvasBox(
  double frameWidth,
  Widget child, {
  bool desktop = true,
  double? frameHeight,
  Alignment alignment = Alignment.topLeft,
  Key? frameKey,
}) {
  return Builder(
    builder: (context) {
      final baseTheme = Theme.of(context);
      final platform = desktop ? TargetPlatform.linux : TargetPlatform.android;
      final themed = baseTheme.copyWith(platform: platform);
      final t = RaftTokens.of(context);
      final Widget padded = Padding(
        padding: const EdgeInsets.all(16),
        child: frameHeight == null
            ? child
            : Align(alignment: alignment, child: child),
      );
      return Theme(
        data: themed,
        child: RaftInteractionScope(
          interaction: desktop
              ? RaftInteraction.pointerMode
              : RaftInteraction.touchMode,
          child: Align(
            alignment: Alignment.topLeft,
            child: RaftRecipeBox(
              declareSurface: true,
              applyText: false,
              tokens: t.recipeTokens,
              style: RaftSlotStyle(
                {'background-color': CssColor(t.ui.layerCanvas.toARGB32())},
                const {},
                const ['bg-layer-canvas'],
                t.recipeTokens,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: SizedBox(
                  key: frameKey,
                  width: frameWidth,
                  height: frameHeight,
                  child: padded,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

ParityCase _quotedMessageSkeleton(String form) {
  final width = form == 'desktop' ? 440.0 : 360.0;
  return ParityCase(
    widgets: const [
      'raft_flutter:QuotedMessageLoadingCard',
      'raft_ui:RaftCard',
      'raft_ui:RaftSkeleton',
    ],
    build: (ctx) => _canvasBox(
      width,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: const QuotedMessageLoadingCard(),
        ),
      ),
      desktop: form == 'desktop',
      frameKey: const ValueKey('wave4b-frame'),
    ),
  );
}

ParityCase _formDialogSelect(String form) {
  final width = form == 'desktop' ? 440.0 : 360.0;
  final field = _wave4bFixture['selectField'] as Map<String, dynamic>;
  final options = (field['options'] as List)
      .cast<Map<String, dynamic>>()
      .map(
        (o) => RaftSelectItem<String>(
          value: o['value'] as String,
          label: o['label'] as String,
        ),
      )
      .toList(growable: false);
  return ParityCase(
    widgets: const ['raft_ui:RaftField', 'raft_ui:RaftSelectField'],
    build: (ctx) => _canvasBox(
      width,
      RaftField(
        label: field['label'] as String,
        hint: field['hint'] as String,
        child: RaftSelectField<String>(
          label: field['label'] as String,
          value: field['value'] as String,
          items: options,
          onChanged: (_) {},
        ),
      ),
      desktop: form == 'desktop',
      frameKey: const ValueKey('wave4b-frame'),
    ),
  );
}

ParityCase _mermaidDownloadMenu() {
  final menu = _wave4bFixture['mermaidMenu'] as Map<String, dynamic>;
  final items = (menu['items'] as List).cast<Map<String, dynamic>>();
  return ParityCase(
    widgets: const [
      'raft_ui:RaftDropdownMenu',
      'raft_ui:RaftMenuPanel',
      'raft_ui:RaftMenuItem',
      'raft_ui:RaftButton',
    ],
    build: (ctx) => _canvasBox(
      420,
      RaftDropdownMenu(
        kind: RaftMenuKind.dropdownMenu,
        align: RaftDropdownAlign.end,
        surfaceKey: const ValueKey('wave4b-mermaid-menu'),
        label: menu['triggerLabel'] as String,
        entries: [
          for (final item in items)
            RaftMenuEntry(
              label: item['label'] as String,
              glyph: item['icon'] == 'code2'
                  ? RaftGlyph.code2
                  : RaftGlyph.download,
              onPressed: () {},
            ),
        ],
        triggerBuilder: (context, focusNode, onPressed) => RaftButton(
          key: const ValueKey('wave4b-mermaid-trigger'),
          focusNode: focusNode,
          uiVariant: RaftButtonVariant.outline,
          uiSize: RaftButtonSize.iconMd,
          glyph: RaftGlyph.download,
          glyphSize: RaftMetrics.iconMd,
          onPressed: onPressed,
        ),
      ),
      frameHeight: 260,
      alignment: Alignment.topRight,
    ),
  );
}

ParityCase _memberActionsMenu() {
  final menu = _wave4bFixture['memberMenu'] as Map<String, dynamic>;
  final items = (menu['items'] as List).cast<String>();
  return ParityCase(
    widgets: const [
      'raft_ui:RaftDropdownMenu',
      'raft_ui:RaftMenuPanel',
      'raft_ui:RaftMenuItem',
      'raft_ui:RaftButton',
    ],
    build: (ctx) => _canvasBox(
      420,
      RaftDropdownMenu(
        kind: RaftMenuKind.dropdownMenu,
        align: RaftDropdownAlign.end,
        surfaceKey: const ValueKey('wave4b-member-menu'),
        label: menu['triggerLabel'] as String,
        entries: [
          for (final label in items)
            RaftMenuEntry(label: label, onPressed: () {}),
        ],
        triggerBuilder: (context, focusNode, onPressed) => RaftButton(
          key: const ValueKey('wave4b-member-actions-trigger'),
          focusNode: focusNode,
          uiVariant: RaftButtonVariant.ghost,
          uiSize: RaftButtonSize.iconMd,
          glyph: RaftGlyph.ellipsisVertical,
          onPressed: onPressed,
        ),
      ),
      frameHeight: 300,
      alignment: Alignment.topRight,
    ),
  );
}

ParityCase _filterMenuTrigger() {
  final ft = _wave4bFixture['filterTrigger'] as Map<String, dynamic>;
  return ParityCase(
    widgets: const ['raft_ui:RaftPickerTriggerButton'],
    build: (ctx) => _canvasBox(
      320,
      Align(
        alignment: Alignment.topLeft,
        widthFactor: 1,
        heightFactor: 1,
        child: RaftPickerTriggerButton(
          key: const ValueKey('wave4b-filter-trigger'),
          label: ft['label'] as String,
          semanticLabel: ft['title'] as String,
          onPressed: () {},
        ),
      ),
      frameKey: const ValueKey('wave4b-frame'),
    ),
  );
}

final Map<String, ParityCase> extLegacyWave4bCases = {
  for (final theme in ['brutal', 'elegant-dark']) ...{
    for (final form in ['desktop', 'phone']) ...{
      'components.legacy-wave4b.quoted-message-skeleton.$form.$theme':
          _quotedMessageSkeleton(form),
      'components.legacy-wave4b.form-dialog-select.$form.$theme':
          _formDialogSelect(form),
    },
    'components.legacy-wave4b.mermaid-download-menu.desktop.$theme':
        _mermaidDownloadMenu(),
    'components.legacy-wave4b.member-actions-menu.desktop.$theme':
        _memberActionsMenu(),
    'components.legacy-wave4b.filter-menu-trigger.desktop.$theme':
        _filterMenuTrigger(),
  },
};
