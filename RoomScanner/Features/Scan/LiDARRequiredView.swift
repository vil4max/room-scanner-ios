import SwiftUI

struct LiDARRequiredView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            Image(systemName: "sensor.tag.radiowaves.forward.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Color.accent)
            Text("LiDAR Required")
                .font(Theme.Font.screenTitle)
                .foregroundStyle(Theme.Color.primaryText)
            Text("RoomScanner needs an iPhone or iPad with a LiDAR scanner.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Color.screenBackground)
    }
}
