-- ⚠️ 意図的な境界破りデモ（この PR はマージしない）
--
-- 「新機能のテーブルを追加したが、RLS の有効化を忘れた」という
-- AI 実装で最も混入しやすい事故を再現する。
-- 認可テスト 001-rls-enabled（public 全テーブルの RLS 有効を機械検査する網）が
-- この変更を検出し、CI（db-tests）が赤になることを実証する。

create table public.expense_reports (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  title text not null,
  amount bigint not null default 0
);

-- ここで alter table ... enable row level security とポリシー定義を「忘れて」いる
