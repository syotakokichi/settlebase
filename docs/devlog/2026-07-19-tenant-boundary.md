# 2026-07-19 テナント境界の最小縦切り（スキーマ・RLS・認可テスト）

テナント境界を「スキーマ → RLS → 認可テスト → CI」の最小縦切りで実装した。
UI は待たず、SQL とテストのレベルで境界が成立していることを先に固める。

## 追加したもの

| ファイル | 内容 |
| --- | --- |
| `supabase/migrations/20260719025419_tenant_schema.sql` | tenants / members / wallets（ロールなし最小形）+ RLS 用インデックス |
| `supabase/migrations/20260719025420_tenant_rls.sql` | 3 テーブルの RLS 有効化 + security definer ヘルパー + authenticated 限定ポリシー |
| `supabase/tests/001-rls-enabled.sql` | public 全テーブルの RLS 有効を機械検査（張り忘れを捕まえる網） |
| `supabase/tests/002-tenant-isolation.sql` | Tenant A から B が見えない・書けない / anon には何も見えない |
| `supabase/tests/003-broken-example.sql` | 危険実装 fixture（RLS 忘れテーブル・security_invoker off ビュー）のリーク実証と検出 |
| `.github/workflows/db-tests.yml` | CI で migration 適用 + pgTAP 実行（Docker）。文書系 harness.yml と責務分離 |

## 設計判断

- `supabase/` は repo 直下（[ADR-0002](../adr/0002-supabase-at-root.md)）
- テストは pgTAP のみ・各ファイル自己完結・ヘルパー自作・二層実行・force RLS 不採用
  （[ADR-0003](../adr/0003-pgtap-test-strategy.md)）
- RLS は「ポリシーを足す」より先に「有効化漏れを検出する網（001）」を張る。
  境界を破る実装が入ったときに、レビューではなくテストが落ちる状態を先に作る

## 実行環境の分担

| 環境 | コマンド | 用途 |
| --- | --- | --- |
| ローカル（Docker なし） | `supabase test db --linked` | リンク済み hosted DB に対して pgTAP 実行（全操作 rollback） |
| CI（Docker あり） | `supabase db start` → `supabase test db` | まっさらな DB で migration + テストを毎回検証 |

## 操作主体と未実施事項

| 操作 | 主体 | 状態 |
| --- | --- | --- |
| migration・テスト・CI 定義の作成 | AI（エージェント） | 実施済み |
| `supabase db push --linked`（hosted への適用） | ユーザー（ローカル権限ゲートにより AI 実行不可） | **未実施・要フォロー** |
| `supabase test db --linked`（hosted での green 確認） | push 後に実施 | **未実施・要フォロー** |

## 境界チェック（push 前ゲート）

| # | チェック | 結果 |
| --- | --- | --- |
| 1 | 禁止語 grep（`scripts/boundary-check.sh`・非公開リスト参照） | 0 件・OK |
| 2 | 公開前チェック 4 点（コード・プロンプトは自作 / スクショなし / 引用なし / 有料コンテンツをなぞっていない） | OK |
| 3 | 入力ソース宣言: 本実装の入力はタスク管理側の設計メモ + 公開情報（Supabase / pgTAP 公式ドキュメント）のみ | OK |
| 4 | devlog 境界: 赤入れレビューは採用結果・理由のみ記録（2026-07-19-boundary-gate.md） | OK |
| 5 | GLOSSARY 境界: 本エントリ・ADR は自分の言葉のみ | OK |
