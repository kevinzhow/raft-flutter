"""Host test for tool/controller_clusters.py on a tiny fixture Dart class."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('controller_clusters', ROOT / 'tool/controller_clusters.py')
cc = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cc)

FIXTURE = textwrap.dedent('''
    import 'dart:async';

    class Fixture extends ChangeNotifier {
      Fixture(this.client) : _bootAt = DateTime.now();
      final Client client;
      final DateTime _bootAt;
      bool _disposed = false;
      // items: only the item members use these; mentioning tags here is a comment.
      List<String> items = [], pinned = [];
      int _itemSeq = 0;
      Map<String, int> tags = {};
      final Set<String> _tagCache = {};
      late final Helper helper = Helper(owner: this, size: () => items.length);
      (int, String)? _record;
      static const known = {'item:added', 'tag:added'};

      List<String> get visibleItems => items.where((i) => !pinned.contains(i)).toList();
      int get tagCount => tags.length;
      set seq(int value) => _itemSeq = value;

      void addItem(String name) {
        if (_disposed) return;
        items = [...items, name];
        _itemSeq++;
        notifyListeners();
      }

      void clearItems() {
        if (_disposed) return;
        items.clear();
        pinned = [];
        _itemSeq = 0;
      }

      String describeItems() {
        final items = <String>['shadow'];
        for (final tags in [1, 2]) {
          items.add('$tags');
        }
        return 'n=${visibleItems.length} seq=$_itemSeq ${items.length}';
      }

      void addTag(String tag, {int weight = 1}) {
        if (_disposed) return;
        tags[tag] = weight;
        _tagCache.add(tag);
        refreshTags();
      }

      void refreshTags() {
        if (_disposed) return;
        _tagCache.removeWhere((t) => !tags.containsKey(t));
        client.get('/tags');
      }

      void _event(Event event) {
        if (_disposed) return;
        if (event.name == 'connected') {
          refreshTags();
        }
        if (event.name == 'item:added' && event.payload is Map) {
          addItem(event.payload['name']);
        }
        switch (event.name) {
          case 'tag:added':
          case 'tag:updated':
            addTag(event.payload['tag']);
          case 'item:cleared':
            clearItems();
        }
      }

      void dispose() {
        _disposed = true;
        super.dispose();
      }
    }

    extension FixtureExtras on Fixture {
      int itemsPerTag() => items.length ~/ (tagCount + 1);
    }
''')

WIDGET = textwrap.dedent('''
    class Panel {
      final Fixture w;
      void tap() {
        w.addItem('x');
        w.addItem('y');
        w.refreshTags();
        print(w.items.length);
      }
    }
''')


class ControllerClustersTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.lib = Path(self.tmp.name) / 'lib'
        self.lib.mkdir()
        (self.lib / 'fixture.dart').write_text(FIXTURE)
        (self.lib / 'panel.dart').write_text(WIDGET)
        self.root = self.lib / 'fixture.dart'

    def report(self, **kw):
        out = io.StringIO()
        argv = ['--class', 'Fixture', '--root', str(self.root), '--lib', str(self.lib),
                '--tests', str(Path(self.tmp.name) / 'none'), '--hub-ratio', '1.0', '--hub', '_disposed', '--hub', 'client', '--json']
        for k, v in kw.items():
            argv += [f'--{k}', str(v)]
        with contextlib.redirect_stdout(out):
            self.assertEqual(cc.main(argv), 0)
        return json.loads(out.getvalue())

    def test_blank_keeps_interpolation_and_drops_comments(self):
        code, strings = cc.blank("var a = 'x $y ${z.w} // no'; // tail $q\n/* items */ var b = 1;")
        self.assertIn('y', code)
        self.assertIn('z.w', code)
        self.assertNotIn('tail', code)
        self.assertNotIn('items', code)
        self.assertNotIn('no', code.replace('var', ''))
        self.assertEqual(list(strings.values()), ['x $ ${} // no'])

    def test_fields_members_and_multi_declarators(self):
        rep = self.report()
        table = rep['field_table']
        for name in ('items', 'pinned', '_itemSeq', 'tags', '_tagCache', 'helper', '_record', 'client', '_disposed'):
            self.assertIn(name, table)
        self.assertNotIn('known', table)  # static
        self.assertEqual(rep['totals']['static_fields'], 1)
        members = rep['member_table']
        for name in ('addItem', 'clearItems', 'visibleItems', 'tagCount', 'seq', 'itemsPerTag', '_event', 'dispose'):
            self.assertIn(name, members)
        self.assertEqual(members['visibleItems']['kind'], 'getter')
        self.assertEqual(members['seq']['kind'], 'setter')

    def test_reads_writes_and_getter_transparency(self):
        members = self.report()['member_table']
        self.assertEqual(members['addItem']['writes'], ['_itemSeq', 'items'])
        self.assertIn('_disposed', members['addItem']['reads'])
        self.assertEqual(members['clearItems']['writes'], ['_itemSeq', 'items', 'pinned'])  # clear() mutates
        # describeItems reads through the visibleItems getter and interpolation, not its local `items`
        self.assertEqual(members['describeItems']['reads'], ['_itemSeq', 'items', 'pinned'])
        self.assertEqual(members['describeItems']['writes'], [])
        self.assertEqual(members['describeItems']['uses'], ['visibleItems'])
        # the extension member is part of the class
        self.assertEqual(members['itemsPerTag']['reads'], ['items', 'tags'])

    def test_shadowing_local_hides_field(self):
        src = cc.Source(Path('x.dart'), "class A { int items = 0; void f() { final items = []; items.add(1); } void g() { items++; } }")
        lo, hi = cc.find_class_body(src, 'A')
        ms = [m for m in cc.split_members(src, lo, hi, 'A') if m.kind != 'field']
        fields = {'items'}
        for m in ms:
            cc.analyze_member(src, m, fields, {m.name for m in ms}, 'A')
        by = {m.name: m for m in ms}
        self.assertFalse(by['f'].reads or by['f'].writes)
        self.assertEqual(dict(by['g'].writes), {'items': 1})

    def test_clusters_split_items_from_tags(self):
        rep = self.report(resolution=1.0)
        homes = {name: info['cluster'] for name, info in rep['field_table'].items()}
        self.assertEqual(homes['items'], homes['_itemSeq'])
        self.assertEqual(homes['items'], homes['pinned'])
        self.assertEqual(homes['tags'], homes['_tagCache'])
        self.assertNotEqual(homes['items'], homes['tags'])
        self.assertTrue(rep['field_table']['_disposed']['hub'])
        members = rep['member_table']
        self.assertEqual(members['addItem']['cluster'], homes['items'])
        self.assertEqual(members['addTag']['cluster'], homes['tags'])
        self.assertEqual(members['refreshTags']['cluster'], homes['tags'])

    def test_events_are_attributed_to_clusters(self):
        rep = self.report(resolution=1.0)
        events = rep['events']
        self.assertEqual(sorted(events), ['connected', 'item:added', 'item:cleared', 'tag:added', 'tag:updated'])
        homes = {n: i['cluster'] for n, i in rep['field_table'].items()}
        self.assertEqual(events['connected']['primary'], homes['tags'])
        self.assertEqual(events['item:added']['primary'], homes['items'])
        self.assertEqual(events['item:cleared']['primary'], homes['items'])
        self.assertEqual(events['tag:added']['primary'], homes['tags'])
        self.assertEqual(events['tag:updated']['handlers'], ['_event'])

    def test_external_callers_and_coupling(self):
        rep = self.report(resolution=1.0)
        by = {c['id']: c for c in rep['clusters']}
        homes = {n: i['cluster'] for n, i in rep['field_table'].items()}
        items = by[homes['items']]
        tags = by[homes['tags']]
        self.assertEqual(items['external']['refs'], 3)  # addItem x2 + items
        self.assertEqual(tags['external']['refs'], 1)   # refreshTags
        self.assertEqual(rep['member_table']['addItem']['external_files'], ['panel.dart'])
        self.assertTrue(any(k['cluster'] == tags['id'] and k['calls_in'] + k['calls_out'] for k in items['coupling']))

    def test_markdown_output(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            cc.main(['--class', 'Fixture', '--root', str(self.root), '--lib', str(self.lib),
                     '--tests', str(Path(self.tmp.name) / 'none'), '--hub-ratio', '1.0', '--hub', '_disposed', '--resolution', '1.0'])
        text = out.getvalue()
        self.assertIn('# Fixture clusters', text)
        self.assertIn('| # | Fields | Members |', text)
        self.assertIn('`item:added`', text)

    def test_louvain_separates_two_cliques(self):
        weights = {('a', 'b'): 1, ('a', 'c'): 1, ('b', 'c'): 1, ('x', 'y'): 1, ('x', 'z'): 1, ('y', 'z'): 1, ('c', 'x'): 0.1}
        comm = cc.louvain(list('abcxyz'), weights)
        self.assertEqual(comm['a'], comm['b'])
        self.assertEqual(comm['x'], comm['z'])
        self.assertNotEqual(comm['a'], comm['x'])


if __name__ == '__main__':
    unittest.main()
