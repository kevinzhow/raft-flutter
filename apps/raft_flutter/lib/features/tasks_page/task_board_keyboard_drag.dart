// The board's keyboard drag (raft-ui 0.95.3 task-dnd `taskKeyboardCoordinates`
// with dnd-kit's keyboard sensor, drag-sensors.mjs): Space on the focused card
// picks it up, Left / Right move the target to the nearest column in that
// direction, Space drops it, Escape puts it back. Only columns are drop
// targets (cards are ordered by the sort, not by hand), so Up / Down are taken
// but go nowhere. Escape during the drag reaches nothing else: no open task
// closes, no selection ends (drag-escape.ts holds it at the window).
//
// Beyond Web: Enter also drops (Web's Enter does nothing during a drag), and
// the drag says what it does in words (Web's board is silent here and only
// announces the move after the server accepts it).
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The column nearest [from] in [direction] (-1 left, 1 right) by the centres
/// of the columns ([centers] in any order); null when there is none that way
/// (dnd-kit: a target more than one pixel beside the card's centre).
String? nearestColumn(Map<String, double> centers, String from, int direction) {
  final origin = centers[from];
  if (origin == null) return null;
  String? best;
  var gap = double.infinity;
  for (final entry in centers.entries) {
    if (entry.key == from) continue;
    final distance = (entry.value - origin) * direction;
    if (distance <= 1 || distance >= gap) continue;
    best = entry.key;
    gap = distance;
  }
  return best;
}

/// One keyboard drag at a time: which card, and the column it is over.
class TaskBoardKeyboardDrag extends ChangeNotifier {
  TaskBoardKeyboardDrag({
    required this.centers,
    required this.onPickUp,
    required this.onOver,
    required this.onDrop,
    required this.onCancel,
  });

  /// Where the columns are now: status to the x of its centre.
  final Map<String, double> Function() centers;
  final void Function(String taskId, String status) onPickUp;
  final void Function(String taskId, String status) onOver;

  /// Dropped over [status] (the column it was picked up from, or another).
  final void Function(String taskId, String status) onDrop;
  final void Function(String taskId) onCancel;

  String? _taskId, _over;

  /// The card being dragged, null when none is.
  String? get taskId => _taskId;

  /// The column the card is over.
  String? get over => _over;
  bool get active => _taskId != null;

  /// A key on card [id] (in column [home]) that has primary focus. Handled
  /// when the drag takes it.
  KeyEventResult handle(String id, String home, KeyEvent event) {
    final key = event.logicalKey;
    if (!active) {
      if (event is! KeyDownEvent || key != LogicalKeyboardKey.space) {
        return KeyEventResult.ignored;
      }
      _taskId = id;
      _over = home;
      onPickUp(id, home);
      notifyListeners();
      return KeyEventResult.handled;
    }
    if (_taskId != id) return KeyEventResult.ignored;
    final down = event is KeyDownEvent;
    final arrow =
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown;
    if (arrow) {
      if (event is KeyUpEvent) return KeyEventResult.handled;
      final direction = key == LogicalKeyboardKey.arrowLeft
          ? -1
          : key == LogicalKeyboardKey.arrowRight
          ? 1
          : 0;
      final next = direction == 0
          ? null
          : nearestColumn(centers(), _over ?? home, direction);
      if (next != null) {
        _over = next;
        onOver(id, next);
        notifyListeners();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter) {
      if (down) _end(drop: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (down) _end(drop: false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// The drag ends without a drop (focus left the card, the card went).
  void cancel() {
    if (active) _end(drop: false);
  }

  void _end({required bool drop}) {
    final id = _taskId!, status = _over;
    _taskId = _over = null;
    if (drop && status != null) {
      onDrop(id, status);
    } else {
      onCancel(id);
    }
    notifyListeners();
  }
}
