"""Exercise exact production collector functions without launching adb/Flutter."""
import ast, json, pathlib, struct, subprocess, tempfile, unittest, zlib, re
root = pathlib.Path(__file__).resolve().parents[2]
source = ast.parse((root/'tool/native-test').read_text())
selected = ast.Module(body=[n for n in source.body if isinstance(n,ast.FunctionDef) and n.name in {'png_complete','atomic_copy','collect_current_evidence'}],type_ignores=[])
ns = dict(json=json,pathlib=pathlib,struct=struct,subprocess=subprocess,zlib=zlib,re=re)
exec(compile(selected,'tool/native-test','exec'),ns)
collect = ns['collect_current_evidence']
def chunk(kind, body):
    return struct.pack('>I',len(body))+kind+body+struct.pack('>I',zlib.crc32(kind+body)&0xffffffff)
png = b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',1,1,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(b'\0\xff\0\0\xff'))+chunk(b'IEND',b'')
class CollectorTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='raft-collector-')
        self.reports=pathlib.Path(self.temp.name); self.acks=[]
        self.run='2026-10-08T01:00:00.000000Z'; self.sha='a'*64
        self.meta={'runId':self.run,'sourceHash':self.sha,'platform':'android','completed':True,'ignored':'must not be copied'}
        self.files={'native-android-run.json':json.dumps(self.meta).encode(),'native-android-checkpoints.tsv':f'android-new-checkpoint\t2026-10-08T01:00:01.000000Z\t{self.run}\n'.encode(),'android-new-checkpoint.png':png}
    def tearDown(self): self.temp.cleanup()
    def perform(self,read=None):
        return collect(self.reports,self.run,self.sha,read or (lambda name:self.files.get(name,b'')),lambda value:self.acks.append(json.loads(value)) or True)
    def test_complete_copies_all_current_pngs_before_exact_ack(self):
        def ack(value):
            self.assertEqual((self.reports/'android-new-checkpoint.png').read_bytes(),png)
            self.assertEqual((self.reports/'native-android-checkpoints.tsv').read_bytes(),self.files['native-android-checkpoints.tsv'])
            copied=json.loads((self.reports/'native-android-run.json').read_bytes()); self.assertTrue(copied['completed']); self.assertNotIn('ignored',copied)
            self.acks.append(json.loads(value)); return True
        self.assertTrue(collect(self.reports,self.run,self.sha,lambda name:self.files.get(name,b''),ack))
        self.assertEqual(self.acks,[{'runId':self.run,'sourceHash':self.sha,'collected':True}])
    def test_previous_completed_run_never_acknowledges(self):
        self.meta['runId']='2026-10-08T00:00:00.000000Z'; self.files['native-android-run.json']=json.dumps(self.meta).encode()
        self.assertFalse(self.perform()); self.assertFalse(self.acks)
    def test_previous_source_never_acknowledges(self):
        self.meta['sourceHash']='b'*64; self.files['native-android-run.json']=json.dumps(self.meta).encode()
        self.assertFalse(self.perform()); self.assertFalse(self.acks)
    def test_incomplete_run_copies_progress_without_ack(self):
        self.meta['completed']=False; self.files['native-android-run.json']=json.dumps(self.meta).encode()
        self.assertFalse(self.perform()); self.assertFalse(self.acks); self.assertFalse(json.loads((self.reports/'native-android-run.json').read_bytes())['completed'])
    def test_stale_tsv_rejected(self):
        self.files['native-android-checkpoints.tsv']=self.files['native-android-checkpoints.tsv'].replace(self.run.encode(),b'2026-10-08T00:00:00.000000Z')
        self.assertFalse(self.perform()); self.assertFalse(self.acks)
    def test_truncated_png_never_acknowledges(self):
        self.files['android-new-checkpoint.png']=png[:-4]; self.assertFalse(self.perform()); self.assertFalse(self.acks)
    def test_corrupt_crc_never_acknowledges(self):
        self.files['android-new-checkpoint.png']=png[:36]+bytes([png[36]^1])+png[37:]; self.assertFalse(self.perform()); self.assertFalse(self.acks)
    def test_missing_png_never_accepts_stale_local_file(self):
        (self.reports/'android-new-checkpoint.png').write_bytes(png); del self.files['android-new-checkpoint.png']
        self.assertFalse(self.perform()); self.assertFalse(self.acks)
    def test_path_traversal_never_read(self):
        self.files['native-android-checkpoints.tsv']=f'../secret\t2026-10-08T01:00:01.000000Z\t{self.run}\n'.encode(); self.assertFalse(self.perform()); self.assertFalse(self.acks)
    def test_run_change_during_copy_never_acknowledges(self):
        calls=0
        def read(name):
            nonlocal calls
            if name=='native-android-run.json':
                calls+=1
                if calls>1:return b'{}'
            return self.files.get(name,b'')
        self.assertFalse(self.perform(read)); self.assertFalse(self.acks)
    def test_invalid_manifest_shape_never_acknowledges(self):
        self.files['native-android-run.json']=b'[]'; self.assertFalse(self.perform()); self.assertFalse(self.acks)
    def test_empty_completed_manifest_never_acknowledges(self):
        self.files['native-android-checkpoints.tsv']=b''; self.assertFalse(self.perform()); self.assertFalse(self.acks)
if __name__=='__main__': unittest.main()
