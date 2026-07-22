import Foundation

public enum InputCommand: Equatable, Sendable {
    case character(Character)
    case space
    case enter
    case backspace
    case escape
    case selectCandidate(Int)
    case moveSelection(Int)
    case movePage(Int)
    case toggleInputMode
}

public enum InputResult: Equatable, Sendable {
    case passThrough
    case composing(text: String, candidates: [String])
    case commit(String)
    case cancelComposition
    case modeChanged(isEnglish: Bool)
}

public struct InputEngine: Sendable {
    public static let candidatesPerPage = 9

    public private(set) var buffer = ""
    public private(set) var candidates: [String] = []
    public private(set) var isEnglishMode = false
    public private(set) var selectedCandidateIndex = 0

    private let codeTable: CodeTable
    private let candidateFrequency: CandidateFrequency
    private let maximumCodeLength: Int

    public init(
        codeTable: CodeTable,
        candidateFrequency: CandidateFrequency = CandidateFrequency(),
        maximumCodeLength: Int = 5
    ) {
        self.codeTable = codeTable
        self.candidateFrequency = candidateFrequency
        self.maximumCodeLength = maximumCodeLength
    }

    public mutating func handle(_ command: InputCommand) -> InputResult {
        switch command {
        case .toggleInputMode:
            clearComposition()
            isEnglishMode.toggle()
            return .modeChanged(isEnglish: isEnglishMode)

        case .character(let character):
            return handle(character)

        case .space:
            return commitFirstCandidate()

        case .enter:
            return commitFirstCandidate()

        case .backspace:
            guard !buffer.isEmpty else { return .passThrough }
            buffer.removeLast()
            guard !buffer.isEmpty else {
                candidates = []
                selectedCandidateIndex = 0
                return .cancelComposition
            }
            return refreshCandidates()

        case .escape:
            guard !buffer.isEmpty else { return .passThrough }
            clearComposition()
            return .cancelComposition

        case .selectCandidate(let index):
            guard candidates.indices.contains(index) else { return .passThrough }
            return commit(candidates[index])

        case .moveSelection(let offset):
            return moveSelection(by: offset)

        case .movePage(let offset):
            return movePage(by: offset)
        }
    }

    public var visibleCandidates: [String] {
        guard !candidates.isEmpty else { return [] }
        let pageStart = (selectedCandidateIndex / Self.candidatesPerPage) * Self.candidatesPerPage
        let pageEnd = min(pageStart + Self.candidatesPerPage, candidates.count)
        return Array(candidates[pageStart..<pageEnd])
    }

    public var selectedCandidateIndexInPage: Int {
        selectedCandidateIndex % Self.candidatesPerPage
    }

    public var currentPage: Int {
        guard !candidates.isEmpty else { return 0 }
        return selectedCandidateIndex / Self.candidatesPerPage + 1
    }

    public var totalPages: Int {
        guard !candidates.isEmpty else { return 0 }
        return (candidates.count - 1) / Self.candidatesPerPage + 1
    }

    public mutating func reset() {
        clearComposition()
    }

    private mutating func handle(_ character: Character) -> InputResult {
        if isEnglishMode {
            return .passThrough
        }

        guard isCodeCharacter(character), buffer.count < maximumCodeLength else {
            return .passThrough
        }
        buffer.append(contentsOf: character.lowercased())
        return refreshCandidates()
    }

    private func isCodeCharacter(_ character: Character) -> Bool {
        guard character.isASCII else { return false }

        if character.isLetter {
            return true
        }

        return codeTable.hasCode(withPrefix: buffer + String(character))
    }

    private mutating func refreshCandidates() -> InputResult {
        candidates = candidateFrequency.rankedCandidates(
            codeTable.candidates(for: buffer),
            for: buffer
        )
        selectedCandidateIndex = 0
        return .composing(text: buffer, candidates: candidates)
    }

    private mutating func commitFirstCandidate() -> InputResult {
        guard !buffer.isEmpty else { return .passThrough }
        return commit(selectedCandidate ?? buffer)
    }

    private var selectedCandidate: String? {
        candidates.indices.contains(selectedCandidateIndex) ? candidates[selectedCandidateIndex] : nil
    }

    private mutating func moveSelection(by offset: Int) -> InputResult {
        guard !candidates.isEmpty else { return .passThrough }

        selectedCandidateIndex = min(
            max(selectedCandidateIndex + offset, 0),
            candidates.count - 1
        )
        return .composing(text: buffer, candidates: candidates)
    }

    private mutating func movePage(by offset: Int) -> InputResult {
        guard !candidates.isEmpty else { return .passThrough }

        let currentPageIndex = selectedCandidateIndex / Self.candidatesPerPage
        let lastPageIndex = (candidates.count - 1) / Self.candidatesPerPage
        let targetPageIndex = min(
            max(currentPageIndex + offset, 0),
            lastPageIndex
        )
        let targetPageStart = targetPageIndex * Self.candidatesPerPage
        let targetPageEnd = min(
            targetPageStart + Self.candidatesPerPage,
            candidates.count
        )
        selectedCandidateIndex = min(
            targetPageStart + selectedCandidateIndexInPage,
            targetPageEnd - 1
        )
        return .composing(text: buffer, candidates: candidates)
    }

    private mutating func commit(_ text: String) -> InputResult {
        clearComposition()
        return .commit(text)
    }

    private mutating func clearComposition() {
        buffer = ""
        candidates = []
        selectedCandidateIndex = 0
    }
}
