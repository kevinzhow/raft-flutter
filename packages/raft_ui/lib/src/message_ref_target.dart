/// Port of Web `parseRaftRefTarget` / `formatRaftRefTarget`
/// (`packages/shared/src/raftRefs.ts`): the targets that `<target>` and
/// `[label](<target>)` can name.
enum RaftRefKind {
  user,
  computer,
  app,
  channel,
  channelThread,
  dm,
  dmThread,
  task,
  message,
  dmMessage,
}

typedef RaftRefTarget = ({RaftRefKind kind, String text, int? taskNumber});

const _name = r'[\p{L}\p{N}_-]+';
const _peer = r'[\w.-]+(?:~(?:agent|human))?(?![\w.~-])';
const _short = r'[\da-f]{6,8}';
const _messageId = r'[A-Za-z0-9][A-Za-z0-9-]{1,63}';

RegExp _re(String body) =>
    RegExp('^$body\$', unicode: true, caseSensitive: false);

final _channelMessage = _re('#($_name)(?::($_short))?\\s+msg=($_messageId)');
final _dmMessage = _re('dm:@($_peer)(?::($_short))?\\s+msg=($_messageId)');
final _channelThread = _re('#($_name):($_short)');
final _dmThread = _re('dm:@($_peer):($_short)');
final _task = _re(r'task\s+#([1-9]\d*)');
final _computer = _re(
  r'computer:([\da-f]{8}-[\da-f]{4}-[1-5][\da-f]{3}-[89ab][\da-f]{3}-[\da-f]{12})',
);
final _app = RegExp(r'^app:([a-z][a-z0-9]*(?:\.[a-z][a-z0-9]*)+)$');
final _user = RegExp('^@($_name)\$', unicode: true);
final _channel = RegExp('^#($_name)\$', unicode: true);
final _dm = _re('dm:@($_peer)');

/// The target [raw] names, or null. `text` is the canonical wire form.
RaftRefTarget? raftParseRefTarget(String raw) {
  final target = raw.trim();
  if (target.isEmpty) return null;
  RaftRefTarget make(RaftRefKind kind, String text, [int? task]) =>
      (kind: kind, text: text, taskNumber: task);
  var m = _channelMessage.firstMatch(target);
  if (m != null) {
    return make(
      RaftRefKind.message,
      m[2] != null ? '#${m[1]}:${m[2]} msg=${m[3]}' : '#${m[1]} msg=${m[3]}',
    );
  }
  m = _dmMessage.firstMatch(target);
  if (m != null) {
    return make(
      RaftRefKind.dmMessage,
      m[2] != null
          ? 'dm:@${m[1]}:${m[2]} msg=${m[3]}'
          : 'dm:@${m[1]} msg=${m[3]}',
    );
  }
  m = _channelThread.firstMatch(target);
  if (m != null) return make(RaftRefKind.channelThread, '#${m[1]}:${m[2]}');
  m = _dmThread.firstMatch(target);
  if (m != null) return make(RaftRefKind.dmThread, 'dm:@${m[1]}:${m[2]}');
  m = _task.firstMatch(target);
  if (m != null) {
    return make(RaftRefKind.task, 'task #${m[1]}', int.parse(m[1]!));
  }
  m = _computer.firstMatch(target);
  if (m != null) {
    return make(RaftRefKind.computer, 'computer:${m[1]!.toLowerCase()}');
  }
  m = _app.firstMatch(target);
  if (m != null) return make(RaftRefKind.app, 'app:${m[1]}');
  m = _user.firstMatch(target);
  if (m != null) return make(RaftRefKind.user, '@${m[1]}');
  m = _channel.firstMatch(target);
  if (m != null) return make(RaftRefKind.channel, '#${m[1]}');
  m = _dm.firstMatch(target);
  if (m != null) return make(RaftRefKind.dm, 'dm:@${m[1]}');
  return null;
}
