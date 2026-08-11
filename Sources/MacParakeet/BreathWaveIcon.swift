import AppKit

/// Generates the MacParakeet "Cursive P" logo programmatically.
///
/// Design: An enclosed circular bowl with a dot inside, and a cursive loop tail
/// that descends, loops under, and trails off left. The loop echoes the bowl's
/// circular rhythm — two circles in harmony.
///
/// Inspired by Daoist simplicity: a single stroke forming a P with a bird's-eye
/// dot at center. The cursive tail gives it handwritten warmth.
///
/// The icon is drawn via Core Graphics so it scales perfectly at any size
/// and works as a template image (adapts to light/dark mode automatically).
enum BreathWaveIcon {

    // MARK: - Canonical Geometry (128×128 viewBox)

    // Bowl: circle cx=68, cy=34, r=26
    // Dot: cx=68, cy=34, r=6
    // Stem + cursive loop tail:
    //   M 42,34 L 42,82 C 42,100 30,110 18,112 C 6,114 2,106 8,98 C 14,90 30,88 42,92
    // Stroke width: 7 (large), 10 (small/menu bar)

    /// Menu bar icon state variants.
    enum MenuBarState: Equatable {
        case idle
        case recording
        case processing

        var accessibilityLabel: String {
            switch self {
            case .idle: "Ready"
            case .recording: "Listening"
            case .processing: "Thinking"
            }
        }
    }

    /// Number of distinct frames used by each menu-bar state. Kept as a pure
    /// helper so the animation contract is cheap to regression-test.
    static func menuBarAnimationFrameCount(for state: MenuBarState) -> Int {
        switch state {
        case .idle: 1
        case .recording, .processing: 4
        }
    }

