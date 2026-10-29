"""Ownership registration and truthful current evidence for tool/ds-audit.

The analyzer supplies identities. This module never resolves Dart by name or
converts static references, case names or historical frames into visual passes.
"""
import hashlib
import importlib.util
import base64
import binascii
import json
import pathlib
import re
import subprocess

HEX = re.compile(r'[0-9a-f]{64}\Z')
ROLES = {'canonical_component', 'internal_wrapper', 'internal_part', 'entry_composition',
         'frozen_legacy', 'preview_fixture', 'proven_unused', 'unresolved'}
APPLICABILITY = {'required', 'not_applicable', 'unknown'}
DELEGATION_REFERENCE_KINDS = {'constructor_call', 'function_call'}
DERIVED_L10N = 'packages/raft_ui/lib/src/l10n/zh_index.g.dart'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def runtime_sources(root):
    """Authored runtime plus tracked local runtime dependencies, no SDK/cache.

    Include new untracked source so a new unregistered widget cannot disappear
    until git add. Paths remain repo-relative and symlinks are rejected.
    """
    names = subprocess.check_output(
        ['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=root,
    ).decode().split('\0')
    files = sorted({n for n in names if n.endswith('.dart') and '/lib/' in n and
                    n.startswith(('apps/', 'packages/', 'third_party/')) and not (
                        n.startswith('third_party/') and pathlib.PurePosixPath(n).parts[2] in
                        {'build', '.dart_tool', 'cache', '.cache', '.local', '.pub-cache'})})
    if (root / DERIVED_L10N).is_file():
        # The normal wrapper creates this ignored data-only input. Bind the
        # actual output and prove it is precisely the existing generator's
        # read-only render, rather than silently dropping ignored runtime code.
        spec = importlib.util.spec_from_file_location('ds_l10n_input', root / 'tool/gen_l10n_index.py')
        generator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(generator)
        output = generator.render(generator.discover((root / DERIVED_L10N).parent))
        if (root / DERIVED_L10N).read_text() != output:
            raise ValueError('generated runtime localization differs from its source generator')
        files = sorted(set(files) | {DERIVED_L10N})
    roots = set()
    for name in files:
        path = root / name
        if path.is_symlink() or not path.resolve().is_relative_to(root.resolve()):
            raise ValueError(f'ownership input leaves the repository: {name}')
        if not path.is_file():
            raise ValueError(f'ownership input is missing: {name}')
        roots.add(name.split('/lib/', 1)[0] + '/lib')
    return files, sorted(roots)


def file_binding(root, name):
    path = root / name
    if pathlib.PurePosixPath(name).is_absolute() or '..' in pathlib.PurePosixPath(name).parts:
        raise ValueError(f'not a repository-relative input: {name}')
    if path.is_symlink() or not path.resolve().is_relative_to(root.resolve()):
        raise ValueError(f'input leaves the repository: {name}')
    data = path.read_bytes()
    return {'file': name, 'bytes': len(data), 'sha256': digest(data)}


def binding_errors(root, rows):
    errors = []
    if not isinstance(rows, list) or not rows:
        return ['missing exact input bindings']
    seen = set()
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get('file'), str):
            errors.append('malformed input binding')
            continue
        name = row['file']
        if name in seen:
            errors.append(f'duplicate input binding: {name}')
        seen.add(name)
        try:
            actual = file_binding(root, name)
        except (OSError, ValueError) as e:
            errors.append(str(e))
            continue
        if type(row.get('bytes')) is not int or row['bytes'] != actual['bytes'] or row.get('sha256') != actual['sha256']:
            errors.append(f'input binding changed: {name}')
    return errors


def _map(value, label, errors):
    if not isinstance(value, dict):
        errors.append(f'{label}: expected an object')
        return {}
    return value


def _reason(row):
    return isinstance(row.get('reason'), str) and bool(row['reason'].strip())


