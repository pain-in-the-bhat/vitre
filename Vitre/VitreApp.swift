import SwiftUI
import AppKit

// MARK: - AppKit Menu Bar Controller

final class MenuBarController: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "Vitre")
            button.action = #selector(togglePopover)
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 340)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: VitreContentView())

        // Close popover when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            guard let button = statusItem.button else { return }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }
}

// MARK: - SwiftUI App

@main
struct VitreApp: App {
    @NSApplicationDelegateAdaptor(MenuBarController.self) var menuBar

    var body: some Scene {
        Settings { EmptyView() }
    }
}

// MARK: - Content View

struct VitreContentView: View {
    @State private var panes: [GlassPane] = []
    @State private var todaySummary: String = ""
    @State private var isLoading = true

    private let canvasSize = CGSize(width: 340, height: 220)

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                VStack {
                    ProgressView().controlSize(.small)
                    Text("Reading opencode.db…").font(.caption).foregroundStyle(.secondary)
                }
                .frame(width: canvasSize.width, height: canvasSize.height)
            } else {
                todayHeader
                StainedGlassView(panes: panes, size: canvasSize)
                metricsFooter
            }
        }
        .frame(width: canvasSize.width)
        .task { loadData() }
        .onReceive(Timer.publish(every: 3600, on: .main, in: .common).autoconnect()) { _ in loadData() }
    }

    private var todayHeader: some View {
        HStack {
            Text("Today").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            Spacer()
            Text(todaySummary).font(.system(size: 13, weight: .bold)).foregroundStyle(.primary)
        }
        .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 6)
    }

    private var metricsFooter: some View {
        let total = panes.reduce(0) { $0 + $1.intensity }
        let avg = panes.isEmpty ? 0 : total / Double(panes.count)
        let peak = panes.map(\.intensity).max() ?? 0
        return HStack(spacing: 16) {
            metric(label: "This Week", value: fmtPct(total / 30))
            metric(label: "Avg Daily", value: fmtPct(avg))
            metric(label: "Peak Day", value: fmtPct(peak))
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 9)).foregroundStyle(.tertiary)
            Text(value).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
        }
    }

    // MARK: - Data

    private func loadData() {
        DispatchQueue.global(qos: .userInitiated).async {
            let days = OpenCodeDB.dailyAggregates(days: 30)
            let maxTokens = days.map({ $0.tokens }).max() ?? 1
            let today = days.last

            let renderer = GlassRenderer(
                seed: monthSeed(), canvasWidth: canvasSize.width,
                canvasHeight: canvasSize.height, todayIndex: max(0, days.count - 1)
            )
            var generated = renderer.generate()

            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
            let cal = Calendar.current

            for i in generated.indices {
                if i < days.count {
                    let d = days[i]
                    let intensity = maxTokens > 0 ? Double(d.tokens) / Double(maxTokens) : 0
                    generated[i].intensity = intensity
                    generated[i].glow = intensity > 0.7 ? 0.6 : intensity * 0.3
                    generated[i].gradient = GlassRenderer.cathedralGradient(for: intensity, isToday: i == days.count - 1)
                    generated[i].label = "\(d.date)\n\(fmt(d.tokens))\n\(d.sessions) sessions"

                    // Date labels
                    if let date = df.date(from: d.date) {
                        let dayNum = cal.component(.day, from: date)
                        generated[i].dateLabel = "\(dayNum)"
                        let wf = DateFormatter(); wf.dateFormat = "EEE"
                        generated[i].weekdayLabel = wf.string(from: date)
                    }
                }
            }

            let summary = today.map { fmt($0.tokens) } ?? "Quiet Day"
            DispatchQueue.main.async {
                panes = generated; todaySummary = summary; isLoading = false
            }
        }
    }

    private func monthSeed() -> Int {
        let f = DateFormatter(); f.dateFormat = "yyyyMM"
        return Int(f.string(from: Date())) ?? 202601
    }

    private func fmt(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM Tokens", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fK Tokens", Double(n) / 1_000) }
        return "\(n) Tokens"
    }

    private func fmtPct(_ v: Double) -> String {
        String(format: "%.0f%%", min(v * 100, 100))
    }
}
