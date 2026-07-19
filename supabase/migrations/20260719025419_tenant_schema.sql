-- テナント境界の最小スキーマ（ロールなし最小形）
-- tenants: テナント / members: ユーザーの所属 / wallets: テナント内のウォレット

create table public.tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null
);

create table public.members (
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  primary key (tenant_id, user_id)
);

create table public.wallets (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  name text not null,
  balance bigint not null default 0
);

-- RLS ポリシーが参照する列にはインデックスを張る（RLS 性能の定石）
create index members_user_id_idx on public.members (user_id);
create index wallets_tenant_id_idx on public.wallets (tenant_id);
