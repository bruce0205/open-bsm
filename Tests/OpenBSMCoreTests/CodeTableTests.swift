import Testing
@testable import OpenBSMCore

@Test func parsesCodeTableAndMergesDuplicateCodes() {
    let table = CodeTable(contents: """
        # Development table
        a 日 月
        A 明 日
        invalid
        """)

    #expect(table.count == 1)
    #expect(table.candidates(for: "A") == ["日", "月", "明"])
}

@Test func ignoresEmptyMappings() {
    let table = CodeTable(entries: ["": ["字"], "a": []])

    #expect(table.count == 0)
}

@Test func normalizesAndMergesEntryKeys() {
    let table = CodeTable(entries: ["A": ["日"], "a": ["月"]])

    #expect(table.count == 1)
    #expect(Set(table.candidates(for: "a")) == ["日", "月"])
}
