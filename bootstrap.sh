#!/usr/bin/env bash
# bootstrap.sh
#
# Universal setup for AI coding agent tools (Claude Code + OpenCode):
#   1. OMC (oh-my-claudecode)  - multi-agent orchestration for Claude Code
#   2. oh-my-opencode          - the equivalent for OpenCode
#   3. Personal/community skills, installed for every detected agent
#      (via the `skills` CLI, https://github.com/vercel-labs/agent-skills)
#   4. Baseline MCP servers in Claude Code (acts as the source of truth)
#   5. vsync                   - keeps skills/MCP servers in sync between
#                                 Claude Code and OpenCode going forward
#                                 (https://github.com/nicepkg/vsync)
#
# Secrets and machine-specific paths are NOT hardcoded here. They are read
# from a local `.env` file next to this script (copy `.env.example` to
# `.env` and fill it in). `.env` must never be committed.
#
# Safe to re-run: every step here is idempotent.
#
# See README.md for how to install each piece manually, without this
# script, on a per-provider basis.

set -uo pipefail

ENV_FILE="$(dirname "${BASH_SOURCE[0]}")/.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$1"; }
ok()   { printf '\033[1;32m-> %s\033[0m\n' "$1"; }

# ---------------------------------------------------------------------------
log "0. Checking prerequisites"
# ---------------------------------------------------------------------------
command -v node >/dev/null || { echo "node/npm is missing - please install it first."; exit 1; }
command -v npm  >/dev/null || { echo "npm is missing - please install it first."; exit 1; }
command -v npx  >/dev/null || { echo "npx is missing - please install it first."; exit 1; }
command -v pipx >/dev/null || warn "pipx is missing - ai-config-cli will be skipped (pipx install pipx)"
ok "node $(node --version), npm $(npm --version)"

# Make sure the OpenCode binary is on PATH if it exists but isn't found
if ! command -v opencode >/dev/null; then
  for candidate in "$HOME/.opencode/bin/opencode" "$HOME/.local/share/opencode/bin/opencode"; do
    if [ -x "$candidate" ]; then
      mkdir -p "$HOME/.local/bin"
      ln -sf "$candidate" "$HOME/.local/bin/opencode"
      ok "Linked opencode: $candidate -> ~/.local/bin/opencode"
      break
    fi
  done
fi
if command -v opencode >/dev/null; then
  ok "opencode found: $(opencode --version 2>/dev/null)"
else
  warn "opencode not found - OpenCode steps will still be attempted (npx will fetch what it needs)"
fi

# A root-owned npm global prefix (common on system-managed Node installs)
# would make every 'npm install -g' below fail with EACCES. Switch to a
# user-owned prefix instead of requiring sudo.
CURRENT_NPM_PREFIX="$(npm config get prefix 2>/dev/null)"
if [ ! -w "$CURRENT_NPM_PREFIX/lib/node_modules" ] 2>/dev/null; then
  NPM_GLOBAL_DIR="$HOME/.npm-global"
  mkdir -p "$NPM_GLOBAL_DIR"
  npm config set prefix "$NPM_GLOBAL_DIR"
  CURRENT_NPM_PREFIX="$NPM_GLOBAL_DIR"
  ok "Switched npm prefix to $NPM_GLOBAL_DIR (no root required)"
fi
# Whether it was just switched or already set: this script run needs the
# prefix's bin dir on PATH, or 'command -v' won't find freshly installed
# binaries (vsync, etc.) later in this same run.
case ":$PATH:" in
  *":$CURRENT_NPM_PREFIX/bin:"*) ;;
  *) export PATH="$CURRENT_NPM_PREFIX/bin:$PATH" ;;
esac
if ! grep -q "$CURRENT_NPM_PREFIX/bin" "$HOME/.bashrc" 2>/dev/null; then
  warn "Add this permanently to your shell rc: export PATH=\"$CURRENT_NPM_PREFIX/bin:\$PATH\""
fi

# ---------------------------------------------------------------------------
log "1. OMC (oh-my-claudecode) for Claude Code"
# ---------------------------------------------------------------------------
npm install -g oh-my-claude-sisyphus && ok "oh-my-claude-sisyphus installed/updated"
if command -v omc >/dev/null; then
  omc install --quiet || warn "omc install reported an error"
  omc setup --quiet   || warn "omc setup reported an error"
  ok "OMC set up"
else
  warn "omc binary not found after npm install - check PATH"
fi

# ---------------------------------------------------------------------------
log "2. oh-my-opencode for OpenCode"
# ---------------------------------------------------------------------------
if command -v opencode >/dev/null; then
  npx --yes oh-my-opencode install --no-tui --platform=opencode \
    --claude=yes --openai=no --gemini=no --copilot=no \
    && ok "oh-my-opencode installed" \
    || warn "oh-my-opencode install failed (see output above)"
  npx --yes oh-my-opencode doctor || warn "oh-my-opencode doctor reported issues"
else
  warn "OpenCode is not installed - skipping oh-my-opencode"
fi

# ---------------------------------------------------------------------------
log "3. ai-config-cli (for authoring/converting your own plugin later, optional)"
# ---------------------------------------------------------------------------
if command -v pipx >/dev/null; then
  pipx install ai-config-cli 2>/dev/null || pipx upgrade ai-config-cli || true
  ok "ai-config-cli available ($(ai-config --version 2>/dev/null))"
fi

