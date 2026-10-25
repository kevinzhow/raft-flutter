// Recipe context of a `RaftRecipeBox`, for the paint-op record (support/paint_ops.dart).
//
// The recipe, slot, axis arguments (variant, size, theme) and states that produced a painted slot are not kept on
// `RaftSlotStyle` yet, so this adapter reports no recipe context and the extreme-theme report says so. When the
// recipe binding change makes generated slots keep that context on `RaftSlotStyle.context`, read it here and
// return the same map (`recipe`, `args`, `states`, `slotIndex`, `callers`, `traced`, `props`, `tokenProps`,
// `literalProps`, `radiusControl`); tool/parity-ext/extreme.py (`recipe_records`) consumes exactly those keys.
import 'package:raft_ui/raft_ui.dart' show RaftRecipeBox;

/// The recipe context of [box]'s style, or null while it is not recorded.
Map<String, Object?>? recipeContextOf(RaftRecipeBox box) => null;

/// Starts recording recipe resolutions (a no-op until the context exists on the style).
void installRecipeTrace() {}

/// Stops what [installRecipeTrace] started.
void removeRecipeTrace() {}
