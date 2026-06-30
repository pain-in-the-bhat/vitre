import SwiftUI

// MARK: - Glass Pane

struct GlassPane: Identifiable {
    let id: Int
    let vertices: [CGPoint]
    var gradient: Gradient
    var intensity: Double
    var glow: Double = 0
    let dayIndex: Int          // -1 = decorative filler
    var isToday: Bool { dayIndex == 0 }
    var isFiller: Bool { dayIndex < 0 }
    var label: String = ""
    var sessions: Int = 0
}

// MARK: - Rose Window Renderer

/// Generates a Gothic rose window with intentional flower composition.
/// Design the lead lines first: 8-fold radial symmetry, branching to 16-fold.
/// Every petal has direction — wide base, tapered tip, pointing outward.
/// Gaps filled with dark decorative glass. No dead space.
struct RoseRenderer {
    let seed: Int
    let diameter: CGFloat

    func generate() -> [GlassPane] {
        var rng = SeededRNG(seed: seed)
        let cx = diameter / 2
        let cy = diameter / 2
        let R = diameter / 2 - 4

        var panes: [GlassPane] = []
        var id = 0
        var dayIdx = 0

        // ── LAYER 1: Central medallion (Today) ──
        let medR = R * 0.13
        panes.append(GlassPane(
            id: id,
            vertices: medallion(cx: cx, cy: cy, r: medR, rng: &rng),
            gradient: Self.palette(1.0, isToday: true, rng: &rng),
            intensity: 1.0, glow: 0.9, dayIndex: 0, label: "Today"
        ))
        id += 1; dayIdx += 1

        // ── LAYER 2: 8 large petals (days 1-8) + 8 gap fillers ──
        let largeInner = R * 0.13
        let largeOuter = R * 0.44
        let largeBaseHW: CGFloat = CGFloat.pi / 8 * 0.72    // 72% of 45° sector
        let largeTipHW: CGFloat = largeBaseHW * 0.22  // tapered to 22%

        for i in 0..<8 {
            if dayIdx > 29 { break }
            let angle = CGFloat(i) * (CGFloat.pi * 2 / 8)
            let v = CGFloat(i % 2 == 0 ? 1 : -1)  // alternate curve direction

            // Petal
            panes.append(GlassPane(
                id: id,
                vertices: petal(cx: cx, cy: cy, innerR: largeInner, outerR: largeOuter,
                               angle: angle, baseHW: largeBaseHW, tipHW: largeTipHW,
                               curve: v * 0.04, jitter: 0.03, rng: &rng),
                gradient: Self.palette(0.3, isToday: false, rng: &rng),
                intensity: 0.3, dayIndex: dayIdx, label: "Day \(dayIdx)"
            ))
            id += 1; dayIdx += 1

            // Gap filler between this petal and the next
            let nextAngle = CGFloat(i + 1) * (CGFloat.pi * 2 / 8)
            panes.append(GlassPane(
                id: id,
                vertices: gapPane(cx: cx, cy: cy, innerR: largeInner, outerR: largeOuter,
                                  a1: angle + largeBaseHW, a2: nextAngle - largeBaseHW,
                                  rng: &rng),
                gradient: Self.fillerGradient(rng: &rng),
                intensity: 0, dayIndex: -1, label: ""
            ))
            id += 1
        }

        // ── LAYER 3: 16 medium petals (days 9-24) + 16 gap fillers ──
        let medInner = R * 0.44
        let medOuter = R * 0.72
        let medBaseHW: CGFloat = CGFloat.pi / 16 * 0.68
        let medTipHW: CGFloat = medBaseHW * 0.20
        let medOffset = CGFloat.pi / 16  // offset to sit between large petal tips

        for i in 0..<16 {
            if dayIdx > 29 { break }
            let angle = medOffset + CGFloat(i) * (CGFloat.pi * 2 / 16)
            let v = CGFloat(i % 2 == 0 ? 1 : -1)

            panes.append(GlassPane(
                id: id,
                vertices: petal(cx: cx, cy: cy, innerR: medInner, outerR: medOuter,
                               angle: angle, baseHW: medBaseHW, tipHW: medTipHW,
                               curve: v * 0.05, jitter: 0.04, rng: &rng),
                gradient: Self.palette(0.2, isToday: false, rng: &rng),
                intensity: 0.2, dayIndex: dayIdx, label: "Day \(dayIdx)"
            ))
            id += 1; dayIdx += 1

            // Gap filler
            let nextAngle = medOffset + CGFloat(i + 1) * (CGFloat.pi * 2 / 16)
            panes.append(GlassPane(
                id: id,
                vertices: gapPane(cx: cx, cy: cy, innerR: medInner, outerR: medOuter,
                                  a1: angle + medBaseHW, a2: nextAngle - medBaseHW,
                                  rng: &rng),
                gradient: Self.fillerGradient(rng: &rng),
                intensity: 0, dayIndex: -1, label: ""
            ))
            id += 1
        }

        // ── LAYER 4: Outer fragments (days 25-30 + filler) ──
        let outerInner = R * 0.72
        let outerOuter = R * 0.95
        let outerCount = 24  // 24 small fragments around the perimeter

        for i in 0..<outerCount {
            let baseAngle = CGFloat.pi * 2 / CGFloat(outerCount)
            let angle = CGFloat(i) * baseAngle
            let isDay = dayIdx <= 29 && i < 30 - 24 + (30 - 24)  // assign remaining days

            if dayIdx <= 29 && i % 3 == 0 {  // every 3rd fragment is a day
                panes.append(GlassPane(
                    id: id,
                    vertices: petal(cx: cx, cy: cy, innerR: outerInner, outerR: outerOuter,
                                   angle: angle, baseHW: baseAngle * 0.35, tipHW: baseAngle * 0.08,
                                   curve: CGFloat(i % 2 == 0 ? 1 : -1) * 0.03, jitter: 0.05, rng: &rng),
                    gradient: Self.palette(0.15, isToday: false, rng: &rng),
                    intensity: 0.15, dayIndex: dayIdx, label: "Day \(dayIdx)"
                ))
                dayIdx += 1
            } else {
                // Decorative filler
                panes.append(GlassPane(
                    id: id,
                    vertices: petal(cx: cx, cy: cy, innerR: outerInner, outerR: outerOuter,
                                   angle: angle, baseHW: baseAngle * 0.35, tipHW: baseAngle * 0.08,
                                   curve: CGFloat(i % 2 == 0 ? 1 : -1) * 0.03, jitter: 0.05, rng: &rng),
                    gradient: Self.fillerGradient(rng: &rng),
                    intensity: 0, dayIndex: -1, label: ""
                ))
            }
            id += 1
        }

        return panes
    }

