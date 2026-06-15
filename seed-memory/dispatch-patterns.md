---
name: dispatch-patterns
description: How to actually orchestrate the swarm — patterns proven over a 3-day PlanLink build
metadata:
  type: reference
---

These patterns emerged from driving the PlanLink swarm (initiative I-0001 through I-0003) Jun 8–11 2026. Use them as defaults; they were tuned against real friction.

## Spawn-then-dispatch

Every Claude Code session has ONE chance to absorb its mission: the `initial_prompt` you pass to `spawn_session`. Make it self-contained. Include:

1. **Who they are** (role, why spawned, what they own)
2. **What was done before** (relevant state + file paths)
3. **What to do** (the actual task, with constraints)
4. **Reporting protocol** (peer_send target SID + format)
5. **When to halt** (after one pass? after a phase? at coord's call?)

Aim for ~50–100 lines. Less is OK if the task is small. More is needed if there's heavy context. Drop the prompt in a temp file and load it via Python into the JSON body — quoting nightmares otherwise.

## The peer_send + nudge primitive (current)

`peer_send` now (per T-0001) wakes the target's pane automatically — no separate inject_input call needed. Response includes `nudged: {sid: bool}` so you know whether the wake actually landed.

Pre-T-0001 code: explicit `inject_input` after every peer_send. Don't bring that pattern back unless you're targeting an offline pane and want to dump literal text rather than signal-then-drain.

## Routing findings to fix-experts

When a tester reports findings, don't have the tester peer_send experts directly. Route through coord. This keeps sequencing clean and lets you see what's flowing in the conversation.

Pattern:
1. tester peer_sends coord with `TESTER ROUND N: <count> findings\n<list>`
2. coord parses the list, groups by owner
3. coord peer_sends each owner with the subset of findings tagged for them
4. owners reply `<ROLE>: <task> FIXED — <summary>` to coord
5. coord re-prompts tester for round N+1

## Loop-until-clean

For verification cycles, set a finite-but-generous loop:
- tester reports N findings → route → fixes confirmed → re-prompt tester → next round
- Stop when N=0 ("ALL CLEAN") OR after K consecutive rounds with no convergence (hard cap)
- 3–5 rounds is the typical convergence shape for a well-scoped change

## Phase gates

When dispatching a multi-task queue (e.g. "do T-0014 then T-0015 then T-0016"), state in the brief: "Halt after each T-XXXX ships. Coord will re-prompt you." Otherwise the expert may chain straight through, denying you the review checkpoints.

T-0006 in the bot-swarm punch-list makes phase gates first-class via `halt_after: true` on task frontmatter. Until that ships, do it via prompt discipline.

## Long-poll the inbox in background

Don't poll. Use `peer_inbox_wait` in the background with a 30-min timeout. When new mail arrives, you get a wake event. While you wait, do other work or hand the user a status update.

```bash
curl -sS --unix-socket .../worker.sock -X POST \
  -d '{"slug":"...","sid":"...","timeout":1800}' \
  http://w/actions/peer_inbox_wait &
```

## Sleep before powering down

Before the host dies (planned shutdown, migration), call `sleep_expert` on every active SID. The transcript compacts into memory; respawning on another host gives the new session a continuous-feel resume even though it's actually a fresh Claude Code REPL.

## Don't dispatch to yourself recursively

Coord routing to coord ends up in your own inbox. Useful for a self-ping smoke test; useless otherwise. If you need to remind yourself of something, write it to a task progress note or a scratch file, not the inbox.

## Initial-prompt for the next coord

When you yourself were spawned, you read MEMORY.md (this dir). When you spawn other experts, give them their own seed-prompt that covers: role identity, reporting protocol, project context, the specific task. The worker's `templates/identity/` has role-specific stubs you can extend.
