# blog-posting-auto

Claude Code 기반 한국어 블로그 글 자동화 파이프라인. Researcher → Fact-Checker → Planner → Writer → Reviewer → (Image Router → Image Generator, 선택) → Publisher 서브에이전트가 `/blog-pipeline` 스킬을 통해 직렬 실행, 최종 결과를 Notion DB에 발행. Fact-Checker가 환각·오인용을 격리해 downstream을 깨끗하게 유지.

## 실행 흐름

```
user: /blog-pipeline <주제 또는 키워드>
  └─ Opus Orchestrator (메인 세션)
      ├─ 1.  blog-researcher    → workspace/{run_id}/research.md
      ├─ 1.5 blog-fact-checker  → workspace/{run_id}/research.verified.md
      │                          + research.rejected.md  (탈락 audit)
      ├─ 2.  blog-planner       → workspace/{run_id}/plan.md
      ├─ 3.  blog-writer        → workspace/{run_id}/draft.md
      ├─ 4.  blog-reviewer      → workspace/{run_id}/final.md
      ├─ 4.5 blog-image-router  → workspace/{run_id}/image-prompts.json   (선택)
      ├─ 4.6 scripts/codex-images.sh generate
      │                          → workspace/{run_id}/images/*.png
      │                          + images.manifest.json  (codex exec, 선택)
      └─ 5.  blog-publisher     → Notion page URL (meta.json 저장)
```

## 디렉토리

- `.claude/agents/` — 7개 서브에이전트 정의 (researcher / fact-checker / planner / writer / reviewer / image-router / publisher)
- `scripts/codex-images.sh`: 4.6단계 이미지 생성 (`generate`) + placeholder 교체 사본 (`swap`)
- `.claude/skills/blog-pipeline/` — `/blog-pipeline` 슬래시 스킬 진입점
- `.claude/style/` — 톤·금지표현·체크리스트 (모든 에이전트가 SessionStart hook으로 로드)
- `.claude/hooks/` — SessionStart / UserPromptSubmit / PreToolUse / SubagentStop / Stop 자동 체크포인트 (날짜 주입 + 금지표현 차단)
- `workspace/{run_id}/` — 실행별 산출물 (gitignored)
- `examples/` — 참고 글 샘플 (스타일 학습용)

## 발행 타겟

`/blog-pipeline` publisher는 `.env`에 설정한 Notion DB로 발행한다. 사용자가 명시적으로 다른 곳을 지정하지 않는 한 `.env` 값을 사용.

- **Parent page**: `.env`의 `NOTION_PARENT_PAGE_ID` (Notion 페이지 URL 끝 32자 hex)
- **DB**: `.env`의 `NOTION_DATABASE_ID` (inline DB URL 끝 32자 hex)
- **Title field**: `.env`의 `NOTION_DB_TITLE_FIELD` (DB 스키마의 title 속성명, 기본 `이름`)

Notion DB ID 찾기: Notion에서 DB 우상단 `...` → `Copy link` → URL의 마지막 32자 hex가 DB ID.

## 환경 변수

`.env.example` 참고. Notion MCP 서버는 `claude_ai_Notion` 사용 (전역 MCP 설정).

- `NOTION_PARENT_PAGE_ID` — 발행 타겟 부모 페이지 ID
- `NOTION_DATABASE_ID` — 발행 대상 DB ID
- `NOTION_DB_TITLE_FIELD` — 제목 필드명 (기본 `이름`)
- `NOTION_DB_STATUS_FIELD` / `NOTION_DB_STATUS_DRAFT_VALUE` — DB에 Status 속성 추가하면 채우기. 빈 값이면 publisher가 매핑 스킵.

## 모델 매핑

