import 'package:flutter/material.dart';

import 'raft/switch.dart';

import 'switch_recipe.dart';

export 'switch_recipe.dart' show RaftSwitchRecipe, RaftSwitchSize;

/// Controlled source Switch. A disabled control never invokes [onChanged].
class RaftSwitch extends StatelessWidget {
  const RaftSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.size = RaftSwitchSize.sm,
    this.enabled = true,
    this.semanticLabel,
    this.semanticDescription,
    this.minimumTargetSize,
  });
  final bool value, enabled;
  final ValueChanged<bool>? onChanged;

  /// The source size variant. The Raft pack uses 50×30 at either size.
  final RaftSwitchSize size;
  final String? semanticLabel, semanticDescription;
  final double? minimumTargetSize;

  @override
  Widget build(BuildContext context) => RaftSwitchControl(
    value: value,
    size: size,
    onChanged: onChanged,
    enabled: enabled,
    semanticLabel: semanticLabel,
    semanticDescription: semanticDescription,
    minimumTargetSize: minimumTargetSize,
  );
}
