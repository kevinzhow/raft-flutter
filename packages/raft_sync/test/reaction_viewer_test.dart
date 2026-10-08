import 'package:test/test.dart';
import 'package:raft_sync/raft_sync.dart';
void main() {
  Map<String,dynamic> snapshot(int version, List<String> emojis, {String server='s'}) =>
    {'serverId': server, 'messageId': 'm', 'viewerVersion': version, 'reactedEmojis': emojis};
  test('late HTTP cannot overwrite newer private socket state', () {
    final l=ReactionViewerLedger();
    expect(l.accept(snapshot(4,['👍']), serverId:'s'), 'accepted');
    expect(l.accept(snapshot(5,[]), serverId:'s'), 'accepted');
    expect(l.accept(snapshot(4,['👍']), serverId:'s'), 'stale');
    expect(l.reacted('m'), isEmpty);
    expect(l.accept(snapshot(5,[]), serverId:'s'), 'duplicate');
    expect(l.accept(snapshot(5,['👍']), serverId:'s'), 'conflict');
    expect(l.reacted('m'), isEmpty);
  });
  test('receiver reset and server boundary remove private choices', () {
    final l=ReactionViewerLedger();
    expect(l.accept(snapshot(1,['👍'],server:'other'), serverId:'s'),'corrupt');
    expect(l.reacted('m'),isNull);
    l.accept(snapshot(1,['👍']),serverId:'s');
    l.reset();
    expect(l.reacted('m'),isNull);
    expect(l.accept(snapshot(0,[]),serverId:'new'),'corrupt');
  });
}
