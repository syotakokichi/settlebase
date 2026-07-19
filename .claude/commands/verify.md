# /verify - 最小検証

実装の最小検証を実行してください。

## 手順

1. **DB テスト（pgTAP）**: CI（db-tests）の green を確認する
   - `supabase test db` は pg_prove をコンテナで実行するため **--linked でも Docker が必須**。
     このリポジトリはローカルに Docker を導入しないため、pgTAP はローカルで実行しない
   - hosted への適用一致は `supabase migration list --linked`（Docker 不要）で確認する
   - `supabase db start` も Docker 前提で **CI 専用**。ローカルでは叩かない
2. **Markdown lint**: `npx markdownlint-cli2 "*.md" "docs/**/*.md"`
   - 設定は `.markdownlint-cli2.jsonc`（CI の対象 glob と揃える）
3. **リンクチェック**: `lychee --offline --no-progress --exclude-path web/node_modules './**/*.md'`
   - repo 内リンクのみ。ローカルでは `web/node_modules` を除外する（CI は checkout のみなので不要）
4. **境界ゲート**: `/boundary-check`（push する場合は必須）

## 報告

- 各ステップの結果（green / 失敗内容と原因）をまとめて報告する
- push するかどうかの判断はユーザーに委ねる
