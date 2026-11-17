// Whether the Tasks page has a selection to end: the task open beside the
// list leaves its Escape to the page then (Web TasksPage: "Before the page's
// own Esc (closing the open task), which sees it taken"). The page and the
// slot are siblings in the shell, so this is the one fact they share.

/// What the Tasks page tells the open task's slot about Escape. The key goes
/// to the page's handler and to the focus tree in an order that is not ours,
/// so the slot leaves its Escape alone when the page [active]ly holds a
/// selection, or has just [consumed] it for this very key press.
abstract final class TasksSelectionEscape {
  /// The page holds a selection.
  static bool active = false;

  /// The page ended its selection with the Escape now held down; set until
  /// the key goes up.
  static bool consumed = false;

  /// The slot's Escape is the page's now.
  static bool get pending => active || consumed;
}
