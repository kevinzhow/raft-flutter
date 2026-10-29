#!/usr/bin/env python3
"""A scriptable org.freedesktop.Notifications server for Linux notification checks.

Run it on a private session bus (never the member's own): it logs every Notify,
CloseNotification and GetCapabilities call as JSON lines and can fire the
ActionInvoked signal a desktop sends when a banner is clicked.

  tool/linux-notify-daemon.py --log notify.jsonl [--no-markup]
  gdbus call --session --dest org.raft.FakeNotifyd --object-path /control \
      --method org.raft.FakeNotifyd.Click <id>

Needs python3-dbus and python3-gi (both stock on Debian/Ubuntu desktops).
"""
import argparse
import json
import sys

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

parser = argparse.ArgumentParser()
parser.add_argument('--log', required=True)
parser.add_argument('--no-markup', action='store_true', help='do not advertise body-markup')
args = parser.parse_args()
dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
names = [dbus.service.BusName('org.freedesktop.Notifications', bus),
         dbus.service.BusName('org.raft.FakeNotifyd', bus)]
log = open(args.log, 'a', buffering=1)


def record(kind, **fields):
    log.write(json.dumps(dict(kind=kind, **fields), default=str, ensure_ascii=False) + '\n')


def plain(value):
    if isinstance(value, dbus.Dictionary):
        return {str(k): plain(v) for k, v in value.items()}
    if isinstance(value, (dbus.Array, list, tuple)):
        return [plain(v) for v in value]
    if isinstance(value, (dbus.Byte, dbus.Int32, dbus.UInt32, dbus.Int64, dbus.UInt64)):
        return int(value)
    if isinstance(value, dbus.Boolean):
        return bool(value)
    if isinstance(value, dbus.String):
        return str(value)
    if isinstance(value, dbus.Struct):
        return [plain(v) for v in value]
    return str(value)


class Notifications(dbus.service.Object):
    def __init__(self):
        super().__init__(bus, '/org/freedesktop/Notifications')
        self.next = 1

    @dbus.service.method('org.freedesktop.Notifications', out_signature='as')
    def GetCapabilities(self):
        caps = ['body', 'actions', 'persistence', 'icon-static']
        if not args.no_markup:
            caps += ['body-markup', 'body-hyperlinks']
        record('GetCapabilities', capabilities=caps)
        return caps

    @dbus.service.method('org.freedesktop.Notifications', in_signature='susssasa{sv}i', out_signature='u')
    def Notify(self, app_name, replaces_id, app_icon, summary, body, actions, hints, timeout):
        replaces_id = int(replaces_id)
        ident = replaces_id if replaces_id else self.next
        if not replaces_id:
            self.next += 1
        record('Notify', id=ident, replaces_id=replaces_id, app_name=str(app_name),
               app_icon=str(app_icon), summary=str(summary), body=str(body),
               actions=plain(actions),
               hints={k: v for k, v in plain(hints).items() if k != 'image-data'},
               timeout=int(timeout))
        return dbus.UInt32(ident)

    @dbus.service.method('org.freedesktop.Notifications', in_signature='u')
    def CloseNotification(self, ident):
        record('CloseNotification', id=int(ident))
        self.NotificationClosed(ident, 3)

    @dbus.service.method('org.freedesktop.Notifications', out_signature='ssss')
    def GetServerInformation(self):
        return 'raft-fake-notifyd', 'raft', '1', '1.2'

    @dbus.service.signal('org.freedesktop.Notifications', signature='uu')
    def NotificationClosed(self, ident, reason):
        pass

    @dbus.service.signal('org.freedesktop.Notifications', signature='us')
    def ActionInvoked(self, ident, key):
        pass

    @dbus.service.signal('org.freedesktop.Notifications', signature='us')
    def ActivationToken(self, ident, token):
        pass


class Control(dbus.service.Object):
    def __init__(self, notifications):
        super().__init__(bus, '/control')
        self.notifications = notifications

    @dbus.service.method('org.raft.FakeNotifyd', in_signature='u')
    def Click(self, ident):
        record('Click', id=int(ident))
        self.notifications.ActionInvoked(ident, 'default')

    @dbus.service.method('org.raft.FakeNotifyd', in_signature='us')
    def ClickWithToken(self, ident, token):
        # A desktop with spec 1.3 sends the focus token just before the click.
        record('ClickWithToken', id=int(ident), token=str(token))
        self.notifications.ActivationToken(ident, token)
        self.notifications.ActionInvoked(ident, 'default')


notifications = Notifications()
Control(notifications)
record('ready')
sys.stdout.write('ready\n')
sys.stdout.flush()
GLib.MainLoop().run()
