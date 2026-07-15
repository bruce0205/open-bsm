import AppKit
@preconcurrency import InputMethodKit
import OpenBSMCore

@objc(OpenBSMInputController)
final class InputController: IMKInputController, @unchecked Sendable {
    private let codeTable: CodeTable
    private var engine: InputEngine
    private var reverseLookupCharacter: String?
    private var reverseLookupCodes: [String] = []
    private var reverseLookupCodeIndex = 0
    private var candidateBar: CandidateBar { sharedCandidateBar }

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        let table: CodeTable
        if let url = Bundle.main.url(forResource: "bsm", withExtension: "txt"),
           let loadedTable = try? CodeTable.load(from: url) {
            table = loadedTable
        } else {
            table = CodeTable(entries: [:])
        }
        codeTable = table
        engine = InputEngine(codeTable: table)
        super.init(server: server, delegate: delegate, client: inputClient)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard event.type == .keyDown else { return false }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if isReverseLookupShortcut(event, modifiers: modifiers) {
            showReverseLookup(client: sender)
            return true
        }

        if reverseLookupCharacter != nil {
            switch event.keyCode {
            case 53:
                hideCandidates()
                return true
            default:
                hideCandidates()
            }
        }

        if modifiers.contains(.command) || modifiers.contains(.control) || modifiers.contains(.option) {
            return false
        }

        if event.keyCode == 49, modifiers.contains(.shift) {
            if !engine.buffer.isEmpty {
                commitComposition(sender)
            }
            apply(engine.handle(.toggleInputMode), client: sender)
            return true
        }

        let command: InputCommand?
        switch event.keyCode {
        case 36, 76:
            command = .enter
        case 49:
            command = .space
        case 51:
            command = .backspace
        case 53:
            command = .escape
        case 123:
            command = .moveSelection(-1)
        case 124:
            command = .moveSelection(1)
        case 126:
            command = .moveSelection(-1)
        case 125:
            command = .moveSelection(1)
        case 116:
            command = .movePage(-1)
        case 121:
            command = .movePage(1)
        default:
            if let index = selectionIndex(for: event), !engine.buffer.isEmpty {
                guard engine.visibleCandidates.indices.contains(index) else {
                    return true
                }
                command = .selectCandidate(
                    engine.selectedCandidateIndex - engine.selectedCandidateIndexInPage + index
                )
            } else if let character = event.characters?.first {
                command = .character(character)
            } else {
                command = nil
            }
        }

