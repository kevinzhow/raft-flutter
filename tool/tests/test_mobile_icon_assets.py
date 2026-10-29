"""Cross-platform asset checks: packaging compatibility and dark launch contrast."""
import json
from pathlib import Path
import struct
import unittest
import xml.etree.ElementTree as ET
import zlib

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'apps/raft_flutter/ios/Runner/Assets.xcassets'
RES = ROOT / 'apps/raft_flutter/android/app/src/main/res'


def png(path):
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    width, height, depth, kind = struct.unpack('>IIBB', data[16:26])
    assert depth == 8 and kind in (2, 6)
    chunks, position = [], 8
    while position < len(data):
        length = struct.unpack('>I', data[position:position+4])[0]
        if data[position+4:position+8] == b'IDAT':
            chunks.append(data[position+8:position+8+length])
        position += length+12
    return width, height, kind, zlib.decompress(b''.join(chunks))


def pixels(path):
    width, height, kind, raw = png(path)
    channels = 3 if kind == 2 else 4
    stride = width*channels
    previous = bytearray(stride)
    for y in range(height):
        offset = y*(stride+1)
        method, row = raw[offset], bytearray(raw[offset+1:offset+1+stride])
        for i in range(stride):
            a = row[i-channels] if i >= channels else 0
            b = previous[i]
            c = previous[i-channels] if i >= channels else 0
            if method == 1: value = a
            elif method == 2: value = b
            elif method == 3: value = (a+b)//2
            elif method == 4:
                p = a+b-c
                pa,pb,pc = abs(p-a),abs(p-b),abs(p-c)
                value = a if pa <= pb and pa <= pc else b if pb <= pc else c
            else:
                assert method == 0
                value = 0
            row[i] = (row[i]+value)&255
        for x in range(width):
            pixel = tuple(row[x*channels:(x+1)*channels])
            yield pixel+(255,) if channels == 3 else pixel
        previous = row


class MobileIconAssetsTest(unittest.TestCase):
    def test_icon_switches_cannot_disable_notification_or_external_intent_owner(self):
        a = '{http://schemas.android.com/apk/res/android}'
        app = ET.parse(RES.parent/'AndroidManifest.xml').getroot().find('application')
        main = next(x for x in app.findall('activity') if x.attrib[a+'name'] == '.MainActivity')
        categories = {x.attrib[a+'name'] for x in main.findall('intent-filter/category')}
        self.assertIn('android.intent.category.INFO', categories)
        self.assertNotIn('android.intent.category.LAUNCHER', categories)
        self.assertEqual(main.attrib[a+'launchMode'], 'singleTask')
        data = [x.attrib for x in main.findall('intent-filter/data')]
        self.assertTrue(any(x.get(a+'host') == 'oauth' for x in data))
        for prefix in ['/servers/', '/join/']:
            self.assertTrue(any(x.get(a+'host') == 'v1' and x.get(a+'pathPrefix') == prefix for x in data))
        actions = {x.attrib[a+'name'] for x in main.findall('intent-filter/action')}
        self.assertTrue({'android.intent.action.SEND', 'android.intent.action.SEND_MULTIPLE'} <= actions)
        aliases = app.findall('activity-alias')
        self.assertEqual(len(aliases), 5)
        self.assertEqual([x.attrib[a+'name'] for x in aliases if x.attrib[a+'enabled'] == 'true'], ['.IconYellow'])
        for alias in aliases:
            target = next(x for x in app.findall('activity') if x.attrib[a+'name'] == alias.attrib[a+'targetActivity'])
            self.assertNotEqual(target.attrib[a+'name'], '.MainActivity')
            self.assertIn('android.intent.category.LAUNCHER', {x.attrib[a+'name'] for x in alias.findall('intent-filter/category')})

    def test_ios_icons_are_opaque_correct_sizes_and_match_android_palette(self):
        colors = {n.attrib['name'].removeprefix('raft_icon_'): n.text
                  for n in ET.parse(RES/'values/raft_icon_colors.xml').getroot()}
        for color, hex_color in colors.items():
            folder = ASSETS/('AppIcon' + ('' if color == 'yellow' else color.title()) + '.appiconset')
            catalog = json.loads((folder/'Contents.json').read_text())
            rgb = tuple(bytes.fromhex(hex_color[1:]))
            for entry in catalog['images']:
                path = folder/entry['filename']
                w,h,kind,_ = png(path)
                expected = round(float(entry['size'].split('x')[0])*int(entry['scale'][0]))
                self.assertEqual((w,h),(expected,expected),str(path))
                self.assertEqual(kind,2,'iOS app icons must have no alpha channel')
                self.assertEqual(next(pixels(path))[:3],rgb)
            for density in ['mdpi','hdpi','xhdpi','xxhdpi','xxxhdpi']:
                self.assertEqual(next(pixels(RES/f'mipmap-{density}/ic_launcher_{color}.png'))[:3],rgb)

    def test_launch_mark_is_one_light_image_for_the_native_icon_tile(self):
        folder = ASSETS/'LaunchMark.imageset'
        catalog = json.loads((folder/'Contents.json').read_text())
        self.assertEqual([x['filename'] for x in catalog['images']], ['mark-light.png'])
        self.assertFalse((folder/'mark-dark.png').exists())
        colors = set(pixels(folder/'mark-light.png'))
        self.assertIn((0, 0, 0, 255), colors)
        self.assertIn((255, 250, 239, 255), colors)
