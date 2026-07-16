import Foundation

public struct CodeTable: Sendable {
    private let entries: [String: [String]]
    private let reverseEntries: [String: [String]]

    public init(entries: [String: [String]]) {
        let normalizedEntries = entries.reduce(into: [String: [String]]()) { result, entry in
            let code = Self.normalize(entry.key)
            guard !code.isEmpty, !entry.value.isEmpty else { return }
            result[code] = Self.unique(result[code, default: []] + entry.value)
        }
        self.entries = normalizedEntries
        reverseEntries = normalizedEntries.keys.sorted().reduce(into: [:]) { result, code in
            for candidate in normalizedEntries[code, default: []] {
                result[candidate, default: []].append(code)
            }
        }
    }

    public init(contents: String) {
        var entries: [String: [String]] = [:]

        for rawLine in contents.split(whereSeparator: \Character.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            let code: String
            let candidates: [String]
            if line.contains("\t") {
                let fields = line.split(separator: "\t").map {
                    String($0).trimmingCharacters(in: .whitespaces)
                }
                guard fields.count >= 2 else { continue }
                code = Self.normalize(fields[0])
                candidates = Array(fields.dropFirst())
            } else {
                let fields = line.split(whereSeparator: \Character.isWhitespace)
                guard fields.count >= 2 else { continue }
                code = Self.normalize(String(fields[0]))
                candidates = fields.dropFirst().map(String.init)
            }
            entries[code, default: []].append(contentsOf: candidates)
        }

        self.init(entries: entries)
    }

    public static func load(from url: URL) throws -> CodeTable {
        try CodeTable(contents: String(contentsOf: url, encoding: .utf8))
    }

    public func merging(_ other: CodeTable, otherCandidatesFirst: Bool = false) -> CodeTable {
        var mergedEntries = entries

        for (code, candidates) in other.entries {
            let existingCandidates = mergedEntries[code, default: []]
            let combinedCandidates = otherCandidatesFirst
                ? candidates + existingCandidates
                : existingCandidates + candidates
            mergedEntries[code] = Self.unique(combinedCandidates)
        }

        return CodeTable(entries: mergedEntries)
    }

    public func candidates(for code: String) -> [String] {
        entries[Self.normalize(code), default: []]
    }

    public func codes(for candidate: String) -> [String] {
        reverseEntries[candidate, default: []]
    }

    public func hasCode(withPrefix prefix: String) -> Bool {
        let normalizedPrefix = Self.normalize(prefix)
        return entries.keys.contains { $0.hasPrefix(normalizedPrefix) }
    }

    public var count: Int {
        entries.count
    }

    private static func normalize(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
