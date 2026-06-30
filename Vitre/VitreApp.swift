import SwiftUI
import AppKit

// MARK: - AppKit Menu Bar

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
        popover.contentSize = NSSize(width: 340, height: 380)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: VitreContentView())

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    @objc private func togglePopover() {
        if popover.isShown { closePopover() }
        else { guard let b = statusItem.button else { return }; popover.show(relativeTo: b.bounds, of: b, preferredEdge: .minY) }
    }

    private func closePopover() {
        if popover.isShown { popover.performClose(nil) }
    }
}

// MARK: - SwiftUI App

@main
struct VitreApp: App {
    @NSApplicationDelegateAdaptor(MenuBarController.self) var menuBar
    var body: some Scene { Settings { EmptyView() } }
}

// MARK: - Content

struct VitreContentView: View {
    @State private var panes: [GlassPane] = []
    @State private var todaySummary: String = ""
    @State private var isLoading = true

    private let windowDiameter: CGFloat = 290

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView().controlSize(.small)
                    .frame(width: windowDiameter, height: windowDiameter + 40)
            } else {
                // Clean header — just today
                Text("Today")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 14)
                Text(todaySummary)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.bottom, 10)

                // Rose window
                RoseWindow(panes: panes, diameter: windowDiameter)
                    .padding(.bottom, 14)
            }
        }
        .frame(width: windowDiameter + 20)
        .task { loadData() }
        .onReceive(Timer.publish(every: 3600, on: .main, in: .common).autoconnect()) { _ in loadData() }
    }

    private func loadData() {
        DispatchQueue.global(qos: .userInitiated).async {
            let days = OpenCodeDB.dailyAggregates(days: 30)
            let maxTokens = days.map({ $0.tokens }).max() ?? 1

            // Sort days: today first (index 0), then yesterday (1), etc.
            let sorted = Array(days.reversed())
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
            let cal = Calendar.current

            let renderer = RoseRenderer(seed: monthSeed(), diameter: windowDiameter)
            var generated = renderer.generate()

            for i in generated.indices {
                let pane = generated[i]
                if pane.isFiller { continue }  // skip decorative gaps
                if pane.dayIndex < sorted.count && pane.dayIndex >= 0 {
                    let d = sorted[pane.dayIndex]
                    let intensity = maxTokens > 0 ? Double(d.tokens) / Double(maxTokens) : 0
                    generated[i].intensity = intensity
                    generated[i].glow = intensity > 0.6 ? intensity * 0.5 : 0
                    generated[i].sessions = d.sessions
                    var rng = SeededRNG(seed: monthSeed() + i)
                    generated[i].gradient = RoseRenderer.palette(intensity, isToday: pane.dayIndex == 0, rng: &rng)

                    let wf = DateFormatter(); wf.dateFormat = "EEE"
                    var label = "\(d.date)\n\(fmt(d.tokens)) · \(d.sessions) sessions"
                    if let date = df.date(from: d.date) {
                        label = "\(wf.string(from: date))\n\(fmt(d.tokens))\n\(d.sessions) sessions"
                    }
                    generated[i].label = label
                }
            }

            let summary = sorted.first.map { fmt($0.tokens) } ?? "Quiet Day"
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
}
