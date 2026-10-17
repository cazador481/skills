#!/usr/bin/env bash
# Compare two versions of the grilling skill with agent-skill-eval.
#
# The variants are renamed (grilling-old, grilling-new) so that an installed
# personal `grilling` skill cannot shadow them in Claude Code.
#
# Usage: evals/grilling/calibrate.sh [OLD_REF] [RUNS] [MODEL]
#   OLD_REF  git ref holding the baseline SKILL.md (default: upstream/main)
#   RUNS     runs per case (default: 3)
#   MODEL    claude-code model alias (default: sonnet)
# Env: EVALS=<file in evals/grilling> picks the suite (default evals.json);
#      BUILD_ONLY=1 builds /tmp/ase-<suite> and validates without running.
set -euo pipefail

old_ref="${1:-upstream/main}"
runs="${2:-3}"
model="${3:-sonnet}"
repo="$(git rev-parse --show-toplevel)"
skill_path="skills/productivity/grilling/SKILL.md"
evals_src="$repo/evals/grilling"
evals_file="${EVALS:-evals.json}"
base="/tmp/ase-${evals_file%.json}"

rm -rf "$base"
for tag in old new; do
  name="grilling-$tag"
  mkdir -p "$base/$tag/skill/$name" "$base/$tag/evals"
  if [ "$tag" = old ]; then
    git -C "$repo" show "$old_ref:$skill_path" > "$base/$tag/skill/$name/SKILL.md"
  else
    cp "$repo/$skill_path" "$base/$tag/skill/$name/SKILL.md"
  fi
  sed -i "0,/^name: grilling\$/s//name: $name/" "$base/$tag/skill/$name/SKILL.md"
  grep -q "^name: $name\$" "$base/$tag/skill/$name/SKILL.md"
  cp -r "$evals_src/files" "$base/$tag/evals/files"
  python3 - "$evals_src/$evals_file" "$base/$tag/evals/evals.json" "$name" <<'EOF'
import json, sys
src, dst, name = sys.argv[1:]
suite = json.load(open(src))
suite["skill_name"] = name
for case in suite["evals"]:
    prompt = case["prompt"].replace("the grilling skill", f"the {name} skill", 1)
    case["prompt"] = prompt.replace('"grilling"', f'"{name}"')
json.dump(suite, open(dst, "w"), indent=2)
EOF
  ase validate "$base/$tag/evals/evals.json" | sed -n 1p
done

[ "${BUILD_ONLY:-0}" = 1 ] && exit 0

for tag in old new; do
  (cd "$base/$tag" && ase run --skill "skill/grilling-$tag" \
    --evals evals/evals.json --agent claude-code \
    --agent-model "claude-code=$model" --no-baseline --runs "$runs" \
    --concurrency 4 --workspace "$base/$tag/ws" > run.log 2>&1) &
done
wait

for tag in old new; do
  echo "== $tag"
  ase status --workspace "$base/$tag/ws/grilling-$tag-workspace" |
    grep -E 'runs:|claude-code_|cost:'
done
echo "Check each run loaded its skill: the Claude session transcript under"
echo "~/.claude/projects must contain a Skill tool call naming grilling-<tag>."
