"""Unit tests for tool/upstream_sync.py on synthetic upstream repositories (no network)."""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location('upstream_sync', Path(__file__).resolve().parents[1] / 'upstream_sync.py')
us = importlib.util.module_from_spec(SPEC)
sys.modules['upstream_sync'] = us
SPEC.loader.exec_module(us)

GIT_ENV = dict(os.environ, GIT_AUTHOR_NAME='t', GIT_AUTHOR_EMAIL='t@example.invalid', GIT_COMMITTER_NAME='t',
               GIT_COMMITTER_EMAIL='t@example.invalid', GIT_TERMINAL_PROMPT='0')


def git(cwd, *args):
    return subprocess.run(['git', *args], cwd=cwd, env=GIT_ENV, check=True, capture_output=True, text=True).stdout


def write_tree(root, files):
    for rel, text in files.items():
        p = Path(root, rel)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding='utf-8')


def make_release(work, tag, files, remove=()):
    """Commit `files` (and remove paths) in the work repo, then tag it (snapshots, like upstream)."""
    write_tree(work, files)
    for rel in remove:
        Path(work, rel).unlink()
    git(work, 'add', '-A')
    git(work, 'commit', '-q', '--allow-empty', '-m', f'Release {tag}')
    git(work, 'tag', tag)


V1 = {
    'packages/web/src/components/foo/FooPanel.tsx': 'export default function FooPanel(){ api.get("/foo"); return <Bar title="a" />; }\n',
    'packages/web/src/components/old/OldThing.tsx': 'export const OldThing = 1;\n',
    'packages/web/src/store/fooStore.ts': 'export interface Foo {\n  id: string;\n  name?: string;\n  legacyKey: number;\n}\n',
    'packages/web/src/i18n/messages/en.ts': 'export const en = {\n  "foo.title": "Foo",\n  "foo.gone": "Gone text",\n  "foo.same": "Same",\n};\n',
    'packages/web/src/i18n/messages/zh-cn.ts': 'export const zhCn = {\n  "foo.title": "富",\n  "foo.gone": "没了",\n  "foo.same": "相同",\n};\n',
    'packages/visual-testing/shared/sharedCases.json': json.dumps({'cases': [{'id': 'components.foo.panel', 'title': 'Foo', 'surface': 'foo'}]}),
    'packages/web/package.json': json.dumps({'dependencies': {'raft-ui': '0.5.27'}}),
    'packages/server/src/app.ts': 'app.use("/api/foo", requireAuth, fooRouter);\n',
    'packages/server/src/routes/foo.ts': 'export const fooRouter = Router();\nfooRouter.get("/", async (req, res) => {\n  const rows = list().sort(byName);\n  res.json(rows);\n});\n',
    'packages/web/src/index.css': ':root { --a: 1px; --b: 2px; }\n',
}
V2 = {
    'packages/web/src/components/foo/FooPanel.tsx': 'export default function FooPanel(){ api.get("/foo"); api.post("/foo/archive"); return <Bar title="a" extra={1} />; }\n',
    'packages/web/src/components/foo/NewThing.tsx': '\n'.join(f'const l{i} = {i};' for i in range(120)) + '\nexport const t = intl("foo.fresh");\n',
    'packages/web/src/store/fooStore.ts': 'export interface Foo {\n  id: string;\n  name?: string;\n  freshKey: string;\n}\n',
    'packages/web/src/i18n/messages/en.ts': 'export const en = {\n  "foo.title": "Foo!",\n  "foo.fresh": "Fresh text",\n  "foo.same": "Same",\n};\n',
    'packages/web/src/i18n/messages/zh-cn.ts': 'export const zhCn = {\n  "foo.title": "富了",\n  "foo.fresh": "新文案",\n  "foo.same": "同样",\n};\n',
    'packages/visual-testing/shared/sharedCases.json': json.dumps({'cases': [{'id': 'components.foo.panel', 'title': 'Foo', 'surface': 'foo'},
                                                                            {'id': 'components.foo.fresh', 'title': 'Fresh', 'surface': 'foo', 'baselineStatus': 'pending'}]}),
    'packages/web/package.json': json.dumps({'dependencies': {'raft-ui': '0.5.52'}}),
    'packages/server/src/routes/foo.ts': 'export const fooRouter = Router();\nfooRouter.get("/", async (req, res) => {\n  if (!isAdmin(req)) return res.status(403).json({ error: "no" });\n  const rows = list().sort(byDate);\n  res.json(rows);\n});\n',
    'packages/web/src/index.css': ':root { --a: 3px; --c: 4px; }\n',
}


