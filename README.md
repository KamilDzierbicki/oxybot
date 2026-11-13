# Flint

Flint turns scattered customer feedback into product decisions. Feedback arrives from Slack channels and a form,
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
| Split into insights, one product each (`flint-extract`) | `FeedbackNote::Extractable`, `InsightExtractor` |
| Hybrid search for candidate features, then a judge (`flint-judge`) | `HybridSearchable`, `Insight::Matchable`, `FeatureJudge` |
| PM links, relinks, creates a feature or dismisses | Inbox (`InsightsController`, `Insights::*`) |
| Demand: insights, distinct customers, their ARR | `Feature.by_demand` |
| Assistant with read-only tools and checked citations (`flint-spark`) | `ProductAgent`, `Conversation::Turn`, `app/tools` |

Design rules worth keeping:

- **Tenancy:** every table has `account_id`, and every query starts from `Current.account` (web) or from the
  record's account (jobs, Slack). Tools are built per turn and search only that account.
- **The model proposes, people decide:** matching only suggests a feature; a PM links it.
- **Model output is input:** unknown products, features outside the candidates and citations of insights no tool
  returned are dropped in code.
- **Feedback is untrusted text:** the extraction model has no tools, and the assistant's tools only read.
- **Slack visibility:** in a shared channel the assistant never shows revenue; direct messages and the web app do.

## Integrations

Both run in mock mode until an access token is saved on the Integrations page.

- **Slack:** create a Slack app with the Events API pointed at `/slack/events` (events `message.channels`,
  `message.im`, `app_mention`; scope `chat:write`), set `SLACK_SIGNING_SECRET`, then save the bot token, the app's
  member id and the feedback channel ids. Users are matched by their Slack member id (set on the user). In mock
  mode the Slack page has a simulator that sends the same events and shows the replies.
- **HubSpot:** create a private app with `crm.objects.companies.read` and `crm.objects.contacts.read`, save its
  token and the company property that holds ARR. Sync runs every hour and from the "Sync now" button. In mock mode
  data comes from `config/mocks/hubspot.yml`.

## Tests

```bash
bin/rails test
```

Tests run offline: WebMock routes the model host to the same mock model, and Slack and HubSpot calls to stubs.
