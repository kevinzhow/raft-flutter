"""Launch screen = stored theme canvas + chosen icon: Android/iOS resources agree.

Canvas colours are the first Flutter frame's scaffold background
(docs/theme-tokens `layer-canvas-muted`: the mobile home/sidebar body); a jump between launch screen and first
frame is a regression. See docs/custom-app-icons.md "Launch screen".
"""
import json
from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / 'apps/raft_flutter'
RES = APP / 'android/app/src/main/res'
MAIN = APP / 'android/app/src/main'
IOS = APP / 'ios/Runner'
A = '{http://schemas.android.com/apk/res/android}'
ICONS = ['yellow', 'blue', 'green', 'white', 'pink']
KINDS = ['brutal_light', 'elegant_light', 'dark', 'system_brutal', 'system_elegant']


def token_canvas(theme):
    data = json.loads((ROOT / f'docs/theme-tokens/{theme}.json').read_text())
    rgba = data['tokens']['layer-canvas-muted']['rgba']
    return '#%02X%02X%02X' % tuple(rgba[:3])


def values(path):
    out = {}
    for node in ET.parse(path).getroot():
        out[node.attrib['name']] = (node.tag, (node.text or '').strip())
    return out


def styles(path):
    out = {}
    for node in ET.parse(path).getroot().findall('style'):
        out[node.attrib['name']] = (node.attrib.get('parent'),
                                    {i.attrib['name']: (i.text or '').strip() for i in node.findall('item')})
    return out


