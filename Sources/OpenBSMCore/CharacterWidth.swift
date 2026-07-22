import Foundation

public enum CharacterWidth: String, Sendable {
    case halfWidth
    case fullWidth

    private static let fullWidthOffset: UInt32 = 0xFEE0

    public func transform(_ text: String) -> String {
        guard self == .fullWidth else { return text }

        return text.unicodeScalars.reduce(into: "") { result, scalar in
            let transformedScalar: UnicodeScalar
            switch scalar.value {
            case 0x20:
                transformedScalar = UnicodeScalar(0x3000)!
            case 0x21...0x7E:
                transformedScalar = UnicodeScalar(scalar.value + Self.fullWidthOffset)!
            default:
                transformedScalar = scalar
            }
            result.unicodeScalars.append(transformedScalar)
        }
    }
}

public struct CharacterWidthPreference {
    private static let defaultsKey = "CharacterWidth"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var current: CharacterWidth {
        get {
            guard let rawValue = defaults.string(forKey: Self.defaultsKey),
                  let width = CharacterWidth(rawValue: rawValue) else {
                return .halfWidth
            }
            return width
        }
        nonmutating set {
            defaults.set(newValue.rawValue, forKey: Self.defaultsKey)
        }
    }
}
