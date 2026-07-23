# AI assistant
## 被動預測

> Ghost Suggestion

不用等使用者主動呼叫 AI 小幫手，而是在每次 commit 一個字/詞之後，背景非同步用上下文預測下一個可能的詞，以淡色 ghost text 形式顯示在游標後方（類似手機輸入法的預測文字）。

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

## 主動查詢

透過某個 hotkey 主動呼叫 AI 小幫手，當視窗開啟時，會自動以「上下文」呼叫 AI api，需考慮 api latency，有 loading 狀態，再顯示結果；若無合適結果 (也可能是 empty response)，再輸入自然語言描述，並且把前文一併塞進 prompt，讓 AI 用「描述 + 上下文」雙重訊號做消歧
prompt 範例：

```
使用者不知道某個字怎麼拆碼，用自然語言描述：「\(desc)」
\(precedingContext.map { "前文語境：\($0)" } ?? "")
請優先參考前文語境，推論這可能會是哪些字，依據可能性高低排序，並回傳前 5 個候選字
```
