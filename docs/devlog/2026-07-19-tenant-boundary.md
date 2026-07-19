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

## 実行環境の分担（2026-07-19 訂正あり）

| 環境 | コマンド | 用途 |
| --- | --- | --- |
| CI（Docker あり） | `supabase db start` → `supabase test db` | まっさらな DB で migration + テストを毎回検証（pgTAP の正） |
| ローカル（Docker なし） | `supabase db push --linked` / `supabase migration list --linked` | hosted への適用と一致確認（Docker 不要） |

**前提の訂正**: 当初「ローカルは `supabase test db --linked`（Docker 不要）」と想定していたが、
`supabase test db` は pg_prove をコンテナ（ghcr.io/supabase/pg_prove）で実行するため
**--linked でも Docker が必須** だった（LegacyDockerRunError で判明）。
ローカルに Docker を導入しない方針を維持し、pgTAP の実行は CI に一本化した
（[ADR-0003](../adr/0003-pgtap-test-strategy.md) に反映）。

## CI が捕まえた環境差（学び）

初回の PR で 002/003 が `permission denied for table tenants` で fail した。
原因は hosted 環境の既定 grant（新規テーブルに anon / authenticated へ広い権限が自動付与される）を
暗黙の前提にしていたこと。CI のまっさらな DB には既定 grant がなく、環境差がそのまま露出した。

対応: migration で `revoke all` → 最小 grant を明示し、テストも
「anon は grant 自体がない（42501 エラー）」を仕様として固定した。
権限をプラットフォーム既定に依存させない設計に直せたのは CI（まっさらな DB での毎回検証）の成果。

## 操作主体と未実施事項

| 操作 | 主体 | 状態 |
| --- | --- | --- |
| migration・テスト・CI 定義の作成 | AI（エージェント） | 実施済み |
| PR #1 のマージ | ユーザー（自作 PR の自動マージはローカル権限ゲートにより AI 実行不可） | 実施済み（2026-07-19） |
| `supabase db push --linked`（hosted への適用） | ユーザー（ローカル権限ゲートにより AI 実行不可） | 実施済み（2026-07-19。`supabase migration list --linked` で一致確認） |
| `supabase test db --linked` | 実施しない | 前提の訂正どおり Docker 必須と判明したため不採用（pgTAP の正は CI） |

## 境界破りデモ PR（赤 CI 証跡）

「テストが境界の破れを機械的に止める」ことを、実際に破ってみせて実証した。

| 項目 | 記録 |
| --- | --- |
| デモ PR | [#2](https://github.com/syotakokichi/settlebase/pull/2)（draft・本文冒頭に意図的デモと明記） |
| 破り方 | RLS を忘れたテーブル追加（`expense_reports`。ブランチ `demo/broken-tenant-boundary`） |
| 検出 | 001-rls-enabled「public スキーマに RLS 無効のテーブルがない」が fail |
| 赤ラン | [run 29674414074](https://github.com/syotakokichi/settlebase/actions/runs/29674414074)（db-tests fail / lint・link は pass） |
| close | 2026-07-19 05:11 UTC。マージせず証跡として残す（誤マージ防止のため open のまま残さない） |

## 境界チェック（push 前ゲート）

| # | チェック | 結果 |
| --- | --- | --- |
| 1 | 禁止語 grep（`scripts/boundary-check.sh`・非公開リスト参照） | 0 件・OK |
| 2 | 公開前チェック 4 点（コード・プロンプトは自作 / スクショなし / 引用なし / 有料コンテンツをなぞっていない） | OK |
| 3 | 入力ソース宣言: 本実装の入力はタスク管理側の設計メモ + 公開情報（Supabase / pgTAP 公式ドキュメント）のみ | OK |
| 4 | devlog 境界: 赤入れレビューは採用結果・理由のみ記録（2026-07-19-boundary-gate.md） | OK |
| 5 | GLOSSARY 境界: 本エントリ・ADR は自分の言葉のみ | OK |
