import importlib.util
import argparse
import contextlib
import copy
import io
import json
import os
from pathlib import Path
import signal
import select
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('lab', ROOT / 'tool/performance/lab.py')
lab = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lab)
TOOLCHAIN = {'frameworkRevision': 'framework-test', 'engineRevision': 'engine-test', 'dartSdkVersion': 'dart-test'}


def frames(ui_ms, raster_ms=2.0, period=16667, start=1_000_000):
    return [{'v': start + i * period, 'b': start + i * period + 100, 'ui': int(u * 1000), 'uit': int(u * 1000),
             'rs': start + i * period + 100 + int(u * 1000), 'r': int(raster_ms * 1000), 'total': 0,
             'ph': {'layout': int(u * 600), 'semantics': int(u * 200)}} for i, u in enumerate(ui_ms)]


def record(scenario='steady-scroll', ui=(2, 3, 4), **extra):
    return {'theme': 'brutal-light', 'scenario': scenario, 'kind': 'continuous', 'displayRefreshRate': 60.0,
            'viewWidth': 1000, 'viewHeight': 700, 'frames': frames(ui), **extra}


class DetectionTest(unittest.TestCase):
    def observed(self, scene='steady-scroll', ui=(2, 3, 4), **extra):
        value = record(scene, ui=ui, profile=True, phasesCollected=False,
                       detection={'arrival': {'arrived': True, 'visibleKeys': ['message-fixture']},
                                  'framePolicy': 'benchmarkLive', 'testerPumpsDuringAction': 0,
                                  'bindingAutoFramesSuppressed': True,
                                  'cpuSamplingEnabled': False, 'phaseProfilingEnabled': False,
                                  'renderSurfaceWidth': 1000, 'renderSurfaceHeight': 700,
                                  'nativeWindowWidth': 1000, 'nativeWindowHeight': 700,
                                  'rebuilds': {'instancesCollected': False, 'timelineRowBuilds': 0}})
        value.update(extra)
        for index, frame in enumerate(value['frames']):
            frame['n'] = index + 1
        return value

    def test_actual_refresh_rate_and_separate_pipeline_budgets(self):
        r = self.observed(ui=(9,), displayRefreshRate=120)
        result = lab.detect_record(r)
        self.assertEqual(result['status'], 'REVIEW')
        self.assertEqual(result['findings'][0]['frameId'], 1)
        self.assertAlmostEqual(result['checks']['frame-budget']['budgetUs'], 1e6 / 120)
        r = self.observed(ui=(12,))
        r['frames'][0]['r'] = 12000  # 12+12 is not a 24 ms pipeline budget.
        self.assertEqual(lab.detect_record(r)['checks']['frame-budget']['status'], 'PASS')

    def test_uit_does_not_replace_the_raw_ui_duration(self):
        r = self.observed(ui=(2,))
        r['frames'][0]['uit'] = 200000
        self.assertFalse(lab.detect_record(r)['findings'])

    def test_all_slow_frames_including_cold_first_are_retained(self):
        r = self.observed('open-cold', ui=(60, 20, 20, 3))
        r['detection']['actions'] = [{'name': 'open-alpha', 'startUs': 1_000_000, 'endUs': 2_000_000}]
        out = lab.detect_record(r, evidence=['raw.json'])
        self.assertEqual([f['frameId'] for f in out['findings']], [1, 2, 3])
        self.assertEqual(out['findings'][0]['observed']['action'], 'open-alpha')
        self.assertEqual(out['findings'][2]['observed']['priority'], 'high')
        self.assertIsNone(out['findings'][0]['cause'])  # First-use delay is not shader proof.
        self.assertEqual(out['findings'][0]['evidence'], ['raw.json'])

    def test_missing_arrival_cannot_pass_even_with_fast_frames(self):
        r = self.observed()
        r['detection'].pop('arrival')
        self.assertEqual(lab.detect_record(r)['status'], 'NOT_RUN')

    def test_missing_arrival_keeps_slow_frame_in_table_and_heading(self):
        r = self.observed(ui=(25,))
        r['detection'].pop('arrival')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'brutal-light-steady-scroll.json').write_text(json.dumps(r))
            out = lab.detection_report(root, ['steady-scroll'], ['brutal-light'])
            row = out['scenarios'][0]
            self.assertEqual(row['status'], 'NOT_RUN')
            self.assertEqual(row['statuses'], ['NOT_RUN', 'REVIEW'])
            text = (root / 'detection.md').read_text()
            self.assertIn('| steady-scroll | brutal-light | NOT_RUN + REVIEW |', text)
            self.assertIn('## brutal-light / steady-scroll — NOT_RUN + REVIEW', text)

    def test_a_started_failure_is_an_issue(self):
        self.assertEqual(lab.detect_record(self.observed(failure='Target never appeared'))['status'], 'ISSUE')

    def test_visible_target_does_not_hide_rejected_live_operation(self):
        r = self.observed('nav-activity-item')
        r['detection']['operationFailures'] = ['agentRevalidation was not accepted']
        self.assertEqual(lab.detect_record(r)['status'], 'ISSUE')

    def test_invalid_refresh_rate_or_raw_frame_is_not_defaulted(self):
        for hz in (None, 0, float('nan'), True):
            with self.subTest(hz=hz):
                r = self.observed(displayRefreshRate=hz)
                self.assertEqual(lab.detect_record(r)['checks']['frame-budget']['status'], 'NOT_RUN')
                self.assertEqual(lab.detect_record(r)['status'], 'NOT_RUN')
        r = self.observed()
        del r['frames'][0]['ui']
        self.assertEqual(lab.detect_record(r)['checks']['frame-budget']['status'], 'NOT_RUN')

    def test_detailed_trace_has_no_timing_pass(self):
        r = self.observed(ui=(25,), phasesCollected=True)
        out = lab.detect_record(r)
        self.assertEqual(out['checks']['frame-budget']['status'], 'REVIEW')
        self.assertFalse(out['findings'][0]['observed']['timingVerdictAllowed'])
        self.assertEqual(out['findings'][0]['signal'], 'instrumented-frame')

    def test_cpu_sampling_and_hidden_phase_profiling_disable_timing_verdict(self):
        for signal in ('cpuSamplingEnabled', 'phaseProfilingEnabled'):
            r = self.observed(ui=(25,))
            r['detection'][signal] = True
            out = lab.detect_record(r)
            self.assertEqual(out['checks']['frame-budget']['status'], 'REVIEW')
            self.assertFalse(out['findings'][0]['observed']['timingVerdictAllowed'])
            del r['detection'][signal]
            self.assertEqual(lab.detect_record(r)['checks']['frame-budget']['status'], 'REVIEW')

    def test_simulated_phone_size_cannot_certify_native_frame_budget(self):
        for ui in ((2,), (25,)):
            r = self.observed(ui=ui)
            r['detection'].update(renderSurfaceWidth=390, renderSurfaceHeight=640)
            out = lab.detect_record(r)
            self.assertEqual(out['checks']['render-surface']['status'], 'REVIEW')
            self.assertEqual(out['checks']['frame-budget']['status'], 'REVIEW')
            self.assertFalse(any(f['observed'].get('timingVerdictAllowed') for f in out['findings']))

    def test_unknown_or_invalid_native_size_cannot_pass(self):
        for size in (None, 0, True, float('nan'), float('inf')):
            r = self.observed()
            r['detection']['nativeWindowWidth'] = size
            out = lab.detect_record(r)
            self.assertEqual(out['checks']['render-surface']['status'], 'REVIEW')
            self.assertEqual(out['status'], 'REVIEW')

    def idle_record(self, **extra):
        r = self.observed('idle-final', ui=(2, 2, 2), kind='idle', idleSeconds=10, **extra)
        r['frames'] = frames((2, 2, 2), period=600000)
        return r

    def test_healthy_natural_idle_without_frames_is_observed(self):
        r = self.idle_record()
        r['frames'] = []
        out = lab.detect_record(r)
        self.assertEqual(out['checks']['idle-work']['status'], 'PASS')
        self.assertEqual(out['checks']['frame-budget']['frames'], 0)
        self.assertEqual(out['checks']['unrelated-rebuild']['status'], 'NOT_RUN')

    def test_fully_live_and_benchmark_are_not_idle_proof(self):
        for policy in ('fullyLive', 'benchmark'):
            r = self.idle_record()
            r['detection']['framePolicy'] = policy
            self.assertEqual(lab.detect_record(r)['checks']['idle-work']['status'], 'NOT_RUN')
        r['detection'].update(framePolicy='benchmarkLive', testerPumpsDuringAction=1)
        self.assertEqual(lab.detect_record(r)['checks']['idle-work']['status'], 'NOT_RUN')
        r['detection'].update(testerPumpsDuringAction=0, bindingAutoFramesSuppressed=False)
        self.assertEqual(lab.detect_record(r)['checks']['idle-work']['status'], 'NOT_RUN')

    def test_continuous_idle_frames_need_replay_until_fixture_cause_known(self):
        r = self.idle_record()
        out = lab.detect_record(r)
        self.assertEqual(out['checks']['idle-work']['status'], 'REVIEW')
        self.assertIsNone(out['findings'][0]['component'])
        r['detection']['control'] = 'unexpected-ticker'
        out = lab.detect_record(r)
        self.assertEqual(out['status'], 'ISSUE')
        self.assertEqual(out['findings'][0]['component'], '_DetectionTicker')

    def test_allowed_animation_is_not_an_idle_paint_storm(self):
        r = self.idle_record()
        r['detection']['allowedActivity'] = ['fixture animation']
        self.assertEqual(lab.detect_record(r)['checks']['idle-work']['status'], 'PASS')
        self.assertFalse(lab.detect_record(r)['findings'])

    def test_aggregate_build_count_is_never_instance_proof(self):
        r = self.idle_record()
        r['frames'] = []
        r['detection']['rebuilds']['timelineRowBuilds'] = 7
        out = lab.detect_record(r)
        self.assertEqual(out['status'], 'REVIEW')
        self.assertEqual(out['checks']['unrelated-rebuild']['status'], 'NOT_RUN')
        self.assertEqual(out['findings'][0]['signal'], 'idle-row-builds')

    def test_reused_debug_instance_counter_requires_specific_scope_evidence(self):
        r = self.observed()
        r['detection']['rebuilds'] = {'instancesCollected': True, 'instances': [
            {'component': 'message-unchanged@12', 'unexpected': True, 'rebuilds': 3}]}
        out = lab.detect_record(r)
        self.assertEqual(out['status'], 'ISSUE')
        self.assertEqual(out['findings'][0]['occurrences'], 3)

    def test_report_preserves_missing_scenes_and_writes_full_findings(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / 'brutal-light-open-cold.json').write_text(json.dumps(self.observed('open-cold', ui=(30,))))
            out = lab.detection_report(root, ['open-cold', 'keyboard'], ['brutal-light'])
            self.assertEqual(out['scenarios'][0]['status'], 'REVIEW')
            self.assertEqual(out['scenarios'][1]['status'], 'NOT_RUN')
            self.assertFalse(out['comparison'])
            self.assertIn('video-play-pause', (root / 'detection.md').read_text())
            self.assertEqual(json.loads((root / 'detection.json').read_text())['scenarios'][0]['findings'][0]['frameId'], 1)

    def test_detection_runs_one_launch_without_quiet_wait_comparison_or_qualification(self):
        with tempfile.TemporaryDirectory() as d:
            args = argparse.Namespace(out=Path(d) / 'new', scenarios='keyboard', themes='brutal-light',
                seconds=8, semantics='platform', details=False, headless=True, records=None)
            with patch.object(lab, 'build', return_value=0) as build, patch.object(lab, 'run', return_value=0) as run, \
                 patch.object(lab, 'compare_cmd') as compare, patch.object(lab, 'qualify_cmd') as qualify, \
                 patch.object(lab.platform, 'system', return_value='Linux'), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(lab.detect_cmd(args), 0)
            self.assertEqual(build.call_count, 1)
            self.assertEqual(run.call_count, 1)
            invocation = run.call_args.args[0]
            self.assertEqual(invocation.wait_quiet, 0)
            self.assertIsNone(invocation.reference)
            self.assertTrue(invocation.no_trace)
            self.assertTrue(invocation.detection)
            self.assertEqual(lab.workload_defines(lab.workload_config(invocation))['RAFT_LAB_IDLE_SECONDS'], '10')
            compare.assert_not_called()
            qualify.assert_not_called()

    def test_unreadable_raw_record_is_not_a_pass(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / 'brutal-light-keyboard.json').write_text('{unfinished')
            out = lab.detection_report(root, ['keyboard'], ['brutal-light'])
            self.assertEqual(out['scenarios'][0]['status'], 'NOT_RUN')

    def test_valid_json_with_wrong_record_shape_is_not_a_pass(self):
        for record in ([], {'detection': []}):
            with self.subTest(record=record), tempfile.TemporaryDirectory() as d:
                root = Path(d)
                (root / 'brutal-light-keyboard.json').write_text(json.dumps(record))
                out = lab.detection_report(root, ['keyboard'], ['brutal-light'])
                self.assertEqual(out['scenarios'][0]['status'], 'NOT_RUN')

    def test_suite_failure_and_sampler_error_survive_fast_scene_results(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / 'brutal-light-open-cold.json').write_text(json.dumps(self.observed('open-cold')))
            (root / 'lab-done.json').write_text(json.dumps({'failures': ['Initial target did not appear']}))
            (root / 'lab-sampler-errors.txt').write_text('start: failed\n')
            out = lab.detection_report(root, ['open-cold'], ['brutal-light'])
            issue = next(row for row in out['scenarios'] if row['scene'] == 'collection')
            self.assertEqual(issue['status'], 'ISSUE')
            self.assertIn('Initial target', issue['reason'])
            self.assertIn('Sampler failed', issue['reason'])

    def test_runtime_cleanup_only_unmounts_the_owned_session(self):
        with tempfile.TemporaryDirectory(prefix='raft-detect-', dir='/tmp') as d:
            root = Path(d)
            (root / 'gvfs').mkdir()
            mountinfo = f'1 0 0:1 / {root}/gvfs rw - fuse.gvfsd-fuse gvfsd-fuse rw\n'
            mountinfo += '2 0 0:2 / /run/user/1000/gvfs rw - fuse.gvfsd-fuse gvfsd-fuse rw\n'
            with patch.object(lab.Path, 'read_text', return_value=mountinfo), \
                 patch.object(lab.subprocess, 'run', return_value=argparse.Namespace(returncode=0, stderr='')) as unmount:
                result = lab.cleanup_private_runtime(root)
            self.assertTrue(result['removed'])
            self.assertEqual(unmount.call_args.args[0], ['fusermount3', '-u', '-z', '--', str(root / 'gvfs')])
            self.assertEqual(unmount.call_count, 1)

    def test_runtime_cleanup_rejects_unowned_paths_and_symlinks(self):
        with self.assertRaises(ValueError):
            lab.cleanup_private_runtime('/run/user/1000')
        with tempfile.TemporaryDirectory(prefix='raft-detect-', dir='/tmp') as d:
            link = Path(d + '-link')
            try:
                link.symlink_to(d)
                with self.assertRaises(ValueError):
                    lab.cleanup_private_runtime(link)
                self.assertTrue(Path(d).is_dir())
            finally:
                link.unlink()

    def test_engine_errors_are_reported_even_when_frame_checks_pass(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / 'brutal-light-open-cold.json').write_text(json.dumps(self.observed('open-cold')))
            (root / 'runner.log').write_text('[ERROR:flutter/text.cc(200)] atlas failure\n' * 2)
            out = lab.detection_report(root, ['open-cold'], ['brutal-light'])
            row = next(row for row in out['scenarios'] if row['scene'] == 'collection-renderer')
            self.assertEqual(row['status'], 'ISSUE')
            self.assertEqual(row['findings'][0]['occurrences'], 2)
            self.assertIsNone(row['findings'][0]['cause'])


