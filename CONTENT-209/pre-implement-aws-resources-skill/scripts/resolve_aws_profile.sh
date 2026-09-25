#!/usr/bin/env bash
# Resolves which AWS CLI profile to use, without running any AWS command.
# Prints one JSON object to stdout and always exits 0 (the caller decides what to do with `status`).
#
# status values:
#   ok        - profile_arg/profile_name/source are set, safe to use directly
#   ambiguous - multiple named profiles exist and none was selected; profiles[] lists the names
#   none      - no credentials file, no env var, and no profile found; AWS CLI is unconfigured
set -euo pipefail

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
  emit_ok "$AWS_PROFILE" "AWS_PROFILE"
  exit 0
fi

if [ -n "${AWS_DEFAULT_PROFILE:-}" ]; then
  emit_ok "$AWS_DEFAULT_PROFILE" "AWS_DEFAULT_PROFILE"
  exit 0
fi

CRED_FILE="${AWS_SHARED_CREDENTIALS_FILE:-$HOME/.aws/credentials}"
CONFIG_FILE="${AWS_CONFIG_FILE:-$HOME/.aws/config}"

extract_profiles() {
  local file="$1" strip_prefix="$2"
  [ -f "$file" ] || return 0
  grep -oE '^\[[^]]+\]' "$file" | sed 's/^\[//; s/\]$//' | while read -r name; do
    if [ "$strip_prefix" = "yes" ]; then
      if [ "$name" = "default" ]; then
        :
      elif [ "${name#profile }" != "$name" ]; then
        name="${name#profile }"
      else
        continue
      fi
    fi
    printf '%s\n' "$name"
  done
}

profiles="$( { extract_profiles "$CRED_FILE" "no"; extract_profiles "$CONFIG_FILE" "yes"; } | sort -u)"

if [ -z "$profiles" ]; then
  printf '{"status":"none","reason":"no credentials file, env var, or profile found"}\n'
  exit 0
fi

if printf '%s\n' "$profiles" | grep -qx 'default'; then
  emit_ok "" "default profile in $([ -f "$CRED_FILE" ] && printf '%s' "$CRED_FILE" || printf '%s' "$CONFIG_FILE")"
  exit 0
fi

count="$(printf '%s\n' "$profiles" | grep -c .)"
if [ "$count" -eq 1 ]; then
  emit_ok "$profiles" "only named profile across $CRED_FILE and $CONFIG_FILE"
  exit 0
fi

profiles_json="$(printf '%s\n' "$profiles" | sed 's/^/"/; s/$/"/' | paste -sd, -)"
printf '{"status":"ambiguous","profiles":[%s]}\n' "$profiles_json"
