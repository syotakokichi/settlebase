-- 002: テナント分離（Tenant A のユーザーから Tenant B のデータが見えない・書けない）
--
-- 各テストファイルは自己完結: fixture（auth.users への最小 insert 含む）と
-- ログインヘルパーをトランザクション内で自作し、rollback で一切残さない。
-- fixture の投入は postgres（テーブル owner）として行うため RLS の対象外で成立する。
begin;
create extension if not exists pgtap with schema extensions;

select plan(9);

-- ---- fixture: 2 テナント・2 ユーザー・2 ウォレット ----
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

-- ---- ヘルパー: 指定ユーザーの authenticated セッションを再現する（自作・最小） ----
-- role と request.jwt.claims をトランザクションローカルに設定する。
-- 呼び出し前に reset role で postgres に戻しておくこと。
create function pg_temp.login_as(uid uuid) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

-- ---- alice（Tenant A）から見える世界 ----
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');

select results_eq(
  'select id from public.tenants',
  array['10000000-0000-0000-0000-00000000000a'::uuid],
  'alice からは Tenant A だけが見える'
);

select is((select count(*)::int from public.wallets), 1, 'alice から見える wallet は自テナントの 1 件のみ');

select is(
  (select count(*)::int from public.wallets
    where tenant_id = '10000000-0000-0000-0000-00000000000b'),
  0,
  'alice から Tenant B の wallet は 0 件'
);

-- 書き込み境界: alice は Tenant B に wallet を作れない
select throws_ok(
  $$ insert into public.wallets (tenant_id, name)
     values ('10000000-0000-0000-0000-00000000000b', 'invasion') $$,
  '42501',
  null,
  'alice は Tenant B に wallet を作成できない（RLS 違反）'
);

-- 自テナントへの書き込みは許可される
select lives_ok(
  $$ insert into public.wallets (tenant_id, name)
     values ('10000000-0000-0000-0000-00000000000a', 'A wallet 2') $$,
  'alice は Tenant A に wallet を作成できる'
);

-- ---- bob（Tenant B）側からの対称確認 ----
reset role;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');

select is(
  (select count(*)::int from public.wallets
    where tenant_id = '10000000-0000-0000-0000-00000000000a'),
  0,
  'bob から Tenant A の wallet は 0 件'
);

select is((select count(*)::int from public.wallets), 1, 'bob から見える wallet は自テナントの 1 件のみ');

-- ---- anon には何も見えない ----
reset role;
set local role anon;

select is((select count(*)::int from public.wallets), 0, 'anon から wallet は 0 件');
select is((select count(*)::int from public.tenants), 0, 'anon から tenant は 0 件');

select * from finish();
rollback;
