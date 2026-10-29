"""Policy probes for the workspace-domain import and type-erasure guard."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'workspace_domain_guard.py'
spec = importlib.util.spec_from_file_location('workspace_domain_guard', SCRIPT)
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


# Frozen at 0c0b5a3b: migration may only lower/remove these edges.
BASELINE_MAXIMA = {'apps/raft_flutter/lib/data/agent_migration_status.dart': {'rootEdges': 1, 'rootIdentifiers': 1},
 'apps/raft_flutter/lib/data/history_gap_recovery.dart': {'rootEdges': 1, 'rootIdentifiers': 3},
 'apps/raft_flutter/lib/data/incoming_share_targets.dart': {'rootEdges': 1, 'rootIdentifiers': 1},
 'apps/raft_flutter/lib/data/message_history_events.dart': {'rootEdges': 1, 'rootIdentifiers': 8},
 'apps/raft_flutter/lib/data/message_history_memory.dart': {'rootEdges': 1, 'rootIdentifiers': 6},
 'apps/raft_flutter/lib/data/message_history_navigation.dart': {'rootEdges': 1, 'rootIdentifiers': 2},
 'apps/raft_flutter/lib/data/message_history_pages.dart': {'rootEdges': 1, 'rootIdentifiers': 9},
 'apps/raft_flutter/lib/data/message_history_positions.dart': {'rootEdges': 1, 'rootIdentifiers': 6},
 'apps/raft_flutter/lib/data/message_history_reconciliation.dart': {'rootEdges': 1, 'rootIdentifiers': 1},
 'apps/raft_flutter/lib/data/message_history_snapshots.dart': {'rootEdges': 1, 'rootIdentifiers': 3},
 'apps/raft_flutter/lib/data/message_history_summaries.dart': {'rootEdges': 1, 'rootIdentifiers': 5},
 'apps/raft_flutter/lib/data/message_history_verification.dart': {'rootEdges': 1, 'rootIdentifiers': 13},
 'apps/raft_flutter/lib/data/message_task_cache.dart': {'rootEdges': 1, 'rootIdentifiers': 8},
 'apps/raft_flutter/lib/data/source_server_unread.dart': {'rootEdges': 1, 'rootIdentifiers': 1},
 'apps/raft_flutter/lib/data/source_task_bucket.dart': {'rootEdges': 1, 'rootIdentifiers': 1},
 'apps/raft_flutter/lib/data/workspace_grid_sessions.dart': {'rootEdges': 1, 'rootIdentifiers': 6},
 'apps/raft_flutter/lib/data/workspace_mode_store.dart': {'rootEdges': 1, 'rootIdentifiers': 1}}

class DomainGuardTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='raft-domain-policy-')
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.data = self.root / 'apps/raft_flutter/lib/data'
        self.data.mkdir(parents=True)
        (self.root / 'tool').mkdir()
        self.manifest = self.root / guard.MANIFEST
        self.manifest.write_text(json.dumps({'legacyDomains': {}, 'compositionHosts': {}}))

    def source(self, text, name='owner.dart'):
        path = self.data / name
        path.write_text(text)
        return path

    def test_comments_strings_and_json_dynamic_are_not_root_access(self):
        self.source("// import 'workspace_controller.dart'; WorkspaceController\n"
                    "void parse(dynamic payload) { final x = payload['server']; print(x); }\n"
                    "const text = 'WorkspaceController as dynamic';\n"
                    "final part = 'workspace_controller.dart';\n")
        self.assertTrue(guard.check(self.root)['passed'])

    def test_new_direct_root_import_is_rejected(self):
        self.source("import 'workspace_controller.dart';\n")
        self.assertFalse(guard.check(self.root)['passed'])

    def test_exported_root_alias_is_rejected(self):
        self.source("export 'workspace_controller.dart';", 'barrel.dart')
        self.source("import 'barrel.dart'; final value = 1;")
        result = guard.check(self.root)
        self.assertTrue(any('owner.dart: rootEdges' in x for x in result['findings']))

    def test_type_reference_and_dynamic_cast_are_rejected(self):
        self.source('Object cast(Object value) => value as WorkspaceController;')
        self.assertFalse(guard.check(self.root)['passed'])
        self.source('void work(Object value) { (value as dynamic).ledger.clear(); }')
        self.assertFalse(guard.check(self.root)['passed'])

    def test_dynamic_authority_is_rejected_without_banning_json(self):
        self.source('void work(dynamic _authority) { _authority.selectChannel(null); }')
        self.assertFalse(guard.check(self.root)['passed'])

    def test_opaque_receiver_alias_cannot_read_root_members(self):
        self.source('void work(Context context) { final key = context.receiverKey; '
                    'final alias = key; alias.server = null; }')
        self.assertFalse(guard.check(self.root)['passed'])

    def test_identity_key_can_be_passed_without_member_access(self):
        self.source('void work(Context context) { final key = context.receiverKey; '
                    'tags[key] = true; identical(key, context.receiverKey); }')
        self.assertTrue(guard.check(self.root)['passed'])

    def test_legacy_allowance_cannot_grow_and_must_retire_when_clean(self):
        path = self.source("import 'workspace_controller.dart'; WorkspaceController? owner;")
        stats, _ = guard.inspect(self.root, path, path.read_text())
        relative = path.relative_to(self.root).as_posix()
        self.manifest.write_text(json.dumps({'legacyDomains': {relative: stats}, 'compositionHosts': {}}))
        self.assertTrue(guard.check(self.root)['passed'])
        path.write_text(path.read_text() + ' WorkspaceController? extra;')
        self.assertFalse(guard.check(self.root)['passed'])
        path.write_text('class MigratedOwner {}')
        self.assertTrue(any('stale legacy' in x for x in guard.check(self.root)['findings']))

    def test_feature_view_model_is_checked_outside_data(self):
        feature = self.root / 'apps/raft_flutter/lib/features/chat_view_model.dart'
        feature.parent.mkdir()
        feature.write_text("import '../data/workspace_controller.dart';")
        self.assertFalse(guard.check(self.root)['passed'])

    def test_repository_allowances_do_not_expand_the_frozen_baseline(self):
        root = SCRIPT.parent.parent
        manifest = json.loads((root / guard.MANIFEST).read_text())
        self.assertLessEqual(set(manifest['compositionHosts']), {'apps/raft_flutter/lib/data/workspace_grid_sessions.dart'})
        for name, allowance in (manifest['legacyDomains'] | manifest['compositionHosts']).items():
            self.assertIn(name, BASELINE_MAXIMA)
            for kind in ('rootEdges', 'rootIdentifiers'):
                self.assertLessEqual(allowance[kind], BASELINE_MAXIMA[name][kind])

    def test_missing_allowance_file_is_rejected(self):
        self.manifest.write_text(json.dumps({'legacyDomains': {'apps/raft_flutter/lib/data/gone.dart': {'rootEdges': 1, 'rootIdentifiers': 0}}, 'compositionHosts': {}}))
        self.assertFalse(guard.check(self.root)['passed'])


if __name__ == '__main__':
    unittest.main()
