# YouTube 정규 세션 설계서: Mac mini/켜져 있는 PC/VPS에서 돌아가는 Claude Code x Codex App Server 블로그 자동화 서버

## 문서 목적

이 문서는 기존 `YOUTUBE_VIDEO_PLAN.md`의 후속 상세 설계서다.

기존 영상 기획은 다음 한 가지를 설명했다.

```text
Claude Code가 블로그 파이프라인을 지휘하고,
이미지가 필요한 순간 Codex를 headless worker로 불러
Codex 내장 image_gen으로 섹션 이미지를 생성한다.
```

이 문서는 그 아이디어를 한 단계 더 확장한다.

```text
Mac mini 또는 VPS에 자동화 서버를 띄워두고,
매일 또는 큐에 쌓인 주제마다 블로그 글, 이미지, Notion Draft 발행까지
밤새 자동으로 돌리는 워크플로우를 설계한다.
```

핵심은 이것이다.

```text
Claude Code는 설계자이자 오케스트레이터다.
Codex는 headless worker이자 자동화 실행 엔진이다.
Codex app-server는 장기적으로 붙일 수 있는 상시 실행 백엔드다.
Spark 계열 모델은 저비용 반복 작업용 worker로 활용한다.
```

이 문서는 Fronmpt Academy의 별도 정규 트랙으로 가져갈 수 있게, 맥락 설명과 구조, 워커 역할, 실패 처리, 운영 방식, 촬영 흐름까지 모두 포함한다.

유튜브에서는 이 전체 내용을 한 번에 다 설명하지 않는다.

```text
YouTube:
  맛보기, 문제의식, 큰 구조, 실제 생성 데모

Fronmpt Academy 정규 트랙:
  워커 설계, 큐, app-server, Spark 활용, 운영 자동화, 보안, 실패 처리까지 세세하게 구현
```

이 분리가 중요하다. 유튜브에서 너무 깊게 들어가면 `Claude Code`, `Codex`, `app-server`, `Spark`, `image_gen`, `Notion`, `Mac mini`가 한꺼번에 섞여 어렵게 느껴진다. 유튜브는 "왜 이 구조가 필요한가"와 "실제로 되는가"를 보여주고, 정규 트랙에서 "어떻게 안정적으로 굴리는가"를 다룬다.

---

## 한 줄 기획

자고 일어나면 검증된 블로그 초안과 섹션 이미지가 Notion Draft에 쌓이는 개인 AI 자동화 서버를 만든다.

---

## 유튜브와 정규 트랙의 역할 분리

### 유튜브에서 보여줄 것

유튜브는 맛보기다.

목표는 시청자가 아래 정도를 이해하는 것이다.

```text
아, Claude Code가 전체 파이프라인을 관리하고
Codex를 worker처럼 불러서 이미지 생성까지 맡길 수 있구나.
Mac mini나 켜져 있는 컴퓨터에 올려두면 자동화 서버처럼 쓸 수 있겠구나.
```

유튜브에서 다룰 범위:

```text
1. 기존 blog-pipeline 구조 소개
2. Claude Code가 Codex를 부르는 방향 정리
3. Codex built-in image_gen으로 이미지가 실제 생성되는 데모
4. 섹션 제목과 본문을 읽고 이미지 프롬프트를 만드는 개념
5. Mac mini/켜져 있는 PC/VPS에서 자동화할 수 있다는 큰 그림
6. app-server는 이미지 API가 아니라 Codex 세션 제어 서버라는 정도의 설명
```

유튜브에서 깊게 들어가지 않을 것:

```text
JSON-RPC app-server bridge 구현
SQLite queue schema 전체 구현
Notion block 변환기 세부 구현
retry/backoff 코드
launchd/systemd 파일 완성본
모델별 비용/usage 최적화
운영 대시보드 구현
```

### 정규 트랙에서 다룰 것

정규 트랙은 구현 과정이다.

목표는 수강자가 자기 컴퓨터나 서버에서 아래 결과를 만들게 하는 것이다.

```text
매일 정해진 시간에 주제가 하나 처리된다.
검증된 final.md가 생긴다.
섹션별 이미지가 생성된다.
Notion Draft에 글이 쌓인다.
실패하면 어디서 왜 멈췄는지 알 수 있다.
```

정규 트랙에서 다룰 범위:

```text
1. job_queue.sqlite 설계
2. run_daily_blog.sh 또는 Node runner 작성
3. worker별 입력/출력 계약 확정
4. Spark worker smoke test
5. Image Prompt Router 구현
6. Codex Image Generator 구현
7. 이미지 QA와 1회 재시도
8. final.with-images.md 또는 Notion payload builder
9. launchd/cron/systemd 배포
10. app-server JSON-RPC 확장
11. 보안과 token 관리
12. 운영 대시보드 구상
```

### 한 문장으로 나누기

```text
유튜브는 "이게 된다"를 보여준다.
정규 트랙은 "내 컴퓨터에서 계속 돌아가게 만든다"를 만든다.
```

---

## 추천 트랙 이름

### 1안

```text
Codex Automation Lab
```

짧고 강의 트랙 이름으로 쓰기 좋다.

### 2안

```text
Claude Code x Codex App Server 자동화 워크플로우
```

기술 키워드가 명확하다.

### 3안

```text
AI 블로그 파이프라인 실전 구축
```

입문자에게 가장 이해가 쉽다.

### 영상 제목 후보

1. 자고 일어나면 블로그 초안이 완성되는 AI 자동화 서버 만들기
2. Claude Code와 Codex로 블로그 자동 발행 파이프라인 구축하기
3. Mac mini에 Codex worker를 띄워두고 밤새 블로그를 쓰게 만들기
4. API 키 없이 Codex image_gen까지 붙인 블로그 자동화 서버
5. Claude Code가 설계하고 Codex가 실행하는 AI 콘텐츠 공장 만들기

---

## 시청자가 먼저 알아야 할 맥락

이 영상은 단순히 "AI로 블로그 글 써보기"가 아니다.

이미 이 프로젝트에는 다음 구조가 있다.

```text
/blog-pipeline <주제>
  -> Researcher
  -> Fact-Checker
  -> Planner
  -> Writer
  -> Reviewer
  -> Publisher
```

각 단계는 `workspace/{RUN_ID}/` 아래에 결과물을 남긴다.

```text
workspace/{RUN_ID}/
├── meta.json
├── research.md
├── research.verified.md
├── research.rejected.md
├── plan.md
├── draft.md
├── final.md
└── notion-payload.json
```

이 구조의 장점은 "글이 만들어진다"가 아니라, **검증된 사실만 downstream으로 흘러간다**는 점이다.

```text
Researcher가 자료를 모은다.
Fact-Checker가 원문 URL을 다시 확인한다.
Planner, Writer, Reviewer는 research.verified.md만 사실 소스로 본다.
```

그래서 블로그 자동화에서 흔한 문제가 줄어든다.

- 출처 없는 가격을 마음대로 쓰는 문제
- 영업시간이 오래된 글에서 온 문제
- 인용문을 그럴듯하게 만들어내는 문제
- 1인칭 경험담인 척 지명, 거리, 가격을 꾸며내는 문제
- 검증에서 탈락한 내용을 Writer가 다시 살리는 문제

이 문서의 확장은 여기에 두 가지를 붙이는 것이다.

1. 섹션별 이미지 자동 생성
2. Mac mini/VPS에서 계속 돌아가는 자동화 운영

---

## 우리가 대화에서 확인한 핵심 사실

### 1. Claude Code가 Codex를 부르는 구조다

처음 헷갈리기 쉬운 지점은 방향이다.

잘못 이해하면 이렇게 생각할 수 있다.

```text
Codex가 Claude Code를 부른다.
```

하지만 이 프로젝트에서 원하는 구조는 반대다.

```text
Claude Code가 Codex를 부른다.
```

역할을 나누면 이렇게 된다.

```text
Claude Code
  - 전체 파이프라인 설계
  - 워커 호출 순서 결정
  - 단계별 검증
  - 실패 시 재시도/중단 판단
  - Notion 발행 승인 게이트 관리

Codex
  - headless worker
  - 특정 작업 실행
  - 이미지 생성
  - 파일 저장
  - manifest 작성
  - 반복적이고 독립적인 작업 처리
```

### 2. Codex imagegen 기본 경로는 OPENAI_API_KEY가 아니다

중요한 정정 포인트다.

기본 경로는 Python API 스크립트가 아니다.

```text
기본 경로:
Codex built-in image_gen tool
```

이 경로는 `codex login`으로 로그인된 ChatGPT/Codex 세션을 사용한다.

```text
codex login status
-> Logged in using ChatGPT
```

이때 생성 이미지는 보통 아래에 생긴다.

```text
~/.codex/generated_images/<session-id>/ig_*.png
```

