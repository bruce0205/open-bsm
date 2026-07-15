# OpenBSM

OpenBSM is an MIT-licensed Boshiamy-compatible input method for
macOS on Apple Silicon. It is implemented with Swift and InputMethodKit, and
focuses on Traditional Chinese input.

The bundled code table is converted from
[`chinese-opendesktop/cin-tables`](https://github.com/chinese-opendesktop/cin-tables/blob/master/boshiamy.cin).
The table includes a non-commercial-use restriction from its source; see the
provenance notice at the start of `Resources/bsm.txt`.

## Version 0.1 scope

### Implemented

- Native Apple Silicon executable.
- InputMethodKit input controller and a custom native candidate bar.
- Plain-text code table loader.
- Letter-root composition with inline marked text.
- Exact-match candidate lookup with nine candidates per page.
- Arrow keys move candidate selection; `Page Up` and `Page Down` change pages.
- Candidates and current/total page controls share one integrated candidate bar.
- `Space` or `Enter` to commit the selected candidate.
- Number keys `1` through `9` to select a candidate from the current page.
- `Backspace` to remove the last root.
- `Escape` to cancel composition.
- `Shift + Space` to switch between Chinese and direct English input.
- Basic Traditional Chinese punctuation, including committing active composition first;
  punctuation roots can also start symbol codes such as `.s`.
- Root-code reverse lookup for selected text with `Option + Shift + R`.
- Input menu item for switching Chinese and English modes.
- Unit tests for table parsing and the input state machine.
- Local build and per-user installation scripts.

### Remaining before the first public release

- Validate behavior in common apps such as Safari, Terminal, VS Code, and
  Microsoft Office.
- Add an original app icon and input menu icon.
- Add Developer ID signing, notarization, and a distributable installer.
- Add a settings window for shortcuts and table management.

## Planned features

- User-defined phrases and shortcut codes.
- Candidate frequency learning.
- Wildcard and fuzzy lookup.
- Full-width and half-width modes.
- Extended punctuation and symbol input.
- User dictionary import, export, and backup.
- Per-app Chinese or English mode memory.
- Optional iCloud dictionary synchronization.

## Requirements

- Apple Silicon Mac.
- macOS 13 or later.
- Xcode 15 or later with the macOS SDK.

## Build

Run the tests and assemble the input method app bundle:

```bash
swift test
make build
```

The resulting app is written to `.build/OpenBSM.app`.

## Install for the current user

```bash
make install
```

Then log out and log in again. Open **System Settings > Keyboard > Text Input >
Edit**, click **+**, and add **OpenBSM** under Traditional Chinese.

The development build uses ad-hoc code signing. Release builds need a Developer
ID certificate and Apple notarization.

## Root-code reverse lookup

Select exactly one character in the current app, then press
`Option + Shift + R`. The fixed-width lookup shows one root code at a time, with
each root rendered as a mini keycap. Press `Option + Shift + R` again to cycle
through alternate codes, or click the previous and next page controls. Press
`Escape` to close the lookup. Selecting zero or multiple characters does not
open the lookup, and arrow keys remain available to the current app.

The lookup requires the current app to expose its selected text through
InputMethodKit. If the app does not support document access, OpenBSM leaves the
selection unchanged and does not show the lookup.

## Code table format

`Resources/bsm.txt` uses one mapping per line. A code is followed by one or more
space-separated candidates:

```text
# Comments start with #
code candidate1 candidate2
```

Codes are normalized to lowercase. Blank lines and malformed lines are ignored.
The bundled table is converted from the CIN format. To use another legally
obtained table, replace `Resources/bsm.txt` and rebuild.

## License and table provenance

OpenBSM source code is licensed under [MIT](LICENSE). The bundled table is a
converted derivative of
[`chinese-opendesktop/cin-tables`' `boshiamy.cin`](https://github.com/chinese-opendesktop/cin-tables/blob/master/boshiamy.cin).
Its source carries a copyright notice for 行易有限公司 and a
`Free for non-commercial use` restriction. That restriction applies to the
bundled table, not to the OpenBSM source code. The imported snapshot's SHA-256
is recorded in `Resources/bsm.txt` for verification.

## Development

The package contains two targets:

- `OpenBSMCore` contains the table loader and platform-independent input engine.
- `OpenBSMInputMethod` connects the engine to InputMethodKit.

The candidate UI is implemented with a custom `NSPanel` instead of
`IMKCandidates`, so the candidate bar layout, controls, and visual styling can
be customized without being limited by the system candidate window.

Open `Package.swift` in Xcode for source-level development. Use `make build` to
produce the correctly structured `.app` bundle required by macOS input methods.

## Privacy

OpenBSM processes input locally. The current implementation has no networking,
analytics, or telemetry.

## Roadmap

### AI integration

- 詞語級聯想
- 錯誤/模糊輸入的智慧修正
