# YouTube 영상 기획서: Claude Code가 Codex OAuth로 이미지를 만드는 블로그 자동화

## 한 줄 기획

Claude Code가 블로그 글 자동화 파이프라인을 지휘하고, 중간에 Codex를 headless worker로 호출해서 Codex 내장 `image_gen` 도구로 이미지를 만드는 구조를 쉽게 보여준다.

## 영상 목표

- `blog-pipeline`이 단순 글쓰기 자동화가 아니라, 다른 AI 도구를 하위 작업자로 부를 수 있는 오케스트레이터라는 점을 보여준다.
- Claude Code와 Codex의 역할을 헷갈리지 않게 분리한다.
- 시청자가 영상을 보고 "아, Claude Code가 Codex를 불러서 OAuth 기반 이미지 생성까지 맡기는 구조구나"라고 이해하게 만든다.
- 이 영상은 정규 트랙의 맛보기다. 유튜브에서는 큰 그림과 실제 데모를 보여주고, Mac mini/켜져 있는 PC/VPS 운영, queue, retry, app-server JSON-RPC, Spark worker 배치는 후속 정규 트랙에서 세세히 다룬다.

## 핵심 메시지

> Claude Code는 전체 워크플로우를 관리하고, Codex는 이미지 생성 같은 특정 작업을 headless로 처리한다.

정정해야 할 중요한 포인트:

> Codex imagegen의 기본 경로는 Python CLI가 아니다. 공식 `openai/codex` 샘플 기준으로 기본은 Codex 내장 `image_gen` 도구이며, 이 경로는 `OPENAI_API_KEY`가 필요 없다. `scripts/image_gen.py` CLI는 fallback 경로이고, 그때만 API 키가 필요하다.

쉽게 말하면:

- Claude Code: 감독, 진행자, 파이프라인 관리자
- Codex: 이미지 생성 전담 작업자
- Image Prompt Router Agent: 글 섹션을 읽고 이미지 프롬프트로 바꾸는 중간 라우터
- Codex 내장 `image_gen`: 실제 이미지를 만드는 도구
- Codex OAuth: `OPENAI_API_KEY` 대신 쓰는 로그인 경로
- `scripts/image_gen.py`: 명시적으로 CLI fallback을 선택했을 때만 쓰는 보조 경로
- `workspace/{RUN_ID}`: 둘이 결과물을 주고받는 작업 폴더

## 추천 영상 제목

1. Claude Code가 Codex를 부르면 자동화가 어디까지 될까?
2. 블로그 자동화에 이미지 생성까지 붙이는 방법
3. Claude Code + Codex OAuth 이미지 자동화 구조 쉽게 보기
4. AI 에이전트끼리 일 시키는 블로그 파이프라인 만들기

## 썸네일 문구

- Claude Code가 Codex를 호출?
- 글 작성 + 이미지 생성 자동화
- API 키 없이 이미지 생성?
- AI 에이전트 협업 구조
- 블로그 파이프라인 완성하기

## 예상 시청자

- Claude Code를 써봤지만 자동화 구조는 아직 낯선 사람
- Codex와 Claude Code를 같이 쓰는 방법이 궁금한 사람
- 블로그, Notion, 이미지 생성 자동화를 만들고 싶은 사람
- AI 에이전트 워크플로우를 실제 프로젝트에 붙이고 싶은 개발자

## 영상 길이

권장 길이: 12-18분

- 너무 짧으면 구조가 안 잡힘
- 너무 길면 `Claude Code`, `Codex`, `OAuth`, `image_gen`, `Notion`이 섞여서 어렵게 느껴짐

## 영상 흐름

### 0. 오프닝 - 30초

보여줄 것:

- 최종 목표 화면
- `workspace/{RUN_ID}` 폴더 구조
- 생성된 글과 이미지 파일 예시

말할 내용:

> 오늘은 Claude Code가 블로그 글을 만들고, 중간에 Codex를 불러서 이미지까지 생성하는 자동화 구조를 보여드릴게요. 핵심은 Claude Code가 모든 걸 직접 하는 게 아니라, 필요한 순간에 Codex를 headless 작업자로 호출한다는 점입니다. 그리고 이 방식은 OpenAI API 키가 아니라 Codex OAuth 로그인을 사용합니다.

### 0.5. 유튜브에서 테스트는 어디까지 보여줄까 - 30초

유튜브에서는 정규 트랙 전체 구현을 다 하지 않는다. 대신 작은 smoke test만 보여준다.

