"""Behaviour-parity tooling (tool/behavior-parity): parsing, TS symbol extraction, status, drift."""
import contextlib
import io
import json
import pathlib
import sys
import tempfile
import textwrap
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tool'))
import behavior_parity as bp  # noqa: E402


def src(text: str) -> bp.Source:
    return bp.Source(textwrap.dedent(text).lstrip("\n"))


def norm(text: str, symbol: str) -> str:
    res = bp.resolve(src(text), symbol)
    assert res.ok, res.note
    return res.normalized


class MaskAndNormalizeTest(unittest.TestCase):
    def test_comments_and_strings_do_not_confuse_brackets(self):
        s = src('''
            function f() {
              // } stray brace in a line comment
              /* } and { in a block comment */
              const a = "}{", b = '}', c = `${ g({ x: '}' }) } {`;
              return /[}{]/.test(a);
            }
            const after = 1;
        ''')
        res = bp.resolve(s, 'f')
        self.assertTrue(res.ok)
        self.assertEqual((res.first_line, res.last_line), (1, 6))
        self.assertTrue(bp.resolve(s, 'after').ok)

    def test_normalization_ignores_formatting_but_not_logic(self):
        a = 'function f(a, b) {\n  // note\n  return a + b; // sum\n}\n'
        b = "function f(a,\n   b,\n) {\n\n  return   a+b;\n}\n"
        c = 'function f(a, b) {\n  return a - b;\n}\n'
        self.assertEqual(norm(a, 'f'), norm(b, 'f'))
        self.assertNotEqual(norm(a, 'f'), norm(c, 'f'))

    def test_quote_style_and_trailing_commas_are_formatting(self):
        a = "const x = { a: 'one', b: [1, 2,], };\n"
        b = 'const x = {\n  a: "one",\n  b: [1, 2],\n};\n'
        self.assertEqual(norm(a, 'x'), norm(b, 'x'))
        self.assertNotEqual(norm(a, 'x'), norm(a.replace("'one'", "'two'"), 'x'))

    def test_apostrophe_in_jsx_text_does_not_swallow_the_rest(self):
        s = src('''
            function Comp() {
              return <p>Don't {x} and it's {y}</p>;
            }
            const next = 1;
        ''')
        res = bp.resolve(s, 'Comp')
        self.assertEqual((res.first_line, res.last_line), (1, 3))
        self.assertTrue(bp.resolve(s, 'next').ok)

    def test_regex_literal_vs_division(self):
        s = src('''
            const half = (a) => a / 2 / 3;
            const re = /[(]\\/{/g;
            const tail = 1;
        ''')
        self.assertEqual(bp.resolve(s, 'half').last_line, 1)
        self.assertEqual(bp.resolve(s, 're').last_line, 2)
        self.assertTrue(bp.resolve(s, 'tail').ok)


