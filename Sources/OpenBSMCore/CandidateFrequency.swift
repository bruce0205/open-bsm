import Foundation

public struct CandidateUsage: Codable, Equatable, Sendable {
    public var count: Int
    public var lastUsedAt: Int64

    public init(count: Int, lastUsedAt: Int64) {
        self.count = count
        self.lastUsedAt = lastUsedAt
    }
}

public struct CandidateFrequency: Codable, Equatable, Sendable {
    public private(set) var records: [String: [String: CandidateUsage]]

    public init(records: [String: [String: CandidateUsage]] = [:]) {
        self.records = records
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        records = try container.decode([String: [String: CandidateUsage]].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(records)
    }

    public mutating func record(
        code: String,
        candidate: String,
        usedAt: Date = .now
    ) {
        let code = normalize(code)
        guard !code.isEmpty, !candidate.isEmpty else { return }

        var usage = records[code]?[candidate]
            ?? CandidateUsage(count: 0, lastUsedAt: 0)
        if usage.count < Int.max {
            usage.count += 1
        }
        usage.lastUsedAt = Int64(usedAt.timeIntervalSince1970 * 1_000)
        records[code, default: [:]][candidate] = usage
    }

    public func rankedCandidates(_ candidates: [String], for code: String) -> [String] {
        let usages = records[normalize(code), default: [:]]
        return candidates.enumerated().sorted { lhs, rhs in
            let lhsUsage = usages[lhs.element]
                ?? CandidateUsage(count: 0, lastUsedAt: 0)
            let rhsUsage = usages[rhs.element]
                ?? CandidateUsage(count: 0, lastUsedAt: 0)
            if lhsUsage.count != rhsUsage.count {
                return lhsUsage.count > rhsUsage.count
            }
            if lhsUsage.lastUsedAt != rhsUsage.lastUsedAt {
                return lhsUsage.lastUsedAt > rhsUsage.lastUsedAt
            }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    @discardableResult
    public mutating func prune(to codeTable: CodeTable) -> Bool {
        let originalRecords = records
        records = records.reduce(into: [:]) { result, codeEntry in
            let validCandidates = codeEntry.value.filter { candidate, _ in
                codeTable.contains(candidate: candidate, for: codeEntry.key)
            }
            if !validCandidates.isEmpty {
                result[codeEntry.key] = validCandidates
            }
        }
        return records != originalRecords
    }

    private func normalize(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
