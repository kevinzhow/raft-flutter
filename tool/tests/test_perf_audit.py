"""Unit tests for tool/perf-audit: regression fixtures, clean fixes, allowlist, and ratchet policy."""
import contextlib
import importlib.machinery
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
LOADER = importlib.machinery.SourceFileLoader('perf_audit_tool', str(ROOT / 'tool/perf-audit'))
SPEC = importlib.util.spec_from_loader('perf_audit_tool', LOADER)
audit = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = audit
LOADER.exec_module(audit)


def make_repo(files: dict[str, str], baseline_files: dict[str, dict[str, int]] | None = None) -> tempfile.TemporaryDirectory:
    tmp = tempfile.TemporaryDirectory()
    root = Path(tmp.name)
    for rel, content in files.items():
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding='utf-8')
    baseline = {
        'version': 1,
        'scopes': list(audit.DEFAULT_SCOPES),
        'totals': {},
        'files': baseline_files or {},
    }
    (root / 'tool').mkdir(parents=True, exist_ok=True)
    (root / 'tool/perf-audit-baseline.json').write_text(json.dumps(baseline, indent=2), encoding='utf-8')
    return tmp


def run_cli(repo: Path, *args: str) -> tuple[int, str, str]:
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        code = audit.main(['--repo', str(repo), *args])
    return code, out.getvalue(), err.getvalue()


REGRESSION_FIXTURES: dict[str, tuple[str, str, str]] = {
    'perf.unique_key_in_render': (
        'third_party/flutter_markdown_plus/lib/src/builder.dart',
        """
class MarkdownBuilder {
  Widget _buildRichText(TextSpan text, {String? key}) {
    final Key k = key == null ? UniqueKey() : Key(key);
    return Text.rich(text, key: k);
  }
}
""",
        'ValueKey',
    ),
    'perf.global_row_invalidation_in_setstate': (
        'apps/raft_flutter/lib/features/chat_view.dart',
        """
class _ChatState {
  @override
  void setState(VoidCallback fn) {
    timelineKeys.invalidateRows();
    super.setState(fn);
  }
}
""",
        'setRowState',
    ),
    'perf.uncached_formatter_or_parser_in_render': (
        'apps/raft_flutter/lib/features/chat_view.dart',
        """
class _ChatState {
  SourceTimeFormatter get timeFormatter => SourceTimeFormatter(
    locale: Localizations.localeOf(context).toLanguageTag(),
  );
}
""",
        'Cache SourceTimeFormatter',
    ),
    'perf.json_encode_in_hot_path': (
        'apps/raft_flutter/lib/features/chat_timeline_presentation.dart',
        """
class Presentation {
  Object _messageState(dynamic msg) {
    return (
      jsonEncode(msg.threadSummary),
      msg.id,
    );
  }
}
""",
        'rowDeepEquals',
    ),
    'perf.cross_notifier_forward': (
        'apps/raft_flutter/lib/features/agent_read_badge.dart',
        """
void wire(dynamic receipts, dynamic w) {
  receipts.addListener(w.notifyListeners);
}
""",
        'ListenableBuilder',
    ),
    'perf.should_repaint_collection_identity': (
        'packages/raft_theme/lib/src/outer_shadow_painter.dart',
        """
class RaftOuterShadowPainter extends CustomPainter {
  final List<BoxShadow> shadows;
  final double radius;
  RaftOuterShadowPainter(this.shadows, this.radius);

  @override
  bool shouldRepaint(RaftOuterShadowPainter old) =>
      old.shadows != shadows || old.radius != radius;
}
""",
        'listEquals',
    ),
    'perf.offstage_without_ticker_mode': (
        'apps/raft_flutter/lib/features/channel_side_column.dart',
        """
class SideColumn {
  Widget build(BuildContext context) {
    return Offstage(offstage: !shown, child: card);
  }
}
""",
        'TickerMode',
    ),
    'perf.inline_listenable_merge_in_build': (
        'apps/raft_flutter/lib/features/workspace_view.dart',
        """
class WorkspaceView {
  Widget buildWorkspace(BuildContext context) => QuietListenableBuilder(
    listenable: Listenable.merge([w, other]),
    builder: (context, _) => const SizedBox.shrink(),
  );
}
""",
        'didUpdateWidget',
    ),
    'perf.broad_media_query_of': (
        'packages/raft_ui/lib/src/adaptive_workspace.dart',
        """
class Adaptive {
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SizedBox(height: media.viewInsets.bottom);
  }
}
""",
        'MediaQuery.sizeOf',
    ),
    'perf.animated_builder_opacity': (
        'packages/raft_ui/lib/src/indicators.dart',
        """
class Pulse {
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) => Opacity(opacity: pulse.value, child: child),
      child: box,
    );
  }
}
""",
        'FadeTransition',
    ),
    'perf.text_painter_in_render': (
        'packages/raft_ui/lib/src/components.dart',
        """
class Composer {
  Widget build(BuildContext context) {
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout(maxWidth: 300);
    return SizedBox(height: tp.height);
  }
}
""",
        'raftTextMetricsCache',
    ),
    'perf.sort_in_hot_path': (
        'apps/raft_flutter/lib/features/resource_view.dart',
        """
class ResourceView {
  Widget build(BuildContext context) {
    final items = List.of(raw)..sort((a, b) => a.compareTo(b));
    return Text(items.first);
  }
}
""",
        'Pre-sort',
    ),
    'perf.eager_scroll_loop': (
        'apps/raft_flutter/lib/features/channel_members_view.dart',
        """
class MembersView {
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (final member in members) MemberRow(member),
      ],
    );
  }
}
""",
        'ListView.builder',
    ),
    'perf.regexp_in_hot_method': (
        'packages/raft_ui/lib/src/icons.dart',
        """
class IconParser {
  bool isLetter(String ch) {
    return RegExp('[a-zA-Z]').hasMatch(ch);
  }
}
""",
        'static final',
    ),
    'perf.external_workspace_notify': (
        'apps/raft_flutter/lib/features/recoverable_uploads_banner.dart',
        """
void onTick(dynamic w) {
  w.notifyListeners();
}
""",
        'scoped ChangeNotifier',
    ),
}


