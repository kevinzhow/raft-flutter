import importlib.util
from pathlib import Path
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('docs_index', TOOL / 'docs_index.py')
docs_index = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(docs_index)

README = (
    '# docs/ index\n\n'
    '- `architecture.md` — layers — before structural changes.\n'
    '- `licenses/` — license notices — when adding assets.\n'
    '- `a.md`, `b.md` — two docs — sometimes.\n'
)


BASE = ['architecture.md', 'a.md', 'b.md', 'licenses/x.txt']


def make(files, readme=README):
    files = list(dict.fromkeys([*BASE, *files]))
    root = Path(tempfile.mkdtemp()) / 'docs'
    root.mkdir()
    for name in files:
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('x')
    if readme is not None:
        (root / 'README.md').write_text(readme)
    return root


class DocsIndexTests(unittest.TestCase):
    def test_the_repository_docs_pass(self):
        docs = TOOL.parent / 'docs'
        problems = docs_index.check(docs) + docs_index.stale_legacy_entries(docs)
        self.assertEqual(problems, [], '\n'.join(problems) + '\n' + docs_index.MESSAGE)

    def test_listed_files_and_directory_contents_pass(self):
        root = make(['licenses/deep/y.txt'])
        self.assertEqual(docs_index.check(root), [])

    def test_unlisted_file_fails(self):
        root = make(['new-rule.md'])
        self.assertEqual(docs_index.check(root), ['docs/new-rule.md is not listed in docs/README.md.'])

    def test_unlisted_file_in_unlisted_directory_fails(self):
        root = make(['extra/z.md'])
        self.assertEqual(docs_index.check(root), ['docs/extra/z.md is not listed in docs/README.md.'])

    def test_forbidden_names_fail_even_when_listed(self):
        for name in ['fix-evidence.md', 'x-audit.md', 'perf-investigation.md', 'Findings.md', 'batch-checkpoint.md']:
            root = make([name], README + f'- `{name}` — d — w.\n')
            problems = docs_index.check(root)
            self.assertEqual(len(problems), 1, name)
            self.assertIn('not allowed', problems[0])

    def test_forbidden_name_in_a_listed_directory_fails(self):
        root = make(['licenses/run-evidence.txt'])
        self.assertEqual(len(docs_index.check(root)), 1)

    def test_legacy_names_are_tolerated_only_while_they_exist(self):
        legacy = sorted(docs_index.LEGACY_FLAGGED_NAMES)
        readme = README + ''.join(f'- `{n}` — d — w.\n' for n in legacy)
        root = make([*legacy], readme)
        self.assertEqual(docs_index.check(root), [])
        self.assertEqual(docs_index.stale_legacy_entries(root), [])
        (root / legacy[0]).unlink()
        (root / 'README.md').write_text(readme.replace(f'- `{legacy[0]}` — d — w.\n', ''))
        self.assertEqual(docs_index.check(root), [])
        self.assertEqual(len(docs_index.stale_legacy_entries(root)), 1)

    def test_readme_entry_for_a_missing_file_fails(self):
        root = make([])
        (root / 'b.md').unlink()
        self.assertEqual(docs_index.check(root), ['docs/README.md lists b.md, which does not exist.'])

    def test_missing_readme_fails(self):
        self.assertEqual(docs_index.check(make([], readme=None)), ['docs/README.md is missing.'])

    def test_main_prints_the_required_message(self):
        root = make(['new.md'])
        problems = docs_index.check(root)
        self.assertTrue(problems)
        self.assertEqual(docs_index.MESSAGE,
                         'Verification evidence goes in the PR description, not docs/. Living docs must be listed in docs/README.md.')


if __name__ == '__main__':
    unittest.main()
