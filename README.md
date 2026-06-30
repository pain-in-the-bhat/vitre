# Vitre

A macOS menu bar app that shows your daily OpenCode token burn as a stained-glass heatmap. Glance at it: the grid tells you whether your $10/month is earning itself.

One flame in the menu bar. Click it, see 30 days of ember-tinted glass tiles. Bright = heavy burn. Dark = quiet day. No badges, no streaks, no judgment. Just the ambient temperature of your usage.

## Install

```bash
brew install xcodegen
cd vitre && xcodegen generate
open Vitre.xcodeproj
# In Xcode: ⌘B, then ⌘R
```

Requires macOS 14+ (MenuBarExtra) and [OpenCode](https://opencode.ai) with its SQLite database at `~/.local/share/opencode/opencode.db`.

## How It Works

Vitre reads `opencode.db` directly — no sandbox, no data pipeline, no inter-process sharing. The menu bar app opens the SQLite file, runs a single aggregation query (`GROUP BY date`), and renders a 7×5 grid of glass tiles.

- **30-day rolling window** — Monday-aligned weeks
- **Log-scale ember colors** — visible differentiation from 10K to 134M tokens
- **Today marker** — subtle white stroke on the current day's cell
- **Footer** — today's token count and session count
- **Auto-refresh** — every hour via background timer
- **Pure menu bar** — no dock icon, no window, lives in `LSUIElement` mode

## Architecture

```
Vitre/
├── VitreApp.swift        — MenuBarExtra + popover host, timer refresh
├── HeatmapView.swift     — 7×5 grid, day labels, today footer
├── GlassTile.swift       — Colored tile (regularMaterial base, upgrade to .glassEffect at macOS 26)
├── EmberScale.swift      — Log-scale orange tint mapping (10K→∞)
└── OpenCodeDB.swift      — Direct SQLite read, DayAggregate model

project.yml               — XcodeGen project spec
```

~300 lines of Swift. No dependencies. No external libraries.

## Liquid Glass

The current version uses `.regularMaterial` for the glass-tile depth effect. When targeting macOS Tahoe 26 (Xcode 26), upgrade `GlassTile.swift`:

```swift
// Before
RoundedRectangle(cornerRadius: 4)
    .fill(tint)
    .background(.regularMaterial, in: .rect(cornerRadius: 4))

// After
RoundedRectangle(cornerRadius: 4)
    .fill(.clear)
    .glassEffect(.regular.tint(tint), in: .rect(cornerRadius: 4))
```

The tint colors will infuse into the actual Liquid Glass material — true stained glass, not a material approximation.

## Design Reference

Apple Liquid Glass design system quarried at `~/Developer/projects/design/liquid-glass.md`.

## License

MIT