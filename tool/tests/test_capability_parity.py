"""Unit tests for tool/capability_parity.py (Web call extraction), on synthetic sources."""
import importlib.util
import sys
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location(
    'capability_parity', Path(__file__).resolve().parents[1] / 'capability_parity.py')
cp = importlib.util.module_from_spec(SPEC)
sys.modules['capability_parity'] = cp  # dataclasses resolve annotations through sys.modules
SPEC.loader.exec_module(cp)


def make_web(files):
    root = tempfile.mkdtemp()
    for rel, text in files.items():
        path = Path(root, 'packages', 'web', 'src', rel)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding='utf-8')
    return root


class NormaliseTests(unittest.TestCase):
    def test_template_placeholders_become_id_and_query_is_dropped(self):
        self.assertEqual(
            cp.normalise_path('`/channels/${channelId}/members/${encodeURIComponent(userId)}?x=${y}`'),
            '/channels/:id/members/:id')

    def test_plain_and_concatenated_strings(self):
        self.assertEqual(cp.normalise_path('"/servers"'), '/servers')
        self.assertEqual(cp.normalise_path('"/tasks/" + id + "/status"'), '/tasks/:id/status')

    def test_dynamic_head_is_unresolved(self):
        self.assertIsNone(cp.normalise_path('somePath'))

    def test_branches_of_a_ternary(self):
        self.assertEqual(
            cp._branches('scope === "server" ? "/mcp/servers" : `/mcp/agents/${id}`'),
            ['"/mcp/servers"', '`/mcp/agents/${id}`'])


class ExtractTests(unittest.TestCase):
    def extract(self, files):
        root = make_web(files)
        self.addCleanup(lambda: __import__('shutil').rmtree(root))
        return root, cp.extract_web(root)

    def test_methods_generics_and_multiline_receivers(self):
        root, calls = self.extract({
            'a.ts': (
                'async function save(id: string) {\n'
                '  await api.patch<{ ok: boolean }>(`/servers/${id}`, { name });\n'
                '  const r = api\n    .get("/servers");\n'
                '  await api.delete(`/servers/${id}/members/${userId}`);\n'
                '  map.get("not-a-path");\n'
                '}\n')})
        self.assertEqual(
            cp.keys(calls),
            ['DELETE /servers/:id/members/:id', 'GET /servers', 'PATCH /servers/:id'])
        self.assertEqual(calls[0].enclosing, 'save')

    def test_test_files_are_skipped(self):
        _root, calls = self.extract({
            'a.test.ts': 'api.get("/hidden");',
            'b.ts': 'api.get("/shown");'})
        self.assertEqual(cp.keys(calls), ['GET /shown'])

    def test_constants_and_helper_functions_resolve_through_the_index(self):
        _root, calls = self.extract({
            'p.ts': (
                'const BASE = "/slack-bridge/provisioning";\n'
                'export function itemPath(id: string): string {\n  return `/items/${id}`;\n}\n'),
            'c.ts': (
                'client.post(`${BASE}/connect`);\n'
                'api.get(itemPath(x));\n')})
        self.assertEqual(cp.keys(calls), ['GET /items/:id', 'POST /slack-bridge/provisioning/connect'])

    def test_local_const_and_ternary(self):
        _root, calls = self.extract({
            'm.ts': (
                'function load() {\n'
                '  const endpoint = scope === "server" ? "/mcp/servers" : `/mcp/agents/${agentId}`;\n'
                '  api.get(endpoint);\n}\n')})
        self.assertEqual(cp.keys(calls), ['GET /mcp/agents/:id', 'GET /mcp/servers'])

    def test_request_config_form_expands_method_ternary(self):
        _root, calls = self.extract({
            'r.ts': (
                'api.request<Ack>({\n  method: on ? "post" : "delete",\n'
                '  url: `/messages/${id}/reactions`,\n  data: {},\n});\n')})
        self.assertEqual(cp.keys(calls), ['DELETE /messages/:id/reactions', 'POST /messages/:id/reactions'])

    def test_unresolved_calls_are_reported_not_dropped(self):
        _root, calls = self.extract({'u.ts': 'function f(path: string) { api.get(path); }'})
        self.assertEqual(len(calls), 1)
        self.assertFalse(calls[0].resolved)

    def test_indirect_table_expands_known_parameter_paths(self):
        _root, calls = self.extract({
            'components/agent/AgentAppAccessTab.tsx': 'const act = async (path: string) => { await api.post(path, {}); };'})
        self.assertEqual(
            cp.keys(calls),
            ['POST /integrations/grants/:id/revoke', 'POST /integrations/requests/:id/approve',
             'POST /integrations/requests/:id/deny'])

    def test_other_network_use_is_keyed_per_file_and_socket_event(self):
        root = make_web({
            'x.ts': 'fetch("/a");\n// fetch (comment only)\n',
            'y.ts': '// fetch(  in a comment\n',
            'z.ts': 'socket.emit("join:channel", id);'})
        self.addCleanup(lambda: __import__('shutil').rmtree(root))
        self.assertEqual(cp.extract_other(root), ['RAW x.ts', 'SOCKET emit join:channel'])

    def test_not_a_checkout_exits(self):
        with self.assertRaises(SystemExit):
            cp.extract_web(tempfile.gettempdir() + '/definitely-missing-checkout')