def make_upstream():
    """-> (bare remote dir, work dir). Tags: v1.2.0, v1.2.10, v1.10.0 (+ a non-release tag)."""
    base = Path(tempfile.mkdtemp())
    work = base / 'work'
    work.mkdir()
    git(work, 'init', '-q')
    make_release(work, 'v1.2.0-source.1', V1)
    make_release(work, 'v1.2.10-source.1', V2, remove=['packages/web/src/components/old/OldThing.tsx'])
    git(work, 'tag', 'not-a-release')
    remote = base / 'remote.git'
    subprocess.run(['git', 'clone', '-q', '--bare', str(work), str(remote)], check=True, env=GIT_ENV)
    return remote, work


def make_repo(pinned='v1.2.0-source.1'):
    repo = Path(tempfile.mkdtemp())
    write_tree(repo, {
        'docs/upstream-sync.json': json.dumps({'schema': 1, 'pinned': pinned, 'commit': '', 'history': []}),
        'packages/raft_ui/lib/src/l10n/zh_x.dart': "const Map<String, String> zhCatalogX = {\n  'Foo': '富',\n  'Same': '相同',\n  'Gone text': '没了',\n};\n",
        'apps/raft_flutter/lib/features/foo_panel.dart': "// Source: FooPanel.tsx\nfinal k = 'legacyKey';\n",
        'docs/capability-parity.json': json.dumps({'entries': [
            {'kind': 'endpoint', 'id': 'GET /foo', 'status': 'covered', 'capability': 'List foos', 'webEntry': 'FooPanel.tsx',
             'flutterRefs': [{'file': 'apps/raft_flutter/lib/features/foo_panel.dart', 'needle': 'x'}]}]}),
    })
    return repo


class TagTests(unittest.TestCase):
    def test_semver_sort_not_lexicographic(self):
        remote, _ = make_upstream()
        mirror = Path(tempfile.mkdtemp()) / 'm.git'
        us.ensure_mirror(mirror, str(remote))
        self.assertEqual(us.list_tags(mirror), ['v1.2.0-source.1', 'v1.2.10-source.1'])

    def test_mirror_fetches_new_tags(self):
        remote, work = make_upstream()
        mirror = Path(tempfile.mkdtemp()) / 'm.git'
        us.ensure_mirror(mirror, str(remote))
        make_release(work, 'v1.10.0-source.1', {'x.txt': 'x'})
        git(work, 'push', '-q', str(remote), '--tags')
        us.ensure_mirror(mirror, str(remote))
        self.assertEqual(us.list_tags(mirror)[-1], 'v1.10.0-source.1')
        us.ensure_mirror(mirror, str(remote), fetch=False)  # no network when told not to

    def test_unreachable_remote_is_a_clear_error(self):
        mirror = Path(tempfile.mkdtemp()) / 'm.git'
        with self.assertRaises(us.UpstreamError) as cm:
            us.ensure_mirror(mirror, '/nonexistent/path/to/repo.git')
        self.assertIn('git', str(cm.exception).lower())
        self.assertFalse(mirror.exists())

    def test_auth_failure_message(self):
        e = us._network_error("fatal: could not read Username for 'https://github.com': terminal prompts disabled")
        self.assertIn('without credentials', str(e))

    def test_unknown_tag(self):
        remote, _ = make_upstream()
        mirror = Path(tempfile.mkdtemp()) / 'm.git'
        us.ensure_mirror(mirror, str(remote))
        with self.assertRaises(us.UpstreamError):
            us.tag_info(mirror, 'v9.9.9-source.1')

    def test_resolve_range_defaults_to_pinned_and_latest(self):
        remote, _ = make_upstream()
        mirror = Path(tempfile.mkdtemp()) / 'm.git'
        us.ensure_mirror(mirror, str(remote))
        repo = make_repo()
        self.assertEqual(us.resolve_range(mirror, repo, None, None), ('v1.2.0-source.1', 'v1.2.10-source.1'))
        with self.assertRaises(us.UpstreamError):
            us.resolve_range(mirror, make_repo('v1.2.10-source.1'), None, None)


