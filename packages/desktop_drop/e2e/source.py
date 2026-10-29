#!/usr/bin/env python3
"""Drag source + fake document portal + XTest driver for the desktop_drop E2E.

env: OFFER=uri | portal,uri | uri,portal | portal   (target order the source offers)
     KEY=live | bogus                                (portal key state)
Prints JSON {"retrieve_calls": n, "invalid": n} on exit.
"""
import ctypes, json, os, sys, threading, time
import gi
gi.require_version('Gtk', '3.0'); gi.require_version('Gdk', '3.0')
from gi.repository import Gtk, Gdk, Gio, GLib

OFFER = os.environ.get('OFFER', 'uri').split(',')
KEY = os.environ.get('KEY', 'live')
FILES = '/tmp/desktop_drop_probe/files'
PORTAL_DOC = '/tmp/desktop_drop_probe/portal-doc'
os.makedirs(FILES, exist_ok=True); os.makedirs(PORTAL_DOC, exist_ok=True)
open(f'{FILES}/a.txt', 'w').write('host file')
open(f'{PORTAL_DOC}/a.txt', 'w').write('portal file')
stats = {'retrieve_calls': 0, 'invalid': 0}
live = {'k-live'} if KEY == 'live' else set()

XML = '''<node><interface name="org.freedesktop.portal.FileTransfer">
<method name="RetrieveFiles"><arg type="s" direction="in"/><arg type="a{sv}" direction="in"/><arg type="as" direction="out"/></method>
</interface></node>'''

def on_call(conn, sender, path, iface, method, params, inv):
    stats['retrieve_calls'] += 1
    key = params.unpack()[0]
    if key in live:
        live.discard(key)  # autostop: one shot
        inv.return_value(GLib.Variant('(as)', ([f'{PORTAL_DOC}/a.txt'],)))
    else:
        stats['invalid'] += 1
        inv.return_dbus_error('org.freedesktop.DBus.Error.AccessDenied', 'Invalid transfer')

def on_bus(conn, name):
    node = Gio.DBusNodeInfo.new_for_xml(XML)
    conn.register_object('/org/freedesktop/portal/documents', node.interfaces[0], on_call, None, None)
Gio.bus_own_name(Gio.BusType.SESSION, 'org.freedesktop.portal.Documents', Gio.BusNameOwnerFlags.NONE, on_bus, None, None)

NAMES = {'uri': 'text/uri-list', 'portal': 'application/vnd.portal.filetransfer'}
win = Gtk.Window(title='source'); win.set_default_size(200, 100); win.move(0, 0)
lbl = Gtk.Label(label='drag me'); win.add(lbl)
targets = [Gtk.TargetEntry.new(NAMES[o], 0, i) for i, o in enumerate(OFFER)]
lbl_ev = Gtk.EventBox(); win.remove(lbl); lbl_ev.add(lbl); win.add(lbl_ev)
lbl_ev.drag_source_set(Gdk.ModifierType.BUTTON1_MASK, targets, Gdk.DragAction.COPY)
def get(w, ctx, sel, info, t):
    name = OFFER[info]
    data = f'file://{FILES}/a.txt\r\n' if name == 'uri' else 'k-live'
    sel.set(sel.get_target(), 8, data.encode())
lbl_ev.connect('drag-data-get', get)
done = threading.Event()
lbl_ev.connect('drag-end', lambda *a: GLib.timeout_add(1500, lambda: (Gtk.main_quit(), False)[1]))
win.connect('destroy', Gtk.main_quit)
win.show_all()

X = ctypes.CDLL('libX11.so.6'); T = ctypes.CDLL('libXtst.so.6')
X.XOpenDisplay.restype = ctypes.c_void_p
dpy = X.XOpenDisplay(None)
def mv(x, y): T.XTestFakeMotionEvent(ctypes.c_void_p(dpy), 0, x, y, 0); X.XFlush(ctypes.c_void_p(dpy))
def btn(down): T.XTestFakeButtonEvent(ctypes.c_void_p(dpy), 1, down, 0); X.XFlush(ctypes.c_void_p(dpy))
def drive():
    time.sleep(1.0)
    mv(50, 50); time.sleep(0.2); btn(1); time.sleep(0.2)
    for i in range(1, 41):
        mv(50 + i * 15, 50 + i * 9); time.sleep(0.03)
    time.sleep(0.5); btn(0)
threading.Thread(target=drive, daemon=True).start()
GLib.timeout_add(15000, Gtk.main_quit)
Gtk.main()
print(json.dumps(stats))
