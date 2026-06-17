import SwiftUI

struct ScanStatusBanner: View {
    enum Style {
        case neutral
        case warning
        case danger
    }

    let message: String
    let style: Style

    var body: some View {
        Text(message)
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.medium)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var backgroundColor: Color {
        switch style {
        case .neutral:
            Theme.Color.cardBackground
        case .warning:
            Theme.Color.warning.opacity(0.25)
        case .danger:
            Theme.Color.danger.opacity(0.25)
        }
    }
}
