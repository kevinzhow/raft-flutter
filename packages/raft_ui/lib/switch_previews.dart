import 'package:flutter/material.dart';

import 'previews.dart';
import 'src/design_primitives.dart';
import 'src/switch.dart';

@RaftPreviews('Source switches', size: Size(640, 440))
Widget sourceSwitchesPreview() => const _Switches();

class _Switches extends StatefulWidget {
  const _Switches();
  @override
  State<_Switches> createState() => _SwitchesState();
}

class _SwitchesState extends State<_Switches> {
  bool small = false, medium = true;
  @override
  Widget build(BuildContext context) => RaftDensityScope(
    density: RaftDensity.desktop,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RaftSwitch(
            value: small,
            semanticLabel: 'Small switch',
            onChanged: (v) => setState(() => small = v),
          ),
          const SizedBox(height: 24),
          RaftSwitch(
            value: medium,
            size: RaftSwitchSize.md,
            semanticLabel: 'Medium switch',
            onChanged: (v) => setState(() => medium = v),
          ),
          const SizedBox(height: 24),
          const RaftSwitch(
            value: false,
            size: RaftSwitchSize.md,
            semanticLabel: 'Disabled switch',
          ),
          const SizedBox(height: 24),
          const RaftSwitch(
            value: true,
            size: RaftSwitchSize.md,
            semanticLabel: 'Disabled checked switch',
          ),
        ],
      ),
    ),
  );
}
