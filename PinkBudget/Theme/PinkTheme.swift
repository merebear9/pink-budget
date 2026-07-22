import SwiftUI

// MARK: - Color Palette

extension Color {
    // Primary pinks
    static let pinkPrimary = Color(hex: "E91E8C")       // Hot pink - primary actions
    static let pinkLight = Color(hex: "FCE4F2")          // Light pink - backgrounds
    static let pinkSoft = Color(hex: "F8B4D9")           // Soft pink - secondary elements
    static let pinkDeep = Color(hex: "BE185D")           // Deep pink - emphasis
    
    // Neutrals
    static let bgPrimary = Color(hex: "FFF5F9")          // Near-white pink tint
    static let bgCard = Color.white
    static let textPrimary = Color(hex: "1F1F1F")
    static let textSecondary = Color(hex: "6B7280")
    static let textMuted = Color(hex: "9CA3AF")
    static let border = Color(hex: "F3E8F0")
    
    // Semantic
    static let success = Color(hex: "10B981")            // Green - on track
    static let warning = Color(hex: "F59E0B")            // Amber - close to limit
    static let danger = Color(hex: "EF4444")             // Red - over budget
    static let info = Color(hex: "6366F1")               // Indigo - informational
    
    // Account colors (for charts)
    static let tspColor = Color(hex: "E91E8C")           // Pink
    static let k401Color = Color(hex: "8B5CF6")          // Purple
    static let rothColor = Color(hex: "06B6D4")          // Cyan
    static let otherColor = Color(hex: "F59E0B")         // Amber
    
    // Budget category colors
    static let catRent = Color(hex: "E91E8C")
    static let catGroceries = Color(hex: "10B981")
    static let catGas = Color(hex: "6366F1")
    static let catDining = Color(hex: "F59E0B")
    static let catSubscriptions = Color(hex: "8B5CF6")
    static let catCats = Color(hex: "EC4899")
    static let catPersonal = Color(hex: "06B6D4")
    static let catMisc = Color(hex: "9CA3AF")
}

// MARK: - Hex Color Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography

struct PinkTypography {
    static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title = Font.system(size: 22, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 16, weight: .regular, design: .default)
    static let callout = Font.system(size: 14, weight: .medium, design: .default)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let money = Font.system(size: 32, weight: .bold, design: .monospaced)
    static let moneySmall = Font.system(size: 18, weight: .semibold, design: .monospaced)
}

// MARK: - Card Style Modifier

struct PinkCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.bgCard)
            .cornerRadius(16)
            .shadow(color: Color.pinkPrimary.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func pinkCard() -> some View {
        modifier(PinkCard())
    }
}

// MARK: - Button Styles

struct PinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PinkTypography.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.pinkPrimary)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PinkOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PinkTypography.headline)
            .foregroundColor(.pinkPrimary)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.pinkPrimary, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