class SummaryTest(unittest.TestCase):
    def test_budgets_and_gate(self):
        row = lab.summarize_record(record(ui=[2, 9, 20]))
        self.assertEqual(row['over8Ui'], 2)
        self.assertEqual(row['over16Ui'], 1)
        self.assertFalse(row['gate60'])
        self.assertEqual(row['semanticsShare'], round(100 * (400 + 1800 + 4000) / 31000, 1))
        self.assertTrue(lab.summarize_record(record(ui=[2, 9, 12]))['gate60'])

    def test_stutter_counts_skipped_vsyncs_only_for_continuous(self):
        r = record(ui=[2, 2, 2])
        r['frames'][2]['v'] += 20000  # one doubled frame interval
        self.assertEqual(lab.summarize_record(r)['stutters'], 1)
        r['kind'] = 'transitions'
        self.assertEqual(lab.summarize_record(r)['stutters'], 0)

    def test_mount_steps_cost_per_row(self):
        r = record('mount-plain', ui=[10, 1, 20, 2], kind='mount', rowKind='plain')
        f = r['frames']
        r['steps'] = [{'t0': f[0]['b'] - 10, 't1': f[2]['b'] - 10, 'newRows': 5},
                      {'t0': f[2]['b'] - 10, 't1': f[3]['b'] + 10, 'newRows': 4}]
        m = lab.summarize_record(r)['mount']
        self.assertEqual(m['rowsMounted'], 9)
        self.assertEqual(sorted([2000, 5000]), [lab.pct([2000, 5000], .5), m['perRowUs']['max']])

    def test_compare_flags_regressions(self):
        base = {'hello': {'fixtureVersion': 'v1'}, 'env': {}, 'scenarios': [lab.summarize_record(record(ui=[2] * 50))]}
        worse = {'hello': {'fixtureVersion': 'v1'}, 'env': {}, 'scenarios': [lab.summarize_record(record(ui=[2] * 49 + [20]))]}
        result = lab.compare(base, worse)
        self.assertGreater(result['regressions'], 0)
        self.assertIn('60 Hz gate pass→FAIL', result['rows'][0]['regressions'])
        self.assertEqual(lab.compare(base, base)['regressions'], 0)
        other = dict(worse, hello={'fixtureVersion': 'v2'})
        self.assertIn('fixture versions differ; numbers are not comparable', lab.compare(base, other)['problems'])

    def test_live_navigation_work_is_preserved_in_summary(self):
        r = record('nav-computer-detail', kind='transitions')
        r['opens'] = [
            {'channel': name, 'visibleMs': 20, 't0': 1_000_000, 't1': 2_000_000,
             'liveActivity': {'events': [{'event': 'agent:created'}, {'event': 'agent:deleted'}],
                              'accepted': {'agentCreate': 1, 'agentDelete': 1}, 'workspaceNotifications': 3},
             'predictiveBackGestures': int(name == 'back'), 'imageResponsesStarted': 2,
             'cacheReads': 1, 'cacheWritesCompleted': 4,
             'requests': {'GET /agents': 2}, 'responses': {'GET /agents': 2}}
            for name in ('enter', 'back')]
        work = lab.summarize_record(r)['navigationActivity']
        self.assertEqual(work['transitions'], 2)
        self.assertEqual(work['events'], 4)
        self.assertEqual(work['accepted'], {'agentCreate': 2, 'agentDelete': 2})
        self.assertEqual(work['predictiveBackGestures'], 1)
        self.assertEqual(work['cacheWritesCompleted'], 8)
        self.assertEqual(work['requests'], {'GET /agents': 4})
        self.assertEqual(work['responses'], {'GET /agents': 4})
        self.assertNotIn('navigationActivity', lab.summarize_record(record()))

    def test_summarize_run_directory(self):
        with tempfile.TemporaryDirectory() as d:
            run = Path(d)
            (run / 'brutal-light-steady-scroll.json').write_text(json.dumps(record()))
            (run / 'brutal-light-steady-scroll.attribution.json').write_text(json.dumps({
                'gcCount': 3, 'cpuWorstUiFrames': {'samples': 10, 'categories': {'fontFallback': 8},
                                                   'appInclusive': [{'name': 'A.build', 'value': 5}], 'self': [], 'inclusive': []},
                'rasterWorstFrames': {'inclusiveUs': [{'name': 'ReactorGLES::React', 'value': 1500}]}}))
            summary = lab.summarize(run)
            self.assertEqual(summary['env']['renderer'], 'Impeller (OpenGLES)')
            self.assertTrue(summary['gate60Passed'])
            text = (run / 'summary.md').read_text()
            self.assertIn('fontFallback 80.0%', text)
            self.assertIn('| steady-scroll | brutal-light | 3 |', text)

    def test_keyboard_windows_ignore_the_pause(self):
        r = record('keyboard', ui=[2, 20, 9, 2, 3], kind='keyboard', keyboardCycles=1)
        for frame, builds, layouts, paints in zip(r['frames'], (5000, 900, 800, 1, 2), (9, 40, 30, 1, 1), (9, 20, 18, 1, 1)):
            frame['builds'] = builds
            frame['layouts'] = layouts
            frame['paints'] = paints
        r['frames'][1]['r'] = 18000
        r['frames'][2]['r'] = 9000
        f = r['frames']
        r['keyboard'] = [
            {'direction': 'open', 't0': f[1]['b'], 't1': f[2]['b'], 'cpuUs': 1200},
            {'direction': 'close', 't0': f[2]['b'], 't1': f[3]['b'], 'cpuUs': 800},
        ]
        row = lab.summarize_record(r)
        k = row['keyboard']
        self.assertEqual(k['frames'], 2)
        self.assertEqual(k['worstUiMs'], 20.0)
        self.assertEqual(k['worstRasterMs'], 18.0)
        self.assertEqual(k['over8Ui'], 2)
        self.assertEqual(k['over16Ui'], 1)
        self.assertEqual(k['over8Raster'], 2)
        self.assertEqual(k['over16Raster'], 1)
        self.assertEqual(k['builds'], {'sum': 1700, 'max': 900, 'mean': 850.0})
        self.assertEqual(k['layouts'], {'sum': 70, 'max': 40, 'mean': 35.0})
        self.assertEqual(k['paints'], {'sum': 38, 'max': 20, 'mean': 19.0})
        self.assertEqual(k['uiThreadCpuUs'], 2000)
        text = lab.markdown({'run': 'kb', 'env': {}, 'hello': {}, 'scenarios': [row], 'gate60Passed': False})
        self.assertIn('Soft keyboard', text)
        self.assertIn('850.0', text)
        self.assertIn('35.0', text)
        self.assertIn('19.0', text)
        self.assertIn('a reference, not a gate', text)
        self.assertNotIn('1700/900', text)

    def test_keyboard_thread_time_joins_animation_frames_only(self):
        r = record('keyboard', ui=[4, 5], kind='keyboard')
        f = r['frames']
        r['keyboard'] = [{'direction': 'open', 't0': f[0]['b'], 't1': f[1]['b'] + 1, 'cpuUs': 100}]
        attribution = {
            'threadTime': {
                'collected': True,
                'uiThreads': ['io.flutter.1.ui'],
                'rasterThreads': ['io.flutter.1.raster'],
                'uiEvents': 4, 'uiEventsWithTdur': 4, 'uiEventsWithTts': 4,
                'rasterEvents': 4, 'rasterEventsWithTdur': 0, 'rasterEventsWithTts': 0,
            },
            'frameThreadTime': [
                {'b': f[0]['b'], 'uiCpuUs': 1500, 'uiEvent': 'Animator::BeginFrame', 'rasterEvent': 'Rasterizer::Draw'},
                {'b': f[1]['b'], 'uiCpuUs': 2500, 'uiEvent': 'Animator::BeginFrame'},
            ],
        }
        row = lab.summarize_record(r, attribution)
        self.assertEqual(row['keyboard']['uiCpuUs']['p50'], 1500)
        self.assertNotIn('rasterCpuUs', row['keyboard'])
        text = lab.markdown({'run': 'kb', 'env': {}, 'hello': {}, 'scenarios': [row], 'gate60Passed': True})
        self.assertIn('raster thread has 4 events and no tdur', text)
        self.assertIn('UI median 1.5 ms CPU', text)

    def test_proc_scene_cpu_names_its_source(self):
        r = record('keyboard', ui=[4, 5], kind='keyboard')
        f = r['frames']
        r['keyboard'] = [{'direction': 'open', 't0': f[0]['b'], 't1': f[1]['b'] + 1}]
        attribution = {
            'procThreadCpu': {
                'source': 'proc-schedstat',
                'collected': True,
                'clkTck': 100,
                'ui': {'tid': 10, 'comm': 'lutter.linkperf', 'matchedBy': 'main-thread', 'ticks': 12, 'ms': 120.0},
                'raster': {'tid': 11, 'comm': '1.raster', 'matchedBy': 'name', 'ticks': 8, 'ms': 80.0},
            },
        }
        row = lab.summarize_record(r, attribution)
        text = lab.markdown({'run': 'kb', 'env': {}, 'hello': {}, 'scenarios': [row], 'gate60Passed': True})
        self.assertIn('scene CPU from /proc schedstat, not timeline tts', text)
        self.assertIn('UI 120.0 ms (main thread `lutter.linkperf`', text)
        self.assertIn('raster 80.0 ms (`1.raster`)', text)

    def test_keyboard_count_change_does_not_change_the_comparison(self):
        def scenario(builds):
            r = record('keyboard', ui=[20, 9], kind='keyboard', keyboardCycles=1)
            for frame, count in zip(r['frames'], builds):
                frame['builds'] = count
                frame['layouts'] = 10
                frame['paints'] = 4
            f = r['frames']
            r['keyboard'] = [{'direction': 'open', 't0': f[0]['b'] - 1, 't1': f[-1]['b'] + 10, 'cpuUs': 1500}]
            return lab.summarize_record(r)

        before = {'hello': {'fixtureVersion': 'v1'}, 'env': {}, 'scenarios': [scenario([900, 800])]}
        after = {'hello': {'fixtureVersion': 'v1'}, 'env': {}, 'scenarios': [scenario([3, 2])]}
        better = lab.compare(before, after)
        self.assertEqual(better['rows'][0]['regressions'], [])
        self.assertEqual(better['rows'][0]['improvements'], [])
        self.assertEqual(better['regressions'], 0)
        worse = lab.compare(after, before)
        self.assertEqual(worse['rows'][0]['regressions'], [])
        self.assertEqual(worse['rows'][0]['improvements'], [])
        self.assertEqual(worse['regressions'], 0)
        self.assertEqual(better['rows'][0]['metrics']['keyboard.builds'][0]['mean'], 850)
        self.assertEqual(better['rows'][0]['metrics']['keyboard.builds'][1]['mean'], 2.5)
        text = lab.compare_markdown(better, 'before', 'after')
        self.assertIn('850.0→2.5', text)
        self.assertIn('a reference, not a gate', text)
        self.assertNotIn('deterministic check', text)

    def test_paired_ratio_interval(self):
        same = [(10, 10)] * 12
        ci = lab.paired_ratio_ci(same, samples=200)
        self.assertEqual(lab.ratio_verdict(ci, high_limit=1.03, low_limit=0.97), 'same')
        slower = [(10, 12)] * 12
        slow_ci = lab.paired_ratio_ci(slower, samples=200)
        self.assertEqual(lab.ratio_verdict(slow_ci), 'regression')
        self.assertEqual(lab.ratio_verdict({'low': 0.98, 'high': 1.08}), 'uncertain')
        self.assertEqual(lab.ratio_verdict({'low': 0.90, 'high': 1.02}), 'pass')
        self.assertEqual(lab.paired_ratio_ci([])['rounds'], 0)
        self.assertEqual(lab.ratio_verdict(lab.paired_ratio_ci([])), 'no-data')
        same_batches = [([10, 100], [10, 100])] * 8
        cluster = lab.cluster_ratio_ci(same_batches, samples=200)
        self.assertEqual(cluster['pairs'], 8)
        self.assertEqual(lab.ratio_verdict(cluster, high_limit=1.03, low_limit=0.97), 'same')
        self.assertEqual(lab.cluster_ratio_ci([])['pairs'], 0)


