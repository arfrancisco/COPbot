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
| **The bot never silently commits the community to anything.** | Events are created only when a user explicitly asks; nothing is inferred from overheard chat. |
| **The bot never posts unprompted, except on a schedule the community opted into.** | No confirmation prompts, no "did you mean…?"; only the digest and reminders people asked for. |
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

### 4.1 Model selection — two independent choices

`gpt-4o-mini` is too weak for reliable multi-step tool use, and the whole design depends on it. The
key structural fact that makes changing this cheap:

> **The completion provider and the embedding provider are independent.** Anthropic has no
> embeddings endpoint at all, so "switch the agent to Claude" does not imply re-embedding anything.
> The pgvector index, its 1536 dimensions, and the HNSW index stay exactly as they are.

So the abstraction is **two adapters, not one**:

```
CompletionProvider   — agent loop, chunk summaries, fact extraction   (swappable)
EmbeddingProvider    — chunk + fact vectors                            (effectively pinned)
```

**Embeddings: stay on OpenAI `text-embedding-3-large` @ 1536 dims.** It already works, the index is
built around it, and changing embedding models means re-embedding the entire corpus and rebuilding
the HNSW index for no measurable gain. This is the one place *not* to touch.

**Completions: recommended split.**

| Role | Model | Price (in/out per 1M) | Why |
|---|---|---|---|
| Agent loop | `claude-sonnet-5` | $3 / $15 | Strong tool use, 1M context, Ruby SDK ships a tool runner |
| Background (summaries, fact extraction) | `claude-haiku-4-5` | $1 / $5 | Summarising a chat chunk is not hard; this is the high-volume path |
| Escalation, if evals demand it | `claude-opus-5` | $5 / $25 | Only if the agent loop measurably fails at Sonnet |

*(Sonnet 5 is at introductory $2/$10 through 2026-08-31 — budget against the standing $3/$15.)*

Three practical notes for the Ruby side:

- **Gem is `anthropic`, not `ruby-openai`.** Client is `Anthropic::Client.new`; it reads
  `ANTHROPIC_API_KEY` from the environment like the current OpenAI client does.
- **The SDK has a tool runner** (`client.beta.messages.tool_runner`, beta) that drives the
  request → execute → loop cycle for us. Tools are `Anthropic::BaseTool` subclasses with an
  `Anthropic::BaseModel` input schema — meaningfully less loop code than hand-rolling it. It is a
  beta surface, so pin the gem version.
- **Prompt caching is a real cost lever here.** Our prompt has a large stable prefix — system
  prompt, channel roster, all active facts — followed by volatile content (current time, recent
  messages, the question). Put a `cache_control` breakpoint at the end of the stable section and
  cache reads cost ~0.1× input. The minimum cacheable prefix on Sonnet 5 is 1024 tokens, which our
  system prompt alone already exceeds. **This requires the prompt to be ordered stable-first** —
  worth designing in from the start rather than retrofitting, since interpolating the current
  timestamp into the system prompt (as v1 does) invalidates the entire cache on every request.

Two Claude-specific parameters worth setting deliberately rather than by default:
`thinking: {type: "adaptive"}` with `output_config: {effort: ...}` replaces temperature-style
tuning (Sonnet 5 rejects non-default `temperature`/`top_p`/`top_k` outright). Start the agent loop
at `medium` effort and let the eval harness in §8 pick the level.

**If staying on OpenAI is preferred**, the adapter split above still applies — swap only the
completion adapter's implementation. The eval harness makes that an A/B rather than a guess, which
is the main argument for building §8 before committing to a provider.

### 4.2 Retrieval mechanics

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

### 4.3 Label context by *kind*, not just content

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

## 6. Event & reminder capture — explicit only

**Decision: the bot only creates events when someone directly asks it to.** No ambient detection, no
unprompted confirmation prompts, no candidate queue.

The flow: a user tags the bot — *"@copbot remind us about the vet visit Tuesday 3pm"* — and the agent
calls `create_event` + `create_reminder` via structured output (strict JSON schema, natural-language
time normalised to ISO 8601 in `Asia/Manila`). It then **echoes back exactly what it created** and how
to cancel. Rows are written directly as `status: confirmed`.

Why this is the right default here rather than a limitation:

