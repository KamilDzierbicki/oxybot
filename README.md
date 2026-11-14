# OxyBot

**An open-source product agent for product teams.** OxyBot collects customer feedback from Slack, Mattermost and
forms, turns it into atomic insights, links them to your backlog, ranks features by how many customers ask and how
much revenue they bring, and drafts specs, reports and release notes with a citation for every claim. You can ask it
questions in the web app, in Slack or in Mattermost, and coding agents read its specs over MCP.

It is self-hosted and built with Ruby on Rails,
Postgres with pgvector, LiteLLM and Langfuse. MIT licensed.

![The assistant answers with cited customer evidence; a citation opens the quote, the customer and their ARR](docs/screenshots/assistant.jpg)

## Why OxyBot

Customer feedback is scattered: a sales call note in Slack, a support thread in Mattermost, a request in the CRM.
Product managers read some of it, remember the loudest customer, and decide from there. Nobody can say how many
customers asked for a feature, how much revenue they bring, or where a claim in a spec came from.

AI product agents fix part of this, but most are closed SaaS: your customers' words and revenue go to a vendor, the
model is the vendor's choice, and you cannot check how a number was made. OxyBot takes a different position:

- **Evidence first.** Every claim in an answer or a document links to the customer quote it comes from. Code drops any
  citation the model did not get from a tool, and code, not the model, counts customers and ARR.
- **People decide.** The model proposes a feature for each insight; a product manager confirms it. Documents change
  only through suggestions you accept, with a diff and a version history you can restore.
- **Your data, your models.** It runs on your server. LiteLLM lets you pick Claude, OpenAI or a local model per task
  and caps the daily spend; embeddings run locally in Ollama; Langfuse traces every call.
- **Where the team already works.** Ask in Slack or Mattermost, send features to Linear, and give coding agents the
  spec and its evidence over MCP.

## Features

**Feedback to evidence**
- Feedback arrives from Slack and Mattermost feedback channels, a web form and (soon) email.
- A model splits each note into atomic insights, one product each, with urgency and the customer behind it.
- Customers and ARR sync from HubSpot; an insight's customer is found from the author's email or domain.
- Hybrid search (vectors plus full text) and a judge model suggest the backlog feature each insight asks for.
- A triage list where a product manager links, picks another feature, creates one or dismisses, with keyboard
  shortcuts and undo: the model proposes, people decide.

**Decisions and documents**
- Features ranked by demand: insights, distinct customers and their ARR, each customer counted once.
- Product specs drafted from the feature's evidence, company knowledge and your codebase (GitHub).
- A weekly opportunity report: growth, emerging themes without a feature, segments by plan, roadmap gaps; posted to chat.
- Voice-of-customer reports, release notes with the customers to notify, and launch reviews against the spec's goals.
- Change requests ("shorten the requirements") come back as suggestions with a diff; every edit is a version.
- Templates, team skills (`/churn-risk`) and team or personal instructions encode how your team works.

**Where you work**
- An assistant in the web app, in Slack (DM or mention) and in Mattermost (`/oxybot` or `@oxybot`).
- Features go to Linear as issues with their spec; status syncs both ways.
- An MCP server gives Claude Code, Codex and Cursor read access to specs and customer evidence.

**Built to be trusted**
- Every claim cites the insight it comes from, and code drops any citation the model did not get from a tool.
- Revenue never appears in shared channels; private chats and the web app show it.
- Multi-tenant from the first table: every query is scoped to the account.

| Insights to triage | Spec with an agent suggestion and its diff |
|---|---|
| ![Insights to triage](docs/screenshots/inbox.jpg) | ![Spec](docs/screenshots/spec.jpg) |
| **Features by demand** | **AI settings** |
| ![Features](docs/screenshots/features.jpg) | ![AI settings](docs/screenshots/ai-settings.jpg) |

## How it works

```
 Slack / Mattermost / form ──► FeedbackNote ──► extract (LLM) ──► Insight ──► embed + hybrid search ──► judge (LLM)
                                                                    │                                     │
 HubSpot ──► Customer (ARR) ────────────────────────────────────────┘                    suggested feature │
                                                                                                           ▼
                                                                    PM confirms in Insights ──► Feature (demand)
                                                                                                           │
            Assistant (app, Slack, Mattermost) ◄── read-only tools ◄───────────────────────────────────────┤
            Documents: spec, VoC, opportunities, release notes, launch review ◄── facts gathered by code ◄──┤
            Linear (issues, status both ways) · MCP server for coding agents ◄─────────────────────────────┘

 Rails ──► LiteLLM (model aliases, budgets, any provider) ──► Claude, OpenAI, local models
   │            └──► Ollama (local embeddings)
   └──► Langfuse (traces, prompt versions)
```

