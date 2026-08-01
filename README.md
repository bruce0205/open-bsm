# OpenBSM

OpenBSM is an MIT-licensed Boshiamy-compatible input method for
macOS on Apple Silicon. It is implemented with Swift and InputMethodKit, and
focuses on Traditional Chinese input.

請參閱[中文使用手冊](docs/user-manual.md)。

The bundled code table is converted from
[`chinese-opendesktop/cin-tables`](https://github.com/chinese-opendesktop/cin-tables/blob/master/boshiamy.cin).
The table includes a non-commercial-use restriction from its source; see the
provenance notice at the start of `Resources/bsm.txt`.

## Current Status

- Version: `0.1.0`
- Status: Pre-release
- Release stage: Beta
- Release identifier: `0.1.0-beta.1`
- Platform: macOS `13+` on Apple Silicon

Release history is tracked in [CHANGELOG.md](CHANGELOG.md)。
The release process is documented in [Release Workflow](docs/workflows/release.md)。

The current version scope and release criteria are documented in
[v0.1.0 Release Scope](docs/release/v0.1.0.md).

## Future features

- Wildcard and fuzzy lookup.
- User dictionary import, export, and backup.
- Optional iCloud dictionary synchronization.

## Requirements

- Apple Silicon Mac.
- macOS 13 or later.
- Xcode 16 or later with the macOS SDK and Swift 6.

## Build

Run the tests and assemble the input method app bundle:

```bash
swift test
make build
```

The resulting app is written to `.build/OpenBSM.app`.

To create a shareable development DMG:

```bash
make dmg
```

The resulting disk image is written to `.build/OpenBSM.dmg`. This DMG is
ad-hoc signed for testing. Public distribution still requires a Developer ID
certificate, notarization, and stapling.

To create a macOS Installer package:

```bash
make pkg
```

The resulting installer is written to `.build/OpenBSM.pkg`. It installs
OpenBSM system-wide under `/Library/Input Methods/` and asks for administrator
authorization. The development package is unsigned; public distribution still
requires a Developer ID Installer certificate, notarization, and stapling.

## Install for the current user

```bash
make install
```

Then log out and log in again. Open **System Settings > Keyboard > Text Input >
Edit**, click **+**, and add **OpenBSM** under Traditional Chinese.

The development build uses ad-hoc code signing. Release builds need a Developer
ID certificate and Apple notarization.

## Usage

OpenBSM starts in Chinese mode. Type a root sequence and select a candidate:

- `Space` or `Enter` commits the highlighted candidate. If the root has no
  exact match, the composition remains active until you correct it with
  `Backspace` or cancel it with `Escape`.
- `Left Arrow` or `Up Arrow` selects the previous candidate.
- `Right Arrow` or `Down Arrow` selects the next candidate.
- `Page Up` and `Page Down` move between candidate pages.
- Number keys `1` through `9` select a visible candidate directly.
- `Backspace` removes the last root; `Escape` cancels the composition.
- Root input is limited to five characters. Additional letters are ignored
  with a system alert sound.
- `Shift + Space` switches between Chinese and direct English input. The hot
  key is registered only while OpenBSM is active and does not require Input
  Monitoring or Accessibility permission.
- `Control + Shift + Space` switches between half-width and full-width input.

### Chinese and English mode memory

Open the input-method menu and choose **中英文模式記憶：依 App** or
**中英文模式記憶：所有 App 共用** to toggle the memory scope. Per-app memory
is the default and identifies each app by its bundle identifier. Both settings
persist across app and input-method restarts. When switching settings, the
active app's current mode is retained.

### Character width

Open the input-method menu and choose **字元寬度：半型** or **字元寬度：全型**
to toggle the current width. Character width is shared by all apps, persists
across input-method restarts, and defaults to half-width. Switching with
`Control + Shift + Space` briefly shows **半** or **全** near the insertion
point. The candidate bar also shows **全** while full-width mode is active.

Full-width mode converts directly entered printable ASCII characters to their
Unicode full-width equivalents, including `Space`. Code-table roots, candidate
selection keys, navigation keys, and shortcuts are not converted.

### Candidate bar theme

Open the input-method menu and choose **切換為淺色候選列** or
**切換為深色候選列**. The current selection is saved and applied to both the
candidate bar and root-code reverse lookup bar. OpenBSM starts in dark mode by
default.

### Candidate frequency learning

When a candidate is committed with `Space`, `Enter`, a number key, or a mouse
click, OpenBSM records its usage for the current root. Candidates are ordered by
usage count, then by the most recent selection, while unlearned candidates keep
their original code-table order. Learning data is stored locally at:

```text
~/Library/Application Support/OpenBSM/frequency.json
```

Writes are debounced and atomic. Reloading the personal code table removes
learning records that no longer exist in the merged bundled and personal table.
If the same root and candidate still exist in the bundled table, their learning
record is preserved. Choose **重置候選字學習…** from the input-method menu and
confirm the warning to delete all learning history.

ASCII letters are accepted as roots even before an exact candidate exists. A
non-letter ASCII character is accepted only when the current root remains a
prefix of at least one code-table entry. Other characters pass through to the
current app without committing or cancelling an active composition.

Punctuation and symbols first follow the same lookup path as Chinese
characters. For example, type `.s` and press `Space` to commit `♠`. In
full-width mode, directly entered ASCII punctuation that is not handled as a
code-table root is converted to its full-width equivalent. Add or modify root
mappings in `Resources/bsm.txt` to customize code-table punctuation.

## Personal code table

Open the input-method menu and choose **編輯個人碼表…** to create and open:

```text
~/Library/Application Support/OpenBSM/user.txt
```

The file uses the same format as the bundled code table:

```text
# code candidate1 candidate2
addr bruce@example.com
sig<TAB>Bruce Hsu
```

Use a literal Tab in place of `<TAB>` when a candidate contains spaces. Multiple
Tab-separated candidate fields are supported, so `cmd<TAB>git push origin
main<TAB>git status` creates two candidates.

After saving the file, choose **重新載入個人碼表** from the input-method menu.
Reloading commits any active composition, preserves the current Chinese or
English mode, and applies the updated mappings immediately.

OpenBSM loads the bundled `Resources/bsm.txt` first, then the personal table.
For a duplicate code, personal candidates appear before bundled candidates;
duplicate candidates are shown only once. The personal table is never written
to the app bundle, so it survives rebuilding and reinstalling OpenBSM.

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
Duplicate codes are merged and duplicate candidates retain their first-seen
order. The bundled table is converted from the CIN format. To use another
legally obtained table, replace `Resources/bsm.txt` and rebuild.

For a personal code table, Tab-separated fields can be used when a candidate
contains spaces. The first field is the code and each remaining field is one
candidate.

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

After the initial installation and login, reload a development build without
logging out by temporarily switching to another input source:

```zsh
# 先切到 ABC
make reload

# 再切回 OpenBSM
```

## Privacy

OpenBSM processes input locally. The current implementation has no networking,
analytics, or telemetry.

## Roadmap

- [AI Assistant](docs/specification/ai-assistant/README.md) — Proposed
