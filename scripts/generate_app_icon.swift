import AppKit

struct IconImage {
    let filename: String
    let pixels: Int
}

let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("DeliveryBar/Assets.xcassets/AppIcon.appiconset")

let images: [IconImage] = [
    .init(filename: "AppIcon-16x16@1x.png", pixels: 16),
    .init(filename: "AppIcon-16x16@2x.png", pixels: 32),
    .init(filename: "AppIcon-32x32@1x.png", pixels: 32),
    .init(filename: "AppIcon-32x32@2x.png", pixels: 64),
    .init(filename: "AppIcon-128x128@1x.png", pixels: 128),
    .init(filename: "AppIcon-128x128@2x.png", pixels: 256),
    .init(filename: "AppIcon-256x256@1x.png", pixels: 256),
    .init(filename: "AppIcon-256x256@2x.png", pixels: 512),
    .init(filename: "AppIcon-512x512@1x.png", pixels: 512),
    .init(filename: "AppIcon-512x512@2x.png", pixels: 1024)
]

let ink = NSColor(calibratedRed: 0.18, green: 0.19, blue: 0.20, alpha: 1.0)
let inkSoft = NSColor(calibratedRed: 0.26, green: 0.27, blue: 0.28, alpha: 1.0)
let paper = NSColor(calibratedRed: 1.00, green: 0.985, blue: 0.94, alpha: 1.0)
let paperWarm = NSColor(calibratedRed: 0.985, green: 0.955, blue: 0.875, alpha: 1.0)
let backgroundTop = NSColor(calibratedRed: 0.985, green: 0.978, blue: 0.94, alpha: 1.0)
let backgroundBottom = NSColor(calibratedRed: 0.94, green: 0.965, blue: 0.935, alpha: 1.0)
let accent = NSColor(calibratedRed: 0.94, green: 0.72, blue: 0.18, alpha: 1.0)
let accentSoft = NSColor(calibratedRed: 0.98, green: 0.84, blue: 0.34, alpha: 1.0)
let grid = NSColor(calibratedRed: 0.78, green: 0.81, blue: 0.78, alpha: 0.11)

func p(_ value: CGFloat, _ scale: CGFloat) -> CGFloat {
    value * scale
}

func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ scale: CGFloat) -> NSRect {
    NSRect(x: p(x, scale), y: p(y, scale), width: p(width, scale), height: p(height, scale))
}

func drawRoundedRect(_ frame: NSRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil, lineWidth: CGFloat = 0) {
    let path = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }
}

func drawLine(from start: CGPoint, to end: CGPoint, width: CGFloat, color: NSColor, cap: NSBezierPath.LineCapStyle = .round) {
    let path = NSBezierPath()
    path.move(to: start)
    path.line(to: end)
    path.lineWidth = width
    path.lineCapStyle = cap
    path.lineJoinStyle = .round
    color.setStroke()
    path.stroke()
}

func drawPaper(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, rotation: CGFloat, scale: CGFloat, lineWidth: CGFloat, accentOffset: CGFloat) {
    let center = CGPoint(x: p(x + width / 2, scale), y: p(y + height / 2, scale))
    NSGraphicsContext.current?.cgContext.saveGState()
    NSGraphicsContext.current?.cgContext.translateBy(x: center.x, y: center.y)
    NSGraphicsContext.current?.cgContext.rotate(by: rotation * .pi / 180)
    NSGraphicsContext.current?.cgContext.translateBy(x: -center.x, y: -center.y)

    let paperFrame = rect(x, y, width, height, scale)
    let accentFrame = paperFrame.offsetBy(dx: p(24, scale), dy: p(-20, scale))
    let accentPath = NSBezierPath(roundedRect: accentFrame, xRadius: p(28, scale), yRadius: p(28, scale))
    accentPath.lineWidth = max(lineWidth * 0.82, 1)
    accentPath.lineJoinStyle = .round
    accentSoft.withAlphaComponent(0.88).setStroke()
    accentPath.stroke()

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.06)
    shadow.shadowOffset = CGSize(width: p(0, scale), height: p(-8, scale))
    shadow.shadowBlurRadius = p(14, scale)
    shadow.set()
    drawRoundedRect(paperFrame, radius: p(28, scale), fill: paper, stroke: ink, lineWidth: lineWidth)
    NSShadow().set()

    drawLine(
        from: CGPoint(x: p(x + 70, scale), y: p(y + 96 + accentOffset, scale)),
        to: CGPoint(x: p(x + width - 82, scale), y: p(y + 96 + accentOffset, scale)),
        width: p(20, scale),
        color: accentSoft
    )
    drawLine(
        from: CGPoint(x: p(x + 74, scale), y: p(y + 165 + accentOffset, scale)),
        to: CGPoint(x: p(x + width - 118, scale), y: p(y + 165 + accentOffset, scale)),
        width: p(15, scale),
        color: inkSoft.withAlphaComponent(0.72)
    )
    drawLine(
        from: CGPoint(x: p(x + 74, scale), y: p(y + 226 + accentOffset, scale)),
        to: CGPoint(x: p(x + width - 150, scale), y: p(y + 226 + accentOffset, scale)),
        width: p(15, scale),
        color: inkSoft.withAlphaComponent(0.54)
    )

    NSGraphicsContext.current?.cgContext.restoreGState()
}

