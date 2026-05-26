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

required_vars="
JJ_ALIAS_NAME
JJ_ALIAS_CONFIG_FILE
SKILL_NAME
SKILL_PURPOSE
"

for var_name in $required_vars; do
  eval "value=\${$var_name:-}"
  if [ -z "$value" ]; then
    echo "error: missing required value in .envrc: $var_name" >&2
    exit 1
  fi
done

case "$JJ_ALIAS_NAME" in
  *[!a-z0-9-]* | "" | -* | *-)
    echo "error: JJ_ALIAS_NAME must be lower-kebab-case" >&2
    echo "received: $JJ_ALIAS_NAME" >&2
    exit 1
    ;;
esac

case "$SKILL_NAME" in
  *[!a-z0-9-]* | "" | -* | *-)
    echo "error: SKILL_NAME must be lower-kebab-case" >&2
    echo "received: $SKILL_NAME" >&2
    exit 1
    ;;
esac

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

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT INT HUP TERM

alias_value=$(
  XDG_CONFIG_HOME="$tmp_dir/config" jj --config-file "$alias_config_file" config get "aliases.$JJ_ALIAS_NAME"
)
JJ_ALIAS_TOML=$(cat "$alias_config_file")
export JJ_ALIAS_TOML

XDG_CONFIG_HOME="$tmp_dir/config" jj config set --user "aliases.$JJ_ALIAS_NAME" "$alias_value"
XDG_CONFIG_HOME="$tmp_dir/config" jj config get "aliases.$JJ_ALIAS_NAME" >/dev/null

if [ "$JJ_ALIAS_NAME" = "enact" ]; then
  repo_dir="$tmp_dir/enact-repo"
  first_input="Plan one
Body one"
  first_message="Plan one

## Plan
Body one"
  second_input="Plan two
Body two"
  second_message="Plan two

## Plan
Body two"

  (
    cd "$tmp_dir"
    XDG_CONFIG_HOME="$tmp_dir/config" jj config set --user user.name "Codex Test" >/dev/null
    XDG_CONFIG_HOME="$tmp_dir/config" jj config set --user user.email "codex@example.invalid" >/dev/null
  )

  XDG_CONFIG_HOME="$tmp_dir/config" jj git init "$repo_dir" >/dev/null

  (
    cd "$repo_dir"

    XDG_CONFIG_HOME="$tmp_dir/config" jj "$JJ_ALIAS_NAME" "$first_input" >/dev/null
    actual_first=$(
      XDG_CONFIG_HOME="$tmp_dir/config" jj log -r @ --no-graph --color never -T description
    )

    if [ "$actual_first" != "$first_message" ]; then
      echo "error: jj enact did not describe the empty current change" >&2
      exit 1
    fi

    printf '%s\n' "content" >file.txt

    XDG_CONFIG_HOME="$tmp_dir/config" jj "$JJ_ALIAS_NAME" "$second_input" >/dev/null
    actual_second=$(
      XDG_CONFIG_HOME="$tmp_dir/config" jj log -r @ --no-graph --color never -T description
    )
    actual_parent=$(
      XDG_CONFIG_HOME="$tmp_dir/config" jj log -r @- --no-graph --color never -T description
    )

    if [ "$actual_second" != "$second_message" ]; then
      echo "error: jj enact did not describe the new current change" >&2
      exit 1
    fi

    if [ "$actual_parent" != "$first_message" ]; then
      echo "error: jj enact did not create the new change on top of existing work" >&2
      exit 1
    fi
  )
fi

if [ -n "${JJ_ALIAS_SMOKE_ARGS:-}" ]; then
  # Intentionally allow word splitting so simple smoke args such as "--help" work.
  # shellcheck disable=SC2086
  XDG_CONFIG_HOME="$tmp_dir/config" jj "$JJ_ALIAS_NAME" $JJ_ALIAS_SMOKE_ARGS >/dev/null
fi

CODEX_SKILLS_DIR="$tmp_dir/skills" sh "$root_dir/scripts/install-codex-skill.sh" "$SKILL_NAME" "$root_dir/codex_skill" >/dev/null

if grep -R '{{' "$tmp_dir/skills/$SKILL_NAME" >/dev/null 2>&1; then
  echo "error: rendered skill still contains template placeholders" >&2
  exit 1
fi

echo "Alias and skill template are valid."
