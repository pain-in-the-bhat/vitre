import SwiftUI

/// A single pane of stained glass — the fundamental unit of the visualization.
struct GlassPane: Identifiable {
    let id: Int
    /// Polygon vertices in normalized 0…1 coordinates (mapped to canvas at render time).
    let vertices: [CGPoint]
    /// Linear gradient across the pane, simulating light through glass.
    var gradient: Gradient
    /// 0 = dark/absent pane, 1 = fully illuminated.
    var intensity: Double
    /// 0 = no glow, 1 = bright inner radiance.
    var glow: Double
    /// Whether this pane represents today.
    var isToday: Bool = false
    /// Hover tooltip text.
    var label: String = ""
    /// Short date label rendered inside the pane (e.g. "15").
    var dateLabel: String = ""
    /// Day of week for the pane (e.g. "Tue").
    var weekdayLabel: String = ""
    /// For the dominant-today layout — fraction of the canvas width this pane occupies.
    var span: CGSize = CGSize(width: 1, height: 1)
}

/// Generates a set of irregular glass panes by jittered subdivision of a rectangular canvas.
/// The same seed always produces the same tessellation.
struct GlassRenderer {
    let seed: Int
    let canvasWidth: CGFloat
    let canvasHeight: CGFloat
    let todayIndex: Int  // which grid cell is "today"

    /// Columns × rows of the base grid before jittering.
    private let cols = 7
    private let rows = 5

    func generate() -> [GlassPane] {
        var rng = SeededRNG(seed: seed)
        let today = todayIndex

        // Build grid of control points and perturb
        var points: [[CGPoint]] = []
        for row in 0...rows {
            var rowPts: [CGPoint] = []
            for col in 0...cols {
                let x = CGFloat(col) / CGFloat(cols) * canvasWidth
                let y = CGFloat(row) / CGFloat(rows) * canvasHeight
                // Jitter interior points (not edges)
                let jx = (col > 0 && col < cols) ? rng.nextCGFloat(-12, 12) : 0
                let jy = (row > 0 && row < rows) ? rng.nextCGFloat(-10, 10) : 0
                rowPts.append(CGPoint(x: x + jx, y: y + jy))
            }
            points.append(rowPts)
        }

        var panes: [GlassPane] = []
        var id = 0

        for row in 0..<rows {
            for col in 0..<cols {
                let index = row * cols + col
                let isToday = index == today

                // Today's pane absorbs neighbors for prominence
                var tl = points[row][col]
                var tr = points[row][col + 1]
                var br = points[row + 1][col + 1]
                var bl = points[row + 1][col]

                var spanW: CGFloat = 1
                var spanH: CGFloat = 1

                if isToday {
                    // Expand today's pane to ~2×2 grid cells
                    if col < cols - 1 {
                        tr = points[row][col + 2]
                        br = points[row + 1][col + 2]
                        spanW = 2
                    }
                    if row < rows - 1 {
                        bl = points[row + 2][col]
                        br = points[row + 2][col + (col < cols - 1 ? 2 : 1)]
                        spanH = 2
                    }
                }

                // Add subtle concave perturbation for handcrafted feel
                let poly: [CGPoint] = isToday
                    ? perturbQuad(tl: tl, tr: tr, br: br, bl: bl, rng: &rng)
                    : [tl, tr, br, bl]

                // Skip cells absorbed by today
                if isToday {
                    // Mark absorbed neighbors as consumed
                    // (handled by span tracking — we skip rendering them)
                }

                panes.append(GlassPane(
                    id: id,
                    vertices: poly,
                    gradient: placeholderGradient(for: index, rng: &rng),
                    intensity: isToday ? 1.0 : rng.nextCGFloat(0.05, 0.85),
                    glow: isToday ? 0.8 : rng.nextCGFloat(0, 0.3),
                    isToday: isToday,
                    label: isToday ? "Today" : "Day \(index + 1)",
                    span: CGSize(width: spanW, height: spanH)
                ))
                id += 1
            }
        }
        return panes
    }