- **Zero false positives.** A bot that invents commitments the group never made is worse than one
  that misses some — and in a small volunteer community, a wrong reminder costs social trust that a
  missed one doesn't.
- **Zero unprompted noise.** Nothing the bot posts is unsolicited.
- **It's the smallest thing that can be evaluated.** Explicit creation is deterministic enough to
  test properly; ambient extraction needs a labelled corpus of "was this really an event?" before
  any confidence threshold means anything.

**Still required, even with explicit-only:**

- **Dedup.** Two people can both ask the bot to remind the group about the same vet visit. Match
  against existing events on `(fuzzy title, starts_at ± 2h, channel)` before inserting, and tell the
  second asker it's already scheduled.
- **Cancellation and listing.** `/events` to list upcoming, and a way to cancel — otherwise a wrong
  reminder is unfixable and fires anyway.
- **Ambiguous time handling.** "Tuesday 3pm" with no date is *next* Tuesday; "3pm" today when it's
  already 4pm is tomorrow. Resolve against Manila time and state the resolved date in the echo, so a
  misparse is visible immediately rather than at reminder time.

The `status: candidate` value stays in the schema (§3.4). Nothing writes it today; it costs nothing
to keep, and it's the seam if ambient detection is ever wanted — the retrieval layer can already
answer *"anong meron this week?"* from `events` without it.

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

**Webhook vs polling — deliberately deferred.** Webhooks are the more robust production choice (no
`sleep 5; retry` loop, no single-threaded listener, work spread across web dynos), and the app
already has Puma and a health endpoint — but the current `Procfile` has no `web` process, so
adopting them means adding one.

**No decision is needed yet.** Phase 1 ships on the existing polling rake task. The ingest boundary
above is the whole point: the transport hands `IngestMessageJob` a normalised message and nothing
downstream knows or cares where it came from, so switching later is one new controller plus a
`Procfile` line. Revisit if polling actually proves flaky in production, not before.

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

**Cost**, assuming ~200 messages/day (revise once §12.1 is answered):

| Item | Model | Rough monthly |
|---|---|---|
| Embeddings (~30 chunks/day + facts) | `text-embedding-3-large` | cents |
| Chunk summaries (~30/day) | `claude-haiku-4-5` | well under $1 |
| Nightly fact extraction | `claude-haiku-4-5` | well under $1 |
| Agent loop (~20 queries/day × 2–3 calls) | `claude-sonnet-5` | the dominant line item |
| Daily digest + weekly summary | `claude-haiku-4-5` | cents |

Total realistically under $10/month, and the agent loop is the only line worth optimising. The two
levers there are prompt caching on the stable prefix (~0.1× on cached input — see §4.1) and the
`effort` setting, both of which the eval harness can be pointed at directly.

*Note on chunking economics: chunking does not reduce embedding cost. v1 embedded ~200 short
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

**Phase 3 — Events & reminders.** `events`/`reminders`, explicit creation via tools, dedup,
cancellation/listing, the reminder poller, daily digest. *Ships: the concierge behaviour.*

**Phase 4 — Semantic memory.** Fact extraction with supersession, weekly summary, Tier-3 judge
evals in CI. All silent background work — no new unprompted output. *Ships: memory that improves on
its own.*

**Phase 5 — Tuning.** Chunk gap, recency window, RRF weights, reranking, effort level — all decided
by eval numbers rather than intuition.

---

## 11. Decisions made

- **Agent model** — provider-agnostic completion adapter; `claude-sonnet-5` for the agent loop,
  `claude-haiku-4-5` for background work, OpenAI `text-embedding-3-large` retained for embeddings
  (§4.1).
- **Event capture** — explicit tagging only. No ambient detection (§6).
- **Ingest transport** — deferred; ship Phase 1 on polling, switch behind the ingest boundary if
  needed (§7).

## 12. Open questions

1. **Message volume** — messages/day and channel count. Drives `RECENT_WINDOW_HOURS`,
   `CHUNK_GAP_MINUTES`, and whether the recency window can be as generous as 8–12h.
2. **Reminder targeting** — announce to the whole channel, or DM the person who asked? DMs require
   the user to have started a private chat with the bot, so channel announcements are the safe
   default; per-event choice is possible but adds a decision to every creation.
3. **Digest opt-in** — does the daily 07:00 digest go to every channel, or one designated one?

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