CLEAN_FIXTURES: dict[str, tuple[str, str]] = {
    'unique_key_fixed': (
        'third_party/flutter_markdown_plus/lib/src/builder.dart',
        """
class MarkdownBuilder {
  Widget _buildRichText(TextSpan text, {String? id}) {
    return Text.rich(text, key: id == null ? null : ValueKey(id));
  }
}
""",
    ),
    'set_row_state_fixed': (
        'apps/raft_flutter/lib/features/chat_view.dart',
        """
class _ChatState {
  void setRowState(VoidCallback fn) {
    timelineKeys.invalidateRows();
    setState(fn);
  }
}
""",
    ),
    'cached_formatter_fixed': (
        'apps/raft_flutter/lib/features/chat_view.dart',
        """
class _ChatState {
  SourceTimeFormatter? _cached;
  String? _cachedLocale;
  SourceTimeFormatter timeFormatter(String locale) {
    if (_cachedLocale == locale) return _cached!;
    _cachedLocale = locale;
    return _cached = SourceTimeFormatter(locale: locale);
  }
}
""",
    ),
    'json_encode_fixed': (
        'apps/raft_flutter/lib/features/chat_timeline_presentation.dart',
        """
class Presentation {
  Object _messageState(dynamic msg) {
    return (msg.threadSummaryRevision, msg.id);
  }
}
""",
    ),
    'cross_notifier_fixed': (
        'apps/raft_flutter/lib/features/agent_read_badge.dart',
        """
class ReadBadge {
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: receipts,
      builder: (context, _) => const SizedBox.shrink(),
    );
  }
}
""",
    ),
    'should_repaint_fixed': (
        'packages/raft_theme/lib/src/outer_shadow_painter.dart',
        """
class RaftOuterShadowPainter extends CustomPainter {
  final List<BoxShadow> shadows;
  final double radius;
  RaftOuterShadowPainter(this.shadows, this.radius);

  @override
  bool shouldRepaint(RaftOuterShadowPainter old) =>
      !listEquals(old.shadows, shadows) || old.radius != radius;
}
""",
    ),
    'offstage_with_ticker_mode_fixed': (
        'apps/raft_flutter/lib/features/channel_side_column.dart',
        """
class SideColumn {
  Widget build(BuildContext context) {
    return Offstage(
      offstage: !shown,
      child: TickerMode(enabled: shown, child: card),
    );
  }
}
""",
    ),
    'cached_listenable_merge_fixed': (
        'apps/raft_flutter/lib/features/workspace_view.dart',
        """
class _WorkspaceState {
  late final Listenable _changes = Listenable.merge([w, other]);

  Widget buildWorkspace(BuildContext context) => QuietListenableBuilder(
    listenable: _changes,
    builder: (context, _) => const SizedBox.shrink(),
  );
}
""",
    ),
    'hoisted_regexp_and_aspect_media_query': (
        'packages/raft_ui/lib/src/adaptive_workspace.dart',
        """
final _letterRe = RegExp('[a-zA-Z]');

class Adaptive {
  static final _digitRe = RegExp(r'[0-9]+');
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return RepaintBoundary(child: FadeTransition(opacity: anim, child: SizedBox(height: inset)));
  }
}
""",
    ),
}


