import Foundation
import OpenBSMCore

@MainActor
final class CandidateFrequencyStore {
    private static let directoryName = "OpenBSM"
    private static let fileName = "frequency.json"
    private static let writeDelay = Duration.milliseconds(500)

    private let fileURL: URL?
    private var frequency: CandidateFrequency
    private var writeTask: Task<Void, Never>?

    init(fileURL: URL? = CandidateFrequencyStore.defaultFileURL()) {
        self.fileURL = fileURL
        frequency = Self.load(from: fileURL)
    }

    var snapshot: CandidateFrequency { frequency }

    func record(code: String, candidate: String) {
        frequency.record(code: code, candidate: candidate)
        scheduleWrite()
    }

    func prune(to codeTable: CodeTable) {
        guard frequency.prune(to: codeTable) else { return }
        writeTask?.cancel()
        writeTask = nil
        write()
    }

    func reset() {
        frequency = CandidateFrequency()
        writeTask?.cancel()
        writeTask = nil
        guard let fileURL else { return }
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            NSLog("OpenBSM failed to reset candidate frequency: %@", error.localizedDescription)
            write()
        }
    }

    func flush() {
        guard writeTask != nil else { return }
        writeTask?.cancel()
        writeTask = nil
        write()
    }

    private func scheduleWrite() {
        writeTask?.cancel()
        writeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.writeDelay)
            guard !Task.isCancelled, let self else { return }
            self.writeTask = nil
            self.write()
        }
    }

    private func write() {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(frequency).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("OpenBSM failed to save candidate frequency: %@", error.localizedDescription)
        }
    }

    private static func load(from fileURL: URL?) -> CandidateFrequency {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let frequency = try? JSONDecoder().decode(CandidateFrequency.self, from: data) else {
            return CandidateFrequency()
        }
        return frequency
    }

    private static func defaultFileURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }
}
