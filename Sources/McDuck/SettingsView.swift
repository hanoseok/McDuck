import SwiftUI

/// Compact settings panel shown from the header gear button. Holds the
/// launch-at-login toggle today; future preferences slot in below it.
struct SettingsView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)

            if settings.isLoginItemAvailable {
                Toggle(isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at Login")
                            .font(.subheadline)
                        Text("Start McDuck automatically when you log in.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                if settings.loginItemNeedsApproval {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("Approval needed in System Settings.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open") {
                            settings.openLoginItemsSettings()
                        }
                        .mcDuckGlassButton()
                        .controlSize(.small)
                    }
                }
            } else {
                Text("Launch at Login is unavailable for this build.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = settings.loginItemError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Menu bar")
                    .font(.subheadline)
                Text("Usage window shown next to the icon (tokens over cost).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Picker("Menu bar", selection: Binding(
                    get: { settings.menuBarPeriod },
                    set: { settings.setMenuBarPeriod($0) }
                )) {
                    ForEach(MenuBarPeriod.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Claude Code plugin")
                    .font(.subheadline)
                Text("Register McDuck's MCP server + usage skill in Claude Code.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    if settings.isPluginInstalled {
                        Button {
                            Task { await settings.uninstallPlugin() }
                        } label: {
                            Label("Remove from Claude Code", systemImage: "trash")
                        }
                        .mcDuckGlassButton()
                        .controlSize(.small)
                        .disabled(settings.isInstallingPlugin)
                    } else {
                        Button {
                            Task { await settings.installPlugin() }
                        } label: {
                            Label("Add to Claude Code", systemImage: "puzzlepiece.extension")
                        }
                        .mcDuckGlassButton()
                        .controlSize(.small)
                        .disabled(settings.isInstallingPlugin)
                    }

                    if settings.isInstallingPlugin {
                        ProgressView().controlSize(.small)
                    }
                }

                switch settings.pluginInstallPhase {
                case .done(let message):
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                case .failed(let message):
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                case .idle, .installing:
                    EmptyView()
                }
            }
        }
        .padding(14)
        .frame(width: 260, alignment: .leading)
        .onAppear {
            settings.refreshLoginItemState()
            settings.refreshPluginInstalled()
        }
    }
}
