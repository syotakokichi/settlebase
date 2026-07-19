-- テナント境界の RLS
--
-- 方針:
-- - 3 テーブルすべて RLS を有効化する（有効化漏れは pgTAP 001 の機械検査で捕まえる）
-- - members への再帰参照を避けるため、所属テナントの取得は security definer 関数に隔離する（公式定石）
-- - ポリシーは authenticated ロールのみに与える。anon には何も許可しない
-- - ポリシー内の auth.uid() は (select ...) でラップし、行ごとの再評価を避ける（initPlan 最適化）

-- PostgREST に公開されない private スキーマにヘルパーを置く
create schema if not exists private;
grant usage on schema private to authenticated;

create or replace function private.user_tenant_ids()
returns setof uuid
language sql
security definer
set search_path = ''
stable
as $$
  select tenant_id from public.members where user_id = (select auth.uid())
$$;

alter table public.tenants enable row level security;
alter table public.members enable row level security;
alter table public.wallets enable row level security;

-- 権限はプラットフォームの既定 grant に依存せず、migration で明示する。
-- （hosted の既定では anon / authenticated に広い grant が付くが、まっさらな DB には無い。
--   環境差で挙動が変わらないよう、いったん revoke してから最小限だけ grant する）
-- anon には何も許可しない。authenticated も RLS と grant の二段で最小権限にする
revoke all on public.tenants, public.members, public.wallets from anon, authenticated;
grant select on public.tenants, public.members, public.wallets to authenticated;
grant insert on public.wallets to authenticated;

create policy "tenants: 自テナントのみ参照" on public.tenants
  for select to authenticated
  using (id in (select private.user_tenant_ids()));

create policy "members: 自テナントのみ参照" on public.members
  for select to authenticated
  using (tenant_id in (select private.user_tenant_ids()));

create policy "wallets: 自テナントのみ参照" on public.wallets
  for select to authenticated
  using (tenant_id in (select private.user_tenant_ids()));

create policy "wallets: 自テナントにのみ作成" on public.wallets
  for insert to authenticated
  with check (tenant_id in (select private.user_tenant_ids()));
