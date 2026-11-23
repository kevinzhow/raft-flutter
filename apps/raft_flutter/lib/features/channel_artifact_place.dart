import 'package:flutter/foundation.dart';

import '../data/workspace_controller.dart';
import 'artifacts/artifact_models.dart';
import 'desktop_browser_tabs.dart';
import 'private_route_guard.dart' show channelSearchPageAuthority;

typedef ConversationArtifact = ({
  ArtifactLinkTarget target,
  ArtifactCard? seed,
  String? title,
  int openedAt,
});

class ChannelArtifactPlace extends ChangeNotifier {
  ChannelArtifactPlace._(this._workspace)
    : _authority = channelSearchPageAuthority(_workspace) {
    _workspace.addListener(_authorityChanged);
  }

  static final _owners = Expando<ChannelArtifactPlace>();

  static ChannelArtifactPlace of(WorkspaceController workspace) {
    final existing = _owners[workspace];
    if (existing != null) return existing;
    final created = _owners[workspace] = ChannelArtifactPlace._(workspace);
    workspace.services.disposeWithSession(created.dispose);
    return created;
  }

  final _open = <String, ConversationArtifact>{};
  final _opener = <String, VoidCallback>{};
  final WorkspaceController _workspace;
  String _authority;

  void _authorityChanged() {
    final next = channelSearchPageAuthority(_workspace);
    if (next == _authority) return;
    _authority = next;
    if (_open.isEmpty) return;
    _open.clear();
    _opener.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _workspace.removeListener(_authorityChanged);
    super.dispose();
  }

  ConversationArtifact? forConversation(String? channel) => _open[channel];

  void show(
    String channel,
    ArtifactLinkTarget target, {
    ArtifactCard? seed,
    required VoidCallback returnFocus,
  }) {
    _open[channel] = (
      target: target,
      seed: seed,
      title: seed?.title,
      openedAt: DesktopBrowserTabs.nextPlacement(),
    );
    _opener[channel] = returnFocus;
    notifyListeners();
  }

  void rename(String channel, ArtifactLinkTarget target, String title) {
    final artifact = _open[channel];
    if (artifact == null ||
        artifact.target != target ||
        artifact.title == title) {
      return;
    }
    _open[channel] = (
      target: artifact.target,
      seed: artifact.seed,
      title: title,
      openedAt: artifact.openedAt,
    );
    notifyListeners();
  }

  void close(String channel) {
    if (_open.remove(channel) == null) return;
    final focus = _opener.remove(channel);
    notifyListeners();
    focus?.call();
  }
}
