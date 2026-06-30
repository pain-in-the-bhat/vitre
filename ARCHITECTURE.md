# Vitre — Architecture & Post-Mortem

## Vision

A macOS widget that shows daily OpenCode token burn as a stained-glass heatmap.
Glance at it: the grid tells you whether your $10/month is earning itself.

One syllable. No dashboard energy. Just the glass.

---

## Final Architecture (What Exists)

```
Vitre.xcodeproj
├── Vitre (macOS app target)
│   ├── VitreApp.swift          — launches, calls DataPublisher
│   ├── DataPublisher.swift     — reads 595MB opencode.db in-memory,
│   │                             queries 30-day aggregates, outputs JSON
│   └── Vitre.entitlements      — temp-exception for DB read
│
└── VitreWidget (WidgetKit extension)
    ├── VitreWidgetBundle.swift  — @main widget entry
    ├── VitreWidget.swift        — TimelineProvider + .systemLarge widget
    ├── HeatmapView.swift        — 7×5 ember-tinted grid, day labels, footer
    ├── GlassTile.swift          — colored tile with .regularMaterial depth
    ├── EmberScale.swift         — log-scale orange tint mapping (10K→134M)
    ├── OpenCodeDB.swift         — DayAggregate model, in-memory DB reader
    ├── AppGroupReader.swift     — data ingestion point (currently broken)
    └── VitreWidget.entitlements — App Sandbox (required for registration)
```

### Data Flow (Intended)

```
opencode.db (592MB, ~/.local/share/opencode/)
    │
    ▼  Data(contentsOf:) — respects temp-exception
    │
    ▼  sqlite3_deserialize → in-memory DB
    │
    ▼  SQL: GROUP BY date → [DayAggregate]
    │
    ▼  JSONEncoder → daily_aggregates.json
    │
    ▼  ???  ← THIS IS THE BROKEN LINK
    │
    ▼  Widget TimelineProvider
    │
    ▼  HeatmapView (7×5 ember grid)
```

### What Works

| Component | Status |
|-----------|--------|
| DB read (in-memory deserialize) | ✅ Proven. 595MB → 19 rows in <5s |
| SQL query (GROUP BY, 30-day window) | ✅ 600M tokens, 19 days |
| Widget registration | ✅ App Sandbox enables gallery visibility |
| Heatmap UI (grid, colors, footer) | ✅ Renders correctly |
| Liquid Glass approximation (.regularMaterial) | ✅ Shipped, upgrade to .glassEffect() at Xcode 26 |
| Ember color scale (log-normalized) | ✅ Visible differentiation 10K→134M |
| Build system (xcodegen + xcodebuild) | ✅ Zero config, `project.yml` → `.xcodeproj` |

### What Doesn't Work

**Data cannot cross from the main app to the widget extension.**

---

## The Data Plumbing Saga

Every approach tried, in order, with the exact failure mode.

### Approach 1: Widget Reads DB Directly
**Method:** `sqlite3_open_v2(path, SQLITE_OPEN_READONLY)` in widget target.
**Entitlement:** `com.apple.security.temporary-exception.files.home-relative-path.read-only`
**Result:** `SQLITE_AUTH` (rc=23). Sandbox blocks SQLite's internal file operations even with temp exception. Widget extensions appear to ignore temp exceptions entirely.

### Approach 2: App Reads DB → App Group (FileManager)
**Method:** App uses `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)` to write JSON. Widget reads from same.
**Entitlements:** App Sandbox + App Groups on both targets.
**Result:** Widget's `containerURL(...)` returns nil. App can write, widget cannot read. Investigation revealed provisioning profile does NOT include App Groups entitlement (free account limitation).

### Approach 3: App Group via UserDefaults
**Method:** `UserDefaults(suiteName: "group.xyz.gurubhat.vitre")` 
**Result:** Suite does not exist. Same provisioning issue.

### Approach 4: App Group via Direct Filesystem Path
**Method:** Widget reads from `~/Library/Group Containers/group.xyz.gurubhat.vitre/daily_aggregates.json` via `Data(contentsOf:)`.
**Result:** Sandbox blocks direct filesystem access. Entitlements only work through containerURL, not raw paths.

