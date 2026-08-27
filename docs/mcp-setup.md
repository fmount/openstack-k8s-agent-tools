# MCP Setup

Optional MCP server integrations for the plugin skills.

## Atlassian (Jira)

Required for `/feature` (Jira ticket planning) and `/jira` (ticket inspection). Uses [mcp-atlassian](https://github.com/sooperset/mcp-atlassian).

### Prerequisites

Install `uv`:

```bash
brew install uv    # macOS
pip install uv     # or via pip
```

### Jira Cloud

```json
{
  "mcpServers": {
    "mcp-atlassian": {
      "command": "uvx",
      "args": ["mcp-atlassian"],
      "env": {
        "JIRA_URL": "https://your-instance.atlassian.net",
        "JIRA_USERNAME": "you@example.com",
        "JIRA_API_TOKEN": "YOUR_JIRA_API_TOKEN",
        "JIRA_SSL_VERIFY": "true",
        "READ_ONLY_MODE": "true"
      }
    }
  }
}
```

Generate a Cloud API token at [https://id.atlassian.com/manage-profile/security/api-tokens](https://id.atlassian.com/manage-profile/security/api-tokens).

### Configuration

The JSON above goes in different locations depending on your platform:

| Platform | Global config | Project config |
|----------|--------------|----------------|
| Claude Code | `~/.claude/settings.json` | `.claude/settings.json` |
| OpenCode | `~/.config/opencode/opencode.json` | `opencode.json` |

**Claude Code CLI** — add via the CLI instead of editing JSON:

```bash
claude mcp add-json "mcp-atlassian" \
  '{"command":"uvx","args":["mcp-atlassian"],"env":{"JIRA_URL":"https://your-instance.atlassian.net","JIRA_USERNAME":"you@example.com","JIRA_API_TOKEN":"YOUR_TOKEN","JIRA_SSL_VERIFY":"true","READ_ONLY_MODE":"true"}}'
```

**OpenCode** — add the `mcpServers` block to your `opencode.json`:

```json
{
  "mcpServers": {
    "mcp-atlassian": {
      "type": "stdio",
      "command": "uvx",
      "args": ["mcp-atlassian"],
      "env": {
        "JIRA_URL": "https://your-instance.atlassian.net",
        "JIRA_USERNAME": "you@example.com",
        "JIRA_API_TOKEN": "YOUR_TOKEN",
        "JIRA_SSL_VERIFY": "true",
        "READ_ONLY_MODE": "true"
      }
    }
  }
}
```

Note: OpenCode requires the `"type": "stdio"` field in MCP server definitions.

**Codex** — Add the atlassian MCP to codex:
```
codex mcp add atlassian \
    --env JIRA_URL=https://redhat.atlassian.net/ \
    --env "JIRA_USERNAME=$EMAIL" \
    --env "JIRA_API_TOKEN=$TOKEN" \
    --env CONFLUENCE_URL=https://redhat.atlassian.net/wiki \
    --env "CONFLUENCE_USERNAME=$EMAIL" \
    --env "CONFLUENCE_API_TOKEN=$TOKEN" \
    -- /usr/bin/podman run -i --rm \
    -e JIRA_URL -e JIRA_USERNAME -e JIRA_API_TOKEN \
    -e CONFLUENCE_URL -e CONFLUENCE_USERNAME -e CONFLUENCE_API_TOKEN \
    ghcr.io/sooperset/mcp-atlassian:latest
```
Confirm it was registered:
```
codex mcp get atlassian
codex mcp list
```

### Read-Only Mode

Set `READ_ONLY_MODE` to `"true"` when you only need to read tickets (recommended for `/feature` planning). Set to `"false"` if you want `/jira` or `/task-executor` to post comments back to Jira.

Note: even with `READ_ONLY_MODE=false`, the plugin's global rules require human approval before posting any comment. See `~/.claude/CLAUDE.md`.

## GitHub CLI (`gh`) Authentication

The `/code-review` and `/feature` skills use `gh` CLI for PR fetching and cross-repo analysis. `gh` must be authenticated.

### Setup

```bash
gh auth login
```

Follow the prompts to authenticate via browser or token.

### Token Permissions (Principle of Least Privilege)

If using a personal access token (PAT) instead of browser auth, grant only the permissions each skill needs:

**For `/code-review`** (read-only PR access):

| Scope | Permission | Why |
|-------|-----------|-----|
| `repo` | Read | Fetch PR diffs, metadata, comments |
| `read:org` | Read | Resolve org membership for private repos |

**For `/feature`** (cross-repo analysis):

| Scope | Permission | Why |
|-------|-----------|-----|
| `repo` | Read | Browse lib-common, peer operators, dev-docs |
| `read:org` | Read | Search within the openstack-k8s-operators org |

No write permissions are needed. The plugin never pushes code or creates PRs -- only the human operator does.

### Fine-Grained PAT (Recommended)

GitHub fine-grained PATs allow per-repository scoping:

```
Token name: openstack-k8s-agent-tools
Expiration: 90 days
Repository access: All repositories (or select specific ones)
Permissions:
  Contents: Read-only
  Pull requests: Read-only
  Metadata: Read-only
```

Generate at [https://github.com/settings/tokens?type=beta](https://github.com/settings/tokens?type=beta).

Set the token:

```bash
export GH_TOKEN="ghp_your_token_here"
```

Or authenticate once:

```bash
gh auth login --with-token < ~/.gh-token
```

## Jira Token Permissions

### Jira Cloud API Token

Jira Cloud API tokens inherit all permissions of the user account. There are no granular scopes. To limit exposure:

- Use a dedicated service account with restricted project access
- Set `READ_ONLY_MODE=true` in the MCP config (recommended for planning)
- The plugin's global rules (`~/.claude/CLAUDE.md`) require human approval before any write operation

Generate at [https://id.atlassian.com/manage-profile/security/api-tokens](https://id.atlassian.com/manage-profile/security/api-tokens).

### Jira Server / Data Center PAT

Personal access tokens on Jira Server/DC can be scoped. Create a token with:

- Read access to the relevant projects (OSPRH, RHOSZ, etc.)
- No admin permissions
- Set an expiration date

### Token Storage

Never commit tokens to git. Store them as environment variables or in a secrets manager:

```bash
# In ~/.bashrc or ~/.zshrc (not committed)
export JIRA_API_TOKEN="your_token"
export GH_TOKEN="ghp_your_token"
```

Or use a `.env` file (gitignored):

```bash
# .env (add to .gitignore)
JIRA_API_TOKEN=your_token
GH_TOKEN=ghp_your_token
```

## Which Skills Need MCP

| Skill | Jira MCP | GitHub CLI | What It Uses |
|-------|---------|-----------|-------------|
| `/feature` | Optional | Optional | Jira: reads tickets. gh: cross-repo analysis. Falls back to spec files / WebFetch. |
| `/jira` | Optional | No | Reads and inspects tickets. Posts comments if READ_ONLY_MODE=false. |
| `/task-executor` | Optional | No | Posts outcome comments to Jira after implementation. |
| `/code-review` | No | Optional | Fetches PR diffs and metadata. Falls back to WebFetch. |
| All other skills | No | No | No external integrations. |
