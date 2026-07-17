import RealityKit
import SwiftUI
import UniformTypeIdentifiers

struct AIResultView: View {
    @Bindable var viewModel: AIResultViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            HStack {
                Text("Results")
                    .font(Theme.Font.screenTitle)
                    .foregroundStyle(Theme.Color.primaryText)
                Spacer()
                Button("Import") {
                    viewModel.isImporterPresented = true
                }
                .font(Theme.Font.button)
            }

            legendRow

            if let errorMessage = viewModel.errorMessage {
                ScanStatusBanner(message: errorMessage, style: .warning)
            }

            if viewModel.models.isEmpty {
                Text("Import a room.glb / room.usdz from the Mac pipeline.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                Picker("Model", selection: $viewModel.selectedModel) {
                    ForEach(viewModel.models, id: \.self) { url in
                        Text(url.lastPathComponent).tag(Optional(url))
                    }
                }
                .pickerStyle(.menu)

                if let selected = viewModel.selectedModel {
                    ModelPreview(url: selected)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(Theme.Spacing.medium)
        .background(Theme.Color.screenBackground.ignoresSafeArea())
        .onAppear(perform: viewModel.reload)
        .fileImporter(
            isPresented: $viewModel.isImporterPresented,
            allowedContentTypes: viewModel.allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                if let url = urls.first {
                    viewModel.importFile(from: url)
                }
            case let .failure(error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    private var legendRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.small) {
                ForEach(viewModel.legend, id: \.name) { item in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: item.hex) ?? Theme.Color.secondaryText)
                            .frame(width: 10, height: 10)
                        Text(item.name)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.secondaryText)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.Color.cardBackground)
                    .clipShape(Capsule())
                }
            }
        }
    }
}

/// Lightweight RealityKit preview for imported USDZ/GLB when loadable.
struct ModelPreview: View {
    let url: URL
    @State private var entity: Entity?

    var body: some View {
        ZStack {
            Theme.Color.cardBackground
            if url.pathExtension.lowercased() == "usdz" || url.pathExtension.lowercased() == "reality" {
                RealityView { content in
                    if let entity {
                        content.add(entity)
                    }
                } update: { content in
                    content.entities.removeAll()
                    if let entity {
                        content.add(entity)
                    }
                }
            } else {
                // GLB/PLY/OBJ: show path until a dedicated loader is wired; Quick Look via share is fine.
                VStack(spacing: Theme.Spacing.small) {
                    Image(systemName: "cube.transparent")
                        .font(.largeTitle)
                        .foregroundStyle(Theme.Color.accent)
                    Text(url.lastPathComponent)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.primaryText)
                    Text("Open in Files / Quick Look for GLB·PLY. USDZ loads in-scene when available.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.secondaryText)
                        .multilineTextAlignment(.center)
                    ShareLink(item: url) {
                        Text("Share / Quick Look")
                            .font(Theme.Font.button)
                    }
                }
                .padding()
            }
        }
        .task(id: url) {
            guard url.pathExtension.lowercased() == "usdz" else {
                entity = nil
                return
            }
            do {
                entity = try await Entity(contentsOf: url)
            } catch {
                CaptureLog.ai.error("USDZ load failed: \(error.localizedDescription)")
                entity = nil
            }
        }
    }
}

private extension Color {
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let int = Int(value, radix: 16) else { return nil }
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}
