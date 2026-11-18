import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import 'channel_settings.dart';
import 'channel_side_store.dart';
import 'management_support.dart' show pageIdentity;
import 'private_route_guard.dart' show channelAuthorityReduced;

/// The details belong to the channel that opened them, including its draft.
class ChannelDetailsStore extends ChangeNotifier {
  ChannelDetailsStore._(this.w) {
    w.addListener(_workspaceChanged);
  }
  final WorkspaceController w;
  static final _owners = Expando<ChannelDetailsStore>();

  static ChannelDetailsStore of(WorkspaceController w) {
    final existing = _owners[w];
    if (existing != null) return existing;
    final created = _owners[w] = ChannelDetailsStore._(w);
    w.services.disposeWithSession(created.dispose);
    return created;
  }

  ({RaftChannel channel, String? dmName, String authority})? _entry;
  RaftChannel? get channel {
    final entry = _entry;
    if (entry == null || entry.authority != pageIdentity(w)) return null;
    final latest = [
      ...w.channels,
      ...w.dms,
    ].where((c) => c.id == entry.channel.id).firstOrNull;
    return channelAuthorityReduced(entry.channel.json, latest?.json)
        ? null
        : entry.channel;
  }

  String? get dmName => _entry?.dmName;

  void open(RaftChannel channel, {String? dmName}) {
    if (_entry?.channel.id == channel.id && this.channel != null) return;
    _entry = (channel: channel, dmName: dmName, authority: pageIdentity(w));
    ChannelSideStore.of(w).focus('details');
    notifyListeners();
  }

  void _workspaceChanged() {
    if (_entry != null && channel == null) close();
  }

  @override
  void dispose() {
    w.removeListener(_workspaceChanged);
    super.dispose();
  }

  void close() {
    if (_entry == null) return;
    _entry = null;
    notifyListeners();
  }
}

Widget channelDetailsHeader(
  WorkspaceController w,
  RaftChannel channel,
  Widget Function(BuildContext context, bool pressed) builder,
) {
  final details = ChannelDetailsStore.of(w);
  return ListenableBuilder(
    listenable: details,
    builder: (context, _) =>
        builder(context, details.channel?.id == channel.id),
  );
}

/// The side area's details section, with focus returning to its opener.
class ChannelDetailsHost extends StatefulWidget {
  const ChannelDetailsHost({
    super.key,
    required this.controller,
    this.headerWrapper,
  });
  final WorkspaceController controller;
  final Widget Function(BuildContext, Widget)? headerWrapper;

  @override
  State<ChannelDetailsHost> createState() => _ChannelDetailsHostState();
}

class _ChannelDetailsHostState extends State<ChannelDetailsHost> {
  final scope = FocusScopeNode(debugLabel: 'channel details');
  FocusNode? opener;

  @override
  void initState() {
    super.initState();
    opener = FocusManager.instance.primaryFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) scope.requestFocus();
    });
  }

  @override
  void dispose() {
    final restore =
        scope.hasFocus || FocusManager.instance.primaryFocus == null;
    scope.dispose();
    if (restore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final back = opener;
        if (back != null && back.context != null && back.canRequestFocus) {
          back.requestFocus();
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final details = ChannelDetailsStore.of(widget.controller);
    final channel = details.channel;
    if (channel == null) return const SizedBox.shrink();
    return FocusScope(
      node: scope,
      child: ChannelSettings(
        key: ValueKey('channel-details-settings-${channel.id}'),
        controller: widget.controller,
        channel: channel,
        dmName: details.dmName,
        isPanel: true,
        details: true,
        headerWrapper: widget.headerWrapper,
        onClose: details.close,
      ),
    );
  }
}