그 다음 프로젝트에서 쓰려면 workspace로 복사한다.

```text
~/.codex/generated_images/<session-id>/ig_*.png
  -> workspace/{RUN_ID}/images/section-04-milyang-soup.png
```

`OPENAI_API_KEY`가 필요한 경우는 별도다.

```text
fallback CLI/API 경로를 명시적으로 선택했을 때
```

즉, 이 트랙에서 보여줄 기본 설명은 이렇다.

```text
Claude Code가 OpenAI REST API를 직접 때리는 게 아니다.
Claude Code가 codex exec를 실행한다.
Codex가 자기 안의 built-in image_gen을 사용한다.
이 경로는 API key가 아니라 Codex/ChatGPT 로그인 사용량 쪽으로 간다.
```

### 3. Codex 사용량 안에서 차감되는 구조로 봐야 한다

우리가 실험한 경로는 `OPENAI_API_KEY` 기반 API 과금이 아니었다.

```text
codex exec
  -> built-in image_gen
  -> ChatGPT/Codex 로그인 세션
```

따라서 일반적인 OpenAI API billing이 아니라, Codex/ChatGPT 플랜의 usage/rate limit 쪽에서 관리된다고 보는 게 맞다.

다만 "하루에 정확히 이미지 N장"처럼 고정 숫자로 문서화된 구조는 아니다.

운영 설계에서는 이렇게 봐야 한다.

```text
정확한 일일 이미지 개수에 기대지 않는다.
rate limit을 읽고, 실패하면 backoff/retry 한다.
일일 생성량 예산을 자체적으로 둔다.
```

예:

```json
{
  "daily_image_budget": 20,
  "max_images_per_post": 5,
  "max_retry_per_image": 1,
  "publish_mode": "draft_only"
}
```

### 4. 우리가 실제로 만든 이미지 구조

실험에서 생성한 블로그 이미지는 아래 경로에 저장됐다.

```text
workspace/20260519-173301-busan-pork-soup/images/
├── section-02-bonjeon-soup.png
├── section-03-halmae-soup.png
├── section-04-milyang-soup.png
├── section-05-joseon-soup.png
└── section-06-ssangdungi-soup.png
```

manifest는 아래 파일에 기록했다.

```text
workspace/20260519-173301-busan-pork-soup/images.manifest.sample.json
```

여기서 중요한 학습이 있었다.

처음에는 이미지가 너무 "상차림 전체샷"으로 갔다.

사용자 피드백:

```text
그런 것보다는 먹는 모습이라던가,
국밥 떠서 확대하는 샷이라던가
그런걸로 가주면 좋을 것 같은데?
```

그래서 프롬프트 방향을 바꿨다.

```text
상차림 전체샷
  -> 숟가락이 올라오는 순간
  -> 국밥 한 숟갈 클로즈업
  -> 젓가락으로 수육을 집는 장면
  -> 먹기 직전의 손 동작
```

이건 앞으로 Image Prompt Router의 핵심 규칙에 넣어야 한다.

```text
맛집/음식 블로그 이미지는 정적인 식탁 사진만 만들지 않는다.
섹션을 여는 이미지는 "먹고 싶게 만드는 행동 장면"을 우선한다.
```

---

## Codex app-server에 대한 판단

### app-server는 이미지 API 서버가 아니다

`codex app-server`는 이미지 생성만 해주는 API 서버가 아니다.

공식 `openai/codex` README 기준으로, app-server는 Codex VS Code extension 같은 rich client를 구동하기 위한 JSON-RPC 서버다.

제공하는 개념은 대략 이렇다.

```text
Thread
Turn
Item
command/exec
fs/readFile
account/read
account/rateLimits/read
mcpServer/tool/call
turn/start
thread/start
```

따라서 app-server를 이 프로젝트에 붙인다는 말은 이런 뜻이다.

```text
이미지 생성 API처럼 직접 호출한다
```

가 아니라,

```text
Codex 세션과 turn을 외부에서 제어할 수 있는 백엔드를 띄운다
```

에 가깝다.

### app-server transport 판단

CLI 도움말 기준으로 app-server는 다음 listen 방식을 가진다.

```text
stdio://
unix://
unix://PATH
ws://IP:PORT
off
```

운영 설계에서는 이렇게 잡는 게 맞다.

```text
Mac mini 단일 머신:
  unix:// 우선

로컬 개발:
  stdio:// 또는 unix://

외부 접속이 필요한 실험:
  ws://127.0.0.1:PORT + SSH tunnel

인터넷에 직접 노출:
  금지
```

이유:

- WebSocket transport는 experimental/unsupported 성격이다.
- app-server는 Codex 세션과 파일 시스템 조작 권한을 가진다.
- 외부에 열면 자동화 서버 전체가 공격면이 된다.
- Mac mini 내부에서만 쓰면 위험이 크게 줄어든다.

### 당장 추천하는 순서

처음부터 app-server JSON-RPC를 깊게 물고 들어가면 복잡도가 높다.

그래서 권장 순서는 이렇다.

```text
1단계: cron/launchd + codex exec worker
2단계: job queue + worker 분리
3단계: image prompt router + imagegen worker 안정화
4단계: app-server를 rate limit/read, persistent thread, remote backend로 접목
5단계: UI dashboard 또는 remote control 연결
```

즉, app-server는 1일차 핵심이 아니다.

초기 MVP는 `codex exec`가 더 낫다.

app-server는 자동화가 안정된 뒤에 붙이는 "상시 실행 Codex backend"다.

---

## Mac mini, 켜져 있는 컴퓨터, VPS 중 무엇이 좋은가

### 결론

이 프로젝트는 Mac mini가 가장 편하지만, 필수는 아니다.

정확히는 세 가지 운영 모드가 있다.

```text
1. Mac mini 같은 상시 켜짐 장비
2. 평소에 켜져 있는 개인 컴퓨터
3. VPS 또는 원격 서버
```

처음 정규 트랙에서는 1번과 2번을 우선으로 잡는 게 좋다.

### Mac mini가 좋은 이유

```text
ChatGPT/Codex OAuth 로그인 유지가 쉽다.
로컬 브라우저 인증이 쉽다.
~/.codex/generated_images 접근이 쉽다.
macOS open, Quick Look, Finder 확인이 쉽다.
Notion, Claude Code, Codex CLI를 같은 사용자 계정에 묶기 쉽다.
항상 켜두는 개인 자동화 서버로 쓰기 좋다.
```

특히 이미지 생성 결과를 확인하거나, `codex login`을 갱신하거나, local app-server를 unix socket으로 묶어두는 운영은 Mac mini가 편하다.

Mac mini는 이런 사람에게 맞다.

```text
집이나 사무실에 항상 켜둘 작은 서버를 두고 싶은 사람
블로그 자동화, 파일 자동화, Notion 자동화를 계속 돌리고 싶은 사람
Mac 앱/브라우저/OAuth 인증을 편하게 유지하고 싶은 사람
전력 소모가 낮은 개인 자동화 서버를 원하는 사람
```

### 그냥 켜져 있는 컴퓨터도 가능하다

Mac mini가 없어도 된다.

평소 작업용 MacBook, iMac, Windows 데스크톱, Linux 데스크톱이 켜져 있다면 그것도 자동화 서버처럼 쓸 수 있다.

```text
MacBook:
  전원 연결 + 화면 잠자기 허용 + 시스템 잠자기 방지 필요

iMac/Mac Studio:
  Mac mini와 거의 같은 운영 가능

Windows 데스크톱:
  작업 스케줄러 + WSL 또는 native Codex CLI 구성 필요

Linux 데스크톱:
  cron/systemd timer로 운영 가능
```

장점:

```text
추가 장비가 필요 없다.
지금 쓰는 Codex/Claude/Notion 인증을 그대로 활용할 수 있다.
이미지 확인이 쉽다.
로컬 파일 접근이 쉽다.
```

단점:

```text
컴퓨터가 꺼져 있으면 작업이 안 돈다.
노트북은 절전/잠자기 설정에 영향을 받는다.
작업 중인 개인 환경과 자동화 로그가 섞일 수 있다.
장시간 작업 중 팬/배터리/네트워크 상태를 신경 써야 한다.
```

이 운영 모드는 정규 트랙에서 꼭 다루는 게 좋다.

왜냐하면 수강생 모두가 Mac mini를 갖고 있지는 않지만, 대부분은 "켜져 있는 컴퓨터" 하나는 갖고 있기 때문이다.

추천 메시지:

```text
Mac mini가 있으면 가장 깔끔합니다.
하지만 처음 배울 때는 그냥 지금 쓰는 컴퓨터를 켜두고 시작해도 됩니다.
중요한 건 장비가 아니라 queue, worker, log, retry 구조입니다.
```

### VPS가 나쁜 것은 아니다

VPS도 가능하다.

다만 다음 문제가 있다.

