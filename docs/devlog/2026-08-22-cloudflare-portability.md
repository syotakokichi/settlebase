# 2026-08-22 Cloudflare Workers への移植性を実測（OpenNext / vinext）

Cloudflare Workers で Next.js を動かす選択肢（Next.js + OpenNext / vinext / TanStack Start）の
整理を見て、本デモが現状のままどこまで乗るかを実測した。
**本番デプロイ先（Vercel）は変更していない。** 移行の判断材料を残すための記録である。

## 前提

| 項目 | 値 |
| --- | --- |
| Next.js | 16.3.2（App Router・`cacheComponents: true`・`proxy.ts` で Supabase セッション更新） |
| Node.js | 25.4.0 |
| OpenNext | `@opennextjs/cloudflare` 1.20.2 / `wrangler` 4.125.0 |
| vinext | `vinext` 1.0.0-beta.8 / `@vinext/cloudflare` 1.0.0-beta.6（実験的） |
| 作業場所 | experiment ブランチ（main には入れていない） |

TanStack Start は Next.js 互換を捨てる書き直しになるため、本デモでは対象外とした。

## やったこと（操作主体つき）

| 作業 | 操作主体 |
| --- | --- |
| `npx vinext check` による互換レポート取得 | AI |
| OpenNext の導入（依存追加・`wrangler.jsonc` / `open-next.config.ts` 作成）とビルド | AI |
| `proxy.ts` → `middleware.ts`（Edge ランタイム）への一時的な戻しと再ビルド | AI |
| `vinext init --platform=cloudflare` とビルド（別 worktree） | AI |
| `wrangler deploy --dry-run` による Worker サイズ計測 | AI |
| Cloudflare へのデプロイ | **未実施**（不可逆操作は人間のゲートに残す方針） |

## 結果

| 観点 | OpenNext | vinext |
| --- | --- | --- |
| `proxy.ts`（Next.js 16・Node ランタイム固定） | **ビルド停止**: `Node.js middleware is not currently supported. Consider switching to Edge Middleware.` | 対応済み（`vinext check` で ✓、バンドルにセッション更新処理が含まれる） |
| 回避策 | `middleware.ts` + Edge ランタイムへ戻す（非推奨 API）+ `@opentelemetry/api` を依存に追加 → ビルド通過 | 不要 |
| `cacheComponents: true` | ビルド通過（Partial Prerender ルート 2 件を検出） | `vinext check` で「experimental・挙動不完全」 |
| Worker サイズ（gzip） | **2,550.92 KiB ≒ 2.49 MiB**（無料枠 3 MiB の約 85%） | **1,007.34 KiB ≒ 0.98 MiB** |
| 互換レポート | -- | 81%（12 supported / 2 partial / 2 issues） |
| 追加で必要になった変更 | 依存 3 件・設定 2 ファイル・`.gitignore` | `"type": "module"`・`vite.config.ts`・`wrangler.jsonc`・スクリプト 4 件（`vinext init` が非破壊で追加） |
| 警告 | -- | 9 ルート中 8 件が「分類不能」（`cookies()` / `headers()` 等を静的解析で検出できない） |

`vinext check` の partial 2 件は `next/font/google`（ビルド時に自己ホストされず CDN 読込）と
`cacheComponents`。issues 2 件は `"type": "module"` の欠如（init が自動追加）と
`eslint.config.mjs` の `__dirname`。

## 未実測

- workerd 上での実動作（Supabase セッション更新・ログイン・`/protected`）。
  Supabase の接続値はデプロイ先の環境変数にしかなく、ローカルに置いていないため
- Workers 無料枠の CPU 時間上限に対する挙動
- Vercel 固有の機能（プレビュー URL 連携など）の代替

## 判断

- **現時点では移行しない。** 本番は Vercel のまま
- OpenNext は `proxy.ts` 非対応が解消されるまで、非推奨の `middleware.ts` に戻す運用になる。
  サイズも無料枠上限の 85% で、機能追加で超える見込みが高い
- vinext はサイズ・`proxy.ts` とも良好だが、実験的（beta）であり
  `cacheComponents` が不完全。本デモは `cacheComponents` を前提にしているため、
  成熟を待つ
- 再評価のトリガー: OpenNext の Node ランタイム proxy 対応、または vinext の
  `cacheComponents` 対応が安定したとき

## 次の一手

- experiment ブランチは記録用に残す（main へはマージしない）
- 再評価時は、本 devlog の表を同じ観点で更新する