def _decision(row, label, errors):
    if not isinstance(row, dict):
        errors.append(f'{label}: expected a decision object')
        return
    if row.get('applicability') not in APPLICABILITY:
        errors.append(f'{label}: applicability must be required|not_applicable|unknown')
    if not row.get('owner') or row.get('applicability') != 'required' and not _reason(row):
        errors.append(f'{label}: pending/NA decisions need an owner and reason')


def owns_reference(reference, owner, declarations):
    """Follow resolved member/State ownership, never a class-name substring."""
    todo = [reference.get('owner'), reference.get('ownerClass')]
    visited = set()
    while todo:
        identity = todo.pop()
        if identity == owner:
            return True
        if identity in visited or identity not in declarations:
            continue
        visited.add(identity)
        row = declarations[identity]
        todo.extend([row.get('owner'), row.get('stateFor')])
    return False


def reference_proof_errors(proof, commit, version, expected_sources):
    """Verify bundled public Git bytes against the pinned commit, offline.

    Commit/tree payloads are public raw Git-object bodies. Source payloads are
    the bytes actually supplied to the reference runner. A checkout's HEAD is
    neither read nor accepted as evidence that its working files match a pin.
    This is called only for an explicit current claim, never UNKNOWN/history.
    """
    errors = []
    if not isinstance(proof, dict) or not isinstance(proof.get('objects'), dict) or not isinstance(proof.get('sources'), list):
        return ['missing bundled pinned-reference Git proof']
    objects = proof['objects']

    def object_bytes(oid, kind):
        row = objects.get(oid)
        if not isinstance(row, dict) or row.get('type') != kind:
            raise ValueError('missing pinned commit/tree object')
        data = base64.b64decode(row['dataBase64'], validate=True)
        actual = hashlib.sha1(kind.encode() + b' ' + str(len(data)).encode() + b'\0' + data).hexdigest()
        if actual != oid:
            raise ValueError('pinned Git object digest mismatch')
        return data

    def tree_member(oid, name):
        data = object_bytes(oid, 'tree')
        while data:
            at = data.index(b'\0')
            header, target = data[:at], data[at+1:at+21]
            if len(target) != 20:
                raise ValueError('truncated public Git tree')
            mode, filename = header.split(b' ', 1)
            if filename == name.encode():
                return mode, target.hex()
            data = data[at+21:]
        raise ValueError('reference source is absent from pinned Git tree')

    try:
        first = object_bytes(commit, 'commit').split(b'\n', 1)[0]
        if not re.fullmatch(rb'tree [0-9a-f]{40}', first):
            raise ValueError('invalid pinned commit tree')
        root_tree = first[5:].decode()
        sources = proof['sources']
        source_names = [r.get('sourcePath') for r in sources if isinstance(r, dict)]
        if not isinstance(expected_sources, list) or not expected_sources or set(source_names) != set(expected_sources) or len(source_names) != len(set(source_names)):
            raise ValueError('reference source set differs from the registered contract')
        if 'packages/web/package.json' not in source_names:
            raise ValueError('reference proof omits the actual Web package manifest')
        for row in sources:
            name = row['sourcePath']
            parts = pathlib.PurePosixPath(name).parts
            if not parts or name.startswith('/') or '..' in parts or '\\' in name:
                raise ValueError('invalid public reference source path')
            oid = root_tree
            for index, part in enumerate(parts):
                mode, oid = tree_member(oid, part)
                if index < len(parts)-1 and mode != b'40000':
                    raise ValueError('reference path leaves a regular Git tree')
            if mode not in {b'100644', b'100755'}:
                raise ValueError('reference source is not a regular pinned blob')
            data = base64.b64decode(row['dataBase64'], validate=True)
            actual = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
            if actual != oid:
                raise ValueError(f'reference runner source differs from pinned Git object: {name}')
            if name == 'packages/web/package.json':
                package = json.loads(data)
                deps = {**package.get('devDependencies', {}), **package.get('dependencies', {})}
                spec = deps.get('@botiverse/raft-ui') or deps.get('raft-ui')
                actual_version = spec.rsplit('@', 1)[-1] if isinstance(spec, str) and spec.startswith('npm:') else spec
                if actual_version != version:
                    raise ValueError('pinned Web package dependency does not match its declared version')
    except (KeyError, TypeError, ValueError, binascii.Error) as e:
        errors.append(str(e))
    return errors