    /// Pixel-art status face used by the always-present menu-bar companion.
    /// Idle is a winky face; listening animates a tiny waveform; thinking
    /// animates a three-dot thought trail. Template rendering keeps every frame
    /// legible in light, dark, tinted, and high-contrast menu bars.
    static func menuBarIcon(
        pointSize: CGFloat = 18,
        state: MenuBarState = .idle,
        frame: Int = 0
    ) -> NSImage {
        let size = NSSize(width: pointSize, height: pointSize)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            let scale = rect.width / 18
            func pixel(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat = 1, _ height: CGFloat = 1) {
                NSBezierPath(rect: NSRect(
                    x: (x * scale).rounded(.down),
                    y: (y * scale).rounded(.down),
                    width: max(scale, (width * scale).rounded(.up)),
                    height: max(scale, (height * scale).rounded(.up))
                )).fill()
            }

            // Chunky, open-corner face outline.
            pixel(5, 15, 8, 1)
            pixel(3, 13, 2, 1)
            pixel(13, 13, 2, 1)
            pixel(2, 6, 1, 7)
            pixel(15, 6, 1, 7)
            pixel(3, 4, 2, 1)
            pixel(13, 4, 2, 1)

            let normalizedFrame = abs(frame) % menuBarAnimationFrameCount(for: state)
            switch state {
            case .idle:
                // One bright eye, one wink, and a crooked pixel smile.
                pixel(5, 10, 2, 2)
                pixel(10, 10, 3, 1)
                pixel(6, 7)
                pixel(7, 6, 4, 1)
                pixel(11, 7)

            case .recording:
                pixel(5, 11, 2, 1)
                pixel(11, 11, 2, 1)
                let patterns: [[CGFloat]] = [
                    [2, 4, 6, 3, 2],
                    [3, 6, 3, 5, 2],
                    [5, 3, 2, 6, 3],
                    [2, 5, 4, 3, 6],
                ]
                for (index, height) in patterns[normalizedFrame].enumerated() {
                    pixel(CGFloat(4 + index * 2), 5, 1, height)
                }

            case .processing:
                // Eyes glance side to side while the emphasized thought dot
                // walks across the bottom of the face.
                let glance = normalizedFrame == 1 || normalizedFrame == 2 ? CGFloat(1) : 0
                pixel(5 + glance, 10, 1, 2)
                pixel(11 + glance, 10, 1, 2)
                for index in 0..<3 {
                    pixel(CGFloat(6 + index * 3), 6, 1, index == normalizedFrame % 3 ? 2 : 1)
                }
            }

            return true
        }
        image.accessibilityDescription = state.accessibilityLabel
        image.isTemplate = true
        return image
    }

    /// Load the canonical parakeet brand mark as a transparent template
    /// NSImage, suitable for inline tinting in SwiftUI views (assistant
    /// avatars, status chips, etc.). The asset (`parakeet-mark.png`) is the
    /// same illustration used by `Assets/AppIcon-1024x1024.png`; this loader
    /// converts the white-on-near-black source to alpha-only at load so
    /// callers control color via `.renderingMode(.template)` +
    /// `.foregroundStyle()`.
    ///
    /// ## Why luminance → alpha
    /// The shipped source is a high-resolution white parakeet on a near-black
    /// background. We don't have a transparent-background variant in the
    /// repo, so we synthesize one: pixel luminance becomes alpha. The white
    /// silhouette goes fully opaque, the dark background fully transparent,
    /// and anti-aliased edges keep their soft falloff intact.
    ///
    /// The processed CGImage is cached in `templateMark` so the per-pixel
    /// pass runs at most once per process.
    static func brandMark(pointSize: CGFloat = 18) -> NSImage {
        let image: NSImage
        if let cgTemplate = templateMark {
            image = NSImage(cgImage: cgTemplate, size: NSSize(width: pointSize, height: pointSize))
        } else {
            image = NSImage(size: NSSize(width: pointSize, height: pointSize))
        }
        image.isTemplate = true
        return image
    }

    /// Lazy process-lifetime cache. Built on first `brandMark(...)` call,
    /// then reused for every subsequent inline render.
    private static let templateMark: CGImage? = {
        guard let url = Bundle.module.url(forResource: "parakeet-mark", withExtension: "png"),
              let nsImage = NSImage(contentsOf: url),
              let source = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return makeLuminanceTemplate(from: source)
    }()

    /// Convert the white-on-near-black source to a tight, transparent template:
    ///
    /// 1. Per-pixel Rec. 709 luminance with black-point (25) and white-point
    ///    (240) cutoffs. Below the black point the source's radial vignette
    ///    gets clamped to fully transparent; above the white point the bird's
    ///    interior saturates to fully opaque. The middle band ramps linearly
    ///    so anti-aliased edges keep their soft falloff.
    /// 2. Scan the resulting alpha buffer to find the parakeet's bounding box.
    /// 3. Crop to a square centered on that bbox with breathing-room padding,
    ///    so callers displaying at N points get ~N points of bird rather than
    ///    bird-with-margin (the source canvas has ~25% empty padding around
    ///    the illustration, which made 18pt displays read as ~13pt of bird).
    private static func makeLuminanceTemplate(from source: CGImage) -> CGImage? {
        let width = source.width
        let height = source.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else { return nil }
        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)

        // Pass 1 — luminance with black/white cutoffs. Coefficients sum to
        // 1024 (Rec. 709, integer fixed-point) so the inner loop stays FP-free.
        let blackPoint = 25
        let whitePoint = 240
        let range = whitePoint - blackPoint
        let total = width * height
        for p in 0..<total {
            let i = p * bytesPerPixel
            let r = Int(buffer[i])
            let g = Int(buffer[i + 1])
            let b = Int(buffer[i + 2])
            let lum = (r * 218 + g * 732 + b * 74) >> 10
            let alpha: UInt8
            if lum <= blackPoint {
                alpha = 0
            } else if lum >= whitePoint {
                alpha = 255
            } else {
                alpha = UInt8(((lum - blackPoint) * 255) / range)
            }
            // Premultiplied: storing (alpha, alpha, alpha, alpha) is equivalent
            // to a pure-white pixel with alpha = alpha.
            buffer[i] = alpha
            buffer[i + 1] = alpha
            buffer[i + 2] = alpha
            buffer[i + 3] = alpha
        }

        guard let fullImage = context.makeImage() else { return nil }

        // Pass 2 — bbox of meaningfully-opaque pixels. Threshold above the
        // tiniest sub-pixel speckle so a single stray pixel can't blow the
        // bbox out to a corner.
        let opaqueThreshold: UInt8 = 16
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        for y in 0..<height {
            let rowBase = y * width * bytesPerPixel
            for x in 0..<width {
                if buffer[rowBase + x * bytesPerPixel + 3] >= opaqueThreshold {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }
        guard maxX >= 0 else { return fullImage }

        // Square crop centered on the parakeet's bbox. 6% padding gives
        // anti-aliased edges room and keeps the bird from kissing the frame
        // edges at small display sizes.
        let parakeetW = maxX - minX + 1
        let parakeetH = maxY - minY + 1
        let padding = max(width, height) / 16
        let side = max(parakeetW, parakeetH) + padding * 2
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        var cropX = centerX - side / 2
        var cropY = centerY - side / 2
        // Clamp to source bounds while preserving square shape.
        if cropX < 0 { cropX = 0 }
        if cropY < 0 { cropY = 0 }
        let cropSide = min(side, min(width - cropX, height - cropY))
        let cropRect = CGRect(x: cropX, y: cropY, width: cropSide, height: cropSide)

        return fullImage.cropping(to: cropRect)
    }

    /// Create the Cursive P logo as a filled NSImage for app icon / dock use.
    /// Uses white on a colored background.
    static func appIcon(size: CGFloat = 512) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            let s = size / 128.0
            let cornerRadius = 22 * s

            // Background — deep teal-blue gradient
            let bg = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            let gradient = NSGradient(
                starting: NSColor(red: 0.12, green: 0.20, blue: 0.32, alpha: 1.0),
                ending: NSColor(red: 0.08, green: 0.14, blue: 0.24, alpha: 1.0)
            )
            gradient?.draw(in: bg, angle: -90)

            // White logo, centered with padding
            let padding: CGFloat = 20 * s
            let ls = (size - padding * 2) / 128.0

            NSColor.white.setStroke()
            NSColor.white.setFill()

            let bowlRadius = 26 * ls

            // Enclosed circular bowl
            let bowl = NSBezierPath(
                ovalIn: NSRect(
                    x: padding + 68 * ls - bowlRadius, y: padding + 34 * ls - bowlRadius,
                    width: bowlRadius * 2, height: bowlRadius * 2
                )
            )
            bowl.lineWidth = 7 * ls
            bowl.stroke()

            // Stem + cursive loop tail
            let tail = NSBezierPath()
            tail.move(to: NSPoint(x: padding + 42 * ls, y: padding + 34 * ls))
            tail.line(to: NSPoint(x: padding + 42 * ls, y: padding + 82 * ls))
            tail.curve(
                to: NSPoint(x: padding + 18 * ls, y: padding + 112 * ls),
                controlPoint1: NSPoint(x: padding + 42 * ls, y: padding + 100 * ls),
                controlPoint2: NSPoint(x: padding + 30 * ls, y: padding + 110 * ls)
            )
            tail.curve(
                to: NSPoint(x: padding + 8 * ls, y: padding + 98 * ls),
                controlPoint1: NSPoint(x: padding + 6 * ls, y: padding + 114 * ls),
                controlPoint2: NSPoint(x: padding + 2 * ls, y: padding + 106 * ls)
            )
            tail.curve(
                to: NSPoint(x: padding + 42 * ls, y: padding + 92 * ls),
                controlPoint1: NSPoint(x: padding + 14 * ls, y: padding + 90 * ls),
                controlPoint2: NSPoint(x: padding + 30 * ls, y: padding + 88 * ls)
            )
            tail.lineWidth = 7 * ls
            tail.lineCapStyle = .round
            tail.stroke()

            // Dot
            let dotRadius = 6 * ls
            NSBezierPath(ovalIn: NSRect(
                x: padding + 68 * ls - dotRadius, y: padding + 34 * ls - dotRadius,
                width: dotRadius * 2, height: dotRadius * 2
            )).fill()

            return true
        }
        return image
    }
}