class SymbolExtractionTest(unittest.TestCase):
    STORE = '''
        interface Store { markRead: (id: string) => Promise<void>; inner: { go(): void } }
        type Handlers = { onTap: () => void };
        export function plainFn<T,>(a: T, b = "}{"): Promise<{ a: string }> {
          return Promise.resolve({ a: `${a}}` });
        }
        const arrow = async (x: number): Promise<number> => x + 1;
        const noSemicolon = 5
        const next = 6
        export const useStore = create<Store>()((set, get) => ({
          markRead: async (id) => {
            set({ n: get().n + id });
          },
          loadStuff(cursor?: string): Promise<void> {
            return fetch(`/a/${cursor}`);
          },
          flag: true,
          get derived() { return 1; },
        }));
        class Klass {
          private count = 0;
          static make(n: number) { return new Klass(); }
          async run(): Promise<void> { await 1; }
          handler = () => { this.count++; };
        }
        function Component() {
          const showMarker = joined && !muted
            && flags[id];
          const onGo = useCallback(async () => { await 1; }, []);
          return <div>{showMarker ? <b>x</b> : null}</div>;
        }
        function wrapper() {
          function plainFn() { return "inner shadow"; }
          return 1;
        }
    '''

    def lines(self, symbol):
        res = bp.resolve(src(self.STORE), symbol)
        self.assertTrue(res.ok, symbol)
        return (res.first_line, res.last_line)

    def test_declaration_forms(self):
        self.assertEqual(self.lines('arrow'), (6, 6))
        self.assertEqual(self.lines('noSemicolon'), (7, 7))
        self.assertEqual(self.lines('next'), (8, 8))
        self.assertEqual(self.lines('Klass'), (19, 24))
        self.assertEqual(self.lines('showMarker'), (26, 27))
        self.assertEqual(self.lines('onGo'), (28, 28))

    def test_shallowest_declaration_wins_over_shadow(self):
        self.assertEqual(self.lines('plainFn'), (3, 5))

    def test_store_actions_methods_properties_and_class_members(self):
        self.assertEqual(self.lines('markRead'), (10, 12))
        self.assertEqual(self.lines('loadStuff'), (13, 15))
        self.assertEqual(self.lines('flag'), (16, 16))
        self.assertEqual(self.lines('derived'), (17, 17))
        self.assertEqual(self.lines('make'), (21, 21))
        self.assertEqual(self.lines('run'), (22, 22))
        self.assertEqual(self.lines('handler'), (23, 23))

    def test_type_only_members_are_not_declarations(self):
        s = src(self.STORE)
        self.assertFalse(bp.resolve(s, 'onTap').ok)
        self.assertFalse(bp.resolve(s, 'inner').ok)
        self.assertFalse(bp.resolve(s, 'doesNotExist').ok)

    def test_call_statement_fallback_for_registrations(self):
        s = src('''
            registerThing((read) => {
              apply(read);
            });
            const x = 1;
        ''')
        res = bp.resolve(s, 'registerThing')
        self.assertTrue(res.ok)
        self.assertEqual((res.first_line, res.last_line), (1, 3))

    def test_effect_anchor(self):
        s = src('''
            function C() {
              useEffect(() => { countRef.current = 1; }, []);
              useEffect(() => { other(); }, []);
            }
        ''')
        res = bp.resolve(s, 'effect:countRef')
        self.assertTrue(res.ok)
        self.assertEqual(len(res.spans), 1)
        self.assertEqual(res.first_line, 2)


class EventAnchorTest(unittest.TestCase):
    CODE = '''
        type Binding = { event: "a:b" | "c:d"; handler: () => void };
        const onAB = (p) => { run(p); };
        const bindings = [
          { event: "a:b", handler: onAB },
          { event: "c:d", handler: (p) => { other(p); } },
          { event: "log:only", detail: 1 },
        ];
        socket.on("x:y", handleXY);
        socket.on("x:z", (d) => { inline(d); });
        const handleXY = function (d) { go(d); };
        function dispatch(t) {
          switch (t) { case "k:one": one(); break; case "k:two": two(); break; }
        }
    '''

    def test_binding_object_and_named_handler(self):
        res = bp.resolve(src(self.CODE), 'event:a:b')
        self.assertTrue(res.ok)
        self.assertEqual(len(res.spans), 2)
        self.assertIn('constonAB', res.normalized.replace(' ', ''))

    def test_inline_handler_and_type_literal_ignored(self):
        res = bp.resolve(src(self.CODE), 'event:c:d')
        self.assertEqual(len(res.spans), 1)
        self.assertIn('other(p)', res.normalized)

    def test_on_registration_with_identifier_or_inline_function(self):
        self.assertIn('go(d)', norm(self.CODE, 'event:x:y'))
        self.assertIn('inline(d)', norm(self.CODE, 'event:x:z'))

    def test_case_clause(self):
        text = norm(self.CODE, 'event:k:one')
        self.assertIn('one()', text)
        self.assertNotIn('two()', text)

    def test_object_without_handler_is_not_a_registration(self):
        res = bp.resolve(src(self.CODE), 'event:log:only')
        self.assertFalse(res.ok)

    def test_unknown_event_is_unresolved(self):
        self.assertFalse(bp.resolve(src(self.CODE), 'event:no:such').ok)


