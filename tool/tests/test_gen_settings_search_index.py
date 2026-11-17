import json
import pathlib
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tool'))
import gen_settings_search_index as gen  # noqa: E402


def write(path, text):
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding='utf8')


ENTRIES = [
    {'id': 'display-name', 'page': 'account', 'section': 'account', 'platforms': ['web', 'desktop'],
     'aliases': {'en': ['name'], 'zh-cn': ['昵称'], 'ja': ['名前']}},
    {'id': 'desktop-app', 'page': 'about', 'section': 'about', 'platforms': ['web'], 'aliases': {'en': ['download']}},
    {'id': 'hidden', 'page': 'account', 'section': 'account', 'platforms': ['web'], 'experimental': True,
     'aliases': {'en': ['x']}},
    {'id': 'sign-out', 'page': 'account', 'section': 'session', 'platforms': ['web'], 'aliases': {'en': ['log out']}},
]
COPY = '''export const SETTINGS_SEARCH_COPY = {
  "display-name": { nameId: "a.name", sectionId: "a.section" },
  "desktop-app": { nameId: "a.desktop" },
  hidden: { nameId: "a.hidden" },
  "sign-out": { nameId: "a.out", descriptionId: "a.outDesc", sectionId: "a.session" },
};
'''
EN = '''export const en = {
  "a.name": "Display name",
  "a.section": "Account",
  "a.desktop": "Desktop app",
  "a.hidden": "Hidden",
  "a.out": "Sign out",
  "a.outDesc":
    "Sign out of 'this' $browser.",
  "a.session": "Session",
};
'''


class SettingsSearchIndexTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.src = pathlib.Path(self.tmp.name)
        write(self.src / 'packages/shared/src/settingsSearch.v1.json',
              json.dumps({'contract': 'settings-search.v1', 'schemaVersion': 1, 'entries': ENTRIES}))
        write(self.src / 'packages/web/src/features/settings/search/settingsSearchCopy.ts', COPY)
        write(self.src / 'packages/web/src/i18n/messages/en.ts', EN)

    def tearDown(self):
        self.tmp.cleanup()

    def test_keeps_the_webs_order_and_skips_what_the_app_does_not_list(self):
        text, strings = gen.build(self.src)
        self.assertLess(text.index("id: 'display-name'"), text.index("id: 'sign-out'"))
        self.assertNotIn('desktop-app', text.replace('Rows the app does not list: desktop-app', ''))
        self.assertNotIn("id: 'hidden'", text)
        self.assertEqual(strings, {'Display name', 'Account', 'Sign out', "Sign out of 'this' $browser.", 'Session'})

    def test_keeps_english_and_chinese_words_only_and_escapes_dart(self):
        text, _ = gen.build(self.src)
        self.assertIn("aliasesZh: ['昵称']", text)
        self.assertNotIn('名前', text)
        self.assertIn(r"description: 'Sign out of \'this\' \$browser.'", text)
        self.assertNotIn('aliasesZh', text.split("id: 'sign-out'")[1])


if __name__ == '__main__':
    unittest.main()
