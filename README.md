# settlebase

マルチテナント社内精算・ウォレット基盤の公開デモ。

デモ: <https://settlebase-sandy.vercel.app>

AI 開発ハーネス連載（Zenn）のデモリポジトリとして、プロダクト本体だけでなく
開発ハーネス（devlog / ADR / GLOSSARY / CI）をまるごと公開する。

## Problem

- 複数のテナント（組織）が同居する精算・ウォレット基盤では、テナント境界の破れがそのまま事故になる
- AI に実装を任せる開発では、境界の破れが静かに混入しやすい

## Solution

- Postgres RLS をテナント境界の最後の砦にする構成
- 境界を検証する認可テスト
- 開発ハーネス（devlog / ADR / GLOSSARY / CI）ごと公開し、連載で解説する

## Out of Scope（やらないこと）

- **実決済は扱わない**。実マネーの入出金・決済 API 連携は本デモの対象外
- 本番運用を想定したサポート・SLA はない

## Tech Stack

- Next.js (App Router) — `web/`
- Supabase (Auth + Postgres RLS)
- Vercel（Root Directory = `web/`）

## リポジトリ構成

```text
settlebase/
├── web/        # Next.js アプリ（アプリ都合のファイルはここに閉じる）
├── docs/
│   ├── devlog/ # 開発ログ（YYYY-MM-DD-topic.md）
│   └── adr/    # 設計判断の記録（MADR-lite）
├── GLOSSARY.md # 用語集（定義 + Avoid）
└── LICENSE     # MIT
```

開発ツール（beads 進捗 UI 等）は将来 `tools/` に置く。
tools は `web/` のスタックに縛られず、独立したスタック（ゼロ依存 CLI 等）を選んでよい。

## 開発

```bash
cd web
npm install
npm run dev
```

環境変数は `web/.env.example` を参照する（`.env` はコミットしない）。

## License

MIT
