# 被動預測

## Status

Proposed。本文定義 Ghost Suggestion 的行為與非同步處理規則。

## Problem Statement

使用者完成一個字或詞後，通常會繼續輸入具有語境關聯的內容。被動預測應在不要求使用者主動呼叫 AI 的情況下，提供下一個可能的詞。

## User Experience

使用者每次提交一個字或詞後，OpenBSM 在背景非同步使用上下文取得預測結果，並以淡色 Ghost Text 顯示在游標後方。

- Ghost Text 永遠只顯示一個候選，且必須是最高信心值的候選。
- Ghost Text 不會自動提交。
- 使用者可忽略 Ghost Text，繼續輸入其他內容。
- 使用者可按下 `Right Arrow` 直接提交目前顯示的候選。
- 若有更多候選，Ghost Text 旁應顯示清楚但低干擾的 pagination 與 navigation 提示。
- 使用者可透過快捷鍵切換下一個候選，或直接點選 navigation button。

## Functional Requirements

1. 每次字詞提交後，系統可依設定觸發一次預測請求。
2. 預測請求必須在背景非同步執行。
3. 應使用 debounce／節流或 idle timer，初始建議值為 `500 ms`。
4. 觸發時機應優先落在詞或句邊界，不應針對每個字元立即呼叫 Provider。
5. 應優先使用 Local Provider，例如 Ollama；被動預測觸發頻率高，直接使用 Cloud API 會快速累積成本。
6. Ghost Text 最多顯示一個候選；其餘候選透過 pagination 與 navigation 操作取得。
7. 提交 Ghost Text 前，必須確認目前游標與 composition 狀態仍符合請求建立時的上下文。

## Technical Requirements

- 使用請求序號、輸入狀態版本或等效機制識別過期回應。
- 新的 composition 開始、游標移動或文件狀態改變時，舊回應應取消或直接丟棄。
- Ghost Text 的繪製不得改變目前 App 的實際文件內容。
- `Right Arrow` 只有在 Ghost Text 可提交時才攔截；其他情況維持現有方向鍵行為。
- Provider 回傳格式應能表達候選文字、排序或信心值，以及是否還有下一個候選。

## Edge Cases

- API 延遲：回應抵達時若使用者已開始新的 composition 或移動游標，直接丟棄，不顯示、不排隊。
- API 回傳空白：視為沒有 Ghost Text，使用者不應察覺到錯誤。
- API 未設定或失敗：視為沒有 Ghost Text，既有輸入流程不受影響。
- 回傳文字與使用者已提交文字重疊：視為沒有 Ghost Text。
- 使用者在預測期間切換中英文模式：清除目前 Ghost Text。
- 使用者連續提交內容：只保留最新有效的預測請求。

## Privacy and Security

- 被動預測預設應使用 Local Provider，避免高頻提交內容離開本機。
- 傳送至 Cloud Provider 前，必須遵循 AI Assistant 的 Provider 與上下文政策。
- 不應在一般日誌記錄完整前文、Prompt 或模型回應。

## Acceptance Criteria

- 使用者完成提交後，UI 不會因等待 AI 回應而卡住。
- 有效預測會以 Ghost Text 顯示，且不會自動寫入文件。
- `Right Arrow` 可提交目前 Ghost Text；沒有 Ghost Text 時不影響既有方向鍵行為。
- 所有列出的過期回應與失敗情境都不會污染新的輸入狀態。

## Open Questions

- 詞／句邊界應由輸入法狀態、語言分析器或 Provider 判斷？
- Ghost Text 應使用既有候選列，還是建立獨立的 suggestion bar？
- 多候選 navigation 的快捷鍵與無障礙標示應如何定義？
