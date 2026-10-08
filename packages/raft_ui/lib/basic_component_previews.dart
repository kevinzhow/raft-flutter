import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Design controls', size: Size(640, 440))
Widget designControlsPreview() => const _DesignControls();

@RaftPreviews('Design fields', size: Size(640, 440))
Widget designFieldsPreview() => const _DesignFields();

@RaftPreviews('Design typography', size: Size(640, 440))
Widget designTypographyPreview() => Builder(
  builder: (context) {
    final t = RaftTokens.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workspace settings',
            style: RaftTypography.heading(t, size: 18, line: 28),
          ),
          const SizedBox(height: 16),
          Text(
            'A shared workspace for humans and agents.',
            style: RaftTypography.body(t),
          ),
          const SizedBox(height: 16),
          Text('Monospace metadata · 09:41', style: RaftTypography.mono(t)),
          const SizedBox(height: 16),
          Text('中文 · 日本語 · English', style: RaftTypography.body(t)),
        ],
      ),
    );
  },
);

@RaftPreviews('Design icons', size: Size(640, 440))
Widget designIconsPreview() => Padding(
  padding: const EdgeInsets.all(24),
  child: Wrap(
    spacing: 20,
    runSpacing: 20,
    children: [
      for (final glyph in RaftGlyph.values)
        Tooltip(message: glyph.name, child: RaftIcon(glyph, size: 24)),
    ],
  ),
);

class _DesignControls extends StatefulWidget {
  const _DesignControls();
  @override
  State<_DesignControls> createState() => _DesignControlsState();
}

class _DesignControlsState extends State<_DesignControls> {
  int clicks = 0;
  bool selected = true;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          children: [
            for (final variant in [
              RaftControlVariant.surface,
              RaftControlVariant.primary,
              RaftControlVariant.accent,
              RaftControlVariant.outline,
              RaftControlVariant.ghost,
              RaftControlVariant.danger,
            ])
              RaftButton(
                label: switch (variant) {
                  RaftControlVariant.surface => 'Default',
                  RaftControlVariant.primary => 'Primary',
                  RaftControlVariant.accent => 'Accent',
                  RaftControlVariant.outline => 'Outline',
                  RaftControlVariant.ghost => 'Ghost',
                  _ => 'Delete',
                },
                variant: variant,
                onPressed: () => setState(() => clicks++),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          children: [
            const RaftButton(label: 'Disabled'),
            RaftButton(label: 'Loading', busy: true, onPressed: () {}),
            RaftIconButton(
              glyph: RaftGlyph.send,
              visualSize: 28,
              tooltip: 'Send',
              variant: RaftControlVariant.accent,
              onPressed: () => setState(() => clicks++),
            ),
            RaftTextButton(
              label: 'Channel',
              glyph: RaftGlyph.hash,
              kind: RaftControlKind.filter,
              onPressed: () => setState(() => clicks++),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            RaftControl(
              kind: RaftControlKind.tab,
              selected: selected,
              shadow: false,
              visualHeight: 24,
              onPressed: () => setState(() => selected = true),
              child: const Text('Diagram'),
            ),
            RaftControl(
              kind: RaftControlKind.tab,
              selected: !selected,
              shadow: false,
              visualHeight: 24,
              onPressed: () => setState(() => selected = false),
              child: const Text('Code'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text('Activated $clicks · ${selected ? 'Diagram' : 'Code'}'),
        ),
      ],
    ),
  );
}

class _DesignFields extends StatefulWidget {
  const _DesignFields();
  @override
  State<_DesignFields> createState() => _DesignFieldsState();
}

class _DesignFieldsState extends State<_DesignFields> {
  String value = 'all';
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Name'),
        const SizedBox(height: 4),
        const RaftFieldSurface(
          child: TextField(
            decoration: InputDecoration(hintText: 'Workspace name'),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Channel'),
        RaftSelectField<String>(
          label: 'Channel',
          value: value,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All channels')),
            DropdownMenuItem(value: 'design', child: Text('#design')),
            DropdownMenuItem(value: 'general', child: Text('#general')),
          ],
          onChanged: (next) => setState(() => value = next!),
        ),
        const SizedBox(height: 16),
        Text('Selected $value'),
        const SizedBox(height: 16),
        RaftButton(
          label: 'Open form',
          secondary: true,
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => RaftFormDialog(
              title: 'Create channel',
              fields: const [
                RaftFormField('name', 'Name', required: true),
                RaftFormField('description', 'Description', multiline: true),
              ],
              onSubmit: (_) async {},
            ),
          ),
        ),
      ],
    ),
  );
}

// Same-content fixtures for the actual upstream component palettes.
@RaftPreviews('Source buttons', size: Size(640, 440))
Widget sourceButtonsPreview() => const _SourceButtons();

class _SourceButtons extends StatefulWidget {
  const _SourceButtons();
  @override
  State<_SourceButtons> createState() => _SourceButtonsState();
}

