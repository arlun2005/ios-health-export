import Foundation
import Observation

@MainActor
@Observable
final class ExportSession {
    enum Phase: Equatable {
        case checking
        case unavailable
        case needsAuthorization
        case setup
        case loading
        case preview
        case failed(String)
    }

    var phase: Phase = .checking
    var dateRange = DateRangeSelection()
    var selectedTypes: Set<ExportableType> = Set(ExportableType.allCases)
    var payload: ExportPayload?
    var files: PreparedExportFiles?
    var isRequestingAccess = false
    var isPreparingFiles = false

    private let health = HealthKitClient()
    private var loadTask: Task<Void, Never>?
    private let exportDirectory: URL

    init(fileManager: FileManager = .default) {
        exportDirectory = fileManager.temporaryDirectory.appendingPathComponent("HealthExport", isDirectory: true)
    }

    var canLoad: Bool {
        !selectedTypes.isEmpty && dateRange.isValid
    }

    var sortedSelectedTypes: [ExportableType] {
        ExportableType.allCases.filter { selectedTypes.contains($0) }
    }

    func start() async {
        phase = .checking
        guard health.isHealthDataAvailable else {
            phase = .unavailable
            return
        }

        do {
            let status = try await health.authorizationRequestStatus()
            switch status {
            case .shouldRequest, .unknown:
                phase = .needsAuthorization
            case .unnecessary:
                phase = .setup
            @unknown default:
                phase = .needsAuthorization
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func requestAccess() async {
        isRequestingAccess = true
        defer { isRequestingAccess = false }
        do {
            try await health.requestReadAuthorization()
            // Read grants are intentionally opaque. Continue to setup and let query results speak.
            phase = .setup
        } catch {
            phase = .failed(HealthExportError.authorizationFailed(error.localizedDescription).localizedDescription)
        }
    }

    func loadPreview() {
        guard canLoad else {
            phase = .failed(selectedTypes.isEmpty
                ? HealthExportError.noTypesSelected.localizedDescription
                : HealthExportError.invalidDateRange.localizedDescription)
            return
        }

        loadTask?.cancel()
        payload = nil
        files = nil
        phase = .loading

        let types = sortedSelectedTypes
        let start = dateRange.startDate()
        let endExclusive = dateRange.endDateExclusive()
        let endInclusive = dateRange.inclusiveEndDate()

        loadTask = Task {
            do {
                let result = try await health.fetch(types: types, start: start, endExclusive: endExclusive)
                guard !Task.isCancelled else { return }
                let payload = ExportPayload(
                    exportedAt: .now,
                    startDate: start,
                    endDateInclusive: endInclusive,
                    types: types,
                    records: result.records,
                    summaries: result.summaries,
                    truncatedTypes: result.summaries.filter(\.truncated).map(\.type)
                )
                self.payload = payload
                self.phase = .preview
                await prepareFiles(from: payload)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                phase = .failed(HealthExportError.queryFailed(error.localizedDescription).localizedDescription)
            }
        }
    }

    func returnToSetup() {
        loadTask?.cancel()
        phase = .setup
    }

    func retryFromFailure() async {
        payload = nil
        files = nil
        await start()
    }

    private func prepareFiles(from payload: ExportPayload) async {
        isPreparingFiles = true
        defer { isPreparingFiles = false }
        do {
            let directory = exportDirectory
            let files = try await Task.detached {
                try ExportFileBuilder.write(payload, to: directory)
            }.value
            guard !Task.isCancelled else { return }
            self.files = files
        } catch {
            // Preview can still show; share buttons stay disabled if files are missing.
            files = nil
        }
    }
}
