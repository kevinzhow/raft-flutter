/// Borrowed task-discussion controllers. Web marks that thread read from the
/// task modal without writing the side-thread URI.
final _taskDiscussions = Expando<bool>();

bool isTaskDiscussion(Object controller) =>
    _taskDiscussions[controller] == true;

void admitTaskDiscussion(Object controller) {
  _taskDiscussions[controller] = true;
}
