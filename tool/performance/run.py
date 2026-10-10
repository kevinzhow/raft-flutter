#!/usr/bin/env python3
"""Run P01 on an actual Linux profile engine and retain the first result."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
HARNESS=Path('apps/raft_flutter/integration_test/message_scroll_performance_test.dart')
PROOF_INPUTS={'driverSha256':Path('apps/raft_flutter/test_driver/performance_driver.dart'),'resizerSha256':Path('tool/performance/resize-window.py'),'comparatorSha256':Path('tool/performance/compare.py')}

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def command(args,env=None):return subprocess.check_output(args,cwd=ROOT,env=env,text=True).strip()
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--out',required=True,type=Path);parser.add_argument('--reference',type=Path);parser.add_argument('--only',choices=['brutal-light','elegant-light','elegant-dark']);parser.add_argument('--semantics',action='store_true');parser.add_argument('--trace',action='store_true')
    args=parser.parse_args();out=args.out.resolve()
    if out.exists():parser.error('Use a new output directory; earlier runs must remain unchanged')
    if not os.environ.get('DISPLAY'):parser.error('DISPLAY must identify the actual native X11 display')
    out.mkdir(parents=True)
    env=dict(os.environ,GDK_BACKEND='x11')
    glx=command(['glxinfo','-B'],env)
    # Software rasterisation is useful diagnostically, but cannot stand in for
    # this hardware benchmark in a release acceptance gate.
    if 'Accelerated: yes' not in glx or 'llvmpipe' in glx.lower():
        parser.error('This acceptance benchmark requires hardware accelerated GL')
    cpu=json.loads(command(['lscpu','--json']))['lscpu']
    hardware={'renderer':{line.split(':',1)[0].strip():line.split(':',1)[1].strip() for line in glx.splitlines() if line.strip().startswith(('Vendor:','Device:','Version:','Accelerated:','OpenGL vendor string:','OpenGL renderer string:','OpenGL version string:'))},'cpu':{v['field']:v['data'] for v in cpu if v['field'] not in ['CPU(s) scaling MHz:','CPU MHz:']},'affinity':sorted(os.sched_getaffinity(0)),'flutter':json.loads(command([str(ROOT/'tool/flutter'),'--version','--machine']))}
    (out/'harness.dart').write_bytes((ROOT/HARNESS).read_bytes())
    (out/'host-load-start.txt').write_text(Path('/proc/loadavg').read_text())
    (out/'hardware.json').write_text(json.dumps(hardware,indent=2)+'\n')
    receipt={'format':'raft-native-performance-v1','suite':'integration_test/message_scroll_performance_test.dart','name':'[P01a][P01b][P01c] brutal-light elegant-light elegant-dark profile scrolling and native resize','semanticsEnabled':args.semantics,'diagnosticOnly':bool(args.only or args.trace),'startedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'commit':command(['git','rev-parse','HEAD']),'sourceHash':command([str(ROOT/'tool/source-hash')]),'harnessSha256':sha(ROOT/HARNESS),'profile':True,'instrumented':False,'complete':False}
    receipt.update({key:sha(ROOT/path) for key,path in PROOF_INPUTS.items()})
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    if args.reference:
        old=args.reference.resolve();prior=json.loads((old/'receipt.json').read_text());priorHardware=json.loads((old/'hardware.json').read_text())
        if prior['harnessSha256']!=receipt['harnessSha256'] or priorHardware!=hardware or prior.get('semanticsEnabled')!=args.semantics or any(prior.get(key)!=receipt[key] for key in PROOF_INPUTS):
            parser.error('Reference must use exactly the same harness, Flutter engine, CPU and renderer')
    env.update(RAFT_PERF_OUT=str(out),RAFT_PERF_REVISION=receipt['commit'],RAFT_PERF_RESIZER=str(ROOT/'tool/performance/resize-window.py'),RAFT_PERF_ONLY=args.only or '',RAFT_PERF_SEMANTICS=str(args.semantics).lower(),RAFT_PERF_TRACE=str(args.trace).lower())
    argv=[str(ROOT/'tool/flutter'),'drive','--profile','--driver=test_driver/performance_driver.dart','--target=integration_test/message_scroll_performance_test.dart','-d','linux','--no-pub']
    with (out/'runner.log').open('w') as log:
        status=subprocess.run(argv,cwd=ROOT/'apps/raft_flutter',env=env,stdout=log,stderr=subprocess.STDOUT).returncode
    (out/'host-load-end.txt').write_text(Path('/proc/loadavg').read_text())
    receipt.update(endedAt=datetime.datetime.now(datetime.timezone.utc).isoformat(),nativeExitCode=status,sourceHashAfter=command([str(ROOT/'tool/source-hash')]),complete=True)
    receipt['proofInputsAfter']={key:sha(ROOT/path) for key,path in PROOF_INPUTS.items()}
    receipt['proofInputsUnchanged']=all(receipt[key]==receipt['proofInputsAfter'][key] for key in PROOF_INPUTS)
    receipt['sourceUnchanged']=receipt['sourceHash']==receipt['sourceHashAfter'] and receipt['proofInputsUnchanged']
    compare=[sys.executable,str(ROOT/'tool/performance/compare.py'),str(out/'results.json'),'--out',str(out/'gate.json')]
    if args.reference:compare+=['--reference',str(args.reference.resolve()/'results.json')]
    gate=subprocess.run(compare).returncode if (out/'results.json').is_file() else 1
    receipt['gateExitCode']=gate
    receipt['exitCode']=status
    def artifact(p):return {'path':str(p.relative_to(out)),'sha256':sha(p)}
    receipt['samples']=[artifact(p) for p in sorted(out.glob('*-scroll.json'))]+[artifact(p) for p in sorted(out.glob('*-native-resize.json'))]
    receipt['driverResult']=artifact(out/'driver-result.json') if (out/'driver-result.json').is_file() else None
    receipt['gateResult']=artifact(out/'gate.json') if (out/'gate.json').is_file() else None
    response=json.loads((out/'driver-result.json').read_text()) if (out/'driver-result.json').is_file() else {}
    receipt['driverAllTestsPassed']=response.get('result')=='true'
    receipt['reference']=str(args.reference.resolve()) if args.reference else None
    receipt['completed']=len(receipt['samples'])==9 and receipt['driverResult'] is not None and receipt['gateResult'] is not None
    receipt['passed']=receipt['completed'] and status==0 and gate==0 and receipt['sourceUnchanged'] and receipt['driverAllTestsPassed'] and not receipt['diagnosticOnly'] and bool(args.reference)
    if args.reference:receipt['referenceReceipt']= {'path':str(args.reference.resolve()/'receipt.json'),'sha256':sha(args.reference.resolve()/'receipt.json')}

    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    return 0 if status==0 and gate==0 and receipt['sourceUnchanged'] and receipt['driverAllTestsPassed'] and not receipt['diagnosticOnly'] else 1
if __name__=='__main__':raise SystemExit(main())
