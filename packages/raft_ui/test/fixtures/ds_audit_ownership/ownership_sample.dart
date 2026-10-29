// Resolved ownership fixture. A local name is not a canonical component.
import 'package:flutter/widgets.dart';
import 'package:raft_theme/recipes/recipe_runtime.dart';

class RaftButton extends StatelessWidget {
  const RaftButton({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class OwnedSample extends StatefulWidget {
  const OwnedSample({super.key});
  @override
  State<OwnedSample> createState() => _OwnedSampleState();
}

class _OwnedSampleState extends State<OwnedSample> {
  @override
  Widget build(BuildContext context) => const RaftButton();
}

Widget buildOwnedSample() => const OwnedSample();

Widget dynamicOwnedBuilder(dynamic builder) => builder();

final ownedTearoff = OwnedSample.new;

RaftRecipeStates ownedState(String value) => RaftRecipeStates({
  if (value == 'condition-only-not-an-atom') 'data-owned=true',
  RaftRecipeStates.hover,
});
