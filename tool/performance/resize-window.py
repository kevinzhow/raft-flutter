#!/usr/bin/env python3
"""Resize only the benchmark's actual X11 GTK window, selected by its PID."""
import ctypes as c
import ctypes.util
import sys
import time
x = c.CDLL(ctypes.util.find_library('X11'))
x.XOpenDisplay.restype = c.c_void_p
x.XOpenDisplay.argtypes = [c.c_char_p]
x.XDefaultRootWindow.restype = c.c_ulong
x.XDefaultRootWindow.argtypes = [c.c_void_p]
x.XInternAtom.restype = c.c_ulong
x.XInternAtom.argtypes = [c.c_void_p, c.c_char_p, c.c_int]
x.XQueryTree.argtypes = [c.c_void_p,c.c_ulong,c.POINTER(c.c_ulong),c.POINTER(c.c_ulong),c.POINTER(c.POINTER(c.c_ulong)),c.POINTER(c.c_uint)]
x.XGetWindowProperty.argtypes = [c.c_void_p,c.c_ulong,c.c_ulong,c.c_long,c.c_long,c.c_int,c.c_ulong,c.POINTER(c.c_ulong),c.POINTER(c.c_int),c.POINTER(c.c_ulong),c.POINTER(c.c_ulong),c.POINTER(c.POINTER(c.c_ubyte))]
x.XResizeWindow.argtypes = [c.c_void_p,c.c_ulong,c.c_uint,c.c_uint]
x.XFlush.argtypes = [c.c_void_p]
x.XFree.argtypes = [c.c_void_p]
x.XCloseDisplay.argtypes = [c.c_void_p]
display=x.XOpenDisplay(None)
if not display: sys.exit('No X11 display for native resize')
atom=x.XInternAtom(display,b'_NET_WM_PID',0)
def own_window(window):
    actual=c.c_ulong(); fmt=c.c_int(); n=c.c_ulong(); left=c.c_ulong(); data=c.POINTER(c.c_ubyte)()
    x.XGetWindowProperty(display,window,atom,0,1,0,0,c.byref(actual),c.byref(fmt),c.byref(n),c.byref(left),c.byref(data))
    match=bool(n.value and fmt.value==32 and c.cast(data,c.POINTER(c.c_ulong))[0]==int(sys.argv[1]))
    if data: x.XFree(data)
    if match: return window
    root=c.c_ulong(); parent=c.c_ulong(); children=c.POINTER(c.c_ulong)(); count=c.c_uint()
    if not x.XQueryTree(display,window,c.byref(root),c.byref(parent),c.byref(children),c.byref(count)): return None
    found=None
    for i in range(count.value):
        found=own_window(children[i])
        if found: break
    if children: x.XFree(children)
    return found
window=own_window(x.XDefaultRootWindow(display))
if not window: sys.exit('Benchmark GTK window PID not found')
x.XResizeWindow(display,window,1280,800)
x.XFlush(display)
start=time.monotonic(); count=0
while time.monotonic()-start<float(sys.argv[2]):
    phase=count%40
    width=1100+int(180*(phase if phase<20 else 40-phase)/20)
    x.XResizeWindow(display,window,width,800+phase%10*4)
    x.XFlush(display); count+=1; time.sleep(.01)
x.XCloseDisplay(display)
print(count)
