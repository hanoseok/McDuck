# McDuck Wiki Update Log

## 2026-06-21
* **UX adjustment**: Removed the visible usage reload text from the main footer action, leaving the ccusage updated time plus an icon-only control.
* **UX adjustment**: Restored the footer's last ccusage refresh time and kept its reload action scoped to usage data only.
* **UX adjustment**: Added version information and update checking back into Settings above Quit while keeping the compact footer behavior.
* **UX adjustment**: Simplified the popover footer so usage reload is the left action, while the right side shows the app version and only reveals Update when a release is available.
* **UX adjustment**: Moved Quit into the Settings panel and moved update controls to the main popover footer's lower-right action area.
* **Feature**: Added planning/implementation notes for settings-driven app updates: Release builds check official `releases/latest`, Snapshot builds check `snapshot-latest`, and installation opens the channel-matched `.pkg` with macOS Installer.
* **Initialization**: Created the OKF-style `wiki/` bundle for McDuck project knowledge.
* **Creation**: Added root navigation, project overview, architecture/module maps, progress, decisions, retrospectives, runbooks, references, and templates.
* **Reference**: Captured the Open Knowledge Format source material in [Open Knowledge Format](references/open-knowledge-format.md).
