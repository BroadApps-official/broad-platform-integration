#!/usr/bin/env swift

import AppKit
import ImageIO
import UniformTypeIdentifiers

private enum Palette {
    static let background = NSColor(srgbRed: 0.059, green: 0.09, blue: 0.165, alpha: 1)
    static let panel = NSColor(srgbRed: 0.09, green: 0.14, blue: 0.22, alpha: 1)
    static let text = NSColor(srgbRed: 0.973, green: 0.98, blue: 0.988, alpha: 1)
    static let secondary = NSColor(srgbRed: 0.58, green: 0.64, blue: 0.72, alpha: 1)
    static let core = color(0x3B82F6)
    static let monetization = color(0x10B981)
    static let uiFlows = color(0xEC4899)
    static let app = color(0xF59E0B)
    static let external = color(0x64748B)

    private static func color(_ rgb: Int) -> NSColor {
        NSColor(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

private struct GIFFrame {
    let image: NSImage
    let delay: Double
}

private func roundedRect(
    _ rect: NSRect,
    radius: CGFloat,
    fill: NSColor,
    stroke: NSColor? = nil,
    lineWidth: CGFloat = 1
) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }
}

private func drawText(
    _ value: String,
    in rect: NSRect,
    size: CGFloat,
    color: NSColor,
    weight: NSFont.Weight = .regular,
    alignment: NSTextAlignment = .left
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byTruncatingTail
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    (value as NSString).draw(in: rect, withAttributes: attributes)
}

private func drawArrow(from start: NSPoint, to end: NSPoint) {
    Palette.secondary.setStroke()
    let line = NSBezierPath()
    line.lineWidth = 3
    line.move(to: start)
    line.line(to: NSPoint(x: end.x - 8, y: end.y))
    line.stroke()

    Palette.secondary.setFill()
    let head = NSBezierPath()
    head.move(to: end)
    head.line(to: NSPoint(x: end.x - 10, y: end.y + 7))
    head.line(to: NSPoint(x: end.x - 10, y: end.y - 7))
    head.close()
    head.fill()
}

private func makeImage(
    size: NSSize,
    draw: () -> Void
) -> NSImage {
    let image = NSImage(size: size)
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    draw()
    image.unlockFocus()
    return image
}

private func flowFrames() -> [GIFFrame] {
    let size = NSSize(width: 1_100, height: 280)
    let stages: [(String, String, NSColor)] = [
        ("Launch", "bounded bootstrap", Palette.core),
        ("Onboarding", "1...N • ATT if enabled", Palette.uiFlows),
        ("Paywall", "0...N products", Palette.uiFlows),
        ("Purchase / Restore", "Apple or RU", Palette.monetization),
        ("Entitlement", "authoritative refresh", Palette.monetization),
        ("Main", "verified access", Palette.app)
    ]
    let nodeWidth: CGFloat = 150
    let nodeHeight: CGFloat = 78
    let spacing: CGFloat = 25
    let startX: CGFloat = 37.5
    let nodeY: CGFloat = 94

    return stages.indices.map { activeIndex in
        let image = makeImage(size: size) {
            Palette.background.setFill()
            NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
            drawText(
                "BroadApps full flow",
                in: NSRect(x: 38, y: 224, width: 420, height: 34),
                size: 24,
                color: Palette.text,
                weight: .bold
            )
            drawText(
                "Premium only after a fresh active entitlement",
                in: NSRect(x: 38, y: 198, width: 560, height: 24),
                size: 14,
                color: Palette.secondary
            )

            for index in stages.indices {
                let x = startX + CGFloat(index) * (nodeWidth + spacing)
                if index < stages.count - 1 {
                    drawArrow(
                        from: NSPoint(x: x + nodeWidth + 3, y: nodeY + nodeHeight / 2),
                        to: NSPoint(x: x + nodeWidth + spacing - 4, y: nodeY + nodeHeight / 2)
                    )
                }

                let stage = stages[index]
                let isActive = index == activeIndex
                let isPast = index < activeIndex
                let fill = (isActive || isPast)
                    ? stage.2.withAlphaComponent(isActive ? 1 : 0.48)
                    : Palette.external.withAlphaComponent(0.32)
                let stroke = isActive ? Palette.text : Palette.external.withAlphaComponent(0.45)
                let needsDarkActiveText = isActive
                    && (stage.2 == Palette.app || stage.2 == Palette.monetization)
                let primaryText = needsDarkActiveText
                    ? NSColor.black.withAlphaComponent(0.78)
                    : Palette.text
                let secondaryText = needsDarkActiveText
                    ? NSColor.black.withAlphaComponent(0.66)
                    : Palette.text.withAlphaComponent(0.9)
                let rect = NSRect(x: x, y: nodeY, width: nodeWidth, height: nodeHeight)
                roundedRect(rect, radius: 18, fill: fill, stroke: stroke, lineWidth: isActive ? 3 : 1)
                drawText(
                    stage.0,
                    in: NSRect(x: x + 7, y: nodeY + 43, width: nodeWidth - 14, height: 23),
                    size: stage.0.count > 14 ? 13 : 16,
                    color: primaryText,
                    weight: .bold,
                    alignment: .center
                )
                drawText(
                    stage.1,
                    in: NSRect(x: x + 7, y: nodeY + 16, width: nodeWidth - 14, height: 20),
                    size: 11,
                    color: secondaryText,
                    alignment: .center
                )
            }

            let progressWidth = (size.width - 76) * CGFloat(activeIndex + 1) / CGFloat(stages.count)
            roundedRect(
                NSRect(x: 38, y: 42, width: size.width - 76, height: 8),
                radius: 4,
                fill: Palette.external.withAlphaComponent(0.30)
            )
            roundedRect(
                NSRect(x: 38, y: 42, width: progressWidth, height: 8),
                radius: 4,
                fill: stages[activeIndex].2
            )
        }
        return GIFFrame(image: image, delay: activeIndex == stages.count - 1 ? 1.15 : 0.72)
    }
}

private func adaptivePaywallFrames() -> [GIFFrame] {
    let size = NSSize(width: 900, height: 430)
    let counts = [0, 1, 4, 12]

    return counts.map { count in
        let image = makeImage(size: size) {
            Palette.background.setFill()
            NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
            drawText(
                "Adaptive paywall",
                in: NSRect(x: 36, y: 374, width: 360, height: 34),
                size: 25,
                color: Palette.text,
                weight: .bold
            )
            drawText(
                "Все продукты провайдера остаются видимыми и сохраняют порядок",
                in: NSRect(x: 36, y: 347, width: 500, height: 24),
                size: 14,
                color: Palette.secondary
            )

            let phone = NSRect(x: 88, y: 40, width: 300, height: 286)
            roundedRect(phone, radius: 34, fill: Palette.panel, stroke: Palette.external, lineWidth: 2)
            roundedRect(
                NSRect(x: 198, y: 306, width: 80, height: 6),
                radius: 3,
                fill: Palette.external
            )
            drawText(
                count == 0 ? "Нет доступных тарифов" : "Выберите тариф",
                in: NSRect(x: 114, y: 265, width: 248, height: 28),
                size: 18,
                color: Palette.text,
                weight: .bold,
                alignment: .center
            )

            if count == 0 {
                roundedRect(
                    NSRect(x: 116, y: 142, width: 244, height: 96),
                    radius: 18,
                    fill: Palette.uiFlows.withAlphaComponent(0.12),
                    stroke: Palette.uiFlows.withAlphaComponent(0.45)
                )
                drawText(
                    "пусто • повторить • восстановить • закрыть",
                    in: NSRect(x: 132, y: 177, width: 212, height: 24),
                    size: 12,
                    color: Palette.secondary,
                    alignment: .center
                )
            } else {
                let visibleRows = min(count, 4)
                for row in 0..<visibleRows {
                    let rowY = 229 - CGFloat(row) * 48
                    let selected = row == min(1, visibleRows - 1)
                    roundedRect(
                        NSRect(x: 116, y: rowY, width: 244, height: 40),
                        radius: 12,
                        fill: selected ? Palette.monetization.withAlphaComponent(0.18) : Palette.external.withAlphaComponent(0.24),
                        stroke: selected ? Palette.monetization : nil,
                        lineWidth: 2
                    )
                    drawText(
                        "Продукт \(row + 1)",
                        in: NSRect(x: 130, y: rowY + 11, width: 150, height: 18),
                        size: 12,
                        color: Palette.text,
                        weight: selected ? .bold : .regular
                    )
                    drawText(
                        "цена",
                        in: NSRect(x: 274, y: rowY + 11, width: 70, height: 18),
                        size: 11,
                        color: Palette.secondary,
                        alignment: .right
                    )
                }
                if count > visibleRows {
                    drawText(
                        "+ ещё \(count - visibleRows) при прокрутке",
                        in: NSRect(x: 116, y: 45, width: 244, height: 18),
                        size: 11,
                        color: Palette.secondary,
                        alignment: .center
                    )
                }
            }

            roundedRect(
                NSRect(x: 116, y: 72, width: 244, height: 46),
                radius: 14,
                fill: Palette.uiFlows
            )
            drawText(
                count == 0 ? "ПОВТОРИТЬ" : "ПРОДОЛЖИТЬ",
                in: NSRect(x: 128, y: 87, width: 220, height: 18),
                size: 13,
                color: Palette.text,
                weight: .bold,
                alignment: .center
            )

            drawText(
                "\(count) продуктов",
                in: NSRect(x: 478, y: 274, width: 330, height: 54),
                size: 38,
                color: Palette.uiFlows,
                weight: .bold
            )
            let notes = count == 0
                ? ["safe exit even for hard policy", "no fake product or price", "restore stays available"]
                : ["provider order is unchanged", "duplicate SKU stays a separate row", "sticky CTA never dims"]
            for (index, note) in notes.enumerated() {
                let y = 221 - CGFloat(index) * 48
                Palette.monetization.setFill()
                NSBezierPath(ovalIn: NSRect(x: 482, y: y + 5, width: 10, height: 10)).fill()
                drawText(
                    note,
                    in: NSRect(x: 508, y: y, width: 340, height: 24),
                    size: 15,
                    color: Palette.text
                )
            }
            drawText(
                "No opacity • no scale • no flicker",
                in: NSRect(x: 478, y: 66, width: 350, height: 28),
                size: 16,
                color: Palette.app,
                weight: .bold
            )
        }
        return GIFFrame(image: image, delay: count == counts.last ? 1.2 : 0.85)
    }
}

private func writeGIF(
    _ frames: [GIFFrame],
    to url: URL
) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.gif.identifier as CFString,
        frames.count,
        nil
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }

    CGImageDestinationSetProperties(
        destination,
        [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0
            ]
        ] as CFDictionary
    )

    for frame in frames {
        var proposedRect = NSRect(origin: .zero, size: frame.image.size)
        guard let image = frame.image.cgImage(
            forProposedRect: &proposedRect,
            context: nil,
            hints: nil
        ) else {
            throw CocoaError(.coderInvalidValue)
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: frame.delay,
                    kCGImagePropertyGIFUnclampedDelayTime: frame.delay
                ]
            ] as CFDictionary
        )
    }

    guard CGImageDestinationFinalize(destination) else {
        throw CocoaError(.fileWriteUnknown)
    }
}

private let scriptURL = URL(fileURLWithPath: #filePath)
private let documentationURL = scriptURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
private let outputURL = documentationURL
    .appendingPathComponent("Assets", isDirectory: true)
    .appendingPathComponent("README", isDirectory: true)

try writeGIF(
    flowFrames(),
    to: outputURL.appendingPathComponent("full-flow.gif")
)
try writeGIF(
    adaptivePaywallFrames(),
    to: outputURL.appendingPathComponent("adaptive-paywall.gif")
)