        guard let command else { return false }
        let result = engine.handle(command)
        guard result != .passThrough else { return false }
        apply(result, client: sender)
        return true
    }

    override func commitComposition(_ sender: Any!) {
        guard !engine.buffer.isEmpty else { return }
        let text = engine.candidates.indices.contains(engine.selectedCandidateIndex)
            ? engine.candidates[engine.selectedCandidateIndex]
            : engine.buffer
        commit(text, client: sender)
    }

    override func deactivateServer(_ sender: Any!) {
        if !engine.buffer.isEmpty {
            commitComposition(sender)
        }
        hideCandidates()
        super.deactivateServer(sender)
    }

    override func hidePalettes() {
        hideCandidates()
        super.hidePalettes()
    }

    override func inputControllerWillClose() {
        hideCandidates()
        super.inputControllerWillClose()
    }

    override func menu() -> NSMenu! {
        let menu = NSMenu(title: "OpenBSM")
        let title = engine.isEnglishMode ? "切換至中文模式" : "切換至英文模式"
        let item = NSMenuItem(title: title, action: #selector(toggleInputMode(_:)), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc private func toggleInputMode(_ sender: Any?) {
        let inputClient = client()
        if !engine.buffer.isEmpty {
            commitComposition(inputClient)
        }
        apply(engine.handle(.toggleInputMode), client: inputClient)
    }

    private func apply(_ result: InputResult, client sender: Any?) {
        switch result {
        case .passThrough:
            break

        case .composing:
            updateComposition()
            updateCandidates()

        case .commit(let text):
            insert(text, client: sender)
            hideCandidates()

        case .cancelComposition:
            updateComposition()
            hideCandidates()

        case .modeChanged:
            updateComposition()
            hideCandidates()
        }
    }

    private func commit(_ text: String, client sender: Any?) {
        engine.reset()
        insert(text, client: sender)
        hideCandidates()
    }

    private func insert(_ text: String, client sender: Any?) {
        guard let inputClient = sender as? (any IMKTextInput) else { return }
        inputClient.insertText(text, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
    }

    private func selectionIndex(for event: NSEvent) -> Int? {
        guard let character = event.charactersIgnoringModifiers?.first,
              let number = character.wholeNumberValue,
              (1...9).contains(number) else {
            return nil
        }
        return number - 1
    }

    private func isReverseLookupShortcut(
        _ event: NSEvent,
        modifiers: NSEvent.ModifierFlags
    ) -> Bool {
        guard event.keyCode == 15 else { return false }
        let shortcutModifiers = modifiers.intersection([
            .command,
            .control,
            .option,
            .shift,
        ])
        return shortcutModifiers == [.option, .shift]
    }

    private func showReverseLookup(client sender: Any?) {
        guard engine.buffer.isEmpty,
              let inputClient = sender as? (any IMKTextInput) else {
            return
        }

        let selectionRange = inputClient.selectedRange()
        guard selectionRange.location != NSNotFound,
              selectionRange.length != NSNotFound,
              selectionRange.length > 0,
              let selectedText = inputClient
                .attributedSubstring(from: selectionRange)?
                .string else {
            hideCandidates()
            return
        }

        guard selectedText.count == 1,
              let selectedCharacter = selectedText.first,
              !selectedCharacter.isWhitespace else {
            hideCandidates()
            return
        }

        let character = String(selectedCharacter)
        if reverseLookupCharacter == character {
            moveReverseLookup(by: 1)
            return
        }

        hideCandidates()
        reverseLookupCharacter = character
        reverseLookupCodes = codeTable.codes(for: character)
        reverseLookupCodeIndex = 0
        updateReverseLookup()
    }

    private func moveReverseLookup(by offset: Int) {
        guard !reverseLookupCodes.isEmpty else { return }
        let count = reverseLookupCodes.count
        let targetIndex = (reverseLookupCodeIndex + offset) % count
        reverseLookupCodeIndex = targetIndex >= 0 ? targetIndex : targetIndex + count
        updateReverseLookup()
    }

    private func updateReverseLookup() {
        guard let reverseLookupCharacter,
              let inputClient = client() else {
            hideCandidates()
            return
        }

        let code = reverseLookupCodes.indices.contains(reverseLookupCodeIndex)
            ? reverseLookupCodes[reverseLookupCodeIndex]
            : nil
        MainActor.assumeIsolated {
            candidateBar.showReverseLookup(
                owner: self,
                character: reverseLookupCharacter,
                code: code,
                currentPage: code == nil ? 0 : reverseLookupCodeIndex + 1,
                totalPages: reverseLookupCodes.count,
                client: inputClient,
                onPageChanged: { [weak self] offset in
                    self?.moveReverseLookup(by: offset)
                }
            )
        }
    }

    private func updateCandidates() {
        let candidates = engine.visibleCandidates
        let selectedCandidateIndex = engine.selectedCandidateIndexInPage
        let currentPage = engine.currentPage
        let totalPages = engine.totalPages
        guard let inputClient = client() else {
            hideCandidates()
            return
        }

        MainActor.assumeIsolated {
            if !candidates.isEmpty {
                candidateBar.show(
                    owner: self,
                    candidates: candidates,
                    selectedIndex: selectedCandidateIndex,
                    currentPage: currentPage,
                    totalPages: totalPages,
                    client: inputClient,
                    onCandidateSelected: { [weak self] index in
                        guard let self else { return }
                        let pageStart = self.engine.selectedCandidateIndex
                            - self.engine.selectedCandidateIndexInPage
                        let result = self.engine.handle(
                            .selectCandidate(pageStart + index)
                        )
                        self.apply(result, client: self.client())
                    },
                    onPageChanged: { [weak self] offset in
                        guard let self else { return }
                        let result = self.engine.handle(.movePage(offset))
                        self.apply(result, client: self.client())
                    }
                )
            } else {
                candidateBar.hide(owner: self)
            }
        }
    }

    private func hideCandidates() {
        reverseLookupCharacter = nil
        reverseLookupCodes = []
        reverseLookupCodeIndex = 0
        MainActor.assumeIsolated {
            candidateBar.hide(owner: self)
        }
    }

}

extension InputController {
    override func composedString(_ sender: Any!) -> Any! {
        engine.buffer
    }

    override func originalString(_ sender: Any!) -> NSAttributedString! {
        NSAttributedString(string: engine.buffer)
    }
}
