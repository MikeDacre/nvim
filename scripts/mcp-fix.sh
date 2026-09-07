#!/usr/bin/env bash
# mcp-fix.sh — recover a hung local MCP server without restarting Claude
# Desktop. Kills matching process(es) by command-line pattern; Claude
# Desktop respawns the server fresh on the next tool call.
#
# Usage:
#   mcp-fix.sh                 # kill desktop-commander (default target)
#   mcp-fix.sh <pattern>       # kill processes matching <pattern> instead
#   mcp-fix.sh --dry-run [pat] # show what would be killed, kill nothing
#   mcp-fix.sh --list          # list all locally-running MCP-ish node procs
#
# From claude_init; 3.2-safe.

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

TARGET="desktop-commander"
DRY_RUN=0
LIST=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --list)    LIST=1 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)         TARGET="$arg" ;;
  esac
done

# A too-generic pattern would take out every node process on the machine.
case "$TARGET" in
  node|npm|npx|python|python3|bash|sh|""|*[!a-zA-Z0-9._-]*)
    echo "  refusing: '$TARGET' is too broad or unsafe as a kill pattern."
    echo "  Use something specific, e.g. desktop-commander. Use --list to look around."
    exit 2 ;;
esac
[ ${#TARGET} -ge 4 ] || { echo "  refusing: pattern '$TARGET' is under 4 characters"; exit 2; }

if [[ $LIST -eq 1 ]]; then
  echo "MCP-ish node processes currently running:"
  ps -axo pid=,pcpu=,pmem=,etime=,command= | grep -i -E "node|desktop-commander|mcp" | grep -v grep
  exit 0
fi

echo "Target pattern: $TARGET"
PIDS=$(pgrep -f "$TARGET" | grep -v "^$$\$" || true)

if [[ -z "$PIDS" ]]; then
  echo "  --    no matching process found — nothing to do"
  exit 0
fi

echo "  found:"
for pid in $PIDS; do
  ps -p "$pid" -ww -o pid=,pcpu=,pmem=,etime=,command= 2>/dev/null | sed 's/^/        /'
done

if [[ $DRY_RUN -eq 1 ]]; then
  echo "  (dry run — no processes killed)"
  exit 0
fi

echo "  sending SIGTERM..."
for pid in $PIDS; do kill -TERM "$pid" 2>/dev/null; done
sleep 2

STILL=$(pgrep -f "$TARGET" | grep -v "^$$\$" || true)
if [[ -n "$STILL" ]]; then
  echo "  still alive — sending SIGKILL..."
  for pid in $STILL; do kill -KILL "$pid" 2>/dev/null; done
fi

echo "  ok    process(es) terminated — will respawn on next tool call"
