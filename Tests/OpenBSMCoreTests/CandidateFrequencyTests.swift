import Foundation
import Testing
@testable import OpenBSMCore

@Test func ranksCandidatesByFrequencyThenRecency() {
    var frequency = CandidateFrequency()
    frequency.record(
        code: "A",
        candidate: "月",
        usedAt: Date(timeIntervalSince1970: 100)
    )
    frequency.record(
        code: "a",
        candidate: "明",
        usedAt: Date(timeIntervalSince1970: 200)
    )
    frequency.record(
        code: "a",
        candidate: "月",
        usedAt: Date(timeIntervalSince1970: 300)
    )

    #expect(frequency.rankedCandidates(["日", "月", "明"], for: "a") == ["月", "明", "日"])
}

@Test func preservesOriginalOrderWithoutLearning() {
    let frequency = CandidateFrequency()

    #expect(frequency.rankedCandidates(["日", "月", "明"], for: "a") == ["日", "月", "明"])
}

@Test func prunesCandidatesMissingFromMergedCodeTable() {
    var frequency = CandidateFrequency(records: [
        "a": [
            "日": CandidateUsage(count: 2, lastUsedAt: 100),
            "月": CandidateUsage(count: 1, lastUsedAt: 200),
        ],
        "user": [
            "個人": CandidateUsage(count: 3, lastUsedAt: 300),
        ],
    ])
    let table = CodeTable(entries: ["a": ["日"]])

    let didPrune = frequency.prune(to: table)
    #expect(didPrune)
    #expect(frequency.records == [
        "a": ["日": CandidateUsage(count: 2, lastUsedAt: 100)],
    ])
    let didPruneAgain = frequency.prune(to: table)
    #expect(!didPruneAgain)
}

@Test func encodesRecordsAsTopLevelJSON() throws {
    let frequency = CandidateFrequency(records: [
        "a": ["日": CandidateUsage(count: 2, lastUsedAt: 100)],
    ])

    let data = try JSONEncoder().encode(frequency)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(object["a"] != nil)
    #expect(object["records"] == nil)
    #expect(try JSONDecoder().decode(CandidateFrequency.self, from: data) == frequency)
}

@Test func inputEngineUsesLearnedCandidateOrder() {
    let table = CodeTable(entries: ["a": ["日", "月"]])
    var frequency = CandidateFrequency()
    frequency.record(code: "a", candidate: "月")
    var engine = InputEngine(codeTable: table, candidateFrequency: frequency)

    #expect(engine.handle(.character("a")) == .composing(text: "a", candidates: ["月", "日"]))
    #expect(engine.handle(.space) == .commit("月"))
}
