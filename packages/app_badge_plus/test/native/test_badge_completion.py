#!/usr/bin/env python3
"""Compile the production Swift plugins against inert system/Flutter fixtures.

No UIApplication, Dock, notification center, device or permission API is used.
The assertions cover the channel reply boundary, not visual OS badge delivery.
"""
import argparse
import json
import pathlib
import os
import subprocess
import sys

FLUTTER = r'''@_exported import Foundation
public typealias FlutterResult = (Any?) -> Void
public let FlutterMethodNotImplemented = "not-implemented"
public protocol FlutterPlugin {}
public final class FlutterMethodCall: NSObject {
  public let method: String
  public let arguments: Any?
  public init(method: String, arguments: Any?) { self.method = method; self.arguments = arguments }
}
public final class FlutterError: NSObject {
  public let code: String
  public let message: String?
  public let details: Any?
  public init(code: String, message: String?, details: Any?) {
    self.code = code; self.message = message; self.details = details
  }
}
public final class FlutterMethodChannel {
  public init(name: String, binaryMessenger: Any) {}
}
public final class FlutterPluginRegistrar {
  MESSENGER
  public func addMethodCallDelegate(_ delegate: Any, channel: FlutterMethodChannel) {}
}
'''
NOTIFICATIONS = r'''@_exported import Foundation
public final class UNUserNotificationCenter {
  public static let shared = UNUserNotificationCenter()
  public static func current() -> UNUserNotificationCenter { shared }
  public var calls: [Int] = []
  public var calledOnMain: [Bool] = []
  public var pending: ((Error?) -> Void)?
  public func setBadgeCount(_ count: Int, withCompletionHandler completionHandler: ((Error?) -> Void)? = nil) {
    calls.append(count); calledOnMain.append(Thread.isMainThread); pending = completionHandler
  }
  public func complete(_ error: Error?) { let reply = pending; pending = nil; reply?(error) }
}
'''
UIKIT = r'''@_exported import Foundation
@_exported import UserNotifications
public final class UIApplication {
  public static let shared = UIApplication()
  public var ignoreWrites = false
  private var value = 0
  public var applicationIconBadgeNumber: Int {
    get { value }
    set { if !ignoreWrites { value = newValue } }
  }
}
'''
COCOA = r'''@_exported import Foundation
public final class NSDockTile {
  public var ignoreWrites = false
  private var value: String?
  public var badgeLabel: String? {
    get { value }
    set { if !ignoreWrites { value = newValue } }
  }
}
public final class NSApplication {
  public static let shared = NSApplication()
  public let dockTile = NSDockTile()
}
'''
COMMON = r'''import Foundation
var failures: [String] = []
var assertions = 0
var skipped: [String] = []
func check(_ condition: @autoclosure () -> Bool, _ label: String) {
  assertions += 1
  if !condition() { failures.append(label) }
}
func drain() { RunLoop.main.run(until: Date().addingTimeInterval(0.03)) }
func report() {
  let data = try! JSONSerialization.data(withJSONObject: ["assertions": assertions, "failures": failures, "skipped": skipped], options: [.sortedKeys])
  print(String(data: data, encoding: .utf8)!)
}
'''
IOS = r'''import Flutter
import UIKit
import UserNotifications
let plugin = AppBadgePlusPlugin()
let center = UNUserNotificationCenter.current()
var replies: [Any?] = []
plugin.handle(FlutterMethodCall(method: "updateBadge", arguments: ["count": 7])) { replies.append($0) }
check(replies.isEmpty, "iOS must not reply before the main-queue setter")
drain()
check(center.calls == [7], "iOS passes the requested count")
check(center.calledOnMain == [true], "iOS setter runs on main")
check(replies.isEmpty, "iOS must await setBadgeCount completion")
let error = NSError(domain: "FixtureBadge", code: 501, userInfo: [NSLocalizedDescriptionKey: "fixture failure", "private": "must not escape"])
DispatchQueue.global().async { center.complete(error) }
drain()
check(replies.count == 1, "iOS replies exactly once on error")
let failure = replies.first as? FlutterError
check(failure?.code == "badge_update_failed", "iOS propagates a FlutterError")
check(failure?.message == "fixture failure", "iOS preserves the system error message")
let details = failure?.details as? [String: Any]
check(details?["code"] as? Int == 501 && details?["domain"] as? String == "FixtureBadge", "iOS preserves error code and domain")
check(details?.count == 2, "iOS excludes arbitrary NSError userInfo")
replies = []
plugin.handle(FlutterMethodCall(method: "updateBadge", arguments: ["count": 0])) {
  check(Thread.isMainThread, "iOS Flutter reply returns on main"); replies.append($0)
}
drain()
check(replies.isEmpty && center.calls == [7, 0], "iOS clearing also awaits completion")
center.complete(nil)
drain()
check(replies.count == 1 && replies[0] == nil, "iOS acknowledges successful completion once")
LEGACY
report()
'''
LEGACY = r'''replies = []
AppBadgePlusPlugin.updateLegacyBadge(3) { replies.append($0) }
check(UIApplication.shared.applicationIconBadgeNumber == 3 && replies.count == 1 && replies[0] == nil, "legacy iOS acknowledges only the applied setter")
UIApplication.shared.ignoreWrites = true
replies = []
AppBadgePlusPlugin.updateLegacyBadge(4) { replies.append($0) }
check(replies.first as? FlutterError != nil, "legacy iOS readback mismatch is an error")
UIApplication.shared.ignoreWrites = false
replies = []
AppBadgePlusPlugin.updateLegacyBadge(0) { replies.append($0) }
check(UIApplication.shared.applicationIconBadgeNumber == 0 && replies.count == 1 && replies[0] == nil, "legacy iOS clearing is checked")
'''
MACOS = r'''import FlutterMacOS
import Cocoa
let plugin = AppBadgePlusPlugin()
let dock = NSApplication.shared.dockTile
var replies: [Any?] = []
plugin.handle(FlutterMethodCall(method: "updateBadge", arguments: ["count": 7])) {
  check(Thread.isMainThread, "macOS reply runs on main")
  check(dock.badgeLabel == "7", "macOS reply follows the actual setter")
  replies.append($0)
}
check(replies.isEmpty && dock.badgeLabel == nil, "macOS must not acknowledge a queued write")
drain()
check(replies.count == 1 && replies[0] == nil, "macOS success replies once")
replies = []
plugin.handle(FlutterMethodCall(method: "updateBadge", arguments: ["count": 0])) { replies.append($0) }
check(replies.isEmpty, "macOS clear must not reply before the setter")
drain()
check(dock.badgeLabel == nil && replies.count == 1 && replies[0] == nil, "macOS clear is applied before success")
dock.ignoreWrites = true
replies = []
plugin.handle(FlutterMethodCall(method: "updateBadge", arguments: ["count": 9])) { replies.append($0) }
drain()
check(replies.count == 1 && replies.first as? FlutterError != nil, "macOS property readback mismatch is an error")
report()
'''


