import SwiftUI

struct StainedGlassView: View {
    let panes: [GlassPane]
    let size: CGSize

    @State private var selectedPane: Int? = nil

    var body: some View {
        ZStack {
            Color(white: 0.06)

            // Layer 1: all panes
            ForEach(panes) { pane in
                let isSelected = selectedPane == pane.id || (selectedPane == nil && pane.isToday)

                PaneView(pane: pane, isSelected: isSelected)
                    .contentShape(PaneShape(vertices: pane.vertices))
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedPane = (selectedPane == pane.id) ? nil : pane.id
                        }
                    }
            }

            // Layer 2: tooltip on top of everything
            if let id = selectedPane ?? panes.first(where: { $0.isToday })?.id,
               let pane = panes.first(where: { $0.id == id }) {
                paneTooltip(pane)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .zIndex(1000)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.2)) { selectedPane = nil }
        }
    }

    private func paneTooltip(_ pane: GlassPane) -> some View {
        let centroids = pane.vertices
        let cx = centroids.map(\.x).reduce(0, +) / CGFloat(centroids.count)
        let cy = centroids.map(\.y).reduce(0, +) / CGFloat(centroids.count)
        let tooltipY = cy < size.height / 2 ? cy + 32 : cy - 24
        let clampedX = min(max(cx, 60), size.width - 60)

        return Text(pane.label)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 6))
            .position(x: clampedX, y: tooltipY)
    }
}

struct PaneView: View {
    let pane: GlassPane
    let isSelected: Bool

    var body: some View {
        PaneShape(vertices: pane.vertices)
            .fill(paneFill)
            .overlay { dateLabel }
            .overlay(PaneShape(vertices: pane.vertices)
                .stroke(Color.black.opacity(0.65), lineWidth: leadWidth))
            .overlay { glowOverlay }
            .scaleEffect(isSelected && !pane.isToday ? 1.04 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .zIndex(pane.isToday || isSelected ? 10 : 0)
    }

    private var paneFill: LinearGradient {
        LinearGradient(gradient: pane.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var dateLabel: some View {
        let centroids = pane.vertices
        let cx = centroids.map(\.x).reduce(0, +) / CGFloat(centroids.count)
        let cy = centroids.map(\.y).reduce(0, +) / CGFloat(centroids.count)
        return VStack(spacing: 0) {
            if !pane.weekdayLabel.isEmpty {
                Text(pane.weekdayLabel)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(pane.intensity > 0.3 ? 0.6 : 0.3))
            }
            Text(pane.dateLabel)
                .font(.system(size: pane.isToday ? 13 : 10, weight: pane.isToday ? .bold : .medium))
                .foregroundStyle(.white.opacity(pane.intensity > 0.3 ? 0.85 : 0.35))
        }
        .position(x: cx, y: cy)
    }

    @ViewBuilder
    private var glowOverlay: some View {
        if isSelected || pane.glow > 0.05 {
            let g = isSelected ? max(pane.glow, 0.5) : pane.glow
            PaneShape(vertices: pane.vertices)
                .stroke(Color.white.opacity(g * 0.5), lineWidth: glowWidth)
                .blur(radius: pane.isToday || isSelected ? 4 : 2)
        }
    }

    private var leadWidth: CGFloat { (pane.isToday || isSelected) ? 2.0 : 1.2 }
    private var glowWidth: CGFloat { (pane.isToday || isSelected) ? 3.0 : 1.5 }
}

struct PaneShape: Shape {
    let vertices: [CGPoint]
    func path(in rect: CGRect) -> Path {
        guard vertices.count >= 3 else { return Path() }
        var p = Path()
        p.move(to: vertices[0])
        for v in vertices.dropFirst() { p.addLine(to: v) }
        p.closeSubpath()
        return p
    }
}