```text
브라우저 OAuth 인증이 번거롭다.
GUI 이미지 확인이 어렵다.
open 명령으로 바로 볼 수 없다.
app-server를 외부 네트워크에 열고 싶어지는 유혹이 생긴다.
보안 설정을 직접 더 많이 해야 한다.
Notion/Claude/Codex 인증 파일 관리가 민감해진다.
```

VPS에서 하려면 최소한 이렇게 해야 한다.

```text
app-server는 127.0.0.1 또는 unix socket에만 바인딩한다.
외부 접속은 SSH tunnel 또는 별도 인증 프록시만 허용한다.
workspace는 사용자별 권한을 분리한다.
토큰 파일은 백업/로그에 남기지 않는다.
자동 발행은 기본 off로 둔다.
```

VPS가 맞는 경우:

```text
24시간 안정성이 가장 중요하다.
GUI 확인이 필요 없다.
API key 기반 fallback까지 포함해 서버형으로 운영할 계획이다.
SSH, systemd, secret 관리에 익숙하다.
```

VPS가 애매한 경우:

```text
ChatGPT OAuth 로그인 유지가 불편하다.
이미지 결과를 바로 보고 고치고 싶다.
처음 실습하는 수강생이다.
app-server 보안 설정에 익숙하지 않다.
```

정규 트랙 순서는 이렇게 가는 게 좋다.

```text
1. 로컬 컴퓨터에서 수동 실행
2. 로컬 컴퓨터를 켜둔 상태로 예약 실행
3. Mac mini 상시 운영
4. VPS/systemd 운영
5. app-server + remote bridge 고급 운영
```

---

## 전체 시스템 그림

### 큰 그림

```text
                              ┌─────────────────────────────┐
                              │        Topic Sources         │
                              │  수동 입력 / CSV / Notion DB │
                              │  트렌드 큐 / 예약 주제       │
                              └──────────────┬──────────────┘
                                             │
                                             ▼
┌────────────────────────────────────────────────────────────────────┐
│                  Mac mini / 켜져 있는 PC / VPS                       │
│                                                                    │
│  ┌────────────────┐     ┌────────────────┐     ┌────────────────┐ │
│  │ Scheduler      │     │ Job Queue      │     │ Orchestrator   │ │
│  │ cron/launchd   │────▶│ SQLite         │────▶│ blog runner    │ │
│  └────────────────┘     └────────────────┘     └───────┬────────┘ │
│                                                         │          │
│                                                         ▼          │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                   Blog Pipeline Workers                       │  │
│  │                                                              │  │
│  │  Researcher -> Fact-Checker -> Planner -> Writer -> Reviewer │  │
│  │                         │                                    │  │
│  │                         ▼                                    │  │
│  │             Image Prompt Router                              │  │
│  │                         │                                    │  │
│  │                         ▼                                    │  │
│  │             Codex Image Workers                              │  │
│  │                         │                                    │  │
│  │                         ▼                                    │  │
│  │             Publisher Adapter                                │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                         │          │
│                                                         ▼          │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                 workspace/{RUN_ID}/                          │  │
│  │  research.md / verified.md / plan.md / draft.md / final.md   │  │
│  │  images/ / image-prompts.json / images.manifest.json         │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                         │          │
└─────────────────────────────────────────────────────────┼──────────┘
                                                          │
                                                          ▼
                                              ┌────────────────────┐
                                              │ Notion Draft DB     │
                                              │ 또는 다른 CMS       │
                                              └────────────────────┘
```

### Codex 관점 그림

```text
Blog Orchestrator
  │
  ├─ codex exec -m spark "섹션별 이미지 프롬프트 만들어줘"
  │      │
  │      └─ image-prompts.json
  │
  ├─ codex exec -m gpt-5.4-mini "built-in image_gen으로 이미지 만들어줘"
  │      │
  │      ├─ ~/.codex/generated_images/<session>/ig_*.png
  │      └─ workspace/{RUN_ID}/images/*.png
  │
  └─ codex app-server
         │
         ├─ thread/start
         ├─ turn/start
         ├─ account/rateLimits/read
         ├─ command/exec
         └─ fs/readFile
```

### app-server를 붙인 최종형

```text
┌──────────────────────────────┐
│ blog automation orchestrator │
└──────────────┬───────────────┘
               │ JSON-RPC
               ▼
┌──────────────────────────────┐
│ codex app-server             │
│ --listen unix://             │
└──────────────┬───────────────┘
               │
               ├─ account/rateLimits/read
               ├─ thread/start
               ├─ turn/start
               ├─ command/exec
               └─ mcpServer/tool/call
               │
               ▼
┌──────────────────────────────┐
│ Codex backend + tools        │
│ image_gen / shell / fs       │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ workspace + generated_images │
└──────────────────────────────┘
```

---

## 워커 설계

이 자동화는 하나의 거대한 프롬프트로 만들면 안 된다.

각 워커가 자기 책임만 가져야 한다.

### 0. Topic Queue Worker

역할:

```text
오늘 처리할 글감 후보를 가져온다.
중복 주제를 제거한다.
우선순위를 정한다.
job_queue.sqlite에 작업을 등록한다.
```

입력:

```text
manual topic
Notion topic DB
CSV
Google Sheet
trend keywords
```

출력:

```json
{
  "job_id": "job_20260525_001",
  "topic": "부산 돼지국밥 맛집 5곳",
  "priority": 50,
  "status": "queued",
  "publish_mode": "draft_only",
  "created_at": "2026-05-25T22:00:00+09:00"
}
```

중요 규칙:

```text
민감 주제는 자동 발행 금지.
가격/영업시간/정책 포함 주제는 Fact-Checker 통과 필수.
이미 같은 제목이 Notion DB에 있으면 skip 또는 update 후보로 보낸다.
```

### 1. Run Initializer

역할:

```text
RUN_ID를 만들고 workspace 디렉토리를 준비한다.
TODAY를 고정한다.
meta.json을 초기화한다.
```

출력:

```text
workspace/{RUN_ID}/meta.json
```

예시:

```json
{
  "run_id": "20260525-223000-busan-pork-soup",
  "topic": "부산 돼지국밥 맛집 5곳",
  "today": "2026-05-25",
  "started_at": "2026-05-25T22:30:00+09:00",
  "publish_mode": "draft_only",
  "stages": {}
}
```

### 2. Research Worker

현재 `blog-researcher`에 해당한다.

역할:

```text
주제에 대한 최신 자료를 검색하고,
사실, 수치, 인용, 경쟁 글을 research.md로 정리한다.
```

모델:

```text
haiku 또는 저비용 검색용 모델
```

출력:

```text
workspace/{RUN_ID}/research.md
```

검증:

```text
파일 존재
핵심 사실 5개 이상
출처 URL 존재
source-date 메타 존재
```

### 3. Fact-Checker Worker

현재 `blog-fact-checker`에 해당한다.

역할:

```text
research.md의 각 주장을 원본 URL로 다시 확인한다.
통과한 사실은 research.verified.md로 보낸다.
탈락한 사실은 research.rejected.md로 보낸다.
```

모델:

```text
sonnet
```

출력:

```text
workspace/{RUN_ID}/research.verified.md
workspace/{RUN_ID}/research.rejected.md
```

중요 규칙:

```text
verified 비율 < 50%면 Planner로 넘기지 않는다.
Researcher를 최대 2회 재시도한다.
그래도 실패하면 사용자 검토 큐로 보낸다.
```

### 4. Planner Worker

현재 `blog-planner`에 해당한다.

역할:

```text
검증된 사실만 보고 글 구조를 설계한다.
독자 문제, 한 줄 결론, 섹션 구조, SEO 키워드, 해시태그를 만든다.
```

모델:

```text
sonnet
```

출력:

```text
workspace/{RUN_ID}/plan.md
```

Spark 활용 가능성:

```text
가능하다.
단, 맛집/여행처럼 사실과 구조가 섞인 글은 sonnet이 안정적이다.
Spark는 제목 후보, SEO 후보, 섹션명 후보처럼 낮은 위험 작업부터 맡기는 게 좋다.
```

### 5. Writer Worker

현재 `blog-writer`에 해당한다.

역할:

```text
plan.md를 따라 draft.md를 쓴다.
research.verified.md에 없는 사실은 쓰지 않는다.
사진 placeholder를 넣는다.
```

모델:

```text
sonnet
```

출력:

```text
workspace/{RUN_ID}/draft.md
```

중요 규칙:

```text
1인칭 경험담에도 측정 가능한 디테일을 임의로 추가하지 않는다.
사진 placeholder는 섹션당 1개 이하.
금지표현 grep을 통과해야 한다.
```

### 6. Reviewer Worker

현재 `blog-reviewer`에 해당한다.

역할:

```text
draft.md를 final.md로 복제한 뒤,
톤, 가독성, 금지표현, 사실관계, 구조를 최종 점검한다.
```

