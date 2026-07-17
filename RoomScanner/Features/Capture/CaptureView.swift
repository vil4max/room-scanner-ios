import SwiftUI

struct CaptureView: View {
    @Bindable var viewModel: CaptureViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            Text("AI Capture")
                .font(Theme.Font.screenTitle)
                .foregroundStyle(Theme.Color.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(viewModel.statusMessage)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Theme.Spacing.medium) {
                MetricCard(title: "Frames", value: "\(viewModel.frameCount)")
                MetricCard(title: "Depth", value: "\(viewModel.depthCount)")
            }

            if let errorMessage = viewModel.errorMessage {
                ScanStatusBanner(message: errorMessage, style: .warning)
            }

            Spacer(minLength: 0)

            Button {
                Task { await viewModel.toggleRecording() }
            } label: {
                Text(viewModel.isRecording ? "Stop & Export" : "Start Recording")
                    .font(Theme.Font.button)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.medium)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isRecording ? Theme.Color.danger : Theme.Color.accent)

            if let shareURL = viewModel.shareURL {
                ShareLink(item: shareURL) {
                    Text("Share Session Folder")
                        .font(Theme.Font.button)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.small)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(Theme.Spacing.medium)
        .background(Theme.Color.screenBackground.ignoresSafeArea())
        .onAppear(perform: viewModel.onAppear)
        .onDisappear(perform: viewModel.onDisappear)
        .task(id: viewModel.isRecording) {
            while !Task.isCancelled && viewModel.isRecording {
                viewModel.refreshCounts()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }
}
