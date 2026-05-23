# McDuck Native Menu Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar app that shows `ccusage` token usage in a Liquid Glass SwiftUI popover.

**Architecture:** Use a Swift Package with a testable `McDuckCore` library and a native `McDuck` executable target. Core owns command execution, dependency checks, JSON parsing, and heatmap transformation; the app target owns `MenuBarExtra`, SwiftUI views, Liquid Glass styling, and packaging metadata.

**Tech Stack:** Swift 6.3, macOS 26 SDK, SwiftUI `MenuBarExtra`, Swift Charts, Liquid Glass `glassEffect`, XCTest, Swift Package Manager.

---

### Task 1: Core Tests And Package Skeleton

**Files:**
- Create: `Package.swift`
- Create: `Sources/McDuckCore/McDuckCore.swift`
- Create: `Tests/McDuckCoreTests/CcusageParserTests.swift`
- Create: `Tests/McDuckCoreTests/HeatmapBuilderTests.swift`
- Create: `Tests/McDuckCoreTests/DependencyManagerTests.swift`

- [ ] **Step 1: Write failing parser, heatmap, and dependency tests**

Create XCTest coverage for:

- Modern `ccusage daily --json --breakdown`
- Alternate `daily`/`totals` JSON
- Date-ordered heatmap cells and token intensity buckets
- Missing Bun detection
- Ready `bunx ccusage --version` detection
- Failed `bunx ccusage --version` detection

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`

Expected: FAIL because `CcusageParser`, `HeatmapBuilder`, `DependencyManager`, and related models are not implemented.

### Task 2: Core Implementation

**Files:**
- Modify: `Sources/McDuckCore/McDuckCore.swift`
- Create: `Sources/McDuckCore/Models.swift`
- Create: `Sources/McDuckCore/CcusageParser.swift`
- Create: `Sources/McDuckCore/HeatmapBuilder.swift`
- Create: `Sources/McDuckCore/CommandRunner.swift`
- Create: `Sources/McDuckCore/BunLocator.swift`
- Create: `Sources/McDuckCore/DependencyManager.swift`
- Create: `Sources/McDuckCore/CcusageClient.swift`

- [ ] **Step 1: Implement minimal core behavior**

Implement the public API required by the tests:

- `UsageDay`
- `ModelUsage`
- `UsageReport`
- `CcusageParser`
- `HeatmapCell`
- `HeatmapBuilder`
- `CommandRequest`
- `CommandResult`
- `CommandRunner`
- `ProcessCommandRunner`
- `BunLocating`
- `StaticBunLocator`
- `BunLocator`
- `DependencyStatus`
- `DependencyManager`
- `CcusageClient`

- [ ] **Step 2: Run tests to verify they pass**

Run: `swift test`

Expected: PASS.

- [ ] **Step 3: Commit**

Run:

```bash
git add Package.swift Sources/McDuckCore Tests/McDuckCoreTests
git commit -m "feat: add ccusage core"
```

### Task 3: Native Menu Bar App

**Files:**
- Create: `Sources/McDuck/McDuckApp.swift`
- Create: `Sources/McDuck/UsageStore.swift`
- Create: `Sources/McDuck/LiquidGlassSupport.swift`
- Create: `Sources/McDuck/McDuckPopover.swift`
- Create: `Sources/McDuck/HeatmapGrid.swift`
- Create: `Sources/McDuck/UsageDetailView.swift`
- Create: `Sources/McDuck/SetupView.swift`

- [ ] **Step 1: Add SwiftUI menu bar executable**

Implement:

- `@main` SwiftUI app with `MenuBarExtra("McDuck", systemImage: "chart.bar.xaxis")`
- `.menuBarExtraStyle(.window)`
- `@Observable` `UsageStore`
- Loading, setup, loaded, empty, and error states
- Heatmap-first popover
- Refresh, setup, retry, and quit actions
- Swift Charts daily summary bars
- Liquid Glass styling with `GlassEffectContainer` and `glassEffect`

- [ ] **Step 2: Build the app**

Run: `swift build`

Expected: PASS.

- [ ] **Step 3: Commit**

Run:

```bash
git add Sources/McDuck
git commit -m "feat: add native menu bar UI"
```

### Task 4: App Bundle Packaging And Docs

**Files:**
- Create: `Resources/McDuck.iconset/`
- Create: `Resources/Info.plist`
- Create: `scripts/build-app.sh`
- Modify: `README.md`

- [ ] **Step 1: Add packaging script**

Create a script that runs `swift build -c release`, creates `dist/McDuck.app`, copies the executable into `Contents/MacOS`, writes `Info.plist`, and sets `LSUIElement=true`.

- [ ] **Step 2: Document local build and run**

Update README with:

- Requirements
- `swift test`
- `swift build`
- `scripts/build-app.sh`
- How setup works for Bun and `ccusage`

- [ ] **Step 3: Verify packaging**

Run: `scripts/build-app.sh`

Expected: `dist/McDuck.app/Contents/MacOS/McDuck` exists and `Info.plist` contains `LSUIElement`.

- [ ] **Step 4: Commit**

Run:

```bash
git add Resources scripts README.md
git commit -m "chore: package mac app"
```

### Task 5: Final Verification

**Files:**
- No expected source edits unless verification exposes a bug.

- [ ] **Step 1: Run full tests**

Run: `swift test`

Expected: PASS.

- [ ] **Step 2: Run release build**

Run: `swift build -c release`

Expected: PASS.

- [ ] **Step 3: Run package script**

Run: `scripts/build-app.sh`

Expected: PASS and app bundle present.

- [ ] **Step 4: Inspect git state**

Run: `git status --short`

Expected: clean or only intentionally uncommitted generated artifacts excluded by `.gitignore`.