class RegressionFixturesTest(unittest.TestCase):
    def test_every_synthetic_regression_fails_check_with_actionable_fix(self):
        for rule_id, (rel_path, source, expected_fix_hint) in REGRESSION_FIXTURES.items():
            with self.subTest(rule=rule_id):
                with make_repo({rel_path: source}) as tmp:
                    code, out, _ = run_cli(Path(tmp), '--check')
                self.assertEqual(code, 1, f'{rule_id} did not fail --check:\n{out}')
                self.assertIn(rule_id, out)
                self.assertIn('0 -> 1', out)
                self.assertIn(expected_fix_hint, out)

    def test_clean_fixed_equivalents_pass_check(self):
        for name, (rel_path, source) in CLEAN_FIXTURES.items():
            with self.subTest(fixture=name):
                with make_repo({rel_path: source}) as tmp:
                    code, out, _ = run_cli(Path(tmp), '--check')
                self.assertEqual(code, 0, f'{name} unexpectedly failed:\n{out}')
                self.assertIn('baseline: no change', out)


class AllowlistTest(unittest.TestCase):
    def test_perf_allow_same_line_and_previous_line_exempt_findings(self):
        source = """
class Sample {
  Widget build(BuildContext context) {
    final a = MediaQuery.of(context); // perf-allow: needs full MediaQueryData for copyWith
    // perf-allow: explicit reset key for one-shot wizard
    return Container(key: UniqueKey(), child: SizedBox(height: a.size.height));
  }
}
"""
        with make_repo({'apps/raft_flutter/lib/features/sample.dart': source}) as tmp:
            code, out, _ = run_cli(Path(tmp), '--check')
        self.assertEqual(code, 0, out)
        self.assertIn('allowlisted 2', out)

    def test_perf_allow_without_reason_is_malformed_and_fails_check(self):
        source = """
class Sample {
  Widget build(BuildContext context) {
    return Container(key: UniqueKey()); // perf-allow:
  }
}
"""
        with make_repo({'apps/raft_flutter/lib/features/sample.dart': source}) as tmp:
            code, out, _ = run_cli(Path(tmp), '--check')
        self.assertEqual(code, 1, out)
        self.assertIn('malformed allow', out)
        self.assertIn('non-empty reason', out)


