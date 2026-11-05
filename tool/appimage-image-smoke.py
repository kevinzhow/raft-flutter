#!/usr/bin/env python3
"""Decode a known SVG through the distribution GdkPixbuf SVG module."""
import ctypes
import ctypes.util
import os
from pathlib import Path
import tempfile


class GError(ctypes.Structure):
    _fields_ = [('domain', ctypes.c_uint), ('code', ctypes.c_int),
                ('message', ctypes.c_char_p)]


def main():
    pixbuf = ctypes.CDLL(ctypes.util.find_library('gdk_pixbuf-2.0') or 'libgdk_pixbuf-2.0.so.0')
    glib = ctypes.CDLL(ctypes.util.find_library('glib-2.0') or 'libglib-2.0.so.0')
    gobject = ctypes.CDLL(ctypes.util.find_library('gobject-2.0') or 'libgobject-2.0.so.0')
    error_pointer = ctypes.POINTER(GError)
    pixbuf.gdk_pixbuf_new_from_file.argtypes = [ctypes.c_char_p, ctypes.POINTER(error_pointer)]
    pixbuf.gdk_pixbuf_new_from_file.restype = ctypes.c_void_p
    for name in ('width', 'height', 'rowstride', 'n_channels'):
        function = getattr(pixbuf, 'gdk_pixbuf_get_' + name)
        function.argtypes = [ctypes.c_void_p]
        function.restype = ctypes.c_int
    pixbuf.gdk_pixbuf_get_pixels.argtypes = [ctypes.c_void_p]
    pixbuf.gdk_pixbuf_get_pixels.restype = ctypes.POINTER(ctypes.c_ubyte)
    glib.g_error_free.argtypes = [error_pointer]
    gobject.g_object_unref.argtypes = [ctypes.c_void_p]
    with tempfile.TemporaryDirectory(prefix='raft-native-svg-') as temporary:
        fixture = Path(temporary) / 'blue.svg'
        fixture.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32">'
                           '<rect width="32" height="32" fill="#0000ff"/></svg>')
        error = error_pointer()
        result = pixbuf.gdk_pixbuf_new_from_file(os.fsencode(fixture), ctypes.byref(error))
        try:
            if not result:
                raise ValueError(error.contents.message.decode() if error else 'SVG decode failed')
            width = pixbuf.gdk_pixbuf_get_width(result)
            height = pixbuf.gdk_pixbuf_get_height(result)
            pixels = pixbuf.gdk_pixbuf_get_pixels(result)
            offset = 16 * pixbuf.gdk_pixbuf_get_rowstride(result) + 16 * pixbuf.gdk_pixbuf_get_n_channels(result)
            if (width, height) != (32, 32) or list(pixels[offset:offset + 3]) != [0, 0, 255]:
                raise ValueError('Distribution SVG loader did not decode the expected blue pixels')
            print('Distribution native SVG loader decoded 32x32 and the expected blue pixels')
        finally:
            if result:
                gobject.g_object_unref(result)
            if error:
                glib.g_error_free(error)


if __name__ == '__main__':
    main()
