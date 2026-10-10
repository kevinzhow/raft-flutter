#!/usr/bin/env python3
"""Gate real uninstrumented P01 samples; an invalid or incomplete run fails."""
import argparse
import json
import math
from pathlib import Path

THEMES = {'brutal-light', 'elegant-light', 'elegant-dark'}
ACTIONS = {'channel-scroll', 'context-scroll', 'native-resize'}

def percentile(values, quantile):
    values = sorted(values)
    return values[math.ceil((len(values)-1)*quantile)]

def assess(samples, reference=None):
    failures=[]; metrics=[]
    def invalid(message):return {'passed':False,'failures':[message],'metrics':[]}
    if not isinstance(samples,list):return invalid('Samples must be a list')
    if any(not isinstance(s,dict) or not {'theme','action','frames','actionElapsedSeconds','cpuPercentOneCore','startOffset','endOffset','mountedBefore','mountedAfter','rssBytes'}.issubset(s) for s in samples):
        return invalid('Missing required raw sample fields')
    if reference is not None:
        if not isinstance(reference,list) or len(reference)!=9:return invalid('Reference must contain all nine raw samples')
        if {(s.get('theme'),s.get('action')) for s in reference if isinstance(s,dict)}!={(t,a) for t in THEMES for a in ACTIONS}:
            return invalid('Reference theme/action coverage differs')
        if any(not isinstance(s.get('frames'),list) or not s['frames'] for s in reference):return invalid('Reference frames cannot be empty')
        if any(not isinstance(f,dict) or any(not isinstance(f.get(k),(int,float)) or not math.isfinite(f[k]) or f[k]<0 for k in ['buildStartUs','buildUs','rasterUs']) for s in reference for f in s['frames']):return invalid('Reference contains invalid raw FrameTiming values')
    if reference is not None and not assess(reference)['passed']:
        return invalid('Reference must itself pass every actual profile measurement gate')
    keys=[(s['theme'],s['action']) for s in samples]
    if set(keys)!={(t,a) for t in THEMES for a in ACTIONS} or len(keys)!=9:
        failures.append('Expected exactly nine distinct theme/action samples')
    previous={} if reference is None else {(s['theme'],s['action']):s for s in reference}
    for s in samples:
        key=(s['theme'],s['action']); frames=s['frames']; label='/'.join(key)
        if any(not isinstance(s.get(k),(int,float)) or not math.isfinite(s[k]) or (s[k]<0 and k not in ['startOffset','endOffset']) for k in ['actionElapsedSeconds','cpuPercentOneCore','displayRefreshRate','rssBytes','startOffset','endOffset']):
            failures.append(label+': finite, nonnegative timing/CPU/display measurements required');continue
        if not isinstance(frames,list) or any(not isinstance(f,dict) or any(not isinstance(f.get(k),(int,float)) or not math.isfinite(f[k]) or f[k]<0 for k in ['buildStartUs','buildUs','rasterUs']) for f in frames):
            failures.append(label+': valid raw FrameTiming records required');continue
        if s.get('frameCount',len(frames))!=len(frames):failures.append(label+': frameCount differs from raw frames')

        if s.get('profile') is not True or s.get('instrumented',False):
            failures.append(label+': profile, uninstrumented samples required')
        duration=s['actionElapsedSeconds']
        if not 9.5<=duration<=15:
            failures.append(label+': action must actually last approximately ten seconds')
        if len(frames)<50:
            failures.append(label+': too few actual engine frames');continue
        frame_span=(frames[-1]['buildStartUs']-frames[0]['buildStartUs'])/1e6
        if frame_span<9:
            failures.append(label+': actual engine frames must span at least nine seconds')
        if s['action'].endswith('scroll') and abs(s['endOffset']-s['startOffset'])<1000:
            failures.append(label+': mounted content did not scroll at least 1000 pixels')
        if s['action']=='native-resize':
            sizes=s.get('nativeSizeChanges',[])
            if not isinstance(sizes,list) or any(not isinstance(v,dict) or any(not isinstance(v.get(k),(int,float)) or not math.isfinite(v[k]) or v[k]<=0 for k in ['width','height']) for v in sizes):
                failures.append(label+': valid native physical dimensions required');continue
            if len(sizes)<10 or len({v['width'] for v in sizes})<6:
                failures.append(label+': actual native engine dimensions did not change')
        row={'theme':s['theme'],'action':s['action'],'frames':len(frames),'frameSpanSeconds':frame_span,'cpuPercentOneCore':s['cpuPercentOneCore'],'mountedBefore':s['mountedBefore'],'mountedAfter':s['mountedAfter'],'rssBytes':s['rssBytes']}
        combined=[f['buildUs']+f['rasterUs'] for f in frames]
        p95=percentile(combined,.95)
        rate=s.get('displayRefreshRate',0)
        if rate<=0:
            failures.append(label+': actual display refresh rate required');rate=60
        budget=8000 if rate>=100 else 16000
        expected=duration*rate
        drop=max(0,1-len(frames)/expected)
        row.update(buildRasterP95Us=p95,displayRefreshRate=rate,expectedVsyncFrames=expected,missedVsyncFraction=drop)
        if p95>=budget:failures.append(f'{label}: build+raster p95 {p95} exceeds {budget}us budget')
        if drop>=.05:failures.append(f'{label}: missed vsync fraction {drop:.3f} exceeds 5%')
        if s['cpuPercentOneCore']>=80:failures.append(f'{label}: CPU must remain below 80% of one core')
        if key in previous:
            base=previous[key]
            if base.get('semanticsEnabled')!=s.get('semanticsEnabled'):failures.append(label+': reference semantics mode differs')
            prior=percentile([f['buildUs']+f['rasterUs'] for f in base['frames']],.95)
            row['referenceBuildRasterP95Us']=prior
            if p95>prior:failures.append(f'{label}: p95 slower than e210562 reference')
        for stage in ['buildUs','rasterUs']:
            row[stage+'P95']=percentile([f[stage] for f in frames],.95)
        metrics.append(row)
    return {'passed':not failures,'failures':failures,'metrics':metrics}

def main():
    parser=argparse.ArgumentParser();parser.add_argument('results',type=Path);parser.add_argument('--reference',type=Path);parser.add_argument('--out',type=Path)
    args=parser.parse_args()
    output=assess(json.loads(args.results.read_text()),None if args.reference is None else json.loads(args.reference.read_text()))
    data=json.dumps(output,ensure_ascii=False,indent=2)
    if args.out:args.out.write_text(data+'\n')
    print(data)
    return 0 if output['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
