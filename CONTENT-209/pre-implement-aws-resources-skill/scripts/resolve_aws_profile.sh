#!/usr/bin/env bash
# Resolves which AWS CLI profile to use, without running any AWS command.
# Prints one JSON object to stdout and always exits 0 (the caller decides what to do with `status`).
#
# status values:
#   ok        - profile_arg/profile_name/source are set, safe to use directly (profile_arg is empty
#               for env-var credentials or a lone default profile)
#   ambiguous - several profiles exist (default included) and none was selected; profiles[] lists them
#   none      - no env var and no usable profile found; AWS CLI is unconfigured
set -euo pipefail

# Profile names are pasted into a shell command by the caller, so only a safe charset is accepted.
valid_name() {
  [[ "$1" =~ ^[A-Za-z0-9_.@+=,-]+$ ]]
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

emit_ok() {
  local profile_name="$1" source="$2"
  local profile_arg=""
  if [ -n "$profile_name" ]; then
    profile_arg="--profile $(json_escape "$profile_name")"
  fi
  printf '{"status":"ok","profile_arg":"%s","profile_name":"%s","source":"%s"}\n' \
    "$(json_escape "$profile_arg")" "$(json_escape "$profile_name")" "$(json_escape "$source")"
}

if [ -n "${AWS_PROFILE:-}" ]; then
  valid_name "$AWS_PROFILE" || { printf '{"status":"none","reason":"AWS_PROFILE contains unsupported characters"}\n'; exit 0; }
  emit_ok "$AWS_PROFILE" "AWS_PROFILE"
  exit 0
fi

if [ -n "${AWS_DEFAULT_PROFILE:-}" ]; then
  valid_name "$AWS_DEFAULT_PROFILE" || { printf '{"status":"none","reason":"AWS_DEFAULT_PROFILE contains unsupported characters"}\n'; exit 0; }
  emit_ok "$AWS_DEFAULT_PROFILE" "AWS_DEFAULT_PROFILE"
  exit 0
fi

if [ -n "${AWS_ACCESS_KEY_ID:-}" ] && [ -n "${AWS_SECRET_ACCESS_KEY:-}" ]; then
  emit_ok "" "AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY env vars"
  exit 0
fi

CRED_FILE="${AWS_SHARED_CREDENTIALS_FILE:-$HOME/.aws/credentials}"
CONFIG_FILE="${AWS_CONFIG_FILE:-$HOME/.aws/config}"

extract_profiles() {
  local file="$1" strip_prefix="$2"
  [ -f "$file" ] || return 0
  { grep -oE '^\[[^]]+\]' "$file" || true; } | sed 's/^\[//; s/\]$//' | while read -r name; do
    if [ "$strip_prefix" = "yes" ]; then
      if [ "$name" = "default" ]; then
        :
      elif [ "${name#profile }" != "$name" ]; then
        name="${name#profile }"
      else
        continue
      fi
    fi
    valid_name "$name" && printf '%s\n' "$name"
  done || true
}

profiles="$( { extract_profiles "$CRED_FILE" "no"; extract_profiles "$CONFIG_FILE" "yes"; } | sort -u)"

if [ -z "$profiles" ]; then
  printf '{"status":"none","reason":"no env var credentials and no usable profile in %s or %s (names with unsupported characters are skipped)"}\n' \
    "$(json_escape "$CRED_FILE")" "$(json_escape "$CONFIG_FILE")"
  exit 0
fi

# A default profile next to named ones is ambiguous: the user may be logged into a live account.
count="$(printf '%s\n' "$profiles" | grep -c .)"
if [ "$count" -eq 1 ]; then
  if [ "$profiles" = "default" ]; then
    emit_ok "" "only profile (default) across $CRED_FILE and $CONFIG_FILE"
  else
    emit_ok "$profiles" "only profile across $CRED_FILE and $CONFIG_FILE"
  fi
  exit 0
fi

profiles_json="$(printf '%s\n' "$profiles" | sed 's/^/"/; s/$/"/' | paste -sd, -)"
printf '{"status":"ambiguous","profiles":[%s]}\n' "$profiles_json"
