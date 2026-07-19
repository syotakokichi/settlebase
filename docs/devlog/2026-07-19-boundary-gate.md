# 2026-07-19 境界チェックゲートの整備（fail-closed）

push 前の境界チェックを、手作業のチェックリストから **fail-closed なスクリプトゲート + ルール** に格上げした。
あわせて開発ハーネスの入口（CLAUDE.md・`.claude/`）を整備した。

## 追加したもの

| ファイル | 役割 |
| --- | --- |
| `scripts/boundary-check.sh` | 禁止語 grep の実行本体。語リストが読めなければ exit 1（fail-closed） |
| `.claude/rules/boundary-check.md` | 境界チェック 5 項目の一般形ルール・CI に含めない理由 |
| `.claude/commands/boundary-check.md` | push 前ゲートの実行手順（/boundary-check） |
| `.claude/commands/verify.md` | 最小検証手順（pgTAP + lint + リンク + 境界ゲート） |
| `CLAUDE.md` | 骨子版に置き換え（公開境界を冒頭に。beads managed block は維持） |

## 設計判断（赤入れレビュー 1 往復で確定）

構成案を赤入れレビューにかけ、以下を採用した。

- **CLAUDE.md は骨子版に全面置き換え**: 入口を「公開境界・検証」中心の 1 枚にする。
  bd init が生成した beads managed block は「タスク運用」節に残し、bd のアップデートと共存させる
- **ゲートは運用ルール + コマンドのみ（git hook 強制なし）**: bd init が既に beads 同期用の
  git hooks を設置しており、hook 連鎖は壊れやすい。実行証跡は devlog 記録で担保する
- **bd init 生成ファイル（AGENTS.md・`.agents/`・`.codex/`）はそのまま残す**: 他エージェントでも
  bd 運用ができる。生成内容は汎用文で、非公開情報の混入なしを grep で確認済み

## 動作確認の証跡

語リストは repo 外の非公開ファイル `~/.config/settlebase/boundary-words.txt` に配置済み
（存在・読み取り可を確認。**内容はここに記録しない**）。

| # | 確認 | 結果 |
| --- | --- | --- |
| 1 | 正常系: repo 全ファイル grep | OK（検査語 5 語・ヒット 0 件・対象 89 ファイル・exit 0） |
| 2 | fail-closed: 語リスト欠如時 | NG 表示のうえ exit 1 で停止（push 不可）を確認 |
| 3 | 検出系: リスト先頭語を含む一時ファイルを repo 内に置いて実行 | exit 1・該当ファイルの行番号つきで NG 出力を確認。一時ファイル削除後は再び OK |

検査対象は「git 追跡ファイル + 未追跡ファイル（gitignore 対象を除く）」で、
コミット前の作業ファイルも網にかかる。

## 運用

- 全 push 前に `/boundary-check` を実行し、5 項目チェックリストを devlog に記録する
- 語リストの正本は非公開側で管理し、実装中に気づいた語はリストに追記してから再実行する
