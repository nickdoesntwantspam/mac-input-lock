#!/usr/bin/env swift

import AppKit

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: create-dmg-background.swift <output.png>\n", stderr)
    exit(1)
}

let size = NSSize(width: 660, height: 420)
let image = NSImage(size: size)
image.lockFocus()

let bounds = NSRect(origin: .zero, size: size)
NSColor(calibratedWhite: 0.94, alpha: 1).setFill()
bounds.fill()

let destination = NSBezierPath(roundedRect: NSRect(x: 415, y: 105, width: 140, height: 160), xRadius: 24, yRadius: 24)
NSColor(calibratedRed: 0.86, green: 0.93, blue: 0.88, alpha: 1).setFill()
destination.fill()
NSColor(calibratedRed: 0.20, green: 0.62, blue: 0.35, alpha: 0.35).setStroke()
destination.lineWidth = 2
destination.stroke()

let titleStyle = NSMutableParagraphStyle()
titleStyle.alignment = .center
let title = NSAttributedString(
    string: "Drag Mac Input Lock to Applications",
    attributes: [
        .font: NSFont.systemFont(ofSize: 24, weight: .semibold),
        .foregroundColor: NSColor(calibratedWhite: 0.16, alpha: 1),
        .paragraphStyle: titleStyle,
    ]
)
title.draw(in: NSRect(x: 50, y: 340, width: 560, height: 36))

let detail = NSAttributedString(
    string: "Then open it from your Applications folder.",
    attributes: [
        .font: NSFont.systemFont(ofSize: 14),
        .foregroundColor: NSColor(calibratedWhite: 0.42, alpha: 1),
        .paragraphStyle: titleStyle,
    ]
)
detail.draw(in: NSRect(x: 50, y: 316, width: 560, height: 24))

let arrowPath = NSBezierPath()
arrowPath.lineWidth = 10
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
arrowPath.move(to: NSPoint(x: 275, y: 185))
arrowPath.line(to: NSPoint(x: 385, y: 185))
arrowPath.move(to: NSPoint(x: 350, y: 220))
arrowPath.line(to: NSPoint(x: 385, y: 185))
arrowPath.line(to: NSPoint(x: 350, y: 150))
NSColor(calibratedRed: 0.20, green: 0.62, blue: 0.35, alpha: 1).setStroke()
arrowPath.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Could not render DMG background.\n", stderr)
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
} catch {
    fputs("Could not write DMG background: \(error)\n", stderr)
    exit(1)
}
