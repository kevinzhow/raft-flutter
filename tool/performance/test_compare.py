import copy
import unittest
from compare import assess


def samples():
    return [dict(theme=t, action=a, profile=True, instrumented=False,
                 actionElapsedSeconds=10, cpuPercentOneCore=20, displayRefreshRate=60,
                 mountedBefore=6, mountedAfter=6, rssBytes=10000000,
                 startOffset=20000, endOffset=8000,
                 nativeSizeChanges=[{'width':1100+i, 'height':800} for i in range(20)],
                 frames=[{'buildStartUs':i*16667,'buildUs':2000,'rasterUs':1000} for i in range(600)])
            for t in ['brutal-light','elegant-light','elegant-dark']
            for a in ['channel-scroll','context-scroll','native-resize']]


class ActualSampleGuards(unittest.TestCase):
    def test_complete_real_movement_can_pass(self):
        self.assertTrue(assess(samples())['passed'])

    def test_missing_or_duplicate_samples_cannot_pass(self):
        data=samples();data[-1]=copy.deepcopy(data[0])
        self.assertFalse(assess(data)['passed'])

    def test_stationary_and_no_native_dimensions_cannot_pass(self):
        data=samples();data[0]['endOffset']=data[0]['startOffset'];data[2]['nativeSizeChanges']=[]
        self.assertFalse(assess(data)['passed'])

    def test_trace_debug_or_timing_flush_cannot_pass(self):
        for field,value in [('profile',False),('instrumented',True),('actionElapsedSeconds',14.5)]:
            data=samples();data[0][field]=value
            if field=='actionElapsedSeconds':
                # Flush may make a stopwatch read 10s with only 2s of frames.
                data[0]['frames']=data[0]['frames'][:120]
            self.assertFalse(assess(data)['passed'])

    def test_nonfinite_or_incomplete_reference_cannot_pass(self):
        data=samples();data[0]['cpuPercentOneCore']=float('nan')
        self.assertFalse(assess(data)['passed'])
        self.assertFalse(assess(samples(),samples()[:-1])['passed'])
        data=samples();data[0]['frames'][0]['buildUs']=float('inf')
        self.assertFalse(assess(data)['passed'])

    def test_budget_and_reference_regression_cannot_pass(self):
        data=samples()
        for f in data[0]['frames']:f['buildUs']=17000
        self.assertFalse(assess(data)['passed'])
        data=samples()
        for f in data[0]['frames']:f['buildUs']=4000
        self.assertFalse(assess(data,samples())['passed'])

if __name__=='__main__':unittest.main()
