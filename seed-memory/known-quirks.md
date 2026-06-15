---
name: known-quirks
description: Current limitations and workarounds — check the punch list (~/bot-swarm/data/bot-swarm/backlog/) for what's being fixed
metadata:
  type: reference
---

These are protocol-level limitations as of 2026-06-11. Each has a corresponding T-NNNN task in the bot-swarm self-project backlog. If you're reading this much later, check whether the fix landed before working around it.

## 1. peer_send silent truncation (T-0002)

Large payloads (>3 KB observed) sometimes arrive truncated mid-sentence with no error. Workaround: keep dispatches under ~2 KB, OR split into multiple shorter peer_sends per logical topic. If a recipient reports something missing from your message, suspect truncation first.

## 2. No `list_actions` discovery (T-0003)

`/openapi.json` returns generic schema. To enumerate actions: `grep "ACTION_REGISTRY" ~/bot-swarm/worker/bot_squad_worker/actions.py`. Every entry there is callable via `/actions/<name>`.

## 3. Opaque `spawn_session` initiative errors (T-0007)

`spawn: invalid initiative name 'I-0002'` actually means: pass the `.md` filename, not the bare ID. Fix is to send the full filename (e.g. `I-0002-domain-feedback-jun2026.md`). Same applies to `bind_initiative`.

## 4. SIDs encode the username — cross-host migration leaves a trail (T-0010)

`S-claude-coord-pN` on this host vs `S-otheruser-coord-pX` on the old host. Slept-expert memory dirs carry across hosts cleanly (rsync); session frontmatter does not. When migrating, write a HANDOFF.md with the old → new SID translation if you care.

## 5. `inject_input` is not idle-aware (T-0005)

If the target pane is mid-task, typing into it interleaves with the current step. peer_send-with-nudge has the same issue. In practice this is rarely catastrophic — Claude Code queues input — but is worth knowing. Future fix: poll the pane for idleness before injecting.

## 6. Inbox files grow without rotation (T-0008)

`_chat/inbox-<sid>.log` files accumulate. No cleanup; size grows linearly. If a swarm runs for weeks, periodically truncate or rotate by hand. The fix is planned but trivial to hand-do: `mv inbox-<sid>.log inbox-<sid>.log.$(date +%Y%m%d) && touch inbox-<sid>.log`.

## 7. Telegram routing on geo-restricted hosts

Some VPS providers (KZ, RU) block direct Telegram API connections. If `bot-swarm-tg-bridge` and `planlink-tg-poller` fail with `ETIMEDOUT` or `Network unreachable` to `api.telegram.org`, you need a proxy. The PlanLink solution: route through a Cloudflare-WARP outbound on an xray container. See `~/bin/with-tg-proxy.sh` (installed by `init.sh --TG_PROXY_VIA_XRAY=1`) for the wrapper that auto-resolves the proxy container IP and exports HTTPS_PROXY.

Anthropic API works from KZ (tested 2026-06-09 from Almaty). The geo-block concern is Telegram-specific, not LLM-API-specific.

## 8. Node fetch doesn't auto-honor HTTPS_PROXY

If you write a Node script (e.g. a Telegram poller) and set `HTTPS_PROXY=http://...` in env, native `fetch` won't use it. Solution:

```js
const PROXY = process.env.HTTPS_PROXY || process.env.https_proxy;
if (PROXY) {
  const { setGlobalDispatcher, ProxyAgent } = await import('undici');
  setGlobalDispatcher(new ProxyAgent(PROXY));
}
```

`undici` is bundled with Node 18+ but importable only if installed (`npm install undici`). Python's urllib DOES honor `HTTPS_PROXY` natively — no fix needed there.

## 9. The bash wrapper around the worker daemon doesn't auto-restart

The systemd-user unit will restart on crash; the in-tmux wrapper used during interactive dev (`bash -lc python -m bot_squad_worker ...`) does not. If you're running the worker outside systemd, wrap it in a `while true; do ...; done` or use systemd.

## 10. `~/.claude/projects/<encoded-cwd>/` is per-cwd

Claude Code's auto-memory is keyed by the cwd you start `claude` in. Encoding: replace `/` with `-`, drop leading dash. `/home/claude/swarm` → `-home-claude-swarm`. Two `claude` sessions in different cwds get separate memory. The init script seeded memory for `$SWARM_HOME`; if you start claude elsewhere, that memory won't be loaded.
