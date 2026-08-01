import Testing
@testable import OpenBSMCore

private let table = CodeTable(entries: [
    "a": ["日", "月"],
    "ab": ["明"],
    ".": ["。"],
    ".s": ["♠"],
    ",a": ["α"],
    "h;": ["☆"],
])

private func makeEngine(candidateCount: Int) -> InputEngine {
    let candidates = (0..<candidateCount).map { "候\($0 + 1)" }
    let table = CodeTable(entries: ["a": candidates])
    var engine = InputEngine(codeTable: table)
    _ = engine.handle(.character("a"))
    return engine
}

@Test func composesAndCommitsFirstCandidate() {
    var engine = InputEngine(codeTable: table)

    #expect(engine.handle(.character("A")) == .composing(text: "a", candidates: ["日", "月"]))
    #expect(engine.handle(.space) == .commit("日"))
    #expect(engine.buffer.isEmpty)
}

@Test func selectsCandidateWithNumberKey() {
    var engine = InputEngine(codeTable: table)

    _ = engine.handle(.character("a"))
    #expect(engine.handle(.selectCandidate(1)) == .commit("月"))
}

@Test func pagesCandidatesAndCommitsTheSelectedCandidate() {
    let candidates = (1...12).map { "候\($0)" }
    let table = CodeTable(entries: ["a": candidates])
    var engine = InputEngine(codeTable: table)

    _ = engine.handle(.character("a"))
    #expect(engine.visibleCandidates == Array(candidates.prefix(9)))
    #expect(engine.selectedCandidateIndexInPage == 0)

    _ = engine.handle(.movePage(1))
    #expect(engine.visibleCandidates == Array(candidates.suffix(3)))
    #expect(engine.selectedCandidateIndex == 9)
    #expect(engine.selectedCandidateIndexInPage == 0)
    #expect(engine.handle(.space) == .commit("候10"))
}

@Test func reportsPageCountsAtCandidateCountBoundaries() {
    let testCases = [
        (candidateCount: 0, currentPage: 0, totalPages: 0),
        (candidateCount: 1, currentPage: 1, totalPages: 1),
        (candidateCount: 9, currentPage: 1, totalPages: 1),
        (candidateCount: 10, currentPage: 1, totalPages: 2),
        (candidateCount: 18, currentPage: 1, totalPages: 2),
        (candidateCount: 19, currentPage: 1, totalPages: 3),
    ]

    for testCase in testCases {
        let engine = makeEngine(candidateCount: testCase.candidateCount)

        #expect(engine.currentPage == testCase.currentPage)
        #expect(engine.totalPages == testCase.totalPages)
    }
}

@Test func updatesPageInformationWithPageUpAndPageDown() {
    var engine = makeEngine(candidateCount: 19)

    #expect(engine.currentPage == 1)
    #expect(engine.totalPages == 3)

    _ = engine.handle(.movePage(1))
    #expect(engine.currentPage == 2)
    #expect(engine.selectedCandidateIndex == 9)

    _ = engine.handle(.movePage(1))
    #expect(engine.currentPage == 3)
    #expect(engine.selectedCandidateIndex == 18)

    _ = engine.handle(.movePage(1))
    #expect(engine.currentPage == 3)
    #expect(engine.selectedCandidateIndex == 18)

    _ = engine.handle(.movePage(-1))
    #expect(engine.currentPage == 2)
    #expect(engine.selectedCandidateIndex == 9)

    _ = engine.handle(.movePage(-1))
    #expect(engine.currentPage == 1)
    #expect(engine.selectedCandidateIndex == 0)

    _ = engine.handle(.movePage(-1))
    #expect(engine.currentPage == 1)
    #expect(engine.totalPages == 3)
    #expect(engine.selectedCandidateIndex == 0)

    engine.reset()
    #expect(engine.currentPage == 0)
    #expect(engine.totalPages == 0)
}

@Test func pageMovementPreservesSelectionPositionWhenPossible() {
    var engine = makeEngine(candidateCount: 20)

    _ = engine.handle(.moveSelection(5))
    _ = engine.handle(.movePage(-1))
    #expect(engine.selectedCandidateIndex == 5)

    _ = engine.handle(.movePage(1))
    #expect(engine.selectedCandidateIndex == 14)

    _ = engine.handle(.movePage(1))
    #expect(engine.selectedCandidateIndex == 19)

    _ = engine.handle(.movePage(1))
    #expect(engine.selectedCandidateIndex == 19)
}