class _SourceButtonsState extends State<_SourceButtons> {
  int count = 0;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          children: [
            for (final variant in [
              RaftControlVariant.surface,
              RaftControlVariant.primary,
              RaftControlVariant.accent,
              RaftControlVariant.outline,
              RaftControlVariant.ghost,
              RaftControlVariant.danger,
            ])
              RaftButton(
                label: switch (variant) {
                  RaftControlVariant.surface => 'Default',
                  RaftControlVariant.primary => 'Primary',
                  RaftControlVariant.accent => 'Accent',
                  RaftControlVariant.outline => 'Outline',
                  RaftControlVariant.ghost => 'Ghost',
                  _ => 'Delete',
                },
                variant: variant,
                onPressed: () => setState(() => count++),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          children: [
            const RaftButton(label: 'Disabled'),
            RaftButton(label: 'Loading', busy: true, onPressed: () {}),
            RaftIconButton(
              glyph: RaftGlyph.send,
              visualSize: 28,
              tooltip: 'Send',
              variant: RaftControlVariant.accent,
              onPressed: () => setState(() => count++),
            ),
            RaftTextButton(
              label: 'Channel',
              glyph: RaftGlyph.hash,
              kind: RaftControlKind.filter,
              onPressed: () => setState(() => count++),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Semantics(liveRegion: true, child: Text('Activated $count')),
      ],
    ),
  );
}

@RaftPreviews('Source inputs', size: Size(640, 440))
Widget sourceInputsPreview() => Padding(
  padding: EdgeInsets.all(24),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Name'),
      SizedBox(height: 4),
      RaftFieldSurface(
        child: TextField(
          decoration: InputDecoration(hintText: 'Workspace name'),
        ),
      ),
      SizedBox(height: 16),
      Text('Email'),
      SizedBox(height: 4),
      RaftFieldSurface(
        child: TextFormField(
          initialValue: 'hello@example.invalid',
          readOnly: true,
        ),
      ),
      SizedBox(height: 16),
      Text('Disabled'),
      SizedBox(height: 4),
      RaftFieldSurface(
        child: TextField(
          enabled: false,
          decoration: InputDecoration(hintText: 'Unavailable'),
        ),
      ),
    ],
  ),
);

@RaftPreviews('Source avatars', size: Size(640, 440))
Widget sourceAvatarsPreview() => const Padding(
  padding: EdgeInsets.all(24),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RaftAvatar(name: 'Human'),
      SizedBox(width: 12),
      RaftAvatar(name: 'Human', size: 20),
    ],
  ),
);

@RaftPreviews('Source menus', size: Size(640, 440))
Widget sourceMenusPreview() => const _SourceMenus();

class _SourceMenus extends StatefulWidget {
  const _SourceMenus();
  @override
  State<_SourceMenus> createState() => _SourceMenusState();
}

class _SourceMenusState extends State<_SourceMenus> {
  bool open = true;
  @override
  Widget build(BuildContext context) {
    final recipe = RaftMenuRecipe(
      RaftTokens.of(context),
      viewportHeight: MediaQuery.sizeOf(context).height,
    );
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RaftButton(
            label: 'Message actions',
            secondary: true,
            onPressed: () => setState(() => open = !open),
          ),
          if (open) ...[
            SizedBox(height: recipe.popupGap),
            RaftMenuPanel(
              onDismiss: () => setState(() => open = false),
              children: [
                RaftMenuItem(
                  label: 'Copy link',
                  glyph: RaftGlyph.copy,
                  onPressed: () => setState(() => open = false),
                ),
                RaftMenuItem(
                  label: 'Download',
                  glyph: RaftGlyph.download,
                  onPressed: () => setState(() => open = false),
                ),
                SizedBox(
                  height: RaftTokens.of(context).brutal ? 2 : 9,
                  child: Center(
                    child: Divider(
                      height: 1,
                      thickness: RaftTokens.of(context).brutal ? 2 : 1,
                      color: RaftTokens.of(context).brutal
                          ? Colors.black
                          : RaftTokens.of(context).colors['line-muted'],
                    ),
                  ),
                ),
                RaftMenuItem(
                  label: 'Delete',
                  glyph: RaftGlyph.trash2,
                  onPressed: () => setState(() => open = false),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

@RaftPreviews('Source text headings', size: Size(640, 440))
Widget sourceTextHeadingsPreview() => Builder(
  builder: (context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var level = 1; level <= 6; level++) ...[
          if (level > 1) const SizedBox(height: 12),
          Text(
            'Heading $level',
            style: RaftTypography.textHeading(
              RaftTokens.of(context),
              level: level,
            ),
          ),
        ],
      ],
    ),
  ),
);

@RaftPreviews('Source text sans', size: Size(640, 440))
Widget sourceTextSansPreview() => Builder(
  builder: (context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final size in RaftSansSize.values) ...[
          if (size != RaftSansSize.large) const SizedBox(height: 16),
          Text(
            'Workspace settings · ${size.name}',
            style: RaftTypography.sans(RaftTokens.of(context), size: size),
          ),
        ],
      ],
    ),
  ),
);
