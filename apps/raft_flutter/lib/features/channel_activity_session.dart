import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';

import '../data/device_preferences.dart';
import '../data/feature_flag_client_facts.dart';
import '../data/workspace_controller.dart';
import 'channel_activity_timeline.dart';
import 'mobile_route_gate.dart';
import 'message_history_gaps.dart';
import 'message_selection.dart';
import 'history_paywall_view.dart';

bool isActivityChannel(RaftChannel? channel) =>
    channel != null &&
    const ['channel', 'private'].contains(channel.type) &&
    channel.string('threadSort') == 'activity';

class ChannelActivitySession extends ChangeNotifier {
  ChannelActivitySession._(this.w) {
    store = ChannelActivityStore(
      _read,
      acceptSummaries: w.messageDomain.mergeThreadSummaries,
    )..addListener(_notify);
    w.addListener(_changed);
    _events = w.client.events.listen(_event);
    w.services.disposeWithSession(dispose);
    _changed();
  }

  static final _owners = Expando<ChannelActivitySession>();
  static ChannelActivitySession of(WorkspaceController w) {
    final source = w.presentationSource;
    if (source != null) return of(source);
    return _owners[w] ??= ChannelActivitySession._(w);
  }

  static const flagKey = RaftFeatureFlags.channelThreadSort;
  final WorkspaceController w;
  late final ChannelActivityStore store;
  StreamSubscription<RaftEvent>? _events;
  String? _scope;
  bool enabled = false, _ended = false;
  int epoch = 0, _ticket = 0;
  Future<void> ready = Future.value();

  String get _authority => jsonEncode([
    w.client.origin,
    w.client.generation,
    w.client.user?.id,
    w.server?.id,
    w.server?.string('role'),
    w.server?.json['permissions'],
  ]);
  List<Object?> get _memoryScope => [
    w.client.origin,
    w.client.user?.id,
    w.server?.id,
    w.server?.string('role'),
  ];
  bool get _eligible =>
      w.server != null && w.client.user != null && w.can('viewChannel');

  void _notify() {
    if (!_ended) notifyListeners();
  }

  void _changed({bool reevaluate = false}) {
    if (_ended || w.services.isDisposed()) return;
    final authority = _authority;
    if (_scope == authority && !reevaluate) return;
    if (_scope != authority) {
      _scope = authority;
      epoch++;
      enabled =
          _eligible && (FeatureFlagMemory.read(_memoryScope, flagKey) ?? false);
      store.reset();
    }
    final server = w.server;
    if (_eligible && server != null) {
      ready = _evaluate(authority, ++_ticket, server.id);
    }
  }

  Future<void> _evaluate(String authority, int ticket, String server) async {
    try {
      final page = await w.client.post(
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(keys: const [flagKey], serverId: server),
      );
      if (_ended || authority != _authority || ticket != _ticket) return;
      final raw = page is Map ? page['evaluations'] : null;
      final matches = raw is List
          ? raw.whereType<Map>().where((row) => row['key'] == flagKey).toList()
          : const <Map>[];
      _setEnabled(matches.length == 1 && matches.single['enabled'] == true);
    } catch (_) {
      if (!_ended && authority == _authority && ticket == _ticket) {
        _setEnabled(false);
      }
    }
  }

  void _setEnabled(bool value) {
    FeatureFlagMemory.write(_memoryScope, {flagKey: value});
    if (enabled == value) return;
    enabled = value;
    _notify();
  }

  Future<dynamic> _read(String id, String? before) async {
    final authority = _authority;
    final token = w.messageDomain.replyToken(id);
    final page = await w.query(
      '/messages/channel/$id/by-activity',
      query: {'limit': 50, 'before': ?before},
    );
    if (_ended ||
        authority != _authority ||
        token != w.messageDomain.replyToken(id) ||
        w.sessionScope.revokedChannels.contains(id)) {
      throw const FormatException('Activity authority changed');
    }
    return page;
  }

  void _event(RaftEvent event) {
    if (_ended) return;
    if (event.name == 'server:updated' || event.name == 'connected') {
      _changed(reevaluate: true);
    } else if (event.name == 'server:features-changed' &&
        event.payload is Map) {
      final payload = event.payload as Map;
      final keys = payload['keys'];
      if (payload['serverId'] == w.server?.id &&
          (keys is! List || keys.contains(flagKey))) {
        _changed(reevaluate: true);
      }
    }
    if (event.name == 'rooms:joined') {
      for (final entry in store.windows.entries.toList()) {
        if (!entry.value.loading) unawaited(store.loadLatest(entry.key));
      }
    }
    if (!enabled || event.payload is! Map) return;
    final payload = Map<String, dynamic>.from(event.payload);
    if (payload['serverId'] != null && payload['serverId'] != w.server?.id) {
      return;
    }
    if (event.name == 'message:updated') store.patch(payload);
    if (event.name == 'thread:updated' &&
        payload['parentMessageId'] is String) {
      final parent = payload['parentMessageId'] as String;
      final followed = w.services.followedThreads.threads
          .where((row) => row['threadChannelId'] == payload['threadChannelId'])
          .firstOrNull;
      store.noteReply(
        parent,
        payload['lastReplyAt'] is String
            ? payload['lastReplyAt'] as String
            : null,
        w.messageDomain.summaryOwner(payload, parent) ??
            followed?['parentChannelId'] as String?,
        inSeq: (id, parent) =>
            w.messageDomain.messageWindows.rows(id).any((m) => m.id == parent),
      );
    }
  }

