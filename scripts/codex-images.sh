#!/usr/bin/env bash
# /blog-pipeline 4.6단계: image-prompts.json의 항목마다 codex exec를 한 번씩 돌려
# Codex 내장 image_gen으로 섹션 이미지를 만든다. final.md는 건드리지 않는다.
#
# usage:
#   scripts/codex-images.sh generate workspace/{RUN_ID}   # images/*.png + images.manifest.json
#   scripts/codex-images.sh swap     workspace/{RUN_ID}   # final.md → final.images.md (사본)
#
# env:
#   CODEX_IMAGE_MODEL  선택. 비우면 ~/.codex/config.toml 기본 모델 사용.
#
# macOS 기본 bash 3.2 호환. jq 필요.

set -euo pipefail

die() { echo "[codex-images] $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || die "jq가 필요해요."

MODE="${1:-}"
RUN_ARG="${2:-}"
[[ -n "$MODE" && -n "$RUN_ARG" ]] || die "usage: $0 generate|swap workspace/{RUN_ID}"
[[ -d "$RUN_ARG" ]] || die "run 디렉토리가 없어요: $RUN_ARG"

RUN_DIR="$(cd "$RUN_ARG" && pwd)"
PROMPTS="$RUN_DIR/image-prompts.json"
MANIFEST="$RUN_DIR/images.manifest.json"
IMG_DIR="$RUN_DIR/images"
LOG_DIR="$RUN_DIR/imagegen-logs"

generate() {
  command -v codex >/dev/null 2>&1 || die "codex CLI가 없어요. README의 사전 요구사항을 보세요."
  codex login status < /dev/null 2>&1 | grep -q "Logged in" || die "codex login이 안 돼 있어요. 'codex login'을 먼저 실행하세요."
  [[ -f "$PROMPTS" ]] || die "image-prompts.json이 없어요: $PROMPTS (4.5단계 blog-image-router 먼저)"
  jq -e 'type == "array" and length > 0' "$PROMPTS" >/dev/null || die "image-prompts.json은 비어 있지 않은 배열이어야 해요."

  mkdir -p "$IMG_DIR" "$LOG_DIR"
  local entries="$LOG_DIR/manifest.jsonl"
  : > "$entries"

  local model_args=()
  if [[ -n "${CODEX_IMAGE_MODEL:-}" ]]; then
    model_args=(-m "$CODEX_IMAGE_MODEL")
  fi

  local total ok=0 failed=0
  total="$(jq 'length' "$PROMPTS")"

  local i=0
  while IFS= read -r entry; do
    i=$((i + 1))
    local filename prompt negatives out name status
    filename="$(jq -r '.filename' <<<"$entry")"
    [[ "$filename" =~ ^[a-z0-9-]+\.png$ ]] || die "filename 형식이 잘못됐어요 (소문자·숫자·하이픈 + .png): $filename"
    prompt="$(jq -r '.prompt' <<<"$entry")"
    negatives="$(jq -r '(.negative_constraints // []) | map("- " + .) | join("\n")' <<<"$entry")"
    out="$IMG_DIR/$filename"
    name="${filename%.png}"

    rm -f "$out"
    cat > "$LOG_DIR/$name.prompt.txt" <<EOF
There is NO OPENAI_API_KEY and none is needed. You are logged in with ChatGPT, so use the built-in Image Gen tool DIRECTLY (account-based). Do NOT report that a key is missing.
Generate ONE real image and save it to exactly this path: $out
Real model image only, NOT drawn with Python/PIL/SVG/code. If it errors, retry once.
Landscape orientation (1536x1024). Write no other files and do not edit any existing file.

IMAGE:
$prompt

AVOID:
$negatives

Print the saved path.
EOF

    echo "[codex-images] ($i/$total) $filename 생성 중..."
    # 프롬프트는 stdin('-')으로 넘기고, 부모 stdin은 물려주지 않는다.
    codex exec \
      -C "$IMG_DIR" \
      -s workspace-write \
      -c 'sandbox_workspace_write.network_access=true' \
      --skip-git-repo-check \
      ${model_args[@]+"${model_args[@]}"} \
      -o "$LOG_DIR/$name.last.md" \
      - < "$LOG_DIR/$name.prompt.txt" > "$LOG_DIR/$name.log" 2>&1 || true

    # exit 0이어도 실패일 수 있어서 파일 존재·형식으로만 판정한다.
    if [[ -s "$out" ]] && file -b "$out" | grep -q "PNG image data"; then
      status="generated"; ok=$((ok + 1))
      echo "[codex-images] ok $out ($(wc -c < "$out" | tr -d ' ') bytes)"
    else
      status="failed"; failed=$((failed + 1))
      echo "[codex-images] FAIL $filename. 로그 끝부분:" >&2
      tail -5 "$LOG_DIR/$name.log" >&2 || true
    fi

    jq -c --arg status "$status" '{
        section_heading: (.section_heading | sub("^#+\\s*"; "")),
        source_placeholder,
        prompt,
        negative_constraints: (.negative_constraints // []),
        filename,
        status: $status
      }' <<<"$entry" >> "$entries"
  done < <(jq -c '.[]' "$PROMPTS")

  jq -s '{images: .}' "$entries" > "$MANIFEST"
  rm -f "$entries"
  echo "[codex-images] manifest: $MANIFEST  generated=$ok failed=$failed total=$total"
  [[ "$failed" -eq 0 ]]
}

swap() {
  [[ -f "$RUN_DIR/final.md" ]] || die "final.md가 없어요: $RUN_DIR/final.md"
  [[ -f "$MANIFEST" ]] || die "images.manifest.json이 없어요. generate를 먼저 실행하세요."

  local pairs="$LOG_DIR/swap-pairs.tsv"
  mkdir -p "$LOG_DIR"
  # placeholder 줄 → 이미지 마크다운. alt는 "AI 생성 이미지: " + placeholder의 [] 안쪽 설명.
  jq -r '.images[] | select(.status == "generated") |
    [ .source_placeholder,
      "![AI 생성 이미지: " + (.source_placeholder | capture("\\[(?<d>.*)\\]").d // .section_heading) + "](images/" + .filename + ")"
    ] | @tsv' "$MANIFEST" > "$pairs"

  awk -F'\t' '
    NR == FNR { map[$1] = $2; next }
    { line = $0; sub(/^[ \t]+/, "", line); sub(/[ \t]+$/, "", line) }
    (line in map) { print map[line]; swapped++; next }
    { print }
    END { printf("[codex-images] swapped=%d\n", swapped) > "/dev/stderr" }
  ' "$pairs" "$RUN_DIR/final.md" > "$RUN_DIR/final.images.md"

  rm -f "$pairs"
  echo "[codex-images] $RUN_DIR/final.images.md 작성 (final.md는 그대로)"
}

case "$MODE" in
  generate) generate ;;
  swap) swap ;;
  *) die "알 수 없는 모드: $MODE (generate|swap)" ;;
esac
