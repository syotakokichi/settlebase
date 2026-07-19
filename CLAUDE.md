# CLAUDE.md - settlebase 開発ガイド

マルチテナント社内精算・ウォレット基盤の公開デモ。技術記事連載の実コード素材として、
スキーマ・RLS・認可テスト・開発ハーネスを段階的に育てる。実決済は扱わない
（プロダクト概要は [README](README.md) を参照）。

## 公開境界（最重要）

- この repo は **公開されている**。公開は不可逆なので、**全 push 前に `/boundary-check` を必ず実行する**
- 境界ゲートは fail-closed: 非公開の語リスト（`~/.config/settlebase/boundary-words.txt`）が
  読めなければ exit 1 で停止する
- 境界チェックは CI に含めない（語リストが非公開のため）。ローカルの push 前ゲートとして運用する
- 詳細: [.claude/rules/boundary-check.md](.claude/rules/boundary-check.md)

## リポジトリ構成

| パス | 役割 |
| --- | --- |
| `web/` | Next.js アプリ（Supabase Auth 込み） |
| `supabase/` | スキーマ migration・RLS・pgTAP 認可テスト |
| `docs/devlog/` | 時系列の開発記録 |
| `docs/adr/` | 設計判断の記録（MADR-lite） |
| `scripts/` | 境界チェック等の運用スクリプト |
| `.claude/` | エージェント向けルール・コマンド |
| `GLOSSARY.md` | ドメイン用語集(定義 + Avoid) |

## タスク運用（beads）

起票 → claim → 実装 → `/verify` → `/boundary-check` → push の順で進める。

<!-- bd 生成の managed block。bd のアップデートと共存させるため内容は変更せず、lint のみ除外する -->
<!-- markdownlint-disable MD031 MD032 MD034 -->
<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:6cd5cc61 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->
<!-- markdownlint-enable MD031 MD032 MD034 -->

## 検証

- `/verify` = pgTAP（`supabase test db --linked`）+ markdownlint + lychee + 境界ゲート
- `supabase db start` は Docker 前提で **CI 専用**。ローカルでは叩かない
- CI: `harness.yml`（lint + リンク）/ `db-tests.yml`（pgTAP）

## セキュリティ既定

- `.env*` はコミットしない（`.env.example` のみ可）
- service_role key はコミット・クライアント使用とも禁止
- anon ロールには何も許可しない（RLS ポリシーは authenticated のみに与える）