| 에이전트 | 기본 모델 | 비고 |
|---------|---------|------|
| Researcher | haiku | 검색·fetch 대량 처리, 비용 최소화 |
| Fact-Checker | sonnet | URL 재방문 + 주장-본문 매치, 환각 격리 |
| Planner | sonnet | 구조 설계, opus 승격 가능 |
| Writer | sonnet | 본문 생성 |
| Reviewer | opus | 톤·금지표현·가독성 게이트 |
| Image Router | sonnet | placeholder → 이미지 프롬프트 (선택) |
| Image Generator | Codex CLI 기본 모델 | `codex exec` + 내장 `image_gen`, `CODEX_IMAGE_MODEL`로 교체 가능 (선택) |
| Publisher | haiku | MCP 호출만, 정형 작업 |

## 핵심 규칙

1. **각 에이전트는 자기 출력 파일만 생성**. 이전 단계 파일은 read-only.
2. **Planner 이후 단계는 `research.verified.md`만 사실 소스로 사용**. `research.md`(원본)는 참고용, verified에 없으면 사용 금지.
3. **Reviewer는 draft.md를 final.md로 복제 후 편집** — draft.md 보존.
4. **Publisher는 명시적 사용자 승인 후에만 실행** (MCP Notify & Wait 정책).
5. **모든 에이전트는 한국어 본문 작성**. 영어 직역체·번역투 금지.
6. **금지표현은 `.claude/style/forbidden.md`에서 일원 관리**. PreToolUse hook이 자동 차단.
7. **Writer는 1인칭 경험담에도 측정 가능한 디테일(지명·거리·시간·가격·브랜드) 임의 추가 금지**. verified에 있을 때만 구체값 사용.
8. **Fact-Checker verified 비율 < 50%면 Researcher 재실행 신호**. Planner 진입 금지.
9. **모든 자료 조사·검증은 실행 날짜 기준** — 오케스트레이터가 `TODAY` 변수를 Researcher·Fact-Checker prompt에 전달. SessionStart + UserPromptSubmit hook이 컨텍스트에 날짜 자동 주입. Researcher는 쿼리에 최신성 키워드(`YEAR`, "최신") 강제, Fact-Checker는 time-sensitive 주장 출처 12개월 초과면 `stale-source` 카테고리로 reject.

10. **이미지 단계는 선택, final.md는 그대로**. `scripts/codex-images.sh generate`는 `images/`와 `images.manifest.json`만 쓴다. placeholder 교체는 사용자 확인 후 `swap`으로 `final.images.md` 사본에만 한다. `codex exec`는 한 번에 하나, stdin은 닫아서(`< /dev/null`) 실행. 실패한 이미지는 `failed`로 남기고 지어내지 않는다.
11. **실존 상호·장소 이미지는 AI 일러스트로만**. 간판·외관·로고·글자 재현 금지. 글이나 README에 쓸 때 "AI 생성 이미지"라고 밝힌다.

## 에이전트 작업 원칙

- 시스템·개발자·사용자 요청이 이 파일과 스킬보다 우선합니다. 요청이 이어지면 현재 파이프라인의 남은 목적과 산출물을 보존하면서 그 변경을 반영합니다.
- 사용자가 승인한 범위의 조사·검증·초안·검토는 중간 확인을 반복해서 요구하지 말고 끝까지 실행합니다. Notion 발행처럼 외부 상태를 바꾸는 단계는 위의 명시적 승인 규칙을 따릅니다.
- 각 단계의 결과와 실패 원인을 확인한 뒤 다음 단계로 진행하고, 실행한 검증과 남은 제한을 보고합니다.

## 사용

```bash
# 1. .env.example을 .env로 복사 후 NOTION_PARENT_PAGE_ID, NOTION_DATABASE_ID 채우기
cp .env.example .env

# 2. Claude Code 세션 시작 (이 폴더에서)
# 3. /blog-pipeline 글감 주제 또는 키워드
```

Notion MCP 서버(`claude_ai_Notion`)가 글로벌 Claude Code 설정에 연결되어 있어야 함. Anthropic Notion connector 가이드 참조.

이미지 단계를 쓰려면 Codex CLI가 필요하다 (`codex login` 상태가 "Logged in using ChatGPT", `codex features list`에서 `image_generation`이 true). 확인한 버전은 codex-cli 0.163.0.