모델:

```text
opus
```

출력:

```text
workspace/{RUN_ID}/final.md
```

중요 규칙:

```text
draft.md는 수정하지 않는다.
research.rejected.md에 있는 표현은 살리지 않는다.
final.md 끝에 reviewer PASS 코멘트를 남긴다.
```

### 7. Image Slot Extractor Worker

새로 추가할 워커다.

역할:

```text
final.md를 읽고 이미지가 들어갈 섹션을 찾는다.
이미지 placeholder가 있으면 추출한다.
placeholder가 없더라도 주요 본문 섹션에는 image slot을 제안한다.
```

출력:

```text
workspace/{RUN_ID}/image-slots.json
```

예시:

```json
{
  "run_id": "20260519-173301-busan-pork-soup",
  "slots": [
    {
      "slot_id": "section-04",
      "section_heading": "🏪 밀양집 — 깡통시장 코스에 붙이기 좋아요",
      "insert_after_heading": true,
      "body_excerpt": "부평동 시장 골목 근처에 있는 집입니다...",
      "placeholder": "📸 [밀양집 외관 또는 리모델링 내부]",
      "recommended_asset_type": "food-action-closeup"
    }
  ]
}
```

중요 규칙:

```text
SEO 키워드 섹션, 해시태그 섹션, 추천 요약 섹션에는 기본적으로 이미지 생성하지 않는다.
본문 핵심 섹션에만 생성한다.
섹션 제목과 본문 사이에 넣을 이미지를 만든다.
```

### 8. Image Prompt Router Worker

이 트랙의 핵심 신규 워커다.

역할:

```text
섹션 제목, 본문, placeholder, research.verified.md를 읽고
이미지 생성용 프롬프트로 라우팅한다.
```

권장 모델:

```text
gpt-5.3 codex spark 또는 기타 저비용 Codex 모델
```

주의:

현재 로컬 config에는 다음 매핑이 있었다.

```toml
"gpt-5.3-codex" = "gpt-5.4"
```

따라서 실제 Spark 모델 id를 확인해야 한다.

입력:

```text
final.md
image-slots.json
research.verified.md
style/image rules
```

출력:

```text
workspace/{RUN_ID}/image-prompts.json
```

예시:

```json
{
  "run_id": "20260519-173301-busan-pork-soup",
  "prompts": [
    {
      "slot_id": "section-04",
      "section_heading": "🏪 밀양집 — 깡통시장 코스에 붙이기 좋아요",
      "filename": "section-04-milyang-soup.png",
      "insert_after_heading": true,
      "use_case": "photorealistic-natural",
      "prompt": "Realistic editorial Korean food blog close-up: a hand holding a metal spoon lifting one rich spoonful from Busan pork gukbap, with sliced pork, a little rice, broth, and a hint of sundae/mixed ingredients visible in the spoon. The black ttukbaegi bowl and kimchi/chive side dishes are softly blurred behind it on a clean modest restaurant table. Market-course casual mood, warm practical lighting, appetizing but restrained, shallow depth of field, no face, no readable text, no logos, no watermark, no exact restaurant reproduction. Landscape orientation.",
      "negative_constraints": [
        "No readable text",
        "No logos",
        "No watermark",
        "No exact storefront reproduction",
        "No faces",
        "No menu board text",
        "No unverified prices",
        "No fake restaurant signage"
      ]
    }
  ]
}
```

라우팅 원칙:

```text
글의 사실을 이미지가 새로 만들면 안 된다.
검증되지 않은 간판, 주소, 가격, 메뉴판 텍스트를 넣지 않는다.
이미지 안에 한글 텍스트를 넣으려 하지 않는다.
상호를 재현하지 않는다.
음식/행동/분위기 중심으로 만든다.
맛집 글은 정적인 상차림보다 먹는 순간의 클로즈업을 우선한다.
filename은 반드시 workspace에서 쓸 `.png` 파일명으로 만든다.
```

음식 블로그 프롬프트 우선순위:

```text
1. 숟가락으로 국밥을 떠올리는 장면
2. 젓가락으로 수육을 집는 장면
3. 김치/부추를 곁들이는 장면
4. 국물 김이 올라오는 클로즈업
5. 테이블 전체샷은 보조
```

### 9. Codex Image Generator Worker

역할:

```text
image-prompts.json을 읽고
Codex built-in image_gen으로 이미지를 생성한다.
생성 결과를 workspace/{RUN_ID}/images/ 아래로 복사한다.
```

실행 형태:

```bash
codex exec --ephemeral \
  -C /path/to/blog-posting-auto \
  -s workspace-write \
  --skip-git-repo-check \
  -m gpt-5.4-mini \
  -o workspace/$RUN_ID/imagegen-test/imagegen-section-04.codex.md \
  'Use the built-in image_gen tool...'
```

중요:

```text
Codex worker 안에서 image_gen을 사용한다.
생성물은 ~/.codex/generated_images 아래에 생긴다.
그 파일을 workspace/{RUN_ID}/images로 복사한다.
final.md는 수정하지 않는다.
manifest는 별도 단계에서 갱신한다.
```

출력:

```text
workspace/{RUN_ID}/images/section-04-milyang-soup.png
workspace/{RUN_ID}/imagegen-test/imagegen-section-04.codex.md
```

검증:

```bash
file workspace/$RUN_ID/images/section-04-milyang-soup.png
python3 -m json.tool workspace/$RUN_ID/images.manifest.json
```

### 10. Image QA Worker

새로 추가할 수 있는 검수 워커다.

역할:

```text
생성된 이미지를 보고 섹션 의도와 맞는지 평가한다.
문제 있으면 재생성 사유를 남긴다.
```

검수 기준:

```text
섹션 주제와 맞는가
음식이 한국 돼지국밥처럼 보이는가
텍스트/로고/워터마크가 없는가
얼굴이 나오지 않는가
상호/실제 매장을 재현하지 않았는가
너무 고급 레스토랑처럼 보이지 않는가
먹는 장면/클로즈업 요구를 반영했는가
```

출력:

```text
workspace/{RUN_ID}/image-qa.json
```

예시:

```json
{
  "section-04": {
    "status": "pass",
    "notes": "Spoon close-up matches the food-action requirement. No readable text or faces."
  },
  "section-05": {
    "status": "retry",
    "reason": "Looks like a generic table setting, not a late-night spoon close-up."
  }
}
```

### 11. Manifest Writer Worker

역할:

```text
생성된 이미지 파일과 프롬프트를 images.manifest.json에 등록한다.
```

출력:

```text
workspace/{RUN_ID}/images.manifest.json
```

예시:

```json
{
  "run_id": "20260519-173301-busan-pork-soup",
  "images": [
    {
      "file_path": "workspace/20260519-173301-busan-pork-soup/images/section-04-milyang-soup.png",
      "section_heading": "🏪 밀양집 — 깡통시장 코스에 붙이기 좋아요",
      "insertion_rule": "Insert between the section heading and the first body paragraph. Do not edit final.md automatically.",
      "prompt": "Realistic editorial Korean food blog close-up...",
      "status": "generated",
      "qa_status": "pass"
    }
  ]
}
```

### 12. Notion Payload Builder Worker

역할:

```text
final.md와 images.manifest.json을 읽고
Notion에 넣을 블록 구조를 만든다.
```

중요한 설계 포인트:

```text
이미지는 섹션 제목과 본문 사이에 들어간다.
final.md를 직접 수정하지 않아도 된다.
Publisher가 Notion block을 만들 때 이미지 블록을 끼워 넣으면 된다.
```

즉, 두 가지 방식이 있다.

방식 A:

```text
final.md에 이미지 markdown을 삽입한다.
```

장점:

```text
결과물이 눈에 잘 보인다.
정적 파일로 관리하기 쉽다.
```

단점:

```text
final.md 원본이 바뀐다.
이미지 URL 업로드 방식에 따라 다시 수정해야 할 수 있다.
```

방식 B:

```text
final.md는 그대로 두고,
Publisher가 manifest를 참고해 Notion block에 이미지를 끼운다.
```

장점:

```text
final.md를 깨끗하게 유지한다.
이미지 삽입 정책을 Publisher에서 통제할 수 있다.
```

단점:

```text
미리보기 구현이 조금 더 필요하다.
```

추천:

```text
MVP는 final.with-images.md를 별도 생성한다.
원본 final.md는 보존한다.
Publisher는 final.with-images.md 또는 manifest 기반 payload를 사용한다.
```

### 13. Publisher Worker

현재 `blog-publisher`를 확장한다.

역할:

```text
final.md 또는 final.with-images.md를 Notion Draft DB에 발행한다.
```

운영 모드:

```text
draft_only:
  Notion Draft까지만 자동 생성

approval_required:
  발행 직전 사용자에게 승인 요청

auto_publish:
  낮은 위험 주제에서만 허용
```