def current_receipt_errors(root, receipt, requirement, manifest, expected_files=()):
    """Validate an explicit current claim, never historical evidence by default.

    A capture runner must supply an exact execution manifest. The old lifecycle
    guard's lexical case-id matching is insufficient for a current visual claim.
    """
    errors = []
    if requirement.get('applicability') != 'required':
        errors.append('UNKNOWN/NA requirement cannot claim current visual PASS')
    if receipt.get('result') != 'pass':
        errors.append('receipt did not pass')
    for key in ('capturedCommit', 'capturedTree'):
        if not re.fullmatch(r'[0-9a-f]{40}', str(receipt.get(key, ''))):
            errors.append(f'missing full {key}')
    for key in ('inputSHA256', 'referenceSHA256', 'stateAssertionSHA256', 'mountAssertionSHA256'):
        value = receipt.get(key)
        if not isinstance(value, str) or not HEX.fullmatch(value) or value != requirement.get(key):
            errors.append(f'{key} does not match the registered requirement')
    for prefix in ('input', 'reference'):
        rows = receipt.get(prefix + 'Bindings')
        errors += [f'{prefix}: {e}' for e in binding_errors(root, rows)]
        if isinstance(rows, list):
            actual_digest = digest(json.dumps(rows, sort_keys=True, separators=(',', ':')).encode())
            if receipt.get(prefix + 'SHA256') != actual_digest:
                errors.append(f'{prefix}SHA256 is not the digest of its exact bindings')
            expected = requirement.get(prefix + 'Files')
            if not isinstance(expected, list) or not expected or set(expected) != {
                    r.get('file') for r in rows if isinstance(r, dict)}:
                errors.append(f'{prefix} binding closure differs from the registered requirement')
    reference_names = {r.get('file') for r in receipt.get('referenceBindings', []) if isinstance(r, dict)}
    pin_file = 'docs/source-reference.json'
    if pin_file not in reference_names:
        errors.append('current reference is not bound to docs/source-reference.json')
    try:
        pin = json.loads((root / pin_file).read_text())
        if receipt.get('referenceCommit') != pin.get('commit') or receipt.get('referencePackageVersion') != pin.get('raftUiNpmVersion'):
            errors.append('reference commit/package does not match the current pinned Web dependency')
        errors += reference_proof_errors(receipt.get('referenceGitProof'), pin.get('commit'),
                                         pin.get('raftUiNpmVersion'), requirement.get('webSourceFiles'))
    except (OSError, ValueError):
        errors.append('current reference pin is unavailable or invalid')
    if receipt.get('caseId') != requirement.get('caseId') or receipt.get('entryId') != requirement.get('entryId'):
        errors.append('case/real-entry identity does not match the requirement')
    errors += binding_errors(root, receipt.get('sourceBindings'))
    sources = receipt.get('sourceBindings', [])
    source_names = {s.get('file') for s in sources if isinstance(s, dict)} if isinstance(sources, list) else set()
    derived_input_names = {r.get('file') for r in receipt.get('inputBindings', [])
                           if isinstance(r, dict) and r.get('file') == DERIVED_L10N}
    if not set(expected_files).issubset(source_names | derived_input_names):
        errors.append('current source closure omits resolved runtime inputs')
    # Validate the claimed Git identity against the actual same source bytes,
    # rather than accepting any correctly-shaped commit/hash in a receipt.
    if not errors:
        try:
            commit = receipt['capturedCommit']
            tree = subprocess.check_output(['git', 'rev-parse', commit + '^{tree}'], cwd=root, stderr=subprocess.DEVNULL).decode().strip()
            if tree != receipt['capturedTree']:
                errors.append('captured tree does not belong to captured commit')
            raw = subprocess.check_output(['git', 'ls-tree', '-r', '-z', commit], cwd=root)
            blobs = {}
            for item in raw.split(b'\0'):
                if item:
                    metadata, name = item.split(b'\t', 1)
                    blobs[name.decode()] = metadata.split()[2].decode()
            for name in source_names:
                data = (root / name).read_bytes()
                actual = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
                if blobs.get(name) != actual:
                    errors.append(f'captured Git source mismatch: {name}')
        except (KeyError, OSError, ValueError, subprocess.CalledProcessError):
            errors.append('captured Git identity is unavailable or invalid')
    errors += binding_errors(root, receipt.get('artifacts'))
    artifacts = receipt.get('artifacts', [])
    if not isinstance(artifacts, list) or len(artifacts) < 3:
        errors.append('both original frames and execution/state metadata are required')
    cases = manifest.get('cases', []) if isinstance(manifest, dict) else []
    if not isinstance(cases, list):
        cases = []
    matches = [c for c in cases if isinstance(c, dict) and c.get('id') == receipt.get('caseId')]
    if len(matches) != 1:
        errors.append('exact execution manifest case is missing or ambiguous')
    else:
        case = matches[0]
        for key in ('entryId', 'inputSHA256', 'referenceSHA256', 'stateAssertionSHA256', 'mountAssertionSHA256', 'result'):
            if case.get(key) != receipt.get(key):
                errors.append(f'execution manifest {key} mismatch')
        if case.get('artifacts') != artifacts:
            errors.append('execution manifest artifact bindings mismatch')
        for key in ('sourceBindings', 'inputBindings', 'referenceBindings', 'capturedCommit', 'capturedTree', 'referenceCommit', 'referencePackageVersion', 'referenceGitProof'):
            if case.get(key) != receipt.get(key):
                errors.append(f'execution manifest {key} mismatch')
    return errors