    /// Slightly perturb a quadrilateral's vertices to add organic irregularity.
    private func perturbQuad(tl: CGPoint, tr: CGPoint, br: CGPoint, bl: CGPoint,
                              rng: inout SeededRNG) -> [CGPoint] {
        // Add midpoints on each edge with slight offset
        let mt = midpoint(tl, tr).offset(dx: rng.nextCGFloat(-4, 4), dy: rng.nextCGFloat(-3, 3))
        let mr = midpoint(tr, br).offset(dx: rng.nextCGFloat(-3, 3), dy: rng.nextCGFloat(-4, 4))
        let mb = midpoint(br, bl).offset(dx: rng.nextCGFloat(-4, 4), dy: rng.nextCGFloat(-3, 3))
        let ml = midpoint(bl, tl).offset(dx: rng.nextCGFloat(-3, 3), dy: rng.nextCGFloat(-4, 4))
        // Return 8-vertex polygon with slightly rounded corners
        return [tl, mt, tr, mr, br, mb, bl, ml]
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    private func placeholderGradient(for index: Int, rng: inout SeededRNG) -> Gradient {
        // Simulate light entering from top-left — actual intensity
        // applied later by VitreView after DB read.
        return Gradient(colors: [
            Color(white: 0.35),
            Color(white: 0.55),
        ])
    }

    /// Cathedral-glass palette: indigo (cold) → teal (warming) → amber (active) → gold (peak).
    static func cathedralGradient(for intensity: Double, isToday: Bool) -> Gradient {
        let i = max(0, min(1, intensity))
        let hue: CGFloat
        let saturation: CGFloat
        let brightness: CGFloat

        if isToday {
            hue = 0.10; saturation = 0.7; brightness = 0.55 + CGFloat(i) * 0.4
        } else if i < 0.15 {
            // Cold/quiet — deep indigo
            hue = 0.62; saturation = 0.5; brightness = 0.18 + CGFloat(i) * 1.5
        } else if i < 0.4 {
            // Warming — teal
            let t = CGFloat((i - 0.15) / 0.25)
            hue = 0.62 - t * 0.1; saturation = 0.5 + t * 0.3; brightness = 0.3 + t * 0.3
        } else if i < 0.7 {
            // Active — amber
            let t = CGFloat((i - 0.4) / 0.3)
            hue = 0.52 - t * 0.42; saturation = 0.7 + t * 0.2; brightness = 0.45 + t * 0.3
        } else {
            // Burning — bright gold
            let t = CGFloat((i - 0.7) / 0.3)
            hue = 0.10 + t * 0.02; saturation = 0.85 + t * 0.1; brightness = 0.65 + t * 0.3
        }
        let b2 = min(brightness + 0.15, 0.95)
        return Gradient(colors: [
            Color(hue: hue, saturation: saturation, brightness: brightness),
            Color(hue: hue, saturation: saturation * 0.85, brightness: b2),
        ])
    }
}

// MARK: - Seeded RNG

struct SeededRNG {
    private var state: UInt64

    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed)) &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state = state &* 0x9E3779B97F4A7C15
        state = (state ^ (state >> 30)) &* 0xBF58476D1CE4E5B9
        state = (state ^ (state >> 27)) &* 0x94D049BB133111EB
        return state ^ (state >> 31)
    }

    mutating func nextCGFloat(_ min: CGFloat, _ max: CGFloat) -> CGFloat {
        let val = CGFloat(next() & 0xFFFF) / CGFloat(0xFFFF)
        return min + val * (max - min)
    }
}

// MARK: - CGPoint helpers

extension CGPoint {
    func offset(dx: CGFloat, dy: CGFloat) -> CGPoint {
        CGPoint(x: x + dx, y: y + dy)
    }
}
