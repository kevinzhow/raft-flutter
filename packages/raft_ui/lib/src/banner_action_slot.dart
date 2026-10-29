import 'package:flutter/widgets.dart';

import 'recipes/recipe_runtime.dart' show RaftSlotStyle;

/// Internal renderer for the published BannerAction slot.
///
/// Canonical Banner supplies the resolved style; there is no new public
/// Banner parameter or theme capability for replacing it.
class RaftBannerActionSlot extends StatelessWidget {
  const RaftBannerActionSlot({
    super.key,
    required this.style,
    required this.children,
  });

  final RaftSlotStyle style;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: style.margin,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: style.columnGap ?? 0,
        runSpacing: style.rowGap ?? 0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    ),
  );
}
