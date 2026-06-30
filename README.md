# Vitre

A macOS menu bar app that transforms your daily OpenCode token usage into a living stained-glass window.

One flame in the menu bar. Click it — a cathedral-glass panel appears. Each day is an irregular pane of colored glass. Indigo whispers quiet days. Amber glows with activity. Gold blazes on heavy burn days. Lead outlines separate the panes. Click any pane to reveal its story.

## Design

Vitre is not a dashboard. It's an ambient artifact — a piece of digital craftsmanship that quietly reflects your month of building software with AI. The window should feel handcrafted, not algorithmic.

**Cathedral palette:** indigo → teal → amber → gold. Cold panes mean the subscription is idle. Warm panes mean it's earning.

**Irregular geometry:** each day is a unique glass shard with jittered vertices and slight concavity. The tessellation is seeded by month, so the same month always produces the same window — but no two months look alike.

**Information without dashboards:** today's token count dominates the header. Three metrics below the window — this week, average daily, peak day. The panes tell the rest.

**Click to explore:** tap any pane to see its date, token count, and session count. Today's pane is pre-selected.

## Install

```bash
brew install xcodegen
cd vitre && xcodegen generate
open Vitre.xcodeproj
# ⌘B, then ⌘R
```

Requires macOS 14+ and [OpenCode](https://opencode.ai) with its database at `~/.local/share/opencode/opencode.db`.

## Architecture

```
Vitre/
├── VitreApp.swift        — AppKit NSStatusItem + NSPopover, data loading
├── StainedGlassView.swift — PaneShape, PaneView, tooltip, click interaction
├── GlassRenderer.swift   — GlassPane model, jittered tessellation, cathedral palette
└── OpenCodeDB.swift      — Direct SQLite read from opencode.db

project.yml               — XcodeGen spec
```

~500 lines of Swift. No dependencies. Reads opencode.db directly — no sandbox, no provisioning, no data pipeline.

## Liquid Glass

When Xcode 26 ships with macOS Tahoe, upgrade `PaneView` to use native `.glassEffect(.regular.tint())` instead of gradient fills. The palette stays the same; the glass becomes real.

## License

MIT
