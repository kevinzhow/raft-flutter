import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'previews.dart';
import 'raft_ui.dart';

@Preview(
  name: 'Hover input · Light',
  group: 'Input policy',
  wrapper: lightWrapper,
  size: Size(640, 440),
)
@Preview(
  name: 'Hover input · Dark',
  group: 'Input policy',
  wrapper: darkWrapper,
  size: Size(640, 440),
)
Widget hoverRegionPreview() => const _InputPreview();

class _InputPreview extends StatefulWidget {
  const _InputPreview();

  @override
  State<_InputPreview> createState() => _InputPreviewState();
}

class _InputPreviewState extends State<_InputPreview> {
  bool touch = false;
  int presses = 0;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RaftSwitch(
          value: touch,
          semanticLabel: 'Touch input: suppress hover',
          onChanged: (value) => setState(() => touch = value),
        ),
        const SizedBox(height: 16),
        Text(touch ? 'Touch input' : 'Hover-capable input'),
        const SizedBox(height: 24),
        RaftHoverScope(
          enabled: !touch,
          child: RaftDensityScope(
            density: touch ? RaftDensity.touch : RaftDensity.desktop,
            child: RaftTooltip(
              message: 'Keyboard focus and activation work in both modes.',
              child: RaftButton(
                label: 'Activate Preview',
                onPressed: () => setState(() => presses++),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Activated $presses times'),
      ],
    ),
  );
}
