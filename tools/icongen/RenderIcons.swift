// 「一局」354 款游戏图标渲染器（拾海 2026-10-13）
//
// 为什么不用 Python/PIL：
//   PIL 装不上 Apple Color Emoji 的位图字号（`invalid pixel size`）⇒ 彩色 emoji 画不出来。
//   本机唯一能稳定画出**彩色 emoji** 的路是 CoreText/AppKit（实测 1464 种颜色 ✓）。
//
// 设计（P11「图像配置拉满」）：
//   · 每张 192×192，4× 超采样再降采样 ⇒ 边缘抗锯齿
//   · 圆角方砖 + 对角渐变 + 中心柔光 + 左上高光带
//   · 图标底下压一层**投影**（emoji 才"立"得起来，不糊在底色上）
//   · emoji 按**视觉包围盒**居中（不是按 ascender/descender —— 否则小图标会偏上）
//   · 右下角一枚**色相环角标**：把 id 哈希映射到色相，保证 354 款两两可区分
//
// 用法：swift RenderIcons.swift <spec.json> <outdir>
//   spec.json: [{"id":"snake","emoji":"🐍","hex":"#6366F1","idx":0}, ...]

import AppKit
import CoreText
import Foundation

// ── 颜色工具 ──────────────────────────────────────────
func hex2rgb(_ s: String) -> (CGFloat, CGFloat, CGFloat) {
    var t = s.trimmingCharacters(in: .whitespaces)
    if t.hasPrefix("#") { t.removeFirst() }
    guard t.count == 6, let v = UInt32(t, radix: 16) else { return (0.4, 0.4, 0.4) }
    return (CGFloat((v >> 16) & 0xFF) / 255.0,
            CGFloat((v >> 8) & 0xFF) / 255.0,
            CGFloat(v & 0xFF) / 255.0)
}

func mix(_ a: (CGFloat, CGFloat, CGFloat), _ b: (CGFloat, CGFloat, CGFloat), _ t: CGFloat)
    -> (CGFloat, CGFloat, CGFloat) {
    return (a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t, a.2 + (b.2 - a.2) * t)
}

func lighten(_ c: (CGFloat, CGFloat, CGFloat), _ k: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
    return (min(1, c.0 + k), min(1, c.1 + k), min(1, c.2 + k))
}

func darken(_ c: (CGFloat, CGFloat, CGFloat), _ k: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
    return (max(0, c.0 * (1 - k)), max(0, c.1 * (1 - k)), max(0, c.2 * (1 - k)))
}

/// 稳定哈希（FNV-1a）—— 同一个 id 永远得到同一个角标色相
func hash32(_ s: String) -> UInt32 {
    var h: UInt32 = 2166136261
    for b in s.utf8 {
        h ^= UInt32(b)
        h = h &* 16777619
    }
    return h
}

// ── emoji 度量（带缓存）────────────────────────────────
// ★ 为什么要自己量像素包围盒：
//   CTLineGetBoundsWithOptions(.useOpticalBounds) 对 emoji 字体给出的框**带大量空白**
//   （实测 pawn 的 bounds 高 235 而实际字形只有 ~180），拿它居中/定尺 ⇒ 每张图大小不一。
//   这里把 emoji 画进临时画布，扫 alpha 找**真实墨迹框**。69 个 emoji 各量一次，之后走缓存。
struct GlyphBox {
    let img: CGImage
    let x0: Int
    let y0: Int
    let w: Int
    let h: Int
    /// 墨迹的平均饱和度。♟️ ½ ％ ➰ 这类"文字呈现"的字形是**纯黑单色**（实测 sat=0.000）。
    let sat: CGFloat
    /// 墨迹的平均**相对亮度** —— 用来跟方砖底色算真实对比度，决定要不要垫底板。
    /// （只看饱和度会误判：🕐 是"浅灰单色"，压在浅蓝底上其实看不清）
    let lum: CGFloat
}

var glyphCache: [String: GlyphBox] = [:]

