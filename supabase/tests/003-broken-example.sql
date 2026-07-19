-- 003: 危険実装のデモ（境界を破る実装をテストが検出することの実証）
--
-- 危険実装 fixture はすべてトランザクション内で作り、rollback で一切残さない。
-- ① RLS を張り忘れたテーブル → 001 と同じ検査網が検出することを実証
-- ② security_invoker を付け忘れたビュー → owner 権限で RLS を素通りし
--    テナント境界がリークすることを実証し、security_invoker = on で塞がることも確認
begin;
create extension if not exists pgtap with schema extensions;

select plan(4);

-- ---- fixture: 002 と同じ最小 2 テナント ----
insert into auth.users (id, email)
values
  ('00000000-0000-0000-0000-00000000000a', 'alice@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'bob@example.com');

insert into public.tenants (id, name)
values
  ('10000000-0000-0000-0000-00000000000a', 'Tenant A'),
  ('10000000-0000-0000-0000-00000000000b', 'Tenant B');

insert into public.members (tenant_id, user_id)
values
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000a'),
  ('10000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000b');

insert into public.wallets (id, tenant_id, name, balance)
values
  ('20000000-0000-0000-0000-00000000000a', '10000000-0000-0000-0000-00000000000a', 'A wallet', 1000),
  ('20000000-0000-0000-0000-00000000000b', '10000000-0000-0000-0000-00000000000b', 'B wallet', 2000);

-- ---- 危険実装①: RLS を張り忘れたテーブル ----
create table public.leaky_notes (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  body text
);

select isnt(
  (select count(*)::int from pg_tables where schemaname = 'public' and rowsecurity = false),
  0,
  '危険実装①: RLS 無効テーブルは 001 と同じ検査網で検出される'
);

-- ---- 危険実装②: security_invoker を付け忘れたビュー ----
-- ビューは既定で作成者（owner = postgres）の権限で実行され、RLS を素通りする
create view public.all_wallets as
  select id, tenant_id, name, balance from public.wallets;

-- alice としてログイン（002 と同じ最小ヘルパー）
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
set local role authenticated;

-- テーブル直接参照は RLS で守られている
select is(
  (select count(*)::int from public.wallets
    where tenant_id = '10000000-0000-0000-0000-00000000000b'),
  0,
  'テーブル直接参照では Tenant B は見えない（RLS 有効）'
);

-- しかしビュー経由では Tenant B の wallet が見えてしまう（リーク実証）
select isnt(
  (select count(*)::int from public.all_wallets
    where tenant_id = '10000000-0000-0000-0000-00000000000b'),
  0,
  '危険実装②: security_invoker off のビュー経由では Tenant B がリークする'
);

-- ---- 対策: security_invoker = on にすればリークは塞がる ----
reset role;
alter view public.all_wallets set (security_invoker = on);
set local role authenticated;

select is(
  (select count(*)::int from public.all_wallets
    where tenant_id = '10000000-0000-0000-0000-00000000000b'),
  0,
  'security_invoker = on でビュー経由のリークが塞がる'
);

select * from finish();
rollback;
