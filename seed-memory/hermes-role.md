---
name: hermes-role
description: Phase-2 stub — where a local Hermes 3 instance could plug into the swarm to absorb transcript-compaction load
metadata:
  type: project
---

**Status: NOT IMPLEMENTED YET.** This file documents the planned integration point so the next coord can pick it up.

## Why Hermes (or similar local model)

Currently `sleep_expert` is the most token-heavy operation in the swarm. The scribe distills hours of transcript into compact memory notes — quality requirements are moderate ("preserve key decisions and open loops"), and it runs frequently (every shutdown, every cross-machine handoff, every periodic compaction). Hosting that load on Claude's API is expensive for what it produces.

A local Nous Hermes 3 (8B, quantized — runs on consumer-CPU; 70B on GPU) absorbs this load:
- No API cost
- No subscription rate-limit pressure
- Data stays local (relevant if expert transcripts touch sensitive code)
- Always available

Quality tradeoff: Hermes is meaningfully weaker than Claude at nuanced summarization, but for "compact a transcript into memory notes" the gap is forgivable.

## Where it plugs in

The `sleep_expert` action currently invokes a "scribe" process that reads the expert's transcript and writes compacted memory files. The scribe is the natural Hermes target — swap the LLM call from Anthropic to a local inference endpoint.

Proposed architecture:

```
┌────────────────────┐    sleep_expert    ┌─────────────────┐
│ coord (Claude)     │ ─────────────────► │ worker daemon    │
└────────────────────┘                    └────────┬─────────┘
                                                    │ spawn scribe
                                                    ▼
                                          ┌─────────────────┐
                                          │ scribe process   │
                                          │ (Python script)  │
                                          └────────┬─────────┘
                                                    │ HTTP POST
                                                    ▼
                                          ┌─────────────────┐
                                          │ local inference  │ ← Hermes 3 here
                                          │ (ollama/llama.cpp│
                                          │ /vllm)           │
                                          └─────────────────┘
```

## Concrete next steps when picking this up

1. **Choose an inference server.** Ollama is simplest on CPU; llama.cpp for tighter control; vllm if a GPU is available. Ollama lets you `ollama pull hermes3:8b` and it just runs.
2. **Add a new action** `set_scribe_backend(name, endpoint)` to the worker, persisting the choice in config.
3. **Modify the scribe** to call the configured endpoint instead of Anthropic when `backend != "claude"`.
4. **Sanity test**: sleep an idle expert, compare the Hermes-generated memory file to a Claude-generated baseline. If quality is acceptable for the role, switch over.

## Other potential roles (lower priority)

- **Inbox triage** — Hermes monitors all session inboxes, generates a one-line "you have 3 unread, mostly about T-0014" summary. Saves coord a peer_inbox_read sweep.
- **Routing heuristic** — given a finding, suggest the owner role (backend/frontend/planner). Currently coord-decides; could be deterministic OR a 1-token classifier.
- **Status board narrator** — periodic English summary of the swarm state. Useful for showing the human user "here's what happened in the last hour."

These are all post-T-0009 (the `status_summary` action) territory — that endpoint provides the data Hermes would narrate over.

## Why not now

The init script ships before this. Until the protocol-level fixes (Tier A of bot-swarm I-0001) land, adding Hermes adds a moving piece. Defer to Phase 2; come back when the swarm is stable and you want to cut LLM costs.
