"""Fixture files and the case manifest of the attachment open smoke (tool/attachment-open-smoke/run).

`generate(directory)` writes every attachment kind the app can open (and some it only downloads) under
<directory>/storage and <directory>/thumb, and returns the manifest the fixture server publishes at
`/__manifest` and the integration test reads. Sources are generated with ffmpeg, ImageMagick and Python only
(no private or third-party media); re-running reuses files that are already there.
"""
import csv, io, json, os, shutil, struct, subprocess, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
HEIC_SAMPLE = [
    Path('/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/work/raft-source/packages/server/src/routes/fixtures/preview-sample.heic'),
    Path('/home/kevinzhow/flutter-sdks/3.41.9/engine/src/flutter/testing/resources/grill_chicken.heic'),
]
MB = 1024 * 1024


def run(*cmd, **kw):
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, **kw)


def pdf_bytes(pages=3, pad_to=0):
    """A small valid multi-page PDF; `pad_to` adds an uncompressed comment stream to reach a size."""
    objs = ['<< /Type /Catalog /Pages 2 0 R >>']
    kids = ' '.join(f'{3 + i} 0 R' for i in range(pages))
    objs.append(f'<< /Type /Pages /Kids [{kids}] /Count {pages} >>')
    font = 3 + pages
    for i in range(pages):
        objs.append(f'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 200] /Resources << /Font << /F1 {font} 0 R >> >> /Contents {font + 1 + i} 0 R >>')
    objs.append('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')
    for i in range(pages):
        s = f'BT /F1 20 Tf 25 100 Td (Smoke PDF page {i + 1}) Tj ET'
        objs.append(f'<< /Length {len(s)} >>\nstream\n{s}\nendstream')
    if pad_to:
        objs.append('<< /Length %d >>\nstream\n%s\nendstream' % (pad_to, 'x' * pad_to))
    body = b'%PDF-1.4\n'
    offsets = []
    for i, o in enumerate(objs):
        offsets.append(len(body))
        body += f'{i + 1} 0 obj\n{o}\nendobj\n'.encode()
    xref = len(body)
    body += f'xref\n0 {len(objs) + 1}\n0000000000 65535 f \n'.encode()
    for off in offsets:
        body += f'{off:010d} 00000 n \n'.encode()
    body += f'trailer\n<< /Size {len(objs) + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n'.encode()
    return body


def minimal_docx():
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('[Content_Types].xml', '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>')
        z.writestr('_rels/.rels', '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>')
        z.writestr('word/document.xml', '<?xml version="1.0"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Smoke docx</w:t></w:r></w:p></w:body></w:document>')
    return buf.getvalue()


def minimal_xlsx():
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('[Content_Types].xml', '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>')
        z.writestr('_rels/.rels', '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>')
        z.writestr('xl/workbook.xml', '<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>')
        z.writestr('xl/_rels/workbook.xml.rels', '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>')
        z.writestr('xl/worksheets/sheet1.xml', '<?xml version="1.0"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>name</t></is></c><c r="B1" t="inlineStr"><is><t>qty</t></is></c></row><row r="2"><c r="A2" t="inlineStr"><is><t>apple</t></is></c><c r="B2"><v>3</v></c></row></sheetData></worksheet>')
    return buf.getvalue()


def big_markdown(size):
    out, i = ['# Quarterly report\n\n'], 0
    while sum(map(len, out)) < size:
        i += 1
        out.append(f'## Section {i}\n\nParagraph {i} of the report with some **bold** words and `code`, long enough to look like prose.\n\n- item one of {i}\n- item two of {i}\n\n')
    return ''.join(out)


def huge_log(size):
    out, n, i = [], 0, 0
    while n < size:
        i += 1
        line = f'line {i} of a very long log file with some text\n'
        out.append(line)
        n += len(line)
    return ''.join(out)


def big_csv(size):
    out, n, i = ['id,name,amount\n'], 15, 0
    while n < size:
        i += 1
        line = f'{i},"Name, {i}",{i * 3}\n'
        out.append(line)
        n += len(line)
    return ''.join(out)


