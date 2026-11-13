# OxyBot

An open product agent for product teams: it turns scattered customer feedback into decisions, specs and
release communication. Feedback arrives from Slack channels and a form,
a model splits it into atomic insights, each insight gets a suggested backlog feature, and a product manager
confirms it in an inbox. Features are then ranked by how many customers ask for them and how much ARR those
customers bring (synced from HubSpot). An assistant answers questions about all of it, in the app and in Slack,
and cites the insights behind every claim.

Stack: Rails 8.1 (Hotwire, Solid Queue, Solid Cable), Postgres with pgvector, RubyLLM, LiteLLM, Langfuse.

## Run it

```bash
docker compose up -d db
bin/rails db:prepare db:seed
bin/dev
```

Open http://localhost:3120 and sign in with the demo account from `db/seeds.rb`. The seeded feedback is
processed by background jobs in the first seconds after start; the Inbox then shows suggestions.

Without `LITELLM_URL` the app uses a mock model (`lib/mock_llm.rb`, mounted at `/mock_llm`). It speaks the same
OpenAI-compatible API as LiteLLM, so every request takes the real path through RubyLLM, schemas and tool calls;
only the answers come from simple word-overlap heuristics. Its suggestions are rough on purpose.

### Real models and traces

```bash
cp .env.example .env    # fill in ANTHROPIC_API_KEY and OPENAI_API_KEY
docker compose --profile ai up -d
bin/dev
```

This starts LiteLLM on port 4010 (aliases in `litellm.yaml`, each with a daily spend cap) and Langfuse on
port 3011 (login from `compose.yml`). Rails sends its own spans to Langfuse through OpenTelemetry and LiteLLM
sends the model calls, so one assistant turn is one trace, grouped by conversation and tagged with the tenant.

## How it works

| Step | Code |
|---|---|
| Feedback arrives (form, Slack feedback channel) | `FeedbackNote`, `SlackMessage#process` |
| Customer resolved from the author's email or domain | `FeedbackNote#resolve_customer` |
| Split into insights, one product each (`oxybot-extract`) | `FeedbackNote::Extractable`, `InsightExtractor` |
| Hybrid search for candidate features, then a judge (`oxybot-judge`) | `HybridSearchable`, `Insight::Matchable`, `FeatureJudge` |
| PM links, relinks, creates a feature or dismisses | Inbox (`InsightsController`, `Insights::*`) |
| Demand: insights, distinct customers, their ARR | `Feature.by_demand` |
| Assistant with read-only tools and checked citations (`oxybot-assistant`) | `ProductAgent`, `Conversation::Turn`, `app/tools` |

Design rules worth keeping:

- **Tenancy:** every table has `account_id`, and every query starts from `Current.account` (web) or from the
  record's account (jobs, Slack). Tools are built per turn and search only that account.
- **The model proposes, people decide:** matching only suggests a feature; a PM links it.
- **Model output is input:** unknown products, features outside the candidates and citations of insights no tool
  returned are dropped in code.
- **Feedback is untrusted text:** the extraction model has no tools, and the assistant's tools only read.
- **Slack visibility:** in a shared channel the assistant never shows revenue; direct messages and the web app do.

## Product agent workflows

| Workflow | Where | Code |
|---|---|---|
| Specs from evidence and code | Feature page, "Write spec" | `Document::Brief#prd_sections`, `DocumentWriter`, `SearchCodeTool` |
| Change requests reviewed inline, version history with diffs | Document page | `DocumentSuggestion`, `Document::Revision`, `Document::Diff` |
| Weekly opportunity discovery (growth, emerging themes, segments, roadmap check), posted to Slack | Documents, and every Monday | `Account::OpportunityDiscovery`, `OpportunityDiscoveryJob` |
| Voice-of-customer report | Documents | `Document::Brief#voc_report_sections` |
| Release notes with the customers to notify | Documents | `Document::Brief#release_notes_sections` |
| Launch review against the spec's success metrics, usage and post-launch feedback | Released feature, "Launch review" | `Document::Brief#launch_review_sections`, `Feature::UsageMetrics` |
| Hand-off to engineering, status synced both ways | Feature page, "Send to Linear" | `Feature::Deliverable`, `Integration::Linear` |
| Specs for coding agents over MCP | Profile, "Create token" | `McpController`, `app/tools/spec_server` |
| Team and personal skills (`/name` in chat or Slack), templates, custom instructions | Skills, Documents → Templates, Knowledge, Profile | `Skill`, `DocumentTemplate` |

Code gathers the facts for every document (counts, ARR, evidence, code hits) and the model only writes;
the agent never edits a document in place, it proposes a change that a person accepts.

Not built yet: real-time co-editing between people, competitive research from public websites,
real analytics connectors (launch reviews read `config/mocks/usage.yml`), and parallel subagents.

## Integrations

Both run in mock mode until an access token is saved on the Integrations page.

- **Slack:** create a Slack app with the Events API pointed at `/slack/events` (events `message.channels`,
  `message.im`, `app_mention`; scope `chat:write`), set `SLACK_SIGNING_SECRET`, then save the bot token, the app's
  member id and the feedback channel ids. Users are matched by their Slack member id (set on the user). In mock
  mode the Slack page has a simulator that sends the same events and shows the replies.
- **HubSpot:** create a private app with `crm.objects.companies.read` and `crm.objects.contacts.read`, save its
  token and the company property that holds ARR. Sync runs every hour and from the "Sync now" button. In mock mode
  data comes from `config/mocks/hubspot.yml`.

- **Linear:** create a personal API key and a webhook (Issues events) pointing at `/linear/webhooks`; save the key,
  the team id and the webhook signing secret. The integration's `external_id` is the Linear organization id. In mock
  mode issues live in the integration's settings and the feature page can simulate a move in Linear.
- **GitHub:** a fine-grained token with read access to the repository's contents, and the repository as `owner/name`.
  In mock mode the spec writer searches the sample repository in `config/mocks/github`.
- **Coding agents (MCP):** create a token on the profile page, then
  `claude mcp add --transport http oxybot http://localhost:3120/mcp --header "Authorization: Bearer <token>"`.
  Tools: `list_specs`, `get_spec`, `search_feedback`, all read-only and limited to the token owner's account.

## Tests

```bash
bin/rails test
```

Tests run offline: WebMock routes the model host to the same mock model, and Slack and HubSpot calls to stubs.
