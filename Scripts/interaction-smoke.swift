#!/usr/bin/env swift
import CoreGraphics
import Foundation

func shelfCount() -> Int {
    guard let rows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return 0 }
    return rows.filter { row in
        guard (row[kCGWindowOwnerName as String] as? String) == "Scene",
              let bounds = row[kCGWindowBounds as String] as? [String: Any],
              let width = bounds["Width"] as? Int
        else { return false }
        return width > 200
    }.count
}

func pressOptionB() {
    for keyDown in [true, false] {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 11, keyDown: keyDown)!
        event.flags = .maskAlternate
        event.post(tap: .cghidEventTap)
    }
}

func postMouse(to point: CGPoint) {
    CGEvent(
        mouseEventSource: nil,
        mouseType: .mouseMoved,
        mouseCursorPosition: point,
        mouseButton: .left
    )!.post(tap: .cghidEventTap)
}

func waitUntil(_ predicate: () -> Bool, timeout: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
        if predicate() { return true }
        usleep(8_000)
    } while Date() < deadline
    return predicate()
}

let display = CGDisplayBounds(CGMainDisplayID())
let edge = CommandLine.arguments.contains("--edge=right") ? "right" : "left"
if CommandLine.arguments.contains("--prepare") {
    postMouse(to: CGPoint(x: display.midX, y: display.midY))
    usleep(100_000)
    exit(0)
}

let original = CGEvent(source: nil)!.location
defer { postMouse(to: original) }
postMouse(to: CGPoint(x: display.midX, y: display.midY))
usleep(80_000)

guard shelfCount() == 0 else {
    FileHandle.standardError.write(Data("interaction-smoke: Scene did not start collapsed\n".utf8))
    exit(1)
}
pressOptionB()
guard waitUntil({ shelfCount() == 1 }, timeout: 0.25) else {
    FileHandle.standardError.write(Data("interaction-smoke: Option-B did not reveal Scene\n".utf8))
    exit(1)
}
let shortcutHideStarted = Date()
pressOptionB()
guard waitUntil({ shelfCount() == 0 }, timeout: 0.3) else {
    FileHandle.standardError.write(Data("interaction-smoke: Option-B did not collapse Scene\n".utf8))
    exit(1)
}
let shortcutHideMilliseconds = Int(Date().timeIntervalSince(shortcutHideStarted) * 1_000)
let edgeX = edge == "left" ? display.minX + 1 : display.maxX - 1
let revealStarted = Date()
postMouse(to: CGPoint(x: edgeX, y: display.minY + 60))
guard waitUntil({ shelfCount() == 1 }, timeout: 0.25) else {
    FileHandle.standardError.write(Data("interaction-smoke: \(edge) edge did not reveal Scene\n".utf8))
    exit(1)
}
let revealMilliseconds = Int(Date().timeIntervalSince(revealStarted) * 1_000)
usleep(250_000)
guard shelfCount() == 1 else {
    FileHandle.standardError.write(Data("interaction-smoke: Scene flashed instead of remaining available at the edge\n".utf8))
    exit(1)
}
let approachX = edge == "left" ? display.minX + 40 : display.maxX - 40
postMouse(to: CGPoint(x: approachX, y: display.midY))
usleep(80_000)
guard shelfCount() == 1 else {
    FileHandle.standardError.write(Data("interaction-smoke: Scene vanished during the edge-to-shelf approach\n".utf8))
    exit(1)
}
let edgeHideStarted = Date()
postMouse(to: CGPoint(x: display.midX, y: display.midY))
guard waitUntil({ shelfCount() == 0 }, timeout: 0.3) else {
    FileHandle.standardError.write(Data("interaction-smoke: Scene did not leave naturally\n".utf8))
    exit(1)
}
let edgeHideMilliseconds = Int(Date().timeIntervalSince(edgeHideStarted) * 1_000)
print("INTERACTION VERDICT: PASS (\(edge), reveal \(revealMilliseconds) ms, edge hide \(edgeHideMilliseconds) ms, shortcut hide \(shortcutHideMilliseconds) ms)")
