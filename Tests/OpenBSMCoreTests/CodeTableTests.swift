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

@Test func reverseLookupReturnsNormalizedCodesInStableOrder() {
    let table = CodeTable(entries: [
        "DUE": ["明"],
        "a": ["日", "明"],
        "due": ["明"],
    ])

    #expect(table.codes(for: "明") == ["a", "due"])
    #expect(table.codes(for: "日") == ["a"])
    #expect(table.codes(for: "月").isEmpty)
}
