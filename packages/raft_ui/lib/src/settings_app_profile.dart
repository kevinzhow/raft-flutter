import 'package:flutter/material.dart';

import 'feedback_inbox.dart' show RaftDashedBorderPainter;
import 'localization.dart';
import 'raft/ui_tokens.dart';
import 'settings_app_editor.dart';
import 'settings_applications.dart';
import 'settings_controls.dart';
import 'settings_layout.dart';
import 'theme.dart';
import 'tokens/tokens.dart';
import 'viewport_breakpoints.dart';

class RaftAppProfileGrid extends StatelessWidget {
  const RaftAppProfileGrid({
    super.key,
    required this.logo,
    required this.fields,
  });

  final Widget logo, fields;

  @override
  Widget build(BuildContext context) => raftBreakpointWidth(context) >= 640
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: RaftSpace.x4,
          children: [
            SizedBox(width: 140, child: logo),
            Expanded(child: fields),
          ],
        )
      : RaftAppEditorStack(children: [logo, fields]);
}

class RaftAppProfileLogo extends StatelessWidget {
  const RaftAppProfileLogo({
    super.key,
    required this.initials,
    this.logoUrl,
    this.actions = const [],
  });

  final String initials;
  final String? logoUrl;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftAppEditorStack(
      gap: RaftSpace.x2,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomPaint(
          foregroundPainter: RaftDashedBorderPainter(t.ui.lineStrong, 2),
          child: Container(
            width: 120,
            height: 120,
            color: t.ui.layerSidebar,
            alignment: Alignment.center,
            child: RaftAppLogo(
              initials: initials,
              logoUrl: logoUrl,
              size: RaftAppLogoSize.lg,
            ),
          ),
        ),
        if (actions.isNotEmpty)
          Wrap(
            spacing: RaftSpace.x2,
            runSpacing: RaftSpace.x2,
            children: actions,
          ),
      ],
    );
  }
}

/// packages/shared appWhenToUse.ts: the agent-facing App hint is measured
/// after trimming, in Unicode code points.
const appWhenToUseMaxCodePoints = 160;

int countAppWhenToUseCharacters(String value) => value.trim().runes.length;

bool isAppWhenToUseTooLong(String value) =>
    countAppWhenToUseCharacters(value) > appWhenToUseMaxCodePoints;

/// AppWhenToUseField.tsx: the optional "When to use" field, with a live
/// end-aligned `N / 160 characters` counter under the control and an
/// over-limit error. Nothing caps the typing; an editor refuses to save while
/// [isAppWhenToUseTooLong]. Web shares this one field between an ordinary
/// App's editor and an MCP App's Profile, so this widget is the only one.
class RaftAppWhenToUseField extends StatelessWidget {
  const RaftAppWhenToUseField({
    super.key,
    this.fieldKey,
    this.countKey,
    required this.controller,
    required this.onChanged,
    this.enabled = true,
  });

  final Key? fieldKey, countKey;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final count = countAppWhenToUseCharacters(controller.text);
    final invalid = count > appWhenToUseMaxCodePoints;
    return RaftAppEditorField(
      label: 'When to use',
      optional: true,
      compact: true,
      hint: 'Shown to agents in their system prompt; leave empty to hide it.',
      error: invalid
          ? raftFormat(
              context,
              'Use no more than {limit} characters before saving.',
              {'limit': appWhenToUseMaxCodePoints},
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: RaftSpace.x1_5,
        children: [
          RaftRecipeInput(
            fieldKey: fieldKey,
            controller: controller,
            enabled: enabled,
            placeholder: raftText(
              context,
              'When an agent should reach for this app, in one line',
            ),
            onChanged: onChanged,
          ),
          Semantics(
            liveRegion: true,
            child: Text(
              raftFormat(context, '{count} / {limit} characters', {
                'count': count,
                'limit': appWhenToUseMaxCodePoints,
              }),
              key: countKey,
              textAlign: TextAlign.end,
              style: t.scale(
                RaftTypeScale.monoMeta,
                mono: true,
                weight: invalid ? FontWeight.w700 : null,
                color: invalid ? t.ui.dangerStrong : t.ui.foregroundHint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