func measureGlyph(_ emoji: String, pt: CGFloat) -> GlyphBox? {
    if let c = glyphCache[emoji] { return c }
    // ★ 画布必须比字形大 —— 曾用固定 320 而 pt=700 ⇒ 字形被画布裁掉，
    //   量出来的"墨迹框"其实是"画布边界"，图标就缺了右下角（2026-10-13 真踩过）
    let side = min(1200, Int((pt * 2.0).rounded(.up)))
    let W = side, H = side
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8,
                              bytesPerRow: W * 4, space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.clear(CGRect(x: 0, y: 0, width: W, height: H))
    let font = CTFontCreateWithName("AppleColorEmoji" as CFString, pt, nil)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: emoji, attributes: [.font: font]))
    let b = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    ctx.textPosition = CGPoint(x: (CGFloat(W) - b.width) / 2 - b.minX,
                               y: (CGFloat(H) - b.height) / 2 - b.minY)
    CTLineDraw(line, ctx)
    guard let img = ctx.makeImage() else { return nil }

    // 扫 alpha 求真实墨迹框（用 CGImage 数据，注意行序）
    guard let dp = img.dataProvider?.data, let p = CFDataGetBytePtr(dp) else { return nil }
    let bpr = img.bytesPerRow
    var minX = W, minY = H, maxX = -1, maxY = -1
    var satSum: CGFloat = 0
    var lumSum: CGFloat = 0
    var satN = 0
    for y in 0..<H {
        let row = p + y * bpr
        for x in 0..<W {
            if row[x * 4 + 3] > 8 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
                let r = CGFloat(row[x * 4]) / 255, g = CGFloat(row[x * 4 + 1]) / 255, b = CGFloat(row[x * 4 + 2]) / 255
                let mx = max(r, max(g, b)), mn = min(r, min(g, b))
                satSum += mx <= 0 ? 0 : (mx - mn) / mx
                // sRGB 相对亮度（WCAG）
                func lin(_ v: CGFloat) -> CGFloat { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
                lumSum += 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
                satN += 1
            }
        }
    }
    if maxX < 0 { return nil }
    if minX <= 0 || minY <= 0 || maxX >= W - 1 || maxY >= H - 1 {
        FileHandle.standardError.write("⚠️ emoji \(emoji) 墨迹触到画布边（\(W)px pt=\(pt)）—— 画布开小了\n".data(using: .utf8)!)
    }
    // 调试：把测量画布导出来看（ICO_DEBUG=2）
    if ProcessInfo.processInfo.environment["ICO_DUMP_GLYPH"] != nil {
        let r2 = NSBitmapImageRep(cgImage: img)
        try? r2.representation(using: .png, properties: [:])!.write(
            to: URL(fileURLWithPath: "/tmp/glyph_\(emoji.unicodeScalars.first!.value).png"))
    }
    let box = GlyphBox(img: img, x0: minX, y0: minY, w: maxX - minX + 1, h: maxY - minY + 1,
                       sat: satN > 0 ? satSum / CGFloat(satN) : 0,
                       lum: satN > 0 ? lumSum / CGFloat(satN) : 0)
    glyphCache[emoji] = box
    return box
}

/// 把字形里的**过暗像素抬亮**（保留 alpha 抗锯齿边缘），用于深色底板上的单色字形。
/// ★ 不做"整体染色"：染成纯白会把 🎲 这种"浅色底 + 深色点"的形体糊成一块白砖
///   （2026-10-13 实拍踩过）。这里改成把最暗的墨迹抬到 ~0.78 亮度，形体仍在。
func liftGlyph(_ gb: GlyphBox) -> CGImage? {
    let w = gb.w, h = gb.h
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let out = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                              bytesPerRow: w * 4, space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
          let src = gb.img.cropping(to: CGRect(x: gb.x0, y: gb.y0, width: w, height: h)),
          let sp = src.dataProvider?.data, let sptr = CFDataGetBytePtr(sp) else { return nil }
    out.clear(CGRect(x: 0, y: 0, width: w, height: h))
    guard let op = out.data?.bindMemory(to: UInt8.self, capacity: h * out.bytesPerRow) else { return nil }
    let sbpr = src.bytesPerRow, obpr = out.bytesPerRow
    // 源图是**非预乘**还是**预乘**在这里都成立：先按非预乘读，再按 alpha 还原成非预乘写回
    for y in 0..<h {
        for x in 0..<w {
            let so = y * sbpr + x * 4
            let oo = y * obpr + x * 4
            let a = sptr[so + 3]
            let un = CGFloat(a) / 255
            // 非预乘还原（a=0 时无所谓）
            let r = un > 0.004 ? CGFloat(sptr[so]) / un : 0
            let g = un > 0.004 ? CGFloat(sptr[so + 1]) / un : 0
            let b = un > 0.004 ? CGFloat(sptr[so + 2]) / un : 0
            let lum = 0.2126 * min(r, 255) + 0.7152 * min(g, 255) + 0.0722 * min(b, 255)
            // 太暗（< 0.52·255）的墨迹 → 按比例抬到 0.78·255，保留色相
            let target: CGFloat = 0.78 * 255
            let k: CGFloat = lum < 0.52 * 255 ? (lum > 1 ? target / lum : 1) : 1
            let nr = min(255, min(r, 255) * k)
            let ng = min(255, min(g, 255) * k)
            let nb = min(255, min(b, 255) * k)
            op[oo] = UInt8(max(0, min(255, nr * un)))
            op[oo + 1] = UInt8(max(0, min(255, ng * un)))
            op[oo + 2] = UInt8(max(0, min(255, nb * un)))
            op[oo + 3] = a
        }
    }
    return out.makeImage()
}

