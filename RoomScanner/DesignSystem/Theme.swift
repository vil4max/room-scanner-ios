import SwiftUI

enum Theme {
    enum Color {
        static let screenBackground = SwiftUI.Color(red: 0.07, green: 0.08, blue: 0.10)
        static let cardBackground = SwiftUI.Color(red: 0.12, green: 0.13, blue: 0.16)
        static let primaryText = SwiftUI.Color.white
        static let secondaryText = SwiftUI.Color(white: 0.65)
        static let accent = SwiftUI.Color(red: 0.20, green: 0.55, blue: 0.95)
        static let warning = SwiftUI.Color(red: 0.95, green: 0.65, blue: 0.20)
        static let danger = SwiftUI.Color(red: 0.95, green: 0.30, blue: 0.30)
    }

    enum Font {
        static let screenTitle = SwiftUI.Font.system(.title2, design: .rounded).weight(.semibold)
        static let metricValue = SwiftUI.Font.system(.title3, design: .rounded).weight(.semibold)
        static let metricTitle = SwiftUI.Font.system(.caption, design: .rounded).weight(.medium)
        static let body = SwiftUI.Font.system(.body, design: .rounded)
        static let caption = SwiftUI.Font.system(.caption, design: .rounded)
        static let button = SwiftUI.Font.system(.headline, design: .rounded).weight(.semibold)
    }

    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }
}
