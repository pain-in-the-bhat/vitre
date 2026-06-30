import SwiftUI

/// A Gothic rose window: tapered petals radiating from a sacred center.
/// Backlit, translucent, with flowing lead lines and warm bloom.
struct RoseWindow: View {
    let panes: [GlassPane]
    let diameter: CGFloat

    @State private var selectedPane: Int? = nil
    @State private var pulse: CGFloat = 0

    var body: some View {
        ZStack {
            // Night behind the glass
            Color(white: 0.01)

            // Backlight — sunlight behind the entire window
            RadialGradient(
                colors: [
                    Color(hue: 0.09, saturation: 0.45, brightness: 0.20).opacity(0.65),
                    Color(hue: 0.07, saturation: 0.25, brightness: 0.08).opacity(0.25),
                    Color.clear,
                ],
                center: .center,
                startRadius: 0,
                endRadius: diameter * 0.48
            )

            // Today's pulse — warm heartbeat at center
            RadialGradient(
                colors: [
                    Color(hue: 0.11, saturation: 0.75, brightness: 0.35 + pulse * 0.15).opacity(0.55),
                    Color.clear,
                ],
                center: .center,
                startRadius: 0,
                endRadius: diameter * 0.20
            )
            .blur(radius: 5)

            // Petals
            ForEach(panes) { pane in
                let isSelected = selectedPane == pane.id || (selectedPane == nil && pane.isToday)

                PetalView(pane: pane, isSelected: isSelected, diameter: diameter)
                    .contentShape(PetalShape(vertices: pane.vertices))
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedPane = (selectedPane == pane.id) ? nil : pane.id
                        }
                    }
            }

            // Soft bloom around bright areas
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color(hue: 0.09, saturation: 0.35, brightness: 0.12).opacity(0.12),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: diameter * 0.25,
                        endRadius: diameter * 0.5
                    )
                )

            // Edge vignette
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.clear, Color.clear, Color.black.opacity(0.55)],
                        center: .center,
                        startRadius: diameter * 0.36,
                        endRadius: diameter * 0.5
                    )
                )

            // Tooltip
            if let id = selectedPane ?? panes.first(where: { $0.isToday })?.id,
               let pane = panes.first(where: { $0.id == id }) {
                petalTooltip(pane)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .zIndex(1000)
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { pulse = 1 }
        }
    }

    private func petalTooltip(_ pane: GlassPane) -> some View {
        let c = pane.vertices
        let cx = c.map(\.x).reduce(0, +) / CGFloat(c.count)
        let cy = c.map(\.y).reduce(0, +) / CGFloat(c.count)
        let dx = cx - diameter / 2, dy = cy - diameter / 2
        let dist = max(sqrt(dx * dx + dy * dy), 1)
        let ox = dx / dist * 70, oy = dy / dist * 70

        return Text(pane.label)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
            .position(x: cx + ox, y: cy + oy)
    }
}

// MARK: - Petal

struct PetalView: View {
    let pane: GlassPane
    let isSelected: Bool
    let diameter: CGFloat

    var body: some View {
        PetalShape(vertices: pane.vertices)
            .fill(petalFill)
            // Bright edge — light catching the glass
            .overlay {
                PetalShape(vertices: pane.vertices)
                    .stroke(
                        pane.intensity > 0.15
                            ? Color.white.opacity(0.05 + pane.intensity * 0.07)
                            : Color.white.opacity(0.015),
                        lineWidth: 0.8
                    )
            }
            // Lead outline — thick, dark, flowing
            .overlay(PetalShape(vertices: pane.vertices)
                .stroke(Color(white: 0.003), lineWidth: leadWidth))
            // Glow
            .overlay { glowLayer }
            .scaleEffect(isSelected ? 1.06 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
            .zIndex(pane.isToday || isSelected ? 10 : 0)
    }

    private var petalFill: RadialGradient {
        let cx = pane.vertices.map(\.x).reduce(0, +) / CGFloat(pane.vertices.count)
        let cy = pane.vertices.map(\.y).reduce(0, +) / CGFloat(pane.vertices.count)
        return RadialGradient(
            gradient: pane.gradient,
            center: UnitPoint(x: cx / diameter, y: cy / diameter),
            startRadius: 0,
            endRadius: diameter * 0.1
        )
    }

    @ViewBuilder
    private var glowLayer: some View {
        if isSelected {
            PetalShape(vertices: pane.vertices)
                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                .blur(radius: 3)
            PetalShape(vertices: pane.vertices)
                .stroke(Color(hue: 0.10, saturation: 0.9, brightness: 0.8).opacity(0.3), lineWidth: 5)
                .blur(radius: 8)
        } else if pane.isToday {
            PetalShape(vertices: pane.vertices)
                .stroke(Color(hue: 0.11, saturation: 0.85, brightness: 0.75).opacity(0.4), lineWidth: 3.5)
                .blur(radius: 6)
        } else if pane.intensity > 0.65 {
            PetalShape(vertices: pane.vertices)
                .stroke(Color(hue: 0.09, saturation: 0.7, brightness: 0.6).opacity(0.15), lineWidth: 2)
                .blur(radius: 4)
        }
    }

    private var leadWidth: CGFloat { pane.isToday ? 3.5 : 2.0 }
}

// MARK: - Smooth Petal Shape (bezier-curved edges)

struct PetalShape: Shape {
    let vertices: [CGPoint]

    func path(in rect: CGRect) -> Path {
        guard vertices.count >= 3 else { return Path() }
        var path = Path()
        let n = vertices.count
        let start = CGPoint(
            x: (vertices[n - 1].x + vertices[0].x) / 2,
            y: (vertices[n - 1].y + vertices[0].y) / 2
        )
        path.move(to: start)
        for i in 0..<n {
            let current = vertices[i]
            let next = vertices[(i + 1) % n]
            let mid = CGPoint(x: (current.x + next.x) / 2, y: (current.y + next.y) / 2)
            path.addQuadCurve(to: mid, control: current)
        }
        path.closeSubpath()
        return path
    }
}
