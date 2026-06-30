import SwiftUI

/// A 7×5 stained-glass heatmap grid. Columns = days of week (Mon–Sun),
/// rows = weeks. Each cell is a Liquid Glass tile with tint intensity
/// proportional to daily token burn.
struct HeatmapView: View {
    let days: [DayAggregate]
    let maxTokens: Int

    // MARK: - Grid computation

    /// 35 slots (7 cols × 5 rows) covering the 30-day window.
    private var cells: [Cell] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -29, to: today)!

        // Align grid start to Monday of the week containing `start`.
        let weekday = calendar.component(.weekday, from: start) // 1=Sun, 2=Mon
        let offsetToMonday = weekday == 1 ? -6 : -(weekday - 2)
        let gridStart = calendar.date(byAdding: .day, value: offsetToMonday, to: start)!

        // Build lookup.
        var lookup: [String: DayAggregate] = [:]
        for day in days { lookup[day.date] = day }

        return (0..<35).map { i in
            let date = calendar.date(byAdding: .day, value: i, to: gridStart)!
            let key = Self.dateString(date)
            let tokens = lookup[key]?.tokens ?? 0
            let inRange = date >= start && date <= today
            let isToday = calendar.isDate(date, inSameDayAs: today)
            return Cell(date: date, tokens: inRange ? tokens : -1, isToday: isToday)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            headerView

            // Grid with day-of-week labels
            HStack(alignment: .top, spacing: 4) {
                dayLabels
                gridView
            }

            // Footer — today summary
            footerSummary
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text("Vitre")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("30 days")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    private var dayLabels: some View {
        VStack(spacing: 3) {
            ForEach(Self.daySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(height: cellSize)
            }
        }
    }

    private var gridView: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)
        return LazyVGrid(columns: columns, spacing: 3) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                cellView(for: cell)
            }
        }
    }

    @ViewBuilder
    private func cellView(for cell: Cell) -> some View {
        let color = cell.tokens >= 0
            ? EmberScale.tint(for: cell.tokens, maxTokens: maxTokens)
            : Color(white: 0.12)

        GlassTile(tint: color, isToday: cell.isToday, size: cellSize)
    }

    @ViewBuilder
    private var footerSummary: some View {
        let todayKey = Self.dateString(Date())
        if let today = days.first(where: { $0.date == todayKey }) {
            HStack(spacing: 6) {
                Circle()
                    .fill(.white.opacity(0.5))
                    .frame(width: 5, height: 5)
                Text("Today")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("·").foregroundStyle(.tertiary)
                Text(Self.formatTokens(today.tokens))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("·").foregroundStyle(.tertiary)
                Text("\(today.sessions) sessions")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private var cellSize: CGFloat { 20 }

    private static let daySymbols = ["M", "T", "W", "T", "F", "S", "S"]

    private static func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - Cell model

private struct Cell {
    let date: Date
    let tokens: Int   // -1 = outside range
    let isToday: Bool
}