def run(args):
    environment = os.environ.copy()
    if args[0] == "swiftc":
        work = pathlib.Path(args[args.index("-I") + 1])
        temporary = work / "tmp"
        temporary.mkdir(exist_ok=True)
        environment["TMPDIR"] = str(temporary) + "/"
        args = [args[0], "-module-cache-path", str(work / "module-cache"), *args[1:]]
    result = subprocess.run(args, capture_output=True, text=True, env=environment)
    if result.returncode:
        raise RuntimeError("Swift fixture compile/run failed: " + result.stderr)
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline-dir', type=pathlib.Path)
    parser.add_argument('--out', type=pathlib.Path)
    args = parser.parse_args()
    package = pathlib.Path(__file__).resolve().parents[2]
    output = args.out or package / '.dart_tool/native_badge_completion'
    output.mkdir(parents=True, exist_ok=True)
    summary = {'boundary': 'production Swift with inert system/Flutter modules; no OS badge writes', 'platforms': {}}
    for platform in ['ios', 'macos']:
        work = output / platform
        work.mkdir(exist_ok=True)
        modules = {'Flutter': FLUTTER.replace('MESSENGER', 'public func messenger() -> Any { 0 }'), 'UserNotifications': NOTIFICATIONS, 'UIKit': UIKIT} if platform == 'ios' else {'FlutterMacOS': FLUTTER.replace('MESSENGER', 'public var messenger: Any { 0 }'), 'Cocoa': COCOA}
        objects = []
        for module, source in modules.items():
            path = work / (module + '.swift'); path.write_text(source)
            obj = work / (module + '.o'); objects.append(str(obj))
            run(['swiftc', '-emit-module', '-emit-object', '-parse-as-library', '-module-name', module, '-I', str(work), str(path), '-o', str(obj)])
        source = args.baseline_dir / platform / 'AppBadgePlusPlugin.swift' if args.baseline_dir else package / platform / 'app_badge_plus/Source/app_badge_plus/AppBadgePlusPlugin.swift'
        plugin = source.read_text()
        legacy = LEGACY if 'static func updateLegacyBadge(' in plugin else 'skipped.append("legacy helper direct checks: unavailable in baseline")'
        harness = (IOS.replace('LEGACY', legacy) if platform == 'ios' else MACOS)
        main_file = work / 'main.swift'; main_file.write_text(COMMON + harness)
        binary = work / 'badge-completion'
        run(['swiftc', '-I', str(work), str(source), str(main_file), *objects, '-o', str(binary)])
        summary['platforms'][platform] = json.loads(run([str(binary)]))
    summary['assertions'] = sum(v['assertions'] for v in summary['platforms'].values())
    summary['failures'] = sum(len(v['failures']) for v in summary['platforms'].values())
    (output / 'result.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary, indent=2))
    return bool(summary['failures'])


if __name__ == '__main__':
    sys.exit(main())
