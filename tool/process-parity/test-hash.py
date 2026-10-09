#!/usr/bin/env python3
"""Hash the actual integration entry and its Android handoff dependency."""
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / 'apps/raft_flutter'
hash_ = hashlib.sha256()
for path in ('integration_test/process_activity_target_test.dart', 'integration_test/support/process_artifact_handoff.dart'):
    hash_.update((path + '\0').encode())
    hash_.update((ROOT/path).read_bytes())
print(hash_.hexdigest())
