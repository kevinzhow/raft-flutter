"""tool/upstream_sync.py for Web 1.24: a release that moves and splits files (components/* -> features/*).

Git sees those as a delete and an add; the report followed them by exported names and copy ids, so a moved
file is neither "removed" nor a "new feature", and path-map.md lists old -> new for `// Source:` comments.
Also: the counterpart guesses that misled the v1.21.23 -> v1.24.0 report, a new feature area that
read "skip", and the `pending` entry of docs/upstream-sync.json (work under way, pin unchanged).
"""
import importlib.util
import json
import os
import shutil
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
W = 'packages/web/src/'


def git(cwd, *args):
    return subprocess.run(['git', *args], cwd=cwd, env=GIT_ENV, check=True, capture_output=True, text=True).stdout


def write_tree(root, files):
    for rel, text in files.items():
        p = Path(root, rel)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding='utf-8')


def filler(tag, n):
    return ''.join(f'const {tag}Line{i} = {i};\n' for i in range(n))


OLD_CHAT = ('export function ChatPanel() { return intl("chat.title"); }\n'
            'export const CHAT_MOBILE_BACK_PROPS = { a: 1 };\n'
            'export function getThreadParentMessageIdFromParam(p: string) { return p; }\n' + filler('old', 200))
V1 = {
    W + 'components/message/ChatPanel.tsx': OLD_CHAT,
    W + 'components/ui/BottomSheet.tsx': 'export function BottomSheetFrame() {}\nexport function stopClickPropagation(e) {}\n'
                                         'export const BOTTOM_SHEET_EASING = 1;\n',
    W + 'components/billing/UpgradeDialog.tsx': 'export function UpgradeDialog() {}\n' + filler('up', 40),
    W + 'components/agentMigration/log/model.ts': 'export const LOG_MODEL_A = 1;\n' + filler('model', 40),
    W + 'raftbench/model.ts': 'export const BENCH_RULES = 1;\n',
    W + 'i18n/messages/en.ts': 'export const en = {\n  "chat.title": "Chat",\n};\n',
    W + 'i18n/messages/zh-cn.ts': 'export const zhCn = {\n  "chat.title": "聊天",\n};\n',
}
V2 = {
    W + 'features/channel/ChatPanel.tsx': ('export function ChatPanel() { return intl("chat.title"); }\n'
                                          'export const CHAT_MOBILE_BACK_PROPS = { a: 2 };\n' + filler('new', 150)),
    W + 'features/channel/chatPanelHelpers.ts': 'export function getThreadParentMessageIdFromParam(p: string) { return p.trim(); }\n',
    W + 'components/message/MessageItem.tsx': 'export function stopClickPropagation(e) { e.stop(); }\n',
    W + 'components/billing/UpgradeDialog.tsx': 'export function UpgradeDialog() {}\n' + filler('up2', 60),
    W + 'components/agentMigration/log/model.ts': 'export const LOG_MODEL_A = 2;\n' + filler('model2', 60),
    W + 'assistant/AssistantPage.tsx': filler('assist', 150),
    W + 'assistant/AssistantSettings.tsx': filler('assistSettings', 120),
    W + 'assistant/assistantApi.ts': 'const BASE = "/servers";\nexport const a = () => api.get(`${BASE}/assistant`);\n',
}


class MoveTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        base = Path(tempfile.mkdtemp())
        cls.addClassCleanup(shutil.rmtree, base)
        work = base / 'work'
        work.mkdir()
        git(work, 'init', '-q')
        write_tree(work, V1)
        git(work, 'add', '-A')
        git(work, 'commit', '-q', '-m', 'Release v1.0.0-source.1')
        git(work, 'tag', 'v1.0.0-source.1')
        for rel in (W + 'components/message/ChatPanel.tsx', W + 'components/ui/BottomSheet.tsx'):
            Path(work, rel).unlink()
        write_tree(work, V2)
        git(work, 'add', '-A')
        git(work, 'commit', '-q', '-m', 'Release v1.1.0-source.1')
        git(work, 'tag', 'v1.1.0-source.1')
        remote = base / 'remote.git'
        subprocess.run(['git', 'clone', '-q', '--bare', str(work), str(remote)], check=True, env=GIT_ENV)
        cls.mirror = base / 'm.git'
        us.ensure_mirror(cls.mirror, str(remote))
        cls.repo = base / 'repo'
        write_tree(cls.repo, {
            'docs/upstream-sync.json': json.dumps({'schema': 1, 'pinned': 'v1.0.0-source.1', 'commit': '', 'history': []}),
            'apps/raft_flutter/lib/features/chat_panel_view.dart': '// Source: components/message/ChatPanel.tsx\n',
            'packages/raft_ui/lib/src/raftbench/raftbench_rules.dart': '/// Web `raftbench/model.ts` rules.\n',
            'apps/raft_flutter/lib/data/computer_upgrade_in_flight.dart': '// computers\n',
        })
        cls.out = base / 'out'
        cls.report = us.generate_report(cls.mirror, cls.repo, 'v1.0.0-source.1', 'v1.1.0-source.1', base / 'trees')
        us.write_report(cls.report, cls.out)
        cls.ui = {x['path'][len(W):]: x for x in cls.report['web_ui']['files']}

    def test_a_split_file_is_followed_by_its_names(self):
        moves = {m['old'][len(W):]: m for m in self.report['moves']}
        chat = moves['components/message/ChatPanel.tsx']
        self.assertEqual(chat['kind'], 'split')
        self.assertEqual({t['path'][len(W):] for t in chat['targets']},
                         {'features/channel/ChatPanel.tsx', 'features/channel/chatPanelHelpers.ts'})
        self.assertEqual(chat['ours'], ['apps/raft_flutter/lib/features/chat_panel_view.dart'])
        # One shared helper name is a coincidence: BottomSheet was removed, not moved into MessageItem.
        self.assertNotIn('components/ui/BottomSheet.tsx', moves)

    def test_moved_files_inherit_the_counterpart_and_are_not_removals(self):
        helpers = self.ui['features/channel/chatPanelHelpers.ts']['cp']
        self.assertEqual(helpers['confidence'], 'documented')
        self.assertIn('moved from ChatPanel.tsx', helpers['via'])
        removals = ' '.join(d['what'] for d in self.report['decisions'] if d['kind'] == 'removal')
        self.assertNotIn('ChatPanel', removals)
        self.assertIn('BottomSheet', removals)
        feats = [d['title'] for d in self.report['decisions'] if d['kind'] == 'feature']
        self.assertNotIn('ChatPanel (new)', feats)

    def test_path_map_is_written(self):
        md = (self.out / 'path-map.md').read_text(encoding='utf-8')
        self.assertIn('`components/message/ChatPanel.tsx` | split', md)
        self.assertIn('chat_panel_view.dart', md)
        data = json.loads((self.out / 'path-map.json').read_text(encoding='utf-8'))
        self.assertEqual(data['to'], 'v1.1.0-source.1')
        self.assertIn('Moved and split Web files', (self.out / 'report.md').read_text(encoding='utf-8'))

    def test_counterpart_guesses_need_a_matching_directory_or_a_leading_word(self):
        self.assertEqual(self.ui['components/agentMigration/log/model.ts']['cp']['confidence'], 'none')
        self.assertEqual(self.ui['components/billing/UpgradeDialog.tsx']['cp']['confidence'], 'none')

    def test_a_new_feature_area_is_discussed_not_skipped(self):
        row = next(d for d in self.report['decisions'] if d['kind'] == 'area' and d['area'] == 'assistant')
        self.assertEqual(row['action'], 'discuss')
        self.assertIn('new Web feature area', row['reason'])


class PendingTests(unittest.TestCase):
    def test_pending_release_stays_pending_until_its_decision(self):
        repo = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, repo)
        state = {'schema': 1, 'pinned': 'v1.0.0-source.1', 'commit': '', 'history': [],
                 'pending': {'tag': 'v1.1.0-source.1', 'commit': 'c', 'from': 'v1.0.0-source.1', 'since': '2026-11-13', 'note': 'n'}}
        write_tree(repo, {'docs/upstream-sync.json': json.dumps(state)})
        self.assertEqual(us.load_state(repo)['pinned'], 'v1.0.0-source.1')
        us.record_decision(repo, 'v1.1.0-source.1', 'follow', 'done', date='2026-11-20')
        after = us.load_state(repo)
        self.assertEqual(after['pinned'], 'v1.1.0-source.1')
        self.assertNotIn('pending', after)

    def test_the_repository_state_is_pending_v124_and_still_pinned_to_v12123(self):
        state = us.load_state(us.ROOT)
        self.assertEqual(state['pinned'], 'v1.21.23-source.1')
        self.assertEqual(state['pending']['tag'], 'v1.24.0-source.1')


if __name__ == '__main__':
    unittest.main()
