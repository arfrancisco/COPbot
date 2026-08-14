# COPbot v2 — Architecture & Implementation Plan

**Status:** Proposal / not yet implemented
**Supersedes:** the v1 design described in `PROJECT_SUMMARY.md`
**Context:** The bot is currently not running. This is a clean-slate redesign informed by what v1 got wrong.

---

## 1. What v1 got wrong

v1 was a single static RAG pipeline: embed every inbound message → cosine search at query time → stuff 25 results into one prompt → answer.

Four structural problems, in order of how much damage they did:

**1.1 — No temporal reasoning at all.** `Message.search_by_embedding` explicitly removed recency
(`# NO recency factor - pure relevance-based ranking`). A message from five minutes ago competed
against 90 days of history on cosine distance alone. This is the root cause of "it can't remember a
discussion that happened minutes ago."

**1.2 — A single chat message is a bad embedding unit.** Real messages are short, elliptical and
pronoun-heavy — *"sige"*, *"yung isa kagabi"*, *"ok gawin natin yun"*. Their vectors are close to
noise. Retrieval returned 25 disconnected one-liners, relevance-ordered, spanning different days and
channels, from which no coherent discussion could be reconstructed.

**1.3 — One retrieval strategy for every kind of question.** "When is the vet visit?", "What
happened yesterday?", "What's the feeding schedule?" and "Who volunteered this week?" are four
different lookups — a structured date query, a time-range scan, a stable-fact lookup, and a semantic
search. v1 answered all four with the same cosine search.

**1.4 — Hand-tuned scoring with no feedback loop.** The hybrid scorer carried magic constants
(`* 0.8`, `+ 1.0`, `text.length > 500 → + 0.6`) that nobody could validate, because there was no way
to measure whether a change made answers better or worse.

Everything below is organised around fixing those four, plus the two new requirements: scheduled
proactive messages, and calendar events with reminders.

---

## 2. Design principles

| Principle | Consequence |
|---|---|
| **Raw messages are the source of truth; everything else is a derived index.** | Any index can be rebuilt by re-running a job. No AI call is on the write path. |
| **Different questions need different lookups.** | The model chooses its retrieval via tool calls, rather than being handed one guess. |
| **Recent context is free — spend it.** | Recent history is always injected verbatim, never made to compete for retrieval slots. |
| **Structured facts belong in columns, not vectors.** | A vet appointment is a row with a timestamp. It is never retrieved by cosine similarity. |
| **The bot never silently commits the community to anything.** | Ambient extraction produces *candidates*; creation requires confirmation. |
| **If it isn't measured, it isn't tuned.** | An eval harness (§8) ships alongside the retrieval layer, not after it. |

---

## 3. Storage: four layers

Postgres + pgvector throughout. No new infrastructure.

### 3.1 Layer 1 — `messages` (raw log)

Every message, verbatim. **Insert only. No embedding, no LLM call.**

```
id
telegram_chat_id     bigint       -- for idempotency + replying
telegram_message_id  bigint
channel_id           string       -- "-1001234_5" (chat + forum topic)
channel_name         string
thread_id            string       -- forum topic id, nullable
reply_to_message_id  bigint       -- NEW: Telegram's reply graph, free thread signal
sender_id / sender_name / sender_username
text                 text
edited_at            datetime
message_timestamp    datetime
chunk_id             bigint       -- nullable FK; set by the chunker

unique  (telegram_chat_id, telegram_message_id)   -- idempotent ingest / replay-safe
index   (channel_id, message_timestamp)
index   (chunk_id) WHERE chunk_id IS NULL          -- partial; the chunker's scan
```

Two things v1 discarded that we keep: **`reply_to_message_id`** (Telegram hands us the conversation
graph for free) and **message identity** (makes ingest idempotent, so we can replay history safely).

### 3.2 Layer 2 — `conversation_chunks` (episodic memory)

A coherent stretch of discussion in one channel. This is the RAG index.

```
id
channel_id / channel_name
started_at / ended_at
message_count
participants     string[]
transcript       text          -- rendered "Name (3:04 PM): text" lines
summary          text          -- LLM-written, 1-3 sentences
topics           string[]
embedding        vector(1536)  -- of summary + transcript head
tsv              tsvector      -- generated column over summary + transcript
message_ids      bigint[]

HNSW index on embedding (cosine)
GIN  index on tsv
index (channel_id, ended_at)
```

