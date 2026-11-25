import AppKit

func color(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: 1)
}

func render(size: Int, to path: String) {
    let s = CGFloat(size)
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    // Origin bottom-left. Work in a 1024 design space.
    ctx.scaleBy(x: s / 1024, y: s / 1024)

    // Desk
    ctx.setFillColor(color(0x2C2C2A))
    ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))

    // Receipt: runs off the top edge, torn zigzag at the bottom.
    let left: CGFloat = 232, right: CGFloat = 792, bottom: CGFloat = 150, tooth: CGFloat = 40
    let paper = CGMutablePath()
    paper.move(to: CGPoint(x: left, y: 1024))
    paper.addLine(to: CGPoint(x: right, y: 1024))
    paper.addLine(to: CGPoint(x: right, y: bottom + tooth))
    let teeth = 7
    let step = (right - left) / CGFloat(teeth)
    for i in 0..<teeth {
        let x = right - CGFloat(i) * step
        paper.addLine(to: CGPoint(x: x - step / 2, y: bottom))
        paper.addLine(to: CGPoint(x: x - step, y: bottom + tooth))
    }
    paper.closeSubpath()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 40, color: CGColor(gray: 0, alpha: 0.45))
    ctx.addPath(paper)
    ctx.setFillColor(color(0xF4EFE2))
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    // Dashed rules
    func dashed(y: CGFloat) {
        ctx.setStrokeColor(color(0x888780))
        ctx.setLineWidth(9)
        ctx.setLineDash(phase: 0, lengths: [34, 24])
        ctx.move(to: CGPoint(x: left + 56, y: y))
        ctx.addLine(to: CGPoint(x: right - 56, y: y))
        ctx.strokePath()
    }
    dashed(y: 842)
    dashed(y: 360)

    // Header and total bars, like printed lines
    ctx.setLineDash(phase: 0, lengths: [])
    ctx.setFillColor(color(0x5F5E5A))
    ctx.fill(CGRect(x: 412, y: 900, width: 200, height: 26))
    ctx.fill(CGRect(x: left + 56, y: 262, width: 150, height: 26))
    ctx.setFillColor(color(0x2C2C2A))
    ctx.fill(CGRect(x: right - 56 - 230, y: 256, width: 230, height: 38))

    // The drip: one ink droplet
    let cx: CGFloat = 512, cy: CGFloat = 560, r: CGFloat = 122
    let drop = CGMutablePath()
    drop.move(to: CGPoint(x: cx, y: cy + r * 2.15))
    drop.addCurve(to: CGPoint(x: cx + r, y: cy), control1: CGPoint(x: cx + r * 0.25, y: cy + r * 1.45), control2: CGPoint(x: cx + r, y: cy + r * 0.75))
    drop.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: 0, endAngle: .pi, clockwise: true)
    drop.addCurve(to: CGPoint(x: cx, y: cy + r * 2.15), control1: CGPoint(x: cx - r, y: cy + r * 0.75), control2: CGPoint(x: cx - r * 0.25, y: cy + r * 1.45))
    drop.closeSubpath()
    ctx.addPath(drop)
    ctx.setFillColor(color(0x2C2C2A))
    ctx.fillPath()

    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

render(size: 1024, to: CommandLine.arguments[1] + "/icon-1024.png")
render(size: 512, to: CommandLine.arguments[1] + "/icon-512.png")
