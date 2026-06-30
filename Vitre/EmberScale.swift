import SwiftUI

/// Maps a token count to an ember-tinted color for the stained-glass heatmap.
/// Uses log-scale normalization so the full range (zero to millions) is visible.
enum EmberScale {

    /// Returns a Color that can be used with `.glassEffect(.regular.tint(color))`.
    /// Intensity 0 = near-invisible (cold/dark), intensity 1 = bright ember glow.
    static func tint(for tokens: Int, maxTokens: Int) -> Color {
        let intensity = normalizedIntensity(tokens: tokens, maxTokens: maxTokens)
        // Ember: orange hue, saturation kicks in with intensity, brightness rises.
        let hue: Double = 0.08        // ~30° — warm orange
        let saturation: Double = 0.3 + intensity * 0.6
        let brightness: Double = 0.25 + intensity * 0.7
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    // MARK: - Private

    /// Log-scale normalization. Floor at 10K tokens (anything below is ~zero visually).
    /// Ceiling at maxTokens. Result clamped to [0, 1].
    private static func normalizedIntensity(tokens: Int, maxTokens: Int) -> Double {
        guard tokens > 0, maxTokens > 0 else { return 0 }
        let floor: Double = log10(10_000)
        let ceiling: Double = log10(Double(max(maxTokens, 10_001)))
        let value: Double = log10(Double(max(tokens, 1)))
        let raw = (value - floor) / (ceiling - floor)
        return min(max(raw, 0), 1)
    }
}
