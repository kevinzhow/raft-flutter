import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import 'management_support.dart'
    show cachedServerFlag, pageIdentity, rememberServerFlag;

const _gateFlag = 'attachment_preview_enabled';

/// The server's document/media preview gate as last read under the current
/// identity (this session, else this device); null when it was never read.
bool? knownAttachmentPreviewGate(WorkspaceController w) =>
    cachedServerFlag(w, _gateFlag);

/// What reading the gate decided for an open that must not wait for it.
enum AttachmentPreviewGate { enabled, disabled, unauthorized }

/// Reads the gate and remembers it for the next open. An unreadable gate
/// leaves the preview enabled (the Web client's default); a revoked session
/// is reported as [AttachmentPreviewGate.unauthorized].
Future<AttachmentPreviewGate> readAttachmentPreviewGate(
  WorkspaceController w,
) async {
  final identity = pageIdentity(w);
  try {
    final enabled = await w.attachmentMedia.previewEnabled();
    rememberServerFlag(w, _gateFlag, enabled, identity);
    return enabled
        ? AttachmentPreviewGate.enabled
        : AttachmentPreviewGate.disabled;
  } on RaftApiException catch (error) {
    return [401, 403].contains(error.status)
        ? AttachmentPreviewGate.unauthorized
        : AttachmentPreviewGate.enabled;
  } catch (_) {
    return AttachmentPreviewGate.enabled;
  }
}
