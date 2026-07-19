# 0002: supabase/ を repo 直下に置く

- Status: accepted
- Date: 2026-07-19

## Context

スキーマ・RLS・認可テストを持つ `supabase/` ディレクトリの置き場所には、
アプリ内（`web/supabase/`）と repo 直下の 2 案がある。
このプロダクトはテナント境界（RLS）を核とするデモであり、DB 層は特定の
フロントエンド実装の内部物ではない。

## Decision

- `supabase init` は repo 直下で実行し、`supabase/` を `web/` と並列に置く
- スキーマ・RLS・pgTAP テストは DB 層の一次成果物として、アプリから独立に管理する
- Supabase CLI の操作（migration・test・push）はすべて repo 直下で行う

## Consequences

- RLS・認可テストがアプリのスタックに縛られず、repo 直下から直接見える
- ADR-0001 の「repo 直下は役割ごとの並列構成」に整合する
- web/ から DB の型定義を生成する場合の置き場所は、必要になった時点で再判断する