Code gathers every fact a document uses (counts, ARR, evidence, code hits) and the model only writes. The model
never edits a document in place and has no tool that changes data or reaches outside the app, because feedback is
text written by outsiders.

## Quick start

You need Ruby 4.0.9 (the version in `.ruby-version`; install it with mise, rbenv or asdf) and Docker. Everything below
runs on your machine, needs no API key and takes a few minutes.

```bash
git clone https://github.com/KamilDzierbicki/oxybot.git
cd oxybot
bundle install
docker compose up -d db          # Postgres 17 with pgvector on localhost:5435
bin/rails db:prepare             # creates the databases, loads the schema and the demo data
bin/dev                          # web server and background jobs on http://localhost:3120
```

Open http://localhost:3120 and sign in as `demo@oxybot.local` with the password `oxybot-demo`. The demo workspace
has products, a backlog, customers with ARR, feedback, and mock Slack and HubSpot. To start empty, create your own
workspace at http://localhost:3120/signup/new.

Without `LITELLM_URL` OxyBot runs on a **built-in mock model** (`lib/mock_llm.rb`): no API keys, every request still
takes the real path through RubyLLM, schemas and tool calls, but answers come from simple heuristics. Integrations
without a token run in **mock mode** too, with a simulator on their page.

### With real models

```bash
cp .env.example .env              # add ANTHROPIC_API_KEY (and OPENAI_API_KEY if you use OpenAI models)
docker compose --profile ai up -d # LiteLLM on :4010, Ollama for embeddings, Langfuse on :3011
bin/dev
```

Every vector records which embedding model made it. OxyBot recognizes the model by its fingerprint (the vector of a
fixed sentence sent with every embedding call), not by the alias name, so pointing `oxybot-embed` at another model,
or switching from the mock to Ollama, is noticed on the first call: search and matching then compare only vectors of
the new model, and each workspace is embedded again in the background, in batches, resuming where it stopped. Check
progress with `bin/rails oxybot:embeddings`; `bin/rails oxybot:reembed` queues any stale workspace by hand.

Two local dashboards come with the `ai` profile:

| Dashboard | URL | Sign in | What you see |
|---|---|---|---|
| LiteLLM | http://localhost:4010/ui | `admin`, password = `LITELLM_API_KEY` (`sk-oxybot-local`) | every model call, its cost, budgets per alias |
| Langfuse | http://localhost:3011 | `admin@oxybot.local` / `oxybot-local` | traces from LiteLLM and Rails, prompt versions |

Langfuse needs ClickHouse, Redis and S3-compatible storage (all in `compose.yml`) and about 3 GB of memory. To run
without it, start only the model services: `docker compose --profile ai up -d litellm ollama ollama-pull`, and leave
the `LANGFUSE_*` variables empty.

Pick the model for each task in **AI settings**. The default aliases are in `litellm.yaml`; `oxybot-haiku` is a cheap
alias that runs every task on Claude Haiku.

## Run in production

The `Dockerfile` builds a production image that serves the app on port 80 and runs background jobs in the same
process. On start it creates or migrates the databases. A production database gets no demo data; create the first
workspace at `/signup/new` and invite your team from **Users**.

```bash
docker build -t oxybot .
bin/rails secret                       # value for SECRET_KEY_BASE
bin/rails db:encryption:init           # values for the three ACTIVE_RECORD_ENCRYPTION_* variables
docker run -d --name oxybot -p 80:80 --env-file .env.production oxybot
```

A minimal `.env.production`:

```bash
SECRET_KEY_BASE=...
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=...
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=...
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=...
DB_HOST=db.internal                    # Postgres 17 with the pgvector extension available
DB_USER=oxybot                         # needs permission to create databases on first start
DB_PASSWORD=...
APP_HOST=oxybot.example.com            # the public host name, used in links and allowed in requests
SOLID_QUEUE_IN_PUMA=true               # background jobs inside the web process
LITELLM_URL=https://litellm.internal/v1
LITELLM_API_KEY=...
```

The app uses four databases: `DB_NAME` (default `oxybot_production`) and the same name with `_cache`, `_queue` and
`_cable`. Run LiteLLM, Ollama and, if you want traces, Langfuse next to it; `compose.yml` and `litellm.yaml` show a
working setup. `config/deploy.yml` is a starting point for deploying with Kamal. Put HTTPS in front of the app;
`FORCE_SSL` is on by default.

Keep the encryption keys safe: integration tokens are encrypted with them, and losing them means connecting every
integration again.

## Observability and evaluation

OxyBot, LiteLLM and Langfuse work as one system:

