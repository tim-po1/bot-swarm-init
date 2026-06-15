---
name: swarm-protocol
description: How the bot-swarm worker daemon works — socket, actions, inbox model
metadata:
  type: reference
---

## The worker daemon

A FastAPI app served over a Unix socket at `~/bot-swarm/data/_sock/worker.sock`. Started via systemd-user (`bot-swarm-worker.service`). All swarm coordination flows through actions on this socket.

Calling convention:

```bash
curl -sS --unix-socket ~/bot-swarm/data/_sock/worker.sock \
  -X POST -H 'Content-Type: application/json' \
  -d '{...params...}' \
  http://w/actions/<name>
```

## Actions you'll use the most

### `spawn_session`
Spawn a new Claude Code session in a tmux pane. Required: `slug`, `window`. Optional: `initial_prompt`, `task_id`, `initiative` (filename of the .md, not bare ID), `owner`, `role`. Returns `{ok, sid}`. New SID encodes the user — e.g. `S-claude-<window>-pN`.

### `peer_send`
Append a message to one or more recipient inboxes AND (default behavior) wake their tmux panes. Required: `slug`, `from_sid`, `to`, `text`. Optional: `nudge` (default true). Returns `{ok, delivered_to: [sid], nudged: {sid: bool}}`.
- `to` accepts a specific SID OR a role keyword (`planner`, `backend-expert`, etc.)
- If pane is dead/missing, `nudged[sid] = false`; inbox delivery still succeeds.

### `peer_inbox_read`
Drain new lines from a session's inbox file. Required: `slug`, `sid`. Returns `{ok, messages, count}`.

### `peer_inbox_wait`
Long-poll the inbox; blocks until new mail or timeout. Required: `slug`, `sid`. Optional: `timeout` (seconds, capped server-side). Returns `{ok, ready, elapsed_sec}`. Use this in background to receive without polling.

### `inject_input`
Send text to a SID's tmux pane (one Enter per line). Required: `sid`, `text`. Use when you want to type something specifically (not just signal). Fails if no live pane.

### `sleep_expert`
Compact a session's in-context transcript into its expert memory dir. Required: `slug`, `sid`. Takes 30 s – 2 min. Lets a slept session lose its in-context state without losing the audit trail. The pane stays alive; the Claude Code REPL just has a compacted summary as memory.

### `list_sessions` / `list_initiatives` / `list_tasks`
Read-only state inspection. Required: `slug` (the session/init/task project).

### `task_progress_add`
Append a one-line progress note to a backlog task's `## Progress` section. Required: `slug`, `task_id`, `sid`, `text`.

## Action discovery

To enumerate all actions: `grep "ACTION_REGISTRY" ~/bot-swarm/worker/bot_squad_worker/actions.py`. A future `list_actions` action is in the punch list (T-0003) but not yet built.

## Inbox model

Per-SID inbox file at `~/bot-swarm/data/<slug>/_chat/inbox-<sid>.log`. Messages are tab-separated lines: `<ISO timestamp>\t[from <sender_sid>]\t<text>`. peer_send appends; peer_inbox_read drains-from-cursor.

For role-keyword delivery with zero live sessions of that role, peer_send writes to `_chat/holding-<role>.log` instead. The first session of that role to spawn picks it up via inbox_read.

## Modes

Each action is tagged `coordinator_only`, `tmux_only`, or `both`. The worker decides which mode applies based on how it was invoked. Coordinator mode runs on the main host; tmux-only mode runs in subordinate user-workers (multi-user setup; rare).

The actions you care about as coord: peer_send and friends are `coordinator_only`; spawn_session, inject_input, list_sessions are `tmux_only`. Both modes run side-by-side in the standard single-host install.