ROW = '| {id} | {anchor} | does a thing | ref | flutter | {audit} | hint | {notes} |'
HEADER = textwrap.dedent('''\
    # Title

    <!-- behavior-parity
    domain: demo
    id-prefix: BP-DEMO
    web: v1.0.0 abcdef1234567890
    scope: store/a.ts, store/b.ts
    events: demo:*, connect
    ignore: store/a.ts#skipMe, event:demo:ignored
    -->

    | ID | Web anchor | Web behaviour | Web ref | Flutter ref | Audit | Test hint | Notes |
    |---|---|---|---|---|---|---|---|
''')


def write_domain(root: pathlib.Path, rows, name='demo'):
    d = root / 'docs/behavior-parity'
    d.mkdir(parents=True, exist_ok=True)
    body = HEADER + '\n'.join(ROW.format(**r) for r in rows) + '\n'
    p = d / f'{name}.md'
    p.write_text(body)
    return p


class DomainParsingTest(unittest.TestCase):
    def test_parse_rows_header_and_validation_errors(self):
        with tempfile.TemporaryDirectory() as t:
            root = pathlib.Path(t)
            p = write_domain(root, [
                dict(id='BP-DEMO-001', anchor='store/a.ts#foo', audit='missing', notes=''),
                dict(id='BP-DEMO-002', anchor='n/a (no Web code)', audit='n-a', notes='owner 2026-10-12'),
                dict(id='BP-DEMO-001', anchor='store/a.ts#bar', audit='aligned', notes=''),
                dict(id='BP-OTHER-003', anchor='store/a.ts#baz', audit='bogus', notes=''),
                dict(id='BP-DEMO-004', anchor='store/a.ts', audit='missing', notes=''),
            ])
            dom = bp.parse_domain(p)
            self.assertEqual(dom.header['id-prefix'], 'BP-DEMO')
            self.assertEqual(dom.scope, ['store/a.ts', 'store/b.ts'])
            self.assertEqual(dom.events, ['demo:*', 'connect'])
            self.assertEqual(len(dom.rows), 5)
            self.assertFalse(dom.rows[1].has_anchor)
            errs = '\n'.join(dom.errors)
            self.assertIn('duplicate ID BP-DEMO-001', errs)
            self.assertIn('does not start with id-prefix', errs)
            self.assertIn("Audit 'bogus'", errs)
            self.assertIn('is not <path>#<symbol>', errs)
            self.assertEqual(len(dom.warnings), 0)  # BP-DEMO-002 is n-a with an owner decision and date

    def test_declared_status_without_owner_decision_warns(self):
        with tempfile.TemporaryDirectory() as t:
            p = write_domain(pathlib.Path(t), [
                dict(id='BP-DEMO-001', anchor='store/a.ts#foo', audit='intended-difference', notes='mobile has no tabs'),
                dict(id='BP-DEMO-002', anchor='store/a.ts#bar', audit='n-a', notes='Kevin decided 2026-10-12'),
            ])
            dom = bp.parse_domain(p)
            self.assertEqual(dom.errors, [])
            self.assertEqual(len(dom.warnings), 1)
            self.assertIn('BP-DEMO-001', dom.warnings[0])

    def test_missing_header_and_bad_cell_count(self):
        with tempfile.TemporaryDirectory() as t:
            p = pathlib.Path(t) / 'x.md'
            p.write_text('| BP-X-001 | a | b |\n')
            dom = bp.parse_domain(p)
            self.assertTrue(any('no <!-- behavior-parity' in e for e in dom.errors))
            self.assertTrue(any('expected 8 cells' in e for e in dom.errors))


