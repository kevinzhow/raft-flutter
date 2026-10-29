"""Android entrypoints must share one UI session/credential owner."""
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
ANDROID = '{http://schemas.android.com/apk/res/android}'


class AndroidEntrypointsTest(unittest.TestCase):
    def test_external_entrypoints_reuse_launcher_session_across_tasks(self):
        manifest = ET.parse(ROOT / 'apps/raft_flutter/android/app/src/main/AndroidManifest.xml')
        application = manifest.getroot().find('application')
        activity = next(a for a in application.findall('activity')
                        if a.get(ANDROID + 'name') == '.MainActivity')
        # singleTop creates another engine when the sender is in another task;
        # that engine cannot acquire NativeSessionOwner from the first UI.
        self.assertEqual(activity.get(ANDROID + 'launchMode'), 'singleTask')
        affinity = activity.get(ANDROID + 'taskAffinity',
                                application.get(ANDROID + 'taskAffinity'))
        self.assertNotEqual(affinity, '', 'Empty affinity prevents task reuse')
        actions = {action.get(ANDROID + 'name')
                   for action in activity.findall('intent-filter/action')}
        self.assertTrue({'android.intent.action.MAIN', 'android.intent.action.VIEW',
                         'android.intent.action.SEND', 'android.intent.action.SEND_MULTIPLE'} <= actions)
        categories = {category.get(ANDROID + 'name')
                      for category in activity.findall('intent-filter/category')}
        # Notifications use the permanent INFO entry, independent of whichever
        # launcher alias is currently enabled. Icon switching must not disable
        # the Activity that owns shares, links and the Flutter session.
        self.assertIn('android.intent.category.INFO', categories)
        self.assertNotIn('android.intent.category.LAUNCHER', categories)
        self.assertIn('android.intent.category.BROWSABLE', categories)
        aliases = application.findall('activity-alias')
        self.assertEqual(len(aliases), 5)
        for alias in aliases:
            self.assertIn('android.intent.category.LAUNCHER', {
                c.get(ANDROID + 'name') for c in alias.findall('intent-filter/category')})
            target = next(a for a in application.findall('activity')
                          if a.get(ANDROID + 'name') == alias.get(ANDROID + 'targetActivity'))
            self.assertNotEqual(target.get(ANDROID + 'name'), '.MainActivity')
            self.assertEqual(target.get(ANDROID + 'exported'), 'false')
        routing = (ROOT / 'apps/raft_flutter/android/app/src/main/kotlin/app/raft/raft_flutter/AppIconStartup.kt').read_text()
        self.assertIn('Intent(intent)', routing, 'Forward URI, grants and notification extras')
        self.assertIn('MainActivity::class.java', routing)
        self.assertIn('Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP', routing)
        # Routing of external links belongs to our authenticated coordinator.
        metadata = {m.get(ANDROID + 'name'): m.get(ANDROID + 'value')
                    for m in activity.findall('meta-data')}
        self.assertEqual(metadata['flutter_deeplinking_enabled'], 'false')


if __name__ == '__main__':
    unittest.main()