def validate(root, registry, ledger, inventory, expected_files, manifest=None):
    """Return independent structural errors and derived pending/history counts."""
    errors = []
    if not isinstance(inventory, dict) or inventory.get('version') != 1:
        return {'errors': ['missing supported resolved ownership inventory'], 'visualPasses': 0}
    coverage = _map(ledger.get('designSystemCoverage'), 'designSystemCoverage', errors)
    unknown = set(coverage) - {'schemaVersion', 'canonicalRegistry', 'declarations', 'entries',
                               'requirements', 'knownStateAtoms', 'stateUses', 'evidence',
                               'currentClaims', 'knownProvenanceDivergences', 'about'}
    if unknown:
        errors.append(f'designSystemCoverage: unknown schema fields {sorted(unknown)}')
    if type(coverage.get('schemaVersion')) is not int or coverage.get('schemaVersion') != 1:
        errors.append('designSystemCoverage.schemaVersion must be integer1')
    if coverage.get('canonicalRegistry') != 'tool/ds-audit-families.json':
        errors.append('coverage must reference the existing canonical registry')
    if set(inventory.get('files', [])) != set(expected_files):
        missing = sorted(set(expected_files) - set(inventory.get('files', [])))
        errors.append(f'resolved runtime file census is incomplete (missing {missing[:8]})')
    families = _map(registry.get('families'), 'families', errors)
    canonical_owners = {}
    for family, raw in families.items():
        if isinstance(raw, dict) and isinstance(raw.get('canonicalBindings'), dict):
            for binding in raw['canonicalBindings'].values():
                if isinstance(binding, dict) and isinstance(binding.get('declarationId'), str):
                    canonical_owners.setdefault(binding['declarationId'], set()).add(family)
    recipes = _map(registry.get('recipes'), 'recipes', errors)
    actual_recipes = _map(inventory.get('recipes'), 'resolved recipes', errors)
    if set(recipes) != set(actual_recipes):
        errors.append(f'recipe registration differs: missing={sorted(set(actual_recipes)-set(recipes))}; obsolete={sorted(set(recipes)-set(actual_recipes))}')
    for name, raw in recipes.items():
        row = _map(raw, f'recipes.{name}', errors)
        family = row.get('family')
        if family is not None and family not in families:
            errors.append(f'recipes.{name}: unknown family {family}')
        if row.get('decision') not in {'existing', 'pending', 'uncertain', 'unresolved'} or not row.get('owner'):
            errors.append(f'recipes.{name}: missing ownership decision')
        if family is None and (row.get('decision') != 'unresolved' or not _reason(row)):
            errors.append(f'recipes.{name}: unresolved ownership needs an explicit owner/reason')
        if name in actual_recipes and row.get('axes') != actual_recipes[name].get('axes'):
            errors.append(f'recipes.{name}: a known variant/axis is not registered')

    declarations = _map(coverage.get('declarations'), 'declarations', errors)
    entries = _map(coverage.get('entries'), 'entries', errors)
    requirements = _map(coverage.get('requirements'), 'requirements', errors)
    actual_declarations = inventory.get('declarations', [])
    if not isinstance(actual_declarations, list):
        errors.append('resolved declaration list is malformed')
        actual_declarations = []
    seen = set()
    for item in actual_declarations:
        if not isinstance(item, dict):
            errors.append('malformed resolved declaration')
            continue
        identity = item.get('id')
        if identity in seen:
            errors.append(f'duplicate resolved declaration: {identity}')
        seen.add(identity)
        if identity not in declarations:
            errors.append(f'unregistered {item.get("kind")}: {identity}')
    resolved_by_id = {d['id']: d for d in actual_declarations if isinstance(d, dict) and isinstance(d.get('id'), str)}
    references = inventory.get('references', [])
    if not isinstance(references, list):
        errors.append('resolved references are malformed')
        references = []
    for identity, raw in declarations.items():
        row = _map(raw, identity, errors)
        if row.get('role') not in ROLES or not row.get('owner'):
            errors.append(f'{identity}: missing role/owner')
        if row.get('pass') is True or row.get('visualStatus') == 'PASS':
            errors.append(f'{identity}: use a validated current claim, never an unqualified visual pass')
        if row.get('role') == 'unresolved' and not _reason(row):
            errors.append(f'{identity}: unresolved mapping needs a reason')
        refs = row.get('familyRefs')
        if not isinstance(refs, list) or any(not isinstance(f, str) or f not in families for f in refs):
            errors.append(f'{identity}: unknown family reference')
            refs = []
        if row.get('role') == 'canonical_component' and (
                identity not in canonical_owners or set(refs) != canonical_owners[identity]):
            errors.append(f'{identity}: this API is not chosen by the canonical registry')
        if row.get('role') in {'internal_wrapper', 'internal_part'}:
            targets = row.get('delegatesTo', [])
            if not targets or not isinstance(targets, list) or any(not isinstance(t, str) or t not in declarations for t in targets):
                errors.append(f'{identity}: internal role needs exact registered owner/delegate identities')
            elif any(t not in canonical_owners or not set(refs) & canonical_owners[t] for t in targets):
                errors.append(f'{identity}: internal role needs its canonical family owner')
            elif row['role'] == 'internal_wrapper' and not all(
                    any(isinstance(r, dict) and r.get('kind') in DELEGATION_REFERENCE_KINDS and
                        r.get('target') == t and owns_reference(r, identity, resolved_by_id)
                        for r in references) for t in targets):
                errors.append(f'{identity}: declared delegation is not resolved')
            elif row['role'] == 'internal_part' and not any(
                    isinstance(r, dict) and r.get('kind') in DELEGATION_REFERENCE_KINDS and
                    r.get('target') == identity and
                    any(owns_reference(r, t, resolved_by_id) for t in targets) for r in references):
                errors.append(f'{identity}: canonical owner does not resolve to this internal part')
            if row['role'] == 'internal_wrapper' and any(
                    isinstance(p, dict) and owns_reference(p, identity, resolved_by_id)
                    for p in inventory.get('paintUses', [])):
                errors.append(f'{identity}: independent paint cannot be declared a thin wrapper')
        if row.get('role') in {'frozen_legacy', 'proven_unused'}:
            if not _reason(row) or not row.get('reviewDecision'):
                errors.append(f'{identity}: legacy/unused classification needs a source-bound review')
            errors += [f'{identity}: {e}' for e in binding_errors(root, row.get('sourceBindings'))]
            if row['role'] == 'proven_unused' and any(isinstance(r, dict) and r.get('target') == identity for r in references):
                errors.append(f'{identity}: resolved references contradict proven_unused')
    for family, row in families.items():
        bindings = _map(row.get('canonicalBindings'), f'{family}.canonicalBindings', errors)
        if set(bindings) != set(row.get('canonical', [])):
            errors.append(f'{family}: canonical bindings must describe the existing canonical list exactly')
        for name, binding in bindings.items():
            identity = binding.get('declarationId') if isinstance(binding, dict) else None
            if identity not in declarations or identity not in seen:
                errors.append(f'{family}.{name}: canonical declaration is not resolved/registered')
            elif resolved_by_id[identity].get('name') != name:
                errors.append(f'{family}.{name}: canonical binding resolves to a different API name')
            if isinstance(binding, dict) and binding.get('role') not in {'public_api', 'placement_part', 'paint_part', 'internal_part'}:
                errors.append(f'{family}.{name}: unknown canonical part role')
    for identity, row in entries.items():
        if not isinstance(row, dict) or not row.get('owner') or row.get('mountStatus') not in {'unresolved', 'source_reviewed', 'observed_in_bound_fixture'}:
            errors.append(f'entry {identity}: missing owner/mount status')
            continue
        for declaration in row.get('declarationRefs', []):
            if declaration not in declarations:
                errors.append(f'entry {identity}: unregistered declaration {declaration}')
        if row.get('mountStatus') == 'unresolved' and not _reason(row):
            errors.append(f'entry {identity}: unresolved mount needs a reason')
    for item in actual_declarations:
        if isinstance(item, dict) and item.get('kind') == 'surface_factory' and not any(
                isinstance(e, dict) and item['id'] in e.get('declarationRefs', []) for e in entries.values()):
            errors.append(f'unregistered surface entry: {item["id"]}')
    for identity, row in requirements.items():
        _decision(row, f'requirement {identity}', errors)
        if not isinstance(row, dict):
            continue
        if row.get('entryId') not in entries:
            errors.append(f'requirement {identity}: unregistered real entry')
        if row.get('applicability') == 'not_applicable':
            errors += [f'requirement {identity}: {e}' for e in binding_errors(root, row.get('sourceBindings'))]

    atoms = _map(coverage.get('knownStateAtoms'), 'knownStateAtoms', errors)
    if atoms != inventory.get('stateAtoms'):
        errors.append('known recipe state atoms changed without a ledger decision')
    states = _map(coverage.get('stateUses'), 'stateUses', errors)
    for state in inventory.get('stateUses', []):
        if state.get('id') not in states:
            errors.append(f'unregistered known state use: {state.get("id")}')
        else:
            _decision(states[state['id']], state['id'], errors)

    evidence = _map(coverage.get('evidence'), 'evidence', errors)
    claims = _map(coverage.get('currentClaims'), 'currentClaims', errors)
    stale = []
    for identity, receipt in evidence.items():
        if not isinstance(receipt, dict) or receipt.get('scope') not in {'historical', 'current'}:
            errors.append(f'evidence {identity}: explicit historical/current scope required')
            continue
        if binding_errors(root, receipt.get('sourceBindings')):
            stale.append(identity)
    accepted = 0
    for requirement_id, receipt_id in claims.items():
        if requirement_id not in requirements or not isinstance(receipt_id, str) or receipt_id not in evidence:
            errors.append(f'current claim {requirement_id}: missing requirement/receipt')
            continue
        receipt = evidence[receipt_id]
        if not isinstance(receipt, dict):
            errors.append(f'current claim {requirement_id}: malformed receipt')
            continue
        if receipt.get('scope') != 'current':
            errors.append(f'current claim {requirement_id}: cannot count historical evidence')
            continue
        if not isinstance(requirements[requirement_id], dict):
            errors.append(f'current claim {requirement_id}: malformed requirement')
            continue
        problems = current_receipt_errors(root, receipt, requirements[requirement_id], manifest, expected_files)
        errors += [f'current claim {requirement_id}: {e}' for e in problems]
        if not problems:
            accepted += 1
    pending = sum(isinstance(declarations.get(i), dict) and declarations[i].get('role') == 'unresolved' for i in seen)
    unreviewed_seeds = sum(isinstance(r, dict) and r.get('role') == 'unresolved' and i not in seen
                          for i, r in declarations.items())
    return {'version': 1, 'errors': errors, 'registeredRecipes': len(recipes),
            'resolvedDeclarations': len(seen), 'unresolvedMappings': pending,
            'unresolvedCensusCandidatesOutsideResolvedInventory': unreviewed_seeds,
            'registeredEntries': len(entries), 'staleHistory': stale,
            'visualPasses': accepted, 'unknownIsNotVisualPass': True}