HTML_PAGE = '<!doctype html><html><head><meta charset="utf-8"><title>Smoke page</title></head><body><h1 id="smoke-h1">Smoke HTML preview</h1><p>Open, close, open again.</p></body></html>'
SVG = '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240" viewBox="0 0 320 240"><rect width="320" height="240" fill="#2255cc"/><circle cx="160" cy="120" r="70" fill="#ffcc33"/></svg>'
MARKDOWN = '# Smoke markdown\n\n- one\n- two\n\n```dart\nvoid main() {}\n```\n'
CODE_PY = 'def smoke(n):\n    return n * 2\n\nprint(smoke(21))\n'
JSON_DOC = json.dumps({'smoke': True, 'items': [1, 2, 3]}, indent=2)
CJK_MD = '# 季度报告\n\n' + ''.join(f'## 第 {i} 节\n\n这是一段中文内容，包含 **加粗**、`代码` 和 [链接](https://example.invalid/{i})。\n\n- 条目一\n- 条目二\n\n' for i in range(120))
CSV_TEXT = 'name,qty\napple,3\npear,5\n'


def generate(directory: Path):
    directory = Path(directory)
    storage, thumbs = directory / 'storage', directory / 'thumb'
    storage.mkdir(parents=True, exist_ok=True)
    thumbs.mkdir(parents=True, exist_ok=True)

    def make(name, builder, *, thumb=False):
        path = storage / name
        if not path.exists() or path.stat().st_size == 0:
            builder(path)
        return path

    def img(name, fmt_args, size='1600x1200', seed=1):
        def build(path):
            run('convert', '-size', size, f'plasma:fractal', *fmt_args, str(path))
        return make(name, build)

    img('photo.jpg', ['-quality', '85'])
    img('photo.png', [])
    img('photo.webp', ['-quality', '80'])
    make('anim.gif', lambda p: run('convert', '-size', '320x240', '-delay', '20', 'plasma:red-blue', 'plasma:green-yellow', '-loop', '0', str(p)))
    heic = next((s for s in HEIC_SAMPLE if s.exists()), None)
    if heic:
        make('photo.heic', lambda p: shutil.copy(heic, p))
    make('vector.svg', lambda p: p.write_text(SVG))
    for name in ('photo-thumb.webp', 'vector-thumb.webp'):
        t = thumbs / name
        if not t.exists():
            run('convert', '-size', '320x240', 'plasma:fractal', '-quality', '70', str(t))
    # Documents.
    make('doc.pdf', lambda p: p.write_bytes(pdf_bytes(3)))
    make('large.pdf', lambda p: p.write_bytes(pdf_bytes(3, pad_to=30 * MB)))
    make('notes.txt', lambda p: p.write_text('Smoke notes\nsecond line\n'))
    make('readme.md', lambda p: p.write_text(MARKDOWN))
    make('cjk.md', lambda p: p.write_text(CJK_MD))
    make('table.csv', lambda p: p.write_text(CSV_TEXT))
    make('table.xlsx', lambda p: p.write_bytes(minimal_xlsx()))
    make('script.py', lambda p: p.write_text(CODE_PY))
    make('data.json', lambda p: p.write_text(JSON_DOC))
    make('memo.docx', lambda p: p.write_bytes(minimal_docx()))
    # Documents the preview service refuses (HTTP 200 {"status":"unsupported","reason":...}): the app reads them itself.
    make('big.md', lambda p: p.write_text(big_markdown(184 * 1024)))
    make('huge.log', lambda p: p.write_text(huge_log(3 * MB)))
    make('big.csv', lambda p: p.write_text(big_csv(6 * MB)))
    make('big.xlsx', lambda p: p.write_bytes(minimal_xlsx() + b'\0' * (12 * MB)))
    make('page.html', lambda p: p.write_text(HTML_PAGE))
    # Audio.
    def tone(name, codec_args):
        make(name, lambda p: run('ffmpeg', '-y', '-f', 'lavfi', '-i', 'sine=frequency=440:duration=6', *codec_args, str(p)))
    tone('tone.m4a', ['-c:a', 'aac', '-b:a', '64k'])
    tone('tone.mp3', ['-c:a', 'libmp3lame', '-b:a', '64k'])
    tone('tone.wav', ['-c:a', 'pcm_s16le', '-ar', '16000'])
    tone('tone.ogg', ['-c:a', 'libvorbis', '-q:a', '2'])
    # Video (testsrc2: moving bars with a frame counter).
    def video(name, args, duration=6, size='640x360'):
        make(name, lambda p: run('ffmpeg', '-y', '-f', 'lavfi', '-i', f'testsrc2=size={size}:rate=30:duration={duration}',
                                 '-f', 'lavfi', '-i', f'sine=frequency=330:duration={duration}', *args, '-shortest', str(p)))
    video('clip-h264.mp4', ['-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-profile:v', 'main', '-movflags', '+faststart', '-c:a', 'aac'])
    video('clip-hevc.mp4', ['-c:v', 'libx265', '-pix_fmt', 'yuv420p', '-tag:v', 'hvc1', '-movflags', '+faststart', '-c:a', 'aac'], size='1280x720')
    video('clip-vp9.webm', ['-c:v', 'libvpx-vp9', '-b:v', '600k', '-pix_fmt', 'yuv420p', '-c:a', 'libopus'])
    # A >24 MB clip (the inline card prepares its first frame only on the first play).
    video('clip-large.mp4', ['-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-b:v', '22M', '-minrate', '22M', '-maxrate', '22M', '-bufsize', '2M',
                              '-movflags', '+faststart', '-c:a', 'aac'], duration=16, size='1920x1080')
    # Download-only.
    make('archive.zip', lambda p: zipfile.ZipFile(p, 'w').writestr('a.txt', 'smoke'))
    make('blob.bin', lambda p: p.write_bytes(os.urandom(200_000)))
    make('large.zip', lambda p: p.write_bytes(os.urandom(30 * MB)))
    return manifest(directory)


