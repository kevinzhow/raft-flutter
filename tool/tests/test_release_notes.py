import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('release_notes', Path(__file__).resolve().parents[1] / 'release_notes.py')
notes = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(notes)

GOOD = """---
version: 0.1.0
date: 2026-10-13
---
# a comment
- feature: New thing.
- improvement!: Faster thing: now with a colon.

- fix: Fixed.
"""


class ParseTests(unittest.TestCase):
    def test_entries_types_emphasis_and_colons(self):
        item = notes.parse_note('v0.1.0+5', GOOD)
        self.assertEqual(item['releaseId'], 'v0.1.0+5')
        self.assertEqual(item['tag'], 'v0.1.0+5')
        self.assertEqual((item['version'], item['date'], item['state']), ('0.1.0', '2026-10-13', 'published'))
        self.assertEqual(item['entries'], [
            {'type': 'feature', 'text': 'New thing.', 'emphasis': False},
            {'type': 'improvement', 'text': 'Faster thing: now with a colon.', 'emphasis': True},
            {'type': 'fix', 'text': 'Fixed.', 'emphasis': False}])

    def test_version_defaults_to_the_tag_and_state_can_retract(self):
        item = notes.parse_note('v1.2.3', '---\ndate: 2026-01-02 # when\nstate: retracted\n---\n- breaking: x\n')
        self.assertEqual((item['version'], item['state']), ('1.2.3', 'retracted'))

    def test_prerelease_tag(self):
        self.assertEqual(notes.parse_note('v1.2.3-rc.1+2', GOOD.replace('0.1.0', '1.2.3-rc.1'))['version'], '1.2.3-rc.1')

    def test_bad_files_are_rejected(self):
        for tag, text in [
            ('release-1', GOOD),
            ('v0.1.0+5', 'no front matter\n- feature: x\n'),
            ('v0.1.0+5', '---\ndate: 2026-10-13\n- feature: x\n'),
            ('v0.1.0+5', GOOD.replace('2026-10-13', '13/10/2026')),
            ('v0.1.0+5', GOOD.replace('date: 2026-10-13', 'when: today')),
            ('v0.1.0+5', GOOD.replace('version: 0.1.0', 'version: 0.2.0')),
            ('v0.1.0+5', GOOD.replace('date:', 'state: draft\ndate:')),
            ('v0.1.0+5', GOOD + 'stray text\n'),
            ('v0.1.0+5', GOOD + '- feat: x\n'),
            ('v0.1.0+5', GOOD + '- feature:\n'),
            ('v0.1.0+5', GOOD + '- feature: ' + 'x' * 501 + '\n'),
            ('v0.1.0+5', '---\ndate: 2026-10-13\n---\n'),
        ]:
            with self.subTest(text=text[:60]), self.assertRaises(ValueError):
                notes.parse_note(tag, text)


class BuildTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name)

    def add(self, tag, date, version=None):
        text = GOOD.replace('2026-10-13', date).replace('0.1.0', version or tag[1:].split('+')[0])
        (self.dir / f'{tag}.md').write_text(text)

    def test_full_history_newest_first_in_web_page_shape(self):
        self.add('v0.1.0+4', '2026-10-10')
        self.add('v0.1.0+5', '2026-10-13')
        self.add('v0.1.1', '2026-10-13')
        self.add('v0.1.1-rc.1+1', '2026-10-13')
        document = notes.build('v0.1.1', self.dir)
        self.assertEqual([i['tag'] for i in document['items']],
                         ['v0.1.1', 'v0.1.1-rc.1+1', 'v0.1.0+5', 'v0.1.0+4'])
        self.assertIsNone(document['nextCursor'])
        for item in document['items']:
            self.assertEqual(set(item), {'releaseId', 'tag', 'version', 'date', 'state', 'entries'})

    def test_same_version_orders_by_plus_number(self):
        for number in (9, 10, 2):
            self.add(f'v0.1.0+{number}', '2026-10-13')
        self.assertEqual([i['tag'] for i in notes.build('v0.1.0+10', self.dir)['items']],
                         ['v0.1.0+10', 'v0.1.0+9', 'v0.1.0+2'])

    def test_release_without_notes_fails_with_the_path_to_add(self):
        self.add('v0.1.0+4', '2026-10-10')
        with self.assertRaisesRegex(ValueError, r'docs/release-notes/v0\.1\.0\+5\.md'):
            notes.build('v0.1.0+5', self.dir)

    def test_a_malformed_old_note_fails_the_build(self):
        self.add('v0.1.0+5', '2026-10-13')
        (self.dir / 'v0.1.0+4.md').write_text('broken')
        with self.assertRaises(ValueError):
            notes.build('v0.1.0+5', self.dir)

    def test_write_is_canonical_utf8_lf(self):
        self.add('v0.1.0+5', '2026-10-13')
        (self.dir / 'v0.1.0+5.md').write_text(GOOD + '- feature: café 中文\n')
        out = self.dir / 'out/release-notes.json'
        notes.write(out, 'v0.1.0+5', self.dir)
        raw = out.read_bytes()
        self.assertTrue(raw.endswith(b'\n') and b'\r' not in raw)
        self.assertIn('café 中文', raw.decode('utf-8'))
        self.assertEqual(json.loads(raw)['items'][0]['tag'], 'v0.1.0+5')


class MarkdownTests(unittest.TestCase):
    def test_groups_entries_by_type_in_a_fixed_order_and_bolds_emphasis(self):
        document = {'items': [
            {'tag': 'v1.0.0+2', 'entries': [
                {'type': 'fix', 'text': 'Fix one.', 'emphasis': False},
                {'type': 'feature', 'text': 'New one.', 'emphasis': True},
                {'type': 'improvement', 'text': 'Better one.', 'emphasis': False},
                {'type': 'fix', 'text': 'Fix two.', 'emphasis': False}]},
            {'tag': 'v1.0.0+1', 'entries': [{'type': 'fix', 'text': 'Old.', 'emphasis': False}]}]}
        text = notes.markdown(document, 'v1.0.0+2')
        self.assertEqual(text, "## What's new\n\n### New\n\n- **New one.**\n\n### Improved\n\n"
                               "- Better one.\n\n### Fixed\n\n- Fix one.\n- Fix two.\n")
        self.assertNotIn('Old.', text)

    def test_every_checked_in_release_renders(self):
        tags = sorted(path.stem for path in notes.NOTES_DIR.glob('v*.md'))
        for tag in tags:
            self.assertIn("## What's new", notes.markdown(notes.build(tag), tag))


class RepositoryTests(unittest.TestCase):
    def test_checked_in_notes_all_parse(self):
        tags = sorted(path.stem for path in notes.NOTES_DIR.glob('v*.md'))
        self.assertIn('v0.1.0+5', tags)
        document = notes.build(tags[-1])
        self.assertEqual(len(document['items']), len(tags))


if __name__ == '__main__':
    unittest.main()
