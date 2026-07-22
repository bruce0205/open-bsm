# Release Workflow

本文件定義 OpenBSM 從需求、實作到正式發布的版本流程。

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
    ├─ 確認 [Unreleased] 內容完整
    └─ 進行測試、審查與 release checklist
    ↓
正式發布
    ├─ Status: Released
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

Release preparation 應包含：

- 確認該版本的 implemented scope。
- 列出 remaining items 與 known limitations。
- 執行測試與建置驗證。
- 進行程式碼審查。
- 完成 release checklist。
- 確認版本號、安裝套件與文件內容一致。

### Released

完成最後測試、審查與 release checklist，並正式發布版本後：

1. 將版本文件的狀態改為 `Released`。
2. 加入正式發布日期。
3. 將 `CHANGELOG.md` 的 `[Unreleased]` 內容整理至版本區段。
4. 使用正式發布日期建立 Changelog entry。
5. 建立 Git tag，例如 `v0.1.0`。
6. 建立並保存正式 release artifact。
7. 更新 README 的 current version 與 project status。

版本文件範例：

```markdown
## Status

Released

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

## Versioning Rules

- 使用 Semantic Versioning 格式：`MAJOR.MINOR.PATCH`。
- Git tag 使用 `v` 加上版本號，例如 `v0.1.0`。
- `docs/release/` 的版本文件名稱、README 顯示版本、Bundle version 與 Git tag 應保持一致。
- 尚未正式發布的變更放在 `CHANGELOG.md` 的 `[Unreleased]` 區段。
- Changelog 的發布日期使用正式發布日，不使用文件建立日或測試開始日。