// ── 单张图标 ──────────────────────────────────────────
/// 渲染一张图标。
/// - Returns: 是否成功
func renderIcon(id: String, emoji: String, hex: String, index: Int, size: Int, out: String) -> Bool {
    let SS = 3                                  // 超采样（3×3 = 9 样本/像素，边缘足够干净）
    let N = size * SS
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: N, height: N, bitsPerComponent: 8,
                              bytesPerRow: N * 4, space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        return false
    }
    ctx.interpolationQuality = .high
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    let base = hex2rgb(hex)
    let seed = hash32(id)

    // ① 底：透明（图标自身带圆角，卡片底色透出来）
    ctx.clear(CGRect(x: 0, y: 0, width: N, height: N))

    // ② 圆角方砖路径
    let inset = CGFloat(N) * 0.015
    let rect = CGRect(x: inset, y: inset, width: CGFloat(N) - inset * 2, height: CGFloat(N) - inset * 2)
    let radius = rect.width * 0.235
    let tile = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.saveGState()
    ctx.addPath(tile)
    ctx.clip()

    // ③ 渐变：**方向随哈希转**（16 档）＋ 极轻微的色相偏移
    //    ⇒ 同一底色、同一 emoji 的两款游戏，明暗走向也不同
    let gAng = CGFloat(seed % 16) / 16.0 * 2 * .pi
    let gdx = cos(gAng) * rect.width * 0.5
    let gdy = sin(gAng) * rect.height * 0.5
    // 色相微扰：只在 ±6° 内，保证仍看得出是"这个颜色"
    let hueBase = NSColor(red: base.0, green: base.1, blue: base.2, alpha: 1)
    var hh: CGFloat = 0, hs: CGFloat = 0, hb: CGFloat = 0, ha: CGFloat = 0
    hueBase.getHue(&hh, saturation: &hs, brightness: &hb, alpha: &ha)
    let hueShift = (CGFloat((seed >> 4) % 13) - 6.0) / 360.0
    let tinted = NSColor(hue: (hh + hueShift + 1).truncatingRemainder(dividingBy: 1),
                         saturation: hs, brightness: hb, alpha: 1)
    var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
    tinted.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
    let top = lighten((tr, tg, tb), 0.22)
    let bottom = darken((tr, tg, tb), 0.36)
    if let grad = CGGradient(colorsSpace: cs,
                             colors: [CGColor(red: top.0, green: top.1, blue: top.2, alpha: 1),
                                      CGColor(red: bottom.0, green: bottom.1, blue: bottom.2, alpha: 1)] as CFArray,
                             locations: [0, 1]) {
        ctx.drawLinearGradient(grad,
                               start: CGPoint(x: rect.midX - gdx, y: rect.midY - gdy),
                               end: CGPoint(x: rect.midX + gdx, y: rect.midY + gdy),
                               options: [])
    }

    // ④ 中心柔光（让图标中心比边缘亮一点，视线收拢）
    let center = CGPoint(x: rect.midX, y: rect.midY)
    if let g2 = CGGradient(colorsSpace: cs,
                           colors: [CGColor(red: 1, green: 1, blue: 1, alpha: 0.20),
                                    CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)] as CFArray,
                           locations: [0, 1]) {
        ctx.drawRadialGradient(g2, startCenter: center, startRadius: 0,
                               endCenter: center, endRadius: rect.width * 0.62, options: [])
    }

    // ⑤ 哈希图案：斜向缎带 + 哈希色相的柔光斑
    //    ⇒ 即使两款游戏共用同一个 emoji、同一个底色，图标也**不可能撞脸**
    let ang = CGFloat((seed >> 8) % 8) / 8.0 * .pi
    let bandW = rect.width * (0.045 + CGFloat((seed >> 11) % 3) * 0.030)
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: ang)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.085))
    var bx = -rect.width * 1.6
    while bx < rect.width * 1.6 {
        ctx.fill(CGRect(x: bx, y: -rect.height, width: bandW, height: rect.height * 2))
        bx += bandW * (2.6 + CGFloat((seed >> 13) % 3) * 0.7)
    }
    ctx.restoreGState()

    // 哈希色相的柔光斑（贴着某一角，位置随哈希走）
    let hue0 = CGFloat(seed % 360) / 360.0
    let blob = NSColor(hue: hue0, saturation: 0.85, brightness: 1.0, alpha: 0.22)
    var br: CGFloat = 0, bg2: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
    blob.getRed(&br, green: &bg2, blue: &bb, alpha: &ba)
    let cornerX = (seed >> 16) % 2 == 0 ? rect.minX : rect.maxX
    let cornerY = (seed >> 17) % 2 == 0 ? rect.minY : rect.maxY
    if let gb = CGGradient(colorsSpace: cs,
                           colors: [CGColor(red: br, green: bg2, blue: bb, alpha: 0.30),
                                    CGColor(red: br, green: bg2, blue: bb, alpha: 0.0)] as CFArray,
                           locations: [0, 1]) {
        ctx.drawRadialGradient(gb,
                               startCenter: CGPoint(x: cornerX, y: cornerY), startRadius: 0,
                               endCenter: CGPoint(x: cornerX, y: cornerY),
                               endRadius: rect.width * 0.85, options: [])
    }

    // ⑥ 左上高光带（"玻璃"质感）
    ctx.saveGState()
    ctx.setBlendMode(.plusLighter)
    if let g3 = CGGradient(colorsSpace: cs,
                           colors: [CGColor(red: 1, green: 1, blue: 1, alpha: 0.34),
                                    CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)] as CFArray,
                           locations: [0, 1]) {
        ctx.drawLinearGradient(g3,
                               start: CGPoint(x: rect.minX, y: rect.maxY),
                               end: CGPoint(x: rect.minX + rect.width * 0.55,
                                            y: rect.maxY - rect.height * 0.55),
                               options: [])
    }
    ctx.restoreGState()

    // ⑧ emoji 下压一层极淡的暗晕（提可读性）
    //   ★ 不用 setShadow：彩色 emoji 带大面积半透明边缘，投影会变成"脏边"
    if let gs = CGGradient(colorsSpace: cs,
                           colors: [CGColor(red: 0, green: 0, blue: 0, alpha: 0.0),
                                    CGColor(red: 0, green: 0, blue: 0, alpha: 0.15),
                                    CGColor(red: 0, green: 0, blue: 0, alpha: 0.0)] as CFArray,
                           locations: [0, 0.5, 1]) {
        ctx.drawRadialGradient(gs, startCenter: center, startRadius: 0,
                               endCenter: center, endRadius: rect.width * 0.48, options: [])
    }

    // ⑨ emoji 本体：按**实测墨迹框**缩放到方砖宽度的 64% 并精确居中
    //   （字体自带的 bounds 对每个 emoji 留白不同 ⇒ 不自己量就会"大小不一、上下不齐"）
    guard let gb = measureGlyph(emoji, pt: rect.width * 0.66) else { return false }
    // ★ 按**最长边**缩放进一个正方形框（不是"宽度对齐"）：
    //   ♟️ 这种瘦高字形若按宽度对齐，高度会冲到方砖的 88%，底板跟着撑满整张图。
    //   实测：按宽度算 drawH=510（占 576 画布的 88%），按最长边算是 346（60%）✓
    let glyphBox = rect.width * 0.60
    let glyphScale = glyphBox / CGFloat(max(gb.w, gb.h))
    let drawW = CGFloat(gb.w) * glyphScale
    let drawH = CGFloat(gb.h) * glyphScale

    // ⑨′ 单色字形（♟️ ½ ％ ➰ ⚫ …）垫一块圆角底板：
    //     · 底色亮 ⇒ 白色底板 + 深色字形（对比度 11:1）
    //     · 底色深 ⇒ 深色底板 + 白色字形
    //     彩色 emoji 不垫（它们自己就够跳）—— 实测 ♟️ 的 sat=0.000、🧠 的 sat=0.42
    let baseLum = 0.2126 * base.0 + 0.7152 * base.1 + 0.0722 * base.2
    // 实测对比度（WCAG 2.x）：>3.0 就够清楚，不垫板 —— 免得每张图都套个白方块
    //   ⚫ 压在浅橙上 = 9.1:1 ⇒ 不垫 ✓ ；♟️ 压在浅蓝上 = 1.7:1 ⇒ 垫 ✓
    let cL = max(baseLum, gb.lum), cD = min(baseLum, gb.lum)
    let contrast = (cL + 0.05) / (cD + 0.05)
    // ★ 阈值取 0.10（不是 0.20）—— 实测 🃏 的 sat=0.085、🕐=0.021、🎲=0.012 才是真单色；
    //   0.20 会把 📐(0.19)、🧊(0.49 不会) 之类**本来就有颜色**的字形也套上白板，
    //   结果 100+ 张图标长得一模一样（2026-10-13 看 52vp 实物发现）
    let needPlate = gb.sat < 0.10 && contrast < 3.0
    if needPlate {
        // 底板边长：至少盖住 glyph，且不小于方砖宽的 60% —— 否则 ♟️ 这种瘦高字形
        // 会顶满底板、四周一点留白都没有（2026-10-13 实拍确认）
        let need = max(drawW, drawH) * 1.24
        let plateSide = max(need, rect.width * 0.62)
        let plateRect = CGRect(x: center.x - plateSide / 2, y: center.y - plateSide / 2,
                               width: plateSide, height: plateSide)
        let platePath = CGPath(roundedRect: plateRect,
                               cornerWidth: plateSide * 0.24, cornerHeight: plateSide * 0.24,
                               transform: nil)
        ctx.saveGState()
        // ★ 投影要"柔"：blur 太小 + 不透明度太高 ⇒ 底板周围一圈发黑像脏边
        ctx.setShadow(offset: CGSize(width: 0, height: -CGFloat(N) * 0.006),
                      blur: CGFloat(N) * 0.040,
                      color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.16))
        if baseLum > 0.42 {
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
        } else {
            ctx.setFillColor(CGColor(red: 0.10, green: 0.11, blue: 0.15, alpha: 0.90))
        }
        ctx.addPath(platePath)
        ctx.fillPath()
        ctx.restoreGState()
        if ProcessInfo.processInfo.environment["ICO_DEBUG"] != nil {
            FileHandle.standardError.write(String(format: "  [dbg] %@ sat=%.3f glyphLum=%.3f tileLum=%.3f contrast=%.2f plate=%.1f (%.1f%% of N)\n",
                id, gb.sat, gb.lum, baseLum, contrast, plateSide, plateSide / CGFloat(N) * 100).data(using: .utf8)!)
        }
    }
    var glyphImg = gb.img.cropping(to: CGRect(x: gb.x0, y: gb.y0, width: gb.w, height: gb.h))
    // 深底 + 单色字形 ⇒ 反白后再画（否则白底板上看得见、深底板上是个更黑的洞）
    if needPlate {
        if baseLum <= 0.42, let masked = liftGlyph(gb) {
            glyphImg = masked
        }
    }
    if let sub = glyphImg {
        ctx.draw(sub, in: CGRect(x: center.x - drawW / 2, y: center.y - drawH / 2,
                                 width: drawW, height: drawH))
    }

    // ⑩ 角标：右下角白环 + 哈希色相点；角标内再按哈希画 1/2/3 个小点
    //    ⇒ 角标本身就带 4 相位 × 3 点数 = 12 种变化
    let dotR = rect.width * 0.056
    let dotC = CGPoint(x: rect.maxX - rect.width * 0.125, y: rect.minY + rect.height * 0.125)
    let hue = CGFloat(seed % 360) / 360.0
    let accent = NSColor(hue: hue, saturation: 0.80, brightness: 1.0, alpha: 1.0)
    var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
    accent.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
    // ★ 2026-10-13 真机实测：原来"白环 + 彩点"在 48vp 下读起来像一个甜甜圈，
    //   不像设计元素 ⇒ 去掉白环，只留一枚**柔和**的彩点（低透明度、无硬边）
    if let gd = CGGradient(colorsSpace: cs,
                           colors: [CGColor(red: ar, green: ag, blue: ab, alpha: 0.95),
                                    CGColor(red: ar, green: ag, blue: ab, alpha: 0.0)] as CFArray,
                           locations: [0, 1]) {
        ctx.drawRadialGradient(gd,
                               startCenter: dotC, startRadius: 0,
                               endCenter: dotC, endRadius: dotR * 2.1, options: [])
    }
    let nDots = 1 + Int((seed >> 19) % 3)
    let phase = CGFloat((seed >> 21) % 4) / 4.0 * 2 * .pi
    ctx.setFillColor(CGColor(red: ar, green: ag, blue: ab, alpha: 1))
    if nDots == 1 {
        ctx.fillEllipse(in: CGRect(x: dotC.x - dotR, y: dotC.y - dotR,
                                   width: dotR * 2, height: dotR * 2))
    } else {
        for k in 0..<nDots {
            let a = phase + CGFloat(k) * 2 * .pi / CGFloat(nDots)
            let rr = dotR * 0.58
            let cx = dotC.x + cos(a) * dotR * 0.42
            let cy = dotC.y + sin(a) * dotR * 0.42
            ctx.fillEllipse(in: CGRect(x: cx - rr, y: cy - rr, width: rr * 2, height: rr * 2))
        }
    }

    // ⑩ 内描边（描一圈更"精致"）
    ctx.addPath(tile)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.16))
    ctx.setLineWidth(CGFloat(N) * 0.006)
    ctx.strokePath()

    ctx.restoreGState()

    // ⑪ 降采样到目标尺寸
    guard let big = ctx.makeImage() else { return false }
    var final = big
    if SS > 1 {
        guard let small = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                                    bytesPerRow: size * 4, space: cs,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return false
        }
        small.interpolationQuality = .high
        small.draw(big, in: CGRect(x: 0, y: 0, width: size, height: size))
        guard let s = small.makeImage() else { return false }
        final = s
    }

    let rep = NSBitmapImageRep(cgImage: final)
    guard let data = rep.representation(using: .png, properties: [:]) else { return false }
    do {
        try data.write(to: URL(fileURLWithPath: out))
    } catch {
        return false
    }
    _ = index
    return true
}