class StatusComputationTest(unittest.TestCase):
    DART = '''
        void main() {
          testWidgets('[BP-DEMO-001] clears the badge', (tester) async {});
          test(
            "[BP-DEMO-002] retries the read",
            () {},
            skip: 'flaky on CI',
          );
          test('[BP-DEMO-003] stays [BP-DEMO-004] shared', () {}, skip: false);
          // test('[BP-DEMO-005] commented out', () {});
          group('[BP-DEMO-006] group only', () { test('plain', () {}); });
          expect(find.text('BP-DEMO-007'), findsOneWidget);
        }
    '''

    def test_scan_test_file(self):
        found = {tid: skipped for tid, _, skipped in bp.scan_test_file(textwrap.dedent(self.DART))}
        self.assertEqual(found['BP-DEMO-001'], False)
        self.assertEqual(found['BP-DEMO-002'], True)
        self.assertEqual(found['BP-DEMO-003'], False)
        self.assertEqual(found['BP-DEMO-004'], False)
        for absent in ('BP-DEMO-005', 'BP-DEMO-006', 'BP-DEMO-007'):
            self.assertNotIn(absent, found)

    def make_row(self, rid, audit, notes=''):
        return bp.Row(rid, 'store/a.ts#foo', 'b', 'r', 'f', audit, 'h', notes, 1)

    def test_compute_status(self):
        tests = {'BP-DEMO-001': [('t.dart', 3, False)], 'BP-DEMO-002': [('t.dart', 5, True)]}
        self.assertEqual(bp.compute_status(self.make_row('BP-DEMO-001', 'missing'), tests)[0], 'aligned')
        self.assertEqual(bp.compute_status(self.make_row('BP-DEMO-002', 'missing'), tests), ('open', 'only skipped tests'))
        self.assertEqual(bp.compute_status(self.make_row('BP-DEMO-003', 'differs'), tests), ('open', 'differs'))
        self.assertEqual(bp.compute_status(self.make_row('BP-DEMO-003', 'aligned'), tests), ('open', 'aligned'))
        self.assertEqual(bp.compute_status(self.make_row('BP-DEMO-004', 'intended-difference'), tests)[0], 'intended-difference')
        self.assertEqual(bp.compute_status(self.make_row('BP-DEMO-001', 'n-a'), tests)[0], 'n-a')

    def test_collect_test_ids_reads_app_and_package_tests(self):
        with tempfile.TemporaryDirectory() as t:
            root = pathlib.Path(t)
            (root / 'apps/raft_flutter/test').mkdir(parents=True)
            (root / 'packages/raft_sync/test').mkdir(parents=True)
            (root / 'apps/raft_flutter/test/a_test.dart').write_text("void main(){ test('[BP-DEMO-001] x', () {}); }")
            (root / 'packages/raft_sync/test/b_test.dart').write_text("void main(){ test('[BP-DEMO-002] y', () {}); }")
            ids = bp.collect_test_ids(root)
            self.assertEqual(sorted(ids), ['BP-DEMO-001', 'BP-DEMO-002'])


WEB_V1 = {
    'store/a.ts': '''
        export const useA = create<S>()((set, get) => ({
          markRead: async (id) => {
            set({ read: id });
          },
          skipMe: () => 1,
          untouched: () => 2,
        }));
        export function stays() { return 1; }
        export function willMove() { return "payload"; }
        export function willChange() { return 1; }
        export function noiseOnly(a, b) { return a + b; }
        export function ambiguousMove() { return 7; }
        export function gone() { return 3; }
    ''',
    'store/bridge.ts': '''
        const handler = (d) => { apply(d); };
        export const bindings = [
          { event: "demo:one", handler },
          { event: "demo:two", handler: (d) => { two(d); } },
        ];
        socket.on("connect", () => { reconnect(); });
        socket.on("demo:ignored", () => {});
        socket.on("demo:new", () => {});
        socket.on("other:thing", () => {});
    ''',
}


def make_web(root: pathlib.Path, files: dict):
    base = root / 'packages/web/src'
    for rel, text in files.items():
        p = base / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(textwrap.dedent(text))
    return bp.WebTree(root)


