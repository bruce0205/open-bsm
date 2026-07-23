import Foundation
import Testing
@testable import OpenBSMCore

@Suite(.serialized)
struct CharacterWidthTests {
    private let suiteName = "CharacterWidthTests"

    @Test func defaultsToHalfWidth() {
        let preference = CharacterWidthPreference(defaults: makeDefaults())

        #expect(preference.current == .halfWidth)
    }

    @Test func persistsSelectedWidth() {
        let defaults = makeDefaults()
        let preference = CharacterWidthPreference(defaults: defaults)

        preference.current = .fullWidth

        #expect(CharacterWidthPreference(defaults: defaults).current == .fullWidth)
    }

    @Test func convertsPrintableASCIIToFullWidth() {
        #expect(CharacterWidth.fullWidth.transform(" ABC 123!?~") == "　ＡＢＣ　１２３！？～")
    }

    @Test func leavesNonASCIIAndControlCharactersUnchanged() {
        #expect(CharacterWidth.fullWidth.transform("中文\n\t") == "中文\n\t")
    }

    @Test func halfWidthLeavesTextUnchanged() {
        #expect(CharacterWidth.halfWidth.transform("ABC 123 中文") == "ABC 123 中文")
    }

    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
