#!/usr/bin/env python3
"""Resize only the benchmark's actual X11 GTK window, selected by its PID."""
import ctypes as c
import ctypes.util
import sys
import json
import os
from pathlib import Path
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
class Attributes(c.Structure):
    _fields_=[('x',c.c_int),('y',c.c_int),('width',c.c_int),('height',c.c_int),('border_width',c.c_int),('depth',c.c_int),('visual',c.c_void_p),('root',c.c_ulong),('window_class',c.c_int),('bit_gravity',c.c_int),('win_gravity',c.c_int),('backing_store',c.c_int),('backing_planes',c.c_ulong),('backing_pixel',c.c_ulong),('save_under',c.c_int),('colormap',c.c_ulong),('map_installed',c.c_int),('map_state',c.c_int),('all_event_masks',c.c_long),('your_event_mask',c.c_long),('do_not_propagate_mask',c.c_long),('override_redirect',c.c_int),('screen',c.c_void_p)]
x.XGetWindowAttributes.argtypes=[c.c_void_p,c.c_ulong,c.POINTER(Attributes)]
display=x.XOpenDisplay(None)
if not display: sys.exit('No X11 display for native resize')
atom=x.XInternAtom(display,b'_NET_WM_PID',0)
def own_window(window):
    actual=c.c_ulong(); fmt=c.c_int(); n=c.c_ulong(); left=c.c_ulong(); data=c.POINTER(c.c_ubyte)()
    x.XGetWindowProperty(display,window,atom,0,1,0,0,c.byref(actual),c.byref(fmt),c.byref(n),c.byref(left),c.byref(data))
    match=bool(n.value and fmt.value==32 and c.cast(data,c.POINTER(c.c_ulong))[0]==int(sys.argv[1]))
    if data: x.XFree(data)
    if match:
        attributes=Attributes()
        x.XGetWindowAttributes(display,window,c.byref(attributes))
        # GTK's invisible group-leader window also advertises this PID. Resize
        # only the mapped, substantial application surface, never that helper.
        if attributes.map_state==2 and attributes.width>200 and attributes.height>200 and not attributes.override_redirect:
            return window
    root=c.c_ulong(); parent=c.c_ulong(); children=c.POINTER(c.c_ulong)(); count=c.c_uint()
    if not x.XQueryTree(display,window,c.byref(root),c.byref(parent),c.byref(children),c.byref(count)): return None
    found=None
    for i in range(count.value):
        found=own_window(children[i])
        if found: break
    if children: x.XFree(children)
    return found
class MessageData(c.Union):
    _fields_=[('b',c.c_char*20),('s',c.c_short*10),('l',c.c_long*5)]
class ClientMessage(c.Structure):
    _fields_=[('type',c.c_int),('serial',c.c_ulong),('send_event',c.c_int),('display',c.c_void_p),('window',c.c_ulong),('message_type',c.c_ulong),('format',c.c_int),('data',MessageData)]
class Event(c.Union):
    _fields_=[('client',ClientMessage),('padding',c.c_long*24)]
x.XSendEvent.argtypes=[c.c_void_p,c.c_ulong,c.c_int,c.c_long,c.POINTER(Event)]
x.XGetAtomName.argtypes=[c.c_void_p,c.c_ulong]
x.XGetAtomName.restype=c.c_void_p
root_window=x.XDefaultRootWindow(display)
def state_names(window):
    actual=c.c_ulong(); fmt=c.c_int(); n=c.c_ulong(); left=c.c_ulong(); data=c.POINTER(c.c_ubyte)()
    x.XGetWindowProperty(display,window,x.XInternAtom(display,b'_NET_WM_STATE',0),0,64,0,0,c.byref(actual),c.byref(fmt),c.byref(n),c.byref(left),c.byref(data))
    names=[]
    if fmt.value==32:
        atoms=c.cast(data,c.POINTER(c.c_ulong))
        for i in range(n.value):
            value=x.XGetAtomName(display,atoms[i])
            if value:
                names.append(c.string_at(value).decode()); x.XFree(value)
    if data: x.XFree(data)
    return names
def send(message, values):
    event=Event(); event.client.type=33; event.client.display=display; event.client.window=window
    event.client.message_type=x.XInternAtom(display,message,0); event.client.format=32
    for i,value in enumerate(values): event.client.data.l[i]=value
    if not x.XSendEvent(display,root_window,0,(1<<20)|(1<<19),c.byref(event)):
        sys.exit('Window manager rejected native resize message')
    x.XFlush(display)
def dimensions():
    a=Attributes(); x.XGetWindowAttributes(display,window,c.byref(a))
    return {'width':a.width,'height':a.height,'mapped':a.map_state==2}
window=own_window(root_window)
if not window: sys.exit('Benchmark GTK window PID not found')
before=state_names(window)
send(b'_NET_WM_STATE',[0,x.XInternAtom(display,b'_NET_WM_STATE_MAXIMIZED_VERT',0),x.XInternAtom(display,b'_NET_WM_STATE_MAXIMIZED_HORZ',0),1,0])
time.sleep(.15)
observations=[]
start=time.monotonic(); count=0
while time.monotonic()-start<float(sys.argv[2]):
    phase=count%40
    width=700+int(240*(phase if phase<20 else 40-phase)/20)
    # Ask the window manager to resize the real top-level client; direct
    # XResizeWindow can be ignored on GNOME-managed maximized windows.
    send(b'_NET_MOVERESIZE_WINDOW',[1|(1<<10)|(1<<11)|(1<<12),0,0,width,550+phase%10*4])
    observations.append({'elapsed':time.monotonic()-start,**dimensions()})
    count+=1; time.sleep(.01)
evidence={'pid':int(sys.argv[1]),'window':window,'stateBefore':before,'stateAfter':state_names(window),'requested':count,'observations':observations}
if os.environ.get('RAFT_PERF_OUT'):
    path=Path(os.environ['RAFT_PERF_OUT'])/f'native-geometry-{time.time_ns()}.json'
    path.write_text(json.dumps(evidence,indent=2)+'\n')
x.XCloseDisplay(display)
print(count)
