import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255.0,
                  green: Double((hex >> 8) & 0xFF) / 255.0,
                  blue: Double(hex & 0xFF) / 255.0,
                  opacity: 1.0)
    }
}

enum Theme {
    static let bg = Color(hex: 0x070A0F)
    static let surface = Color(hex: 0x111721)
    static let surface2 = Color(hex: 0x161E29)

    static let line = Color.white.opacity(0.075)
    static let line2 = Color.white.opacity(0.13)

    static let text = Color(hex: 0xEAF0F7)
    static let muted = Color(hex: 0x8794A6)
    static let muted2 = Color(hex: 0x5D6A7B)

    static let accent = Color(hex: 0x4FE3A6)
    static let accentDeep = Color(hex: 0x1FB98A)
    static let amber = Color(hex: 0xF5C878)
    static let red = Color(hex: 0xFF7070)

    static let accentGradient = LinearGradient(
        colors: [Color(hex: 0x63EDB4), Color(hex: 0x25BE8D)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let logoGradient = LinearGradient(
        colors: [Color(hex: 0x7BF3C4), Color(hex: 0x2AC593)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

enum AvatarTint {
    struct Pair {
        let background: Color
        let foreground: Color
    }

    static let all: [Pair] = [
        Pair(background: Color(hex: 0x4FE3A6).opacity(0.13), foreground: Color(hex: 0x5BEBB0)),
        Pair(background: Color(hex: 0x7BA8FF).opacity(0.13), foreground: Color(hex: 0x8FB6FF)),
        Pair(background: Color(hex: 0xB79BFF).opacity(0.13), foreground: Color(hex: 0xC4AEFF)),
        Pair(background: Color(hex: 0xF5C878).opacity(0.13), foreground: Color(hex: 0xF5C878)),
        Pair(background: Color(hex: 0xFF8F8F).opacity(0.12), foreground: Color(hex: 0xFF9E9E))
    ]

    static func pair(for title: String) -> Pair {
        let sum = title.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return all[sum % all.count]
    }
}
