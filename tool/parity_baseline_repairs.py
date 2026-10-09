"""Owner-authorized visual fixture repairs; no reference product edits."""
import hashlib
import json
from pathlib import Path
import shutil


def prepare_cases(root, source, out, source_commit):
    repair = repair_definition(root)
    original = (Path(source) / 'packages/web/visual-testing/VisualTestingCases.tsx').read_text()
    generated = repair_cases(original, repair, source_commit)
    repair['originalCasesSha256'] = hashlib.sha256(original.encode()).hexdigest()
    repair['generatedCasesSha256'] = hashlib.sha256(generated.encode()).hexdigest()
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    (out / 'VisualTestingCases.generated.tsx').write_text(generated)
    (out / 'baseline-repair.json').write_text(json.dumps(repair, ensure_ascii=False, indent=2) + '\n')
    return repair

TASKS_ANCHOR = '''    tasks: [
      { taskNumber: 787 },
      { taskNumber: 31 },
      { taskNumber: 521 },
      { taskNumber: 607 },
      { taskNumber: 606 },
    ] as never,'''


def repair_definition(root):
    path = Path(root) / 'tool/reference-patches/markdown-tasks.json'
    repair = json.loads(path.read_text())
    repair['fixtureSha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
    tasks = repair['tasks']
    if {t['taskNumber'] for t in tasks} != {787, 31, 521, 607, 606} or len(tasks) != 5:
        raise ValueError('markdown task repair must preserve the five referenced numbers')
    required = {'id', 'messageId', 'channelId', 'taskNumber', 'title', 'status', 'createdAt'}
    for task in tasks:
        if not required <= task.keys() or task['status'] not in {'todo', 'in_progress', 'in_review', 'done', 'closed'}:
            raise ValueError('markdown task fixture requires a complete, valid task')
    return repair


def repair_cases(code, repair, source_commit):
    if source_commit != repair['sourceCommit']:
        raise ValueError('markdown task repair is bound to a different reference commit')
    if code.count(TASKS_ANCHOR) != 1:
        raise ValueError('reference task fixture anchor changed; review the repair')
    rows = json.dumps(repair['tasks'], ensure_ascii=False, indent=2)
    return code.replace(TASKS_ANCHOR, '    // Owner-authorized fixture repair: complete shared task states.\n'
                        '    tasks: ' + rows + ' as never,')


def capture_is_current(metadata, repair):
    if not metadata.is_file():
        return False
    recorded = json.loads(metadata.read_text()).get('baselineRepair', {})
    return recorded.get('fixtureSha256') == repair['fixtureSha256'] and recorded.get('renderVerified') is True


def preserve_capture(react_dir, history_dir, case_id):
    image = Path(react_dir) / f'{case_id}.png'
    if not image.is_file():
        return None
    digest = hashlib.sha256(image.read_bytes()).hexdigest()
    archived = Path(history_dir) / case_id / digest
    archived.mkdir(parents=True, exist_ok=True)
    for suffix in ('.png', '.metadata.json'):
        original = Path(react_dir) / f'{case_id}{suffix}'
        target = archived / original.name
        if original.is_file() and not target.exists():
            shutil.copy2(original, target)
    return {'caseId': case_id, 'sha256': digest, 'directory': str(archived)}


def repair_annotations(out, site, repair):
    """Publish original bytes and actual render receipts alongside the result."""
    out, site = Path(out), Path(site)
    notes = {}
    evidence = site / 'reference-repairs'
    evidence.mkdir(parents=True, exist_ok=True)
    (evidence / 'fixture.json').write_text(json.dumps(repair, ensure_ascii=False, indent=2) + '\n')
    for case_id in repair['cases']:
        metadata = out / 'visual-testing-results/react' / f'{case_id}.metadata.json'
        if not capture_is_current(metadata, repair):
            continue
        image = metadata.with_name(f'{case_id}.png')
        if not image.is_file():
            continue
        shutil.copy2(metadata, evidence / metadata.name)
        links = [{'title': '浏览器渲染检查', 'href': f'reference-repairs/{metadata.name}'},
                 {'title': '两端共享测试数据', 'href': 'reference-repairs/fixture.json'}]
        history = out / 'react-baseline-history' / case_id
        for archived in sorted(history.glob('*')):
            original = archived / f'{case_id}.png'
            if not original.is_file():
                continue
            if hashlib.sha256(original.read_bytes()).hexdigest() != archived.name:
                raise ValueError('archived reference image checksum changed')
            relative = Path('reference-history') / case_id / archived.name
            shutil.copytree(archived, site / relative, dirs_exist_ok=True)
            old_metadata = archived / f'{case_id}.metadata.json'
            previous_repair = (json.loads(old_metadata.read_text()).get('baselineRepair', {})
                               if old_metadata.is_file() else {})
            title = ('此前 React 截图（基准修复后）' if previous_repair.get('renderVerified')
                     else '修复前 React 截图')
            links.append({'title': title, 'href': str(relative / original.name)})
        notes[case_id] = {
            'kind': 'repair', 'title': 'React 测试基准已修复',
            'description': '原测试漏了任务状态，导致 Markdown 进入原文回退。现两端使用同一份完整任务数据，浏览器已验证任务标签正常渲染、无回退错误。旧截图保留；当前差异按原阈值重新计算，不自动判 Flutter 通过。',
            'baselineSha256': hashlib.sha256(image.read_bytes()).hexdigest(),
            'links': links,
        }
    (evidence / 'repairs.json').write_text(json.dumps(notes, ensure_ascii=False, indent=2) + '\n')
    return notes


if __name__ == '__main__':
    import argparse
    import subprocess
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--out', required=True)
    args = parser.parse_args()
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=args.source, text=True).strip()
    prepare_cases(args.root, args.source, args.out, commit)