### Approach 5: Widget Reads App's Container (String Replacement)
**Method:** Widget replaces `xyz.gurubhat.vitre.widget` with `xyz.gurubhat.vitre` in `NSHomeDirectory()` to construct app container path.
**Result:** Sandbox blocks cross-container reads. Extensions cannot read parent app's container via filesystem.

### Approach 6: App Writes into Widget's Container
**Method:** App replaces its bundle ID with widget's bundle ID and writes JSON there. Widget reads from own container.
**Result:** Sandbox blocks cross-container writes. Even with App Sandbox disabled on the app, the system prevents writing to another app's container.

### Approach 7: Keychain Sharing
**Method:** App writes to keychain with `kSecAttrAccessGroup: "3BHALMRSXD.xyz.gurubhat.vitre"`. Widget reads.
**Entitlement:** `keychain-access-groups: ["3BHALMRSXD.*"]` (present in provisioning profile).
**Result:** Widget's `SecItemCopyMatching` returns `errSecItemNotFound`. Widget either can't access shared keychain items or the access group doesn't match at runtime. No embedded provisioning profile found in widget bundle — entitlement may not be active.

### Approach 8: Local HTTP Server
**Method:** App runs `NWListener` on localhost:19876. Widget fetches via `Data(contentsOf: URL)`.
**Entitlements:** `com.apple.security.network.server` (app) + `com.apple.security.network.client` (widget).
**Result:** `NWListener` fails to start. Network server entitlement not in provisioning profile.

### Approach 9: Widget Reads DB via Foundation (In-Memory, No SQLite File Ops)
**Method:** Widget uses `Data(contentsOf:)` to read DB into memory, then `sqlite3_deserialize` to open in-memory. Same technique that works in the main app.
**Entitlement:** Temp exception on widget.
**Result:** `Data(contentsOf:)` also blocked by widget sandbox. Temp exception not honored for extensions.

---

## Root Cause Analysis

### The Sandbox Wall

macOS widget extensions run in a **strict sandbox** that is more restrictive than the containing app:

```
┌─────────────────────────────────────────────────┐
│  MAIN APP (Vitre)                                │
│  ✅ temp-exception honored                       │
│  ✅ can read opencode.db                         │
│  ✅ can write to own container                   │
│  ❌ cannot write to widget container             │
│  ❌ cannot write to App Group (no provisioning)   │
│  ❌ cannot start network server (no provisioning) │
│                                                  │
│              ═══ WALL ═══                        │
│                                                  │
│  WIDGET EXTENSION (VitreWidget)                  │
│  ✅ App Sandbox enables registration              │
│  ❌ temp-exception NOT honored                    │
│  ❌ cannot read files outside container           │
│  ❌ App Group containerURL returns nil             │
│  ❌ keychain sharing returns empty                │
│  ❌ cannot read parent app container              │
│  ✅ can read from own container                   │
└─────────────────────────────────────────────────┘
```

### The Free Account Ceiling

Apple Developer Program (free) provisioning profiles include:
- `application-identifier`
- `team-identifier`
- `keychain-access-groups`

They do NOT include:
- `com.apple.security.application-groups` (App Groups)
- `com.apple.security.network.server` (inbound networking)
- Any custom entitlements beyond the baseline

**App Groups** require manual creation in the Developer Portal, which is only available with a paid account ($99/yr). Without App Groups in the provisioning profile, the entitlement in the code signature is inactive — the system ignores it at runtime.

**Keychain sharing** IS in the free provisioning (`keychain-access-groups: ["*"]`), but our implementation didn't work. Possible reasons:
1. Widget extension's provisioning profile may differ from the app's
2. Access group string mismatch
3. Widget process can't access keychain at all in sandbox

---

## Path Ahead

### Option A: Menu Bar App (Recommended — Free)

Abandon WidgetKit. Build Vitre as a native macOS menu bar app (like `recall`).

**Advantages:**
- No sandbox restrictions — direct DB access
- Full SwiftUI control — proper Liquid Glass when Xcode 26 ships
- Popover can show the heatmap on click
- Lives in menu bar, always visible
- Reuses all existing UI code (HeatmapView, GlassTile, EmberScale)
- No provisioning issues
- Can auto-refresh on a timer