class DesignSystemDriftTests(unittest.TestCase):
    def setUp(self):
        remote, _ = make_upstream()
        self.mirror = Path(tempfile.mkdtemp()) / 'm.git'
        us.ensure_mirror(self.mirror, str(remote))
        self.repo = Path(tempfile.mkdtemp())

    def recipes_from(self, version):
        write_tree(self.repo, {us.RECIPES_DOC: f'GENERATED by `tool/recipes/run` from raft-ui {version} (`dist/index.mjs`)\n'})

    def test_reads_the_web_raft_ui_version_including_npm_aliases(self):
        self.assertEqual(us.web_raft_ui_version(self.mirror, 'v1.2.0-source.1'), '0.5.27')

    def test_recipes_on_another_raft_ui_than_the_web_are_reported(self):
        # 2026-10-26: the Web had moved to raft-ui 0.7.0 while the recipes stayed on 0.5.52.
        self.recipes_from('0.5.20')
        drift = us.design_system_drift(self.mirror, self.repo, 'v1.2.0-source.1')
        self.assertIn('raft-ui 0.5.27', drift)
        self.assertIn('0.5.20', drift)
        self.assertIn('tool/recipes/run', drift)

    def test_matching_versions_are_quiet(self):
        self.recipes_from('0.5.27')
        self.assertIsNone(us.design_system_drift(self.mirror, self.repo, 'v1.2.0-source.1'))


class ClassifyTests(unittest.TestCase):
    def test_categories(self):
        c = us.classify
        self.assertEqual(c('packages/web/src/components/settings/SettingsPanel.tsx'), ('web_ui', 'components/settings'))
        self.assertEqual(c('packages/web/src/store/messageStore.ts'), ('web_ui', 'store'))
        self.assertEqual(c('packages/web/src/pages/HomePage.tsx'), ('web_ui', 'pages'))
        self.assertEqual(c('packages/web/src/i18n/messages/en.ts')[0], 'i18n')
        self.assertEqual(c('packages/web/src/index.css')[0], 'styles')
        self.assertEqual(c('packages/server/src/routes/agents.ts')[0], 'server_api')
        self.assertEqual(c('packages/server/src/services/billingService.ts')[0], 'server_other')
        self.assertEqual(c('packages/shared/src/index.ts')[0], 'shared_types')
        self.assertEqual(c('packages/web/visual-testing/VisualTestingCases.tsx')[0], 'visual_cases')
        self.assertEqual(c('packages/visual-testing/shared/sharedCases.json')[0], 'visual_cases')
        self.assertEqual(c('manual/agent-knowledge/app.md')[0], 'docs')
        self.assertEqual(c('packages/daemon/src/core.ts')[0], 'runtime_other')

    def test_tests_and_infra_are_ignored(self):
        for p in ('packages/web/src/components/a/A.test.tsx', 'packages/web/tests/foo.test.ts', 'pnpm-lock.yaml',
                  'packages/server/drizzle/meta/0335_snapshot.json', 'packages/server/src/services/x.test.ts',
                  'infra/risingwave/a.sql', 'packages/web/tests/e2e/a.spec.ts'):
            self.assertEqual(us.classify(p)[0], 'tests_infra', p)


