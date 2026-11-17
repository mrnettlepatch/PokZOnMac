// crear_icono.swift — genera el icono de la app (1024x1024 PNG) a partir del
// logo del propio juego (Graphics/Titles/pokelogo.png), con un fondo inspirado
// en la pantalla de título: degradado azul y destello dorado.
//
// Uso: swift crear_icono.swift /ruta/pokelogo.png salida.png
import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard args.count == 3, let logoImg = NSImage(contentsOfFile: args[1]),
      let rawLogo = logoImg.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write("Uso: swift crear_icono.swift pokelogo.png salida.png\n".data(using: .utf8)!)
    exit(1)
}

// Recorta el margen transparente del logo para centrarlo bien.
func trimTransparent(_ img: CGImage) -> CGImage {
    let w = img.width, h = img.height
    var px = [UInt8](repeating: 0, count: w * h * 4)
    let c = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    var minX = w, minY = h, maxX = -1, maxY = -1
    for y in 0..<h { for x in 0..<w where px[(y * w + x) * 4 + 3] > 16 {
        minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
    } }
    guard maxX >= minX else { return img }
    // En memoria la fila 0 es la superior, igual que en CGImage.cropping
    return img.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)) ?? img
}
let logo = trimTransparent(rawLogo)

let S: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r / 255, g / 255, b / 255, a])!
}

// Forma estándar de los iconos de macOS: cuadrado redondeado de 824 px centrado.
let inset: CGFloat = 100
let tile = CGRect(x: inset, y: inset, width: S - 2 * inset, height: S - 2 * inset)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

// Sombra exterior suave
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0, 0, 0, 0.35))
ctx.addPath(tilePath); ctx.setFillColor(rgb(40, 110, 170)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(tilePath); ctx.clip()

// 1. Degradado radial azul (como el fondo del título): oscuro abajo, cielo arriba.
let blue = CGGradient(colorsSpace: cs, colors: [rgb(196, 226, 244), rgb(92, 166, 214), rgb(28, 82, 140), rgb(14, 40, 78)] as CFArray,
                      locations: [0, 0.38, 0.78, 1])!
ctx.drawRadialGradient(blue, startCenter: CGPoint(x: S * 0.42, y: S * 0.66), startRadius: 0,
                       endCenter: CGPoint(x: S * 0.5, y: S * 0.5), endRadius: S * 0.75, options: [.drawsAfterEndLocation])

// 2. Rayos dorados desde la esquina superior derecha (destello del título).
let sun = CGPoint(x: tile.maxX - 90, y: tile.maxY - 110)
ctx.saveGState()
ctx.setBlendMode(.screen)
for i in 0..<14 {
    let a0 = CGFloat.pi * (0.92 + Double(i) * 0.062)
    let a1 = a0 + 0.028
    let r: CGFloat = 1300
    let ray = CGMutablePath()
    ray.move(to: sun)
    ray.addLine(to: CGPoint(x: sun.x + cos(a0) * r, y: sun.y + sin(a0) * r))
    ray.addLine(to: CGPoint(x: sun.x + cos(a1) * r, y: sun.y + sin(a1) * r))
    ray.closeSubpath()
    ctx.addPath(ray)
    ctx.setFillColor(rgb(255, 226, 150, i % 2 == 0 ? 0.13 : 0.07))
    ctx.fillPath()
}
ctx.restoreGState()

// 3. Resplandor dorado
ctx.saveGState()
ctx.setBlendMode(.screen)
let glow = CGGradient(colorsSpace: cs, colors: [rgb(255, 244, 205, 0.95), rgb(255, 210, 110, 0.55), rgb(255, 180, 70, 0)] as CFArray,
                      locations: [0, 0.35, 1])!
ctx.drawRadialGradient(glow, startCenter: sun, startRadius: 0, endCenter: sun, endRadius: 520, options: [])
ctx.restoreGState()

// 4. Hojas doradas sueltas (como las partículas del título)
let leaves: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
    (0.80, 0.30, 16, 0.6), (0.86, 0.46, 12, -0.4), (0.22, 0.80, 11, 0.9),
    (0.73, 0.18, 10, 1.2), (0.15, 0.24, 13, -0.8), (0.90, 0.63, 9, 0.3),
]
for (fx, fy, sz, rot) in leaves {
    ctx.saveGState()
    ctx.translateBy(x: S * fx, y: S * fy); ctx.rotate(by: rot)
    ctx.addEllipse(in: CGRect(x: -sz, y: -sz * 0.55, width: sz * 2, height: sz * 1.1))
    ctx.setFillColor(rgb(255, 214, 120, 0.9)); ctx.fillPath()
    ctx.restoreGState()
}

// 5. Viñeta sutil en los bordes para dar profundidad
let vign = CGGradient(colorsSpace: cs, colors: [rgb(0, 0, 0, 0), rgb(0, 10, 30, 0.35)] as CFArray, locations: [0.62, 1])!
ctx.drawRadialGradient(vign, startCenter: CGPoint(x: S / 2, y: S / 2), startRadius: 0,
                       endCenter: CGPoint(x: S / 2, y: S / 2), endRadius: S * 0.62, options: [.drawsAfterEndLocation])

// 6. Logo del juego, centrado, con sombra
let lw = CGFloat(logo.width), lh = CGFloat(logo.height)
let maxW = tile.width * 0.92, maxH = tile.height * 0.86
let scale = min(maxW / lw, maxH / lh)
let dw = lw * scale, dh = lh * scale
let logoRect = CGRect(x: S / 2 - dw / 2, y: S / 2 - dh / 2 - 6, width: dw, height: dh)
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: rgb(10, 25, 50, 0.55))
ctx.interpolationQuality = .high
ctx.draw(logo, in: logoRect)
ctx.restoreGState()

// 7. Borde interior claro (brillo del cristal)
ctx.saveGState()
ctx.addPath(CGPath(roundedRect: tile.insetBy(dx: 2, dy: 2), cornerWidth: 183, cornerHeight: 183, transform: nil))
ctx.setStrokeColor(rgb(255, 255, 255, 0.28)); ctx.setLineWidth(4); ctx.strokePath()
ctx.restoreGState()

let out = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: out)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
print("Icono generado: \(args[2])")