def size(directory, name):
    return (Path(directory) / 'storage' / name).stat().st_size


def manifest(directory):
    directory = Path(directory)
    have = lambda n: (directory / 'storage' / n).exists()
    cases = []

    last = [{}]

    def add(id, file, filename, mime, kind, **extra):
        if not have(file):
            last[0] = {}
            return
        case = dict(id=id, file=file, filename=filename, mime=mime, kind=kind, size=size(directory, file),
                    url='presigned', thumb=None, expireFirst=False)
        case.update(extra)
        cases.append(case)
        last[0] = case

    # ---- images ------------------------------------------------------------
    add('img-jpg', 'photo.jpg', 'photo.jpg', 'image/jpeg', 'image', width=1600, height=1200)
    add('img-png', 'photo.png', 'photo.png', 'image/png', 'image', width=1600, height=1200)
    add('img-webp', 'photo.webp', 'photo.webp', 'image/webp', 'image', width=1600, height=1200)
    add('img-gif', 'anim.gif', 'anim.gif', 'image/gif', 'image', width=320, height=240)
    add('img-heic', 'photo.heic', 'IMG_0001.HEIC', 'image/heic', 'image', width=1600, height=1200)
    add('img-thumb', 'photo.png', 'with-thumb.png', 'image/png', 'image', width=1600, height=1200, thumb='ok', thumbFile='photo-thumb.webp')
    add('img-thumb-missing', 'photo.png', 'thumb-missing.png', 'image/png', 'image', width=1600, height=1200, thumb='missing', thumbFile='photo-thumb.webp')
    add('img-thumb-expired', 'photo.png', 'thumb-expired.png', 'image/png', 'image', width=1600, height=1200, thumb='expired', thumbFile='photo-thumb.webp')
    add('img-expired-url', 'photo.jpg', 'expired-first.jpg', 'image/jpeg', 'image', width=1600, height=1200)
    last[0]['expireFirst'] = True
    add('img-stream', 'photo.jpg', 'streamed.jpg', 'image/jpeg', 'image', width=1600, height=1200)
    last[0]['url'] = 'stream'
    add('img-redirect', 'photo.jpg', 'redirected.jpg', 'image/jpeg', 'image', width=1600, height=1200)
    last[0]['url'] = 'redirect'
    add('svg-thumb', 'vector.svg', 'diagram.svg', 'image/svg+xml', 'svg', width=320, height=240, thumb='ok', thumbFile='vector-thumb.webp')
    add('svg-nothumb', 'vector.svg', 'plain.svg', 'image/svg+xml', 'download')
    # ---- documents ---------------------------------------------------------
    add('pdf', 'doc.pdf', 'report.pdf', 'application/pdf', 'pdf')
    add('pdf-large', 'large.pdf', 'large-report.pdf', 'application/pdf', 'pdf')
    add('pdf-stream', 'doc.pdf', 'streamed.pdf', 'application/pdf', 'pdf')
    last[0]['url'] = 'stream'
    add('pdf-redirect', 'doc.pdf', 'redirected.pdf', 'application/pdf', 'pdf')
    last[0]['url'] = 'redirect'
    add('pdf-expired-url', 'doc.pdf', 'expired-first.pdf', 'application/pdf', 'pdf')
    last[0]['expireFirst'] = True
    add('doc-txt', 'notes.txt', 'notes.txt', 'text/plain', 'document',
        preview={'kind': 'text', 'text': 'Smoke notes\nsecond line\n'})
    add('doc-md', 'readme.md', 'readme.md', 'text/markdown', 'document',
        preview={'kind': 'markdown', 'markdown': MARKDOWN})
    add('doc-md-cjk', 'cjk.md', 'report.md', 'text/markdown', 'document',
        preview={'kind': 'markdown', 'markdown': CJK_MD})
    # Markdown files that exist on a real server (copied into <data>/storage by hand when wanted).
    for n in (1, 2):
        if have(f'real-{n}.md'):
            add(f'doc-md-real-{n}', f'real-{n}.md', 'report.md', 'text/markdown', 'document',
                preview={'kind': 'markdown', 'markdown': (directory / 'storage' / f'real-{n}.md').read_text().strip()})
    add('doc-csv', 'table.csv', 'table.csv', 'text/csv', 'document',
        preview={'kind': 'csv', 'headers': ['name', 'qty'], 'rows': [['apple', '3'], ['pear', '5']], 'rowCount': 2, 'columnCount': 2})
    add('doc-xlsx', 'table.xlsx', 'table.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'document',
        preview={'kind': 'xlsx', 'sheetCount': 1, 'sheets': [{'name': 'Sheet1', 'headers': ['name', 'qty'], 'rows': [['apple', '3']], 'rowCount': 1, 'columnCount': 2}]})
    add('doc-md-too-large', 'big.md', 'big-report.md', 'text/markdown', 'document',
        previewRefusal='too_large', shows='Quarterly report')
    add('doc-log-huge', 'huge.log', 'build.log', 'text/plain', 'document',
        previewRefusal='too_large', shows='line 1 of a very long log file with some text', notice=True)
    add('doc-csv-large', 'big.csv', 'big.csv', 'text/csv', 'document',
        previewRefusal='too_large', shows='Name, 1', notice=True)
    add('doc-xlsx-too-large', 'big.xlsx', 'big.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'document',
        previewRefusal='too_large', panel=True)
    add('doc-code', 'script.py', 'script.py', 'text/x-python', 'document',
        preview={'kind': 'text', 'text': CODE_PY})
    add('doc-json', 'data.json', 'data.json', 'application/json', 'document',
        preview={'kind': 'text', 'text': JSON_DOC})
    add('docx', 'memo.docx', 'memo.docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'download')
    add('html', 'page.html', 'page.html', 'text/html', 'html')
    # ---- audio -------------------------------------------------------------
    add('aud-m4a', 'tone.m4a', 'voice.m4a', 'audio/mp4', 'audio')
    add('aud-mp3', 'tone.mp3', 'song.mp3', 'audio/mpeg', 'audio')
    add('aud-wav', 'tone.wav', 'tone.wav', 'audio/wav', 'audio')
    add('aud-ogg', 'tone.ogg', 'clip.ogg', 'audio/ogg', 'audio')
    add('aud-stream', 'tone.mp3', 'streamed.mp3', 'audio/mpeg', 'audio')
    last[0]['url'] = 'stream'
    # ---- video -------------------------------------------------------------
    add('vid-h264', 'clip-h264.mp4', 'clip-h264.mp4', 'video/mp4', 'video')
    add('vid-hevc', 'clip-hevc.mp4', 'clip-hevc.mp4', 'video/mp4', 'video')
    add('vid-webm', 'clip-vp9.webm', 'clip.webm', 'video/webm', 'video')
    add('vid-large', 'clip-large.mp4', 'big-clip.mp4', 'video/mp4', 'video')
    add('vid-stream', 'clip-h264.mp4', 'streamed.mp4', 'video/mp4', 'video')
    last[0]['url'] = 'stream'
    add('vid-redirect', 'clip-h264.mp4', 'redirected.mp4', 'video/mp4', 'video')
    last[0]['url'] = 'redirect'
    add('vid-expired-url', 'clip-h264.mp4', 'expired-first.mp4', 'video/mp4', 'video')
    last[0]['expireFirst'] = True
    # ---- download only -----------------------------------------------------
    add('zip', 'archive.zip', 'archive.zip', 'application/zip', 'download')
    add('bin', 'blob.bin', 'blob.bin', 'application/octet-stream', 'download')
    add('zip-large', 'large.zip', 'backup.zip', 'application/zip', 'download')
    add('zip-stream', 'archive.zip', 'streamed.zip', 'application/zip', 'download')
    last[0]['url'] = 'stream'
    return {'cases': cases}


if __name__ == '__main__':
    import sys
    print(json.dumps(generate(Path(sys.argv[1])), indent=1))