기본값:

```text
draft_only
```

왜냐하면 이 repo의 기존 핵심 규칙이 있다.

```text
Publisher는 명시적 사용자 승인 후에만 실행한다.
```

자동화 서버에서도 이 원칙은 유지하는 게 안전하다.

현실적 운영:

```text
밤새 자동 생성
  -> Notion Draft DB에 쌓임
  -> 아침에 사람이 확인
  -> 승인한 글만 Publish
```

---

## 워커별 모델 배치

### 기본 배치

| 단계 | 워커 | 권장 모델 | 이유 |
|---|---|---|---|
| 0 | Topic Queue | Spark/mini | 정형 작업 |
| 1 | Researcher | haiku | 검색/수집 비용 절감 |
| 1.5 | Fact-Checker | sonnet | 원문 매치와 판단 필요 |
| 2 | Planner | sonnet | 구조 설계 품질 필요 |
| 3 | Writer | sonnet | 한국어 본문 품질 필요 |
| 4 | Reviewer | opus | 최종 게이트 |
| 4.5 | Image Slot Extractor | Spark | 섹션 추출 정형 작업 |
| 4.6 | Image Prompt Router | Spark 또는 mini | 프롬프트 변환 |
| 4.7 | Codex Image Generator | Codex image_gen 가능 모델 | built-in image_gen 호출 |
| 4.8 | Image QA | mini 또는 시각 판단 가능 모델 | 이미지 적합성 확인 |
| 5 | Publisher | haiku | Notion MCP 정형 호출 |

### Spark를 어디에 쓸 것인가

사용자가 말한 "5.3 Codex Spark가 놀고 있다"는 아이디어는 좋다.

다만 Spark를 모든 곳에 쓰면 안 된다. 그리고 먼저 실제 계정에서 해당 모델이 실행되는지 확인해야 한다.

### Spark 사용 여부 확인

로컬 확인 기준:

```text
codex-cli 0.133.0
image_generation stable true
fast_mode stable true
multi_agent stable true
```

현재 로컬 config에는 이 매핑이 있다.

```toml
"gpt-5.3-codex" = "gpt-5.4"
```

따라서 `gpt-5.3-codex`라고 부르면 실제로는 `gpt-5.4`로 넘어갈 수 있다.

반면 Spark 모델은 별도 id로 테스트해야 한다.

실제 smoke test 명령:

```bash
codex exec --ephemeral \
  -C /Users/parkeungje/project/blog-posting-auto \
  --skip-git-repo-check \
  -m gpt-5.3-codex-spark \
  -s read-only \
  'Return exactly: SPARK_OK'
```

확인 결과:

```text
SPARK_OK
```

즉, 현재 이 로컬 환경에서는 `gpt-5.3-codex-spark`가 최소한 `codex exec`에서 실행된다.

하지만 문서와 강의에서는 이렇게 안내해야 한다.

```text
Spark는 research preview 성격이므로 계정/플랜/시점에 따라 사용 가능 여부가 달라질 수 있다.
강의 시작 전 반드시 자기 환경에서 smoke test를 먼저 돌린다.
실패하면 Spark 자리는 gpt-5.4-mini 또는 현재 사용 가능한 저비용 모델로 대체한다.
```

공식 rate card에서도 `GPT-5.3-Codex-Spark`는 research preview로 표시되고, credit rate가 final이 아니라고 되어 있다. 따라서 장기 운영 비용 계산을 Spark에 고정하면 안 된다.

### Spark에 맡길 작업

적합한 작업:

```text
섹션 추출
이미지 slot 제안
이미지 프롬프트 초안
파일명 생성
manifest 작성
SEO 키워드 후보
해시태그 후보
제목 후보 10개 만들기
job 상태 요약
실패 로그 요약
```

조심해야 하는 작업:

```text
가격/영업시간 검증
출처 날짜 판단
본문 최종 작성
Reviewer 최종 사실 게이트
Notion 실제 발행
```

Spark 활용 원칙:

```text
낮은 위험, 반복적, 구조화된 작업부터 맡긴다.
발행 품질과 사실 책임이 큰 단계는 상위 모델이 맡는다.
Spark 실패 시 같은 입력을 mini 또는 gpt-5.4로 fallback할 수 있게 만든다.
```

---

## 워크플로우 로직을 상태 머신으로 보기

정규 트랙에서는 "프롬프트를 잘 쓴다"보다 "상태 전이를 잘 설계한다"가 중요하다.

블로그 자동화 서버의 핵심 상태는 다음과 같다.

```text
queued
  -> initializing
  -> researching
  -> fact_checking
  -> planning
  -> writing
  -> reviewing
  -> routing_images
  -> generating_images
  -> qa_images
  -> building_payload
  -> publishing_draft
  -> done
```

실패 상태는 별도로 둔다.

```text
research_failed
factcheck_failed
writing_failed
review_failed
image_failed
publish_failed
needs_human_review
cancelled
```

상태 전이 규칙:

```text
Researcher 실패:
  네트워크/검색 실패면 retry
  자료 부족이면 needs_human_review

Fact-Checker 실패:
  verified ratio < 50%면 Researcher 최대 2회 재실행
  그래도 실패하면 needs_human_review

Writer 실패:
  금지표현/검증 실패면 Writer 재실행
  2회 실패하면 needs_human_review

Reviewer 실패:
  draft 수정이 아니라 Writer 재호출
  rejected 사실이 살아 있으면 강제 중단

Image Generator 실패:
  해당 section만 1회 retry
  계속 실패하면 이미지 없이 Draft 생성하거나 needs_human_review

Publisher 실패:
  Notion API 일시 실패면 retry
  DB schema 문제면 needs_human_review
```

이렇게 상태를 분리해야 아침에 확인했을 때 알 수 있다.

```text
작업이 안 돈 건지
자료가 부족한 건지
이미지만 실패한 건지
Notion 발행만 실패한 건지
Codex usage limit에 걸린 건지
```

정규 트랙에서 보여줄 핵심 로직은 이 흐름이다.

```text
while true:
  job = pick_next_job()
  if no job:
    exit

  lock(job)
  initialize_run(job)

  run_stage("researcher")
  verify_stage_output("research.md")

  run_stage("fact_checker")
  if verified_ratio < 0.5:
    retry_research_or_mark_review()

  run_stage("planner")
  run_stage("writer")
  run_stage("reviewer")

  run_stage("image_slot_extractor")
  run_stage("image_prompt_router", model="gpt-5.3-codex-spark")

  for prompt in image_prompts:
    enqueue_image_job(prompt)

  run_image_workers(max_parallel=2)
  run_image_qa()
  build_manifest()

  build_notion_payload()
  publish_draft()

  mark_done(job)
```

이 로직이 있어야 `codex exec`든 `app-server`든 교체 가능하다.

중요한 메시지:

```text
자동화의 본체는 모델이 아니라 workflow state machine이다.
모델은 각 상태에서 호출되는 worker일 뿐이다.
```

---

## 테스트 전략: 가볍게 확인하고 흔적 지우기

정규 트랙에서는 테스트를 단계별로 나눠야 한다.

처음부터 전체 블로그 생성, 이미지 생성, Notion 발행까지 한 번에 테스트하면 실패 지점을 알기 어렵다.

### YouTube용 smoke test

유튜브에서는 이것만 보여준다.

```text
Spark가 이미지 프롬프트 라우터 역할을 할 수 있는가?
```

테스트 범위:

```text
입력:
  final.md의 섹션 제목과 본문 일부

실행:
  codex exec -m gpt-5.3-codex-spark

출력:
  /tmp/blog_spark_router_smoke.json

검증:
  JSON parse 성공
  필수 key 존재

정리:
  /tmp 테스트 파일 삭제
```

이 smoke test는 실제 이미지를 만들지 않는다.

이유:

```text
유튜브에서는 구조를 보여주는 게 목적이다.
이미지 생성은 usage를 더 쓴다.
Spark의 역할은 이미지 생성이 아니라 프롬프트 라우팅이다.
정규 트랙에서 image_gen worker까지 이어 붙인다.
```

권장 명령:

```bash
OUT=/tmp/blog_spark_router_smoke.json
rm -f "$OUT"

codex exec --ephemeral \
  -C /Users/parkeungje/project/blog-posting-auto \
  --skip-git-repo-check \
  -m gpt-5.3-codex-spark \
  -s read-only \
  -o "$OUT" \
  'Read this section context and return only valid JSON for one image prompt. Required keys: section_heading, filename, prompt, negative_constraints, insertion_rule. Section: "🏪 밀양집 — 깡통시장 코스에 붙이기 좋아요". Body: "부평동 시장 골목 근처에 있는 집입니다. 백년가게로 선정됐고, 유튜브 채널 풍자 또간집에도 소개됐어요. 최근 리모델링을 해서 내부가 깔끔해졌습니다. 섞어국밥은 순대·내장·고기가 한 번에 들어간 조합입니다." Visual direction: food action close-up, spoon lifting gukbap, no readable text, no logo, no face.'

python3 -m json.tool "$OUT" >/dev/null
rm -f "$OUT"
test ! -e "$OUT" && echo "cleaned"
```

