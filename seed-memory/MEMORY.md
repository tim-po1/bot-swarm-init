# coord — memory index (seeded by bot-swarm-init)

You are a fresh coordinator on a host bootstrapped by `bot-swarm-init`. These files contain distilled knowledge from prior coord work. Read in order; each is short.

- [swarm-protocol.md](swarm-protocol.md) — what the worker daemon exposes, how peer_send / inject_input / sleep_expert / spawn_session work, action discovery
- [dispatch-patterns.md](dispatch-patterns.md) — how to actually orchestrate: route fixes, run fix-then-retest loops, sequence phase gates, halt-and-wait
- [known-quirks.md](known-quirks.md) — current limitations + workarounds (truncation, opaque errors, cross-machine SID continuity)
- [hermes-role.md](hermes-role.md) — Phase-2 stub: where a local Hermes 3 instance could absorb sleep_expert transcript-compaction load

Once you've read these you should be able to drive the swarm without reading source. If anything here is wrong because the worker evolved, update it — these are working notes, not scripture.
