# 0003: pgTAP テスト戦略（自己完結・自作ヘルパー・二層実行・force RLS 不採用）

- Status: accepted
- Date: 2026-07-19

## Context

テナント境界を守る RLS は「張り忘れ・条件漏れが静かに混入する」性質があり、
機械検査で継続的に守る必要がある。一方、ローカル開発機に Docker を導入しない
制約があるため、テストの実行環境と書き方に工夫が要る。

## Decision

- **テスト層は pgTAP のみ**。アプリ経由（supabase-js）の統合テストは UI 実装後の
  マイルストーンで再判断する
- **各テストファイルは自己完結**にする。extension 作成・fixture・ログインヘルパーを
  すべて自トランザクション内で行い、rollback で一切残さない。
  共有 setup ファイル方式は、各ファイルが begin/rollback で閉じる構造だと
  後続ファイルから参照できないため採らない
- **テストヘルパーは自作の最小実装**（auth.users への最小 insert +
  `request.jwt.claims` と role の設定）。外部のテストヘルパーパッケージは
  拡張機構への依存が増えるため採用しない。依存が最小で、リンク先の hosted DB でも
  同一挙動になり、テストの中身をそのまま記事で説明できる
- **pgTAP の実行は CI に一本化**: `supabase db start` + `supabase test db`（Docker あり。
  migration の適用からテストまでを毎回まっさらな DB で検証する）。
  当初は「ローカルは `supabase test db --linked`（Docker 不要）」を想定したが、
  `supabase test db` は pg_prove をコンテナで実行するため **--linked でも Docker が必須**
  と判明した（2026-07-19 訂正）。ローカルに Docker を導入しない方針を維持し、
  ローカルからの検証は push（= PR の CI）を単位とする
- **hosted への適用確認**: 適用は `supabase db push --linked`、一致確認は
  `supabase migration list --linked`（どちらも Docker 不要）で行う
- **force RLS（`alter table ... force row level security`）は今回不採用**。
  テスト fixture の投入をテーブル owner（postgres）で行う構成のため、
  owner にも RLS を強制すると fixture 投入自体が塞がる。
  なお service_role は bypassrls 属性を持つため、force の有無に影響されない

## Consequences

- テストファイル間で fixture の記述が重複するが、ファイル単位の独立性・可搬性を優先する
- ローカルでは pgTAP を直接実行できない。テストの検証単位は PR / push の CI になる
- hosted 側で pgtap extension の作成が権限上できない場合のみ、dashboard から
  一度だけ有効化する（fallback。実施した場合は devlog に記録する）
- owner 経由の direct SQL は RLS の対象外である事実は、テスト（003）で
  「境界はロールと実行経路に依存する」例として明示的に扱う
