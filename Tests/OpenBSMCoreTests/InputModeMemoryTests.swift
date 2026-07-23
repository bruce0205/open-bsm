import Foundation
import Testing
@testable import OpenBSMCore

@Suite(.serialized)
struct InputModeMemoryTests {
    private let suiteName = "InputModeMemoryTests"

    @Test func defaultsToPerApplicationChineseMode() {
        let defaults = makeDefaults()
        let memory = InputModeMemory(defaults: defaults)

        #expect(memory.scope == .perApplication)
        #expect(!memory.isEnglishMode(for: "dev.openbsm.editor"))
    }

    @Test func remembersModesByApplication() {
        let defaults = makeDefaults()
        let memory = InputModeMemory(defaults: defaults)

        memory.setEnglishMode(true, for: "dev.openbsm.browser")

        #expect(memory.isEnglishMode(for: "dev.openbsm.browser"))
        #expect(!memory.isEnglishMode(for: "dev.openbsm.editor"))
    }

    @Test func sharesGlobalModeAcrossApplications() {
        let defaults = makeDefaults()
        let memory = InputModeMemory(defaults: defaults)

        memory.selectScope(
            .global,
            currentIsEnglish: true,
            bundleIdentifier: "dev.openbsm.browser"
        )

        #expect(memory.isEnglishMode(for: "dev.openbsm.browser"))
        #expect(memory.isEnglishMode(for: "dev.openbsm.editor"))
    }

    @Test func selectingPerApplicationStoresTheCurrentMode() {
        let defaults = makeDefaults()
        let memory = InputModeMemory(defaults: defaults)
        memory.selectScope(.global, currentIsEnglish: false, bundleIdentifier: nil)

        memory.selectScope(
            .perApplication,
            currentIsEnglish: true,
            bundleIdentifier: "dev.openbsm.editor"
        )

        #expect(memory.isEnglishMode(for: "dev.openbsm.editor"))
        #expect(!memory.isEnglishMode(for: "dev.openbsm.browser"))
    }

    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