class LaunchThemeResourcesTest(unittest.TestCase):
    def test_android_canvas_colours_equal_the_theme_tokens(self):
        light = values(RES / 'values/raft_launch_colors.xml')
        night = values(RES / 'values-night/raft_launch_colors.xml')
        brutal, elegant, dark = (token_canvas(t) for t in ['brutal-light', 'elegant-light', 'elegant-dark'])
        self.assertEqual(light['raft_canvas_brutal_light'][1].upper(), brutal)
        self.assertEqual(light['raft_canvas_elegant_light'][1].upper(), elegant)
        self.assertEqual(light['raft_canvas_elegant_dark'][1].upper(), dark)
        # `system` resolves per device day/night: light family canvas, Elegant dark at night.
        self.assertEqual(light['raft_canvas_system_brutal'][1], '@color/raft_canvas_brutal_light')
        self.assertEqual(light['raft_canvas_system_elegant'][1], '@color/raft_canvas_elegant_light')
        self.assertEqual(night['raft_canvas_system_brutal'][1], '@color/raft_canvas_elegant_dark')
        self.assertEqual(night['raft_canvas_system_elegant'][1], '@color/raft_canvas_elegant_dark')
        self.assertEqual(light['raft_launch_light_bars'][1], 'true')
        self.assertEqual(night['raft_launch_light_bars'][1], 'false')

    def test_ios_launch_background_equals_the_theme_tokens(self):
        catalog = json.loads((IOS / 'Assets.xcassets/LaunchBackground.colorset/Contents.json').read_text())

        def hex_of(entry):
            c = entry['color']['components']
            return '#%02X%02X%02X' % tuple(round(float(c[k]) * 255) for k in ('red', 'green', 'blue'))
        elegant = json.loads((IOS / 'Assets.xcassets/LaunchBackgroundElegant.colorset/Contents.json').read_text())
        for name, entries, light in (('brutal', catalog, 'brutal-light'), ('elegant', elegant, 'elegant-light')):
            by_style = {('dark' if e.get('appearances') else 'light'): hex_of(e) for e in entries['colors']}
            self.assertEqual(by_style['light'], token_canvas(light), name)
            self.assertEqual(by_style['dark'], token_canvas('elegant-dark'), name)

    def test_every_theme_and_icon_has_a_persistable_splash_theme(self):
        themes = styles(RES / 'values-v33/raft_splash_themes.xml')
        for kind in KINDS:
            base = themes[f'RaftSplash_{kind}'][1]
            self.assertTrue(base['android:windowSplashScreenBackground'].startswith('@color/raft_canvas_'))
            self.assertEqual(base['android:windowSplashScreenBehavior'], 'icon_preferred')
            for icon in ICONS:
                parent, items = themes[f'RaftSplash_{kind}_{icon}']
                self.assertEqual(parent, f'RaftSplash_{kind}')
                self.assertEqual(items['android:windowSplashScreenAnimatedIcon'], f'@mipmap/ic_launcher_{icon}')
        canvas = {k: themes[f'RaftSplash_{k}'][1]['android:windowSplashScreenBackground'] for k in KINDS}
        self.assertEqual(canvas['dark'], '@color/raft_canvas_elegant_dark')
        self.assertEqual(canvas['brutal_light'], '@color/raft_canvas_brutal_light')
        self.assertEqual(canvas['elegant_light'], '@color/raft_canvas_elegant_light')
        self.assertEqual(canvas['system_brutal'], '@color/raft_canvas_system_brutal')
        self.assertEqual(canvas['system_elegant'], '@color/raft_canvas_system_elegant')
        # Dark canvas needs light system-bar icons; light canvases dark ones.
        bars = {k: themes[f'RaftSplash_{k}'][1]['android:windowLightStatusBar'] for k in KINDS}
        self.assertEqual(bars['dark'], 'false')
        self.assertEqual((bars['brutal_light'], bars['elegant_light']), ('true', 'true'))

    def test_kotlin_kinds_channel_and_style_names_match_resources_and_dart(self):
        kotlin = (MAIN / 'kotlin/app/raft/raft_flutter/LaunchTheme.kt').read_text()
        self.assertEqual(re.findall(r'[A-Z_]+\("([a-z_]+)"\)', kotlin), KINDS)
        self.assertIn('"RaftSplash_${kind.id}_$icon"', kotlin)
        dart = (APP / 'lib/platform/launch_theme.dart').read_text()
        channel = re.search(r"MethodChannel\('([^']+)'\)", dart).group(1)
        self.assertIn(f'const val CHANNEL = "{channel}"', kotlin)
        # Both sides read the appearance under the same preference keys.
        prefs = (APP / 'lib/data/device_preferences.dart').read_text()
        main = (APP / 'lib/app_root.dart').read_text()
        for key in ('raft.mode', 'raft.light'):
            self.assertIn(f"'{key}'", prefs)
            self.assertIn(f'"flutter.{key}"', kotlin)
        self.assertIn('NativeLaunchTheme.instance.set(value)', main)
        self.assertIn('NativeLaunchTheme.instance.set(appearance)', main)
        keep = (RES / 'raw/keep.xml').read_text()
        self.assertIn('@style/RaftSplash_*', keep)
        self.assertIn('@color/raft_canvas_*', keep)

    def test_entry_themes_show_theme_canvas_and_the_alias_icon_not_the_icon_colour(self):
        icon_colors = {k.removeprefix('raft_icon_'): v[1] for k, v in values(RES / 'values/raft_icon_colors.xml').items()}
        for qualifier in ('values', 'values-v31', 'values-v33'):
            entry = styles(RES / qualifier / 'raft_icon_styles.xml')
            for icon in ICONS:
                parent, items = entry[f'IconLaunch{icon.title()}']
                self.assertEqual(items['android:windowBackground'], f'@drawable/launch_{icon}')
                self.assertEqual(items['windowSplashScreenBackground'], '@color/raft_canvas_system_brutal')
                self.assertEqual(items['postSplashScreenTheme'], '@style/NormalTheme')
                for name, value in items.items():
                    self.assertNotIn('raft_icon_', value, f'{qualifier} {icon} {name}: splash must not use the icon colour')
                if qualifier != 'values':
                    self.assertEqual(items['android:windowSplashScreenBackground'], '@color/raft_canvas_system_brutal')
                    self.assertEqual(items['android:windowSplashScreenAnimatedIcon'], f'@mipmap/ic_launcher_{icon}')
        for icon in ICONS:
            window = ET.parse(RES / f'drawable/launch_{icon}.xml').getroot()
            refs = [i.attrib.get(A + 'drawable') for i in window.findall('item')]
            self.assertEqual(refs, ['@color/raft_canvas_system_brutal', f'@drawable/launch_tile_{icon}'])
            tile = ET.parse(RES / f'drawable/launch_tile_{icon}.xml').getroot()
            self.assertEqual(tile.find('item/shape/solid').attrib[A + 'color'], f'@color/raft_icon_{icon}')
            self.assertEqual(icon_colors[icon][0], '#')
        plain = ET.parse(RES / 'drawable/launch_background.xml').getroot()
        self.assertEqual([i.attrib.get(A + 'drawable') for i in plain.findall('item')], ['@color/raft_canvas_system_brutal'])
        base = styles(RES / 'values/styles.xml')['RaftLaunchWindow'][1]
        self.assertEqual(base['android:windowBackground'], '@drawable/launch_background')
        self.assertEqual(base['android:colorBackground'], '@color/raft_canvas_system_brutal')

    def test_ios_launch_screen_is_the_adaptive_canvas_and_the_scene_draws_the_icon_tile(self):
        board = (IOS / 'Base.lproj/LaunchScreen.storyboard').read_text()
        self.assertIn('<color key="backgroundColor" name="LaunchBackground"/>', board)
        self.assertNotIn('LaunchMark', board, 'the static system LaunchScreen cannot know the chosen icon')
        self.assertNotIn('imageView', board)
        scene = (IOS / 'SceneDelegate.swift').read_text()
        self.assertIn('"flutter.raft.mode"', scene)
        self.assertIn('"LaunchBackground"', scene)
        self.assertIn('"LaunchBackgroundElegant"', scene)
        self.assertIn('"flutter.raft.light"', scene)
        self.assertIn('alternateIconName', scene)
        self.assertIn('controller.splashScreenView = startup', scene)
        self.assertNotIn('startupColor', scene, 'the full-screen icon colour caused the theme flash')


if __name__ == '__main__':
    unittest.main()