class DartTests(unittest.TestCase):
    def paths(self, code):
        root = tempfile.mkdtemp()
        self.addCleanup(lambda: __import__('shutil').rmtree(root))
        target = Path(root, 'apps/raft_flutter/lib/a.dart')
        target.parent.mkdir(parents=True)
        target.write_text(code, encoding='utf-8')
        Path(root, 'packages/raft_client/lib').mkdir(parents=True)
        return [(d.method, d.key_path) for d in cp.extract_flutter(root, {'servers', 'channels'})]

    def test_interpolation_methods_and_ternaries(self):
        got = self.paths(
            "void f() {\n"
            "  client.post('/servers/$id/leave');\n"
            "  client.request('PATCH', '/channels/${c['id']}/x');\n"
            "  client.get('/channels/$id/${unread ? 'unread' : 'read'}');\n"
            "  var s = 'not a /servers path';\n}\n")
        self.assertIn(('POST', '/servers/:id/leave'), got)
        self.assertIn(('PATCH', '/channels/:id/x'), got)
        self.assertIn(('GET', '/channels/:id/unread'), got)
        self.assertIn(('GET', '/channels/:id/read'), got)
        self.assertEqual(len(got), 4)


class OverloadRetryWrapperTests(unittest.TestCase):
    def test_wrapper_calls_count_as_get_and_its_own_passthrough_does_not(self):
        root = make_web({
            'api/overloadRetry.ts': 'export const getWithRwOverloadRetry = (async (url: string) => {\n  return api.get(url);\n}) as typeof api.get;\n',
            'store/s.ts': 'import { getWithRwOverloadRetry } from "../api/overloadRetry";\n'
                          'async function f() { await getWithRwOverloadRetry("/channels/unread", { params: { summary: 1 } }); }\n',
        })
        keys = [f'{c.method} {c.key_path}' for c in cp.extract_web(root)]
        self.assertEqual(keys, ['GET /channels/unread'])


class ReportTests(unittest.TestCase):
    def test_committed_markdown_matches_the_json(self):
        spec = importlib.util.spec_from_file_location(
            'capability_parity_report', Path(__file__).resolve().parents[1] / 'capability_parity_report.py')
        report = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(report)
        self.assertEqual(report.main(['report', '--check']), 0,
                         'run python3 tool/capability_parity_report.py')

    def test_every_entry_has_a_known_status_and_area(self):
        import json
        doc = json.loads(Path(__file__).resolve().parents[2].joinpath('docs/capability-parity.json').read_text())
        for e in doc['entries']:
            self.assertIn(e['status'], {'covered', 'partial', 'missing', 'na'}, e['id'])


if __name__ == '__main__':
    unittest.main()
