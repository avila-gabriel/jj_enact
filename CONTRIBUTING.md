# JJ Alias Skill Template

A starting point for a Codex skill backed by a `jj` command alias.

## Use

After cloning, verify the template:

```sh
task bootstrap
```

Edit `.envrc` for the alias name, smoke test, and skill metadata:

```sh
export JJ_ALIAS_NAME="my-jj-alias"
export JJ_ALIAS_CONFIG_FILE="jj-alias.toml"
export JJ_ALIAS_SMOKE_ARGS="--help"

export SKILL_NAME="$JJ_ALIAS_NAME"
export SKILL_DESCRIPTION="When Codex should load this skill."
export SKILL_PURPOSE="the workflow this jj alias automates"
export TOOL_DESCRIPTION="One sentence about the alias-backed skill."
export CRITICAL_CONSTRAINT="A rule Codex must follow, if any."
```

Edit the alias TOML block in `jj-alias.toml`:

```toml
[aliases]
my-jj-alias = ["status"]
```

Iterate until the alias and skill render cleanly:

```sh
task done
```

Install the alias and Codex skill:

```sh
task install
jj my-jj-alias --help
```

`task install` writes the alias with `jj config set --user` and installs the rendered skill into `~/.agents/skills/<skill-name>/`.
