"""Fail a Windows bundle whose executables need a DLL the user may not have.

Every .exe/.dll in the staged bundle is read as a PE file. Each DLL it
imports (normal and delay-loaded) must be shipped in the bundle, be part of
Windows 10 1903 or later. Anything
else stops the release: v1.21.23+7 shipped without the MSVC runtime and did
not start on machines without the Visual C++ Redistributable.

Pure Python so the same check runs on the Windows release runner, on the
Linux hosts and in tool/tests.

    python3 tool/windows_dependencies.py <bundle-dir>
"""
from pathlib import Path
import struct
import sys

# DLLs present on every supported Windows (10 1903+, 11). API sets
# (api-ms-win-*, ext-ms-*) are resolved by the loader and accepted by prefix.
SYSTEM = {
    'advapi32.dll', 'avicap32.dll', 'avrt.dll', 'bcrypt.dll', 'cfgmgr32.dll',
    'comctl32.dll', 'comdlg32.dll', 'crypt32.dll', 'd2d1.dll', 'd3d11.dll',
    'd3d12.dll', 'd3d9.dll', 'dbghelp.dll', 'dcomp.dll', 'dwmapi.dll',
    'dwrite.dll', 'dxgi.dll', 'gdi32.dll', 'gdiplus.dll', 'hid.dll',
    'icu.dll',  # Windows 10 1903+
    'imm32.dll', 'iphlpapi.dll', 'kernel32.dll', 'mf.dll', 'mfplat.dll',
    'mfreadwrite.dll', 'msimg32.dll', 'mswsock.dll', 'ncrypt.dll',
    'netapi32.dll', 'ntdll.dll', 'ole32.dll', 'oleacc.dll', 'oleaut32.dll',
    'opengl32.dll', 'powrprof.dll', 'propsys.dll', 'psapi.dll', 'rpcrt4.dll',
    'secur32.dll', 'setupapi.dll', 'shcore.dll', 'shell32.dll', 'shlwapi.dll',
    'ucrtbase.dll', 'uiautomationcore.dll', 'urlmon.dll', 'user32.dll',
    'userenv.dll', 'uxtheme.dll', 'version.dll', 'winhttp.dll', 'wininet.dll',
    'winmm.dll', 'wintrust.dll', 'ws2_32.dll', 'wtsapi32.dll',
}
SYSTEM_PREFIXES = ('api-ms-win-', 'ext-ms-')
UNSUPPORTED_RUNTIME_PREFIX = 'microsoft.windowsappruntime'

# Debug CRTs exist only on machines with Visual Studio and may not be
# redistributed, so a release must never depend on them.
DEBUG_RUNTIMES = {'ucrtbased.dll', 'vcruntime140d.dll', 'vcruntime140_1d.dll',
                  'msvcp140d.dll', 'msvcp140_1d.dll', 'msvcp140_2d.dll',
                  'concrt140d.dll'}


def pe_imports(data):
    """Names of the DLLs a PE image imports, or None if it is not a PE image."""
    if data[:2] != b'MZ' or len(data) < 0x40:
        return None
    header = struct.unpack_from('<I', data, 0x3c)[0]
    if data[header:header + 4] != b'PE\0\0':
        return None
    sections, optional_size = struct.unpack_from('<H', data, header + 6)[0], \
        struct.unpack_from('<H', data, header + 20)[0]
    optional = header + 24
    directories = optional + (112 if struct.unpack_from('<H', data, optional)[0] == 0x20b else 96)
    table = []
    for index in range(sections):
        entry = optional + optional_size + 40 * index
        virtual_size, address, raw_size, raw = struct.unpack_from('<IIII', data, entry + 8)
        table.append((address, max(virtual_size, raw_size), raw))

    def offset(rva):
        for address, size, raw in table:
            if address <= rva < address + size:
                return rva - address + raw
        return None

    names = set()
    # Import directory (20-byte descriptors, name at +12) and delay-load
    # directory (32-byte descriptors, name at +4); both end with a zero entry.
    for directory, size, name_field in ((1, 20, 12), (13, 32, 4)):
        position = offset(struct.unpack_from('<I', data, directories + 8 * directory)[0] or -1)
        while position is not None and position + size <= len(data):
            name = struct.unpack_from('<I', data, position + name_field)[0]
            start = offset(name) if name else None
            if start is None:
                break
            names.add(data[start:data.index(b'\0', start)].decode('ascii', 'replace'))
            position += size
    return names


def audit(bundle):
    """Map each unresolved DLL to (reason, importers). Empty means shippable."""
    bundle = Path(bundle)
    files = [path for path in bundle.rglob('*') if path.is_file()]
    shipped = {path.name.lower() for path in files}
    problems = {}
    for path in files:
        if path.suffix.lower() not in {'.exe', '.dll'}:
            continue
        if path.name.lower().startswith(UNSUPPORTED_RUNTIME_PREFIX):
            problems.setdefault(path.name.lower(), (
                'Windows App Runtime must not be bundled; use system Toast', set()
            ))[1].add(path.relative_to(bundle).as_posix())
        for name in pe_imports(path.read_bytes()) or ():
            key = name.lower()
            if key in DEBUG_RUNTIMES:
                reason = 'debug runtime: never present on user machines'
            elif key.startswith(UNSUPPORTED_RUNTIME_PREFIX):
                reason = 'Windows App Runtime is not a supported dependency; use system Toast'
            elif key in shipped or key in SYSTEM or key.startswith(SYSTEM_PREFIXES):
                continue
            else:
                reason = 'not in the bundle and not part of Windows'
            problems.setdefault(key, (reason, set()))[1].add(path.relative_to(bundle).as_posix())
    return problems


def check(bundle):
    problems = audit(bundle)
    if problems:
        lines = [f'  {name}: {reason} (needed by {", ".join(sorted(users))})'
                 for name, (reason, users) in sorted(problems.items())]
        raise ValueError('Windows bundle has unresolved DLL dependencies:\n' + '\n'.join(lines))


def main(argv):
    if len(argv) != 2:
        print(__doc__.strip().splitlines()[-1].strip(), file=sys.stderr)
        return 2
    try:
        check(argv[1])
    except ValueError as error:
        print(error, file=sys.stderr)
        return 1
    print(f'{argv[1]}: every imported DLL is shipped or part of Windows')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
