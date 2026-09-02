# shellcheck shell=bash

setup() {
  _init_repo "$1"
  mkdir -p .sjujperpowers .test-bin .kata-fixture docs/sjujperpowers/specs docs/sjujperpowers/plans
  cat > .sjujperpowers/config.json <<'EOF'
{
  "version": 1,
  "roadmap": {
    "provider": "file"
  },
  "execution": {
    "provider": "kata",
    "project": "sjujperpowers",
    "completion": "landed"
  }
}
EOF
  cat > .test-bin/kata <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> .kata-fixture/commands.log

if [ "${1:-}" = version ]; then
  printf '%s\n' 'kata v0.15.0'
  exit 0
fi

create_key=''
create_label=''
blocks=''
close_ref=''
show_ref=''
previous=''
expect_value=''
for argument in "$@"; do
  if [ "$previous" = close ]; then
    close_ref=$argument
  fi
  if [ "$previous" = show ]; then
    show_ref=$argument
  fi
  if [ "$expect_value" = key ]; then
    create_key=$argument
    expect_value=''
    continue
  fi
  if [ "$expect_value" = label ]; then
    create_label=$argument
    expect_value=''
    continue
  fi
  if [ "$expect_value" = blocks ]; then
    blocks=$argument
    expect_value=''
    continue
  fi
  case "$argument" in
    --idempotency-key) expect_value=key ;;
    --label) expect_value=label ;;
    --blocks) expect_value=blocks ;;
  esac
  previous=$argument
done
close_ref=${close_ref##*#}
show_ref=${show_ref##*#}

case " $* " in
  *' list '*)
    case " $* " in
      *' --label sjujperpowers-task '*) ;;
      *) printf '%s\n' 'plan recovery must filter the task label' >&2; exit 64 ;;
    esac
    case " $* " in
      *' --meta sjujperpowers.plan=docs/sjujperpowers/plans/example.md '*)
        printf '%s\n' '{"issues":[{"short_id":"task1","title":"Document provider ownership","status":"open","labels":["sjujperpowers-task"],"metadata":{"sjujperpowers.plan":"docs/sjujperpowers/plans/example.md","sjujperpowers.task":"1"}}]}'
        ;;
      *) printf '%s\n' 'plan recovery must filter exact plan metadata' >&2; exit 64 ;;
    esac
    ;;
  *' health '*)
    printf '%s\n' '{"status":"ok"}'
    ;;
  *' projects show '*)
    printf '%s\n' '{"project":{"name":"sjujperpowers"}}'
    ;;
  *' next '*)
    case " $* " in
      *' --label sjujperpowers-task '*) ;;
      *) printf '%s\n' 'next must filter sjujperpowers-task' >&2; exit 64 ;;
    esac
    if [ -f .kata-fixture/task-ready ]; then
      printf '%s\n' '{"issue":{"short_id":"task1","title":"Document provider ownership","labels":["sjujperpowers-task"],"status":"open"},"parent":{"short_id":"root","qualified_id":"sjujperpowers#root","status":"open"}}'
    else
      printf '%s\n' '{"issue":{"short_id":"root","title":"Provider Ownership","labels":["sjujperpowers-plan"],"status":"open"}}'
    fi
    ;;
  *' show '*)
    task_status=open
    if [ -f .kata-fixture/task1-closed ]; then
      task_status=closed
    fi
    if [ "$show_ref" = root ]; then
      printf '{"issue":{"short_id":"root","title":"Provider Ownership","status":"open"},"links":[{"from":{"short_id":"task1","status":"%s"},"to":{"short_id":"root","status":"open"},"type":"blocks"}],"labels":[{"label":"sjujperpowers-plan"}]}\n' "$task_status"
    else
      printf '{"issue":{"short_id":"task1","title":"Document provider ownership","status":"%s"},"parent":{"short_id":"root","qualified_id":"sjujperpowers#root","status":"open"},"labels":[{"label":"sjujperpowers-task"}]}\n' "$task_status"
    fi
    ;;
  *' claim '*)
    jj log -r @ --no-graph -T change_id > .kata-fixture/change-at-claim
    jj log -r @ --no-graph -T description > .kata-fixture/description-at-claim
    printf '%s\n' '{"issue":{"short_id":"task1","status":"in_progress"}}'
    ;;
  *' comment '*)
    printf '%s\n' '{"comment":{"created":true}}'
    ;;
  *' create '*)
    issue_id=root
    case "$create_key" in
      *:task:*) issue_id="task${create_key##*:}" ;;
    esac
    if [ "$issue_id" = task1 ] && [ "$create_label" = sjujperpowers-task ] && [ "$blocks" = root ]; then
      touch .kata-fixture/task-ready
    fi
    printf '{"issue":{"short_id":"%s"}}\n' "$issue_id"
    ;;
  *' close '*)
    landed_readme=$(jj file show -r main README.md)
    case "$landed_readme" in
      *'Plane owns roadmap outcomes and Kata owns activated implementation tasks'*)
        touch .kata-fixture/landed-before-close
        ;;
      *)
        touch .kata-fixture/close-before-land
        ;;
    esac
    if [ -f .sjujperpowers/sdd/example/progress.md ]; then
      touch .kata-fixture/recovery-at-close
    fi
    if [ "$close_ref" = task1 ]; then
      touch .kata-fixture/task1-closed
    fi
    if [ "$close_ref" = root ]; then
      if [ -f .kata-fixture/task1-closed ]; then
        touch .kata-fixture/root-after-children
      else
        touch .kata-fixture/root-before-children
      fi
    fi
    printf '{"issue":{"short_id":"%s","status":"closed"}}\n' "$close_ref"
    ;;
  *)
    printf 'unexpected kata command: %s\n' "$*" >&2
    exit 64
    ;;
esac
EOF
  chmod +x .test-bin/kata
  cat > .gitignore <<'EOF'
.kata-fixture/
EOF
  cat > README.md <<'EOF'
# Demo Product

Provider ownership is not yet documented.
EOF
  cat > docs/sjujperpowers/specs/example-design.md <<'EOF'
# Provider Ownership

**Milestone:** M1 — Provider ownership
EOF
  cat > docs/sjujperpowers/plans/example.md <<'EOF'
# Provider Ownership Implementation Plan

**Spec:** `docs/sjujperpowers/specs/example-design.md`

**Source:** file:M1 — Provider ownership

### Task 1: Document provider ownership

Update the README.

EOF
  # shellcheck disable=SC2154
  PATH="$PWD/.test-bin:$PATH" node \
    "$here/../skills/tracking-providers/scripts/materialize-plan.mjs" \
    --root "$PWD" \
    --plan docs/sjujperpowers/plans/example.md >/dev/null
  rm .kata-fixture/commands.log
  _commit "initial project"
  _bookmark_main_at_parent
}