성공 기준:

```text
codex exec가 성공한다.
JSON parse가 성공한다.
prompt에 action close-up 방향이 들어간다.
negative_constraints에 no readable text, no logos, no faces가 들어간다.
filename은 workspace에서 쓸 PNG 파일명 규칙을 따른다.
테스트 파일이 삭제된다.
```

실제 smoke test에서 확인한 점:

```text
Spark는 필수 key가 있는 JSON을 정상 생성했다.
프롬프트에는 spoon/action close-up 방향이 들어갔다.
negative_constraints도 6개 생성됐다.
/tmp 테스트 파일 삭제도 성공했다.
```

보완해야 할 점:

```text
Spark가 filename을 .jpg로 제안할 수 있다.
프로젝트 이미지 산출물은 PNG로 통일한다.
따라서 Image Prompt Router 규칙에 "filename must end with .png"를 명시한다.
Manifest Writer도 .jpg/.jpeg/.webp를 받으면 .png 규칙 위반으로 reject한다.
```

### End-to-end smoke test 결과

Spark가 만든 프롬프트를 실제 `image_gen` worker에 넘기는 테스트도 수행했다.

테스트 흐름:

```text
Spark worker
  -> /tmp/spark_imagegen_prompt.json 생성
  -> JSON parse
  -> prompt 추출
  -> Codex image_gen worker 호출
  -> /tmp/spark_imagegen_smoke.png 생성
  -> PNG 해상도 확인
  -> /tmp 파일 삭제
  -> 새 ~/.codex/generated_images 테스트 디렉터리 삭제
```

확인 결과:

```text
Spark prompt JSON 생성: 성공
filename .png 규칙: 성공
Codex built-in image_gen 호출: 성공
생성 이미지: PNG
해상도: 1536 x 1024
cleanup: ok
```

이 테스트로 확인한 것은 "Spark가 실제 이미지 생성 도구를 직접 호출한다"가 아니다.

정확한 구조는 다음과 같다.

```text
Spark:
  이미지 프롬프트 JSON 생성

Codex image_gen worker:
  Spark가 만든 prompt를 받아 실제 이미지 생성
```

실패 시 fallback:

```text
Spark 모델 호출 실패:
  gpt-5.4-mini 또는 현재 사용 가능한 저비용 모델로 대체

JSON parse 실패:
  프롬프트에 "Return only valid JSON. No markdown."를 더 강하게 명시

프롬프트 품질 낮음:
  Image Prompt Router 규칙을 더 구체화
```

### 정규 트랙 테스트 단계

정규 트랙에서는 테스트를 아래 순서로 확장한다.

```text
1. Spark 모델 smoke test
2. Spark image prompt JSON test
3. image_prompts.json schema test
4. Codex image_gen 단일 이미지 생성 test
5. images.manifest.json test
6. final.with-images.md 생성 test
7. Notion Draft dry-run payload test
8. 실제 Notion Draft 발행 test
9. cron/launchd 예약 실행 test
10. 실패 재시도 test
```

각 테스트는 원칙적으로 자기 산출물을 지운다.

예외:

```text
정규 트랙 데모 산출물로 보여줄 샘플 workspace만 남긴다.
그 외 smoke test 파일은 /tmp에 만들고 삭제한다.
```

---

## 자동화 실행 흐름

### MVP 흐름

```text
cron 또는 launchd
  -> run_daily_blog.sh
  -> topic queue에서 1개 주제 가져오기
  -> /blog-pipeline headless 실행
  -> final.md 생성
  -> codex exec로 Image Prompt Router 실행
  -> codex exec로 Image Generator 병렬 실행
  -> images.manifest.json 생성
  -> final.with-images.md 생성
  -> Notion Draft 생성
  -> meta.json 업데이트
```

### 세부 흐름

```text
[1] Scheduler fires
    |
    v
[2] Pick queued topic
    |
    v
[3] Create RUN_ID
    |
    v
[4] Researcher
    |
    v
[5] Fact-Checker
    |
    +-- verified ratio < 50% -> Research retry
    |
    v
[6] Planner
    |
    v
[7] Writer
    |
    v
[8] Reviewer
    |
    v
[9] Image Slot Extractor
    |
    v
[10] Image Prompt Router
    |
    v
[11] Image Generator pool
    |
    +-- section-02 image
    +-- section-03 image
    +-- section-04 image
    |
    v
[12] Image QA
    |
    +-- fail -> retry once
    |
    v
[13] Manifest Writer
    |
    v
[14] Notion Payload Builder
    |
    v
[15] Publisher
    |
    v
[16] Job complete
```

### 병렬화 구조

이미지 생성은 섹션별로 독립적이다.

따라서 병렬화가 가능하다.

```text
Image Prompt Router
  -> image-prompts.json
       ├─ section-02 prompt -> Codex image worker A
       ├─ section-03 prompt -> Codex image worker B
       ├─ section-04 prompt -> Codex image worker C
       └─ section-05 prompt -> Codex image worker D
```

하지만 무제한 병렬은 좋지 않다.

권장 제한:

```json
{
  "max_parallel_image_workers": 2,
  "max_images_per_post": 5,
  "max_image_retry": 1,
  "daily_image_budget": 20
}
```

이유:

```text
Codex usage/rate limit을 빨리 소모할 수 있다.
이미지 생성 품질 확인 없이 너무 많이 만들 수 있다.
실패했을 때 어떤 worker가 어떤 파일을 덮었는지 추적이 어려워진다.
```

---

## app-server를 접목하는 방식

### 방식 1: 당장 안정적인 codex exec worker

초기 구현은 이 방식이 가장 좋다.

```text
orchestrator
  -> shell command
  -> codex exec --ephemeral ...
  -> output files
```

장점:

```text
구현이 단순하다.
지금 이미 실험으로 검증했다.
생성 파일 경로를 확인할 수 있다.
worker마다 독립 실행이 쉽다.
로그를 파일로 남기기 쉽다.
```

단점:

```text
매번 새 Codex 프로세스가 뜬다.
persistent thread 관리가 약하다.
rate limit 상태를 세밀하게 읽기 어렵다.
장기 실행 세션 제어는 app-server보다 약하다.
```

### 방식 2: app-server를 상시 백엔드로 사용

중장기 구조다.

```text
codex app-server --listen unix://
```

orchestrator는 JSON-RPC로 요청한다.

```text
initialize
thread/start
turn/start
stream notifications
turn/completed
```

장점:

```text
Codex 세션을 더 정교하게 제어할 수 있다.
rich client처럼 thread/turn/event를 추적할 수 있다.
account/rateLimits/read 같은 endpoint를 활용할 수 있다.
command/exec, fs/readFile 같은 기능도 있다.
나중에 dashboard를 만들기 좋다.
```

단점:

```text
프로토콜 구현이 필요하다.
WebSocket transport는 experimental 성격이다.
auth/token 문제가 생길 수 있다.
에러 처리가 codex exec보다 복잡하다.
```

### 추천 하이브리드

처음부터 둘 중 하나만 고집하지 않는다.

```text
MVP:
  codex exec로 worker 실행

운영 안정화 후:
  app-server는 rate limit/read, thread 상태, dashboard용으로 붙임

최종형:
  app-server 기반 turn/start로 Codex worker를 직접 제어
```

---

## 파일과 데이터 계약

AI 자동화가 안정되려면 "파일 계약"이 중요하다.

각 worker는 자기 파일만 써야 한다.

### 권장 workspace 구조

```text
workspace/{RUN_ID}/
├── meta.json
├── job.json
├── research.md
├── research.verified.md
├── research.rejected.md
├── plan.md
├── draft.md
├── final.md
├── final.with-images.md
├── image-slots.json
├── image-prompts.json
├── image-qa.json
├── images.manifest.json
├── notion-payload.json
├── images/
│   ├── section-02-bonjeon-soup.png
│   ├── section-03-halmae-soup.png
│   └── section-04-milyang-soup.png
└── logs/
    ├── researcher.log
    ├── fact-checker.log
    ├── imagegen-section-02.codex.md
    └── publisher.log
```

### meta.json

```json
{
  "run_id": "20260525-223000-busan-pork-soup",
  "topic": "부산 돼지국밥 맛집 5곳",
  "today": "2026-05-25",
  "status": "image_generated",
  "publish_mode": "draft_only",
  "stages": {
    "researcher": {
      "status": "pass",
      "started_at": "2026-05-25T22:30:01+09:00",
      "finished_at": "2026-05-25T22:32:10+09:00"
    },
    "fact_checker": {
      "status": "pass",
      "verified": 18,
      "rejected": 3,
      "ratio": 0.857
    },
    "image_generator": {
      "status": "pass",
      "images": 5,
      "failed": 0
    }
  }
}
```