// ── main ─────────────────────────────────────────────
let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("用法: swift RenderIcons.swift <spec.json> <outdir> [size]\n".data(using: .utf8)!)
    exit(2)
}
let specPath = args[1]
let outDir = args[2]
let size = args.count >= 4 ? (Int(args[3]) ?? 192) : 192

guard let raw = try? Data(contentsOf: URL(fileURLWithPath: specPath)),
      let arr = try? JSONSerialization.jsonObject(with: raw) as? [[String: Any]] else {
    FileHandle.standardError.write("spec.json 读不了\n".data(using: .utf8)!)
    exit(2)
}

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

var ok = 0
var failed: [String] = []
for (i, item) in arr.enumerated() {
    guard let id = item["id"] as? String,
          let emoji = item["emoji"] as? String,
          let hex = item["hex"] as? String else {
        failed.append("item \(i): 字段缺失")
        continue
    }
    let out = (outDir as NSString).appendingPathComponent("gico_\(id).png")
    if renderIcon(id: id, emoji: emoji, hex: hex, index: i, size: size, out: out) {
        ok += 1
    } else {
        failed.append(id)
    }
}
print("渲染完成: \(ok)/\(arr.count)  → \(outDir)")
if !failed.isEmpty {
    print("失败 \(failed.count) 张: \(failed.prefix(20).joined(separator: ", "))")
    exit(1)
}
