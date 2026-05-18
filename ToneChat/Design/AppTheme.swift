import SwiftUI
import UIKit

enum AppTheme {
    // MARK: - Spacing

    static let spacingXS: CGFloat = 8
    static let spacingSM: CGFloat = 12
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24

    // MARK: - Radius

    static let radiusCard: CGFloat = 12
    static let radiusComposer: CGFloat = 22
    static let radiusBubble: CGFloat = 16

    // MARK: - Colors (cool blue-gray, same shade steps as warm palette)

    static let background = Color.dynamic(light: 0xF4F6FA, dark: 0x121820)
    static let surface = Color.dynamic(light: 0xE8EDF5, dark: 0x1A2433)
    static let surfaceElevated = Color.dynamic(light: 0xFFFFFF, dark: 0x243044)
    static let textPrimary = Color.dynamic(light: 0x0F172A, dark: 0xEFF3F9)
    static let textSecondary = Color.dynamic(light: 0x64748B, dark: 0x94A3B8)
    static let accent = Color.dynamic(light: 0x2563EB, dark: 0x60A5FA)
    static let userBubble = Color.dynamic(light: 0xDBE4F2, dark: 0x2A3548)
    static let border = Color.dynamic(light: 0xC5D3E3, dark: 0x334155)
    static let errorBackground = Color.dynamic(light: 0xFCE8E6, dark: 0x3D2020)
    static let errorText = Color.dynamic(light: 0xB42318, dark: 0xFCA5A5)

    static func icon(for personaId: String) -> String {
        switch personaId {
        case "preset-wook": return "music.note"
        case "preset-nedc": return "heart"
        case "preset-australian": return "cloud.sun"
        default: return "person.crop.circle"
        }
    }

    static func subtitle(for persona: Persona) -> String {
        switch persona.id {
        case "preset-wook":
            return "Festival scene · chill house"
        case "preset-nedc":
            return "Wise old man"
        case "preset-australian":
            return "Cranky uncle energy"
        default:
            return persona.isPreset ? "Built-in voice" : "Custom voice"
        }
    }
}

private extension Color {
    static func dynamic(light: UInt, dark: UInt) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

struct ThemeBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(AppTheme.background)
    }
}

extension View {
    func themeBackground() -> some View {
        modifier(ThemeBackgroundModifier())
    }
}
