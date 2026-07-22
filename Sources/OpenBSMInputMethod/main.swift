import AppKit
import InputMethodKit

let app = NSApplication.shared
guard let bundleIdentifier = Bundle.main.bundleIdentifier,
      let connectionName = Bundle.main.object(forInfoDictionaryKey: "InputMethodConnectionName") as? String,
      let inputMethodServer = IMKServer(name: connectionName, bundleIdentifier: bundleIdentifier) else {
    fatalError("Unable to start the OpenBSM input method server")
}

let sharedCandidateBar = CandidateBar()
let sharedCharacterWidthIndicator = CharacterWidthIndicator()

withExtendedLifetime((inputMethodServer, sharedCandidateBar, sharedCharacterWidthIndicator)) {
    app.run()
}
