import SwiftUI

/// A stained-glass tile for the heatmap.
/// Uses `.regularMaterial` + tinted fill for a glass-like depth effect.
/// Upgrade to `.glassEffect(.regular.tint())` when targeting macOS 26.
struct GlassTile: View {
    let tint: Color
    let isToday: Bool
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(tint)
            .background(.regularMaterial, in: .rect(cornerRadius: 4))
            .frame(width: size, height: size)
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.white.opacity(0.7), lineWidth: 1.5)
                }
            }
    }
}
