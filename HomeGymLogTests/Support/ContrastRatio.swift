import Foundation

/// An sRGB color with 0…255 channels, for the contrast tests (m5-light-theme spec §5).
/// `ExpressibleByStringLiteral` lets a test write `"15803D"` where an `RGB` is expected
/// (≈ a TypeScript template-literal type that also parses). A malformed literal traps: literals exist only in
/// test source, so a typo is a test bug. Colorset data never uses this init; it goes through the Static suite's
/// strict parser, which fails through `#require` instead.
struct RGB: Equatable, CustomStringConvertible, ExpressibleByStringLiteral {
    let r: Int, g: Int, b: Int

    init(r: Int, g: Int, b: Int) {
        self.r = r; self.g = g; self.b = b
    }

    init(stringLiteral hex: String) {
        guard hex.count == 6, hex.allSatisfy(\.isHexDigit), let value = Int(hex, radix: 16) else {
            preconditionFailure("RGB literal must be six hex digits, got \"\(hex)\"")
        }
        self.init(r: (value >> 16) & 0xFF, g: (value >> 8) & 0xFF, b: value & 0xFF)
    }

    /// Uppercase six-digit hex, e.g. "15803D".
    var hex: String { String(format: "%02X%02X%02X", r, g, b) }

    var description: String { hex }
}

/// Test-only WCAG 2.1 math (spec 5.1, 5.2, 5.4). ≈ a small pure util module used only by Jest tests.
/// Every function is total: `RGB` channels are already validated integers.
enum ContrastRatio {
    /// Relative luminance, spec 5.1.
    static func luminance(_ c: RGB) -> Double {
        func linear(_ channel: Int) -> Double {
            let v = Double(channel) / 255
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
    }

    /// Contrast ratio, spec 5.2; argument order does not matter.
    static func ratio(_ a: RGB, _ b: RGB) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// `fg` at opacity `alpha` over an opaque `bg`, per channel, rounded (spec 5.4).
    static func blend(_ fg: RGB, _ alpha: Double, _ bg: RGB) -> RGB {
        func mix(_ f: Int, _ b: Int) -> Int { Int((alpha * Double(f) + (1 - alpha) * Double(b)).rounded()) }
        return RGB(r: mix(fg.r, bg.r), g: mix(fg.g, bg.g), b: mix(fg.b, bg.b))
    }
}