def calibration_run(side):
    cpus = [0, 2] if side == 'old' else [1, 3]
    pid = 100 if side == 'old' else 200
    source = {'digest': 'a' * 64}
    artifact = {'digest': ('b' if side == 'old' else 'c') * 64,
                'path': f'/isolated/{side}', 'files': {'raft_flutter': 'd' * 64, 'lib/libflutter_linux_gtk.so': 'e' * 64}}
    config = {'themes': 'brutal-light', 'scenarios': 'keyboard', 'seconds': 8,
              'semantics': 'platform', 'phases': True, 'rounds': 3}
    manifest = {'schema': 1, 'source': source, 'artifact': artifact,
                'driverSha256': 'e' * 64, 'fixtureSha256': 'f' * 64,
                'toolchain': TOOLCHAIN,
                'buildReceipt': {'source': source, 'sourceAfter': source, 'artifact': artifact, 'exitCode': 0, 'toolchain': TOOLCHAIN,
                                 'config': config, 'identitySuffix': f'.{side}'},
                'config': config, 'pair': '01', 'order': side,
                'invocation': ['python3', 'tool/performance/lab.py', 'run'],
                'bootId': 'test-boot', 'cpus': cpus, 'topology': [
                    {'cpu': i, 'core': i % 2, 'socket': 0, 'siblings': [i % 2, i % 2 + 2]}
                    for i in range(4)]}
    rows, frame_rows, barriers = [], [], []
    for n in range(4):
        start = 1_000_000_000 + n * 10_000_000_000
        role = lambda tid: {'tid': tid, 'ns': 10_000, 'ms': .01,
            'start': {'beforeNs': start, 'afterNs': start + 10, 'cpus': cpus, 'startTicks': tid},
            'end': {'beforeNs': start + 1_000_000_000, 'afterNs': start + 1_000_000_010,
                    'cpus': cpus, 'startTicks': tid}}
        rows.append({'batch': side, 'pair': '01', 'order': side, 'round': n, 'warmup': n == 0,
                     'collected': True, 'source': 'proc-schedstat', 'pid': pid, 'processStartTicks': pid,
                     'executable': f'/isolated/{side}/raft_flutter', 'ui': role(pid + 1), 'raster': role(pid + 2),
                     'mappedAot': [f'/isolated/{side}/lib/libapp.so'],
                     'theme': 'brutal-light', 'scenario': 'keyboard', 'load': '21 18 16', 'loadEnd': '22 18 16'})
        frame_rows.append({'batch': side, 'round': n, 'warmup': n == 0,
                           'record': record('keyboard', kind='keyboard')})
        barriers.append({'batch': side, 'peerBatch': 'new' if side == 'old' else 'old', 'round': n})
    return {'manifest': manifest, 'env': {'exitCode': 0, 'hostActivity': {'intervalSeconds': 4, 'processes': []}},
            'hello': {'fixtureVersion': 'test-m7', 'linuxApplicationIdSuffix': f'.{side}', 'themes': ['brutal-light'], 'scenarios': ['keyboard'],
                      'seconds': 8, 'semantics': 'platform', 'phases': True},
            'driverResult': {'result': 'true', 'failureDetails': []},
            'done': {'failures': []}, 'samplerErrors': '', 'procRounds': rows,
            'frameRounds': frame_rows, 'barrierRounds': barriers}


