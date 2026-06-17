import Foundation

@Observable
@MainActor
final class ScanHistoryViewModel {
    private let loadScanHistory: LoadScanHistory

    var sessions: [ScanSession] = []
    var isLoading = false
    var errorMessage: String?

    init(loadScanHistory: LoadScanHistory) {
        self.loadScanHistory = loadScanHistory
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        do {
            sessions = try await loadScanHistory()
        } catch {
            errorMessage = "Failed to load scan history."
            sessions = []
        }
        isLoading = false
    }
}