class DriftTest(unittest.TestCase):
    ROWS = [
        dict(id='BP-DEMO-001', anchor='store/a.ts#markRead', audit='differs', notes=''),
        dict(id='BP-DEMO-002', anchor='store/a.ts#stays', audit='aligned', notes=''),
        dict(id='BP-DEMO-003', anchor='store/a.ts#willMove', audit='missing', notes=''),
        dict(id='BP-DEMO-004', anchor='store/a.ts#willChange', audit='missing', notes=''),
        dict(id='BP-DEMO-005', anchor='store/a.ts#noiseOnly', audit='missing', notes=''),
        dict(id='BP-DEMO-006', anchor='store/a.ts#ambiguousMove', audit='missing', notes=''),
        dict(id='BP-DEMO-007', anchor='store/a.ts#gone', audit='missing', notes=''),
        dict(id='BP-DEMO-008', anchor='store/bridge.ts#event:demo:one', audit='aligned', notes=''),
        dict(id='BP-DEMO-009', anchor='store/bridge.ts#event:demo:two', audit='aligned', notes=''),
        dict(id='BP-DEMO-010', anchor='n/a (no Web code)', audit='n-a', notes='owner decision 2026-10-12'),
    ]

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)
        self.dom = bp.parse_domain(write_domain(self.root, self.ROWS))
        self.v1 = make_web(self.root / 'web1', WEB_V1)
        self.entries, bad = bp.compute_fingerprints(self.dom, self.v1)
        self.assertEqual(bad, [])

    def classify(self, files):
        web = make_web(self.root / 'web2', files)
        return {r.id: bp.check_row(r, self.entries.get(r.id), web) for r in self.dom.rows}

    def test_fingerprints_cover_anchored_rows_only(self):
        self.assertEqual(len(self.entries), 9)
        self.assertNotIn('BP-DEMO-010', self.entries)

    def test_nothing_changed(self):
        res = self.classify(WEB_V1)
        self.assertEqual({v.state for k, v in res.items() if k != 'BP-DEMO-010'}, {'unchanged'})
        self.assertEqual(res['BP-DEMO-010'].state, '-')

    def test_classification(self):
        a = WEB_V1['store/a.ts']
        a2 = (a
              .replace('return "payload"; }', 'return "other"; }')  # MOVED + body changed (checked below)
              .replace('export function willChange() { return 1; }', 'export function willChange() { return 2; }')
              .replace('export function noiseOnly(a, b) { return a + b; }',
                       'export function noiseOnly(a,\n   b) {\n  // reviewed\n  return a+b;\n}')
              .replace('export function ambiguousMove() { return 7; }\n', '')
              .replace('export function gone() { return 3; }\n', ''))
        # willMove: keep body identical but move file
        a2 = a2.replace('export function willMove() { return "other"; }\n', '')
        files = {
            'store/a.ts': a2,
            'store/moved.ts': 'export function willMove() { return "payload"; }\n',
            'store/amb1.ts': 'export function ambiguousMove() { return 7; }\n',
            'store/amb2.ts': 'export function ambiguousMove() { return 8; }\n',
            'store/bridge.ts': WEB_V1['store/bridge.ts'].replace('two(d)', 'two(d, 1)'),
        }
        res = self.classify(files)
        self.assertEqual(res['BP-DEMO-001'].state, 'unchanged')
        self.assertEqual(res['BP-DEMO-003'].state, 'MOVED')
        self.assertEqual(res['BP-DEMO-003'].new_path, 'store/moved.ts')
        self.assertFalse(res['BP-DEMO-003'].changed)
        self.assertEqual(res['BP-DEMO-004'].state, 'CHANGED')
        self.assertEqual(res['BP-DEMO-005'].state, 'unchanged', 'comment/whitespace-only edit must not drift')
        self.assertEqual(res['BP-DEMO-006'].state, 'REMOVED', 'two other homes are not a unique move')
        self.assertIn('2 other files', res['BP-DEMO-006'].detail)
        self.assertEqual(res['BP-DEMO-007'].state, 'REMOVED')
        self.assertEqual(res['BP-DEMO-008'].state, 'unchanged')
        self.assertEqual(res['BP-DEMO-009'].state, 'CHANGED')

    def test_moved_with_changed_body_is_flagged(self):
        files = dict(WEB_V1)
        files['store/a.ts'] = WEB_V1['store/a.ts'].replace('export function willMove() { return "payload"; }\n', '')
        files['store/moved.ts'] = 'export function willMove() { return "payload2"; }\n'
        res = self.classify(files)
        self.assertEqual((res['BP-DEMO-003'].state, res['BP-DEMO-003'].changed), ('MOVED', True))

    def test_missing_file_and_missing_baseline(self):
        res = self.classify({'store/other.ts': 'export const z = 1;\n'})
        self.assertEqual(res['BP-DEMO-001'].state, 'REMOVED')
        row = self.dom.rows[0]
        self.assertEqual(bp.check_row(row, None, self.v1).state, 'NEW')
        stale = dict(self.entries[row.id], anchor='store/a.ts#other')
        self.assertEqual(bp.check_row(row, stale, self.v1).state, 'STALE')

    def test_rename_candidate_by_similarity(self):
        body = ('export function computeTotals(items) {\n'
                '  let total = 0;\n  for (const item of items) {\n    if (item.done && !item.hidden) total += item.count * 2;\n  }\n'
                '  return total > 100 ? 100 : total;\n}\n')
        web1 = make_web(self.root / 'r1', {'store/x.ts': body})
        dom = bp.parse_domain(write_domain(self.root / 'r', [dict(id='BP-DEMO-001', anchor='store/x.ts#computeTotals', audit='missing', notes='')]))
        entries, _ = bp.compute_fingerprints(dom, web1)
        web2 = make_web(self.root / 'r2', {
            'store/x.ts': body.replace('computeTotals', 'sumVisibleItems') + 'export const unrelated = () => { return 1 + 1; };\n',
            'store/y.ts': 'export function other(a) {\n  const names = a.map((n) => n.toUpperCase());\n  return names.join(",").slice(0, 40);\n}\n',
        })
        row = dom.rows[0]
        self.assertEqual(bp.check_row(row, entries[row.id], web2).state, 'REMOVED')
        cand, sim = bp.find_rename_candidate(row, entries[row.id], web2, {})
        self.assertEqual(cand, 'store/x.ts#sumVisibleItems')
        self.assertGreaterEqual(sim, bp.RENAME_MIN_SIMILARITY)


