# myagentskills

Personal setup for keeping AI coding agents (Claude Code, OpenCode) configured
consistently across machines: same skills, same MCP servers, same
orchestration layer.

It's three separate pieces glued together:

1. **[OMC (oh-my-claudecode)](https://www.npmjs.com/package/oh-my-claude-sisyphus)** -
   multi-agent orchestration for Claude Code.
2. **[oh-my-opencode](https://github.com/code-yeongyu/oh-my-openagent)** -
   the equivalent orchestration layer for OpenCode.
3. **Skills + MCP servers**, installed via the
   **[`skills`](https://github.com/vercel-labs/agent-skills)** CLI and kept in
   sync between providers via **[`vsync`](https://github.com/nicepkg/vsync)**.

`bootstrap.sh` does all of this in one shot on a fresh machine. This README
also documents how to do every step **by hand, per provider**, in case you
don't want to run the script, only need one piece, or are debugging why
something isn't showing up.

## What's included

### Orchestration

| Provider | Tool | Package |
|---|---|---|
| Claude Code | OMC | `oh-my-claude-sisyphus` (npm) |
| OpenCode | oh-my-opencode | `oh-my-opencode` (npm) |

### Skills

58 personal/community skills, installed globally for every detected agent
(Claude Code, OpenCode, Codex, Cursor, GitHub Copilot, ...) via the `skills`
CLI:

| Source repo | Skills |
|---|---|
| `mariusmariusmariusmariusmarius/rechtstexte-de` | rechtstexte-de |
| `Leonxlnx/taste-skill` | brandkit, design-taste-frontend, gpt-taste, imagegen-frontend-mobile, imagegen-frontend-web, minimalist-ui, redesign-existing-projects, stitch-design-taste |
| `emilkowalski/skills` | animate, animation-vocabulary, apple-design, ask-sonner, emil-design-eng, find-animation-opportunities, improve-animations, pick-ui-library, prototype, review-animations |
| `vercel-labs/skills` | find-skills |
| `anthropics/skills` | frontend-design, skill-creator, mcp-builder, webapp-testing, web-artifacts-builder, claude-api, docx, pdf, pptx, xlsx, canvas-design, theme-factory, brand-guidelines, doc-coauthoring |
| `blader/humanizer` | humanizer |
| `addyosmani/web-quality-skills` | accessibility, performance, seo, web-quality-audit |
| `JuliusBrussee/caveman` | cavecrew, caveman, caveman-commit, caveman-compress, caveman-discover, caveman-evidence-review, caveman-explore, caveman-help, caveman-learn, caveman-manage, caveman-optimize, caveman-review, caveman-setup, caveman-stats, investigate-first, lean-build, migration, safe-refactor, surgical-patch, verify-and-stop |
| `Monstroxx/luau-script-hub` | luau-script-hub |

`anthropics/skills` also ships `academy-guide`, `discernment-nudge`,
`internal-comms`, `slack-gif-creator`, and `algorithmic-art`, which were left
out on purpose: the first two are behavior-nudging skills (steering you
towards Anthropic's learning site, or appending follow-up questions to every
substantive answer) rather than task tools, and the rest are
corporate-Slack/novelty use cases that didn't seem generally useful here. Add
them the same way (`skill_add anthropics/skills <name>`) if you want them.

OMC's own ~50 Claude-Code-only skills/agents (team, ultragoal, ralph,
autopilot, planner/executor/architect, ...) are **not** synced to OpenCode on
purpose: they depend on Claude Code's Task/subagent machinery and would be
inert files there.

### MCP servers

Defined once in Claude Code, then mirrored to OpenCode by `vsync`:

| Server | Transport | Needs |
|---|---|---|
| `context7` | http | nothing (public endpoint) |
| `github` | stdio via docker | `GITHUB_PERSONAL_ACCESS_TOKEN`, docker |
| `blender` | stdio | local `blender-mcp` install |
| `supabase` | http | your Supabase project's MCP URL |

## Quick start (with the script)

```bash
cp .env.example .env
$EDITOR .env                # fill in your secrets/paths
./bootstrap.sh
```

Re-running is safe - every step is idempotent. Sanity checks afterwards:

```bash
npx skills list -g
omc doctor
ai-config doctor
vsync plan
```

One thing the script cannot do for you (blocked by sandboxing in some
environments): add the npm global bin dir to your shell rc permanently. If
your system's npm prefix isn't user-writable, the script switches it to
`~/.npm-global` and prints the line to add - do that once:

```bash
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
```

## Manual installation, per provider (no script)

### Claude Code

**Orchestration (OMC):**

```bash
npm install -g oh-my-claude-sisyphus
omc install
omc setup
```

**Skills** (repeat per source repo, `-a claude-code` limits it to Claude Code
only; drop `-a` or use `-a '*'` to install for every detected agent at once):

```bash
npx skills add <owner>/<repo> -g -a claude-code -y -s <skill-name> [-s <skill-name> ...]

# example:
npx skills add anthropics/skills -g -a claude-code -y -s frontend-design
```

**MCP servers:** edit `~/.claude.json`, key `mcpServers`. Two transport
shapes:

```jsonc
// remote (http)
"context7": {
  "type": "http",
  "url": "https://mcp.context7.com/mcp"
}

// local (stdio)
"github": {
  "type": "stdio",
  "command": "docker",
  "args": ["run", "-i", "--rm", "-e", "GITHUB_PERSONAL_ACCESS_TOKEN",
            "ghcr.io/github/github-mcp-server"],
  "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "<token>" }
}
```

Restart Claude Code after editing so it picks up new servers.

### OpenCode

**Orchestration (oh-my-opencode):**

```bash
# interactive (recommended for a one-off manual install):
npx oh-my-opencode install

# non-interactive:
npx oh-my-opencode install --no-tui --platform=opencode \
  --claude=yes --openai=no --gemini=no --copilot=no
```

Do **not** `npm install -g oh-my-opencode` - the project explicitly says
global installs aren't supported; always invoke it through `npx`/`bunx`.
Requires OpenCode >= 1.4.0.

**Skills:**

```bash
npx skills add <owner>/<repo> -g -a opencode -y -s <skill-name> [-s <skill-name> ...]
```

Known quirk: if a skill is already installed globally (for another agent)
and you add `-a opencode` to an otherwise-unchanged `skills add` call, the
tool sometimes registers OpenCode as a target in its lockfile without
actually copying the files. If `~/.config/opencode/skills/<name>/` doesn't
show up, copy it manually from the canonical store:

```bash
cp -r ~/.agents/skills/<name> ~/.config/opencode/skills/<name>
```

**MCP servers:** OpenCode has a native CLI for this - prefer it over editing
JSON by hand:

```bash
opencode mcp add
opencode mcp list
```

Or edit `~/.config/opencode/opencode.json` directly, key `mcp`:

```jsonc
// remote
"context7": {
  "type": "remote",
  "url": "https://mcp.context7.com/mcp",
  "enabled": true
}

// local
"github": {
  "type": "local",
  "command": ["docker", "run", "-i", "--rm", "-e", "GITHUB_PERSONAL_ACCESS_TOKEN",
              "ghcr.io/github/github-mcp-server"],
  "environment": { "GITHUB_PERSONAL_ACCESS_TOKEN": "<token>" },
  "enabled": true
}
```

Note OpenCode uses `command` as an array and `environment` (not `env`) -
different shape from Claude Code's format.

## Keeping things in sync afterwards: vsync

Install once:

```bash
npm install -g @nicepkg/vsync
```

Config lives at `~/.vsync.json` (user scope) or `<project>/.vsync.json`
(project scope):

```json
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
```

`agents: false` is intentional - see the note above about OMC's
Claude-only skills/agents.

```bash
vsync sync --user --dry-run   # preview
vsync sync --user             # apply (safe mode: creates/updates, never deletes)
vsync sync --user --prune     # strict mirror, including deletions
vsync plan                    # show the current plan without syncing
```

## Notes / things that bit us building this

- **npm global prefix**: on distros where Node is system-managed (e.g.
  Arch/CachyOS), `npm config get prefix` often points at a root-owned
  `/usr`, so `npm install -g` fails with `EACCES`. Fix is a user-owned
  prefix (`npm config set prefix ~/.npm-global` + PATH), not `sudo` -
  `bootstrap.sh` does this automatically.
- **`.env` values with special characters**: always quote values containing
  `&`, `?`, `#`, etc. An unquoted `&` gets parsed by bash as a background-job
  operator when the file is `source`d, silently truncating the variable.
- **`skills` CLI global target detection**: see the "Known quirk" note under
  OpenCode above.
- **[ai-config-cli](https://github.com/safurrier/ai-config)** was evaluated
  for this project and deliberately *not* used for skill/MCP syncing: its
  model is built around packaging a single Claude Code plugin and converting
  it to Codex/Cursor/OpenCode/Pi per-project, not syncing a user's global
  skill/MCP setup across machines. Its user-scope OpenCode output path also
  appears to target `~/opencode.json` instead of the real
  `~/.config/opencode/opencode.json`. It's still useful (and installed by
  `bootstrap.sh`) if you ever want to package one of these skills as a
  proper, portable Claude Code plugin - see `ai-config plugin create` and
  `ai-config convert`.
