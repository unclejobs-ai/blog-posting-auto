---
name: blog-pipeline
description: 주제 또는 키워드를 받아 한국어 블로그 글 한 편을 Researcher→Fact-Checker→Planner→Writer→Reviewer→Publisher 6단계로 생성·발행. Fact-Checker가 환각·오인용을 격리. Reviewer 뒤에 선택 단계로 Codex CLI(`codex exec`) 섹션 이미지 생성. Notion DB에 Draft 페이지 생성까지 자동화. 사용 트리거 — `/blog-pipeline <주제>` 또는 "블로그 글 자동으로 써줘" 같은 요청.
---

# /blog-pipeline

블로그 글 한 편을 6단계 서브에이전트 직렬 실행으로 생성하고 Notion에 발행하는 워크플로우. Researcher가 모은 사실을 Fact-Checker가 원본 URL 재방문으로 검증, downstream(Planner/Writer/Reviewer)은 verified.md만 사실 근거로 사용.

## 실행 순서

오케스트레이터(메인 세션)가 다음을 순서대로 수행:

### 0. 준비

1. **`RUN_ID` + `TODAY` 생성**: slug는 주제에서 한국어→영어 음차 또는 핵심 명사.
   ```bash
   RUN_ID="$(date +%Y%m%d-%H%M%S)-{slug}"
   TODAY="$(date +%Y-%m-%d)"
   mkdir -p workspace/$RUN_ID
   ```
   `TODAY`는 모든 서브에이전트 호출 시 prompt에 박아 전달 — Researcher 최신성 쿼리, Fact-Checker staleness 판정 기준.
2. **`workspace/{RUN_ID}/meta.json`** 초기 기록:
   ```json
   {
     "run_id": "...",
     "topic": "...",
     "today": "YYYY-MM-DD",
     "started_at": "ISO-8601",
     "stages": {}
   }
   ```
3. `.env` 존재 + `NOTION_DATABASE_ID` 채워졌는지 확인. 없으면 사용자에게 알리고 Publisher 단계는 skip 옵션 안내.

### 1. Researcher

```
Agent(subagent_type="blog-researcher", prompt=<<<
RUN_ID: {RUN_ID}
TODAY:  {TODAY}      ← 최신성 쿼리 기준
TOPIC:  {사용자 입력 주제}

workspace/{RUN_ID}/research.md 생성.
모든 WebSearch 쿼리에 {TODAY 연도} 또는 "최신" 키워드 포함.
각 사실에 source-date 메타 부착.
>>>)
```

검증: `workspace/{RUN_ID}/research.md` 존재 + 4KB 이상 + 각 사실에 `(source-date: ...)` 메타 존재.

### 1.5. Fact-Checker

```
Agent(subagent_type="blog-fact-checker", prompt=<<<
RUN_ID: {RUN_ID}
TODAY:  {TODAY}      ← staleness 판정 기준 (TODAY-12개월 미만 출처만 통과)

workspace/{RUN_ID}/research.md의 각 주장을 원본 URL 재방문해 검증.
time-sensitive(가격·시간·정책·버전) 사실은 source-date 12개월 초과면 rejected (stale-source).
research.verified.md + research.rejected.md 생성.
>>>)
```

검증:
- `research.verified.md` 존재 + `research.rejected.md` 존재 (빈 파일이어도 OK)
- stdout 통계 라인 `[fact-checker] ... verified=M rejected=N-M ratio=M/N%` 캡처
- **verified 비율 < 50% → 자동 RETRY**: Researcher 재호출 (최대 2회). 그래도 50% 미만이면 사용자 결정 요청.
- verified 비율 ≥ 50%면 다음 단계 진행.

### 2. Planner

```
Agent(subagent_type="blog-planner", prompt=<<<
RUN_ID: {RUN_ID}

workspace/{RUN_ID}/research.verified.md를 읽고 plan.md 작성.
research.md는 참고만, verified에 없는 사실은 절대 사용 금지.
>>>)
```

검증: `plan.md` 존재 + 섹션 5개 이상.

### 3. Writer

```
Agent(subagent_type="blog-writer", prompt=<<<
RUN_ID: {RUN_ID}

plan.md 따라 draft.md 작성.
사실 출처는 research.verified.md만.
>>>)
```