func drawPerson(scale: CGFloat, lineWidth: CGFloat) {
    let head = NSBezierPath(ovalIn: rect(150, 350, 154, 154, scale))
    paper.setFill()
    head.fill()
    ink.setStroke()
    head.lineWidth = lineWidth
    head.stroke()

    let neckBody = NSBezierPath()
    neckBody.move(to: CGPoint(x: p(229, scale), y: p(350, scale)))
    neckBody.curve(
        to: CGPoint(x: p(178, scale), y: p(210, scale)),
        controlPoint1: CGPoint(x: p(222, scale), y: p(302, scale)),
        controlPoint2: CGPoint(x: p(178, scale), y: p(286, scale))
    )
    neckBody.curve(
        to: CGPoint(x: p(320, scale), y: p(207, scale)),
        controlPoint1: CGPoint(x: p(184, scale), y: p(154, scale)),
        controlPoint2: CGPoint(x: p(316, scale), y: p(154, scale))
    )
    neckBody.curve(
        to: CGPoint(x: p(266, scale), y: p(352, scale)),
        controlPoint1: CGPoint(x: p(320, scale), y: p(278, scale)),
        controlPoint2: CGPoint(x: p(274, scale), y: p(302, scale))
    )
    paperWarm.setFill()
    neckBody.fill()
    ink.setStroke()
    neckBody.lineWidth = lineWidth
    neckBody.lineJoinStyle = .round
    neckBody.stroke()

    let arm = NSBezierPath()
    arm.move(to: CGPoint(x: p(292, scale), y: p(288, scale)))
    arm.curve(
        to: CGPoint(x: p(430, scale), y: p(374, scale)),
        controlPoint1: CGPoint(x: p(346, scale), y: p(308, scale)),
        controlPoint2: CGPoint(x: p(378, scale), y: p(362, scale))
    )
    arm.lineWidth = max(p(27, scale), 1.1)
    arm.lineCapStyle = .round
    arm.lineJoinStyle = .round
    ink.setStroke()
    arm.stroke()

    drawLine(
        from: CGPoint(x: p(435, scale), y: p(375, scale)),
        to: CGPoint(x: p(455, scale), y: p(395, scale)),
        width: max(p(22, scale), 1),
        color: ink
    )

    let eyeSize = p(18, scale)
    NSColor(calibratedWhite: 0.16, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: p(197, scale), y: p(417, scale), width: eyeSize, height: eyeSize)).fill()
    NSBezierPath(ovalIn: NSRect(x: p(254, scale), y: p(417, scale), width: eyeSize, height: eyeSize)).fill()
}

func drawIdeaMark(scale: CGFloat, lineWidth: CGFloat) {
    let bulb = NSBezierPath()
    bulb.move(to: CGPoint(x: p(334, scale), y: p(620, scale)))
    bulb.curve(
        to: CGPoint(x: p(406, scale), y: p(618, scale)),
        controlPoint1: CGPoint(x: p(350, scale), y: p(668, scale)),
        controlPoint2: CGPoint(x: p(390, scale), y: p(668, scale))
    )
    bulb.curve(
        to: CGPoint(x: p(384, scale), y: p(580, scale)),
        controlPoint1: CGPoint(x: p(408, scale), y: p(600, scale)),
        controlPoint2: CGPoint(x: p(398, scale), y: p(590, scale))
    )
    bulb.lineWidth = lineWidth
    bulb.lineCapStyle = .round
    bulb.lineJoinStyle = .round
    accent.setStroke()
    bulb.stroke()

    drawLine(
        from: CGPoint(x: p(350, scale), y: p(570, scale)),
        to: CGPoint(x: p(388, scale), y: p(570, scale)),
        width: max(p(16, scale), 0.9),
        color: ink
    )
    drawLine(
        from: CGPoint(x: p(358, scale), y: p(540, scale)),
        to: CGPoint(x: p(380, scale), y: p(540, scale)),
        width: max(p(14, scale), 0.8),
        color: ink
    )
    drawLine(
        from: CGPoint(x: p(355, scale), y: p(622, scale)),
        to: CGPoint(x: p(370, scale), y: p(604, scale)),
        width: max(p(13, scale), 0.75),
        color: accentSoft
    )
    drawLine(
        from: CGPoint(x: p(370, scale), y: p(604, scale)),
        to: CGPoint(x: p(388, scale), y: p(632, scale)),
        width: max(p(13, scale), 0.75),
        color: accentSoft
    )
}