class UncoveredTest(unittest.TestCase):
    def test_events_and_store_actions(self):
        with tempfile.TemporaryDirectory() as t:
            root = pathlib.Path(t)
            rows = [
                dict(id='BP-DEMO-001', anchor='store/bridge.ts#event:demo:one', audit='aligned', notes=''),
                dict(id='BP-DEMO-002', anchor='store/a.ts#stays', audit='aligned', notes=''),
            ]
            dom = bp.parse_domain(write_domain(root, rows))
            web = make_web(root / 'web', WEB_V1)
            unc = bp.uncovered(dom, web)
            events = {e['event'] for e in unc['events']}
            # derived from code (binding objects with a handler and .on calls); filtered by the header globs
            self.assertEqual(events, {'demo:two', 'demo:new', 'connect'})
            self.assertNotIn('demo:one', events)    # anchored
            self.assertNotIn('demo:ignored', events)  # ignore: list
            self.assertNotIn('other:thing', events)   # outside `events:` globs
            syms = {s['name'] for s in unc['symbols']}
            self.assertIn('markRead', syms)           # zustand store action
            self.assertIn('willChange', syms)         # exported function
            self.assertNotIn('stays', syms)           # anchored
            self.assertNotIn('skipMe', syms)          # ignore: list
            self.assertNotIn('useA', syms)            # the store hook itself

    def test_other_domains_anchors_count_as_covered(self):
        with tempfile.TemporaryDirectory() as t:
            root = pathlib.Path(t)
            dom = bp.parse_domain(write_domain(root, [dict(id='BP-DEMO-001', anchor='store/a.ts#stays', audit='aligned', notes='')]))
            other = bp.parse_domain(write_domain(root, [dict(id='BP-DEMO-001', anchor='store/bridge.ts#event:demo:two', audit='aligned', notes='')], name='other'))
            web = make_web(root / 'web', WEB_V1)
            unc = bp.uncovered(dom, web, all_domains=[dom, other])
            self.assertNotIn('demo:two', {e['event'] for e in unc['events']})


