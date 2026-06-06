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
        }
        .padding(14)
        .frame(width: 260, alignment: .leading)
        .onAppear { settings.refreshLoginItemState() }
    }
}