class ParserTests(unittest.TestCase):
    def test_ts_interface_type_and_zod(self):
        text = '''
export interface Foo extends Base {
  id: string;
  name?: string | null; // trailing
  "quoted-key": number,
  nested: { a: number; b: string };
  fn: (x: number) => void;
}
export type Bar = {
  readonly one: 1
  two?: "a" | "b"
}
export const fooSchema = z.object({
  title: z.string().min(1),
  tags: z.array(z.string()).optional(),
});
'''
        shapes = us.parse_ts_shapes(text)
        self.assertEqual(set(shapes['Foo']), {'id', 'name?', 'quoted-key', 'nested', 'fn'})
        self.assertEqual(set(shapes['Bar']), {'one', 'two?'})
        self.assertEqual(set(shapes['fooSchema']), {'title', 'tags'})

    def test_shape_diff(self):
        old = {'A': {'x': 'string', 'y': 'number'}, 'Gone': {'q': 'string'}}
        new = {'A': {'x': 'number', 'z': 'string'}, 'New': {'w': 'string'}}
        d = us.diff_shapes(old, new)
        self.assertEqual([t['name'] for t in d['added_types']], ['New'])
        self.assertEqual([t['name'] for t in d['removed_types']], ['Gone'])
        a = d['changed']['A']
        self.assertEqual([i['field'] for i in a['added']], ['z'])
        self.assertEqual([i['field'] for i in a['removed']], ['y'])
        self.assertEqual([i['field'] for i in a['retyped']], ['x'])

    def test_i18n_catalog_with_multiline_and_escapes(self):
        text = '''export const en = {
  "a.b": "Hello \\"x\\"",
  "a.c":
    "On the next line",
  "a.d": `tmpl {n}`,
  // "a.e": "commented",
};'''
        c = us.parse_i18n_catalog(text)
        self.assertEqual(c['a.b'], 'Hello "x"')
        self.assertEqual(c['a.c'], 'On the next line')
        self.assertEqual(c['a.d'], 'tmpl {n}')
        self.assertNotIn('a.e', c)

    def test_dart_catalog(self):
        text = """const Map<String, String> zhCatalogX = {
  // comment 'skip': 'me',
  'It\\'s': '它的',
  "{count} added to #{channel}":
      "已向 #{channel} 添加 {count} 位",
  'Long ' 'joined': '拼接',
};"""
        c = us.parse_dart_catalog(text)
        self.assertEqual(c["It's"], '它的')
        self.assertEqual(c['{count} added to #{channel}'], '已向 #{channel} 添加 {count} 位')
        self.assertEqual(c['Long joined'], '拼接')
        self.assertNotIn('skip', c)

    def test_socket_events_and_route_defs(self):
        self.assertEqual(us.socket_events('on("message:new") "a/b:c" "data:image" x("plain")'), {'message:new'})
        self.assertEqual(us.route_defs('fooRouter.get("/a/:id", h);\nrouter.post(`/b`, h); other.get("/c")'), {'GET /a/:id', 'POST /b'})

    def test_mount_map_and_endpoint_normalisation(self):
        m = us.mount_map('app.use("/api/servers", requireAuth, requireVerified, serverRouter);\napp.use("/api/x", a, xRouter);')
        self.assertEqual(m['serverRouter'], ['/servers'])
        self.assertEqual(us.norm_endpoint('/servers', '/:serverId/invites/:inviteId/'), '/servers/:id/invites/:id')
        self.assertEqual(us.norm_endpoint('/', '/health'), '/health')

    def test_camel_to_snake_and_hunk_summary(self):
        self.assertEqual(us.camel_to_snake('SettingsPanel'), 'settings_panel')
        self.assertEqual(us.camel_to_snake('HTMLPreviewDialog'), 'html_preview_dialog')
        s = us.summarize_hunk_lines(['+<Foo bar={1} />', '-<Old />', '+const x = useThing();', '+  id: "a.b.c"'])
        self.assertEqual(s['jsx_added'], ['Foo'])
        self.assertEqual(s['jsx_removed'], ['Old'])
        self.assertIn('bar', s['props_added'])
        self.assertIn('useThing', s['hooks_added'])
        self.assertIn('a.b.c', s['i18n_ids_added'])

    def test_sizing(self):
        self.assertEqual([us.sizing(n) for n in (10, 150, 151, 800, 801)], ['S', 'S', 'M', 'M', 'L'])


class ReportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        remote, _ = make_upstream()
        cls.mirror = Path(tempfile.mkdtemp()) / 'm.git'
        us.ensure_mirror(cls.mirror, str(remote))
        cls.repo = make_repo()
        cls.work = Path(tempfile.mkdtemp())
        cls.report = us.generate_report(cls.mirror, cls.repo, 'v1.2.0-source.1', 'v1.2.10-source.1', cls.work)

    def test_diff_counts_use_trees(self):
        d = self.report['diff']
        self.assertEqual(d['deleted'], 1)
        self.assertIn('web_ui', d['by_category'])

    def test_api_added_and_trees_cleaned(self):
        keys = [e['key'] for e in self.report['api']['added']]
        self.assertEqual(keys, ['POST /foo/archive'])
        self.assertFalse(any(self.work.iterdir()))

    def test_ui_counterpart_and_removed_file(self):
        ui = {Path(x['path']).stem: x for x in self.report['web_ui']['files']}
        self.assertEqual(ui['FooPanel']['cp']['confidence'], 'documented')
        self.assertIn('foo_panel.dart', ui['FooPanel']['cp']['files'][0])
        self.assertEqual(ui['NewThing']['status'], 'A')
        self.assertEqual(ui['OldThing']['status'], 'D')
        self.assertIn('extra', ui['FooPanel']['summary']['props_added'])

    def test_fields_flag_reads(self):
        ch = self.report['fields']['changed']['Foo']
        self.assertEqual([i['field'] for i in ch['removed']], ['legacyKey'])
        self.assertTrue(ch['removed'][0]['ours'])  # the app mentions 'legacyKey'
        self.assertEqual(ch['action'], 'follow')

    def test_i18n_sync_buckets(self):
        i = self.report['i18n']
        self.assertEqual([x['id'] for x in i['added']], ['foo.fresh'])
        self.assertEqual([x['id'] for x in i['removed']], ['foo.gone'])
        self.assertEqual([x['id'] for x in i['changed_en']], ['foo.title'])
        self.assertEqual([x['id'] for x in i['changed_zh']], ['foo.same'])
        self.assertTrue(i['changed_zh'][0]['drift_in_ours'])  # ours keeps '相同', Web now says '同样'
        self.assertNotIn('_en_b', i)

    def test_visual_cases_added(self):
        v = self.report['visual']
        self.assertEqual([x['id'] for x in v['added']], ['components.foo.fresh'])
        self.assertEqual(v['added'][0]['baselineStatus'], 'pending')

    def test_styles_and_dependencies(self):
        s = self.report['styles']
        self.assertEqual(s['dependency_changes']['raft-ui'], ('0.5.27', '0.5.52'))
        css = s['css']['packages/web/src/index.css']
        self.assertEqual((css['added'], css['removed'], css['changed']), (['--c'], ['--b'], ['--a']))

    def test_behaviour_names_endpoint_and_tags(self):
        bh = {x['file']: x for x in self.report['behaviour']['files']}
        r = bh['routes/foo.ts']
        self.assertIn('permission', r['tags'])
        self.assertIn('sorting', r['tags'])
        self.assertEqual(r['endpoints'], ['GET /foo'])
        self.assertTrue(any('List foos' in f for f in r['flutter']))

    def test_decisions_have_all_columns(self):
        self.assertTrue(self.report['decisions'])
        for d in self.report['decisions']:
            for k in ('id', 'what', 'state', 'action', 'reason', 'size', 'risk'):
                self.assertTrue(d[k], (d['id'], k))
            self.assertIn(d['action'], us.DECISIONS)
            self.assertIn(d['size'], 'SML')
            self.assertIn(d['risk'], ('low', 'medium', 'high'))

    def test_behavior_drift_is_skipped_without_the_checklists(self):
        self.assertEqual(self.report['behavior_drift'], {'available': False, 'domains': {}})

    def test_markdown_and_json_render(self):
        out = Path(tempfile.mkdtemp())
        md, js = us.write_report(self.report, out)
        text = md.read_text(encoding='utf-8')
        for heading in ('## 决策表', '## 逻辑漂移', '## 服务端行为变化', '## 附录: zh 文案同步清单', '### Parity cases affected'):
            self.assertIn(heading, text)
        self.assertEqual(json.loads(js.read_text())['to']['tag'], 'v1.2.10-source.1')


class DecisionTests(unittest.TestCase):
    def test_record_decision_advances_pin_and_appends_history(self):
        repo = make_repo()
        e = us.record_decision(repo, 'v1.2.10-source.1', 'partial', note='ok', report_path='docs/x.md', deferred=['A03'], date='2026-10-20', commit='abc')
        state = json.loads((repo / 'docs/upstream-sync.json').read_text())
        self.assertEqual(state['pinned'], 'v1.2.10-source.1')
        self.assertEqual(state['commit'], 'abc')
        self.assertEqual(state['history'][-1], e)
        self.assertEqual((e['from'], e['deferred'], e['decision']), ('v1.2.0-source.1', ['A03'], 'partial'))

    def test_record_decision_rejects_old_or_bad_input(self):
        repo = make_repo('v1.2.10-source.1')
        with self.assertRaises(us.UpstreamError):
            us.record_decision(repo, 'v1.2.0-source.1', 'follow')
        with self.assertRaises(us.UpstreamError):
            us.record_decision(repo, 'v1.3.0-source.1', 'maybe')
        with self.assertRaises(us.UpstreamError):
            us.record_decision(repo, 'main', 'follow')
        self.assertEqual(json.loads((repo / 'docs/upstream-sync.json').read_text())['pinned'], 'v1.2.10-source.1')

    def test_cli_status_and_record(self):
        remote, _ = make_upstream()
        mirror, repo = Path(tempfile.mkdtemp()) / 'm.git', make_repo()
        base = ['--mirror', str(mirror), '--remote', str(remote), '--repo', str(repo)]
        self.assertEqual(us.main(base + ['status']), 0)
        self.assertEqual(us.main(base + ['--no-fetch', 'record-decision', '--to', 'v1.2.10-source.1', '--decision', 'follow']), 0)
        self.assertEqual(us.load_state(repo)['pinned'], 'v1.2.10-source.1')
        self.assertEqual(us.load_state(repo)['commit'], us.tag_info(mirror, 'v1.2.10-source.1')['commit'])
        self.assertEqual(us.main(base + ['--no-fetch', 'record-decision', '--to', 'v1.2.10-source.1', '--decision', 'follow']), 3)


if __name__ == '__main__':
    unittest.main()
