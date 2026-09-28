#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${SLACK_WEBHOOK_URL:-}" ]]; then
  echo "SLACK_WEBHOOK_URL is NOT SET"
  exit 0
fi

EVENT="${HERDR_PLUGIN_EVENT_JSON:-}"

if [[ -z "$EVENT" ]]; then
  echo "HERDR_PLUGIN_EVENT_JSON is empty"
  exit 0
fi

STATUS="$(jq -r '(.data.agent_status // .agent_status // "unknown")' <<<"$EVENT")"

echo "STATUS: $STATUS"

AGENT="$(jq -r '(.data.display_agent // .display_agent // .data.agent // .agent // "Unknown agent")' <<<"$EVENT")"
TITLE="$(jq -r '(.data.title // .title // empty)' <<<"$EVENT")"
PANE_ID="$(jq -r '(.data.pane_id // .pane_id // empty)' <<<"$EVENT")"
WORKSPACE_ID="$(jq -r '(.data.workspace_id // .workspace_id // empty)' <<<"$EVENT")"

case "$STATUS" in
working)
  if [[ -n "$PANE_ID" ]]; then
    STATE_FILE="${HERDR_PLUGIN_STATE_DIR:?HERDR_PLUGIN_STATE_DIR is not set}/active-panes.json"
    mkdir -p "$HERDR_PLUGIN_STATE_DIR"
    exec 9>"${STATE_FILE}.lock"
    flock 9
    [[ -e "$STATE_FILE" ]] || printf '{}' >"$STATE_FILE"
    STATE_TMP="$(mktemp "${STATE_FILE}.XXXXXX")"
    trap 'rm -f "$STATE_TMP"' EXIT
    jq --arg pane "$PANE_ID" '.[$pane] = true' "$STATE_FILE" >"$STATE_TMP"
    mv "$STATE_TMP" "$STATE_FILE"
  fi
  echo "NOTIFY: skipped"
  exit 0
  ;;
done|idle)
  if [[ -z "$PANE_ID" ]]; then
    echo "NOTIFY: skipped (missing pane_id)"
    exit 0
  fi
  STATE_FILE="${HERDR_PLUGIN_STATE_DIR:?HERDR_PLUGIN_STATE_DIR is not set}/active-panes.json"
  mkdir -p "$HERDR_PLUGIN_STATE_DIR"
  exec 9>"${STATE_FILE}.lock"
  flock 9
  [[ -e "$STATE_FILE" ]] || printf '{}' >"$STATE_FILE"
  ACTIVE="$(jq -r --arg pane "$PANE_ID" '.[$pane] // false' "$STATE_FILE")"
  STATE_TMP="$(mktemp "${STATE_FILE}.XXXXXX")"
  trap 'rm -f "$STATE_TMP"' EXIT
  jq --arg pane "$PANE_ID" 'del(.[$pane])' "$STATE_FILE" >"$STATE_TMP"
  mv "$STATE_TMP" "$STATE_FILE"
  flock -u 9
  exec 9>&-
  if [[ "$ACTIVE" != true ]]; then
    echo "NOTIFY: skipped (no preceding working state)"
    exit 0
  fi
  EMOJI="✅"
  LABEL="完了"
  ;;
blocked)
  EMOJI="⚠️"
  LABEL="ブロック"
  ;;
*)
  echo "NOTIFY: skipped"
  exit 0
  ;;
esac

TEXT="${EMOJI} ${AGENT} — ${LABEL}"

if [[ -n "$TITLE" ]]; then
  TEXT+=$'\n'"${TITLE}"
fi

TEXT+=$'\n'"Workspace: ${WORKSPACE_ID}"
TEXT+=$'\n'"Pane: ${PANE_ID}"

PAYLOAD="$(jq -n --arg text "$TEXT" '{text: $text}')"

HTTP_CODE="$(
  curl \
    --silent \
    --show-error \
    --fail \
    --max-time 10 \
    -o /dev/null \
    -w '%{http_code}' \
    -X POST \
    -H 'Content-Type: application/json' \
    --data "$PAYLOAD" \
    "$SLACK_WEBHOOK_URL"
)"

echo "Slack HTTP status: $HTTP_CODE"