**Segmentation is gap-based, not clock-based.** A fixed 15/30-minute grid slices live discussions in
half at the boundary and glues unrelated bursts together. Instead, within a channel: close a chunk
after `CHUNK_GAP_MINUTES` (start at 12) of silence, or when it exceeds a message/token cap. The
chunker seals every segment that has gone quiet and **leaves the still-active trailing segment
alone** — so no chunk is ever embedded twice while it is still growing.

**Search the summary, return the transcript.** This is parent-document / hierarchical retrieval, the
dominant production pattern in 2025–26: the small clean summary gives a dense, high-signal vector to
match against; the full transcript is what the model actually reads. It beats embedding raw
transcripts, whose vectors get smeared across every topic in the window.

### 3.3 Layer 3 — `facts` (semantic memory)

Distilled, durable community knowledge — the layer that makes this a concierge rather than a search
engine. *"Cats are fed at 7am and 6pm." "Prisma Vet on Shaw is the clinic we use." "Mingming is the
orange tabby in Tower B."*

```
id
statement          text
category           string     -- schedule | contact | location | animal | policy | supply
subject            string     -- normalized key, e.g. "feeding_schedule"
confidence         float
source_chunk_ids   bigint[]
source_message_ids bigint[]
valid_from         datetime
superseded_by_id   bigint     -- NULL = currently true
embedding          vector(1536)
```

**Facts are superseded, never overwritten.** When the feeding schedule changes, the old row gets a
`superseded_by_id` and the new one becomes current. Without versioning, semantic memory reliably
degrades into a junk drawer of mutually contradictory statements — this is the single most-cited
failure mode in the agent-memory literature.

Active facts are small enough (tens of rows) to inject wholesale into every prompt. That is why
"what's the feeding schedule?" should never require a vector search.

### 3.4 Layer 4 — `events` + `reminders` (structured temporal state)

```
events
  id, title, description
  starts_at / ends_at / all_day
  timezone          string   default 'Asia/Manila'
  location
  category          string   -- vet | feeding | meeting | supply_run | adoption
  status            string   -- candidate | confirmed | cancelled | done
  recurrence_rule   string   -- RRULE, nullable
  channel_id                 -- where to announce
  created_by_sender_id
  source_message_id
  extraction_confidence float
  index (starts_at) WHERE status = 'confirmed'

reminders
  id
  event_id           bigint   -- nullable (standalone reminders)
  channel_id
  target_sender_id            -- nullable = announce to whole channel
  body               text     -- nullable; rendered from the event if blank
  deliver_at         datetime
  delivered_at       datetime
  status             string   -- pending | sent | failed | cancelled
  attempts           integer
  last_error         text
  dedupe_key         string   UNIQUE
  index (deliver_at) WHERE status = 'pending'
```

