import Foundation

public enum InputModeMemoryScope: String, Sendable {
    case perApplication
    case global
}

public struct InputModeMemory {
    private enum Key {
        static let scope = "InputModeMemoryScope"
        static let globalEnglishMode = "GlobalEnglishMode"
        static let perApplicationEnglishModes = "PerApplicationEnglishModes"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var scope: InputModeMemoryScope {
        get {
            guard let rawValue = defaults.string(forKey: Key.scope),
                  let scope = InputModeMemoryScope(rawValue: rawValue) else {
                return .perApplication
            }
            return scope
        }
        nonmutating set {
            defaults.set(newValue.rawValue, forKey: Key.scope)
        }
    }

    public func isEnglishMode(for bundleIdentifier: String?) -> Bool {
        switch scope {
        case .global:
            return defaults.bool(forKey: Key.globalEnglishMode)
        case .perApplication:
            guard let bundleIdentifier else { return false }
            return perApplicationModes[bundleIdentifier] ?? false
        }
    }

    public func setEnglishMode(_ isEnglish: Bool, for bundleIdentifier: String?) {
        switch scope {
        case .global:
            defaults.set(isEnglish, forKey: Key.globalEnglishMode)
        case .perApplication:
            guard let bundleIdentifier else { return }
            var modes = perApplicationModes
            modes[bundleIdentifier] = isEnglish
            defaults.set(modes, forKey: Key.perApplicationEnglishModes)
        }
    }

    public func selectScope(
        _ scope: InputModeMemoryScope,
        currentIsEnglish: Bool,
        bundleIdentifier: String?
    ) {
        self.scope = scope
        setEnglishMode(currentIsEnglish, for: bundleIdentifier)
    }

    private var perApplicationModes: [String: Bool] {
        defaults.dictionary(forKey: Key.perApplicationEnglishModes) as? [String: Bool] ?? [:]
    }
}
