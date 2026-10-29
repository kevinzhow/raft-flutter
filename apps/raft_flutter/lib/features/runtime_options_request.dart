import 'package:raft_client/raft_client.dart';

/// Web `RUNTIME_FORM_V2_MARKER_HEADERS`: the server sends each runtime row's
/// `runtimeFormV2` marker only to a client that asks (released mobile apps
/// decode runtime options strictly and break on unknown keys). Without the
/// header a legacy-editor runtime never learns it has a v2 form, and the
/// `runtime_form_v2_web` flag has no effect.
const runtimeFormV2MarkerHeaders = {'X-Raft-Runtime-Form-V2': '1'};

/// Runs [read] (a `GET .../runtime-options`: the Computer's, or an existing
/// agent's) so that its request carries [runtimeFormV2MarkerHeaders].
T readRuntimeOptions<T>(T Function() read) =>
    RaftClient.runWithHeaders(runtimeFormV2MarkerHeaders, read);
