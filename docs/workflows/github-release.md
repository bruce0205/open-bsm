# GitHub Release Workflow

本文件定義 OpenBSM 在 GitHub 上發布 Alpha、Beta 或 GA 版本的實際操作流程。

## Release Branch Strategy

先在 `dev` branch 完成實作、文件更新與驗證，再透過 Pull Request 合併至
`main`。Release tag 與 release artifact 必須從已合併的 `main` commit 建立，
確保原始碼、版本 tag 與安裝套件來自同一個版本。

## 1. 在 `dev` 完成變更與驗證

以下以 `v0.1.0-beta.1` 為例：

```zsh
git checkout dev
git pull origin dev

swift test
make build
git diff --check

git add .
git commit -m "chore: prepare v0.1.0-beta.1 release"
git push origin dev
```

建立 Pull Request：

```zsh
gh pr create \
  --base main \
  --head dev \
  --title "chore: prepare v0.1.0-beta.1 release" \
  --body "Prepare v0.1.0-beta.1 release"
```

## 2. 從 `main` 建立 Release tag

Pull Request 合併後，切換至最新的 `main`：

```zsh
git checkout main
git pull origin main

git tag -a v0.1.0-beta.1 -m "Release v0.1.0-beta.1"
git push origin v0.1.0-beta.1
```

## 3. 建立各架構的 `.pkg`

`make pkg` 與 `make pkg-x86_64` 都會輸出 `.build/OpenBSM.pkg`，因此每次建置
後應立即複製並重新命名：

```zsh
mkdir -p .build/release-assets

make pkg
cp .build/OpenBSM.pkg \
  .build/release-assets/OpenBSM-0.1.0-beta.1-arm64.pkg

make pkg-x86_64
cp .build/OpenBSM.pkg \
  .build/release-assets/OpenBSM-0.1.0-beta.1-x86_64.pkg

file .build/release-assets/*.pkg
```

## 4. 建立 GitHub Pre-release

若尚未登入 GitHub CLI，先執行：

```zsh
gh auth login
```

建立 GitHub Pre-release 並附加兩個架構的安裝套件：

```zsh
gh release create v0.1.0-beta.1 \
  .build/release-assets/OpenBSM-0.1.0-beta.1-arm64.pkg \
  .build/release-assets/OpenBSM-0.1.0-beta.1-x86_64.pkg \
  --title "OpenBSM v0.1.0-beta.1" \
  --prerelease \
  --generate-notes
```

每次 Beta 更新應增加識別碼，例如 `v0.1.0-beta.2`，並更新指令中的版本號。

預發布套件目前使用 ad-hoc signing；若要作為正式公開版本發布，仍需完成
Developer ID signing、notarization 與 stapling。