| What | Where it shows |
|---|---|
| Every model call, with its cost, linked to the prompt version it was built from | Langfuse traces, LiteLLM logs |
| People's decisions as scores on the call they judge: `feature_match` (linked the suggested feature), `insight_kept` (kept or dismissed an insight), `suggestion_accepted` (took the agent's edit) | Langfuse scores |
| Skills run in the assistant (`/churn-risk`), with use counts per skill | Langfuse Skills |
| Experiments: the demo dataset in `config/evals` run on any model, with accuracy | `bin/rails evals:run MODEL=oxybot-haiku`, Langfuse Datasets |
| LLM-as-judge evaluators: is an answer supported by the quotes it cites, are extracted insights faithful | Langfuse Evaluators (see below) |
| A daily AI budget per workspace, enforced by LiteLLM, with today's spend | AI settings, LiteLLM Customers |
| Environments (development, production) kept apart | every trace and score |

Set it up once Langfuse runs:

```bash
bin/rails langfuse:push_prompts   # prompts become versions in Langfuse
bin/rails langfuse:push_skills    # skills appear in Langfuse's Skills view
bin/rails langfuse:setup          # Langfuse calls models through LiteLLM; evaluators and their rules
bin/rails evals:run               # a first experiment on the demo dataset
```

Scores carry only a name and 0 or 1, never text. Prompts and answers enter traces only with
`OXYBOT_TRACE_CONTENT=true`, which evaluators need; turn it on for local work or a demo workspace, not for real
customer data, and run `bin/rails langfuse:setup` again to switch the evaluator rules on.

## Configuration

| Variable | Purpose | Default |
|---|---|---|
| `LITELLM_URL`, `LITELLM_API_KEY` | Where Rails sends model calls. Empty: the built-in mock model | mock |
| `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` | Provider keys, read by LiteLLM only | none |
| `OLLAMA_API_BASE` | Embedding server used by the `oxybot-embed` alias | `http://ollama:11434` |
| `LANGFUSE_URL`, `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY` | Traces from Rails and prompt management | off |
| `SLACK_SIGNING_SECRET` | Verifies Slack events | local default in development |
| `APP_HOST`, `APP_PROTOCOL` | Links in chat messages and Linear issues | `localhost:3120`, `http` |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | Postgres with pgvector | compose database on 5435 |
| `SECRET_KEY_BASE` | Signs sessions and cookies (production) | required |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `..._DETERMINISTIC_KEY`, `..._KEY_DERIVATION_SALT` | Encrypt integration tokens (production) | required |
| `SEED_DEMO` | `true` loads the demo workspace into a production database | off |
| `AI_ENABLED` | `false` stops every model call (answers, drafts, extraction) without a deploy | `true` |
| `SENTRY_DSN` | Error and job failure reports to Sentry or a self-hosted GlitchTip | off |
| `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `MAILER_FROM` | Outgoing mail (invitations, password resets) | none: links are shown in the app |
| `FORCE_SSL` | HTTPS, HSTS and secure cookies in production | `true` |
| `ALLOW_PRIVATE_INTEGRATION_HOSTS` | Allow a self-hosted Mattermost on a private network address | `false` in production |
| `PRIVACY_POLICY_URL`, `TERMS_URL` | Links shown on sign-in, sign-up and invitation pages | none |
| `CHAT_RETENTION_DAYS` | How long routed chat messages are kept | `90` |
| `OXYBOT_TRACE_CONTENT` | `true` puts prompts and answers into Langfuse traces, for evaluators. Customer text: local or demo data only | off |
| `LANGFUSE_ENVIRONMENT` | Environment name on traces and scores | the Rails environment |
| `LITELLM_URL_FOR_LANGFUSE` | Where Langfuse reaches LiteLLM for evaluators | `http://litellm:4000/v1` |

Everything else is set in the dashboard:

| Setting | Where | Who |
|---|---|---|
| Connect, test and disconnect Slack, Mattermost, HubSpot, Linear, GitHub | Integrations | admins |
| Users, roles (admin, member), invitations | Users | admins |
| Model per task, matching and theme thresholds, agent step limit, weekly report schedule | AI settings | admins |
| Time zone, export, deletion of the workspace | Workspace | admins |
| Team instructions, document templates | Knowledge base, Documents → Templates | admins |
| Products, features, knowledge, skills, personal instructions, chat ids, MCP token | their pages, Profile | everyone |

Model budgets and which provider an alias calls stay in LiteLLM (`litellm.yaml` or its admin UI).

### Prompts

With Langfuse configured, `bin/rails langfuse:push_prompts` uploads `config/prompts/*.txt` as versions labeled
`production`. Edit them in Langfuse; OxyBot uses the new version within 5 minutes ("Reload prompts now" in AI settings
skips the wait) and tags every trace with the prompt version. Without Langfuse, or when it is down, the files are used.

