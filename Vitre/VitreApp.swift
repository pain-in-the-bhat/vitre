import SwiftUI

@main
struct VitreApp: App {
    var body: some Scene {
        MenuBarExtra("Vitre", systemImage: "flame.fill") {
            VitreView()
        }
        .menuBarExtraStyle(.window)
    }
}

struct VitreView: View {
    @State private var days: [DayAggregate] = []
    @State private var maxTokens: Int = 1
    @State private var lastRefresh: Date = .distantPast

    var body: some View {
        VStack(spacing: 0) {
            if days.isEmpty {
                Text("Reading opencode.db…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 280)
            } else {
                HeatmapView(days: days, maxTokens: maxTokens)
            }
        }
        .frame(width: 340, height: 280)
        .background(.black.opacity(0.0))
        .task { refresh() }
        .onReceive(Timer.publish(every: 3600, on: .main, in: .common).autoconnect()) { _ in refresh() }
    }

    private func refresh() {
        DispatchQueue.global(qos: .userInitiated).async {
            let d = OpenCodeDB.dailyAggregates(days: 30)
            let mx = d.map({ $0.tokens }).max() ?? 1
            DispatchQueue.main.async {
                days = d
                maxTokens = mx
                lastRefresh = Date()
            }
        }
    }
}