보여줄 테스트:

```text
final.md의 섹션 하나를 Spark worker에게 전달
  ↓
Spark가 이미지 프롬프트 JSON 생성
  ↓
JSON schema가 맞는지 확인
  ↓
테스트 파일 삭제
```

이 테스트의 목적:

- Spark가 실제로 `codex exec`에서 호출되는지 확인
- Spark가 이미지 프롬프트 라우터 역할을 할 수 있는지 확인
- 실제 이미지 생성이나 Notion 발행은 정규 트랙에서 다룬다고 선을 긋기

후속으로 Spark prompt를 실제 `image_gen` worker에 넘기는 end-to-end smoke test도 가능하다. 이 경우 이미지는 1장만 생성하고, `/tmp`에 저장해 PNG 여부와 해상도만 확인한 뒤 테스트 파일과 새 generated_images 캐시 디렉터리를 삭제한다.

말할 내용:

> 여기서는 전체 자동화 서버를 완성하지 않고, Spark가 섹션을 읽고 이미지 프롬프트 JSON을 만들 수 있는지만 확인하겠습니다. 실제 queue, retry, app-server, Notion Draft 발행은 정규 트랙에서 구현합니다.

### 1. 현재 블로그 파이프라인 소개 - 1분

보여줄 것:

- `.claude/skills/blog-pipeline/SKILL.md`
- `.claude/agents/`
- `workspace/{RUN_ID}/`

설명:

현재 구조는 다음 순서로 움직인다.

```text
Researcher
→ Fact-Checker
→ Planner
→ Writer
→ Reviewer
→ Publisher
```

쉽게 풀어서:

- Researcher: 자료 조사
- Fact-Checker: 사실 검증
- Planner: 글 구조 설계
- Writer: 초안 작성
- Reviewer: 최종 글 다듬기
- Publisher: Notion 발행

강조할 점:

> 이 파이프라인은 이미 글을 만들 수 있습니다. 그런데 글 안에는 `📸 [사진 설명]` 같은 이미지 자리가 생깁니다. 이 부분을 실제 이미지 파일로 바꾸고 싶어서 Codex를 붙이는 겁니다.

### 2. 헷갈리는 지점 정리 - 1분

핵심 정리:

```text
헷갈리기 쉬운 구조:
Claude Code가 Python image API 스크립트를 직접 실행한다

우리가 확인한 구조:
Claude Code skill이 codex exec를 실행하고,
Codex가 내부 image_gen 도구를 OAuth로 호출한다
```

말할 내용:

> 여기서 중요한 건 라우팅입니다. Claude Code가 직접 OpenAI REST API를 호출하는 게 아닙니다. Claude Code가 `codex exec`를 실행하고, Codex가 자기 안의 내장 `image_gen` 도구를 사용합니다. OAuth 토큰은 REST API에 바로 넣으면 401이 나지만, `codex exec` 안에서는 Codex가 내부 브릿지로 처리합니다.

### 3. 전체 구조 그림 - 2분

보여줄 다이어그램:

```text
사용자
  ↓
/blog-pipeline
  ↓
Claude Code 오케스트레이터
  ↓
글 생성 단계
  ↓
final.md 생성
  ↓
Image Prompt Router가 섹션별 이미지 의도 추출
  ↓
Claude Code가 codex exec 실행
  ↓
Codex headless worker
  ↓
Codex 내장 image_gen 실행
  ↓
Codex OAuth 인증 사용
  ↓
이미지 파일 + manifest 생성
  ↓
Claude Code가 결과 확인
  ↓
Notion 발행
```

쉬운 비유:

> Claude Code는 PD처럼 전체 순서를 관리합니다. Codex는 이미지팀처럼 필요한 장면에서 호출됩니다. 이미지를 만드는 인증과 실행은 Codex 안에서 처리되고, 둘은 `workspace` 폴더를 통해 결과물을 주고받습니다.

### 4. 이미지가 들어갈 위치와 프롬프트 라우터 - 2분

중요한 위치 규칙:

```markdown
# 🚉 본전돼지국밥 — 부산역 내리면 바로

![section image](images/section-02-bonjeon-soup.png)

부산역에서 내려 짐도 못 풀었을 때 가기 딱 좋은 곳입니다...
```

이미지는 섹션 끝에 붙는 장식이 아니라, **부제와 본문 사이**에 들어간다.