func drawSparkLine(scale: CGFloat) {
    let path = NSBezierPath()
    path.move(to: CGPoint(x: p(276, scale), y: p(530, scale)))
    path.curve(
        to: CGPoint(x: p(526, scale), y: p(710, scale)),
        controlPoint1: CGPoint(x: p(352, scale), y: p(620, scale)),
        controlPoint2: CGPoint(x: p(430, scale), y: p(708, scale))
    )
    path.curve(
        to: CGPoint(x: p(638, scale), y: p(634, scale)),
        controlPoint1: CGPoint(x: p(576, scale), y: p(710, scale)),
        controlPoint2: CGPoint(x: p(606, scale), y: p(676, scale))
    )
    path.lineWidth = max(p(19, scale), 0.95)
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    accent.setStroke()
    path.stroke()

    drawLine(
        from: CGPoint(x: p(485, scale), y: p(780, scale)),
        to: CGPoint(x: p(485, scale), y: p(832, scale)),
        width: max(p(15, scale), 0.85),
        color: accentSoft
    )
    drawLine(
        from: CGPoint(x: p(550, scale), y: p(755, scale)),
        to: CGPoint(x: p(590, scale), y: p(792, scale)),
        width: max(p(15, scale), 0.85),
        color: accentSoft
    )
}

func drawIcon(side: Int) -> NSBitmapImageRep {
    let size = NSSize(width: side, height: side)
    let scale = CGFloat(side) / 1024.0
    let lineWidth = max(p(28, scale), 1.15)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: side,
        pixelsHigh: side,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Unable to create \(side)x\(side) bitmap")
    }
    bitmap.size = size

    let previousContext = NSGraphicsContext.current
    let context = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current = context
    context?.cgContext.setAllowsAntialiasing(true)
    context?.cgContext.setShouldAntialias(true)
    context?.cgContext.setShouldSmoothFonts(false)
    defer {
        NSGraphicsContext.current = previousContext
    }

    NSColor.clear.setFill()
    NSRect(origin: .zero, size: size).fill()

    let baseRect = rect(48, 48, 928, 928, scale)
    let basePath = NSBezierPath(roundedRect: baseRect, xRadius: p(206, scale), yRadius: p(206, scale))

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.12)
    shadow.shadowOffset = CGSize(width: 0, height: p(-24, scale))
    shadow.shadowBlurRadius = p(42, scale)
    shadow.set()
    NSColor.white.setFill()
    basePath.fill()
    NSShadow().set()

    basePath.addClip()
    let gradient = NSGradient(starting: backgroundTop, ending: backgroundBottom)
    gradient?.draw(in: baseRect, angle: -90)

    for gridLine in stride(from: CGFloat(190), through: CGFloat(830), by: CGFloat(160)) {
        drawLine(
            from: CGPoint(x: p(gridLine, scale), y: p(96, scale)),
            to: CGPoint(x: p(gridLine, scale), y: p(928, scale)),
            width: max(p(6, scale), 0.35),
            color: grid,
            cap: .butt
        )
        drawLine(
            from: CGPoint(x: p(96, scale), y: p(gridLine, scale)),
            to: CGPoint(x: p(928, scale), y: p(gridLine, scale)),
            width: max(p(6, scale), 0.35),
            color: grid,
            cap: .butt
        )
    }

    let glow = NSBezierPath(ovalIn: rect(150, 125, 640, 640, scale))
    accentSoft.withAlphaComponent(0.10).setFill()
    glow.fill()

    drawSparkLine(scale: scale)
    drawPaper(x: 606, y: 292, width: 260, height: 340, rotation: -10, scale: scale, lineWidth: lineWidth, accentOffset: 0)
    drawPaper(x: 548, y: 350, width: 266, height: 350, rotation: -3, scale: scale, lineWidth: lineWidth, accentOffset: 10)
    drawPaper(x: 642, y: 408, width: 248, height: 322, rotation: 8, scale: scale, lineWidth: lineWidth, accentOffset: -10)
    drawPerson(scale: scale, lineWidth: lineWidth)
    drawIdeaMark(scale: scale, lineWidth: max(p(20, scale), 1.0))

    let border = NSBezierPath(roundedRect: baseRect.insetBy(dx: p(10, scale), dy: p(10, scale)), xRadius: p(196, scale), yRadius: p(196, scale))
    NSColor.white.withAlphaComponent(0.58).setStroke()
    border.lineWidth = max(p(10, scale), 0.7)
    border.stroke()

    return bitmap
}

func writePNG(_ bitmap: NSBitmapImageRep, to url: URL, pixels: Int) throws {
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "DeliveryBarIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode \(pixels)x\(pixels) PNG"])
    }
    try png.write(to: url, options: .atomic)
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for icon in images {
    let image = drawIcon(side: icon.pixels)
    let destination = outputDirectory.appendingPathComponent(icon.filename)
    try writePNG(image, to: destination, pixels: icon.pixels)
    print("Generated \(icon.filename)")
}
