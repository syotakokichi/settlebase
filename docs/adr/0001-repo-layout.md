# 0001: アプリを web/ に隔離した並列リポジトリ構成

- Status: accepted
- Date: 2026-07-18

## Context

公式 with-supabase テンプレを repo 直下に展開すると、node_modules や各種設定ファイルなど
アプリ都合のファイルと、docs・開発ツール・用語集が同列に並び、全体が把握しづらくなる
（構成レビューでの人間の赤入れ指摘）。

## Decision

- Next.js アプリ一式を `web/` に隔離し、repo 直下は `web/` `docs/` `GLOSSARY.md` `LICENSE` `README.md` の並列とする
- 開発ツールは将来 `tools/` に置き、`web/` のスタックに縛られない（ゼロ依存 CLI 等も可）
- workspace 管理（npm/pnpm workspace）は導入しない。各ディレクトリが独立に完結する
- Vercel は Root Directory = `web/` を指定してデプロイする

## Consequences

- repo 直下の見通しが保たれ、ドキュメントとアプリを対等に扱える
- 開発開始に `cd web` が一段増える。テンプレ標準の手順とズレるため README に明記する
- tools を別スタックで作る自由度を確保。共通依存の管理が必要になった時点で workspace 導入を再判断する
