"""Attach evidence-bound reference warnings without changing official results."""
import hashlib
import json
import pathlib


def admitted_defects(registry, source_commit, react_dir):
    if registry['sourceCommit'] != source_commit:
        return {}
    accepted = {}
    for case_id, entry in registry['cases'].items():
        image = pathlib.Path(react_dir) / f'{case_id}.png'
        if image.is_file() and hashlib.sha256(image.read_bytes()).hexdigest() == entry['baselineSha256']:
            accepted[case_id] = entry
    return accepted


def annotate_site(site, defects):
    """Annotate the current generated viewer; preserve all metrics and images."""
    if not defects:
        return
    path = pathlib.Path(site) / 'index.html'
    original = path.read_text()
    if 'id="raft-reference-defects"' in original:
        raise ValueError('reference annotations already attached')
    payload = json.dumps(defects, ensure_ascii=False).replace('<', r'\u003c')
    script = '''
<script id="raft-reference-defects">
(function () {
  const defects = DEFECTS;
  const wrapper = document.getElementById('vt-stage-wrap');
  if (!wrapper) return;
  const notice = document.createElement('aside');
  notice.setAttribute('data-reference-note', '');
  notice.setAttribute('role', 'note');
  notice.style.cssText = 'padding:12px;margin-bottom:12px;border:2px solid #a16207;background:#fef3c7;color:#422006;white-space:normal;line-height:1.5';
  wrapper.prepend(notice);
  function update() {
    const id = decodeURIComponent(location.hash.replace(/^#case\\//, ''));
    const defect = defects[id];
    notice.hidden = !defect;
    notice.toggleAttribute('data-reference-repair', defect?.kind === 'repair');
    notice.toggleAttribute('data-reference-defect', !!defect && defect.kind !== 'repair');
    notice.replaceChildren();
    if (!defect) return;
    const title = document.createElement('strong');
    title.textContent = defect.title;
    const description = document.createElement('p');
    description.style.margin = '4px 0 0';
    description.textContent = defect.description;
    notice.append(title, description);
    for (const link of defect.links ?? []) {
      const anchor = document.createElement('a');
      anchor.textContent = link.title;
      anchor.href = link.href;
      anchor.style.marginRight = '16px';
      notice.append(anchor);
    }
  }
  addEventListener('hashchange', update);
  const stage = document.getElementById('vt-stage');
  if (stage) new MutationObserver(update).observe(stage, {childList:true});
  update();
})();
</script>
'''.replace('DEFECTS', payload)
    path.write_text(original.replace('</body>', script + '</body>'))
    (path.parent / 'reference-defects.json').write_text(json.dumps(defects, ensure_ascii=False, indent=2) + '\n')
