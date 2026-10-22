// Renders the 1024 × 1024 iOS icon: a white cash envelope with a $ on a green plate (opaque, full bleed).
// Usage: swift scripts/make_icon.swift TipShare/Resources/Assets.xcassets/AppIcon.appiconset/icon.png
import AppKit

let px = 1024
let cg = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                   space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let green = CGColor(red: 0.12, green: 0.55, blue: 0.33, alpha: 1)
let dark = CGColor(red: 0.07, green: 0.38, blue: 0.22, alpha: 1)
cg.setFillColor(green); cg.fill(CGRect(x: 0, y: 0, width: px, height: px))

let body = CGRect(x: 192, y: 300, width: 640, height: 424)
cg.setFillColor(.white)
cg.addPath(CGPath(roundedRect: body, cornerWidth: 48, cornerHeight: 48, transform: nil)); cg.fillPath()
// Flap (y grows upward in CoreGraphics).
cg.setStrokeColor(dark); cg.setLineWidth(28); cg.setLineJoin(.round); cg.setLineCap(.round)
cg.move(to: CGPoint(x: 232, y: 684)); cg.addLine(to: CGPoint(x: 512, y: 480)); cg.addLine(to: CGPoint(x: 792, y: 684))
cg.strokePath()

let gc = NSGraphicsContext(cgContext: cg, flipped: false)
NSGraphicsContext.current = gc
let font = NSFont.systemFont(ofSize: 300, weight: .heavy)
let text = NSAttributedString(string: "$", attributes: [.font: font, .foregroundColor: NSColor(cgColor: green)!])
let size = text.size()
text.draw(at: NSPoint(x: 512 - size.width / 2, y: 330 - size.height / 2 + 40))

let rep = NSBitmapImageRep(cgImage: cg.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