검증:
- `draft.md` 존재
- 금지표현 grep 0건: `grep -nE -f .claude/style/forbidden.patterns workspace/{RUN_ID}/draft.md`
- UNVERIFIED CLAIM 0건 (Writer 자가검증 #5 통과)

### 4. Reviewer

```
Agent(subagent_type="blog-reviewer", prompt=<<<
RUN_ID: {RUN_ID}

draft.md → final.md. 5단계 검사 통과시키기.
사실 근거는 research.verified.md, rejected.md의 표현은 무조건 제거.
>>>)
```

검증: `final.md` 존재 + 끝에 `<!-- reviewer: PASS / ... / UNVERIFIED K건 모호화 -->` 코멘트.

### 4.5. Image Router (선택)

사용자가 이미지를 원할 때만 실행 (예: `/blog-pipeline <주제> --images`, "이미지도 만들어줘"). 아니면 4.5·4.6 건너뛰고 5단계로.

```
Agent(subagent_type="blog-image-router", prompt=<<<
RUN_ID: {RUN_ID}

workspace/{RUN_ID}/final.md의 📸 placeholder마다 image-prompts.json 항목 작성.
사실 경계는 research.verified.md. final.md 수정 금지.
>>>)
```

검증: `image-prompts.json` 존재 + `jq empty` 통과 + 항목마다 `source_placeholder`가 final.md에 그대로 있음.

### 4.6. Image Generator (선택, `codex exec`)

```bash
scripts/codex-images.sh generate workspace/$RUN_ID < /dev/null
```

- 항목 하나당 `codex exec` 1회, **한 번에 하나씩** 직렬 실행. 병렬 금지 (계정 사용량·속도 제한).
- Codex 내장 `image_gen`이 ChatGPT 로그인(`codex login`)으로 생성. `OPENAI_API_KEY` 불필요.
- 1장에 30초~수 분. Bash timeout을 넉넉히 (10분) 주거나 백그라운드로.
- `codex exec`는 exit 0이어도 실패일 수 있다. 스크립트는 PNG 파일 존재·형식으로만 판정.

산출:

- `images/{filename}.png`
- `images.manifest.json`: `{images: [{section_heading, source_placeholder, prompt, negative_constraints, filename, status}]}`, `status`는 `generated` 또는 `failed`
- `imagegen-logs/`: 항목별 프롬프트·codex 로그 (실패 원인 확인용)

검증: manifest의 `generated` 수 = image-prompts.json 항목 수. `failed`가 있으면 로그 끝부분을 사용자에게 보여 주고 재시도/스킵 선택받기.

**placeholder 교체 (final.md는 그대로)**

이미지를 확인한 뒤 사용자가 원하면:

```bash
scripts/codex-images.sh swap workspace/$RUN_ID
```

- `final.md`를 읽어 `final.images.md` 사본을 만든다. `status=generated`인 항목의 `source_placeholder` 줄을 `![설명](images/{filename})`로 **그 자리에서** 바꾼다. `failed` 항목의 placeholder는 남는다.
- `final.md`는 수정하지 않는다 (핵심 규칙 1). Publisher는 계속 `final.md`를 발행한다.
- Notion은 로컬 상대 경로 이미지를 읽지 못한다. 이미지는 Notion 페이지에 직접 올리거나, 상대 경로 이미지를 지원하는 다른 발행 타겟에서 `final.images.md`를 쓴다.

### 5. Publisher (명시 승인 후)

오케스트레이터가 사용자에게 미리보기 1줄 보여주고 명시 OK 받기:

```
제목: {제목}
대상: Notion DB ({NOTION_DATABASE_ID})
태그: {N개}
발행할까요?
```

OK 받으면:

```
Agent(subagent_type="blog-publisher", prompt=<<<
RUN_ID: {RUN_ID}

final.md를 NOTION_DATABASE_ID DB에 발행.
>>>)
```

검증: `meta.json.page_url` 존재.

## 산출물 디렉토리

```
workspace/{RUN_ID}/
├── meta.json              # 실행 메타 (단계별 시작/종료 시각, 모델, 토큰, fact-check ratio)
├── research.md            # 1단계 산출 (원본, audit용)
├── research.verified.md   # 1.5단계 산출 (downstream의 유일한 사실 진실원)
├── research.rejected.md   # 1.5단계 산출 (탈락 사유 + 항목, audit/디버깅)
├── plan.md                # 2단계 산출
├── draft.md               # 3단계 산출
├── final.md               # 4단계 산출 (Notion 발행 원본)
├── image-prompts.json     # 4.5단계 산출 (선택)
├── images/                # 4.6단계 산출 (선택, *.png)
├── images.manifest.json   # 4.6단계 산출 (선택)
├── imagegen-logs/         # 4.6단계 codex 로그 (선택)
├── final.images.md        # swap 산출 (선택, 이미지 줄 들어간 사본)
└── notion-payload.json    # 5단계 직전 페이로드 (디버깅용)
```

## 오케스트레이터 규칙

- **단계 실패 시 다음 단계로 진행 금지**. 사용자에게 사유 보고 후 재시도/스킵 선택권.
- **단계 간 결과물 검증은 오케스트레이터 책임**. 서브에이전트 자체 평가 신뢰하지 말 것.
- **Fact-Checker verified 비율 < 50% 시 Researcher 재호출** (최대 2회). 그래도 미달이면 사용자 결정.
- **Publisher는 항상 사용자 명시 승인 후에만 호출**.
- **이미지 단계는 선택**. `codex exec`는 한 번에 하나만. 실패한 이미지는 지어내지 말고 manifest의 `failed`와 로그로 보고.
- **Reviewer 실패 시**: 사유 보고 → Writer 재호출 (최대 2회) → 그래도 실패면 사용자에게 결정 요청.

## 참고

- 톤·금지표현·체크리스트: `.claude/style/` 전체
- 참고 글 샘플: `examples/` (5개 카테고리: food / travel / tutorial / comparison / activity)
- 에이전트 정의: `.claude/agents/blog-{researcher,fact-checker,planner,writer,reviewer,image-router,publisher}.md`
- 이미지 생성 스크립트: `scripts/codex-images.sh`
- Hook 자동 체크포인트: `.claude/hooks/`