class CliAndRepoTest(unittest.TestCase):
    def test_report_json_and_update_fingerprints_roundtrip(self):
        with tempfile.TemporaryDirectory() as t:
            root = pathlib.Path(t)
            write_domain(root, [
                dict(id='BP-DEMO-001', anchor='store/a.ts#stays', audit='missing', notes=''),
                dict(id='BP-DEMO-002', anchor='store/a.ts#willChange', audit='differs', notes=''),
                dict(id='BP-DEMO-003', anchor='store/a.ts#gone', audit='intended-difference', notes='owner 2026-10-12'),
            ])
            (root / 'apps/raft_flutter/test').mkdir(parents=True)
            (root / 'apps/raft_flutter/test/a_test.dart').write_text("void main(){ test('[BP-DEMO-001] stays', () {}); }")
            web = make_web(root / 'web', WEB_V1)
            domains = bp.find_domains(root)
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(bp.update_fingerprints(domains, web), 0)
            side = json.loads((root / 'docs/behavior-parity/demo.fingerprints.json').read_text())
            self.assertEqual(sorted(side['rows']), ['BP-DEMO-001', 'BP-DEMO-002', 'BP-DEMO-003'])
            self.assertEqual(side['rows']['BP-DEMO-001']['anchor'], 'store/a.ts#stays')
            report = bp.build_report(root, domains, web, with_uncovered=False)
            counts = report['domains']['demo']['counts']
            self.assertEqual(counts, {'aligned': 1, 'open': 1, 'intended-difference': 1})
            self.assertEqual(report['domains']['demo']['driftCounts'], {'unchanged': 3})
            self.assertEqual(report['errors'], [])
            text = bp.render_text(report)
            self.assertIn('aligned 1', text)

    def test_unresolved_anchor_is_an_audit_error_and_sidecar_not_written(self):
        with tempfile.TemporaryDirectory() as t:
            root = pathlib.Path(t)
            write_domain(root, [dict(id='BP-DEMO-001', anchor='store/a.ts#nope', audit='missing', notes='')])
            web = make_web(root / 'web', WEB_V1)
            with contextlib.redirect_stderr(io.StringIO()):
                rc = bp.update_fingerprints(bp.find_domains(root), web)
            self.assertEqual(rc, 1)
            self.assertFalse((root / 'docs/behavior-parity/demo.fingerprints.json').exists())

    def test_checked_in_checklists_are_well_formed(self):
        """The real checklists: every row parses, IDs are unique, every anchored row has a baseline fingerprint."""
        domains = bp.find_domains(ROOT)
        self.assertGreaterEqual(len(domains), 2)
        all_ids = []
        for dom in domains:
            self.assertEqual(dom.errors, [], dom.file)
            side = bp.load_sidecar(dom)
            self.assertIsNotNone(side, f'{dom.file}: missing sidecar')
            for row in dom.rows:
                all_ids.append(row.id)
                if row.has_anchor:
                    self.assertIn(row.id, side['rows'], row.id)
                    self.assertEqual(side['rows'][row.id]['anchor'], row.anchor, row.id)
            hw = dom.header['web'].split()
            self.assertTrue(side['web']['commit'].startswith(hw[1]) or hw[1].startswith(side['web']['commit']), dom.file)
        self.assertEqual(len(all_ids), len(set(all_ids)))


if __name__ == '__main__':
    unittest.main()
