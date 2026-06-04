import SwiftUI

struct SetupView: View {
    let requirement: UsageStore.SetupRequirement
    let isInstalling: Bool
    let log: String?
    let action: () -> Void
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "shippingbox.and.arrow.down")
                    .font(.title3)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 3) {
                    Text(requirement.title)
                        .font(.headline)
                    Text(requirement.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                action()
            } label: {
                Label(requirement.actionTitle, systemImage: requirement.actionSystemImage)
                    .frame(maxWidth: .infinity)
            }
            .mcDuckGlassButton(prominent: true)
            .controlSize(.large)
            .disabled(isInstalling)

            if let secondaryTitle, let secondaryAction {
                Button(secondaryTitle, action: secondaryAction)
                    .mcDuckGlassButton()
                    .controlSize(.small)
                    .disabled(isInstalling)
            }

            if isInstalling {
                ProgressView()
                    .controlSize(.small)
            }

            if let log, !log.isEmpty {
                Text(log)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
        .padding(14)
        .mcDuckGlass()
    }
}
