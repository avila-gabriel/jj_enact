#!/usr/bin/env sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
env_file="$root_dir/.envrc"

if [ ! -f "$env_file" ]; then
  echo "error: missing .envrc" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$env_file"
set +a

SKILL_NAME="${SKILL_NAME:-${JJ_ALIAS_NAME:-}}"
JJ_ALIAS_CONFIG_FILE="${JJ_ALIAS_CONFIG_FILE:-jj-alias.toml}"

if [ -z "${JJ_ALIAS_NAME:-}" ] || [ -z "${JJ_ALIAS_CONFIG_FILE:-}" ]; then
  echo "error: JJ_ALIAS_NAME and JJ_ALIAS_CONFIG_FILE are required in .envrc" >&2
  exit 1
fi

case "$JJ_ALIAS_CONFIG_FILE" in
  /*)
    alias_config_file="$JJ_ALIAS_CONFIG_FILE"
    ;;
  *)
    alias_config_file="$root_dir/$JJ_ALIAS_CONFIG_FILE"
    ;;
esac

if [ ! -f "$alias_config_file" ]; then
  echo "error: missing jj alias config file: $JJ_ALIAS_CONFIG_FILE" >&2
  exit 1
fi

alias_value=$(jj --config-file "$alias_config_file" config get "aliases.$JJ_ALIAS_NAME")
JJ_ALIAS_TOML=$(cat "$alias_config_file")
export JJ_ALIAS_TOML

jj config set --user "aliases.$JJ_ALIAS_NAME" "$alias_value"
jj config get "aliases.$JJ_ALIAS_NAME" >/dev/null

sh "$root_dir/scripts/install-codex-skill.sh" "$SKILL_NAME" "$root_dir/codex_skill"

echo "Installed jj alias: jj $JJ_ALIAS_NAME"