## Integrations

Every integration starts in mock mode until you save its token, and has a **Test connection** button.

- **Slack:** a Slack app with scopes `chat:write`, `app_mentions:read`, `im:history`, `channels:history`, events
  `app_mention`, `message.im`, `message.channels`, the App Home messages tab on, and the request URL `/slack/events`.
  Step-by-step instructions are on the Slack integration page. DM the app for a private, ongoing conversation; mention
  it in a channel for an answer in the thread.
- **Mattermost (self-hosted):** a bot account for replies, outgoing webhooks for feedback channels and for `@oxybot`
  questions (`/mattermost/webhooks`), and a slash command `/oxybot` (`/mattermost/commands`) that works anywhere,
  including direct messages, with an answer only the asker sees. Instructions are on the Mattermost integration page.
- **HubSpot:** a private app token with `crm.objects.companies.read` and `crm.objects.contacts.read`. Choose the
  company property that holds ARR. Syncs every hour.
- **Linear:** a personal API key, the team id, and a webhook (Issues) to `/linear/webhooks` with its signing secret.
- **GitHub:** a fine-grained, read-only token for the repository; the spec writer searches it for technical context.
- **Coding agents (MCP):** create a token on your profile, then
  `claude mcp add --transport http oxybot https://your-host/mcp --header "Authorization: Bearer <token>"`.
  Tools: `list_specs`, `get_spec`, `search_feedback`.

## Security model

- **Limits:** sign-in and password resets are limited per address and per email; model-backed actions (questions,
  drafts, change requests, feedback) are limited per user per minute; MCP per token. The values are defaults in the
  controllers; LiteLLM's daily budgets cap the total spend.
- **Sessions** end after 14 days without use or 30 days after sign-in; a password reset ends all sessions and revokes
  the MCP token.
- **Chat identities** (Slack and Mattermost ids) are set by admins, and Slack events reach a workspace only after
  "Test connection" confirmed its team id, so nobody can claim someone else's messages or workspace.
- **Outbound calls** have timeouts; integration URLs that point to private or local addresses are refused in
  production (server-side request forgery).
- **Privacy:** workspace export (JSON) and deletion, deletion of feedback and customers, daily purge of ended
  sessions and old chat messages, no contact emails sent to the model, and LiteLLM traces without message text.

- **Tenancy:** every table carries `account_id`; controllers start from `Current.account`, jobs and webhooks from the
  record's account, and agent tools are built per request for one account.
- **Untrusted text:** feedback and chat messages are data. The extraction model has no tools, the assistant's tools
  only read, and model output is validated (unknown products, features outside the candidates and invented citations
  are dropped).
- **Webhooks** are verified: Slack and Linear signatures with replay windows, Mattermost tokens, and slash command
  callbacks only to your own Mattermost server.
- **Secrets:** integration tokens are encrypted at rest (Active Record Encryption); MCP tokens and invitation links
  are stored as SHA-256 digests and shown once.
- **Roles:** only admins change integrations, users, AI settings and team-wide instructions.

Found a vulnerability? See [SECURITY.md](SECURITY.md).

## Development

```bash
bin/rails test     # offline: model, Slack, Mattermost, HubSpot, Linear and GitHub calls are stubbed
bin/rubocop
bin/brakeman
```

The code follows Rails conventions: logic lives in models and concerns (`Insight::Matchable`,
`Feature::Deliverable`), plain Ruby objects sit next to their model (`Document::Brief`, `Conversation::Turn`), jobs
only call a model method, and there are no service objects. Agents (`app/agents`) are RubyLLM agents; their tools are
in `app/tools`.

| Path | What is there |
|---|---|
| `app/models/feedback_note`, `insight`, `feature` | Extraction, matching, demand, delivery to Linear |
| `app/models/document*` | Briefs, generation, revisions, diffs, versions |
| `app/models/integration*`, `chat_message.rb` | Slack, Mattermost, HubSpot, Linear, GitHub adapters |
| `app/models/conversation*`, `app/tools` | The assistant and its read-only tools |
| `app/tools/spec_server` | MCP tools for coding agents |
| `config/prompts` | Prompt fallbacks (Langfuse text-prompt format) |
| `lib/mock_llm.rb` | The offline model used in development and tests |

## Roadmap

- Real-time co-editing of documents between people
- Analytics connectors (Amplitude, Pendo) for launch reviews; today they read `config/mocks/usage.yml`
- Email and support-tool sources (Intercom, Zendesk, Gong)
- Competitive research from public sources

## Contributing

Issues and pull requests are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE). Use it, change it, host it for your team or your customers; keep the copyright notice.