def check(root, inventory):
    """Read exact current contracts once; called by the existing DS command."""
    registry = json.loads((root / 'tool/ds-audit-families.json').read_text())
    ledger = json.loads((root / 'docs/state-parity.json').read_text())
    files, _ = runtime_sources(root)
    names = subprocess.check_output(
        ['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=root,
    ).decode().split('\0')
    render_inputs = sorted(set(files) | {n for n in names if
        n in {'.fvmrc', 'pubspec.yaml', 'pubspec.lock', 'tool/flutter', 'tool/gen_l10n_index.py'} or
        n.startswith(('apps/', 'packages/', 'third_party/')) and (
            n.endswith('/pubspec.yaml') or '/assets/' in n)})
    # New current acceptance submissions require an exact, local execution
    # manifest. Normal structural checks with no claims need no capture output.
    manifest = None
    claims = ledger.get('designSystemCoverage', {}).get('currentClaims', {})
    if not isinstance(claims, dict):
        claims = {}  # validate reports the schema error; no artifact is needed
    path = root / '.local/design-system-execution.json'
    if claims and path.is_file():
        manifest = json.loads(path.read_text())
    result = validate(root, registry, ledger, inventory, files, manifest)
    for requirement, receipt_id in claims.items():
        if not isinstance(receipt_id, str):
            continue
        receipt = ledger['designSystemCoverage']['evidence'].get(receipt_id, {})
        if not isinstance(receipt, dict):
            continue
        bound = {r.get('file') for r in receipt.get('sourceBindings', []) if isinstance(r, dict)}
        bound |= {r.get('file') for r in receipt.get('inputBindings', []) if isinstance(r, dict) and r.get('file') == DERIVED_L10N}
        if not set(render_inputs).issubset(bound):
            result['errors'].append(f'current claim {requirement}: render assets/dependency/SDK bindings are incomplete')
            result['visualPasses'] = 0
    inputs = [file_binding(root, n) for n in [
        'tool/ds-audit', 'tool/ds_coverage.py', 'tool/ds-audit-families.json',
        'docs/state-parity.json', 'pubspec.lock', 'tool/gen_l10n_index.py',
        'tool/ds_audit/bin/ds_audit.dart', 'tool/ds_audit/lib/ownership_inventory.dart',
    ]]
    result['contractBindings'] = inputs
    result['runtimeInputSHA256'] = digest(json.dumps(
        [file_binding(root, n) for n in files], sort_keys=True).encode())
    return result