### job_queue.sqlite

최소 테이블:

```sql
CREATE TABLE jobs (
  id TEXT PRIMARY KEY,
  topic TEXT NOT NULL,
  status TEXT NOT NULL,
  priority INTEGER NOT NULL DEFAULT 50,
  run_id TEXT,
  publish_mode TEXT NOT NULL DEFAULT 'draft_only',
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE job_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  message TEXT,
  payload_json TEXT,
  created_at TEXT NOT NULL
);
```

상태:

```text
queued
running
research_failed
factcheck_failed
writing_failed
review_failed
image_failed
draft_published
needs_human_review
done
cancelled
```

---

## 이미지 생성 정책

### 이미지 위치

이미지는 섹션 끝이 아니라 제목과 본문 사이에 들어간다.

```markdown
# 🏪 밀양집 — 깡통시장 코스에 붙이기 좋아요

![밀양집 섹션 이미지](images/section-04-milyang-soup.png)

부평동 시장 골목 근처에 있는 집입니다...
```

이 위치 규칙 때문에 프롬프트는 "섹션을 여는 장면"이어야 한다.

### 음식 블로그 이미지 기본값

기본값은 전체 상차림이 아니다.

```text
먹는 순간
한 숟갈 클로즈업
젓가락으로 집는 장면
국물이 올라오는 장면
손만 보이는 행동 컷
```

### 금지할 것

```text
읽을 수 있는 한글 텍스트
실제 상호 간판 재현
메뉴판 가격
브랜드 로고
워터마크
사람 얼굴
특정 식당 내부의 정확한 재현
검증되지 않은 메뉴
```

### 권장 프롬프트 패턴

```text
Realistic editorial Korean food blog close-up:
<행동 장면>.
The <main food> is in focus, with <context items> softly blurred behind it.
Warm practical restaurant lighting.
Appetizing but restrained.
Shallow depth of field.
No face, no readable text, no logos, no watermark, no exact restaurant reproduction.
Landscape orientation.
```

### 예시: 국밥 한 숟갈

```text
Realistic editorial Korean food blog close-up: a hand holding a metal spoon lifting one rich spoonful from Busan pork gukbap, with sliced pork, a little rice, broth, and scallion visible in the spoon. The black ttukbaegi bowl and kimchi/chive side dishes are softly blurred behind it on a clean modest restaurant table. Warm practical lighting, appetizing but restrained, shallow depth of field, no face, no readable text, no logos, no watermark, no exact restaurant reproduction. Landscape orientation.
```

---

## 발행 정책

### 기본은 Draft

자동화 서버가 밤새 글을 만들더라도 기본은 Draft다.

```text
자동 생성
  -> Notion Draft
  -> 아침에 사람이 검토
  -> 승인 후 Publish
```

### 왜 완전 자동 발행을 바로 하면 안 되는가

이 프로젝트는 맛집, 가격, 영업시간, 장소, 정책 같은 time-sensitive 정보를 다룰 수 있다.

이런 정보는 틀리면 신뢰도 문제가 생긴다.

그래서 운영 정책을 나눠야 한다.

```text
낮은 위험:
  evergreen 튜토리얼, 개인 노트 정리, 내부 문서
  -> 자동 Draft 또는 조건부 자동 발행 가능

중간 위험:
  맛집, 여행, 가격, 운영시간
  -> Draft까지만 자동

높은 위험:
  의료, 법률, 금융, 정치, 안전
  -> 자동 발행 금지
```

### Publisher 승인 게이트

기존 repo 규칙:

```text
Publisher는 명시적 사용자 승인 후에만 실행한다.
```

자동화 서버에서는 이것을 이렇게 바꿔 적용할 수 있다.

```text
Draft 생성은 자동 허용
Public publish는 명시 승인 필요
```

---

## 운영 스케줄

### Mac mini launchd 예시

```text
~/Library/LaunchAgents/com.fronmpt.blog-pipeline.plist
```

개념:

```text
매일 06:00 실행
네트워크가 없으면 실패 기록
Codex login 상태 확인
job queue에서 주제 하나 가져오기
완료 후 Notion Draft 생성
```

### cron 예시

```bash
0 6 * * * cd /Users/parkeungje/project/blog-posting-auto && ./automation/run_daily_blog.sh >> logs/cron.log 2>&1
```

### systemd timer 예시

VPS에서는 systemd timer가 더 낫다.

```text
blog-pipeline.service
blog-pipeline.timer
```

서비스는 app-server와 분리한다.

```text
codex-app-server.service
blog-pipeline-worker.service
```

---

## 인증과 보안

### 인증 파일

민감한 것:

```text
~/.codex/auth.json
~/.codex/config.toml
.env
Notion tokens
Claude/Notion MCP credentials
```

규칙:

```text
git에 절대 포함하지 않는다.
백업 로그에 남기지 않는다.
CI 로그에 출력하지 않는다.
app-server를 인터넷에 직접 열지 않는다.
```

### app-server 바인딩

권장:

```bash
codex app-server --listen unix://
```

또는:

```bash
codex app-server --listen ws://127.0.0.1:9234
```

비권장:

```bash
codex app-server --listen ws://0.0.0.0:9234
```

외부 접속이 필요하면:

```text
SSH tunnel
Tailscale
Cloudflare Tunnel + 별도 인증
```

단, 첫 버전에서는 외부 접속 자체를 빼는 게 좋다.

---

## 실패 처리

### 실패 원칙

```text
실패한 단계 이후로 진행하지 않는다.
단계별 실패 사유를 meta.json과 job_events에 남긴다.
재시도 가능한 실패와 사람 확인이 필요한 실패를 구분한다.
```

### 재시도 가능

```text
일시적 네트워크 실패
WebFetch timeout
Codex rate limit temporary error
이미지 생성 실패
Notion API 일시 실패
```

### 재시도하면 안 되는 것

```text
Fact-Checker verified 비율이 낮음
출처가 부족함
글 주제가 너무 모호함
Notion DB 스키마가 깨짐
금지 주제 정책에 걸림
```

### 이미지 재시도

이미지는 최대 1회만 자동 재시도한다.

재시도 프롬프트는 구체적으로 바꾼다.

```text
Before:
  table setting with pork gukbap

After:
  close-up of spoon lifting pork gukbap, hand only, no face
```

---

## 관측성과 로그

자동화 서버는 "돌아갔는지"보다 "어디서 왜 멈췄는지"가 중요하다.

### 반드시 남길 로그

```text
job_id
run_id
topic
stage
model
start time
finish time
status
error message
output path
generated image count
fact-check ratio
notion page url
```

### 대시보드에서 보고 싶은 것

```text
오늘 생성한 글 수
오늘 생성한 이미지 수
실패한 job
사람 검토가 필요한 job
Codex usage/rate limit 상태
Notion Draft URL
최근 이미지 미리보기
```

---

## Fronmpt Academy 세션 구성

### 세션 1: 문제 정의와 현재 blog-pipeline 이해

목표:

```text
블로그 자동화가 단순 글쓰기 프롬프트가 아니라,
검증 가능한 파이프라인이어야 하는 이유를 이해한다.
```

보여줄 것:

```text
.claude/skills/blog-pipeline/SKILL.md
.claude/agents/
workspace/{RUN_ID}/
research.verified.md
research.rejected.md
```

핵심 메시지:

```text
자동화의 품질은 Writer가 아니라 Fact-Checker에서 결정된다.
```

### 세션 2: Claude Code가 Codex를 worker로 부르는 구조

목표:

```text
Claude Code와 Codex의 역할을 분리한다.
```

보여줄 것:

```bash
codex login status
codex features list
codex exec --help
```

핵심 메시지:

```text
Claude Code는 감독이고 Codex는 작업자다.
```

### 세션 3: image_gen과 섹션 이미지 자동화

목표:

```text
final.md의 섹션을 읽고 이미지를 생성하는 워크플로우를 만든다.
```

보여줄 것:

```text
image-slots.json
image-prompts.json
~/.codex/generated_images
workspace/{RUN_ID}/images
images.manifest.json
```

핵심 메시지:

```text
이미지는 섹션 제목과 본문 사이에 들어가는 시각 앵커다.
```

### 세션 4: Mac mini 자동화 서버 만들기

목표:

```text
수동 실행을 스케줄러 기반 자동 실행으로 바꾼다.
```

보여줄 것:

```text
cron
launchd
job_queue.sqlite
logs/
meta.json
```

핵심 메시지:

```text
AI 자동화도 결국 queue, worker, log, retry 구조로 운영해야 한다.
```