**Effort:** ~2 hours. Drop widget target, move HeatmapView into app, add menu bar icon + popover. The data pipeline already works — just needs a host that isn't sandboxed to death.

**Tradeoff:** Not in Notification Center. Click to see instead of glance. But the menu bar is arguably more visible than the widget panel.

### Option B: Paid Developer Account ($99/yr)

Enables App Groups provisioning. The widget approach works immediately.

**Steps:**
1. Enroll in Apple Developer Program
2. Create App Group ID `group.xyz.gurubhat.vitre` in Developer Portal
3. Xcode auto-provisions with App Group included
4. App writes to App Group container → Widget reads from it
5. Everything else is already built

**Effort:** ~15 minutes after enrollment. All code is written.

### Option C: Debug Keychain Further

The free provisioning DOES include `keychain-access-groups`. There may be a configuration issue:

1. Widget needs `Keychain Access Groups` capability added in Xcode's Signing & Capabilities (not just entitlements file)
2. Access group string might need to match exactly: `$(AppIdentifierPrefix)xyz.gurubhat.vitre`
3. May need `com.apple.security.application-groups` entitlement even for keychain sharing (contradictory but some reports suggest this)

**Effort:** Unknown. Could be 15 minutes or another dead end.

---

## Files Inventory

| File | Lines | Purpose |
|------|-------|---------|
| `project.yml` | 51 | XcodeGen project spec |
| `Vitre/VitreApp.swift` | 20 | App entry point |
| `Vitre/DataPublisher.swift` | 43 | DB → JSON pipeline |
| `Vitre/Vitre.entitlements` | 10 | App entitlements |
| `VitreWidget/VitreWidgetBundle.swift` | 8 | Widget bundle entry |
| `VitreWidget/VitreWidget.swift` | 59 | TimelineProvider + widget definition |
| `VitreWidget/HeatmapView.swift` | 158 | 7×5 grid, day labels, footer |
| `VitreWidget/GlassTile.swift` | 24 | Colored tile with material |
| `VitreWidget/EmberScale.swift` | 28 | Log-scale ember color map |
| `VitreWidget/OpenCodeDB.swift` | 52 | DayAggregate + in-memory DB reader |
| `VitreWidget/AppGroupReader.swift` | 12 | Data ingestion (broken link) |
| `VitreWidget/VitreWidget.entitlements` | 8 | Widget entitlements |
| `VitreWidget/Info.plist` | 30 | Extension point config |
| `README.md` | 60 | Build instructions |
| `~/design/liquid-glass.md` | 120 | Liquid Glass reference |

**Total:** ~600 lines of Swift, ~150 lines of config.

---

## Key Learnings

1. **Widget extensions on macOS are extremely sandboxed.** More than iOS widgets, more than the containing app. Almost no data-sharing mechanisms work without paid entitlements.

2. **Free Apple Developer accounts cannot use App Groups.** This is the single constraint that blocked every file-based approach. The provisioning profile simply doesn't include the entitlement.

3. **In-memory SQLite deserialization works around sandbox file-op restrictions.** Loading the DB via `Data(contentsOf:)` (Foundation) and deserializing into `:memory:` bypasses SQLite's temp-file issues. This is a portable pattern for sandboxed DB access.

4. **xcodegen's `entitlements` key can overwrite files.** The key in `project.yml` manages the entitlements file, which can blank it during regeneration. Safer to use only `CODE_SIGN_ENTITLEMENTS` in build settings.

5. **WKAppBundleIdentifier is not required for macOS widgets.** Microsoft Word's widget doesn't use it. Removing it simplified our Info.plist without affecting registration.

6. **CODE_SIGN_ALLOW_ENTITLEMENTS_MODIFICATION=YES** is needed when using `-allowProvisioningUpdates` from CLI — the provisioning process modifies entitlements files during build.

---

*Written June 29, 2026. 3 hours of debugging. 9 failed approaches. 1 working data pipeline with no delivery mechanism.*