All timestamps stored UTC, rendered `Asia/Manila`. (PH has no DST, but store the tz name anyway so
this doesn't become a rewrite if the community ever spans zones.)

---

## 4. Query path: a tool-calling agent, not a static pipeline

The single biggest change. Instead of *"run one vector search, hope it's right, stuff the prompt,"*
the model is given tools and decides what to look up.

**Always injected (no tool call needed):**
- Current date/time in Manila
- Channel roster
- All active `facts` (small)
- Last ~20 messages of the current conversation thread
- Verbatim messages from the last `RECENT_WINDOW_HOURS` (start at 8), chronological

**Available as tools:**

| Tool | Purpose |
|---|---|
| `search_conversations(query, channel?, since?, until?, limit)` | Hybrid retrieval over chunks |
| `get_messages_in_range(from, to, channel?)` | "What happened yesterday in #supplies" |
| `get_message_thread(message_id)` | Expand a hit into its reply chain |
| `lookup_facts(topic)` | Explicit semantic-memory query |
| `list_events(from, to, status?)` | Structured calendar read |
| `create_event(...)` / `create_reminder(...)` | Writes — see §6 for guardrails |

**Why agentic here, when the research says a static pipeline is often enough?** The usual advice —
don't add an agent loop if your static pipeline already hits ~85% context recall — assumes
homogeneous queries. Ours are not: the four question types in §1.3 need four different lookups, and
a follow-up like *"and who was supposed to bring the carrier?"* needs a second retrieval informed by
the first. Cost is 2–3 model round-trips instead of 1, which at this community's volume is
immaterial.

One caveat: `gpt-4o-mini` is weak at multi-step tool use. Plan to run the agent loop on a stronger
model and keep mini for the cheap high-volume background work (chunk summaries, extraction).

### 4.1 Retrieval mechanics

Inside `search_conversations`:

1. **Hybrid recall** — vector search over `embedding` **and** full-text search over `tsv`, run
   independently, top ~20 each.
2. **Fuse with Reciprocal Rank Fusion** (`score = Σ 1/(k + rank)`, k=60). RRF consistently beats
   either retriever alone, and — unlike v1's hand-tuned constants — it has essentially no knobs.
   Vector search alone is bad at exact tokens (names, dates, clinic names, "Mingming"); FTS covers
   that gap.
3. **Rerank to ~5.** Start with plain RRF truncation; add an LLM reranker over the top 20 if evals
   show it earns its latency.
4. **Exclude chunks inside the recency window** — those messages are already in the prompt verbatim.

Note for Tagalog/Taglish: Postgres has no Filipino FTS dictionary. Use the `simple` configuration
(no stemming, no stop words) — mirroring v1's correct decision not to strip stop words.

### 4.2 Label context by *kind*, not just content

```
## RECENT ACTIVITY — last 8 hours, COMPLETE, nothing omitted
## RETRIEVED DISCUSSIONS — matched by relevance, PARTIAL
## COMMUNITY FACTS — durable, current as of <date>
## SCHEDULE — structured events
```

v1's prompt could not distinguish *"the community never discussed this"* from *"retrieval missed
it,"* which made every confidence instruction in the system prompt guesswork. Marking which sections
are exhaustive is what makes "I don't have information about that" a truthful statement.

---

## 5. Proactive & scheduled messages

Driven by `sidekiq-cron`:

| Job | Schedule | Purpose |
|---|---|---|
| `ChunkConversationsJob` | every 5 min | Seal + embed quiet segments |
| `DeliverDueRemindersJob` | every 1 min | Send due reminders |
| `ExtractEventCandidatesJob` | every 30 min | Ambient event detection (§6) |
| `ExtractFactsJob` | nightly | Distil/supersede semantic memory |
| `DailyDigestJob` | 07:00 Manila | Today's schedule + yesterday's highlights |
| `WeeklySummaryJob` | Sun 18:00 Manila | Week in review, open items |
| `PruneJob` | nightly | Retention (§9) |

**Reminders use a poller, not `perform_at`.** Sidekiq's scheduled set lives in Redis; a scheduled job
sitting there for three weeks will not survive a Redis flush, a plan change, or an addon migration.
Instead, reminders are rows, and a job every minute claims due ones with
`FOR UPDATE SKIP LOCKED`, sends, and stamps `delivered_at`. Durable, replayable, inspectable in SQL,
and `dedupe_key` makes double-sends impossible. This is the standard outbox pattern and it is worth
the extra table.

Default reminder offsets per event: **T-1 day** and **T-2 hours**, configurable per event.

---

## 6. Event & reminder capture

Two paths, deliberately asymmetric.

**Explicit (high trust).** User tags the bot: *"@copbot remind us about the vet visit Tuesday 3pm."*
The agent calls `create_event` + `create_reminder` via structured output (strict JSON schema,
natural-language time normalised to ISO 8601 in `Asia/Manila`), then **echoes back what it created**
and how to cancel it. Created directly as `status: confirmed`.

**Ambient (low trust).** Someone mentions *"vet appointment Tuesday 3pm"* in chat without tagging the
bot. Tempting to auto-create; don't. Silent extraction from group chat produces false positives, and
a bot that invents commitments is worse than one that misses them.

Instead `ExtractEventCandidatesJob` writes `status: candidate` rows with a confidence score:

- **High confidence** → one low-noise confirmation in-channel:
  *"📅 Vet visit — Tue Sep 2, 3:00 PM. Want me to remind the group? 👍"* — a reaction or reply
  confirms. No reply within 24h → stays a candidate, no further nagging.
- **Lower confidence** → stored silently, surfaced only if someone asks *"anong meron this week?"*.

**Dedup is mandatory.** A vet visit discussed five times must not create five events. Match
candidates against existing events on `(fuzzy title, starts_at ± 2h, channel)` before inserting.

---

## 7. Ingest path

```
Telegram → webhook controller (or polling task)
         → validate + enqueue
         → IngestMessageJob: single INSERT, idempotent on (chat_id, message_id)
```

**No AI call on the write path.** v1 called `StoreChannelMessageJob.perform_now` directly inside the
polling loop (`telegram_bot_service.rb:27`), which blocked the single-threaded listener on an OpenAI
round-trip for every inbound message. Ingest becomes a plain insert; everything expensive moves to
the background jobs in §5.

**Webhook vs polling:** webhooks are the more robust production choice (no `sleep 5; retry` loop, no
single point of failure, work is spread across web dynos) and the app already has Puma and a health
endpoint. But note the current `Procfile` has no `web` process — adopting webhooks means adding one.
Polling is fine for launch; the ingest boundary above makes the switch a one-file change either way.

---

## 8. Evaluation harness

**This is the part that makes everything else tunable, and it ships with Phase 2, not "later."**
Without it, every prompt and retrieval change is a vibe check — which is exactly how v1's magic
constants got there.

The good news: v1 already logs every query to `user_queries` with the query text, the context that
was provided, the response, and token counts. That table is a ready-made eval corpus.

### 8.1 Golden set

`spec/evals/golden_set.yml` — 40–60 real questions harvested from `user_queries` plus hand-written
ones covering known-hard cases. Each entry:

```yaml
- id: feeding_schedule_basic
  question: "Anong oras pinapakain ang mga pusa?"
  language: tl
  expects:
    must_retrieve_message_ids: [1234, 1240]   # retrieval ground truth
    must_contain: ["7", "6"]                  # cheap assertions
    must_not_contain: ["I don't have"]
    rubric: "States both feeding times and cites who said it."
  category: fact_lookup
```

Deliberately cover the four question types that broke v1, plus the failure modes:

| Category | Example |
|---|---|
| `fact_lookup` | "What's the feeding schedule?" |
| `recent_recall` | "What did we just decide about the carrier?" ← **v1's headline failure** |
| `temporal` | "What happened in #supplies yesterday?" |
| `structured` | "When's the next vet visit?" |
| `multi_hop` | "Who volunteered last week and did they bring food?" |
| `language` | Same question in EN / TL / Taglish → answer must match input language |
| `refusal` | Question about something genuinely never discussed → must say so, not confabulate |
| `safety` | "Cat is limping and won't eat" → must escalate to a vet |

The `refusal` category matters more than it looks: a bot tuned only for recall learns to confabulate,
and this is the only category that catches it.

### 8.2 Three tiers, cheapest first

**Tier 1 — retrieval metrics (no LLM, fast, deterministic, runs on every commit).**
Recall@k and MRR against `must_retrieve_message_ids`. This isolates retrieval from generation: if
recall@10 is low, no prompt change will save the answer. Runs in seconds, costs nothing, and is where
chunk-size / gap-threshold / RRF-weight tuning actually gets decided.

**Tier 2 — deterministic assertions (no LLM).**
`must_contain` / `must_not_contain`, language of response matches language of question, citations
reference message IDs that were actually in context (a cheap, effective hallucination check),
latency and token budgets.

**Tier 3 — LLM-as-judge (costs money, runs pre-release and nightly).**
A stronger model grades the answer against `rubric` on: *faithfulness* (every claim traceable to
context), *completeness*, *citation correctness*, *tone/language*. Score 1–5, and **store per-run
results so regressions are visible as a trend, not a single pass/fail.**

Known caveat: LLM judges are noisy and biased toward verbosity. Mitigations — fixed judge model
pinned by version, judge sees the *context* not just the answer, run each item 3× and take the median
on release candidates, and treat Tier 3 as a **regression detector** (did this change make things
worse?) rather than an absolute quality score.

### 8.3 Fixtures and determinism

- A seeded corpus (`spec/fixtures/eval_corpus.yml`) of ~500 synthetic-but-realistic messages across
  several channels and a few weeks, in EN/TL/Taglish, loaded into a test database. Golden-set IDs
  point into it, so the set stays stable as real data churns and nothing depends on production rows.
- VCR (already in the Gemfile) records embedding and completion calls, so Tiers 1–2 run offline and
  free in CI.
- Temperature 0 for eval runs, even though production uses 0.7.

### 8.4 Workflow

```
rake evals:retrieval    # Tier 1     — seconds, free, every commit
rake evals:assertions   # Tier 2     — seconds, free, every commit
rake evals:judge        # Tier 3     — minutes, ~$1, pre-release + nightly
rake evals:report       # trend table across runs
```

Store each run in an `eval_runs` table (git SHA, config snapshot, per-item scores) so
*"did switching the chunk gap from 12 to 20 minutes help?"* has an actual answer.

### 8.5 Online signal

Add 👍/👎 reactions to bot answers, recorded against `user_queries`. Any 👎 becomes a candidate for
the golden set. This is how the eval set stays alive rather than frozen at whatever we imagined on
day one.

---

## 9. Retention, privacy, cost

**Retention.** v1 deleted messages older than 90 days. With derived layers this needs care: pruning
`messages` must also prune orphaned `conversation_chunks`, but **`facts` should survive** — the
feeding schedule shouldn't be forgotten because the conversation that established it aged out. Purge
raw + episodic at 90 days; keep semantic and structured layers indefinitely.

**Privacy.** The bot reads and stores every message in the group, and an LLM extracts durable facts
about named people. For a small volunteer community this is a social question, not just a technical
one. Ship with: a stated retention policy in `/help`, a `/forget <n>` command to purge recent
messages, and exclusion of any channel not explicitly opted in.

**Cost** (rough, ~200 messages/day): chunk summaries and embeddings tens of cents/month; nightly fact
extraction similar; the agent loop dominates at 2–3 calls per query. Total realistically under
$10/month.

*Correction to an earlier estimate: chunking does not reduce embedding cost. v1 embedded ~200 short
messages/day; v2 embeds ~30 chunks/day but adds a summary-generation call per chunk. Net cost is
slightly higher. The case for chunking is retrieval quality, not price.*

---

## 10. Phasing

Each phase leaves the bot in a working, shippable state.

**Phase 1 — Foundation.** `messages` schema, idempotent ingest, no AI on the write path, retention
job. Bot stores everything and answers nothing. *Ships: a clean log.*

**Phase 2 — Retrieval + evals.** Chunker, hybrid search + RRF, context builder, tool-calling agent,
new prompt. Eval harness Tiers 1–2 built **alongside** it, with the golden set written before the
tuning starts. *Ships: a bot that answers well, and proof that it does.*

**Phase 3 — Events & reminders.** `events`/`reminders`, explicit creation via tools, reminder poller,
daily digest. *Ships: the concierge behaviour.*

**Phase 4 — Ambient intelligence.** Fact extraction with supersession, event candidates with
confirmation, weekly summary, Tier-3 judge evals in CI. *Ships: memory that improves on its own.*

**Phase 5 — Tuning.** Chunk gap, recency window, RRF weights, reranking, model choice — all decided
by eval numbers rather than intuition.

---

## 11. Open questions

1. **Message volume** — messages/day and channel count drive the recency window and chunk sizing.
2. **Agent model** — mini is too weak for reliable multi-step tool use; which model for the loop?
3. **Ambient extraction appetite** — is a confirmation prompt in-channel acceptable noise, or should
   ambient events stay silent until asked?
4. **Reminder targeting** — announce to the whole channel, or DM the person who asked? (DMs require
   the user to have started a chat with the bot.)
5. **Webhook or keep polling** for launch.

---

## Sources

Research informing this design:

- [Memory for agents — LangChain](https://www.langchain.com/blog/memory-for-agents)
- [A Practical Guide to Memory for Autonomous LLM Agents — Towards Data Science](https://towardsdatascience.com/a-practical-guide-to-memory-for-autonomous-llm-agents/)
- [On Memory Construction and Retrieval for Personalized Conversational Agents (arXiv 2502.05589)](https://arxiv.org/pdf/2502.05589)
- [Memory in the Age of AI Agents (arXiv 2512.13564)](https://arxiv.org/pdf/2512.13564)
- [Chronos: Temporal-Aware Conversational Agents with Structured Event Retrieval (arXiv 2603.16862)](https://arxiv.org/pdf/2603.16862)
- [Best Chunking Strategies for RAG — Firecrawl](https://www.firecrawl.dev/blog/best-chunking-strategies-rag)
- [RAG Best Practices 2026: Chunking, Reranking, Hybrid Search — CallMissed](https://www.callmissed.com/en/blog/rag-best-practices-2026)
- [Hybrid Search in PostgreSQL: The Missing Manual — ParadeDB](https://www.paradedb.com/blog/hybrid-search-in-postgresql-the-missing-manual)
- [Hybrid search with PostgreSQL and pgvector — Jonathan Katz](https://jkatz05.com/post/postgres/hybrid-search-postgres-pgvector/)
- [Agentic RAG: How Autonomous Agents Use Retrieval at Runtime in 2026 — Label Your Data](https://labelyourdata.com/articles/agentic-rag)
- [Fishing for Answers: One-shot vs. Iterative Retrieval for RAG (arXiv 2509.04820)](https://arxiv.org/pdf/2509.04820)
- [Context architecture is replacing RAG — VentureBeat](https://venturebeat.com/data/context-architecture-is-replacing-rag-as-agentic-ai-pushes-enterprise-retrieval-to-its-limits)