class RatchetPolicyTest(unittest.TestCase):
    SAMPLE_ONE = """
class Sample {
  Widget build(BuildContext context) {
    final a = MediaQuery.of(context);
    return SizedBox(height: a.size.height);
  }
}
"""
    SAMPLE_TWO = """
class Sample {
  Widget build(BuildContext context) {
    final a = MediaQuery.of(context);
    final b = MediaQuery.of(context);
    return SizedBox(height: a.size.height + b.size.height);
  }
}
"""
    PATH = 'apps/raft_flutter/lib/features/sample.dart'

    def test_ratchet_passes_when_equal_or_lower_and_fails_when_higher(self):
        base = {self.PATH: {'perf.broad_media_query_of': 1}}
        # Equal -> PASS
        with make_repo({self.PATH: self.SAMPLE_ONE}, base) as tmp:
            code, out, _ = run_cli(Path(tmp), '--check')
        self.assertEqual(code, 0, out)
        self.assertIn('baseline: no change', out)

        # Higher (1 -> 2) -> FAIL
        with make_repo({self.PATH: self.SAMPLE_TWO}, base) as tmp:
            code, out, _ = run_cli(Path(tmp), '--check')
        self.assertEqual(code, 1, out)
        self.assertIn('1 -> 2', out)
        self.assertIn('PERF DRIFT GREW', out)

        # Lower (2 -> 1) -> PASS with "baseline can lower"
        base_two = {self.PATH: {'perf.broad_media_query_of': 2}}
        with make_repo({self.PATH: self.SAMPLE_ONE}, base_two) as tmp:
            code, out, _ = run_cli(Path(tmp), '--check')
        self.assertEqual(code, 0, out)
        self.assertIn('baseline can lower', out)
        self.assertIn('2 -> 1', out)

    def test_update_baseline_refuses_increase_and_lowers_cleanly(self):
        base = {self.PATH: {'perf.broad_media_query_of': 1}}
        with make_repo({self.PATH: self.SAMPLE_TWO}, base) as tmp:
            repo = Path(tmp)
            code, _, err = run_cli(repo, '--update-baseline')
            self.assertEqual(code, 1)
            self.assertIn('refusing to raise', err)
            # With --accept-increase it writes 2
            code2, _, _ = run_cli(repo, '--update-baseline', '--accept-increase')
            self.assertEqual(code2, 0)
            updated = json.loads((repo / 'tool/perf-audit-baseline.json').read_text(encoding='utf-8'))
            self.assertEqual(updated['files'][self.PATH]['perf.broad_media_query_of'], 2)

            # Lowering back to 1 succeeds without --accept-increase
            (repo / self.PATH).write_text(self.SAMPLE_ONE, encoding='utf-8')
            code3, _, _ = run_cli(repo, '--update-baseline')
            self.assertEqual(code3, 0)
            lowered = json.loads((repo / 'tool/perf-audit-baseline.json').read_text(encoding='utf-8'))
            self.assertEqual(lowered['files'][self.PATH]['perf.broad_media_query_of'], 1)

    def test_json_with_check_returns_nonzero_on_regression(self):
        with make_repo({self.PATH: self.SAMPLE_ONE}) as tmp:
            code, out, _ = run_cli(Path(tmp), '--json', '--check')
        self.assertEqual(code, 1)
        doc = json.loads(out)
        self.assertEqual(doc['totals']['perf.broad_media_query_of'], 1)


class RepoBaselineContractTest(unittest.TestCase):
    def test_checked_in_baseline_has_zero_p0_render_regressions(self):
        baseline_path = ROOT / 'tool/perf-audit-baseline.json'
        self.assertTrue(baseline_path.is_file(), 'tool/perf-audit-baseline.json must exist')
        doc = json.loads(baseline_path.read_text(encoding='utf-8'))
        totals = doc.get('totals', {})
        self.assertEqual(totals.get('perf.unique_key_in_render', 0), 0)
        self.assertEqual(totals.get('perf.global_row_invalidation_in_setstate', 0), 0)
        for rule_id in totals:
            self.assertIn(rule_id, audit.RULES)


if __name__ == '__main__':
    unittest.main()
