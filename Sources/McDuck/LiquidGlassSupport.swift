import SwiftUI

extension View {
    @ViewBuilder
    func mcDuckGlass(cornerRadius: CGFloat = 18) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.interactive(true), in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
        }
    }

    /// Liquid Glass button style (macOS 26+), with a bordered fallback.
    @ViewBuilder
    func mcDuckGlassButton(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else {
            if prominent {
                self.buttonStyle(.borderedProminent)
            } else {
                self.buttonStyle(.bordered)
            }
        }
    }
}

struct McDuckGlassContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 12) {
                content
            }
        } else {
            content
        }
    }
}