    // MARK: - Petal Geometry

    /// A tapered petal: wide base → slight widening → tapered tip pointing outward.
    /// 10 vertices for smooth bezier curvature. Slight directional curve.
    private func petal(cx: CGFloat, cy: CGFloat, innerR: CGFloat, outerR: CGFloat,
                       angle: CGFloat, baseHW: CGFloat, tipHW: CGFloat,
                       curve: CGFloat, jitter: CGFloat, rng: inout SeededRNG) -> [CGPoint] {
        let span = outerR - innerR
        let midR = innerR + span * 0.35  // where petal is widest
        let upperR = innerR + span * 0.75

        // Slight curve: shift center angle at different radii
        let curveAt: (CGFloat) -> CGFloat = { r in
            let t = (r - innerR) / span
            return angle + curve * t * t
        }

        var pts: [CGPoint] = []

        // Left edge: base → mid → upper → tip
        pts.append(pt(cx, cy, innerR, angle - baseHW + rng.nextCGFloat(-jitter, jitter)))
        pts.append(pt(cx, cy, midR * 0.95, curveAt(midR) - baseHW * 1.08 + rng.nextCGFloat(-jitter, jitter)))
        pts.append(pt(cx, cy, upperR, curveAt(upperR) - tipHW * 1.3 + rng.nextCGFloat(-jitter, jitter)))
        pts.append(pt(cx, cy, outerR * 0.97, curveAt(outerR * 0.97) - tipHW * 0.5))

        // Tip
        pts.append(pt(cx, cy, outerR, curveAt(outerR)))

        // Right edge: tip → upper → mid → base
        pts.append(pt(cx, cy, outerR * 0.97, curveAt(outerR * 0.97) + tipHW * 0.5))
        pts.append(pt(cx, cy, upperR, curveAt(upperR) + tipHW * 1.3 + rng.nextCGFloat(-jitter, jitter)))
        pts.append(pt(cx, cy, midR * 0.95, curveAt(midR) + baseHW * 1.08 + rng.nextCGFloat(-jitter, jitter)))
        pts.append(pt(cx, cy, innerR, angle + baseHW + rng.nextCGFloat(-jitter, jitter)))

        // Base center (slight inward curve)
        pts.append(pt(cx, cy, innerR * 0.96, angle))

        return pts
    }