class ConcurrentQualificationTest(unittest.TestCase):
    def test_overlap_requires_both_positive_windows(self):
        self.assertTrue(lab.window_overlap(0, 1000, 10, 1010)['ok'])
        for values in ((0, 100, 0, 10), (0, 0, 0, 100), (0, 100, 0, float('nan'))):
            self.assertFalse(lab.window_overlap(*values)['ok'])

    def test_all_rounds_and_actual_roles_qualify_under_natural_high_load(self):
        result = lab.qualify_pair(calibration_run('old'), calibration_run('new'))
        self.assertTrue(result['qualified'], result['reasons'])
        self.assertEqual(len(result['rounds']), 4)
        self.assertEqual(result['independentPairs'], 1)
        self.assertIn('Flutter', result['primaryMetrics'])

    def test_invalid_warmup_or_one_measured_round_voids_the_whole_pair(self):
        for index in (0, 2):
            old, new = calibration_run('old'), calibration_run('new')
            new['procRounds'][index]['raster']['start']['beforeNs'] += 900_000_000
            new['procRounds'][index]['raster']['start']['afterNs'] += 900_000_000
            result = lab.qualify_pair(old, new)
            self.assertFalse(result['qualified'])
            self.assertEqual(result['independentPairs'], 0)
            self.assertTrue(any('overlap' in reason for reason in result['reasons']))

    def test_missing_malformed_and_nonfinite_observations_are_not_filtered(self):
        for bad in (None, 0, -1, float('nan'), float('inf'), True):
            old, new = calibration_run('old'), calibration_run('new')
            new['procRounds'][1]['ui']['ns'] = bad
            result = lab.qualify_pair(old, new)
            self.assertFalse(result['qualified'], bad)

    def test_role_affinity_and_counter_identity_are_required(self):
        for change in ('missing', 'different', 'thread-replaced'):
            old, new = calibration_run('old'), calibration_run('new')
            role = new['procRounds'][0]['ui']
            if change == 'missing':
                role['start'].pop('cpus')
            elif change == 'different':
                role['end']['cpus'] = [0, 2]
            else:
                role['end']['startTicks'] += 1
            self.assertFalse(lab.qualify_pair(old, new)['qualified'], change)

    def test_smt_overlap_and_reused_launch_are_rejected(self):
        old, new = calibration_run('old'), calibration_run('new')
        new['manifest']['cpus'] = [2]
        self.assertFalse(lab.qualify_pair(old, new)['qualified'])
        old, new = calibration_run('old'), calibration_run('new')
        first = lab.qualify_pair(old, new)
        self.assertFalse(lab.qualify_pair(old, new, seen_launches=set(first['launchKeys']))['qualified'])

    def test_missing_round_sampler_error_or_false_success_is_rejected(self):
        for field in ('procRounds', 'frameRounds', 'barrierRounds', 'samplerErrors', 'driverResult'):
            old, new = calibration_run('old'), calibration_run('new')
            if field.endswith('Rounds'):
                new[field].pop(1)
            elif field == 'samplerErrors':
                new[field] = 'cpu: read failed'
            else:
                new[field] = {'result': 'false', 'failureDetails': []}
            self.assertFalse(lab.qualify_pair(old, new)['qualified'], field)

    def test_source_artifact_configuration_and_launch_match_receipts(self):
        for field in ('source', 'artifact', 'config', 'identitySuffix'):
            old, new = calibration_run('old'), calibration_run('new')
            receipt = copy.deepcopy(new['manifest']['buildReceipt'])
            receipt[field] = {} if field != 'identitySuffix' else ''
            new['manifest']['buildReceipt'] = receipt
            self.assertFalse(lab.qualify_pair(old, new)['qualified'], field)

    def test_counter_read_uncertainty_cannot_manufacture_overlap(self):
        old, new = calibration_run('old'), calibration_run('new')
        # Nominal start stamps match, but the first counter read takes 10% of
        # the window. Its guaranteed overlap is below 95% of the other side.
        new['procRounds'][0]['ui']['start']['afterNs'] += 100_000_000
        self.assertFalse(lab.qualify_pair(old, new)['qualified'])

    def test_loaded_fixture_engine_and_toolchain_must_match(self):
        for field in ('fixture', 'engine', 'toolchain'):
            old, new = calibration_run('old'), calibration_run('new')
            if field == 'fixture':
                new['hello']['fixtureVersion'] = 'old-arrival-condition'
            elif field == 'engine':
                new['manifest']['artifact']['files']['lib/libflutter_linux_gtk.so'] = 'f' * 64
            else:
                new['manifest']['toolchain'] = {**TOOLCHAIN, 'engineRevision': 'different-engine'}
            self.assertFalse(lab.qualify_pair(old, new)['qualified'], field)

    def test_actual_loaded_artifact_and_units_must_match(self):
        for field in ('executable', 'mappedAot', 'ms', 'peer', 'loaded-config'):
            old, new = calibration_run('old'), calibration_run('new')
            if field in ('executable', 'mappedAot'):
                new['procRounds'][1][field] = '/another/bundle'
            elif field == 'ms':
                new['procRounds'][1]['ui']['ms'] = float('nan')
            elif field == 'peer':
                new['barrierRounds'][1]['peerBatch'] = 'stale'
            else:
                new['hello']['seconds'] = 2
            self.assertFalse(lab.qualify_pair(old, new)['qualified'], field)

    def test_qualify_command_preserves_original_inputs_and_rejects_reuse(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            names = {'manifest': 'run-manifest.json', 'env': 'env.json', 'hello': 'lab-hello.json',
                     'driverResult': 'driver-result.json', 'done': 'lab-done.json'}
            for side in ('old', 'new'):
                folder = base / side
                folder.mkdir()
                run = calibration_run(side)
                for key, filename in names.items():
                    (folder / filename).write_text(json.dumps(run[key]))
                for key, filename in (('procRounds', 'proc-rounds.jsonl'), ('frameRounds', 'frame-rounds.jsonl'), ('barrierRounds', 'barrier-rounds.jsonl')):
                    (folder / filename).write_text(''.join(json.dumps(row) + '\n' for row in run[key]))
            args = argparse.Namespace(old=base / 'old', new=base / 'new', out=base / 'first.json', previous=[])
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(lab.qualify_cmd(args), 0)
                args.previous = [args.out]
                args.out = base / 'second.json'
                self.assertEqual(lab.qualify_cmd(args), 1)
            self.assertIn('launch already used', json.loads(args.out.read_text())['reasons'])
            self.assertEqual(len((base / 'old/proc-rounds.jsonl').read_text().splitlines()), 4)


class ReceiptAndNaturalLoadTest(unittest.TestCase):
    def test_build_receipt_binds_source_configuration_and_copied_bundle(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            app = root / 'app'
            source = {'digest': 'a' * 64, 'files': {'lib/main.dart': 'b' * 64}}
            args = argparse.Namespace(out=root / 'evidence', identity_suffix='.m7old', themes='brutal-light',
                                      scenarios='keyboard', seconds=8, rounds=3, semantics='platform', no_trace=False)

            def compiler(argv, **kw):
                self.assertIn('--profile', argv)
                self.assertIn('--dart-define=RAFT_LINUX_APPLICATION_ID_SUFFIX=.m7old', argv)
                self.assertEqual(kw['env']['RAFT_APPLICATION_ID_SUFFIX'], '.m7old')
                bundle = app / 'build/linux/x64/profile/bundle'
                (bundle / 'lib').mkdir(parents=True)
                (bundle / 'raft_flutter').write_bytes(b'fixture executable')
                (bundle / 'lib/libapp.so').write_bytes(b'fixture AOT')
                return argparse.Namespace(returncode=0)

            with patch.object(lab, 'ROOT', root), patch.object(lab, 'APP', app), \
                 patch.object(lab.platform, 'system', return_value='Linux'), patch.object(lab, 'flutter_guard'), \
                 patch.object(lab, 'source_snapshot', return_value=source), \
                 patch.object(lab, 'linux_build_preflight'), patch.object(lab, 'flutter_toolchain', return_value=TOOLCHAIN), \
                 patch.object(lab.subprocess, 'run', side_effect=compiler), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(lab.build(args), 0)
            receipt = json.loads((args.out / 'build-receipt.json').read_text())
            self.assertEqual(receipt['source'], receipt['sourceAfter'])
            self.assertEqual(receipt['artifact'], lab.artifact_snapshot(args.out / 'bundle'))
            self.assertEqual(receipt['toolchain'], TOOLCHAIN)

    def test_source_changes_during_build_are_recorded_as_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / 'failed'
            args = argparse.Namespace(out=out, identity_suffix='.m7old', themes='brutal-light', scenarios='keyboard',
                                      seconds=8, rounds=3, semantics='platform', no_trace=False)
            with patch.object(lab.platform, 'system', return_value='Linux'), patch.object(lab, 'flutter_guard'), \
                 patch.object(lab, 'source_snapshot', side_effect=[{'digest': 'a'}, {'digest': 'b'}]), \
                 patch.object(lab, 'linux_build_preflight'), patch.object(lab, 'flutter_toolchain', return_value=TOOLCHAIN), \
                 patch.object(lab.subprocess, 'run', return_value=argparse.Namespace(returncode=1)), \
                 contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(lab.build(args), 1)
            receipt = json.loads((out / 'build-receipt.json').read_text())
            self.assertEqual(receipt['error'], 'Source changed during the build.')
            self.assertTrue((out / 'build.log').exists())

    def test_poisoned_cmake_cache_is_rejected_before_any_compiler_runs(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            app = root / 'app'
            media = root / '.local/media-linux/bundle/libs/libmpv.so.2'
            media.parent.mkdir(parents=True)
            media.write_bytes(b'prepared fixture')
            cache = app / 'build/linux/x64/profile/CMakeCache.txt'
            cache.parent.mkdir(parents=True)
            cache.write_text('CMAKE_INSTALL_PREFIX:PATH=/usr/local\n')
            args = argparse.Namespace(out=root / 'failed', identity_suffix='.m7old', themes='brutal-light',
                                      scenarios='keyboard', seconds=8, rounds=3, semantics='platform', no_trace=False)
            with patch.object(lab, 'ROOT', root), patch.object(lab, 'APP', app), \
                 patch.object(lab.platform, 'system', return_value='Linux'), patch.object(lab, 'flutter_guard'), \
                 patch.object(lab, 'source_snapshot', return_value={'digest': 'a'}), \
                 patch.object(lab, 'flutter_toolchain', return_value=TOOLCHAIN), \
                 patch.object(lab.subprocess, 'run') as compiler, contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(lab.build(args), 1)
                compiler.assert_not_called()
            receipt = json.loads((args.out / 'build-receipt.json').read_text())
            self.assertIn('Unsafe CMake install prefix', receipt['error'])
            self.assertEqual(cache.read_text(), 'CMAKE_INSTALL_PREFIX:PATH=/usr/local\n')
            self.assertIn('reset this worktree cache', (args.out / 'build.log').read_text())

    def test_missing_media_and_escaped_build_directory_fail_preflight(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            app = root / 'app'
            with patch.object(lab, 'ROOT', root), patch.object(lab, 'APP', app):
                with self.assertRaisesRegex(ValueError, 'media runtime is missing'):
                    lab.linux_build_preflight()
                media = root / '.local/media-linux/bundle/libs/libmpv.so.2'
                media.parent.mkdir(parents=True)
                media.write_bytes(b'fixture')
                (app / 'build').mkdir(parents=True)
                (app / 'build/linux').symlink_to(root / 'elsewhere', target_is_directory=True)
                with self.assertRaisesRegex(ValueError, 'escapes this app directory'):
                    lab.linux_build_preflight()

    def test_explicit_zero_rounds_cannot_fall_back_to_environment(self):
        args = argparse.Namespace(themes='brutal-light', scenarios='keyboard', seconds=8,
                                  semantics='platform', no_trace=False, rounds=0)
        with patch.dict(lab.os.environ, {'RAFT_LAB_ROUNDS': '3'}), self.assertRaises(SystemExit):
            lab.workload_config(args)

    def test_concurrent_run_never_waits_for_quiet_or_retries_a_failed_launch(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / 'run'
            args = argparse.Namespace(out=out, device='linux', flutter_args=['--use-application-binary=/test/raft_flutter'],
                themes='brutal-light', scenarios='keyboard', seconds=8, rounds=3, semantics='platform',
                no_trace=False, reference=None, max_load=None)
            manifest = {'source': {'digest': 'a'}, 'artifact': {'path': '/test', 'digest': 'b'}}

            def failed_start(argv, **kw):
                kw['stdout'].write('Application failed to start\n')
                return argparse.Namespace(returncode=1)

            def summary(path):
                (path / 'summary.md').write_text('No sample, failed launch.')

            with patch.dict(lab.os.environ, {'DISPLAY': ':test'}), patch.object(lab, 'concurrent_run', return_value=True), \
                 patch.object(lab, 'flutter_guard'), patch.object(lab, 'run_manifest', return_value=manifest), \
                 patch.object(lab, 'wait_for_display'), patch.object(lab, 'wait_for_quiet_host') as quiet, \
                 patch.object(lab.time, 'sleep') as sleep, patch.object(lab, 'environment', return_value={'loadavg': [21, 18, 16]}), \
                 patch.object(lab.os, 'getloadavg', return_value=(20, 18, 16)), \
                 patch.object(lab, 'host_cpu_snapshot', return_value={}), \
                 patch.object(lab, 'host_cpu_delta', return_value={'intervalSeconds': 4, 'processes': []}), \
                 patch.object(lab, 'source_snapshot', return_value=manifest['source']), \
                 patch.object(lab, 'artifact_snapshot', return_value=manifest['artifact']), \
                 patch.object(lab.subprocess, 'run', side_effect=failed_start) as launch, \
                 patch.object(lab, 'summarize', side_effect=summary), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(lab.run(args), 1)
                quiet.assert_not_called()
                sleep.assert_not_called()
                self.assertEqual(launch.call_count, 1)
            self.assertTrue((out / 'runner.log').exists())
            self.assertEqual(json.loads((out / 'env.json').read_text())['exitCode'], 1)

    def test_an_unpaired_concurrency_override_is_rejected(self):
        with patch.dict(lab.os.environ, {'RAFT_LAB_ALLOW_CONCURRENT': '1'}, clear=True):
            with self.assertRaises(SystemExit):
                lab.concurrent_run('linux')


class AndroidRunSafetyTest(unittest.TestCase):
    def test_changed_official_app_fails_even_when_metric_comparison_passes(self):
        with tempfile.TemporaryDirectory(prefix='raft-lab-safety-') as directory:
            base = Path(directory)
            original = base / 'profile.apk'
            original.write_bytes(b'original test artifact')
            output = base / 'run'
            args = argparse.Namespace(out=output, device='owned-test-device',
                flutter_args=[f'--use-application-binary={original}'], themes='elegant-light',
                scenarios='steady-scroll', seconds=8, semantics='platform', no_trace=True,
                reference=base / 'reference', max_load=None)
            before = {'version': 4001, 'ceDataInode': '123'}
            after = {'version': 4001, 'ceDataInode': '789'}

            def harness(argv, **kwargs):
                # Simulate a concurrent build replacing the source path. The
                # runner must install its frozen artifact instead.
                original.write_bytes(b'replaced by a different build')
                binary_arg = next(arg for arg in argv if arg.startswith('--use-application-binary='))
                binary = Path(binary_arg.split('=', 1)[1])
                self.assertEqual(binary, (output / 'test-profile.apk').resolve())
                self.assertEqual(binary.read_bytes(), b'original test artifact')
                self.assertIn('--keep-app-running', argv)
                return argparse.Namespace(returncode=0)

            def summary(out):
                (out / 'summary.md').write_text('fake metrics')
                return {}

            with patch.object(lab, 'flutter_guard') as guard, \
                 patch.object(lab, 'protected_state', side_effect=[before, after]), \
                 patch.object(lab, 'environment', return_value={'loadavg': [0, 0, 0]}), \
                 patch.object(lab.os, 'getloadavg', return_value=(0, 0, 0), create=True), \
                 patch.object(lab, 'wait_for_display'), patch.object(lab, 'wait_for_quiet_host'), \
                 patch.object(lab.subprocess, 'run', side_effect=harness), \
                 patch.object(lab, 'summarize', side_effect=summary), \
                 patch.object(lab, 'compare_cmd', return_value=0), \
                 contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(lab.run(args), 1)
            self.assertEqual(guard.call_count, 2)
            env = json.loads((output / 'env.json').read_text())
            self.assertEqual(env['exitCode'], 1)
            self.assertIn('protectedAppError', env)


_MANAGED_LIFETIME_SCRIPT = """
import json,os,signal,subprocess,sys,time
child = subprocess.Popen([sys.executable, '-c',
    'import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); time.sleep(60)'],
    start_new_session=sys.argv[2].startswith('detached'),
    env={k:v for k,v in os.environ.items() if k != 'RAFT_LAB_PROCESS_OWNER'}
        if sys.argv[2].startswith('sanitized') else None)
time.sleep(.1)
# The consumer treats existence as readiness, including on normal leader exit.
# Publish only after close, on the same filesystem, so no partial JSON is visible.
pending = sys.argv[1] + '.partial'
with open(pending, 'w') as stream:
    json.dump({'leader': os.getpid(), 'child': child.pid, 'group': os.getpgrp()}, stream)
os.replace(pending, sys.argv[1])
if sys.argv[2].endswith('interrupt'): time.sleep(60)
"""


@unittest.skipUnless(os.name == 'posix', 'POSIX process lifecycle fixture')
class DetectionReadinessPublicationTest(unittest.TestCase):
    def test_partial_identity_is_not_published_as_ready(self):
        # Pause the exact native fixture midway through json.dump. Readiness
        # must remain absent until a whole identity can be consumed, regardless
        # of host load or whether the managed leader is about to exit.
        held_writer = """
import json,os,sys
_real_dump = json.dump
def held_dump(identity, stream):
    stream.write('{"leader":')
    stream.flush()
    os.write(int(sys.argv[3]), (str(identity['child']) + '\\n').encode())
    os.read(int(sys.argv[4]), 1)
    stream.seek(0)
    stream.truncate()
    _real_dump(identity, stream)
json.dump = held_dump
"""
        for mode in ('interrupt', 'normal', 'detached-interrupt', 'detached-normal',
                     'sanitized-interrupt', 'sanitized-normal'):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as directory:
                state = Path(directory) / 'state.json'
                ready_read, ready_write = os.pipe()
                release_read, release_write = os.pipe()
                process = None
                child = None
                released = False
                try:
                    process = subprocess.Popen([sys.executable, '-c',
                        held_writer + _MANAGED_LIFETIME_SCRIPT,
                        str(state), mode, str(ready_write), str(release_read)],
                        pass_fds=(ready_write, release_read), start_new_session=True,
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    os.close(ready_write)
                    ready_write = None
                    os.close(release_read)
                    release_read = None
                    self.assertTrue(select.select([ready_read], [], [], 5)[0],
                                    'managed fixture never reached the partial-write barrier')
                    identity_bytes = os.read(ready_read, 128)
                    self.assertTrue(identity_bytes.endswith(b'\n'), identity_bytes)
                    child = int(identity_bytes)
                    if state.exists():
                        # On the old fixture this raises the same JSONDecodeError
                        # as the full check, rather than hiding it with retries.
                        json.loads(state.read_text())
                    self.assertFalse(state.exists(), 'partial identity was published')
                    os.write(release_write, b'1')
                    released = True
                    deadline = time.monotonic() + 5
                    while not state.exists() and time.monotonic() < deadline:
                        time.sleep(.01)
                    self.assertTrue(state.exists(), 'complete identity was never published')
                    identity = json.loads(state.read_text())
                    self.assertEqual(identity, {
                        'leader': process.pid, 'child': child, 'group': process.pid})
                    if mode.endswith('normal'):
                        self.assertEqual(process.wait(timeout=5), 0)
                finally:
                    if not released:
                        with contextlib.suppress(BrokenPipeError):
                            os.write(release_write, b'1')
                    if process is not None:
                        with contextlib.suppress(ProcessLookupError):
                            os.killpg(process.pid, signal.SIGKILL)
                        if child is not None:
                            with contextlib.suppress(ProcessLookupError):
                                os.kill(child, signal.SIGKILL)
                        process.wait(timeout=5)
                    for fd in (ready_read, ready_write, release_read, release_write):
                        if fd is not None:
                            os.close(fd)


@unittest.skipUnless(sys.platform.startswith('linux'), 'Linux private display sessions')
class DetectionLifetimeTest(unittest.TestCase):
    def test_collected_scope_disappearing_before_stop_is_checked_as_empty(self):
        process = Mock(pid=123456, returncode=0)
        process.wait.return_value = 0
        process.poll.return_value = 0
        shown = subprocess.CompletedProcess([], 0,
            'LoadState=loaded\nActiveState=active\nControlGroup=/raft-detect-unit-test-absent\n')
        gone = subprocess.CompletedProcess([], 1,
            'LoadState=not-found\nActiveState=inactive\nControlGroup=\n')
        receipts = []
        with patch.object(lab.subprocess, 'Popen', return_value=process), \
             patch.object(lab.subprocess, 'run', side_effect=[shown,
                 subprocess.CompletedProcess([], 5, ''), gone]):
            self.assertEqual(lab.run_owned_process(['true'], process_groups=receipts), 0)
        self.assertEqual(receipts[0]['scopeStopExitCode'], 5)
        self.assertTrue(receipts[0]['cleanupComplete'])
        self.assertEqual(receipts[0]['cgroupPopulatedAfter'], '0')

    def test_system_exit_after_runtime_creation_still_removes_it(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / '.fvmrc').write_text('{"flutter":"test"}')
            bundle = root / 'bundle'
            bundle.mkdir()
            (bundle / 'raft_flutter').write_bytes(b'wrong application identity')
            out = root / 'out'
            args = argparse.Namespace(out=out, device='linux', flutter_args=[],
                detection=True, headless=True, themes='brutal-light', scenarios='steady-scroll',
                seconds=8, rounds=1, semantics='platform', no_trace=True)
            manifest = {'buildReceipt': {'identitySuffix': '.unit_owned'}, 'artifact': {'path': str(bundle)}}
            created = []
            real_mkdtemp = tempfile.mkdtemp

            def create(**kwargs):
                value = real_mkdtemp(**kwargs)
                created.append(Path(value))
                return value

            try:
                with patch.object(lab, 'ROOT', root), patch.object(lab, 'flutter_guard'), \
                     patch.object(lab, 'run_manifest', return_value=manifest), \
                     patch.object(lab, 'environment', return_value={'loadavg': [0, 0, 0]}), \
                     patch.dict(os.environ, {'RAFT_FLUTTER_BIN': sys.executable}), \
                     patch.object(lab.tempfile, 'mkdtemp', side_effect=create):
                    with self.assertRaisesRegex(SystemExit, 'native application identity'):
                        lab.run(args)
                self.assertEqual(len(created), 1)
                self.assertFalse(created[0].exists())
                receipt = json.loads((out / 'env.json').read_text())
                self.assertTrue(receipt['privateRuntimeRemoved'])
                self.assertNotEqual(receipt['exitCode'], 0)
            finally:
                for path in created:
                    if path.exists():
                        lab.cleanup_private_runtime(path)

    def test_owned_group_cleanup_on_interrupt_and_normal_parent_exit(self):
        if not shutil.which('systemd-run'):
            self.skipTest('Linux user systemd is required for the native detection lifecycle test.')
        manager = subprocess.run(['systemctl', '--user', 'show', '--property=Version'],
            capture_output=True, timeout=5)
        if manager.returncode:
            self.skipTest('No reachable user systemd manager; native scope cleanup was not run.')
        # A descendant ignores TERM. Cleanup must escalate for that same group
        # while leaving a separately launched sentinel alive.
        managed = _MANAGED_LIFETIME_SCRIPT
        wrapper = """
import importlib.util,os,subprocess,sys
spec=importlib.util.spec_from_file_location('lab',sys.argv[1])
lab=importlib.util.module_from_spec(spec);spec.loader.exec_module(lab)
raise SystemExit(lab.run_owned_process([sys.executable,'-c',sys.argv[2],sys.argv[3],sys.argv[4]],
    env={**os.environ,'RAFT_LAB_PROCESS_OWNER':sys.argv[3]},
    stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL))
"""

        def running(pid):
            try:
                stat = Path(f'/proc/{pid}/stat').read_text()
                return stat[stat.rfind(')') + 2:].split()[0] != 'Z'
            except FileNotFoundError:
                return False

        for mode in ('interrupt', 'normal', 'detached-interrupt', 'detached-normal',
                     'sanitized-interrupt', 'sanitized-normal'):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as directory:
                state = Path(directory) / 'state.json'
                sentinel = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'], start_new_session=True)
                wrapper_process = subprocess.Popen([sys.executable, '-c', wrapper,
                    str(ROOT / 'tool/performance/lab.py'), managed, str(state), mode],
                    start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
                identity = None
                try:
                    deadline = time.monotonic() + 5
                    while not state.exists() and wrapper_process.poll() is None and time.monotonic() < deadline:
                        time.sleep(.02)
                    self.assertTrue(state.exists(), wrapper_process.communicate(timeout=1)[1].decode()
                                    if wrapper_process.poll() is not None else 'child did not become ready')
                    identity = json.loads(state.read_text())
                    self.assertEqual(identity['leader'], identity['group'])
                    if mode.endswith('interrupt'):
                        wrapper_process.send_signal(signal.SIGINT)
                    wrapper_process.communicate(timeout=8)
                    self.assertEqual(wrapper_process.returncode == 0, mode.endswith('normal'))
                    self.assertIsNone(sentinel.poll())
                    self.assertFalse(running(identity['leader']))
                    self.assertFalse(running(identity['child']))
                finally:
                    if identity:
                        with contextlib.suppress(ProcessLookupError):
                            os.killpg(identity['group'], signal.SIGKILL)
                        with contextlib.suppress(ProcessLookupError):
                            os.kill(identity['child'], signal.SIGKILL)
                    if wrapper_process.poll() is None:
                        os.killpg(wrapper_process.pid, signal.SIGKILL)
                    wrapper_process.communicate(timeout=3)
                    sentinel.terminate()
                    sentinel.wait(timeout=3)


if __name__ == '__main__':
    unittest.main()
