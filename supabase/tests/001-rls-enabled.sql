-- 001: public スキーマの全テーブルで RLS が有効であることの機械検査
--
-- 「新しいテーブルを足したときに RLS を張り忘れる」事故を自動で捕まえる網。
-- 個別テーブルの検査も添えて、どのテーブルが原因かをすぐ特定できるようにする。
-- 各テストファイルは自己完結: extension 作成もトランザクション内で行い、rollback で残さない。
begin;
create extension if not exists pgtap with schema extensions;

select plan(4);

-- 網: public に RLS 無効のテーブルが 1 つもない
select is(
  (select count(*)::int from pg_tables where schemaname = 'public' and rowsecurity = false),
  0,
  'public スキーマに RLS 無効のテーブルがない'
);

-- 個別: 3 テーブルの RLS が有効
select ok(
  (select relrowsecurity from pg_class where oid = 'public.tenants'::regclass),
  'tenants の RLS が有効'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.members'::regclass),
  'members の RLS が有効'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.wallets'::regclass),
  'wallets の RLS が有効'
);

select * from finish();
rollback;