    // MARK: - Gap Pane (dark decorative filler between petals)

    private func gapPane(cx: CGFloat, cy: CGFloat, innerR: CGFloat, outerR: CGFloat,
                         a1: CGFloat, a2: CGFloat, rng: inout SeededRNG) -> [CGPoint] {
        // 4-vertex quadrilateral filling the V-shaped gap
        let midA = (a1 + a2) / 2
        let midR = innerR + (outerR - innerR) * 0.5
        return [
            pt(cx, cy, innerR, a1 + rng.nextCGFloat(-0.02, 0.02)),
            pt(cx, cy, outerR * 0.98, a1 + rng.nextCGFloat(-0.03, 0.03)),
            pt(cx, cy, outerR * 0.98, a2 + rng.nextCGFloat(-0.03, 0.03)),
            pt(cx, cy, innerR, a2 + rng.nextCGFloat(-0.02, 0.02)),
            pt(cx, cy, midR * 0.9, midA + rng.nextCGFloat(-0.02, 0.02)),  // slight inward dent
        ]
    }

    // MARK: - Medallion

    private func medallion(cx: CGFloat, cy: CGFloat, r: CGFloat, rng: inout SeededRNG) -> [CGPoint] {
        // 12-lobed sacred heart
        (0..<24).map { i in
            let a = CGFloat(i) * CGFloat.pi / 12
            let rr = r * (i % 2 == 0 ? 1.0 : 0.85) * rng.nextCGFloat(0.94, 1.0)
            return CGPoint(x: cx + rr * cos(a), y: cy + rr * sin(a))
        }
    }

    private func pt(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ a: CGFloat) -> CGPoint {
        CGPoint(x: cx + r * cos(a), y: cy + r * sin(a))
    }

    // MARK: - Palette

    /// Five-stop warm palette: smoked glass → indigo → violet → amber → gold.
    static func palette(_ intensity: Double, isToday: Bool, rng: inout SeededRNG) -> Gradient {
        let i = max(0, min(1, intensity))
        let stops: [(CGFloat, CGFloat, CGFloat)] = [
            (0.62, 0.08, 0.05),  // smoked glass
            (0.70, 0.55, 0.18),  // indigo
            (0.83, 0.58, 0.38),  // royal violet
            (0.08, 0.88, 0.62),  // warm amber
            (0.13, 0.92, 0.95),  // golden yellow
        ]
        let idx = i * CGFloat(stops.count - 1)
        let lo = Int(idx), hi = min(lo + 1, stops.count - 1)
        let t = idx - CGFloat(lo)
        let a = stops[lo], b = stops[hi]
        let h = a.0 + (b.0 - a.0) * t
        let s = a.1 + (b.1 - a.1) * t
        let br = a.2 + (b.2 - a.2) * t
        let (hh, ss, bb) = isToday ? (CGFloat(0.11), CGFloat(0.85), CGFloat(0.60 + i * 0.35)) : (h, s, br)
        return Gradient(colors: [
            Color(hue: hh, saturation: ss, brightness: min(bb + 0.10, 0.98)),
            Color(hue: hh, saturation: ss * 0.78, brightness: max(bb - 0.05, 0.03)),
        ])
    }

    /// Dark decorative glass for gap fillers — present but quiet.
    private static func fillerGradient(rng: inout SeededRNG) -> Gradient {
        Gradient(colors: [
            Color(hue: 0.60, saturation: 0.05, brightness: 0.07),
            Color(hue: 0.60, saturation: 0.03, brightness: 0.04),
        ])
    }
}

// MARK: - Seeded RNG

struct SeededRNG {
    private var state: UInt64
    init(seed: Int) { state = UInt64(bitPattern: Int64(seed)) &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &* 0x9E3779B97F4A7C15
        state = (state ^ (state >> 30)) &* 0xBF58476D1CE4E5B9
        state = (state ^ (state >> 27)) &* 0x94D049BB133111EB
        return state ^ (state >> 31)
    }
    mutating func nextCGFloat(_ min: CGFloat, _ max: CGFloat) -> CGFloat {
        min + CGFloat(next() & 0xFFFF) / CGFloat(0xFFFF) * (max - min)
    }
}
