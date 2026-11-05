#!/usr/bin/env python3
"""Exercise the distribution GIO desktop launcher with a harmless executable."""
import ctypes
import ctypes.util
import json
import os
import shlex
import tempfile
import time
from pathlib import Path
import sys


class GError(ctypes.Structure):
    _fields_ = [('domain', ctypes.c_uint), ('code', ctypes.c_int),
                ('message', ctypes.c_char_p)]


def main():
    gio = ctypes.CDLL(ctypes.util.find_library('gio-2.0') or 'libgio-2.0.so.0')
    glib = ctypes.CDLL(ctypes.util.find_library('glib-2.0') or 'libglib-2.0.so.0')
    gobject = ctypes.CDLL(ctypes.util.find_library('gobject-2.0') or 'libgobject-2.0.so.0')
    error_pointer = ctypes.POINTER(GError)
    gio.g_app_info_create_from_commandline.argtypes = [
        ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int, ctypes.POINTER(error_pointer)]
    gio.g_app_info_create_from_commandline.restype = ctypes.c_void_p
    gio.g_app_info_launch.argtypes = [
        ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(error_pointer)]
    gio.g_app_info_launch.restype = ctypes.c_int
    glib.g_error_free.argtypes = [error_pointer]
    gobject.g_object_unref.argtypes = [ctypes.c_void_p]
    keys = ('PATH', 'LD_LIBRARY_PATH', 'GIO_MODULE_DIR',
            'GSETTINGS_SCHEMA_DIR', 'GIO_LAUNCH_DESKTOP', 'GTK_IM_MODULE_FILE', 'GDK_PIXBUF_MODULE_FILE')
    expected = {key: os.environ[key] for key in keys if key in os.environ}
    with tempfile.TemporaryDirectory(prefix='raft-gio-child-check-') as temporary:
        output = Path(temporary) / 'child-environment.json'
        # Only this throwaway child sees/writes the selected environment.
        # No browser, account or user file is opened.
        child_code = ('import json,os; from pathlib import Path; '
                      f'keys={keys!r}; '
                      'value={k:v for k,v in os.environ.items() if k in keys}; '
                      f'path=Path({str(output)!r}); staged=path.with_suffix(".pending"); '
                      'staged.write_text(json.dumps(value)); staged.replace(path)')
        command = shlex.join([sys.executable, '-c', child_code]).encode()
        error = error_pointer()
        info = gio.g_app_info_create_from_commandline(
            command, b'Raft AppImage desktop launcher check', 0,
            ctypes.byref(error))
        try:
            if not info or not gio.g_app_info_launch(info, None, None, ctypes.byref(error)):
                message = error.contents.message.decode() if error else 'Unknown GIO launch failure'
                raise ValueError(message)
            deadline = time.monotonic() + 10
            while not output.exists() and time.monotonic() < deadline:
                time.sleep(0.05)
            if not output.exists() or json.loads(output.read_text()) != expected:
                raise ValueError('Desktop child did not recover the original host environment')
            print('Distribution GIO desktop launcher executed the child with the original host environment')
        finally:
            if info:
                gobject.g_object_unref(info)
            if error:
                glib.g_error_free(error)


if __name__ == '__main__':
    main()