그래서 단순히 `📸 [사진 설명]`만 보고 만들면 부족하다. 라우터는 다음을 같이 읽어야 한다.

- 섹션 제목: 독자가 처음 보는 맥락
- 섹션 본문 첫 1-3문단: 장소, 분위기, 핵심 메시지
- 기존 `📸` placeholder: 작성자가 의도한 장면
- `research.verified.md`: 실제 사실 경계

Image Prompt Router Agent의 역할:

```text
입력:
- final.md
- section heading
- section body
- optional photo placeholder
- research.verified.md

출력:
- image slot 위치
- image prompt
- negative constraints
- filename
- manifest entry
```

라우팅 규칙:

- 본문을 그대로 설명하는 이미지가 아니라, 섹션을 열어주는 장면으로 만든다.
- 검증되지 않은 간판명, 가격, 주소, 로고, 메뉴판 글자는 이미지에 넣지 않는다.
- 식당/장소 글은 실제 상호 재현보다 "분위기와 음식" 중심으로 간다.
- 텍스트 렌더링은 피한다. 이미지 안에 한글 간판, 메뉴판 문구를 요구하지 않는다.
- 블로그 본문과 겹치지 않게, 독자가 스크롤을 멈출 수 있는 시각 앵커를 만든다.

예시:

```json
{
  "section_heading": "🚉 본전돼지국밥 — 부산역 내리면 바로",
  "insert_after_heading": true,
  "source_placeholder": "📸 [본전돼지국밥 국물과 부추무침]",
  "prompt": "Editorial Korean food blog photo: a steaming bowl of Busan-style pork rice soup in a black ttukbaegi, fresh chive salad and kimchi side dishes on a simple table, warm casual restaurant lighting, travel-meal feeling right after arriving by train, shallow depth of field, realistic texture, no readable text, no logos, no watermark",
  "filename": "section-02-bonjeon-soup.png"
}
```

### 5. codex-image repo가 쓰는 2중 라우팅 - 2분

보여줄 구조:

```text
/codex-image 프롬프트
  ↓
Claude Code skill
  ↓
Bash: codex exec "Use built-in image_gen..."
  ↓
Codex CLI
  ↓
~/.codex/auth.json의 ChatGPT OAuth 세션 확인
  ↓
Codex 내장 image_gen 도구
  ↓
gpt-image-2
  ↓
~/.codex/generated_images/<session>/ig_*.png
  ↓
프로젝트 폴더로 복사
```

핵심:

- OAuth 토큰은 `sk-*` API 키가 아니다.
- OAuth 토큰으로 OpenAI REST API를 직접 호출하면 실패한다.
- 하지만 `codex exec` 내부에서는 Codex가 OAuth 인증을 이미지 생성 서비스로 라우팅한다.
- 그래서 `OPENAI_API_KEY` 없이도, `codex login`이 되어 있으면 이미지 생성이 가능하다.
- 공식 `openai/codex` imagegen 샘플도 기본 모드를 내장 `image_gen`으로 두고, CLI/API 경로는 fallback으로 분리한다.

### 6. Codex를 부르는 실제 명령 - 2분

보여줄 명령:

```bash
codex exec --ephemeral \
  -C "$CLAUDE_PROJECT_DIR" \
  -s workspace-write \
  -a never \
  -o "workspace/$RUN_ID/imagegen.codex.md" \
  "Read workspace/$RUN_ID/final.md.
Extract every 📸 placeholder.
For each placeholder, use the built-in image_gen tool to generate a matching blog image.
Save images under workspace/$RUN_ID/images/.
Write workspace/$RUN_ID/images.manifest.json.
Do not edit final.md."
```

쉽게 설명:

- `codex exec`: Codex를 headless로 실행
- `--ephemeral`: 세션 기록을 오래 남기지 않는 일회성 실행
- `-C`: 작업할 프로젝트 루트 지정
- `-s workspace-write`: 프로젝트 workspace 안에 파일을 쓸 수 있게 허용
- `-a never`: 중간에 사용자 승인 질문을 하지 않음
- `-o`: Codex의 최종 보고서를 파일로 저장
- `built-in image_gen`: Codex 안에서만 호출되는 이미지 생성 도구

강조할 점:

> Claude Code는 이 명령을 Bash로 실행하기만 합니다. 실제 이미지 프롬프트 작성, OAuth 인증, `image_gen` 호출은 Codex가 맡습니다.

### 7. 산출물 계약 만들기 - 2분

중요한 이유:

AI끼리 일을 나눌 때는 "어디까지 해도 되는지"를 명확히 해야 한다.

Codex에게 줄 규칙:

```text
해도 되는 것:
- final.md 읽기
- 📸 placeholder 추출
- 이미지 프롬프트 생성
- workspace/{RUN_ID}/images/ 아래 이미지 저장
- images.manifest.json 생성

하면 안 되는 것:
- final.md 수정
- research.verified.md 수정
- Notion 발행
- 검증되지 않은 사실 추가
```

권장 산출물:

```text
workspace/{RUN_ID}/
├── final.md
├── images/
│   ├── section-01.png
│   ├── section-02.png
│   └── section-03.png
├── image-prompts.json
├── images.manifest.json
└── imagegen.codex.md
```

`images.manifest.json` 예시:

```json
{
  "run_id": "20260525-223000-topic",
  "images": [
    {
      "placeholder": "📸 [따뜻한 분위기의 카페 입구]",
      "file": "workspace/20260525-223000-topic/images/section-01.png",
      "prompt": "A warm editorial blog photo of a cafe entrance, no text, no logo",
      "status": "generated"
    }
  ]
}
```

### 7. blog-pipeline에 붙일 위치 - 1분

추천 위치:

```text
4. Reviewer
4.5 Image Prompt Router
4.6 Image Generator
5. Publisher
```

이유:

- Writer 단계의 초안은 아직 바뀔 수 있다.
- Reviewer가 최종 글을 만든 뒤에 이미지 placeholder가 안정된다.
- Prompt Router가 섹션 제목과 본문을 보고 이미지 의도를 정리한다.
- Publisher 직전에 이미지를 만들면 Notion 발행에 같이 넣기 쉽다.

말할 내용:

> 이미지는 final.md가 나온 뒤에 만드는 게 좋습니다. 먼저 Prompt Router가 섹션별 이미지 의도를 정리하고, 그 결과를 Codex image_gen 단계가 받아서 실제 파일을 만듭니다.

### 8. headless flags 설명 - 1분 30초

Claude Code 쪽에서 필요한 것:

```bash
claude -p \
  --output-format stream-json \
  --permission-mode dontAsk \
  --allowedTools "Read,Write,Edit,Grep,Glob,Bash(codex exec:*)" \
  '/blog-pipeline "주제" --images --no-publish'
```

설명:

- `claude -p`: Claude Code를 비대화형으로 실행
- `--output-format stream-json`: 진행 상황을 로그로 받기 좋음
- `--permission-mode dontAsk`: 미리 허용한 도구만 사용
- `--allowedTools`: Claude Code가 실행할 수 있는 도구 제한
- `Bash(codex exec:*)`: Claude Code가 Codex worker를 부를 수 있게 허용

주의:

> 여기서 Claude Code가 직접 `python image_gen.py`를 실행하는 게 아닙니다. Claude Code는 `codex exec`만 실행하고, 그 안에서 Codex가 내장 `image_gen` 도구를 사용합니다.

### 9. 실제 데모 순서 - 2분

데모 순서:

1. `/blog-pipeline "주제"` 실행
2. `final.md` 생성 확인
3. `final.md` 안의 `📸` placeholder 확인
4. Claude Code가 `codex exec`를 실행하는 부분 보여주기
5. Codex 결과 파일 `imagegen.codex.md` 확인
6. `~/.codex/generated_images/<session>/`에 원본이 생기는 구조 설명
7. `images/` 폴더 확인
8. `images.manifest.json` 확인
9. Notion 발행 전 미리보기 보여주기

화면에 크게 보여줄 포인트:

```text
Claude Code: 전체 파이프라인 진행
Codex: 이미지 생성 전담
image_gen: Codex 안에서 실행되는 내장 도구
OAuth: API 키 대신 쓰는 인증 경로
workspace: 결과물 교환 장소
```

### 10. 주의할 점 - 1분

꼭 말해야 할 것:

- 이 구조는 `OPENAI_API_KEY`가 아니라 `codex login`이 필요하다.
- Codex가 "Logged in using ChatGPT" 상태여야 한다.
- Codex의 `image_generation` 기능이 켜져 있어야 한다.
- `OPENAI_API_KEY`가 필요한 경우는 사용자가 명시적으로 CLI/API fallback을 선택했을 때다.
- 이미지 생성 비용은 계정/플랜 정책을 따른다.
- 이미지 생성 결과가 마음에 안 들면 재시도 로직이 필요하다.
- Notion에 로컬 이미지를 바로 넣을 수 있는지는 별도 확인이 필요하다.
- Publisher는 사용자 승인 후 실행하는 기존 규칙을 유지하는 게 안전하다.

