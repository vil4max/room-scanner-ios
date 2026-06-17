import SwiftUI

struct ScanView: View {
    @Bindable var viewModel: ScanViewModel
    let historyViewModel: ScanHistoryViewModel
    @State private var showsDevTools = false

    var body: some View {
        ZStack {
            ARViewContainer(
                session: viewModel.arSession,
                placementResetToken: viewModel.placementResetToken,
                onFigurePlaced: viewModel.handleFigurePlaced,
                onPlacementIssue: viewModel.handlePlacementIssue
            )
            .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.small) {
                HStack {
                    lidarBadge
                    Spacer()
                }
                if let guidanceMessage = viewModel.guidanceMessage, showsTrackingBanner {
                    ScanStatusBanner(message: guidanceMessage, style: viewModel.guidanceStyle)
                }
                if let placementNotice = viewModel.placementNotice {
                    placementNoticeBanner(placementNotice)
                }
                Spacer(minLength: 0)
                compactBottomBar
            }
            .padding(.horizontal, Theme.Spacing.medium)
            .padding(.top, Theme.Spacing.small)
            .padding(.bottom, Theme.Spacing.medium)
        }
        .background(Theme.Color.screenBackground)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: viewModel.onAppear)
        .onDisappear(perform: viewModel.onDisappear)
        .sheet(isPresented: $showsDevTools) {
            DevToolsSheet(
                viewModel: viewModel,
                historyViewModel: historyViewModel
            )
        }
    }

    private var lidarBadge: some View {
        HStack(spacing: Theme.Spacing.small) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
            Text("LiDAR ON")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.primaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay {
            Capsule()
                .stroke(Theme.Color.secondaryText.opacity(0.35), lineWidth: 1)
        }
        .clipShape(Capsule())
        .accessibilityLabel("LiDAR active")
    }

    private var compactBottomBar: some View {
        VStack(spacing: Theme.Spacing.small) {
            if !viewModel.hasPlacedFigure {
                Text("Tap the floor to place the figure")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.primaryText)
                    .padding(.horizontal, Theme.Spacing.medium)
                    .padding(.vertical, Theme.Spacing.small)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            } else {
                Text("Figure placed. Reset session in Scan details to place again.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.medium)
                    .padding(.vertical, Theme.Spacing.small)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
            Button {
                showsDevTools = true
            } label: {
                VStack(spacing: Theme.Spacing.small) {
                    Capsule()
                        .fill(Theme.Color.secondaryText.opacity(0.35))
                        .frame(width: 36, height: 4)
                    HStack(spacing: Theme.Spacing.medium) {
                        compactMetric(title: "Coverage", value: viewModel.coverageText)
                        compactMetric(title: "Mesh", value: viewModel.meshElementText)
                        compactMetric(title: "Time", value: viewModel.durationText)
                    }
                    Text("Scan details")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.secondaryText)
                }
                .padding(Theme.Spacing.medium)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Scan details")
            .accessibilityHint("Opens developer metrics and snapshot history")
        }
    }

    private func compactMetric(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)
            Text(value)
                .font(Theme.Font.metricTitle)
                .foregroundStyle(Theme.Color.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func placementNoticeBanner(_ message: String) -> some View {
        Text(message)
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.medium)
            .background(Theme.Color.cardBackground.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var showsTrackingBanner: Bool {
        viewModel.guidanceStyle == .warning || viewModel.guidanceStyle == .danger
    }
}

private struct DevToolsSheet: View {
    @Bindable var viewModel: ScanViewModel
    let historyViewModel: ScanHistoryViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                    metricsSection
                    resetSessionSection
                    historySection
                }
                .padding(Theme.Spacing.large)
            }
            .background(Theme.Color.screenBackground)
            .navigationTitle("Developer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text("Live Metrics")
                .font(Theme.Font.screenTitle)
                .foregroundStyle(Theme.Color.primaryText)
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: Theme.Spacing.medium
            ) {
                MetricCard(title: "Duration", value: viewModel.durationText)
                MetricCard(title: "Tracking", value: viewModel.trackingText)
                MetricCard(title: "Feature Points", value: viewModel.featurePointText)
                MetricCard(title: "Anchors", value: viewModel.anchorText)
                MetricCard(title: "Mesh Elements", value: viewModel.meshElementText)
                MetricCard(title: "Combined Points", value: viewModel.combinedPointText)
                MetricCard(title: "Coverage", value: viewModel.coverageText)
                MetricCard(title: "Quality", value: viewModel.quality.rawValue.capitalized)
            }
        }
    }

    private var resetSessionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text("Session")
                .font(Theme.Font.screenTitle)
                .foregroundStyle(Theme.Color.primaryText)
            Button("Reset session") {
                viewModel.resetSession()
            }
            .font(Theme.Font.button)
            .foregroundStyle(Theme.Color.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.medium)
            .background(Theme.Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text("Clears the figure and AR anchors so you can place again.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text("Snapshots")
                .font(Theme.Font.screenTitle)
                .foregroundStyle(Theme.Color.primaryText)
            if historyViewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if let errorMessage = historyViewModel.errorMessage {
                Text(errorMessage)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.danger)
            } else if historyViewModel.sessions.isEmpty {
                Text("No snapshots yet. Place the figure to save one.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.secondaryText)
            } else {
                VStack(spacing: Theme.Spacing.small) {
                    ForEach(historyViewModel.sessions) { session in
                        devSnapshotRow(session)
                    }
                }
            }
        }
        .task {
            await historyViewModel.reload()
        }
    }

    private func devSnapshotRow(_ session: ScanSession) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(Theme.Font.metricTitle)
                .foregroundStyle(Theme.Color.secondaryText)
            HStack {
                Text(ScanMetricsFormatter.duration(session.duration))
                    .font(Theme.Font.metricValue)
                    .foregroundStyle(Theme.Color.primaryText)
                Spacer()
                Text(session.quality.rawValue.capitalized)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.accent)
            }
            Text("Anchors \(session.anchorCount) · Mesh \(session.meshElementCount)")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)
        }
        .padding(Theme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
