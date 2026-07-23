# AI Assistant

## Status

Proposed。此目錄包含 AI 字根助手的產品與技術規格，目前尚未列入已實作功能。

## Priority

最高。

## Overview

AI 字根助手的目標，是在既有 OpenBSM 輸入流程上提供兩種輔助能力：

- 被動預測：每次提交字或詞後，根據上下文非同步建議下一個可能的詞。
- 主動查詢：開啟查詢視窗後先以上下文自動查詢，沒有合適結果時，再接受自然語言描述並結合前文語境協助推論候選字。

AI 功能不得阻塞既有輸入流程。AI 未設定、請求失敗、回傳空白或回應逾時時，應視為沒有建議，使用者仍可正常使用 OpenBSM。

## Source Requirement

- [AI Assistant Requirement](../../requirement/ai-assistant.md)

## Scope

- 與現有候選列、組字狀態及輸入法快捷鍵整合。
- 支援 Local Provider 優先的推論架構，例如 Ollama。
- 對非同步請求、過期回應、游標變更與 composition 變更定義明確行為。
- 對主動查詢的 loading、初始上下文查詢與自然語言補充查詢定義明確行為。
- 將 AI 建議視為輔助內容，不得未經使用者操作自動提交文字。

## Non-Goals

- 不取代既有 Boshiamy 碼表查詢與候選字選取流程。
- 不在背景自動提交 AI 產生的文字。
- 不要求使用者必須設定 Cloud API 才能使用基本輸入功能。
- 不在本階段定義模型訓練、雲端帳號管理或跨裝置同步。

## Specifications

- [被動預測](passive-prediction.md)
- [主動查詢](active-query.md)

## Shared Acceptance Criteria

- AI 請求不可阻塞字根輸入、候選字操作或文字提交。
- 使用者開始新的 composition 或移動游標後，舊請求的回應不得更新畫面。
- AI 功能失敗時，既有輸入法功能與快捷鍵行為維持不變。
- 所有 AI 建議均須由使用者明確操作後才可提交。
- 預設優先使用本機 Provider；若未設定 Provider，OpenBSM 仍可正常運作。
- 主動查詢視窗開啟後，應先自動使用上下文查詢；只有在沒有合適結果時才要求使用者補充描述。

## Open Questions

- AI Provider 的抽象介面與設定入口應放在哪一層？
- 如何在不暴露敏感內容的前提下定義上下文擷取範圍？
- AI 候選結果是否需要獨立的排序、快取與 telemetry 策略？