짧게 정리:

> 자동화는 가능하지만, 발행까지 완전 무인으로 돌리는 건 조심해야 합니다. 이미지는 Codex OAuth로 만들 수 있지만, Notion 발행은 기존처럼 승인 단계를 남겨두는 편이 안전합니다.

### 11. 마무리 - 30초

말할 내용:

> 오늘 구조의 핵심은 간단합니다. Claude Code가 전체 블로그 파이프라인을 관리하고, 이미지가 필요한 순간에 Codex를 headless worker로 호출합니다. Codex는 OAuth 로그인과 내장 `image_gen` 도구로 이미지를 만들고, 결과만 workspace에 남깁니다. 이렇게 역할을 나누면 Claude Code와 Codex를 하나의 자동화 워크플로우처럼 사용할 수 있습니다.

## 영상에서 쓰면 좋은 짧은 표현

- "Claude Code는 감독, Codex는 작업자입니다."
- "API 키를 넘기는 게 아니라, Codex OAuth 경로를 타는 구조입니다."
- "둘은 workspace 폴더를 통해 대화합니다."
- "Claude Code는 `codex exec`만 실행합니다."
- "`image_gen`은 Codex 안에서 실행되는 내장 도구입니다."
- "이미지는 final.md가 나온 뒤에 만드는 게 안전합니다."

## 피해야 할 설명

- "Claude Code가 OpenAI REST API를 직접 호출한다"
- "Codex가 Claude Code를 호출한다"
- "이미지 생성까지 Claude Code가 직접 한다"
- "OAuth 토큰을 API 키처럼 REST에 넣으면 된다"
- "Notion 발행까지 무조건 완전 자동화한다"

위 표현들은 실제 구조와 다르게 들릴 수 있다.

## 촬영 체크리스트

- [ ] `codex --version` 확인
- [ ] `codex exec --help` 확인
- [ ] `codex login status`가 "Logged in using ChatGPT"인지 확인
- [ ] `codex features list`에서 `image_generation` 상태 확인
- [ ] `.claude/skills/blog-pipeline/SKILL.md` 열어두기
- [ ] `wjb127/codex-image`의 `SKILL.md` 열어두기
- [ ] 샘플 `final.md` 준비
- [ ] `📸` placeholder가 들어간 예시 준비
- [ ] `~/.codex/generated_images/` 구조 보여주기
- [ ] `workspace/{RUN_ID}/images/` 생성 장면 준비
- [ ] `images.manifest.json` 예시 준비
- [ ] Notion 발행은 승인 단계가 필요하다고 언급

## 구현 문서로 이어질 다음 단계

이 영상은 개념 설명과 구조 소개에 집중한다.

후속 영상이나 문서에서는 다음을 다룰 수 있다.

1. `blog-image-generator` 단계 실제 추가
2. Claude Code에서 `codex exec`를 호출하는 권한 설정
3. `images.manifest.json` 스키마 확정
4. Notion 이미지 업로드 방식 결정
5. 실패 시 재시도 로직 추가

## 최종 한 문장

Claude Code가 전체 글 자동화를 맡고, Codex가 OAuth 기반 내장 `image_gen`으로 이미지를 만드는 하위 작업자가 되면, API 키 없이도 블로그 글과 이미지까지 이어지는 자동화 워크플로우를 만들 수 있다.

## 후속 정규 세션 설계서

이 영상의 후속 트랙으로, Mac mini 또는 VPS에 Codex app-server와 Codex worker를 띄워두고 블로그 글, 섹션 이미지, Notion Draft 발행까지 자동화하는 상세 설계는 별도 문서로 분리했다.

- [YOUTUBE_CODEX_APP_SERVER_AUTOMATION_TRACK.md](./YOUTUBE_CODEX_APP_SERVER_AUTOMATION_TRACK.md)

후속 문서에서는 Mac mini가 있는 경우, Mac mini가 없지만 개인 컴퓨터를 켜둘 수 있는 경우, VPS에서 돌리는 경우를 나눠 설명한다. 또한 `gpt-5.3-codex-spark`를 실제 worker로 쓸 수 있는지 smoke test하는 절차와, Spark를 어떤 낮은 위험 작업에 배치할지도 별도로 다룬다.
