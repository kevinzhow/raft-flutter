import 'dart:async';

import 'package:raft_client/raft_client.dart';

import 'workspace_controller.dart';
import 'workspace_share_targets.dart';

export 'workspace_share_targets.dart';

/// Compatibility composition adapter. The D5 reader owns the projection;
/// caller migration removes this remaining controller edge in the final round.
FutureOr<List<IncomingShareTarget>?> cachedShareTargets(
  WorkspaceController w,
  RaftRecord server,
) => WorkspaceShareTargets(
  selectedServer: () => w.server,
  channels: () => w.channels,
  dms: () => w.dms,
  peerRows: (kind) => w.services.entityDirectory.rows(kind).cast<Map>(),
  selfId: () => w.client.user?.id,
  cachedChannelDirectory: (id) => w.cachedChannelDirectory(id),
).cached(server);
