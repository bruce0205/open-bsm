# Release Workflow

本文件定義 OpenBSM 從需求、實作到預發布與正式發布的版本流程。

## Workflow

```text
Requirement
    ↓
Specification
    ↓
Implementation
    ↓
Release preparation
    ├─ 建立 docs/release/vX.Y.Z.md
    ├─ Status: Pre-release
    ├─ 設定 Release Stage：Alpha、Beta 或 GA
    ├─ 設定 Release Identifier，例如 0.1.0-beta.1
    ├─ 確認 [Unreleased] 內容完整
    └─ 進行測試、審查與 release checklist
    ↓
預發布（Alpha／Beta）
    ├─ Status: Pre-release
    ├─ 建立 Git tag：vX.Y.Z-alpha.N 或 vX.Y.Z-beta.N
    └─ 建立並保存預發布 artifact
    ↓
正式發布（GA）
    ├─ Status: Released
    ├─ Release Stage: GA
    ├─ 加入 Released date
    ├─ 將 [Unreleased] 改為 [X.Y.Z] - YYYY-MM-DD
    ├─ 建立新的空白 [Unreleased]
    └─ 建立 Git tag：vX.Y.Z
```

## Phase Responsibilities

### Requirement

描述使用者需求、產品目標與預期行為。需求文件使用自然語言，作為後續 specification 的來源。

位置：

```text
docs/requirement/
```

### Specification

將需求轉換為可供 AI agent 與工程師實作的技術規格，包含功能需求、技術限制、edge cases、隱私要求與 acceptance criteria。

位置：

```text
docs/specification/
```

### Implementation

依照 specification 修改程式碼、測試與必要的文件。實作完成後，應確認功能符合 acceptance criteria，並執行適當的測試與靜態檢查。

### Release Preparation

當版本功能接近完成且準備進入發布流程時，建立版本 scope 文件：

```text
docs/release/vX.Y.Z.md
```

文件初始狀態為：

```markdown
## Status

Pre-release
```

每個版本生命週期只建立一份 release scope，例如：

```text
docs/release/v0.1.0.md
```

文件使用以下欄位區分預發布階段與實際發布版本：

```markdown
## Status

Pre-release

## Release Stage

Beta

## Release Identifier

0.1.0-beta.1
```

`Release Stage` 可使用 `Alpha`、`Beta` 或 `GA`。同一階段有多次發布時，
使用 `Release Identifier` 的序號區分，例如 `0.1.0-beta.1` 與
`0.1.0-beta.2`。

Release preparation 應包含：

- 確認該版本的 implemented scope。
- 列出 remaining items 與 known limitations。
- 執行測試與建置驗證。
- 進行程式碼審查。
- 完成 release checklist。
- 確認版本號、安裝套件與文件內容一致。

### Pre-release（Alpha／Beta）

完成預發布測試與 checklist 後：

1. 保持版本文件的狀態為 `Pre-release`。
2. 設定對應的 `Release Stage` 與 `Release Identifier`。
3. 在 Changelog 記錄實際預發布版本，例如 `[0.1.0-beta.1]`。
4. 建立對應 Git tag，例如 `v0.1.0-beta.1`。
5. 建立並保存預發布 artifact。

### Released（GA）

完成最後測試、審查與 release checklist，並正式發布版本後：

1. 將版本文件的狀態改為 `Released`。
2. 將 `Release Stage` 設為 `GA`。
3. 加入正式發布日期。
4. 將 `CHANGELOG.md` 的 `[Unreleased]` 內容整理至版本區段。
5. 使用正式發布日期建立 Changelog entry。
6. 建立 Git tag，例如 `v0.1.0`。
7. 建立並保存正式 release artifact。
8. 更新 README 的 current version 與 project status。

版本文件範例：

```markdown
## Status

Released

## Release Stage

GA

## Release Date

2026-07-22
```

Changelog 範例：

```markdown
## [Unreleased]

## [0.1.0] - 2026-07-22

### Added

### Changed

### Fixed
```

GitHub branch、tag、artifact 與 Release 的實際操作流程，請參閱
[GitHub Release Workflow](github-release.md)。

## Versioning Rules

- 使用 Semantic Versioning 格式：`MAJOR.MINOR.PATCH`。
- 預發布版本使用 Semantic Versioning 的 prerelease identifier，例如
  `0.1.0-alpha.1` 或 `0.1.0-beta.1`。
- Git tag 使用 `v` 加上完整 Release Identifier，例如 `v0.1.0-beta.1`；GA
  版本則使用 `v0.1.0`。
- `docs/release/` 的版本文件以 base version 命名，例如 `v0.1.0.md`；
  `Release Identifier` 記錄實際 Alpha、Beta 或 GA 版本。
- README 顯示的版本與 `Resources/Info.plist` 的 Bundle version 應保持一致；
  預發布階段另外記錄 `Release Stage` 與 `Release Identifier`。
- 尚未正式發布的變更放在 `CHANGELOG.md` 的 `[Unreleased]` 區段。
- Changelog 應以實際 Release Identifier 建立預發布或 GA 區段，例如
  `[0.1.0-beta.1]` 與 `[0.1.0]`。
- Changelog 的發布日期使用實際發布日，不使用文件建立日或測試開始日。