@Test func movesCandidateSelectionAcrossPageBoundaries() {
    let candidates = (1...10).map { "候\($0)" }
    let table = CodeTable(entries: ["a": candidates])
    var engine = InputEngine(codeTable: table)

    _ = engine.handle(.character("a"))
    _ = engine.handle(.moveSelection(9))

    #expect(engine.visibleCandidates == ["候10"])
    #expect(engine.selectedCandidateIndex == 9)
    #expect(engine.handle(.enter) == .commit("候10"))
}

@Test func movesAdjacentSelectionAcrossPageBoundaries() {
    var engine = makeEngine(candidateCount: 19)

    _ = engine.handle(.moveSelection(8))
    #expect(engine.currentPage == 1)
    #expect(engine.selectedCandidateIndexInPage == 8)

    _ = engine.handle(.moveSelection(1))
    #expect(engine.currentPage == 2)
    #expect(engine.selectedCandidateIndexInPage == 0)

    _ = engine.handle(.moveSelection(-1))
    #expect(engine.currentPage == 1)
    #expect(engine.selectedCandidateIndexInPage == 8)
}

@Test func selectionMovementPassesThroughWithoutCandidates() {
    var engine = InputEngine(codeTable: table)

    #expect(engine.handle(.moveSelection(-1)) == .passThrough)
    #expect(engine.handle(.moveSelection(1)) == .passThrough)
}

@Test func movesCandidateSelectionOneStepInBothDirections() {
    var engine = InputEngine(codeTable: table)

    _ = engine.handle(.character("a"))
    _ = engine.handle(.moveSelection(1))
    #expect(engine.selectedCandidateIndex == 1)

    _ = engine.handle(.moveSelection(-1))
    #expect(engine.selectedCandidateIndex == 0)
}

@Test func backspaceUpdatesThenCancelsComposition() {
    var engine = InputEngine(codeTable: table)

    _ = engine.handle(.character("a"))
    _ = engine.handle(.character("b"))
    #expect(engine.handle(.backspace) == .composing(text: "a", candidates: ["日", "月"]))
    #expect(engine.handle(.backspace) == .cancelComposition)
}

@Test func unmatchedCodeRemainsComposingUntilCorrectedOrCancelled() {
    let table = CodeTable(entries: ["sss": ["絑"]])
    var engine = InputEngine(codeTable: table)

    _ = engine.handle(.character("s"))
    _ = engine.handle(.character("s"))
    _ = engine.handle(.character("s"))
    #expect(engine.handle(.character("s")) == .composing(text: "ssss", candidates: []))

    #expect(engine.handle(.space) == .composing(text: "ssss", candidates: []))
    #expect(engine.handle(.enter) == .composing(text: "ssss", candidates: []))
    #expect(engine.buffer == "ssss")

    #expect(engine.handle(.backspace) == .composing(text: "sss", candidates: ["絑"]))
    #expect(engine.handle(.escape) == .cancelComposition)
}

@Test func rejectsCodeCharacterBeyondMaximumLength() {
    var engine = InputEngine(codeTable: table, maximumCodeLength: 5)

    for character in "abcde" {
        _ = engine.handle(.character(character))
    }

    #expect(engine.handle(.character("f")) == .rejectedInput)
    #expect(engine.buffer == "abcde")
}

@Test func englishModePassesCharactersThrough() {
    var engine = InputEngine(codeTable: table)

    #expect(engine.handle(.toggleInputMode) == .modeChanged(isEnglish: true))
    #expect(engine.handle(.character("a")) == .passThrough)
}

@Test func composesSymbolCodeFromPunctuationRoot() {
    var engine = InputEngine(codeTable: table)

    #expect(engine.handle(.character(".")) == .composing(text: ".", candidates: ["。"]))
    #expect(engine.handle(.character("s")) == .composing(text: ".s", candidates: ["♠"]))
    #expect(engine.handle(.space) == .commit("♠"))
}

@Test func composesSymbolCodeWithPunctuationSuffix() {
    var engine = InputEngine(codeTable: table)

    _ = engine.handle(.character("h"))
    #expect(engine.handle(.character(";")) == .composing(text: "h;", candidates: ["☆"]))
}

@Test func passesThroughPunctuationWithoutCodeMapping() {
    var engine = InputEngine(codeTable: table)

    #expect(engine.handle(.character("!")) == .passThrough)
}

@Test func keepsCompositionWhenPunctuationHasNoCodeMapping() {
    var engine = InputEngine(codeTable: table)

    _ = engine.handle(.character("a"))
    #expect(engine.handle(.character(",")) == .passThrough)
    #expect(engine.buffer == "a")
}