### 세션 5: Codex app-server 확장

목표:

```text
codex exec worker 구조에서 app-server backend 구조로 확장하는 방향을 이해한다.
```

보여줄 것:

```bash
codex app-server --help
codex app-server --listen unix://
codex app-server generate-json-schema
```

핵심 메시지:

```text
app-server는 이미지 API가 아니라 Codex 세션 제어 서버다.
```

### 세션 6: Notion Draft 발행과 운영 정책

목표:

```text
완전 자동 발행이 아니라 Draft 자동화와 승인 게이트를 설계한다.
```

보여줄 것:

```text
Notion DB
Draft page
Publisher approval rule
publish_mode
```

핵심 메시지:

```text
자동 생성과 자동 공개 발행은 다르다.
```

---

## 구현 로드맵

### Phase 0: 현재 상태 정리

완료된 것:

```text
기존 6단계 blog-pipeline 존재
Codex built-in image_gen 경로 확인
OPENAI_API_KEY 없이 이미지 생성 가능 확인
이미지 5장 생성 테스트
manifest 샘플 작성
이미지 방향성 피드백 반영
```

### Phase 1: 이미지 단계 정식 추가

할 일:

```text
Image Slot Extractor 추가
Image Prompt Router 추가
Codex Image Generator 추가
images.manifest.json 스키마 확정
final.with-images.md 생성기 추가
```

성공 조건:

```text
/blog-pipeline 실행 후 final.md와 images/가 같이 생긴다.
이미지는 섹션 제목과 본문 사이에 삽입 가능한 상태다.
```

### Phase 2: 자동 실행 MVP

할 일:

```text
automation/run_daily_blog.sh 작성
job_queue.sqlite 생성
topic queue worker 작성
cron 또는 launchd 등록
logs/ 생성
```

성공 조건:

```text
아침마다 Notion Draft DB에 새 글 초안이 하나 생긴다.
실패하면 job_queue에 이유가 남는다.
```

### Phase 3: Spark worker 활용

할 일:

```text
실제 Spark 모델 id 확인
Prompt Router를 Spark로 실행
SEO/해시태그 후보 생성을 Spark로 분리
이미지 QA 요약을 Spark로 분리
```

성공 조건:

```text
상위 모델 사용량을 줄이면서 품질 저하가 크지 않다.
```

### Phase 4: app-server 접목

할 일:

```text
codex app-server --listen unix:// 실행
JSON-RPC bridge 작성
initialize/thread/start/turn/start 최소 구현
account/rateLimits/read 연결
command/exec 연결
```

성공 조건:

```text
orchestrator가 app-server를 통해 Codex turn을 시작하고 완료 상태를 읽을 수 있다.
```

### Phase 5: 운영 대시보드

할 일:

```text
job 상태 UI
Notion Draft 링크
이미지 미리보기
실패 재시도 버튼
publish 승인 버튼
usage/rate limit 표시
```

성공 조건:

```text
Mac mini에서 밤새 돌아간 작업을 아침에 한 화면에서 확인할 수 있다.
```

---

## 촬영용 데모 플로우

### 데모 1: 지금 프로젝트 구조 보여주기

화면:

```text
README.md
.claude/agents/
.claude/skills/blog-pipeline/SKILL.md
workspace/{RUN_ID}/
```

말할 내용:

```text
이 프로젝트는 그냥 글을 쓰는 게 아니라,
Researcher와 Fact-Checker를 분리해서 검증된 사실만 Writer로 넘기는 구조입니다.
```

### 데모 2: 이미지 생성 경로 보여주기

명령:

```bash
codex login status
codex features list
ls ~/.codex/generated_images
```

말할 내용:

```text
여기서 중요한 건 OpenAI API key를 넘긴 게 아니라는 점입니다.
Codex가 로그인된 상태에서 자기 built-in image_gen을 호출합니다.
```

### 데모 3: 섹션을 읽고 이미지 프롬프트 만들기

보여줄 파일:

```text
final.md
image-prompts.json
```

말할 내용:

```text
이미지 프롬프트는 placeholder만 보고 만들면 안 됩니다.
섹션 제목, 본문 첫 문단, verified facts를 같이 봐야 합니다.
```

### 데모 4: 먹는 장면으로 재생성한 차이 보여주기

비교:

```text
상차림 전체샷
vs
숟가락 클로즈업
```

말할 내용:

```text
블로그 이미지는 정보 전달보다 스크롤을 멈추게 하는 역할이 큽니다.
그래서 음식 글에서는 먹는 순간의 액션 컷이 더 좋습니다.
```

### 데모 5: 자동화 서버 그림 보여주기

도식:

```text
Scheduler -> Queue -> Orchestrator -> Workers -> Workspace -> Notion Draft
```

말할 내용:

```text
여기까지 오면 AI 프롬프트가 아니라 운영 시스템입니다.
큐, 워커, 로그, 재시도, 승인 게이트가 필요합니다.
```

### 데모 6: app-server는 어디에 붙는지 설명

명령:

```bash
codex app-server --help
```

말할 내용:

```text
app-server는 이미지 API 서버가 아닙니다.
Codex 세션을 외부 rich client가 제어할 수 있게 하는 JSON-RPC 서버입니다.
그래서 처음에는 codex exec로 시작하고, 나중에 app-server로 고도화하는 순서가 좋습니다.
```

---

## 말로 설명할 때 쓸 문장

짧은 표현:

```text
Claude Code는 감독, Codex는 작업자입니다.
```

```text
Codex app-server는 이미지 API가 아니라 Codex 세션 제어 서버입니다.
```

```text
자동 생성과 자동 발행은 다릅니다.
```

```text
Mac mini는 개인 AI 자동화 서버로 쓰기 좋습니다.
```

```text
Spark는 글의 최종 책임자가 아니라 반복 작업자부터 맡기는 게 좋습니다.
```

```text
이미지는 글의 장식이 아니라 섹션을 여는 시각 앵커입니다.
```

```text
맛집 이미지는 상차림보다 먹는 순간이 더 강합니다.
```

---

## 피해야 할 설명

```text
Claude Code가 OpenAI 이미지 API를 직접 호출한다.
Codex가 Claude Code를 부른다.
OAuth 토큰을 REST API key처럼 쓰면 된다.
app-server를 외부에 열어두면 편하다.
완전 자동 발행부터 하면 된다.
Spark로 모든 단계를 대체하면 된다.
이미지는 그냥 placeholder 문구만 보고 만들면 된다.
```

위 표현은 실제 구조와 다르거나 운영 리스크를 만든다.

---

## 최종 아키텍처 요약

```text
Mac mini
  ├─ launchd scheduler
  ├─ SQLite job queue
  ├─ blog orchestrator
  ├─ Claude Code / blog-pipeline
  ├─ Codex exec workers
  ├─ Codex app-server
  ├─ Spark prompt workers
  ├─ image_gen workers
  ├─ workspace artifacts
  └─ Notion Draft publisher
```

역할:

```text
Claude Code:
  전체 설계, 단계 검증, 발행 게이트

Codex exec:
  지금 바로 쓸 수 있는 headless worker 실행 경로

Codex app-server:
  나중에 붙일 상시 실행 세션 백엔드

Spark:
  저비용 반복 작업자

image_gen:
  Codex 안에서 실행되는 이미지 생성 도구

Notion:
  자동 발행지가 아니라 우선 Draft 저장소
```

---

## 최종 결론

이 아이디어는 정규 세션으로 충분히 갈 수 있다.

단순히 "블로그를 AI로 써요"가 아니라, 다음 주제를 모두 포함하기 때문이다.

```text
에이전트 역할 분리
사실 검증 파이프라인
Codex OAuth 기반 이미지 생성
Claude Code와 Codex의 상하위 worker 구조
Spark 모델의 비용 절감 활용
Mac mini 개인 자동화 서버
app-server 기반 장기 확장
Notion Draft 발행
운영/보안/재시도/로그 설계
```

가장 좋은 메시지는 이것이다.

```text
이제 AI 자동화는 프롬프트 하나가 아니라,
작업을 나누고, 검증하고, 실패를 기록하고,
사람이 승인할 부분을 남기는 운영 시스템으로 가야 합니다.
```

그리고 이 프로젝트는 그걸 블로그 자동화라는 쉬운 예제로 보여주기 좋다.

---

## 참고 링크

- 기존 영상 기획서: [YOUTUBE_VIDEO_PLAN.md](./YOUTUBE_VIDEO_PLAN.md)
- Codex app-server README: https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md
- Codex CLI repository: https://github.com/openai/codex
- OpenAI Help Center - Codex with ChatGPT plan: https://help.openai.com/en/articles/11369540-codex-in-chatgpt-faq
- OpenAI Help Center - Codex rate card: https://help.openai.com/articles/20001106-codex-rate-card