# ---------------------------------------------------------------------------
log "4. Personal/community skills for every agent (Claude Code, OpenCode, ...)"
# ---------------------------------------------------------------------------
skill_add() {
  # $1 = source repo, remaining args = skill names
  local source="$1"; shift
  local args=(-g -a '*' -y)
  for s in "$@"; do args+=(-s "$s"); done
  npx --yes skills add "$source" "${args[@]}" \
    && ok "Synced skills from $source" \
    || warn "Skill sync for $source failed"
}

skill_add mariusmariusmariusmariusmarius/rechtstexte-de rechtstexte-de
skill_add Leonxlnx/taste-skill brandkit design-taste-frontend gpt-taste \
  imagegen-frontend-mobile imagegen-frontend-web minimalist-ui \
  redesign-existing-projects stitch-design-taste
skill_add emilkowalski/skills animate animation-vocabulary apple-design \
  ask-sonner emil-design-eng find-animation-opportunities improve-animations \
  pick-ui-library prototype review-animations
skill_add vercel-labs/skills find-skills
skill_add anthropics/skills frontend-design
skill_add blader/humanizer humanizer
skill_add addyosmani/web-quality-skills accessibility performance seo web-quality-audit
skill_add JuliusBrussee/caveman cavecrew caveman caveman-commit caveman-compress \
  caveman-discover caveman-evidence-review caveman-explore caveman-help \
  caveman-learn caveman-manage caveman-optimize caveman-review caveman-setup \
  caveman-stats investigate-first lean-build migration safe-refactor \
  surgical-patch verify-and-stop

# Known tool quirk: for skills that are already installed globally, adding a
# new agent target (e.g. -a opencode) sometimes only updates the lockfile
# without physically copying the files. As a safety net, copy anything
# missing straight from the canonical store.
if [ -d "$HOME/.agents/skills" ] && [ -d "$HOME/.config/opencode/skills" ]; then
  for d in "$HOME/.agents/skills"/*/; do
    name="$(basename "$d")"
    if [ ! -e "$HOME/.config/opencode/skills/$name" ]; then
      cp -r "$d" "$HOME/.config/opencode/skills/$name"
      ok "Copied over (tool-quirk workaround): $name -> OpenCode"
    fi
  done
fi

# ---------------------------------------------------------------------------
log "5. Baseline MCP servers in Claude Code (source of truth for vsync)"
# ---------------------------------------------------------------------------
python3 - <<'PYEOF'
import json, os

path = os.path.expanduser("~/.claude.json")
with open(path) as f:
    data = json.load(f)
data.setdefault("mcpServers", {})

# context7 needs no secrets/paths - always add it
data["mcpServers"].setdefault("context7", {
    "type": "http",
    "url": "https://mcp.context7.com/mcp",
})

gh_token = os.environ.get("GITHUB_PERSONAL_ACCESS_TOKEN", "")
if gh_token and os.system("command -v docker >/dev/null 2>&1") == 0:
    data["mcpServers"]["github"] = {
        "type": "stdio",
        "command": "docker",
        "args": ["run", "-i", "--rm", "-e", "GITHUB_PERSONAL_ACCESS_TOKEN",
                 "ghcr.io/github/github-mcp-server"],
        "env": {"GITHUB_PERSONAL_ACCESS_TOKEN": gh_token},
    }
    print("github MCP server set")
else:
    print("github MCP server skipped (GITHUB_PERSONAL_ACCESS_TOKEN missing or docker not found)")

blender_bin = os.environ.get("BLENDER_MCP_BIN", "")
blender_path = os.environ.get("BLENDER_PATH", "")
if blender_bin and os.path.exists(blender_bin):
    data["mcpServers"]["blender"] = {
        "type": "stdio",
        "command": blender_bin,
        "args": [],
        "env": {"BLENDER_PATH": blender_path} if blender_path else {},
    }
    print("blender MCP server set")
else:
    print("blender MCP server skipped (BLENDER_MCP_BIN not set/found)")

supabase_url = os.environ.get("SUPABASE_MCP_URL", "")
if supabase_url:
    data["mcpServers"]["supabase"] = {"type": "http", "url": supabase_url}
    print("supabase MCP server set")
else:
    print("supabase MCP server skipped (SUPABASE_MCP_URL missing)")

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print("~/.claude.json updated, mcpServers:", list(data["mcpServers"].keys()))
PYEOF

# ---------------------------------------------------------------------------
log "6. vsync - ongoing sync from Claude Code to OpenCode"
# ---------------------------------------------------------------------------
npm install -g @nicepkg/vsync && ok "vsync installed/updated"

VSYNC_CONFIG="$HOME/.vsync.json"
if [ ! -f "$VSYNC_CONFIG" ]; then
  cat > "$VSYNC_CONFIG" <<'JSONEOF'
{
  "version": "1.0.0",
  "level": "user",
  "source_tool": "claude-code",
  "target_tools": ["opencode"],
  "sync_config": {
    "skills": true,
    "mcp": true,
    "agents": false,
    "commands": true
  },
  "use_symlinks_for_skills": false,
  "language": "en"
}
JSONEOF
  ok "Created ~/.vsync.json (source: claude-code -> opencode)"
else
  ok "~/.vsync.json already exists, left unchanged"
fi

if command -v vsync >/dev/null; then
  echo "--- vsync dry-run (preview) ---"
  vsync sync --user --dry-run || warn "vsync dry-run failed"
  echo
  echo y | vsync sync --user && ok "vsync sync applied" || warn "vsync sync failed"
else
  warn "vsync binary not found after npm install - check PATH"
fi

log "Done."
echo "Sanity checks: 'npx skills list -g', 'omc doctor', 'ai-config doctor', 'vsync plan'"