  @override
  void dispose() {
    if (_ended) return;
    _ended = true;
    w.removeListener(_changed);
    unawaited(_events?.cancel());
    store.removeListener(_notify);
    store.dispose();
    super.dispose();
  }
}

/// A mounted channel retains only its activity pages. Seq metadata, reads and
/// context navigation stay with WorkspaceMessages throughout.
class ChannelActivityPresentation extends ChangeNotifier {
  ChannelActivityPresentation(this.w, {required this.thread}) {
    update();
  }
  final WorkspaceController w;
  final bool thread;
  ChannelActivitySession? _session;
  ChannelActivitySession get session =>
      _session ??= (ChannelActivitySession.of(w)..addListener(_changed));
  (String, int)? _retained;
  VoidCallback? _release;

  bool get forumChannel =>
      !thread &&
      isActivityChannel(w.channel) &&
      !w.sessionScope.revokedChannels.contains(w.channel?.id) &&
      session.enabled;
  bool get mode => forumChannel && !w.messageDomain.state.hasNewer;
  ChannelActivityWindow? get window =>
      _retained != null && _retained == (w.channel?.id, session.epoch)
      ? session.store.windows[_retained?.$1]
      : null;
  bool get hasMore =>
      mode ? window?.hasMore ?? false : w.messageDomain.state.hasMore;
  bool get historyLimited => mode
      ? window?.historyLimited ?? false
      : w.messageDomain.state.historyLimited;
  bool get paywallAtTop =>
      mode ? !hasMore && historyLimited : RaftHistoryPaywallView.atTop(w);
  bool get allHidden =>
      mode ? historyLimited : RaftHistoryPaywallView.hidesAll(w);
  bool get loadingOlder =>
      mode ? window?.loadingOlder ?? false : w.messageDomain.state.loadingOlder;
  bool get loading => mode
      ? w.messageDomain.timeline().isEmpty &&
            window?.messages.isEmpty != false &&
            (w.messageDomain.state.channelLoading || (window?.loading ?? true))
      : w.messageDomain.state.channelLoading;

  void update() {
    final next = forumChannel ? (w.channel!.id, session.epoch) : null;
    if (_retained == next) return;
    _release?.call();
    _release = null;
    _retained = next;
    if (next != null) _release = session.store.retain(next.$1);
  }

  void _changed() {
    update();
    notifyListeners();
  }

  List<RaftMessage> rows(List<RaftMessage> seq) => mode
      ? buildChannelActivityTimeline(
          w.channel!.id,
          seq,
          window,
          w.messageDomain.threadSummariesFor(w.channel!.id),
        )
      : seq;
  List<RaftMessage> rowsFor(
    BuildContext context, {
    required bool direct,
    required bool visible,
  }) {
    final messages = w.messageDomain;
    if (MobileRouteGate.sharedWindow(
      context,
      w,
      direct: direct,
      visible: visible,
    )) {
      final window = thread ? messages.threadWindow : messages.messageWindow;
      if (window != null && !window.retired) return rows(window.timeline);
    }
    return rows(messages.timeline(thread: thread));
  }

  Widget wrapRow(RaftMessage message, Widget child) => mode
      ? child
      : HistoryGapPlaceholder(
          controller: w,
          thread: thread,
          newerId: message.id,
          child: child,
        );

  Future<void> older() => mode
      ? session.store.loadOlder(w.channel!.id)
      : w.messageDomain.older(thread: thread);

  @override
  void dispose() {
    _session?.removeListener(_changed);
    _release?.call();
    super.dispose();
  }
}

class ChannelActivitySelection extends MessageSelection {
  ChannelActivitySelection(this.activity, this.displayed)
    : super(activity.w, thread: activity.thread);
  final ChannelActivityPresentation activity;
  final List<RaftMessage> Function() displayed;

  @override
  List<SelectedMessageRow> get available => activity.mode
      ? [
          for (final message in displayed())
            if (message.string('messageType') != 'system')
              SelectedMessageRow(message),
        ]
      : super.available;
}
