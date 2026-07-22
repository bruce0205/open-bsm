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
- Plain-text code table loader with normalized, case-insensitive roots.
- Composition of roots up to five characters with inline marked text.
- Exact-match candidate lookup with nine candidates per page.
- Arrow keys move candidate selection; `Page Up` and `Page Down` change pages.
- Mouse-selectable candidates and page controls in one integrated candidate bar.
- `Space` or `Enter` to commit the selected candidate.
- Number keys `1` through `9` to select a candidate from the current page.
- `Backspace` to remove the last root.
- `Escape` to cancel composition.
- `Shift + Space` to switch between Chinese and direct English input, including
  terminal clients such as iTerm2, Ghostty, and the VS Code integrated terminal.
- Punctuation and symbol input exclusively through code-table roots such as
  `.s`, `,s`, `[[`, and `]]`; there are no hard-coded punctuation conversions.
- Personal code table at `~/Library/Application Support/OpenBSM/user.txt`.
- Root-code reverse lookup for selected text with `Option + Shift + R`.
- Input menu item for switching Chinese and English modes.
- User-selectable per-app or global Chinese and English mode memory.
- Global full-width and half-width modes with `Control + Shift + Space`.
- Candidate bar theme switch with dark and light modes.
- Unit tests for table parsing and the input state machine.
- Local build and per-user installation scripts.

### Remaining before the first public release

- Validate behavior in additional apps such as Safari and Microsoft Office.
- Add an original app icon.
- Add Developer ID signing, notarization, and a distributable installer.
- Add a settings window for shortcuts and table management.

## Planned features

- Candidate frequency learning.
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
  exact match, it commits the root text itself.
- `Left Arrow` or `Up Arrow` selects the previous candidate.
- `Right Arrow` or `Down Arrow` selects the next candidate.
- `Page Up` and `Page Down` move between candidate pages.
- Number keys `1` through `9` select a visible candidate directly.
- `Backspace` removes the last root; `Escape` cancels the composition.
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

### AI字根助手

#### 被動預測

> Ghost Suggestion

不用等使用者主動呼叫 AI 助手，而是在每次 commit 一個字/詞之後，背景非同步用上下文預測下一個可能的詞，以淡色 ghost text 形式顯示在游標後方（類似手機輸入法的預測文字）。

Ghost Text 永遠只顯示一個（最高信心值的候選），並且不會自動 commit，使用者可以選擇忽略或按下 right arrow 直接 commit top-1 的ghost text。

且能清楚的視覺提示告訴使用者「還有更多」，在 ghost text 旁邊加上 pagination 和 navigation 極簡標示，像root-code reverse lookup一樣，按下 hotkey 可以 navigate 到下一個 candidate 或是直接 click navigation button。

技術上：

- 建議優先用 Local provider（Ollama）做這層，因為觸發頻率高（每次 commit 都可能觸發），走 Cloud API 成本會快速累積
- 要做 debounce/節流 (idle timer 為 500ms)，例如只在詞/句邊界觸發，而非每個字元

edge case：

- api 延遲：若 AI 建議回傳時，使用者已經開始新的 composition 或已移動游標，該次回應直接丟棄，不顯示、不排隊。
- api 回傳空白：視為沒有 ghost text，使用者不會察覺到任何差異。
- api 未設定或失敗：視為沒有 ghost text，使用者不會察覺到任何差異。
- api 回傳的 ghost text 與使用者已經 commit 的文字重疊：視為沒有 ghost text，使用者不會察覺到任何差異。

#### 主動查詢

透過某個 hotkey 主動呼叫 AI 小幫手、輸入自然語言描述時，把最近的前文一併塞進 prompt，讓 AI 用「描述 + 上下文」雙重訊號做消歧
prompt 範例：

```
使用者不知道某個字怎麼拆碼，用自然語言描述：「\(desc)」
\(precedingContext.map { "前文語境：\($0)" } ?? "")
請優先參考前文語境，推論這可能會是哪些字，依據可能性高低排序，並回傳前 5 個候選字
```
