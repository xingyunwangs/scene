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
    usleep(450_000)
}

func moveMouse(to point: CGPoint) {
    CGEvent(
        mouseEventSource: nil,
        mouseType: .mouseMoved,
        mouseCursorPosition: point,
        mouseButton: .left
    )!.post(tap: .cghidEventTap)
    usleep(550_000)
}

let display = CGDisplayBounds(CGMainDisplayID())
if CommandLine.arguments.contains("--prepare") {
    moveMouse(to: CGPoint(x: display.midX, y: display.midY))
    exit(0)
}

let original = CGEvent(source: nil)!.location
defer { moveMouse(to: original) }
moveMouse(to: CGPoint(x: display.midX, y: display.midY))

guard shelfCount() == 0 else {
    FileHandle.standardError.write(Data("interaction-smoke: Scene did not start collapsed\n".utf8))
    exit(1)
}
pressOptionB()
guard shelfCount() == 1 else {
    FileHandle.standardError.write(Data("interaction-smoke: Option-B did not reveal Scene\n".utf8))
    exit(1)
}
pressOptionB()
guard shelfCount() == 0 else {
    FileHandle.standardError.write(Data("interaction-smoke: Option-B did not collapse Scene\n".utf8))
    exit(1)
}
moveMouse(to: CGPoint(x: display.minX + 1, y: display.midY))
guard shelfCount() == 1 else {
    FileHandle.standardError.write(Data("interaction-smoke: left edge did not reveal Scene\n".utf8))
    exit(1)
}
moveMouse(to: CGPoint(x: display.midX, y: display.midY))
usleep(1_100_000)
guard shelfCount() == 0 else {
    FileHandle.standardError.write(Data("interaction-smoke: Scene did not leave naturally\n".utf8))
    exit(1)
}
print("INTERACTION VERDICT: PASS")
